# Análise ponta a ponta — FinançaFácil 2.0.7 (e o que foi aplicado na 2.1.0)

Revisão de 22/10/2026 sobre o `main` em `1e4e3f4`. Escopo: app Flutter (`flutter_project/lib`), testes, scripts Supabase, ferramentas de validação e CI. As mudanças estão no branch `refactor/analise-clean-code-solid`.

## Resumo

O app tem uma base melhor do que a média de projetos desse tamanho: separação por funcionalidade, repositórios com interface, regras de recorrência bem pensadas (projeção em memória, sem parcelas antecipadas), validações sérias na importação e uma suíte de testes grande. Os principais riscos não estão no código de tela, e sim em volta dele: **o app não pode ser publicado na Play Store hoje** (alvo API 34), **o esquema base do banco não está versionado**, e **cada alteração baixa o histórico financeiro inteiro**, o que vai pesar conforme o uso cresce. Na experiência, o problema central é a navegação: as ações mais frequentes estão a dois ou três toques e há entradas duplicadas para as mesmas telas.

## 1. Visão de líder técnico

### Arquitetura

**Pontos fortes.** Pastas por funcionalidade (`auth`, `transactions`, `imports`, `notifications`, `profile`, `dashboard`) com `data`/`domain`/`presentation`. Interfaces de repositório (`FinanceRepository`, `ImportRepository`, `ProfileRepository`, `AuthGateway`, `ReminderService`) permitem testar telas sem Supabase. Lógica financeira sensível (centavos, recorrência, reajustes) está em funções puras e testadas.

**Problemas encontrados (e o que foi feito):**

| Problema | Situação |
|---|---|
| Telas buscavam dependências sozinhas (`widget.repository ?? AppServices.finance`): localizador de serviço escondido em 8 telas | **Corrigido.** Telas recebem tudo pelo construtor; `AppServices` só aparece em `main`, `AuthGate` e `MainLayout` |
| `MainLayout` com cerca de 300 linhas: cabeçalho, sincronização de lembretes, navegação e três flags de toque duplo | **Corrigido.** `ReminderSynchronizer`, `MainHeader` e `SingleFlight` extraídos |
| Regra de situação do lançamento (atrasada, vence hoje, recebido automático) dentro do widget do cartão | **Corrigido.** `EntryStatus` no domínio |
| Cálculo de reajuste futuro duplicado entre a regra e a projeção | **Corrigido.** `AmountSchedule` único |
| Formatação de data `AAAA-MM-DD` repetida em 3 lugares; `daysUntil` morando no resumo do painel e importado por notificações e transações | **Corrigido.** `core/utils/dates.dart` |
| 11 `AlertDialog` de confirmação copiados | **Corrigido.** `showConfirmDialog` |
| Parâmetros só usados por testes (`showRegistration`, `showHeader`, `showIdentity`, `photoStore`): ramos inteiros de tela que nunca rodavam em produção | **Removidos**; testes passaram a exercitar o fluxo real |
| `financeRevision` e `ReminderPreferences` são `ValueNotifier` globais e mutáveis | Mantido. Funciona no tamanho atual; ver recomendações |
| `ReminderPreferences` guarda também o tema | Mantido; o nome engana. Renomear para `DevicePreferences` quando mexer na área |
| `AppTheme.semanticColor` decide a cor comparando `Color` por igualdade (`color == Colors.amber`) | Mantido; frágil. Trocar por tokens semânticos no `ThemeExtension` |
| Dinheiro em `double` no domínio (convertido para centavos nas somas) | Mantido. Sem erro visível hoje, mas o correto é inteiro em centavos de ponta a ponta |

### Dados e desempenho — gargalos

1. **Cada invalidação baixa todo o histórico.** `SupabaseFinanceRepository._loadSnapshot` lê `transactions`, `recurrence_rules`, `recurrence_occurrences` e categorias duas vezes, paginando de 500 em 500, **sem filtro de data**. O cache dura 2 minutos, mas é descartado a cada alteração e a cada retorno do app ao primeiro plano. Com alguns anos de uso, abrir o app passa a custar dezenas de requisições.
   - **Corrigido nesta revisão:** telas chamavam `notifyFinanceChanged()` depois de o repositório já ter chamado — editar um valor ou confirmar um pagamento baixava o histórico **duas vezes**. `plans()` fazia uma consulta própria em vez de usar o snapshot. Mudar o horário dos lembretes invalidava os dados financeiros só para reagendar.
   - **Recomendado:** filtrar `transactions` por intervalo (`due_date` do mês consultado ± horizonte), mover a projeção de recorrência para uma RPC ou view, e só invalidar ao retomar o app se o snapshot tiver mais de alguns minutos.
