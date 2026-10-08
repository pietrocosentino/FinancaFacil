# Itens excluídos da entrega limpa

A cópia usada pelo workflow fica em `flutter_project`. Os itens abaixo existiam na raiz do ZIP enviado e não eram usados pelo build Flutter:

- `android/`, `ios/`, `assets/`, `test/` e `pubspec.yaml` **da raiz** — duplicações; suas versões necessárias foram mantidas dentro de `flutter_project`.
- `src/`, `package.json`, `bun.lock`, `index.html`, `metadata.json`, `tsconfig.json` e `vite.config.ts` — protótipo React/Vite, fora do aplicativo Flutter.
- `.env.example` da raiz — configuração do protótipo; não era lida pelo aplicativo Flutter.
- `FinancaFacil_Atualizado.zip`, `FinancaFacil_UI_UX.zip`, `FinancaFacil_UI_UX_Testes.zip` e `financafacil-main (1).zip` — pacotes antigos dentro do repositório.
- `flutter_project/android/app/google-services.json` — configuração Firebase sem utilização.

Não apague as pastas `android`, `ios`, `assets`, `lib`, `test` ou `supabase` **dentro de `flutter_project`**. Elas fazem parte da entrega.

O pacote não inclui caches, diretórios de build, cobertura gerada, `local.properties`, xcconfig gerado ou registradores automáticos de plugins. O Flutter gera esses arquivos quando necessário; eles foram incluídos no `.gitignore`. Não foram removidos o wrapper Gradle, os projetos Xcode, os ícones, as regras de preservação de recursos ou scripts necessários.

O `.gitignore` foi ampliado e os arquivos do projeto mantêm os caminhos esperados pelo workflow. O upload de arquivos pelo site não apaga as cópias antigas: essa limpeza também precisa ser feita no repositório remoto.
