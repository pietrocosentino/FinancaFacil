-- Executar após 001_recorrencia.sql. Exclusão de um mês não apaga a regra.
begin;
alter table public.recurrence_occurrences add column if not exists is_deleted boolean not null default false;
create or replace function public.delete_finance_entry(p_entry_id text)
returns void language plpgsql security definer set search_path = '' as $$
declare
  owner uuid := auth.uid();
  parts text[];
  rule public.recurrence_rules;
  month_date date;
  offset_month integer;
  changed integer;
begin
  if owner is null then raise exception 'Sessão expirada'; end if;
  if p_entry_id is null or length(p_entry_id) > 200 then raise exception 'Registro inválido'; end if;
  if left(p_entry_id,2) = 'r:' then
    parts := string_to_array(p_entry_id, ':');
    if array_length(parts,1) <> 3 or parts[3] !~ '^[0-9]{4}-[0-9]{2}-01$' then
      raise exception 'Mês inválido';
    end if;
    month_date := parts[3]::date;
    select * into strict rule from public.recurrence_rules
      where id = parts[2]::uuid and user_id = owner for update;
    offset_month := (extract(year from month_date)::integer - extract(year from rule.first_due)::integer)*12
      + extract(month from month_date)::integer - extract(month from rule.first_due)::integer;
    if offset_month < 0 or offset_month > 1200 or
      (rule.total_installments is not null and offset_month >= rule.total_installments) then
      raise exception 'Parcela fora do período';
    end if;
    insert into public.recurrence_occurrences(rule_id,user_id,due_month,is_paid,is_deleted)
      values(rule.id,owner,month_date,false,true)
      on conflict(rule_id,due_month) do update set is_deleted=true,is_paid=false;
  else
    delete from public.transactions where id::text = p_entry_id and user_id = owner;
    get diagnostics changed = row_count;
    if changed <> 1 then raise exception 'Registro não encontrado'; end if;
  end if;
end;
$$;
revoke all on function public.delete_finance_entry(text) from public,anon;
grant execute on function public.delete_finance_entry(text) to authenticated;
-- Encerrar novamente nunca prolonga uma regra já encerrada.
create or replace function public.stop_finance_plan(p_rule_id uuid)
returns void language plpgsql security invoker set search_path = '' as $$
declare
  rule public.recurrence_rules;
  month_end date := (date_trunc('month', timezone('America/Sao_Paulo', now())) + interval '1 month - 1 day')::date;
begin
  if auth.uid() is null then raise exception 'Sessão expirada'; end if;
  select * into strict rule from public.recurrence_rules
    where id = p_rule_id and user_id = auth.uid() for update;
  update public.recurrence_rules set end_date = least(coalesce(rule.end_date, month_end), month_end)
    where id = p_rule_id and user_id = auth.uid();
end;
$$;
revoke all on function public.stop_finance_plan(uuid) from public,anon;
grant execute on function public.stop_finance_plan(uuid) to authenticated;
notify pgrst, 'reload schema';
commit;
