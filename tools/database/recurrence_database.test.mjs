// Regras mensais: confirmação por mês, correção de valor, reajustes futuros e
// encerramento. As datas são relativas ao mês atual de São Paulo, como no app.
import assert from 'node:assert/strict';
import {createDatabase, other, owner} from './schema.mjs';

let checks = 0;
const equal = (actual, expected) => { assert.deepEqual(actual, expected); checks++; };
const rejects = async (action, pattern) => { await assert.rejects(action, pattern); checks++; };

const [year, month] = new Intl.DateTimeFormat('en-CA', {
  timeZone: 'America/Sao_Paulo', year: 'numeric', month: '2-digit',
}).format(new Date()).split('-').map(Number);
const monthKey = offset => {
  const date = new Date(Date.UTC(year, month - 1 + offset, 1));
  return date.toISOString().slice(0, 10);
};
const lastDay = offset => {
  const date = new Date(Date.UTC(year, month + offset, 0));
  return date.toISOString().slice(0, 10);
};

const {db, category, account} = await createDatabase(false);
await db.exec('set role authenticated');
await account(owner);

const createRule = async (fields = {}) => (await db.query(
  `insert into recurrence_rules(user_id, first_due, due_day, total_installments, template)
   values($1, $2, $3, $4, $5::jsonb) returning id`,
  [owner, fields.first_due ?? `${monthKey(-2).slice(0, 8)}28`, fields.due_day ?? 31,
    fields.total_installments ?? null,
    JSON.stringify({type: 'despesa', amount: 100, description: 'Aluguel',
      notes: '', category_id: category})])).rows[0].id;
const occurrence = (rule, due, paid = null, amount = null) => db.query(
  'select public.set_recurrence_occurrence($1::uuid,$2::date,$3,$4)', [rule, due, paid, amount]);
const futureAmount = (rule, from, amount) => db.query(
  'select public.set_recurrence_future_amount($1::uuid,$2::date,$3)', [rule, from, amount]);
const stored = async (rule, due) => (await db.query(
  'select amount::float as amount, is_paid from recurrence_occurrences where rule_id=$1 and due_month=$2',
  [rule, due])).rows[0];
const changes = async rule => (await db.query(
  "select template->'future_amounts' as changes from recurrence_rules where id=$1", [rule])).rows[0].changes;

const rent = await createRule();

// Confirmação mensal e correção de valor sem perder a confirmação.
// Corrigir o valor antes de confirmar; depois de paga, a conta fica bloqueada (008).
await occurrence(rent, monthKey(-1), null, 120);
await occurrence(rent, monthKey(-1), true);
equal(await stored(rent, monthKey(-1)), {amount: 120, is_paid: true});
await rejects(() => occurrence(rent, monthKey(-1), null, 130), /não pode ser alterado/);
await rejects(() => occurrence(rent, monthKey(-1), false), /não pode ser alterado/);
equal(await stored(rent, monthKey(-1)), {amount: 120, is_paid: true});
await rejects(() => occurrence(rent, monthKey(-3), true), /fora do período/);
await rejects(() => occurrence(rent, `${monthKey(0).slice(0, 8)}02`, true), /Mês inválido/);
await rejects(() => occurrence(rent, monthKey(0), null, 0), /Valor inválido/);

// Reajuste: nunca retroativo; preserva o valor de meses já pagos.
await rejects(() => futureAmount(rent, monthKey(-1), 150), /mês atual/);
await rejects(() => futureAmount(rent, monthKey(0), -1), /Valor inválido/);
await occurrence(rent, monthKey(0), true);
await occurrence(rent, monthKey(1), null, 130);
await futureAmount(rent, monthKey(0), 150);
equal(await stored(rent, monthKey(0)), {amount: 100, is_paid: true});
equal(await stored(rent, monthKey(1)), {amount: null, is_paid: false});
equal(await changes(rent), [{from_month: monthKey(0), amount: 150}]);
// Um novo reajuste substitui os posteriores e mantém os anteriores.
await futureAmount(rent, monthKey(2), 200);
await futureAmount(rent, monthKey(1), 180);
equal(await changes(rent), [
  {from_month: monthKey(0), amount: 150},
  {from_month: monthKey(1), amount: 180},
]);

// Parcelamento: não aceita meses além da última parcela.
const optical = await createRule({first_due: `${monthKey(0).slice(0, 8)}10`, due_day: 10,
  total_installments: 3});
await occurrence(optical, monthKey(2), true);
await rejects(() => occurrence(optical, monthKey(3), true), /fora do período/);
await rejects(() => futureAmount(optical, monthKey(3), 90), /fora do período/);

// Encerramento: termina no fim do mês atual; meses pagos ficam bloqueados (008).
await db.query('select public.stop_finance_plan($1::uuid)', [rent]);
equal((await db.query('select end_date::text from recurrence_rules where id=$1', [rent])).rows[0].end_date,
  lastDay(0));
await rejects(() => occurrence(rent, monthKey(0), false), /não pode ser alterado/);
equal((await stored(rent, monthKey(0))).is_paid, true);
await rejects(() => occurrence(rent, monthKey(1), true), /encerrada/);
await rejects(() => futureAmount(rent, monthKey(1), 300), /fora do período/);

// Inativar/reativar (008): só lançamentos confirmados; sai dos totais sem sumir.
const inactive = (id, flag) => db.query('select public.set_entry_inactive($1,$2)', [id, flag]);
const flag = async due => (await db.query(
  'select is_inactive from recurrence_occurrences where rule_id=$1 and due_month=$2', [rent, due])).rows[0].is_inactive;
await inactive(`r:${rent}:${monthKey(0)}`, true);
equal(await flag(monthKey(0)), true);
await inactive(`r:${rent}:${monthKey(0)}`, false);
equal(await flag(monthKey(0)), false);
await rejects(() => inactive(`r:${rent}:${monthKey(1)}`, true), /Somente lançamentos confirmados/);
await rejects(() => inactive(`r:${rent}:2026-01-02`, true), /Mês inválido/);
await rejects(() => inactive(null, true), /Registro inválido/);
await rejects(() => db.query('select public.delete_finance_entry($1)', [`r:${rent}:${monthKey(0)}`]),
  /não pode ser (excluída|alterado)/);
// Renda mensal: despesas não podem ser alteradas por essa função.
await rejects(() => db.query('select public.update_income_rule($1::uuid,$2,$3,$4)',
  [rent, 'Novo nome', category, 5]), /Somente rendas/);

// Isolamento entre contas e bloqueio para anônimos.
await account(other);
await rejects(() => occurrence(rent, monthKey(0), true), /no rows/);
await rejects(() => futureAmount(rent, monthKey(0), 10), /no rows/);
equal((await db.query('select count(*)::int as n from recurrence_rules')).rows[0].n, 0);
await account('');
await rejects(() => occurrence(rent, monthKey(0), true), /Sessão expirada/);
await db.exec('reset role; set role anon');
await rejects(() => occurrence(rent, monthKey(0), true), /permission denied/);
await rejects(() => futureAmount(rent, monthKey(0), 10), /permission denied/);
await db.close();

console.log(`${checks} verificações PostgreSQL de recorrência passaram.`);