2. **Projeção repetida.** Início, cabeçalho, Extrato e Notificações chamam `transactions()` a cada revisão; o snapshot é compartilhado, mas a projeção e o `fromMap` de todo o histórico rodam 3–4 vezes. Barato hoje, linear no histórico.
3. **Lembretes:** `planReminders` ordenava a lista inteira para cada um dos 90 dias; agora só conta.

### Banco (Supabase)

- **Esquema base fora do repositório.** `categories` e `transactions` (com suas políticas RLS) não estão em nenhum script. Não dá para recriar o banco do zero nem revisar as políticas dessas tabelas. É o maior risco de operação. O esquema usado nos testes (`tools/database/schema.mjs`) é um bom ponto de partida para versionar com a Supabase CLI.
- **Migrações sem numeração** e com duplicação: `experiencia.sql` repetia exatamente uma função de `editar_valores.sql` (**removido**). A ordem agora está em `supabase/README.md`.
- **Fuso inconsistente (corrigido):** `set_recurrence_future_amount` usava `current_date` (UTC do servidor) e `stop_finance_plan` usava São Paulo. Entre 21h e 0h do último dia do mês, um reajuste "a partir deste mês" era recusado.
- RLS por `user_id` e RPCs `security invoker` estão corretas; as duas `security definer` (`delete_finance_entry`, `undo_finance_import`) verificam o dono e fixam `search_path`. Boas práticas.
- RPCs de recorrência não tinham nenhum teste de banco: **criados 24** (confirmação, correção de valor, reajuste não retroativo, parcelas, encerramento, isolamento entre contas, anônimo).

### Plataforma e entrega

- **Bloqueante para publicar:** `targetSdkVersion 34`. Desde 31/08/2026 a Google Play exige API 36 para apps novos e atualizações (com extensão possível até 01/11/2026). Subir para 36 exige testar edge-to-edge e o gesto de voltar preditivo em aparelho; não foi alterado aqui por não haver como validar em dispositivo.
- APK de release assinado com a chave de debug; iOS sem assinatura. Precisa de keystore própria e de um job de release antes de qualquer distribuição.
- Dependências fixadas em versões antigas (`flutter_local_notifications` 17.x, `file_picker` 8.x, `archive` 3.x, `flutter_timezone` 3.x, `flutter_lints` 4.x). Rodar `flutter pub outdated` e atualizar uma por vez, com o CI.
- A URL do projeto Supabase e a chave pública ficam como padrão no código. A chave `anon` é pública por natureza, mas um build de testes aponta para produção se ninguém passar `--dart-define`.
- Erros são engolidos com `catch (_)` em quase toda a apresentação, sem registro. Não há telemetria de falhas; quando algo falhar com um usuário real, não haverá rastro.

### Qualidade e testes

| | Antes | Depois |
|---|---|---|
| Testes Flutter | 214 (1 falhando, dependia da data) | **247, todos passando** |
| Cobertura de linhas | 81,8% | **86,2%** |
| Verificações de banco (PGlite) | 278 | **302** |
| Análise estática | sem erros | sem erros, avisos ou infos |
| Formatação | 78 de 87 arquivos fora do padrão | **padrão `dart format`, verificado no CI** |

O CI agora publica análise, testes com falha (nome e mensagem) e cobertura como anotações do PR — antes era preciso baixar o log. A suíte cumpriu o papel de regressão: pegou dois erros que eu mesmo introduzi na refatoração (`setState` recebendo um `Future` no Início e no cabeçalho), e ao procurar o mesmo padrão apareceu um defeito antigo no Histórico de importações (erro ao desfazer um lote ou ao tentar novamente, em modo debug). O teste do dia 31 falhava em parte dos dias do mês porque dependia da data atual.

## 2. Visão de UX

### Navegação e arquitetura de informação

