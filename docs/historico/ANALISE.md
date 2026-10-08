# Análise do FinançaFácil

Revisão de 08/10/2026, baseada no ZIP `financafacil-main(2).zip` enviado pelo usuário. A entrega revisada é **1.2.1+7**. O escopo foi o aplicativo Flutter, seus testes, scripts Supabase, configurações nativas e workflow; os arquivos do protótipo web foram identificados como externos ao aplicativo compilado.

## Diagnóstico priorizado

### Crítico

**Corrigido — voltar pelo Android podia descartar um cadastro sem perguntar.** O navegador interno usava `pop()`, que contornava a proteção do formulário. Agora usa `maybePop()`. O teste de regressão falhou na versão enviada e passou na corrigida. Alterações de tipo, data, categoria e dia mensal também entram na proteção de dados não salvos.

**Corrigido — projetos duplicados dificultavam atualizar a versão efetivamente compilada.** O repositório tinha plataformas, pubspec e testes tanto na raiz quanto em `flutter_project`, além de arquivos React/Vite e ZIPs antigos. O workflow compila somente `flutter_project`. A entrega foi consolidada nessa estrutura; atualizar uma cópia fora dela não muda o aplicativo gerado.

**Pendente de implantação — o estado real do Supabase não foi validado.** Os scripts distribuídos não criam o esquema inicial de `categories` e `transactions`; pressupõem um banco existente. Sem essas tabelas, permissões, relacionamento de categoria e migrações de recorrência, consultas e gravações falham. Isso impede reproduzir uma instalação do zero apenas executando os scripts atuais. O arquivo `supabase/diagnostico.sql` foi ampliado, mas não foi executado no seu projeto. Também é necessário confirmar RLS nas tabelas financeiras base e o isolamento entre dois usuários. Esta pendência não é uma afirmação de que seu banco atual esteja incorreto.

### Importante

| Problema encontrado | Resultado da revisão |
|---|---|
| Setas de mês sem limite e calendário com data final em janeiro de 2100 | Seletor próprio de mês e limites coerentes entre 2020 e dezembro de 2100. |
| Escolher outro mês podia trocar o dia mensal por um dia de calendário | O mês inicial e o dia mensal são tratados separadamente; dia 31 continua 31, com vencimento ajustado ao fim dos meses curtos. |
| Categoria não selecionada deixava o botão sem explicação | Validação explícita na categoria; o botão permite mostrar o que falta preencher. |
| Categoria do cadastro anterior podia ficar escondida no estado após limpar o formulário | Estado e campo são reiniciados juntos; seleção automática permanece apenas quando existe uma única categoria. |
| Toques rápidos no cadastro podiam abrir duas rotas com a mesma chave global | Guarda de abertura evita formularios duplicados. |
| Filtros fixos da lista podiam consumir a tela com teclado ou fonte grande | Filtros e lançamentos compartilham uma rolagem; teste em 320 px e escala de texto 2 nos dois temas. |
| Configuração de lembretes desaparecia se a consulta falhasse | Permissões ficam fora do resultado da consulta e continuam acessíveis sem conexão. |
| Máscara de telefone mandava o cursor para o fim | Cursor preservado na edição; backspace em separador e composição do teclado tratados. |
| Valores ambíguos, como `1.2,3`, ou notação científica podiam ser aceitos | Validação de entrada conserva formatos monetários válidos e rejeita os ambíguos. Os cálculos e o arredondamento em centavos foram preservados. |
| Alterar somente os minutos não notificava observadores do horário | Preferência passou a representar hora e minuto juntos. Valores inválidos usam os padrões, com compatibilidade para a preferência antiga. |
| Cache de notificações com estrutura inválida podia lançar erro ao ser consultado | Cache inválido é descartado; não é tratado como confirmação ou atualização do banco. |
| Identificador mensal podia normalizar mês inválido para outra data | Exigido o formato mensal canônico antes de enviar a ocorrência à RPC. |
| Tipografia dependia de download por `google_fonts` | Fonte do sistema, com hierarquia consistente; dependência e transitivas exclusivas removidas pelo resolvedor. |
| Workflow não executava análise ou testes e recriava a estrutura Android a cada build | Verificação obrigatória antes dos builds, lockfile obrigatório e remoção de `flutter create` do CI. |

**Pendente — validação nativa e em aparelho.** A revisão executou os testes, a análise e a compilação do bundle Flutter. Não executou `assembleRelease`, Xcode ou CocoaPods nesta máquina. Portanto, os builds finais Android/iOS dependem da execução do workflow e os lembretes precisam ser conferidos em aparelhos reais.

**Pendente para distribuição pública.** O Android continua usando a chave de depuração no build release, adequada para os testes atuais, mas deve usar uma chave de publicação para distribuição definitiva. O artefato iOS de dispositivo continua sem assinatura por desenho do workflow. Não foram inventadas credenciais de assinatura.

