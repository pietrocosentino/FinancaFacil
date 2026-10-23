# Scripts do Supabase

Execute no SQL Editor do Supabase, nesta ordem, os que ainda não foram aplicados.
Todos podem ser executados novamente sem apagar dados.

| Ordem | Arquivo | O que faz |
|---|---|---|
| 1 | `recorrencia.sql` | Tabelas `recurrence_rules` e `recurrence_occurrences`, RLS e a RPC `set_recurrence_occurrence`. |
| 2 | `lembretes.sql` | Coluna `notes` em `transactions`. |
| 3 | `editar_valores.sql` | Correção de valor de mês confirmado e a RPC `set_recurrence_future_amount` (reajustes). |
| 4 | `importacao_mvp2.sql` | Lotes de importação do Excel: `preview_finance_import`, `import_finance_batch` e `undo_finance_import`. |
| 5 | `excluir_lancamentos.sql` | `delete_finance_entry` (exclui um mês ou um lançamento) e `stop_finance_plan` (encerra recorrência). |

`diagnostico.sql` é somente leitura: confere tabelas, políticas, permissões e funções.

## Pré-requisito importante

Os scripts pressupõem as tabelas base `categories` e `transactions`, com RLS por
`user_id`, que **não estão versionadas neste repositório**. Um projeto Supabase novo
não pode ser recriado apenas com estes arquivos. O esquema usado nos testes
automatizados está em `tools/database/schema.mjs` e serve de referência.

## Testes

Na raiz do repositório: `npm ci --prefix tools/database` e `npm test --prefix tools/database`.
Os testes usam PostgreSQL em memória (PGlite) e nunca acessam o Supabase remoto.
