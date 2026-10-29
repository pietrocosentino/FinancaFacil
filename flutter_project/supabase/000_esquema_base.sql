-- Esquema base: categorias e lançamentos avulsos.
-- Em um banco que já tem essas tabelas, nada é alterado: as tabelas usam
-- "if not exists" e as políticas só são criadas quando a tabela não tem
-- nenhuma. Em um projeto Supabase novo, cria tudo o que o app precisa.
begin;

create table if not exists public.categories (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(btrim(name)) between 1 and 60),
  transaction_type text not null check (transaction_type in ('EXPENSE','INCOME')),
  user_id uuid references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

create table if not exists public.transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  type text not null check (type in ('despesa','receita')),
  amount numeric(12,2) not null check (amount > 0),
  description text not null,
  notes text not null default '',
  category_id uuid not null references public.categories(id),
  due_date date not null,
  is_recurrent boolean not null default false,
  is_paid boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists transactions_user_due on public.transactions(user_id, due_date);

alter table public.categories enable row level security;
alter table public.transactions enable row level security;

do $$
begin
  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'categories') then
    create policy categories_visible on public.categories for select to authenticated
      using (user_id is null or user_id = (select auth.uid()));
  end if;
  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'transactions') then
    create policy transactions_owner on public.transactions for all to authenticated
      using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
  end if;
end $$;

grant select on public.categories to authenticated;
grant select, insert, update on public.transactions to authenticated;
revoke all on public.categories, public.transactions from anon;

-- Categorias padrão, compartilhadas (user_id nulo), somente em banco vazio.
insert into public.categories(name, transaction_type)
select name, kind from (values
  ('Moradia','EXPENSE'), ('Alimentação','EXPENSE'), ('Transporte','EXPENSE'),
  ('Saúde','EXPENSE'), ('Educação','EXPENSE'), ('Lazer','EXPENSE'),
  ('Contas e serviços','EXPENSE'), ('Compras','EXPENSE'), ('Outras despesas','EXPENSE'),
  ('Salário','INCOME'), ('Renda extra','INCOME'), ('Investimentos','INCOME'),
  ('Outras receitas','INCOME')
) as defaults(name, kind)
where not exists (select 1 from public.categories);

notify pgrst, 'reload schema';
commit;
