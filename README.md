# FinançaFácil

Aplicativo Flutter de finanças pessoais com Supabase: contas e rendas avulsas, mensais e parceladas, confirmação de pagamentos, lembretes no aparelho e importação de planilha Excel. Versão 2.1.0+17.

## Funcionalidades

- **Adicionar** (botão no Início e no Extrato): conta ou despesa, renda ou importação de planilha. Categorias próprias podem ser criadas no cadastro.
- **Início:** pendências próximas, resumo de qualquer mês (saldo previsto e confirmado, rendas, contas pagas e a pagar), comparação com o mês anterior e despesas por categoria.
- **Extrato:** lançamentos do mês com filtros por situação e tipo, busca, confirmação individual ou em lote, edição de valor, "Não recebi" para renda mensal, exclusão e encerramento de recorrências.
- **Perfil:** foto (salva só no aparelho), nome e telefone, horário dos lembretes, tema (segue o sistema por padrão) e saída.
- **Sino:** contas atrasadas e dos próximos 3 dias, com confirmação de pagamento.

Regras principais: recorrências são regras projetadas mês a mês, sem parcelas antecipadas; o dia de vencimento é mantido (dia 31 vira o último dia em meses curtos); rendas recorrentes contam como recebidas na data cadastrada, a menos que o mês seja marcado como "Não recebi"; despesas exigem confirmação manual; reajustes valem do mês escolhido em diante e preservam meses já pagos.

## Estrutura

```
flutter_project/
  lib/core          configuração, utilitários de data/dinheiro, tema, composição de serviços
  lib/features      auth, dashboard, transactions, imports, notifications, profile
                    (cada uma com data / domain / presentation)
  lib/shared        layout principal, cabeçalho, diálogos e painéis reutilizáveis
  supabase/         scripts SQL (ordem em supabase/README.md)
  test/             testes Flutter
tools/database      testes do SQL em PostgreSQL local (PGlite)
tools/validation    contratos de API e script de validação para Windows
docs/               análise técnica e de UX, testes, importação, endpoints
```

As telas recebem repositórios pelo construtor; as implementações Supabase são criadas apenas em `main.dart`, `AuthGate` e `MainLayout`.

## Rodar no Windows

```powershell
cd C:\Users\pietr\Downloads\FinancaFacil\flutter_project
C:\dev\flutter\bin\flutter.bat pub get
C:\dev\flutter\bin\flutter.bat run --debug -d emulator-5554
```

Plugins nativos novos exigem parar e rodar de novo (hot reload não instala plugins). Se o emulador tiver outro ID, veja `flutter devices`.

Para validar tudo antes de enviar: `powershell -ExecutionPolicy Bypass -File .\tools\validation\run-tests.ps1` na raiz. Detalhes em `docs/TESTES-REGRESSAO.md`.

## Banco de dados

Execute os scripts numerados de `flutter_project/supabase` no SQL Editor, na ordem de `flutter_project/supabase/README.md`. Um projeto novo é criado do zero a partir de `000_esquema_base.sql`; em um banco existente, aplique de novo `003` e depois `006`.

## Importar planilha

Adicionar → Importar planilha: baixe o modelo, preencha a aba Lançamentos e escolha o arquivo (.xlsx, até 5 MB e 500 linhas). Corrija as linhas sinalizadas, associe ou crie as categorias e confirme. Tudo entra pendente; uma conta de dez meses vira uma única regra mensal. Regras completas em `docs/MVP2.md`.

## Ambiente

Flutter 3.47.6, Dart 3.13, Java 17. Android: compileSdk e targetSdk 36 (exigência atual da Google Play), minSdk 23. iOS mínimo 15.

**Publicar na Play Store:** gere uma chave (`keytool -genkey -v -keystore financafacil.jks -keyalg RSA -keysize 2048 -validity 10000 -alias financafacil`) e crie `flutter_project/android/key.properties` com `storeFile`, `storePassword`, `keyAlias` e `keyPassword`. Os dois ficam fora do Git. Sem eles, o APK de release usa a chave de depuração e serve só para testes. O build iOS do CI não é assinado. URL e chave do Supabase não ficam no código: rode sempre com `--dart-define-from-file=env.local.json` (modelo em `env.example.json`); no CI elas vêm dos Secrets `SUPABASE_URL` e `SUPABASE_ANON_KEY`.

## Documentação

- `docs/ANALISE.md` — análise técnica e de UX, gargalos e próximos passos.
- `docs/TESTES-REGRESSAO.md` — suíte, cobertura e como executar.
- `docs/MVP2.md` — regras da importação de Excel.
- `docs/ARQUIVOS-E-DRIVE.md` — seleção de arquivos e Google Drive no emulador.
- `docs/endpoints.openapi.json` — RPCs usadas pelo app.
