import {PGlite} from '@electric-sql/pglite';
import fs from 'node:fs/promises';

const scripts = new URL('../../flutter_project/supabase/', import.meta.url);

/** Migrações na ordem de aplicação documentada em supabase/README.md. */
export const migrations = [
  'recorrencia.sql',
  'editar_valores.sql',
  'importacao_mvp2.sql',
  'excluir_lancamentos.sql',
];

export const owner = '11111111-1111-4111-8111-111111111111';
export const other = '22222222-2222-4222-8222-222222222222';

export const readMigration = file => fs.readFile(new URL(file, scripts), 'utf8');

/**
 * Banco PostgreSQL em memória com o esquema base do Supabase (auth, categorias
 * e lançamentos com RLS) e as migrações do app aplicadas.
 * `integerIds` simula bancos com IDs inteiros em vez de UUID.
 */
export async function createDatabase(integerIds) {
  const db = new PGlite();
  const category = integerIds ? '1' : '33333333-3333-4333-8333-333333333333';
  const privateCategory = integerIds ? '2' : '44444444-4444-4444-8444-444444444444';
  const categoryType = integerIds ? 'bigint' : 'uuid';
  const idColumn = integerIds ? 'bigserial' : 'uuid default gen_random_uuid()';
  await db.exec(`
    create role anon; create role authenticated;
    create schema auth;
    create table auth.users(id uuid primary key);
    insert into auth.users values('${owner}'),('${other}');
    create function auth.uid() returns uuid language sql stable as
      $$ select nullif(current_setting('request.jwt.claim.sub', true),'')::uuid $$;
    grant usage on schema auth to authenticated;
    create table public.categories(id ${categoryType} primary key,name text not null,
      transaction_type text not null,user_id uuid);
    insert into categories values('${category}','Moradia','EXPENSE',null),
      ('${privateCategory}','Privada','EXPENSE','${other}');
    create table public.transactions(id ${idColumn} primary key,
      user_id uuid not null references auth.users(id), type text not null,
      amount numeric not null check(amount > 0),description text not null,notes text,
      category_id ${categoryType} not null references categories(id),due_date date not null,
      is_recurrent boolean not null default false,is_paid boolean not null default false,
      created_at timestamptz not null default now());
    alter table categories enable row level security;
    create policy category_visible on categories for select to authenticated
      using(user_id is null or user_id=auth.uid());
    alter table transactions enable row level security;
    create policy transaction_owner on transactions for all to authenticated
      using(user_id=auth.uid()) with check(user_id=auth.uid());
    grant select on categories to authenticated;
    grant select,insert,update on transactions to authenticated;
    grant usage,select on all sequences in schema public to authenticated;
  `);
  for (const file of migrations) await db.exec(await readMigration(file));
  const account = id =>
    db.query("select set_config('request.jwt.claim.sub',$1,false)", [id]);
  return {db, category, privateCategory, account};
}
