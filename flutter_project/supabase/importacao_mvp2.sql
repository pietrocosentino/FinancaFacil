-- Aplicar após recorrencia.sql, lembretes.sql e editar_valores.sql.
-- Pressupõe categories e transactions existentes, com RLS e permissões corretas.
-- Não modifica lançamentos antigos nem políticas das tabelas financeiras base.
begin;

create table if not exists public.finance_import_batches (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  file_name text not null check (length(file_name) between 1 and 255),
  file_hash text not null check (file_hash ~ '^[a-f0-9]{64}$'),
  row_count integer not null check (row_count between 1 and 500),
  status text not null default 'active' check (status in ('active','undone')),
  created_at timestamptz not null default now(),
  undone_at timestamptz,
  unique(id, user_id)
);
create unique index if not exists finance_import_active_file
  on public.finance_import_batches(user_id, file_hash) where status = 'active';
create table if not exists public.finance_import_items (
  batch_id uuid not null,
  user_id uuid not null references auth.users(id) on delete cascade,
  source_line integer not null check (source_line between 2 and 10000),
  record_kind text not null check (record_kind in ('transaction','rule')),
  record_id text not null,
  original_record jsonb not null,
  primary key(batch_id, source_line),
  foreign key(batch_id,user_id) references public.finance_import_batches(id,user_id) on delete cascade
);
alter table public.finance_import_batches enable row level security;
alter table public.finance_import_items enable row level security;
drop policy if exists finance_import_batches_owner on public.finance_import_batches;
create policy finance_import_batches_owner on public.finance_import_batches
  for all to authenticated using(user_id = (select auth.uid())) with check(user_id = (select auth.uid()));
drop policy if exists finance_import_items_owner on public.finance_import_items;
create policy finance_import_items_owner on public.finance_import_items
  for all to authenticated using(user_id = (select auth.uid())) with check(user_id = (select auth.uid()));
grant select, insert on public.finance_import_batches, public.finance_import_items to authenticated;
revoke all on public.finance_import_batches, public.finance_import_items from anon;

create or replace function public.preview_finance_import(p_rows jsonb)
returns jsonb language plpgsql security invoker set search_path = '' as $$
declare
  item jsonb;
  matches jsonb := '[]'::jsonb;
begin
  if auth.uid() is null then raise exception 'Sua sessão terminou. Entre novamente.'; end if;
  if p_rows is null or jsonb_typeof(p_rows) <> 'array' then raise exception 'Lote inválido.'; end if;
  if jsonb_array_length(p_rows) > 500 then raise exception 'Importe até 500 linhas.'; end if;
  for item in select value from jsonb_array_elements(p_rows) loop
    if coalesce((item->>'recurring')::boolean, false) then
      if exists(select 1 from public.recurrence_rules r
          where r.user_id = auth.uid() and r.first_due = (item->>'due_date')::date
          and r.template->>'type' = item->>'type'
          and lower(btrim(r.template->>'description')) = lower(btrim(item->>'description'))
          and (r.template->>'amount')::numeric = (item->>'amount')::numeric
          and r.template->>'category_id' = item->>'category_id'
          and coalesce(r.due_day, extract(day from r.first_due)::integer) = (item->>'due_day')::integer
          and r.total_installments is not distinct from (item->>'months')::integer) then
        matches := matches || jsonb_build_array((item->>'line')::integer);
      end if;
    else
      if exists(select 1 from public.transactions t
          where t.user_id = auth.uid() and t.due_date = (item->>'due_date')::date
          and t.type::text = item->>'type' and t.amount = (item->>'amount')::numeric
          and lower(btrim(t.description)) = lower(btrim(item->>'description'))
          and t.category_id::text = item->>'category_id') then
        matches := matches || jsonb_build_array((item->>'line')::integer);
      end if;
    end if;
  end loop;
  return matches;
end;
$$;

create or replace function public.import_finance_batch(
  p_file_name text, p_file_hash text, p_rows jsonb, p_allow_similar boolean default false
) returns jsonb language plpgsql security invoker set search_path = '' as $$
declare
  batch public.finance_import_batches;
  item jsonb;
  transaction_row public.transactions;
  rule public.recurrence_rules;
  value_amount numeric;
  first_due date;
  requested_day integer;
  count_months integer;
  last_day integer;
  is_recurring boolean;
  expected_category_type text;
  snapshot jsonb;
  record_id text;
  record_kind text;
  selected_lines integer[] := '{}';
