# MVP2 — importação de Excel

## Entrega

No Início ou no Extrato, **Adicionar → Importar planilha** abre a seleção de arquivo, o modelo para baixar e o histórico. O formato é .xlsx, até 5 MB, com até 500 linhas na aba Lançamentos. Os exemplos estão somente na aba Como preencher e nunca são cadastrados automaticamente.

A prévia mostra receitas, despesas, valor por linha, primeiro vencimento, categoria e recorrência. O usuário pode corrigir campos e associar categorias às existentes, ou desmarcar linhas. Tipos e categorias não recebem valores padrão silenciosos. As despesas e rendas avulsas entram pendentes. Rendas recorrentes são consideradas recebidas automaticamente na data mensal, por cálculo do aplicativo. As recorrências criam uma regra por linha; não multiplicam o valor mensal nem antecipam as parcelas.

O primeiro vencimento define mês e dia inicial. A coluna opcional Dia de vencimento permite manter, por exemplo, dia 31 com primeiro vencimento em 28/02. A quantidade vazia significa recorrência sem data final. Quantidades de 2 a 1200 meses mantêm o intervalo usado pelo formulário atual. Para uma única parcela, use lançamento avulso.

## Duplicatas e falhas

O arquivo é identificado por SHA-256, por usuário. Reenviar o mesmo arquivo enquanto houver lote ativo retorna o lote existente, inclusive após perda de resposta da rede. Um arquivo alterado recebe outro hash; nesse caso a prévia compara as linhas com registros existentes.

Linhas semelhantes dentro da planilha ou no banco começam desmarcadas. O usuário pode selecioná-las explicitamente e confirmar a inclusão. A comparação é um alerta de semelhança, não uma garantia de que todas as duplicatas possíveis serão encontradas. Ela considera descrição, tipo, valor, vencimento, categoria e, para regras, dia e quantidade de meses. Descrições muito diferentes não são reconhecidas como a mesma conta.

A gravação inteira acontece em uma RPC transacional. Qualquer linha inválida reverte registros, regras e metadados do lote. Importações da mesma conta usam bloqueio transacional. A criação manual de contas continua pelo repositório atual; as duas operações não compartilham um bloqueio exclusivo global.

## Histórico e desfazer

O histórico lista as últimas 100 importações da conta. Desfazer exige que todos os registros ainda correspondam ao estado originalmente cadastrado. Um pagamento confirmado, um valor editado, uma recorrência encerrada, uma ocorrência gravada ou um registro removido bloqueia o desfazer do lote inteiro. Não há remoção parcial silenciosa.

Lotes desfeitos continuam no histórico. O mesmo arquivo pode ser importado novamente depois que seu lote foi desfeito. O arquivo original não é enviado nem armazenado no Supabase; apenas dados validados, nome, hash e registros do lote são persistidos.

## Categorias

Uma categoria da planilha que não existe pode ser criada na própria prévia, com o botão **Criar categoria “nome”**: todas as linhas do mesmo tipo com esse nome são associadas a ela. Nada é criado sem esse toque. Requer `006_categorias_e_renda.sql`. A RPC usa SECURITY INVOKER na importação para respeitar a visibilidade de categorias e as políticas existentes das tabelas financeiras.

O desfazer usa uma função restrita à conta autenticada, com verificação dos registros e bloqueios. Ela não concede DELETE geral nas tabelas financeiras. O SQL pressupõe transactions, categories, recurrence_rules e recurrence_occurrences existentes e corretamente protegidas por RLS.

## Ativação

1. Atualize os arquivos locais preservando .git e android/local.properties.
2. Execute flutter pub get e reinicie totalmente o app; file_picker é um plugin nativo novo.
3. Se as migrações anteriores já estão aplicadas, execute somente supabase/004_importacao_mvp2.sql no SQL Editor do Supabase.
4. Em um banco existente ainda sem recorrência, confira e aplique a sequência descrita em flutter_project/supabase/README.md. Elas pressupõem as tabelas base existentes; não criam um banco novo completo.
5. Teste com duas linhas reais, confira a prévia, importe e consulte o mês do primeiro vencimento.

Testes e cobertura atuais: veja `docs/TESTES-REGRESSAO.md`.
