-- Executar uma vez no SQL Editor do Supabase antes de instalar esta versão.
-- Não altera nem apaga lançamentos antigos.
begin;
create table if not exists public.recurrence_rules (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  first_due date not null,
  due_day integer check (due_day between 1 and 31),
  total_installments integer check (total_installments between 2 and 1200),
  end_date date,
  template jsonb not null check (
    jsonb_typeof(template) = 'object' and
    template ? 'type' and template ? 'amount' and
    jsonb_typeof(template->'amount') = 'number' and
    template->>'category_id' is not null and template->>'description' is not null and
    template->>'type' in ('despesa','receita') and
    (template->>'amount')::numeric > 0 and
    template ? 'category_id' and template ? 'description'
  ),
  created_at timestamptz not null default now(),
  unique(id, user_id)
);
create table if not exists public.recurrence_occurrences (
  rule_id uuid not null,
  user_id uuid not null references auth.users(id) on delete cascade,
  due_month date not null check (extract(day from due_month) = 1),
  amount numeric check (amount > 0),
  is_paid boolean not null default false,
  primary key(rule_id, due_month),
  foreign key(rule_id, user_id) references public.recurrence_rules(id, user_id) on delete cascade
);
alter table public.recurrence_rules add column if not exists due_day integer check (due_day between 1 and 31);
alter table public.recurrence_rules enable row level security;
alter table public.recurrence_occurrences enable row level security;
drop policy if exists recurrence_rules_owner on public.recurrence_rules;
create policy recurrence_rules_owner on public.recurrence_rules
  for all to authenticated using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));
drop policy if exists recurrence_occurrences_owner on public.recurrence_occurrences;
create policy recurrence_occurrences_owner on public.recurrence_occurrences
  for all to authenticated using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));
grant select, insert, update on public.recurrence_rules to authenticated;
-- A RPC valida o período e preserva pagamento/valor; as permissões usam RLS.
grant select, insert, update on public.recurrence_occurrences to authenticated;
revoke all on public.recurrence_rules, public.recurrence_occurrences from anon;
create or replace function public.set_recurrence_occurrence(
  p_rule_id uuid, p_due_month date,
  p_is_paid boolean default null, p_amount numeric default null
) returns void language plpgsql security invoker set search_path = '' as $$
declare
  rule public.recurrence_rules;
  month_offset integer;
  due_date date;
  last_day integer;
begin
  if auth.uid() is null then raise exception 'Sessão expirada'; end if;
  select * into strict rule from public.recurrence_rules
    where id = p_rule_id and user_id = auth.uid() for update;
  if extract(day from p_due_month) <> 1 then raise exception 'Mês inválido'; end if;
  month_offset := (extract(year from p_due_month)::integer - extract(year from rule.first_due)::integer) * 12
    + extract(month from p_due_month)::integer - extract(month from rule.first_due)::integer;
  if month_offset < 0 or month_offset > 1200 or
    (rule.total_installments is not null and month_offset >= rule.total_installments)
    then raise exception 'Parcela fora do período'; end if;
  last_day := extract(day from (p_due_month + interval '1 month - 1 day'))::integer;
  due_date := p_due_month + (least(coalesce(rule.due_day, extract(day from rule.first_due)::integer), last_day) - 1);
  if rule.end_date is not null and due_date > rule.end_date and not (coalesce(p_is_paid = false, false) and p_amount is null and exists (select 1 from public.recurrence_occurrences where rule_id = p_rule_id and user_id = auth.uid() and due_month = p_due_month and is_paid)) then
    raise exception 'Recorrência encerrada';
  end if;
  if p_amount is not null and p_amount <= 0 then raise exception 'Valor inválido'; end if;
  insert into public.recurrence_occurrences(rule_id, user_id, due_month, amount, is_paid)
    values (p_rule_id, auth.uid(), p_due_month, p_amount, coalesce(p_is_paid, false))
    on conflict (rule_id, due_month) do update set
      amount = coalesce(p_amount, recurrence_occurrences.amount),
      is_paid = coalesce(p_is_paid, recurrence_occurrences.is_paid);
end;
$$;
revoke all on function public.set_recurrence_occurrence(uuid,date,boolean,numeric) from public, anon;
grant execute on function public.set_recurrence_occurrence(uuid,date,boolean,numeric) to authenticated;
notify pgrst, 'reload schema';
commit;
