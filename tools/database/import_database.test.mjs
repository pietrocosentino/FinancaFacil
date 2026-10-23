import assert from 'node:assert/strict';
import {createDatabase, other, owner, readMigration} from './schema.mjs';

let checks = 0;
async function scenario(integerIds) {
  const {db, category, privateCategory, account} = await createDatabase(integerIds);
  // Idempotência da própria migração.
  await db.exec(await readMigration('004_importacao_mvp2.sql'));
  await db.exec('set role authenticated');
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
  await account(owner);
  const started = performance.now();
  const volumeRows = Array.from({length:500}, (_,i) => row(i+2, {
    description:`Massa ${i}`, amount:(i+1)/100, recurring:false}));
  const beforeVolume = await counts();
  const bulk = await save(volumeRows);
  equal((await counts()).transactions, beforeVolume.transactions + 500);
  equal((await save(volumeRows, (await db.query(
    'select file_hash from finance_import_batches where id=$1',[bulk.batch_id])).rows[0].file_hash)).already_imported,true);
  equal(await undo(bulk.batch_id),500);
  const beforeInvalid = await counts();
  await rejects(()=>save([...volumeRows.slice(0,499),row(501,{amount:-1})]), /valor|Valor/);
  equal(await counts(),beforeInvalid);
  await rejects(()=>save([...volumeRows,row(502)]), /500/);
  equal(await counts(),beforeInvalid);
  console.log(`Carga 500 linhas (${integerIds?'inteiro':'UUID'}): ${Math.round(performance.now()-started)} ms; importação, reenvio, desfazer e rollback.`);
  const invalidRows = [
    {amount:0}, {amount:-0.01}, {amount:1000000000}, {amount:1.001},
    {amount:'10.00'}, {amount:null}, {type:'INCOME'}, {type:'sql'},
    {description:''}, {description:' '.repeat(5)}, {description:'x'.repeat(161)},
    {notes:'x'.repeat(1001)}, {due_date:'2019-12-31'}, {due_date:'2101-01-01'},
    {due_date:'2026-02-30'}, {due_date:'10/11/2026'}, {due_day:0}, {due_day:32},
    {months:1}, {months:1201}, {recurring:'Sim'}, {line:1}, {line:10001},
    {category_id:privateCategory}, {category_id:'unknown'}, {category_id:null},
    {recurring:false,months:12}
  ];
  for (const invalid of invalidRows) {
    const snapshot = await counts();
    await rejects(()=>save([row(2,{description:'Válida antes de falha',recurring:false}),
      row(3,{description:'Teste inválido',...invalid})]), /./);
    equal(await counts(),snapshot);
  }
  await rejects(()=>save([row(2),row(2)],hash(),true), /Numeração/);
  for (const invalidFile of ['', ' '.repeat(3), 'x'.repeat(256)]) {
    await rejects(()=>db.query('select import_finance_batch($1,$2,$3::jsonb,false)',
      [invalidFile,hash(),JSON.stringify([row(2)])]), /Identificação/);
  }
  for (const badHash of ['', 'a'.repeat(63), 'G'.repeat(64)]) {
    await rejects(()=>save([row(2)],badHash), /Identificação/);
  }
  // Massa pseudoaleatória determinística: 5 lotes de 100 linhas.
  let randomSeed = 42;
  const random = () => {randomSeed=(1664525*randomSeed+1013904223)>>>0;return randomSeed;};
  for (let batchNo=0;batchNo<5;batchNo++) {
    const rows=Array.from({length:100},(_,i)=>row(i+2,{
      description:`Fuzz ${batchNo}-${i}`, amount:(1+random()%10000000)/100,
      recurring:false}));
    const baseline=await counts();
    const receipt=await save(rows);
    equal(receipt.count,100);
    const sum=(await db.query('select sum(t.amount)::text as total from transactions t join finance_import_items i on i.record_id=t.id::text and i.record_kind=\'transaction\' where i.batch_id=$1',[receipt.batch_id])).rows[0].total;
    equal(Math.round(Number(sum)*100),rows.reduce((n,r)=>n+Math.round(r.amount*100),0));
    equal(await undo(receipt.batch_id),100);
    equal((await counts()).transactions,baseline.transactions);
  }
  await db.exec('set role anon');
  await rejects(()=>db.query('select public.delete_finance_entry($1)',['anything']),/permission denied/);
  await rejects(()=>db.query('select public.import_finance_batch($1,$2,$3::jsonb,false)',
    ['x.xlsx',hash(),'[]']),/permission denied/);
  await db.close();
}
await scenario(false);
await scenario(true);
console.log(`${checks} verificações PostgreSQL passaram (IDs UUID e inteiro).`);
