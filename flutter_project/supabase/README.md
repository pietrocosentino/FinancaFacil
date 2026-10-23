# Scripts do Supabase

Execute no SQL Editor do Supabase, nesta ordem, os que ainda não foram aplicados.
Todos podem ser executados novamente sem apagar dados.

| Ordem | Arquivo | O que faz |
|---|---|---|
| 0 | `000_esquema_base.sql` | Tabelas `categories` e `transactions`, RLS e categorias padrão. Em um banco que já tem essas tabelas, não altera nada. |
| 1 | `001_recorrencia.sql` | Tabelas `recurrence_rules` e `recurrence_occurrences`, RLS e a RPC `set_recurrence_occurrence`. |
| 2 | `002_lembretes.sql` | Coluna `notes` em `transactions`. |
| 3 | `003_editar_valores.sql` | Correção de valor de mês confirmado e a RPC `set_recurrence_future_amount` (reajustes). |
| 4 | `004_importacao_mvp2.sql` | Lotes de importação do Excel: `preview_finance_import`, `import_finance_batch` e `undo_finance_import`. |
| 5 | `005_excluir_lancamentos.sql` | `delete_finance_entry` (exclui um mês ou um lançamento) e `stop_finance_plan` (encerra recorrência). |
| 6 | `006_categorias_e_renda.sql` | Categorias criadas pelo usuário (`create_category`) e "Não recebi" para renda mensal (`set_income_not_received`). |

`diagnostico.sql` é somente leitura: confere tabelas, políticas, permissões e funções.

## Atualizando um banco que já existe

Se você já tinha aplicado os scripts antigos (sem número), aplique só os novos:

1. `003_editar_valores.sql` de novo: o mês atual passou a ser calculado no fuso de São Paulo.
2. `006_categorias_e_renda.sql`.

Os nomes mudaram (ganharam número), mas o conteúdo dos demais é o mesmo. O app funciona sem o 006; apenas "Nova categoria" e "Não recebi" mostram o aviso de que o banco precisa ser atualizado.

## Segurança

O 006 cria políticas **restritivas** em `categories`: mesmo que uma política antiga permita ler tudo, cada conta só vê as categorias compartilhadas (sem dono) e as suas, e só cria categorias em nome próprio.

## Testes

Na raiz do repositório: `npm ci --prefix tools/database` e `npm test --prefix tools/database`.
Os testes usam PostgreSQL em memória (PGlite) e nunca acessam o Supabase remoto. Um dos cenários cria um projeto do zero somente com estes scripts.
