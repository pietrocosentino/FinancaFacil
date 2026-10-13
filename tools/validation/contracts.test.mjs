import fs from 'node:fs';
import assert from 'node:assert/strict';
const root = new URL('../../', import.meta.url);
const read = name => fs.readFileSync(new URL(name, root), 'utf8');
const api = JSON.parse(read('docs/endpoints.openapi.json'));
const sql = ['recorrencia','editar_valores','importacao_mvp2','excluir_lancamentos']
  .map(name=>read(`flutter_project/supabase/${name}.sql`)).join('\n');
const adapters = ['transactions/data/finance_repository','imports/data/import_repository']
  .map(name=>read(`flutter_project/lib/features/${name}.dart`)).join('\n');
let checks=0;
for (const [path, methods] of Object.entries(api.paths)) {
  const name=path.split('/').pop();
  assert.ok(adapters.includes(`rpc('${name}'`),`${name} não é usado pelo app`); checks++;
  const definition=new RegExp(`function\\s+public\\.${name}\\s*\\(([\\s\\S]*?)\\)`, 'i').exec(sql);
  assert.ok(definition,`${name} sem implementação SQL`); checks++;
  const params=Object.keys(methods.post.requestBody.content['application/json'].schema.properties);
  for(const param of params){assert.ok(definition[1].includes(param),`${name}: parâmetro SQL ausente ${param}`);checks++;}
  assert.ok(methods.post.security[0].apiKey && methods.post.security[0].bearerAuth);checks++;
}
for(const match of adapters.matchAll(/rpc\('([^']+)'/g)) {
  assert.ok(api.paths[`/rest/v1/rpc/${match[1]}`],`Endpoint não documentado ${match[1]}`);checks++;
}
const env=JSON.parse(read('flutter_project/env.example.json'));
const config=read('flutter_project/lib/core/config/supabase_config.dart');
for(const key of Object.keys(env)){assert.ok(config.includes(`String.fromEnvironment('${key}'`));checks++;}
assert.ok(!JSON.stringify(env).includes('service_role'));checks++;
console.log(`${checks} verificações de contratos de API e ambiente passaram.`);
