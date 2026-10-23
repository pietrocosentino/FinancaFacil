-- Lançamentos confirmados ficam bloqueados: não podem ser alterados nem
-- excluídos. Uma confirmação feita por engano pode ser inativada (sai dos
-- totais, continua no histórico) e reativada. Renda mensal pode ter nome,
-- categoria e dia alterados. Executar após 007. Não apaga dados.
begin;

alter table public.transactions add column if not exists is_inactive boolean not null default false;
alter table public.recurrence_occurrences add column if not exists is_inactive boolean not null default false;

-- Sem sessão de usuário (painel, service role, exclusão da conta em cascata)
-- a proteção não se aplica; ela vale para o aplicativo e para a API pública.
create or replace function public.guard_confirmed_transaction()
returns trigger language plpgsql set search_path = '' as $$
begin
  if auth.uid() is null then return coalesce(new, old); end if;
  if tg_op = 'DELETE' then
    if old.is_paid then
      raise exception 'Lançamento confirmado não pode ser excluído. Use Inativar.';
    end if;
    return old;
  end if;
  if tg_op = 'UPDATE' and old.is_paid
    and (to_jsonb(new) - 'is_inactive') is distinct from (to_jsonb(old) - 'is_inactive') then
    raise exception 'Lançamento confirmado não pode ser alterado. Use Inativar.';
  end if;
  if new.is_inactive and not new.is_paid then
    raise exception 'Somente lançamentos confirmados podem ser inativados.';
  end if;
  return new;
end;
$$;
drop trigger if exists guard_confirmed_transaction on public.transactions;
create trigger guard_confirmed_transaction
  before insert or update or delete on public.transactions
  for each row execute function public.guard_confirmed_transaction();

create or replace function public.guard_confirmed_occurrence()
returns trigger language plpgsql set search_path = '' as $$
begin
  if auth.uid() is null then return coalesce(new, old); end if;
  if tg_op = 'DELETE' then
    if old.is_paid then
      raise exception 'Lançamento confirmado não pode ser excluído. Use Inativar.';
    end if;
    return old;
  end if;
  if tg_op = 'UPDATE' and old.is_paid then
    -- Reajuste futuro grava o valor que já valia no mês confirmado.
    if current_setting('financafacil.freeze_amount', true) = 'on'
      and old.amount is null and new.amount is not null
      and (to_jsonb(new) - 'amount') = (to_jsonb(old) - 'amount') then
      return new;
    end if;
    if (to_jsonb(new) - 'is_inactive') is distinct from (to_jsonb(old) - 'is_inactive') then
      raise exception 'Lançamento confirmado não pode ser alterado. Use Inativar.';
    end if;
  end if;
  if new.is_inactive and not new.is_paid then
    raise exception 'Somente lançamentos confirmados podem ser inativados.';
  end if;
  return new;
end;
$$;
drop trigger if exists guard_confirmed_occurrence on public.recurrence_occurrences;
create trigger guard_confirmed_occurrence
  before insert or update or delete on public.recurrence_occurrences
  for each row execute function public.guard_confirmed_occurrence();

-- Inativar/reativar um lançamento confirmado (avulso ou mês de recorrência).
create or replace function public.set_entry_inactive(p_entry_id text, p_inactive boolean)
returns void language plpgsql security invoker set search_path = '' as $$
declare
  parts text[];
  changed integer;
begin
  if auth.uid() is null then raise exception 'Sessão expirada'; end if;
  if p_entry_id is null or length(p_entry_id) > 200 or p_inactive is null then
    raise exception 'Registro inválido';
  end if;
  if left(p_entry_id, 2) = 'r:' then
    parts := string_to_array(p_entry_id, ':');
    if array_length(parts, 1) <> 3 or parts[3] !~ '^[0-9]{4}-[0-9]{2}-01$' then
      raise exception 'Mês inválido';
    end if;
    update public.recurrence_occurrences set is_inactive = p_inactive
      where rule_id = parts[2]::uuid and due_month = parts[3]::date
        and user_id = auth.uid() and is_paid;
  else
    update public.transactions set is_inactive = p_inactive
      where id::text = p_entry_id and user_id = auth.uid() and is_paid;
  end if;
  get diagnostics changed = row_count;
  if changed <> 1 then
    raise exception 'Somente lançamentos confirmados podem ser inativados.';
  end if;