- **A aba Finanças é só um menu** com três opções. Cadastrar uma despesa — a ação mais frequente do app — custa dois toques e uma tela intermediária. Um botão flutuante "+" no Início e no Extrato resolveria; Finanças poderia sumir ou virar "Importar".
- **Três portas para o perfil**: foto no cabeçalho (abre o perfil numa folha sobreposta), aba Perfil e, dentro dele, "Minhas notificações". **Três portas para notificações**: sino, cartão do Início e item do perfil. Redundância confunde mais do que ajuda; o cabeçalho já tem foto e sino, a aba Perfil pode sair.
- O cabeçalho fixo com foto, marca e sino ocupa altura permanente em todas as telas, inclusive nas que já têm `AppBar` própria — em celulares pequenos são duas barras empilhadas.

### Início

- Três cartões de saldo (confirmado, previsto, a pagar) mais a explicação "Como calculamos o saldo?". O conceito de dois saldos que **não acumulam entre meses** é contraintuitivo para quem pensa em conta bancária; vale um único número principal com o detalhamento abaixo.
- Não há navegação de mês no Início: para ver outubro em novembro é preciso ir ao Extrato, que não mostra resumo.
- "Para onde vai o seu dinheiro?" funciona, mas com barras sem cor por categoria e sem comparação com o mês anterior.

### Cadastro

- Bom: validação clara, aviso de descarte, dia 31 preservado, prévia do valor e da última parcela.
- "Uma vez / Todo mês / Parcelado" + "Quantidade de meses restantes" + "Dia de vencimento" + data do primeiro vencimento: quatro controles para uma ideia. Parcelado poderia pedir só "em quantas vezes" e derivar o resto.
- **Categorias não podem ser criadas no app.** Se a lista do banco não tiver a categoria certa, o usuário fica preso — inclusive na importação, que recusa categorias novas.
- Textos diziam "Consulte em Finanças" depois de a consulta ter mudado para o Extrato (**corrigido**), e a prévia pedia para confirmar o recebimento de renda recorrente, que é automático (**corrigido**).

### Extrato

- O painel de filtros (busca, tipo, mês, "Mês atual", três chips, link de recorrências) empurra a lista para baixo; em 360×720 sobra pouco espaço para lançamentos. Filtros poderiam ficar numa linha rolável.
- Ações do lançamento escondidas no menu "⋮" e um `ExpansionTile` "Detalhes" em cada cartão: muitos toques para tarefas comuns. Tocar no cartão não faz nada.
- Confirmação em lote com revisão antes de gravar é um acerto.

### Notificações

- "Manter pendente" só mostra uma mensagem; não adia nem silencia nada. Ou vira "Lembrar amanhã" de verdade, ou sai.
- Renda recorrente é marcada como **recebida automaticamente** na data. Se o salário atrasar, o saldo confirmado mente sem aviso. Pelo menos um "Não recebi" deveria existir.

### Perfil, acessibilidade e consistência

- Tema padrão é sempre claro; o padrão esperado hoje é seguir o sistema.
- Foto de perfil só no aparelho: some ao trocar de celular, e o texto avisa isso só dentro do seletor.
- Acessibilidade acima da média: áreas de toque de 48 px, rótulos semânticos, testes com fonte 2× e tela de 320 px nos dois temas.
- Mensagens de erro são genéricas ("Verifique sua conexão") mesmo quando o problema é outro (ex.: script SQL não aplicado).

## 3. O que foi feito nesta revisão

1. **Limpeza:** 13 arquivos obsoletos ou duplicados removidos (histórico e relatórios de validação antigos, instruções de pacotes ZIP, manifesto SHA desatualizado, script SQL duplicado, ícone duplicado, saída de ferramenta, `.env.example` que o Flutter não lê) e os ramos de tela que só existiam para testes (botão Adicionar e importação no Extrato, cabeçalho alternativo do Início, identidade duplicada no Perfil). Nenhuma dependência do `pubspec.yaml` estava sem uso: todas são importadas ou usadas pelo CI (`flutter_launcher_icons`).
2. **Clean code e SOLID:** responsabilidade única (`ReminderSynchronizer`, `MainHeader`, `EntryStatus`, `statement.dart`), aberto/fechado mantido em `ProfileMenuItem`, substituição de Liskov no repositório de teste (agora notifica alterações como o real), segregação de interface em `ProfilePhotoSource` e inversão de dependência em todas as telas. Diálogos, datas e reajustes sem duplicação.
3. **Testes:** 33 novos testes Flutter (domínio, sincronização de lembretes, diálogo, foto de perfil, histórico de importações, ações visíveis no fluxo real) e 24 verificações de banco para recorrência. Suíte completa usada como regressão a cada commit no CI.
4. **Correções de comportamento:** `setState` com `Future` no Histórico de importações, fuso no reajuste futuro, textos de aba desatualizados, prévia de renda recorrente, recarga dupla do histórico.

