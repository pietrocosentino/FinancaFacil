# Testes e regressão

Toda alteração enviada ao GitHub (push no `main` ou pull request) passa pelo workflow `.github/workflows/build.yml` antes dos builds Android e iOS. O resultado aparece como anotações no próprio PR: análise estática, nome e mensagem de cada teste que falhar, total de testes e cobertura.

| Etapa | Comando | O que garante |
|---|---|---|
| Contratos | `node tools/validation/contracts.test.mjs` | RPCs usadas pelo app existem no SQL e em `docs/endpoints.openapi.json`; variáveis de ambiente; identificadores do projeto iOS |
| Banco | `npm test --prefix tools/database` | Importação (UUID e IDs inteiros, 500 linhas, rollback, duplicatas, desfazer), recorrência (confirmação, correção, reajuste, parcelas, encerramento), categorias próprias, "Não recebi" e criação de projeto novo, sempre com RLS e duas contas |
| Formatação | `dart format --output=none --set-exit-if-changed lib test` | Estilo único do formatador oficial |
| Análise | `dart analyze` | Regras de `flutter_lints` e ordenação de imports |
| Flutter | `flutter test --coverage` | Domínio, repositórios contra HTTP simulado, telas e fluxos de navegação |

Resultado em 23/10/2026 (CI, Flutter 3.47.6, versão 2.1.0): **270 testes Flutter aprovados**, cobertura de **86,7%** das linhas de `lib`, análise sem nenhum aviso, **351 verificações PostgreSQL** (278 de importação, 24 de recorrência e 49 de categorias, "Não recebi" e projeto novo do zero) e builds Android (targetSdk 36) e iOS concluídos.

## Onde estão os testes

- **Regras puras:** `domain_helpers_test`, `business_rules_unit_test`, `recurrence_test`, `finance_summary_test`, `amount_edit_scope_test`, `import_models_test`, `finance_utils_test`, `auth_validators_test`, `input_helpers_test`.
- **Adapters (SDK Supabase real, HTTP simulado):** `finance_repository_contract_test`, `import_repository_contract_test`, `auth_profile_contract_test`, `finance_cache_test`.
- **Serviços locais:** `reminder_service_test`, `reminder_synchronizer_test`, `device_preferences_test`, `profile_photo_store_test`, `profile_image_decoder_test`, `selected_file_reader_test`, `xlsx_import_reader_test`.
- **Usabilidade da 2.1.0:** `usability_features_test` (Início por mês e comparação, Extrato com "Não recebi", ações pelo cartão, filtros e seleção, criação de categoria no cadastro e na importação), `finance_tabs_test` (botão Adicionar e três abas), `errors_and_receipt_test` (mensagens de falha, registro de erros, renda não recebida e contratos HTTP das novas funções).
- **Telas e fluxos:** `navigation_regression_test`, `ux_flows_test`, `finance_screens_test`, `finance_tabs_test`, `finance_actions_visibility_test`, `automatic_income_test`, `edit_confirmed_amount_test`, `delete_entry_test`, `reminders_test`, `import_flow_test`, `import_history_screen_test`, `login_screen_test`, `profile_*_test`, `shared_widgets_test`.
- **Carga e limites:** `stress_regression_test` (500/501 linhas, 100 mil lançamentos, 1200 parcelas, calendário 2020–2100).

Os repositórios simulados de `test/support` seguem o mesmo contrato dos reais: toda alteração chama `notifyFinanceChanged()`.

## Executar localmente

No Windows, na raiz: `powershell -ExecutionPolicy Bypass -File .\tools\validation\run-tests.ps1` (use `-Flutter CAMINHO` se o SDK não estiver em `C:\dev\flutter`). Logs e cobertura ficam em `test-results`.

Manualmente: na raiz, `npm ci --prefix tools/database` e `npm test --prefix tools/database`; em `flutter_project`, `flutter pub get`, `dart format lib test`, `flutter analyze` e `flutter test --coverage`.

Para apontar para outro projeto Supabase, copie `env.example.json` para `env.local.json` e rode `flutter run --dart-define-from-file=env.local.json`. Nunca coloque a chave `service_role` no app.

## O que os testes automáticos não cobrem

- Execução em aparelho Android/iOS: notificações reais, seletores de arquivo e galeria, links de login e recuperação.
- Supabase real: as políticas atuais do seu projeto, concorrência entre conexões e latência. Os scripts foram testados em PostgreSQL local, não no seu banco.
- Desempenho com histórico grande em modo profile.
- Leitor de tela e navegação por teclado físico.
