# Validação executada

Data: 08/10/2026. Ambiente Linux, Flutter 3.24.5 e Dart 3.5.4.

| Verificação | Resultado |
|---|---|
| Suíte recebida, antes das alterações | **75 testes passaram**. |
| Novo teste de voltar pelo Android aplicado ao código recebido | Falhou, reproduzindo o descarte sem confirmação. |
| Suíte final revisada | **112 testes passaram**: 75 existentes e 37 novos casos. |
| Análise estática com `--fatal-infos` | **Nenhum problema encontrado**. |
| Formatação de `lib` e `test` | **0 arquivos precisando de formatação**. |
| Dependências com lockfile obrigatório | Resolvidas e conferidas com Flutter 3.24.5. |
| Compilação `flutter build bundle --no-pub` | Concluída; kernel e assets gerados. |
| Fonte MaterialIcons no bundle | Presente no manifesto e nos assets gerados. |
| Geração Android/iOS de launcher icons | Concluída. |
| YAMLs, plist/XMLs nativos e arquivo wrapper Gradle | Estrutura/sintaxe válidas. |
| Revisão visual por renderização de widgets | Nove capturas: início, finanças, cadastro e perfil nos dois temas; login claro. |

As verificações finais foram feitas após as correções. A captura visual usa fontes carregadas no ambiente de teste e dados simulados; não é uma execução em um telefone.

## O que os novos testes verificam

- Voltar e trocar de aba sem perder o cadastro; descarte somente após autorização.
- Toques rápidos abrindo apenas um formulário.
- Categoria obrigatória e reinício coerente no cadastro seguinte.
- Dia 31 preservado ao selecionar fevereiro.
- Listas em tela estreita, texto ampliado e teclado aberto, nos dois temas.
- Permissão de notificações acessível quando o backend falha.
- Seleção de dezembro de 2100 sem erro de intervalo.
- Entrada monetária, correção do telefone, composição do teclado e referências mensais inválidas.
- Alteração somente de minutos, armazenamento das preferências e compatibilidade com horário antigo.
- Cache corrompido descartado.
- Uma compra de dez parcelas gravando **uma regra**, sem ocorrências antecipadas.
- Confirmação e edição de valor enviadas para o mês correto; reajuste futuro enviado para a RPC específica.
- Paginação de 501 transações e filtro de proprietário nas tabelas financeiras.
- Falha parcial de lote provocando atualização da interface.
- Ausência de sessão impedindo consultas/gravações financeiras e edição de perfil.
- Login, cadastro com e sem confirmação, recuperação, atualização de senha, tradução de erro e preservação dos metadados de perfil.

Os testes de adapters usam o SDK real e HTTP simulado, com armazenamento PKCE em memória. Os testes de serviço de notificações usam canais nativos simulados. Os testes financeiros usam resultados esperados de negócio, mantendo os cálculos em centavos, regras de recorrência e lembretes.

## Cobertura de linhas

Cobertura agregada dos arquivos registrados pelo Flutter: **1570/1975 linhas (79.5%)**. Isso mede execução de linhas, não comprova cobertura de todos os ramos ou cenários.

| Arquivo | Linhas executadas | Cobertura |
|---|---:|---:|
| `lib/features/dashboard/domain/finance_summary.dart` | 29/29 | 100.0% |
| `lib/features/transactions/domain/recurrence.dart` | 41/41 | 100.0% |
| `lib/features/notifications/domain/reminder_plan.dart` | 18/18 | 100.0% |
| `lib/features/transactions/domain/finance_models.dart` | 79/92 | 85.9% |
| `lib/features/transactions/data/finance_repository.dart` | 99/117 | 84.6% |
| `lib/features/auth/data/auth_gateway.dart` | 21/25 | 84.0% |
| `lib/features/profile/data/profile_repository.dart` | 11/13 | 84.6% |

A cobertura é produzida por `flutter test --coverage`. O workflow publica `lcov.info`; o diretório de cobertura não é incluído como código do aplicativo.

## Limites e validação restante

Não foram executados nesta máquina o build Gradle de APK, Xcode, CocoaPods, assinatura ou instalação no iPhone. O bundle confirma a compilação Dart e inclusão de assets, **não substitui** esses builds nativos.

Não houve execução de SQL nem testes de conexão autenticada no Supabase do usuário. RLS, enums, relacionamentos, grants e funcionamento das RPCs precisam ser conferidos no banco real ou em uma base de testes compatível. Os contratos HTTP simulados não validam o SQL que o servidor executa.

Ainda precisam de teste em aparelho: entrega dos lembretes com o aplicativo fechado, retomada após boot, permissões negadas, limite e renovação dos agendamentos, horário/fuso, links de confirmação e recuperação, expiração da sessão e falhas de rede reais.

Para isolamento de dados, testar duas contas distintas e verificar que uma não lê ou altera os registros da outra. Para notificações, confirmar manualmente um pagamento e verificar que os avisos daquela ocorrência são removidos, preservando a próxima recorrência.

O workflow agora bloqueia os builds se formatação, análise ou testes falharem. Não foi enviado commit ou push para o GitHub durante esta revisão.
