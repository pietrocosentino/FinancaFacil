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
  assert.ok(new RegExp(`rpc\\(\\s*'${name}'`).test(adapters),`${name} não é usado pelo app`); checks++;
  const definition=new RegExp(`function\\s+public\\.${name}\\s*\\(([\\s\\S]*?)\\)`, 'i').exec(sql);
  assert.ok(definition,`${name} sem implementação SQL`); checks++;
  const params=Object.keys(methods.post.requestBody.content['application/json'].schema.properties);
  for(const param of params){assert.ok(definition[1].includes(param),`${name}: parâmetro SQL ausente ${param}`);checks++;}
  assert.ok(methods.post.security[0].apiKey && methods.post.security[0].bearerAuth);checks++;
}
for(const match of adapters.matchAll(/rpc\(\s*'([^']+)'/g)) {
  assert.ok(api.paths[`/rest/v1/rpc/${match[1]}`],`Endpoint não documentado ${match[1]}`);checks++;
}
const env=JSON.parse(read('flutter_project/env.example.json'));
const config=read('flutter_project/lib/core/config/supabase_config.dart');
for(const key of Object.keys(env)){assert.ok(new RegExp(`String\\.fromEnvironment\\(\\s*'${key}'`).test(config),`${key} não é lida pelo app`);checks++;}
assert.ok(!JSON.stringify(env).includes('service_role'));checks++;

const project = read('flutter_project/ios/Runner.xcodeproj/project.pbxproj');
const scheme = read('flutter_project/ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme');
// Flutter's SwiftPM migrator expects the identifiers from its iOS template.
for (const [id, label, type] of [
  ['97C146ED1CF9000F007C117D', 'Runner', 'PBXNativeTarget'],
  ['97C146EB1CF9000F007C117D', 'Frameworks', 'PBXFrameworksBuildPhase'],
  ['97C146E61CF9000F007C117D', 'Project object', 'PBXProject'],
]) {
  assert.ok(project.includes(id + ' /* ' + label + ' */ = {'),
      'Identificador incompatível com migração SwiftPM: ' + type); checks++;
}
const references = [...scheme.matchAll(/<BuildableReference\s+([\s\S]*?)>/g)];
assert.ok(references.length >= 3, 'Scheme deve referenciar Runner nas ações de build/run/profile'); checks++;
for (const ref of references) {
  assert.ok(ref[1].includes('BlueprintIdentifier = "97C146ED1CF9000F007C117D"'),
      'BuildableReference incompatível com o alvo Runner'); checks++;
}
assert.ok(project.includes('rootObject = 97C146E61CF9000F007C117D'), 'rootObject incompatível'); checks++;

console.log(`${checks} verificações de contratos de API, ambiente e iOS passaram.`);
