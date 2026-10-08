# FinançaFácil — revisão 1.2.1+7

Aplicativo Flutter para acompanhar rendas, contas mensais e parcelas, com lembretes e confirmação manual dos pagamentos.

O único projeto do aplicativo fica em **`flutter_project`**. Execute os comandos Flutter dentro dessa pasta.

## O que foi entregue

- Correções de navegação, formulário, entrada de dados e tratamento de falhas.
- Temas claro e escuro consistentes, menu fixo e botão visível para novo lançamento.
- Listas com rolagem para telas pequenas e teclado aberto.
- Testes financeiros preservados e novos testes de regressão e contratos HTTP simulados.
- Workflow com análise e testes antes dos builds Android e iOS.
- Projeto consolidado, sem protótipo web, cópias de plataformas na raiz ou ZIPs antigos.

Leia `docs/ANALISE.md` para o diagnóstico e `docs/VALIDACAO.md` para os resultados e limites da validação. `docs/LIMPEZA.md` lista os itens removidos da entrega.

## Executar e conferir

Use Flutter **3.24.5**, Dart **3.5.4** e Java **17** para o Android, conforme o workflow.

```sh
cd flutter_project
flutter pub get --enforce-lockfile
dart format --output=none --set-exit-if-changed lib test
flutter analyze --fatal-infos
flutter test --coverage
flutter run
```

O `pubspec.lock` faz parte do projeto. Não o apague para resolver builds: isso muda as versões das dependências. `app_links` permanece fixado em **6.3.2**.

Para Android:

```sh
flutter build apk --release
```

Para iOS, em um Mac com Xcode e CocoaPods:

```sh
flutter build ios --release --no-codesign
flutter build ios --simulator --debug
```

O build sem assinatura para dispositivo serve para verificar a compilação. A instalação no iPhone físico precisa de assinatura. O workflow também disponibiliza uma versão para simulador.

## Supabase

A configuração existente foi preservada. A chave configurada tem papel público `anon`, não `service_role`. A proteção dos dados depende das políticas RLS do banco.

Os scripts pressupõem que as tabelas `categories` e `transactions` já existam. Esta revisão não executou SQL nem alterou o banco remoto. Para uma instalação nova, primeiro confira o esquema base e depois a sequência documentada em `docs/ANALISE.md`.

## Atualizar o GitHub no Windows

**Extraia este pacote. Envie os arquivos extraídos; não apenas o ZIP.**

Com GitHub Desktop, clone o repositório e abra a pasta do clone. Preserve a pasta `.git`. Substitua `flutter_project` e `.github` pelas versões deste pacote, copie o README, `.gitignore` e `docs`, e remova os itens antigos listados em `docs/LIMPEZA.md`. Confira o resumo das mudanças, faça o commit e o push.

Pelo site do GitHub, faça os uploads em lotes separados para evitar o limite de quantidade de arquivos:

1. Dentro de `flutter_project`, envie `lib`, `test`, `assets`, `supabase`, `pubspec.yaml`, `pubspec.lock` e `analysis_options.yaml`.
2. Dentro da mesma pasta, envie `android` e `ios`.
3. Atualize `.github/workflows/build.yml` e os documentos da raiz.

Preserve os caminhos das pastas e remova as cópias antigas da raiz conforme a lista. Upload de novos arquivos não remove automaticamente arquivos antigos.

Acompanhe o workflow **Build FinançaFácil**. Primeiro deve passar **Análise e testes**, depois os builds Android e iOS. Esta revisão não foi enviada ao seu GitHub automaticamente.