### Melhorias

**Aplicadas:** títulos alinhados, paleta compartilhada, botões com áreas de toque maiores, botão “Novo lançamento” com texto em Finanças, categoria nos cartões, estados de filtro legíveis, ícones e rótulos nas três abas, explicação do saldo expansível, avisos com contraste nos dois temas e atualização por gesto em Notificações.

**Aplicadas em clean code:** composição de serviços preservada; enums para frequência e filtros; navegação de mês centralizada; estado assíncrono em listas reutilizado; fonte de dados de teste HTTP compartilhada; remoção de constante não usada, espaçamento duplicado, busca repetida de índice e ordenação de reajustes dentro do loop de meses.

**Para evolução:** versionar o esquema inicial do banco com migrações verificáveis; testar as RPCs em PostgreSQL com dois usuários; testar login, recuperação, notificações e retorno de links em dispositivos; otimizar leituras de todo o histórico quando a base crescer. Não foi adicionada uma estrutura de gerenciamento de estado apenas para aumentar a complexidade do projeto.

## Arquitetura atual

O projeto é organizado por funcionalidade, com separação entre apresentação, acesso a dados e regras de domínio. Usa `StatefulWidget` para estado das telas e `ValueNotifier` para tema, horário e atualização financeira. Não é uma implementação integral da chamada Clean Architecture.

- `lib/main.dart`: inicialização, localidade brasileira, temas e entrada na autenticação.
- `lib/core`: configuração, composição de serviços, preferências, erros e utilitários.
- `lib/features/auth`: sessão, gateway Supabase e formulários de acesso.
- `lib/features/transactions`: modelos, projeção mensal, repositório e telas financeiras.
- `lib/features/dashboard`: cálculo de resumo mensal e início.
- `lib/features/notifications`: seleção de pendências, planejamento local e lista de avisos.
- `lib/features/profile`: leitura e edição de metadados do usuário.
- `lib/shared/widgets`: layout com navegador interno, painéis assíncronos e seletor de mês.

As telas recebem interfaces de repositórios, o que permite testar comportamento sem chamar o Supabase. Em produção, `AppServices` fornece os adapters. O navegador interno mantém o menu fixo; `IndexedStack` preserva as abas.

`financeRevision` provoca novas consultas após alterações e ao retornar ao aplicativo. É simples e apropriado para o tamanho atual, mas pode gerar consultas repetidas e merece revisão se o aplicativo crescer.

## Telas e funções

| Área | Funções existentes |
|---|---|
| Acesso | Entrar com e-mail/senha, criar conta com nome/e-mail/telefone opcional, pedir recuperação e definir nova senha. |
| Início | Pendências prioritárias, notificações com contagem, saldos confirmado e previsto, total a pagar, recebido/pago e despesas por categoria. |
| Finanças | Consulta por mês, busca, filtro por receita/despesa e status, seleção de pagamentos, revisão antes de confirmar e correção da confirmação. |
| Novo lançamento | Valor, nome, vencimento, categoria, observação, receita/despesa, avulso/mensal/parcelado e confirmação inicial apenas para avulsos. |
| Edição de valor | Alterar um mês ou aplicar aos meses seguintes de uma recorrência elegível. |
| Contas mensais e parcelas | Consultar regras, última parcela e reajustes; encerrar após o mês atual preservando histórico. |
| Notificações | Atrasadas, vencendo hoje e nos próximos três dias; confirmar pagamento ou manter pendente; configuração de permissão e consulta de cache offline. |
| Perfil | Nome, e-mail, telefone, edição, aparência, horário dos lembretes e saída da sessão. |

## Regras de negócio preservadas

- Saldo confirmado: rendas recebidas menos despesas pagas **no mês**.
- Saldo previsto: rendas menos despesas previstas **no mês**; não acumula saldo bancário de meses anteriores.
- Recorrências são regras; as parcelas são projetadas em memória para a consulta. Uma compra de dez parcelas não insere dez transações antecipadamente.
- Contas sem fim, como aluguel, mantêm quantidade de meses opcional.
- Parcelamentos continuam aceitando de 2 a 1200 meses, conforme a regra existente.
- O dia mensal é conservado; em mês curto, usa-se o último dia disponível.
- O pagamento é manual e individual por ocorrência. Abrir uma notificação não paga a conta.
- Avisos começam três dias antes e incluem pendências atrasadas. Pagamentos confirmados saem da lista.
- O agendamento mantém horizonte de 90 dias e limite de 60 dias com notificações; é renovado ao abrir/retomar o aplicativo e após mudanças.
- Reajustes futuros preservam valores de ocorrências já confirmadas. Encerrar uma regra mantém o histórico confirmado.

