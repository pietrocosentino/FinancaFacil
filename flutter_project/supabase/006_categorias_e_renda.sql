-- Categorias criadas pelo usuário e "Não recebi" para renda recorrente.
-- Executar após 005_excluir_lancamentos.sql. Não altera nem apaga dados.
begin;

-- Categorias próprias: user_id nulo continua significando categoria compartilhada.
alter table public.categories add column if not exists user_id uuid references auth.users(id) on delete cascade;

-- Política restritiva: soma-se às existentes e garante que ninguém veja ou
-- crie categorias de outra conta, qualquer que seja a política permissiva atual.
drop policy if exists categories_own_or_shared on public.categories;
create policy categories_own_or_shared on public.categories as restrictive
  for select to authenticated
  using (user_id is null or user_id = (select auth.uid()));
drop policy if exists categories_insert_own_restrict on public.categories;
create policy categories_insert_own_restrict on public.categories as restrictive
  for insert to authenticated
  with check (user_id = (select auth.uid()));
drop policy if exists categories_insert_own on public.categories;
create policy categories_insert_own on public.categories
  for insert to authenticated
  with check (user_id = (select auth.uid()));
grant insert on public.categories to authenticated;

do $$
declare
  sequence_name text := pg_get_serial_sequence('public.categories', 'id');
begin
  if sequence_name is not null then
    execute format('grant usage, select on sequence %s to authenticated', sequence_name);
  end if;
end $$;

-- Cria a categoria ou devolve a existente com o mesmo nome (sem diferenciar
-- maiúsculas). Converte o tipo para a coluna real (texto ou enum).
create or replace function public.create_category(p_name text, p_type text)
returns jsonb language plpgsql security invoker set search_path = '' as $$
declare
  clean_name text := regexp_replace(btrim(coalesce(p_name, '')), '\s+', ' ', 'g');
  existing public.categories;
  created public.categories;
begin
  if auth.uid() is null then raise exception 'Sua sessão terminou. Entre novamente.'; end if;
  if p_type is null or p_type not in ('EXPENSE','INCOME') then raise exception 'Tipo de categoria inválido.'; end if;
  if length(clean_name) not between 2 and 40 then raise exception 'Use um nome de categoria com 2 a 40 caracteres.'; end if;
  select * into existing from public.categories c
    where c.transaction_type::text = p_type and lower(c.name) = lower(clean_name)
      and (c.user_id is null or c.user_id = auth.uid())
    order by c.user_id nulls first limit 1;
  if found then return jsonb_build_object('id', existing.id::text, 'name', existing.name); end if;
  created := jsonb_populate_record(null::public.categories,
    jsonb_build_object('name', clean_name, 'transaction_type', p_type, 'user_id', auth.uid()));
  insert into public.categories(name, transaction_type, user_id)
    values (created.name, created.transaction_type, auth.uid())
    returning * into created;
  return jsonb_build_object('id', created.id::text, 'name', created.name);
end;
$$;
revoke all on function public.create_category(text, text) from public, anon;
grant execute on function public.create_category(text, text) to authenticated;

-- Renda recorrente é considerada recebida na data. "Não recebi" passa aquele
-- mês para confirmação manual, como uma conta: fica pendente até confirmar.
alter table public.recurrence_occurrences add column if not exists manual_receipt boolean not null default false;

create or replace function public.set_income_not_received(p_rule_id uuid, p_due_month date)
returns void language plpgsql security invoker set search_path = '' as $$
declare
  rule public.recurrence_rules;
  month_offset integer;
begin
  if auth.uid() is null then raise exception 'Sessão expirada'; end if;
  select * into strict rule from public.recurrence_rules
    where id = p_rule_id and user_id = auth.uid() for update;
  if rule.template->>'type' <> 'receita' then raise exception 'Somente rendas podem ser marcadas como não recebidas.'; end if;
  if p_due_month is null or extract(day from p_due_month) <> 1 then raise exception 'Mês inválido'; end if;
  month_offset := (extract(year from p_due_month)::integer - extract(year from rule.first_due)::integer) * 12
    + extract(month from p_due_month)::integer - extract(month from rule.first_due)::integer;
  if month_offset < 0 or month_offset > 1200 or
    (rule.total_installments is not null and month_offset >= rule.total_installments) or
    (rule.end_date is not null and p_due_month > rule.end_date)
    then raise exception 'Parcela fora do período'; end if;
  insert into public.recurrence_occurrences(rule_id, user_id, due_month, is_paid, manual_receipt)
    values (p_rule_id, auth.uid(), p_due_month, false, true)
    on conflict (rule_id, due_month) do update set is_paid = false, manual_receipt = true;
end;
$$;
revoke all on function public.set_income_not_received(uuid, date) from public, anon;
grant execute on function public.set_income_not_received(uuid, date) to authenticated;

notify pgrst, 'reload schema';
commit;