end;
$$;
revoke all on function public.set_entry_inactive(text, boolean) from public, anon;
grant execute on function public.set_entry_inactive(text, boolean) to authenticated;

-- Renda mensal: nome, categoria e dia valem para toda a recorrência.
create or replace function public.update_income_rule(
  p_rule_id uuid, p_description text, p_category_id text, p_due_day integer
) returns void language plpgsql security invoker set search_path = '' as $$
declare
  rule public.recurrence_rules;
  clean_name text := regexp_replace(btrim(coalesce(p_description, '')), '\s+', ' ', 'g');
begin
  if auth.uid() is null then raise exception 'Sessão expirada'; end if;
  select * into strict rule from public.recurrence_rules
    where id = p_rule_id and user_id = auth.uid() for update;
  if rule.template->>'type' <> 'receita' then
    raise exception 'Somente rendas mensais podem ser alteradas por aqui.';
  end if;
  if length(clean_name) not between 1 and 120 then raise exception 'Informe um nome de até 120 caracteres.'; end if;
  if p_due_day is null or p_due_day not between 1 and 31 then raise exception 'Informe um dia de 1 a 31.'; end if;
  if not exists (select 1 from public.categories c where c.id::text = p_category_id
      and c.transaction_type::text = 'INCOME' and (c.user_id is null or c.user_id = auth.uid())) then
    raise exception 'Selecione uma categoria de receita.';
  end if;
  update public.recurrence_rules set
    due_day = p_due_day,
    template = template || jsonb_build_object('description', clean_name, 'category_id', p_category_id)
    where id = p_rule_id and user_id = auth.uid();
end;
$$;
revoke all on function public.update_income_rule(uuid, text, text, integer) from public, anon;
grant execute on function public.update_income_rule(uuid, text, text, integer) to authenticated;

-- Igual à versão anterior, marcando a gravação permitida em meses confirmados.
create or replace function public.set_recurrence_future_amount(p_rule_id uuid, p_from_month date, p_amount numeric)
returns void language plpgsql security invoker set search_path = '' as $$
declare
  rule public.recurrence_rules;
  offset_month integer;
  scheduled jsonb;
  paid record;
  previous_amount numeric;
  changes jsonb;
begin
  if auth.uid() is null then raise exception 'Sessão expirada'; end if;
  if p_from_month is null or extract(day from p_from_month) <> 1 or p_from_month < date_trunc('month', timezone('America/Sao_Paulo', now()))::date then raise exception 'Escolha o mês atual ou um mês futuro'; end if;
  if p_amount is null or p_amount <= 0 or p_amount::text in ('NaN','Infinity','-Infinity') then raise exception 'Valor inválido'; end if;
  select * into strict rule from public.recurrence_rules where id = p_rule_id and user_id = auth.uid() for update;
  offset_month := (extract(year from p_from_month)::integer - extract(year from rule.first_due)::integer) * 12 + extract(month from p_from_month)::integer - extract(month from rule.first_due)::integer;
  if offset_month < 0 or offset_month > 1200 or (rule.total_installments is not null and offset_month >= rule.total_installments) or (rule.end_date is not null and p_from_month > rule.end_date) then raise exception 'Mês fora do período'; end if;
  perform set_config('financafacil.freeze_amount', 'on', true);
  for paid in select * from public.recurrence_occurrences where rule_id = p_rule_id and user_id = auth.uid() and due_month >= p_from_month and is_paid and amount is null for update loop
    previous_amount := (rule.template->>'amount')::numeric;
    for scheduled in select value from jsonb_array_elements(coalesce(rule.template->'future_amounts', '[]'::jsonb)) order by value->>'from_month' loop
      if (scheduled->>'from_month')::date <= paid.due_month then previous_amount := (scheduled->>'amount')::numeric; end if;
    end loop;
    update public.recurrence_occurrences set amount = previous_amount where rule_id = p_rule_id and user_id = auth.uid() and due_month = paid.due_month;
  end loop;
  perform set_config('financafacil.freeze_amount', 'off', true);
  update public.recurrence_occurrences set amount = null where rule_id = p_rule_id and user_id = auth.uid() and due_month >= p_from_month and not is_paid;
  select coalesce(jsonb_agg(value order by value->>'from_month'), '[]'::jsonb) into changes from jsonb_array_elements(coalesce(rule.template->'future_amounts','[]'::jsonb)) where (value->>'from_month')::date < p_from_month;
  changes := changes || jsonb_build_array(jsonb_build_object('from_month', p_from_month, 'amount', p_amount));
  update public.recurrence_rules set template = jsonb_set(template, '{future_amounts}', changes) where id = p_rule_id and user_id = auth.uid();
