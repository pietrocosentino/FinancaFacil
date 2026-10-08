-- Execute depois de recorrencia.sql. Não altera os lançamentos existentes.
begin;
alter table public.transactions add column if not exists notes text not null default '';
notify pgrst, 'reload schema';
commit;
