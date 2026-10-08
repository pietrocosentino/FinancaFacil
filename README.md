# FinançaFácil — 1.3.0+8

Projeto completo: perfil com foto e dados pessoais separados, edição de valores de rendas e despesas confirmadas, opção de atualizar os próximos meses de uma recorrência, lembretes e confirmação manual preservados.

Use Flutter 3.47.6, Dart 3.13.5 e Java 17. Android: Gradle 8.14.3, AGP 8.11.1, Kotlin 2.2.20 e compileSdk 36. O aplicativo mantém targetSdk 34 e assinatura de debug para testes; publicação nas lojas exige configuração própria.

## Instalar no Windows e enviar pelo VS Code

1. Se COMMIT_EDITMSG estiver aberto, escreva uma mensagem na primeira linha, salve e clique em Commit. A primeira linha vazia impede concluir o commit.
2. Faça uma cópia de segurança da sua pasta FinancaFacil antes de substituir os arquivos.
3. Extraia este ZIP em uma pasta temporária. Copie seu conteúdo para C:\Users\pietr\Downloads\FinancaFacil, aceitando substituir arquivos. Preserve a pasta .git e seu android/local.properties. Não crie flutter_project dentro de flutter_project.
4. Se ainda existirem .github/workflows/build-apk.yml ou build-ios.yml, remova somente esses workflows antigos. O pacote usa apenas build.yml.
5. Abra a pasta FinancaFacil no VS Code. No terminal PowerShell:

```powershell
cd C:\Users\pietr\Downloads\FinancaFacil\flutter_project
C:\dev\flutter\bin\flutter.bat pub get
C:\dev\flutter\bin\dart.bat format lib test
C:\dev\flutter\bin\flutter.bat analyze --no-fatal-infos
C:\dev\flutter\bin\flutter.bat test
C:\dev\flutter\bin\flutter.bat run -d emulator-5554
```

O emulador precisa estar ligado. A seleção de foto adiciona um plugin nativo: pare a execução antiga e execute novamente; hot reload não instala plugins.

O lockfile antigo não acompanha o pacote porque as dependências mudaram. pub get gera ou atualiza o pubspec.lock na sua máquina. Inclua esse arquivo no commit após a resolução bem-sucedida. O workflow resolve dependências com pub get e executa análise e testes antes dos builds.

Depois dos testes, envie os arquivos extraídos, não o ZIP:

```powershell
cd C:\Users\pietr\Downloads\FinancaFacil
git status
git add .
git commit -m "Atualiza perfil e edicao de valores"
git push origin main
```

Se o Git disser que faltam nome e email, configure sua identidade com git config user.name e git config user.email, usando seu próprio nome e email. Se o push falhar, copie a mensagem completa; não use force push para tentar resolver.

## Banco de dados

No Supabase, abra SQL Editor e execute flutter_project/supabase/editar_valores.sql para habilitar as correções de recorrências confirmadas. Leia EDICAO-DE-VALORES.txt. O script não foi executado automaticamente no banco remoto. As demais migrações anteriores continuam necessárias para um banco novo; não são recriadas por este script.

A foto é opcional e fica salva neste aparelho, separada por conta. Não é enviada ao Supabase. Dados pessoais permanecem no repositório de perfil existente. Editar um valor não desfaz sua confirmação de pagamento ou recebimento. Em uma renda confirmada, atualizar os próximos meses mantém o mês confirmado com o valor original.

## Validação e limites

Os 129 testes da implementação de perfil e edição de valores passaram no ambiente disponível, com Flutter 3.24.5 e um substituto de teste para image_picker. Eles cobrem regras, interface e contratos HTTP simulados. Não validam a galeria nativa, o banco remoto ou compilação Android/iOS.

Este pacote recebeu depois a adaptação ao Flutter 3.47.6 informado pelo usuário, incluindo CardThemeData, callbacks de navegação, dropdowns, intl e build Android. Não foi possível executar essa versão de Flutter neste ambiente; execute os comandos acima para validar a versão consolidada. O iOS foi adaptado ao ciclo UIScene com registro dos plugins no engine implícito, conforme a documentação Flutter. Build iOS exige Mac/Xcode; instalação em iPhone exige assinatura.

Os documentos antigos em docs/historico referem-se à revisão anterior e não comprovam validação deste pacote.