## 4. Avaliação crítica e próximos passos

**Prioridade 1 — impede uso real**
1. Subir `targetSdkVersion` para 36 e testar em aparelho (prazo da Play: 01/11/2026 com extensão).
2. Versionar o esquema base (`categories`, `transactions`, políticas) e migrar os scripts para a Supabase CLI com numeração.
3. Keystore de release e job de publicação; remover a URL de produção como padrão de builds de teste.

**Prioridade 2 — vai doer com o crescimento**
4. Consultas por intervalo de datas e projeção de recorrência no banco, em vez de baixar tudo a cada mudança.
5. Registro de erros (Sentry ou Crashlytics) no lugar dos `catch (_)` silenciosos.
6. Dinheiro em centavos inteiros no domínio.

**Prioridade 3 — produto e UX**
7. Botão "+" global e fim da aba-menu Finanças; uma porta só para perfil e notificações.
8. Criação de categorias pelo usuário (inclusive na importação).
9. "Não recebi" para renda automática e um "Lembrar amanhã" real.
10. Navegação de mês e comparação com o mês anterior no Início; tema padrão seguindo o sistema.

**O que não faz sentido hoje:** a aba Finanças como menu; o botão "Manter pendente"; dois saldos mensais que não acumulam sem um saldo geral; o perfil acessível por cabeçalho e por aba ao mesmo tempo; e a renda considerada recebida sem nenhuma forma de contestar.

**Limites desta revisão:** testes rodaram no CI (Linux, Flutter 3.47.6) com repositórios simulados e PostgreSQL em memória. Não houve execução em aparelho, em Supabase real nem medição de desempenho com histórico grande.

## 5. Aplicado na versão 2.1.0 (23/10/2026)

| Recomendação | Situação |
|---|---|
| 1. `targetSdkVersion` 36 | **Feito**, com voltar preditivo e edge-to-edge. Falta testar em aparelho Android 15/16. |
| 2. Versionar o esquema base | **Feito**: `000_esquema_base.sql` cria um projeto do zero; scripts numerados; teste que monta o banco só com eles. |
| 3. Assinatura de release | **Preparado**: `android/key.properties` ativa a chave própria. A chave precisa ser gerada por você. |
| 4. Consultas por intervalo de datas | **Parcial**: retorno ao app só recarrega depois de 1 minuto fora ou em outro dia. O histórico ainda é lido por inteiro a cada alteração. |
| 5. Registro de erros | **Feito** no app (`AppLog`, com captura global e as últimas 50 falhas). Ligar Sentry ou Crashlytics é trocar o destino em um ponto só. |
| 6. Dinheiro em centavos inteiros | Pendente. As somas já são em centavos; o modelo ainda guarda `double`. |
| 7. Botão Adicionar e fim da aba-menu | **Feito**: abas Início, Extrato e Perfil; uma porta para perfil (nome no cabeçalho leva à aba) e para notificações (sino). |
| 8. Categorias do usuário | **Feito** no cadastro e na importação, com política restritiva no banco. |
| 9. "Não recebi" e "Manter pendente" | **Feito**: "Não recebi" deixa o mês pendente; "Manter pendente" foi removido. |
| 10. Início por mês, comparação e tema | **Feito**. |

Outras correções desta versão: espaço duplicado da barra de status sob o cabeçalho; tocar no cartão abre as ações; confirmação individual no Extrato; detalhes do lançamento visíveis sem expandir; mensagens de erro que distinguem rede, sessão e banco desatualizado; folha de cadastro rolável em telas baixas.

**Atenção:** o projeto Supabase "Finança Fácil" estava **pausado (INACTIVE)** em 23/10/2026. Enquanto estiver assim, o app não consegue entrar nem carregar dados. Reative-o no painel do Supabase e aplique `003` e `006`.