A validação de entrada foi endurecida para rejeitar valores ou identificadores inválidos, sem mudar essas regras financeiras.

## Supabase

`Supabase.initialize` usa o endereço do projeto informado e uma chave de papel `anon`. Nome e telefone ficam nos metadados de `auth.users`; o código não usa uma tabela `profiles`.

O gateway usa autenticação por senha, cadastro, recuperação e atualização de senha. Os callbacks configurados são `com.pietro.financafacil://login-callback` e `com.pietro.financafacil://reset-password`. Esses endereços precisam estar autorizados na configuração Auth do Supabase para confirmação e recuperação funcionarem no aplicativo.

O repositório financeiro consulta:

- `transactions`: lançamentos avulsos e legados, com categoria por relacionamento.
- `categories`: categorias por `transaction_type`, usando `EXPENSE`/`INCOME`.
- `recurrence_rules`: início, dia mensal, quantidade opcional, encerramento e template.
- `recurrence_occurrences`: confirmação e valor específico de um mês.

Os tipos financeiros do template são `despesa`/`receita`; o parser também reconhece `EXPENSE`/`INCOME` para dados legados. As consultas financeiras usam o usuário da sessão e paginação de 500 registros. As categorias são compartilhadas conforme as políticas do banco.

As RPCs `set_recurrence_occurrence` e `set_recurrence_future_amount` atualizam ocorrências e reajustes. São `security invoker`, verificam usuário e usam RLS. As operações de lote não são uma transação única: se parte falhar, a interface informa e recarrega. Isso foi preservado e testado.

Ordem existente dos scripts: `recorrencia.sql`, `lembretes.sql`, `experiencia.sql`. Antes, é necessário que o esquema base exista. O arquivo `diagnostico.sql` contém apenas consultas de leitura e pode ajudar a conferir tabelas, constraints, políticas, grants e funções. A revisão não alterou os scripts de gravação nem executou migrações remotamente.

## Android

Identificador `com.pietro.financafacil`; `compileSdk`/`targetSdk` 34; mínimo 23; AGP 8.1.0; Gradle 8.3; Kotlin 1.9.0; Java 17 no CI e alvo de bytecode 1.8. Desugaring está configurado para notificações.

O manifesto inclui internet, permissão de notificações, retomada após boot, receivers do plugin e os callbacks de autenticação. O ícone próprio de notificação e sua regra de preservação existem. O wrapper Gradle foi conferido estruturalmente; o workflow garante permissão de execução do script.

`app_links` 6.3.2 possui `compileSdk 34` explícito no código do pacote instalado. A configuração problemática por dependência de `flutter.compileSdkVersion` de outras versões não está nessa versão. O pin e o lockfile foram mantidos; isto não equivale a comprovar o build Gradle final.

`google-services.json` foi removido porque não há integração Firebase, plugin Google Services ou dependência Firebase no aplicativo. Os lembretes são locais.

## iOS

Identificador `com.pietro.financafacil`; deployment target 13.0. O Podfile contém apenas o target existente `Runner`. Não há referência ao `RunnerTests` inexistente que causou o erro anterior.

Os xcconfig Debug/Release incluem as configurações Pods e Flutter; Profile usa a configuração Release. As fases Flutter Build e Embed existem. `AppDelegate` usa a assinatura correta de `didFinishLaunchingWithOptions`, registra os plugins e configura o delegate de notificações. Info.plist declara o esquema dos callbacks e desativa o processamento paralelo de deep links do Flutter.

Plists, esquemas, storyboards e demais XMLs foram verificados quanto à sintaxe. A integração nativa e a instalação no iPhone precisam da validação em Mac/aparelho; não foram executadas nesta revisão.

## Dependências e testes

O ambiente declarado Dart >=3.5.0 é coerente com Flutter 3.24.5/Dart 3.5.4 usado na validação. `intl` 0.19.0 está compatível com `flutter_localizations` dessa versão. As dependências de Supabase, links, notificações, timezone e preferências têm usos no código.

`google_fonts` foi removido após trocar para fonte do sistema. `http` foi declarado em dev_dependencies porque é usado diretamente nos testes dos adapters; não depende mais de uma importação transitive implícita. `flutter_launcher_icons` continua necessário para gerar os ícones Android/iOS e foi executado com sucesso.

Os 75 testes recebidos estavam passando. Eles protegem cenários financeiros relevantes, mas não provavam o funcionamento completo dos adapters ou da navegação. A suíte revisada tem novos testes de regressão, armazenamento local e contratos HTTP do SDK. Não foi descartado teste útil para forçar resultado verde.

Consulte `VALIDACAO.md` para a contagem final, cobertura de linhas e o que ainda não foi testado.
