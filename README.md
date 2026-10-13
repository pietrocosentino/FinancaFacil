# FinançaFácil — MVP2 (2.0.7+16)

Projeto completo com todas as alterações solicitadas: importação de Excel, ações compactas, foto e nome fixos no cabeçalho, menu extensível, dados pessoais separados com edição via Alterar, exclusão de lançamentos, edição de valores e recorrências.

Rendas recorrentes são consideradas recebidas automaticamente na data cadastrada, sem integração bancária. Rendas futuras permanecem previstas. Despesas e rendas avulsas mantêm confirmação manual. Excluir somente este mês impede que o lançamento reapareça; encerrar a recorrência preserva o histórico. O cadastro concluído oferece Sair e Cadastrar outra.

O repositório financeiro compartilha consultas em memória por conta/revisão por até dois minutos, invalidando dados após alterações, atualização manual, retomada do app ou troca de conta. A foto é carregada uma vez e decodificada em tamanho reduzido. E-mail permanece identificação da autenticação; Nome e Telefone são editáveis.

Validação: 191 testes Flutter passaram na cópia adaptada ao SDK 3.24.5 disponível, com 98 verificações PostgreSQL para IDs UUID e inteiro. Build Android/iOS no Flutter 3.47.6 e medição de desempenho real ainda precisam ser validados no seu ambiente.

## Atualizar no Windows

1. Faça backup da sua pasta FinancaFacil.
2. Extraia o pacote em uma pasta temporária. Copie o conteúdo para C:\Users\pietr\Downloads\FinancaFacil, substituindo arquivos. Preserve .git e flutter_project/android/local.properties. Não crie flutter_project dentro de flutter_project.
3. Se ainda existirem build-apk.yml e build-ios.yml em .github/workflows, remova somente esses workflows antigos; o pacote usa build.yml.
4. No Supabase SQL Editor, execute flutter_project/supabase/excluir_lancamentos.sql. Esse é o novo script para exclusão e encerramento. Se os anteriores ainda não foram aplicados, execute primeiro recorrencia.sql, editar_valores.sql e importacao_mvp2.sql, nessa ordem. Os scripts não foram executados no seu Supabase automaticamente.
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

## Correção 2.0.5

O clique na foto abre um menu modal sobre a tela atual, com botão Fechar menu. Os dados pessoais abrem dentro do menu, sem substituir a aba principal. Cinco testes de navegação e perfil passaram na cópia de compatibilidade; build nativo não executado neste ambiente.

## Ajuste visual 2.0.6

Nome FinançaFácil visível no cabeçalho e botão Adicionar centralizado com largura conforme o texto, mantendo área de toque de 48 pixels. Sete testes de perfil e ações visíveis passaram na cópia de compatibilidade. Build nativo não executado.

## Navegação 2.0.7

Quatro abas: Início, Finanças (cadastro de conta, renda e importação), Extrato (consulta, filtros, confirmação, edição e exclusão) e Perfil. Cadastro de renda abre com o tipo Receita selecionado. As regras financeiras e de recorrência continuam iguais. A suíte completa passou com 193 testes na cópia de compatibilidade; build nativo não executado.

## Testes ampliados e ambiente
Consulte `docs/TESTES-REGRESSAO.md` e `docs/endpoints.openapi.json`.
