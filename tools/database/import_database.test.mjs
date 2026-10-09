import {PGlite} from '@electric-sql/pglite';
import fs from 'node:fs/promises';
import assert from 'node:assert/strict';

const scripts = new URL('../../flutter_project/supabase/', import.meta.url);
let checks = 0;
async function scenario(integerIds) {
  const db = new PGlite();
  const owner = '11111111-1111-4111-8111-111111111111';
  const other = '22222222-2222-4222-8222-222222222222';
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
  for (const file of ['recorrencia.sql','editar_valores.sql','importacao_mvp2.sql','excluir_lancamentos.sql']) {
    await db.exec(await fs.readFile(new URL(file,scripts),'utf8'));
  }
  // Idempotência da própria migração.
  await db.exec(await fs.readFile(new URL('importacao_mvp2.sql',scripts),'utf8'));
  await db.exec('set role authenticated');
  const account = (id) => db.query("select set_config('request.jwt.claim.sub',$1,false)",[id]);
  await account(owner);
  const row = (line, overrides={}) => ({line,description:'Aluguel',type:'despesa',amount:1500,
    due_date:'2026-11-10',due_day:10,recurring:true,months:null,category_id:category,notes:'',...overrides});
  let key = 0;
  const hash = () => (++key).toString(16).padStart(64,'0');
  const save = async (rows,fileHash=hash(),allow=false) => (await db.query(
    'select public.import_finance_batch($1,$2,$3::jsonb,$4) as receipt',
    ['contas.xlsx',fileHash,JSON.stringify(rows),allow])).rows[0].receipt;
  const preview = async rows => (await db.query('select public.preview_finance_import($1::jsonb) as lines',
    [JSON.stringify(rows)])).rows[0].lines;
  const undo = async id => (await db.query('select public.undo_finance_import($1::uuid) as count',[id])).rows[0].count;
  const counts = async () => (await db.query(`select
    (select count(*)::int from transactions) as transactions,
    (select count(*)::int from recurrence_rules) as rules,
    (select count(*)::int from finance_import_batches) as batches`)).rows[0];
  function equal(actual,expected) { assert.deepEqual(actual,expected);checks++; }
  async function rejects(action,pattern) { await assert.rejects(action,pattern);checks++; }

  const fixedHash=hash();
  const imported=await save([row(2),row(3,{description:'Ótica',amount:90.6,months:10}),
    row(4,{description:'Conta avulsa',amount:50,recurring:false})],fixedHash);
  equal(imported.count,3);
  equal((await counts()).rules,2);
  equal((await counts()).transactions,1);
  equal((await db.query('select total_installments from recurrence_rules order by total_installments nulls first')).rows,
    [{total_installments:null},{total_installments:10}]);
  equal((await db.query('select count(*)::int as n from recurrence_occurrences')).rows[0].n,0);
  equal((await db.query('select bool_or(is_paid) as paid from transactions')).rows[0].paid,false);
  const retried=await save([row(2)],fixedHash);
  equal(retried.already_imported,true);
  equal(retried.batch_id,imported.batch_id);
  equal(await preview([row(2)]),[2]);
  const before=await counts();
  await rejects(()=>save([row(2)]),/semelhante/);
  equal(await counts(),before);
  // A última linha inválida reverte inclusive a primeira e os metadados do lote.
  await rejects(()=>save([row(2,{description:'Nova conta',recurring:false}),row(3,{amount:0})]),/inválid/);
  equal(await counts(),before);
  await rejects(()=>save([row(2,{category_id:privateCategory})]),/Categoria/);
  equal(await counts(),before);
  await rejects(()=>save([row(2,{type:'receita'})]),/Categoria/);
  await rejects(()=>save([row(2,{months:1})]),/inválid/);
  await rejects(()=>save([row(2,{amount:90.601})]),/inválid/);
  await rejects(()=>save([row(2,{due_day:8})]),/corresponde/);
  const missingRecurring=row(2,{description:'Sem recorrência informada'});
  delete missingRecurring.recurring;
  await rejects(()=>save([missingRecurring]),/Linha inválida/);
  const missingAmount=row(2,{description:'Sem valor informado'});
  delete missingAmount.amount;
  await rejects(()=>save([missingAmount]),/Linha inválida/);
  const deliberate=await save([row(2)],hash(),true);
  equal(deliberate.count,1);
  equal(await undo(deliberate.batch_id),1);
  equal(await undo(deliberate.batch_id),0);
  const disposableHash=hash();
  const disposable=await save([row(2,{description:'Descartável',recurring:false})],disposableHash);
  equal(await undo(disposable.batch_id),1);
  equal((await save([row(2,{description:'Descartável',recurring:false})],disposableHash)).already_imported,false);

  // Um pagamento protege o lote inteiro, inclusive as regras ainda pendentes.
  await db.exec("update transactions set is_paid=true where description='Conta avulsa'");
  await rejects(()=>undo(imported.batch_id),/preservado/);
  equal((await counts()).rules,before.rules);
  await db.exec("update transactions set is_paid=false where description='Conta avulsa'");
  const ruleId=(await db.query("select id from recurrence_rules where template->>'description'='Aluguel'")).rows[0].id;
  await db.query('select public.set_recurrence_occurrence($1::uuid,$2::date,true,null)',[ruleId,'2026-11-01']);
  await rejects(()=>undo(imported.batch_id),/preservado/);
  equal((await counts()).rules,before.rules);
  const edited=await save([row(2,{description:'Corrigida',recurring:false})]);
  await db.exec("update transactions set amount=1600 where description='Corrigida'");
  await rejects(()=>undo(edited.batch_id),/preservado/);
  const disposableId=(await db.query("select id::text from transactions where description='Descartável'")).rows[0].id;
  const remove = id => db.query('select public.delete_finance_entry($1)',[id]);
  await account(other);
  await rejects(()=>db.query('select public.stop_finance_plan($1::uuid)',[ruleId]),/no rows/);
  await rejects(()=>remove(disposableId),/não encontrado/);
  await rejects(()=>remove(`r:${ruleId}:2026-11-01`),/no rows/);
  await account(owner);
  await remove(disposableId);
  equal((await db.query('select count(*)::int as n from transactions where id::text=$1',[disposableId])).rows[0].n,0);
  await rejects(()=>remove(disposableId),/não encontrado/);
  await remove(`r:${ruleId}:2026-11-01`);
  equal((await db.query('select is_deleted,is_paid from recurrence_occurrences where rule_id=$1',[ruleId])).rows[0],{is_deleted:true,is_paid:false});
  equal((await db.query('select count(*)::int as n from recurrence_rules where id=$1',[ruleId])).rows[0].n,1);
  await remove(`r:${ruleId}:2026-11-01`);
  equal((await db.query('select count(*)::int as n from recurrence_occurrences where rule_id=$1',[ruleId])).rows[0].n,1);
  await rejects(()=>remove(`r:${ruleId}:2026-10-01`),/fora do período/);
  await rejects(()=>remove(`r:${ruleId}:2026-11-02`),/Mês inválido/);
  await rejects(()=>undo(imported.batch_id),/preservado/);
  await db.query("update recurrence_rules set end_date='2025-01-31' where id=$1",[ruleId]);
  await db.query('select public.stop_finance_plan($1::uuid)',[ruleId]);
  equal((await db.query('select end_date::text from recurrence_rules where id=$1',[ruleId])).rows[0].end_date,'2025-01-31');
  // Segunda conta não vê os lotes nem pode desfazer lote da primeira.
  await account(other);
  equal(await counts(),{transactions:0,rules:0,batches:0});
  await rejects(()=>undo(imported.batch_id),/no rows/);
  equal(await preview([row(2)]),[]);
  equal((await save([row(2)],fixedHash)).already_imported,false);
  await account('');
  await rejects(()=>remove(disposableId),/Sessão expirada/);
  await rejects(()=>save([row(2)]),/sessão/);
  await db.close();
}
await scenario(false);
await scenario(true);
console.log(`${checks} verificações PostgreSQL passaram (IDs UUID e inteiro).`);
