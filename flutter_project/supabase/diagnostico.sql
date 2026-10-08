-- Somente leitura. Execute no SQL Editor para verificar o banco existente.
select table_name, column_name, data_type, udt_name, is_nullable, column_default
from information_schema.columns
where table_schema = 'public' and table_name in ('transactions', 'categories', 'recurrence_rules', 'recurrence_occurrences')
order by table_name, ordinal_position;

select tablename, policyname, roles, cmd, qual, with_check
from pg_policies
where schemaname = 'public' and tablename in ('transactions', 'categories', 'recurrence_rules', 'recurrence_occurrences');

select relname, relrowsecurity, relforcerowsecurity
from pg_class join pg_namespace on pg_namespace.oid = pg_class.relnamespace
where nspname = 'public' and relname in ('transactions', 'categories', 'recurrence_rules', 'recurrence_occurrences');

select conname, pg_get_constraintdef(oid)
from pg_constraint
where conrelid in (to_regclass('public.transactions'), to_regclass('public.categories'),
    to_regclass('public.recurrence_rules'), to_regclass('public.recurrence_occurrences'));

-- A ausência destas funções impede confirmações e ajustes de recorrências.
select routine_name, security_type, data_type
from information_schema.routines
where routine_schema = 'public'
  and routine_name in ('set_recurrence_occurrence', 'set_recurrence_future_amount')
order by routine_name;

select table_name, grantee, privilege_type
from information_schema.role_table_grants
where table_schema = 'public'
  and table_name in ('transactions', 'categories', 'recurrence_rules', 'recurrence_occurrences')
  and grantee in ('authenticated', 'anon')
order by table_name, grantee, privilege_type;
