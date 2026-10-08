-- Execute após recorrencia.sql e lembretes.sql.
begin;
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
  if p_from_month is null or extract(day from p_from_month) <> 1 or p_from_month < date_trunc('month', current_date)::date then raise exception 'Escolha o mês atual ou um mês futuro'; end if;
  if p_amount is null or p_amount <= 0 or p_amount::text in ('NaN','Infinity','-Infinity') then raise exception 'Valor inválido'; end if;
  select * into strict rule from public.recurrence_rules where id = p_rule_id and user_id = auth.uid() for update;
  offset_month := (extract(year from p_from_month)::integer - extract(year from rule.first_due)::integer) * 12 + extract(month from p_from_month)::integer - extract(month from rule.first_due)::integer;
  if offset_month < 0 or offset_month > 1200 or (rule.total_installments is not null and offset_month >= rule.total_installments) or (rule.end_date is not null and p_from_month > rule.end_date) then raise exception 'Mês fora do período'; end if;
  -- Preserva valores já confirmados, sem criar parcelas antecipadamente.
  for paid in select * from public.recurrence_occurrences where rule_id = p_rule_id and user_id = auth.uid() and due_month >= p_from_month and is_paid and amount is null for update loop
    previous_amount := (rule.template->>'amount')::numeric;
    for scheduled in select value from jsonb_array_elements(coalesce(rule.template->'future_amounts', '[]'::jsonb)) order by value->>'from_month' loop
      if (scheduled->>'from_month')::date <= paid.due_month then previous_amount := (scheduled->>'amount')::numeric; end if;
    end loop;
    update public.recurrence_occurrences set amount = previous_amount where rule_id = p_rule_id and user_id = auth.uid() and due_month = paid.due_month;
  end loop;
  update public.recurrence_occurrences set amount = null where rule_id = p_rule_id and user_id = auth.uid() and due_month >= p_from_month and not is_paid;
  select coalesce(jsonb_agg(value order by value->>'from_month'), '[]'::jsonb) into changes from jsonb_array_elements(coalesce(rule.template->'future_amounts','[]'::jsonb)) where (value->>'from_month')::date < p_from_month;
  changes := changes || jsonb_build_array(jsonb_build_object('from_month', p_from_month, 'amount', p_amount));
  update public.recurrence_rules set template = jsonb_set(template, '{future_amounts}', changes) where id = p_rule_id and user_id = auth.uid();
end;
$$;
revoke all on function public.set_recurrence_future_amount(uuid,date,numeric) from public, anon;
grant execute on function public.set_recurrence_future_amount(uuid,date,numeric) to authenticated;
notify pgrst, 'reload schema';
commit;