begin
  if auth.uid() is null then raise exception 'Sua sessão terminou. Entre novamente.'; end if;
  if p_file_name is null or length(btrim(p_file_name)) not between 1 and 255 or
      p_file_hash is null or p_file_hash !~ '^[a-f0-9]{64}$' then
    raise exception 'Identificação do arquivo inválida.';
  end if;
  if p_rows is null or jsonb_typeof(p_rows) <> 'array' then raise exception 'Lote inválido.'; end if;
  if jsonb_array_length(p_rows) not between 1 and 500 then raise exception 'Selecione entre 1 e 500 linhas.'; end if;
  -- Serializa importações da mesma conta, inclusive arquivos distintos.
  perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text || ':finance-import', 0));
  select * into batch from public.finance_import_batches
    where user_id = auth.uid() and file_hash = p_file_hash and status = 'active';
  if found then return jsonb_build_object('batch_id', batch.id, 'count', batch.row_count, 'already_imported', true); end if;

  insert into public.finance_import_batches(user_id,file_name,file_hash,row_count)
    values(auth.uid(), btrim(p_file_name), p_file_hash, jsonb_array_length(p_rows)) returning * into batch;
  for item in select value from jsonb_array_elements(p_rows) loop
    if jsonb_typeof(item) is distinct from 'object' or jsonb_typeof(item->'amount') is distinct from 'number' or
        jsonb_typeof(item->'recurring') is distinct from 'boolean' or
        item->>'type' is null or item->>'type' not in ('receita','despesa') or
        item->>'description' is null or length(btrim(item->>'description')) not between 1 and 160 or
        length(coalesce(item->>'notes','')) > 1000 or
        item->>'due_date' is null or item->>'due_date' !~ '^\d{4}-\d{2}-\d{2}$' or
        item->>'category_id' is null or item->>'due_day' is null or item->>'line' is null then
      raise exception 'Linha inválida. Confira descrição, tipo, valor e vencimento.';
    end if;
    if (item->>'line')::integer not between 2 and 10000 or (item->>'line')::integer = any(selected_lines) then
      raise exception 'Numeração de linhas inválida.';
    end if;
    selected_lines := array_append(selected_lines, (item->>'line')::integer);
    value_amount := (item->>'amount')::numeric;
    first_due := (item->>'due_date')::date;
    requested_day := (item->>'due_day')::integer;
    count_months := (item->>'months')::integer;
    is_recurring := (item->>'recurring')::boolean;
    if value_amount <= 0 or value_amount > 999999999.99 or value_amount <> round(value_amount,2) or
        value_amount::text in ('NaN','Infinity','-Infinity') or
        extract(year from first_due) not between 2020 and 2100 or
        requested_day not between 1 and 31 or
        (count_months is not null and (not is_recurring or count_months not between 2 and 1200)) then
      raise exception 'Valor, data ou quantidade de meses inválida.';
    end if;
    last_day := extract(day from (date_trunc('month',first_due) + interval '1 month - 1 day'))::integer;
    if (is_recurring and extract(day from first_due) <> least(requested_day,last_day)) or
        (not is_recurring and extract(day from first_due) <> requested_day) then
      raise exception 'Primeiro vencimento não corresponde ao dia escolhido.';
    end if;
    expected_category_type := case when item->>'type' = 'receita' then 'INCOME' else 'EXPENSE' end;
    -- SECURITY INVOKER: só associa categorias visíveis pelas políticas existentes.
    if not exists(select 1 from public.categories c where c.id::text = item->>'category_id'
        and c.transaction_type::text = expected_category_type) then
      raise exception 'Categoria indisponível ou incompatível com o tipo.';
    end if;
    if not coalesce(p_allow_similar,false) and
        jsonb_array_length(public.preview_finance_import(jsonb_build_array(item))) > 0 then
      raise exception 'Encontramos um lançamento semelhante. Refaça a prévia e confirme se deseja incluir duplicatas.';
    end if;
    if is_recurring then
      insert into public.recurrence_rules(user_id,first_due,due_day,total_installments,template)
        values(auth.uid(), first_due, requested_day, count_months,
          jsonb_build_object('type',item->>'type','amount',value_amount,
            'description',btrim(item->>'description'),'notes',btrim(coalesce(item->>'notes','')),
            'category_id',item->>'category_id')) returning * into rule;
      record_id := rule.id::text; record_kind := 'rule'; snapshot := to_jsonb(rule);
    else
      -- Converte para os tipos reais de type/category_id, sem presumir UUID ou inteiro.
      transaction_row := jsonb_populate_record(null::public.transactions,
          jsonb_build_object('type',item->>'type','category_id',item->>'category_id'));
      insert into public.transactions(user_id,type,amount,description,notes,category_id,due_date,is_recurrent,is_paid,created_at)
        values(auth.uid(),transaction_row.type,value_amount,btrim(item->>'description'),
          btrim(coalesce(item->>'notes','')),transaction_row.category_id,first_due,false,false,now())
          returning * into transaction_row;
      record_id := transaction_row.id::text; record_kind := 'transaction'; snapshot := to_jsonb(transaction_row);
    end if;
    insert into public.finance_import_items(batch_id,user_id,source_line,record_kind,record_id,original_record)
      values(batch.id,auth.uid(),(item->>'line')::integer,record_kind,record_id,snapshot);
  end loop;
  return jsonb_build_object('batch_id',batch.id,'count',batch.row_count,'already_imported',false);
end;
$$;

-- Exclusão restrita aos registros originais do lote da conta autenticada.
-- Não concede DELETE geral às tabelas financeiras.
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
      if not found or transaction_row.is_paid or to_jsonb(transaction_row) <> item.original_record then
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
revoke all on function public.preview_finance_import(jsonb) from public, anon;
revoke all on function public.import_finance_batch(text,text,jsonb,boolean) from public, anon;
revoke all on function public.undo_finance_import(uuid) from public, anon;
grant execute on function public.preview_finance_import(jsonb) to authenticated;
grant execute on function public.import_finance_batch(text,text,jsonb,boolean) to authenticated;
grant execute on function public.undo_finance_import(uuid) to authenticated;
notify pgrst, 'reload schema';
commit;
