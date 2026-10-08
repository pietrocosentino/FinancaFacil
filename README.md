# FinançaFácil — MVP2 (2.0.0+9)

Projeto completo com importação de Excel, perfil com foto e dados pessoais separados, edição de rendas e despesas confirmadas, recorrências, lembretes e confirmação manual.

## Atualizar no Windows

1. Faça backup da sua pasta FinancaFacil.
2. Extraia o pacote em uma pasta temporária. Copie o conteúdo para C:\Users\pietr\Downloads\FinancaFacil, substituindo arquivos. Preserve .git e flutter_project/android/local.properties. Não crie flutter_project dentro de flutter_project.
3. Se ainda existirem build-apk.yml e build-ios.yml em .github/workflows, remova somente esses workflows antigos; o pacote usa build.yml.
4. No Supabase SQL Editor, execute flutter_project/supabase/importacao_mvp2.sql. Se editar_valores.sql ainda não foi aplicado, execute-o antes. Leia docs/MVP2.md para os pré-requisitos do banco. O SQL não foi executado no seu Supabase automaticamente.
5. Abra FinancaFacil no VS Code. Com o emulador ligado, no terminal PowerShell:

```powershell
cd C:\Users\pietr\Downloads\FinancaFacil\flutter_project
C:\dev\flutter\bin\flutter.bat pub get
C:\dev\flutter\bin\dart.bat format lib test
C:\dev\flutter\bin\flutter.bat analyze --no-fatal-infos
C:\dev\flutter\bin\flutter.bat test
C:\dev\flutter\bin\flutter.bat run --debug -d emulator-5554
```


Pare a execução anterior antes de iniciar novamente. Hot reload não instala o plugin file_picker. Se o emulador tiver outro ID, use o ID listado por flutter devices.

## Usar a importação

Em Finanças, toque em Importar planilha Excel. Baixe o modelo, preencha a aba Lançamentos e escolha o arquivo. Os exemplos ficam na aba Como preencher e não são importados. Corrija as linhas sinalizadas e associe categorias existentes. Confira o resumo e confirme somente os registros desejados.

Todos entram pendentes. Uma conta de 90,60 reais por dez meses cria uma única regra mensal, com lembretes e confirmação a cada mês. Aluguel, água e luz podem ficar com a quantidade de meses vazia, sem data final. O histórico permite desfazer somente lotes inteiramente intactos.

O modelo também acompanha o pacote em flutter_project/assets/import/modelo_financafacil.xlsx. O leitor não executa fórmulas e aceita .xlsx de até 5 MB, com até 500 lançamentos. Categorias novas não são criadas automaticamente.

## Enviar ao GitHub

Depois de validar, envie os arquivos extraídos, não o ZIP. O pubspec.lock anterior não acompanha este pacote; pub get atualiza ou gera o lockfile local, que deve ser incluído no commit.

```powershell
cd C:\Users\pietr\Downloads\FinancaFacil
git status
git add .
git commit -m "Implementa importacao de Excel no MVP2"
git push origin main
```


Se houver erro de Git, pare e leia a mensagem. Não use force push como tentativa de resolver. O workflow verifica Flutter e SQL antes dos builds. Os testes de banco usam Node 22 e PGlite; não conectam ao Supabase remoto.

## Ambiente

Código direcionado a Flutter 3.47.6, Dart 3.13.5 e Java 17. Android: Gradle 8.14.3, AGP 8.11.1, Kotlin 2.2.20, compileSdk 36. iOS mínimo 15 e ciclo UIScene. O APK release ainda usa assinatura de debug para testes; publicação exige assinatura própria. Um build iOS sem assinatura não instala em iPhone físico.

A foto de perfil fica neste aparelho e não é sincronizada com o Supabase. A URL e chave pública anon existentes foram preservadas. A proteção dos dados depende das políticas RLS.

Consulte docs/MVP2.md para regras, resultado dos testes e limites da validação. Os documentos em docs/historico referem-se a versões anteriores.