end;
$$;
revoke all on function public.set_recurrence_future_amount(uuid,date,numeric) from public, anon;
grant execute on function public.set_recurrence_future_amount(uuid,date,numeric) to authenticated;

-- A nova coluna não pode impedir desfazer lotes importados antes dela.
create or replace function public.undo_finance_import(p_batch_id uuid)
returns integer language plpgsql security definer set search_path = '' as $$
declare
  batch public.finance_import_batches;
  item public.finance_import_items;
  transaction_row public.transactions;
  rule public.recurrence_rules;
  count_removed integer := 0;
begin
  if auth.uid() is null then raise exception 'Sua sessão terminou. Entre novamente.'; end if;
  perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text || ':finance-import', 0));
  select * into strict batch from public.finance_import_batches
    where id = p_batch_id and user_id = auth.uid() for update;
  if batch.status = 'undone' then return 0; end if;
  for item in select * from public.finance_import_items where batch_id = batch.id
      and user_id = auth.uid() order by record_kind,record_id loop
    if item.record_kind = 'transaction' then
      select * into transaction_row from public.transactions
        where id::text = item.record_id and user_id = auth.uid() for update;
      if not found or transaction_row.is_paid
        or (to_jsonb(transaction_row) - 'is_inactive') <> (item.original_record - 'is_inactive') then
        raise exception 'Lote preservado: um lançamento foi alterado, confirmado ou removido.';
      end if;
    else
      select * into rule from public.recurrence_rules
        where id::text = item.record_id and user_id = auth.uid() for update;
      if not found or to_jsonb(rule) <> item.original_record or exists(
          select 1 from public.recurrence_occurrences o where o.rule_id = rule.id and o.user_id = auth.uid()) then
        raise exception 'Lote preservado: uma recorrência foi alterada ou possui confirmações.';
      end if;
    end if;
  end loop;
  -- Todos os registros foram conferidos e permanecem bloqueados até o commit.
  for item in select * from public.finance_import_items where batch_id = batch.id and user_id = auth.uid() loop
    if item.record_kind = 'transaction' then
      delete from public.transactions where id::text = item.record_id and user_id = auth.uid();
    else
      delete from public.recurrence_rules where id::text = item.record_id and user_id = auth.uid();
    end if;
    count_removed := count_removed + 1;
  end loop;
  if count_removed <> batch.row_count then raise exception 'Lote incompleto. Nenhum registro removido.'; end if;
  update public.finance_import_batches set status = 'undone', undone_at = now()
    where id = batch.id and user_id = auth.uid();
  return count_removed;
end;
$$;
revoke all on function public.undo_finance_import(uuid) from public, anon;
grant execute on function public.undo_finance_import(uuid) to authenticated;

notify pgrst, 'reload schema';
commit;
