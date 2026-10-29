// Categorias próprias, "Não recebi" e criação de um projeto novo do zero.
import assert from 'node:assert/strict';
import {createDatabase, createFreshDatabase, other, owner, readMigration} from './schema.mjs';

let checks = 0;
const equal = (actual, expected) => { assert.deepEqual(actual, expected); checks++; };
const rejects = async (action, pattern) => { await assert.rejects(action, pattern); checks++; };

async function categories(integerIds) {
  const {db, account} = await createDatabase(integerIds);
  // Simula uma política antiga permissiva demais: a restritiva deve prevalecer.
  await db.exec(`create policy legacy_all on public.categories for select to authenticated using (true);
    create policy legacy_insert on public.categories for insert to authenticated with check (true);`);
  await db.exec('set role authenticated');
  const create = (name, type = 'EXPENSE') => db.query(
    'select public.create_category($1,$2) as category', [name, type]).then(r => r.rows[0].category);
  const visible = async () => (await db.query(
    'select name from categories order by name')).rows.map(r => r.name);

  await account(owner);
  equal(await visible(), ['Moradia']);
  const pet = await create('  Pet   shop ');
  equal(pet.name, 'Pet shop');
  equal((await create('PET SHOP')).id, pet.id);
  const shared = await create('moradia');
  equal(shared.name, 'Moradia');
  equal((await create('Pet shop', 'INCOME')).id === pet.id, false);
  await rejects(() => create('x'), /2 a 40/);
  await rejects(() => create('a'.repeat(41)), /2 a 40/);
  await rejects(() => create('Viagem', 'outro'), /Tipo/);
  await rejects(() => db.query(
    "insert into categories(name, transaction_type, user_id) values('Intrusa','EXPENSE',$1)", [other]),
    /row-level security/);
  equal(await visible(), ['Moradia', 'Pet shop', 'Pet shop']);

  await account(other);
  equal(await visible(), ['Moradia', 'Privada']);
  equal((await create('Pet shop')).id === pet.id, false);
  await account('');
  await rejects(() => create('Sem sessão'), /sessão/);
  await db.exec('reset role; set role anon');
  await rejects(() => create('Anônimo'), /permission denied/);
  await db.close();
}

async function notReceived() {
  const {db, category, account} = await createDatabase(false);
  await db.exec('set role authenticated');
  await account(owner);
  const rule = async (type, fields = {}) => (await db.query(
    `insert into recurrence_rules(user_id, first_due, due_day, total_installments, end_date, template)
     values($1, '2026-01-05', 5, $2, $3, $4::jsonb) returning id`,
    [owner, fields.total ?? null, fields.end ?? null, JSON.stringify({type, amount: 3000,
      description: 'Salário', notes: '', category_id: category})])).rows[0].id;
  const notReceived = (id, month) => db.query(
    'select public.set_income_not_received($1::uuid,$2::date)', [id, month]);
  const occurrence = async (id, month) => (await db.query(
    'select is_paid, manual_receipt from recurrence_occurrences where rule_id=$1 and due_month=$2',
    [id, month])).rows[0];

  const salary = await rule('receita');
  await notReceived(salary, '2026-03-01');
  equal(await occurrence(salary, '2026-03-01'), {is_paid: false, manual_receipt: true});
  await db.query("select public.set_recurrence_occurrence($1::uuid,'2026-03-01'::date,true,null)", [salary]);
  equal(await occurrence(salary, '2026-03-01'), {is_paid: true, manual_receipt: true});
  await notReceived(salary, '2026-03-01');
  equal(await occurrence(salary, '2026-03-01'), {is_paid: false, manual_receipt: true});
  equal(await occurrence(salary, '2026-04-01'), undefined);

  await rejects(async () => notReceived(await rule('despesa'), '2026-03-01'), /Somente rendas/);
  await rejects(() => notReceived(salary, '2025-12-01'), /fora do período/);
  await rejects(() => notReceived(salary, '2026-03-02'), /Mês inválido/);
  const ended = await rule('receita', {end: '2026-02-28'});
  await rejects(() => notReceived(ended, '2026-03-01'), /fora do período/);
  const limited = await rule('receita', {total: 3});
  await rejects(() => notReceived(limited, '2026-04-01'), /fora do período/);

  await account(other);
  await rejects(() => notReceived(salary, '2026-05-01'), /no rows/);
  await db.exec('reset role; set role anon');
  await rejects(() => notReceived(salary, '2026-05-01'), /permission denied/);
  await db.close();
}

async function freshProject() {
  const {db, account} = await createFreshDatabase();
  // Executar o esquema base de novo não duplica categorias nem políticas.
  await db.exec(await readMigration('000_esquema_base.sql'));
  await db.exec(await readMigration('006_categorias_e_renda.sql'));
  const policies = async () => (await db.query(
    "select count(*)::int as n from pg_policies where tablename in ('categories','transactions')")).rows[0].n;
  equal(await policies(), 5);
  await db.exec('set role authenticated');
  await account(owner);
  const shared = (await db.query('select id, name, transaction_type from categories')).rows;
  equal(shared.length, 13);
  const housing = shared.find(c => c.name === 'Moradia').id;
  await db.query(`insert into transactions(user_id, type, amount, description, category_id, due_date)
    values($1, 'despesa', 1500, 'Aluguel', $2, '2026-11-10')`, [owner, housing]);
  await rejects(() => db.query(`insert into transactions(user_id, type, amount, description, category_id, due_date)
    values($1, 'despesa', 10, 'Intruso', $2, '2026-11-10')`, [other, housing]), /row-level security/);
  await rejects(() => db.query(`insert into transactions(user_id, type, amount, description, category_id, due_date)
    values($1, 'outro', 10, 'Tipo inválido', $2, '2026-11-10')`, [owner, housing]), /check constraint/);
  const receipt = (await db.query('select public.import_finance_batch($1,$2,$3::jsonb,false) as r',
    ['contas.xlsx', 'a'.repeat(64), JSON.stringify([{line: 2, description: 'Luz', type: 'despesa',
      amount: 180.5, due_date: '2026-11-15', due_day: 15, recurring: true, months: null,
      category_id: housing, notes: ''}])])).rows[0].r;
  equal(receipt.count, 1);
  const own = (await db.query("select public.create_category('Pet shop','EXPENSE') as c")).rows[0].c;
  equal(typeof own.id, 'string');

  await account(other);
  equal((await db.query('select count(*)::int as n from transactions')).rows[0].n, 0);
  equal((await db.query('select count(*)::int as n from recurrence_rules')).rows[0].n, 0);
  equal((await db.query('select count(*)::int as n from categories')).rows[0].n, 13);
  await db.exec('reset role; set role anon');
  await rejects(() => db.query('select * from transactions'), /permission denied/);
  await db.close();
}

await categories(false);
await categories(true);
await notReceived();
await freshProject();
console.log(`${checks} verificações PostgreSQL de categorias, renda e projeto novo passaram.`);
