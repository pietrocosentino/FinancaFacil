# FinançaFácil

Aplicativo Flutter de finanças pessoais com Supabase: contas e rendas avulsas, mensais e parceladas, confirmação de pagamentos, lembretes no aparelho e importação de planilha Excel. Versão 2.0.7+16.

## Funcionalidades

- **Início:** pendências próximas, saldo confirmado e previsto do mês, despesas por categoria.
- **Finanças:** cadastro de conta, renda e importação de planilha.
- **Extrato:** consulta por mês, filtros, confirmação em lote, edição de valor, exclusão e encerramento de recorrências.
- **Perfil:** foto (salva só no aparelho), nome e telefone, horário dos lembretes, tema e saída.

Regras principais: recorrências são regras projetadas mês a mês, sem parcelas antecipadas; o dia de vencimento é mantido (dia 31 vira o último dia em meses curtos); rendas recorrentes contam como recebidas na data cadastrada; despesas exigem confirmação manual; reajustes valem do mês escolhido em diante e preservam meses já pagos.

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

Execute os scripts de `flutter_project/supabase` no SQL Editor, na ordem de `flutter_project/supabase/README.md`. Eles pressupõem as tabelas base `categories` e `transactions`, que ainda não estão versionadas neste repositório.

## Importar planilha

Em Finanças → Importar planilha: baixe o modelo, preencha a aba Lançamentos e escolha o arquivo (.xlsx, até 5 MB e 500 linhas). Corrija as linhas sinalizadas, associe categorias existentes e confirme. Tudo entra pendente; uma conta de dez meses vira uma única regra mensal. Regras completas em `docs/MVP2.md`.

## Ambiente

Flutter 3.47.6, Dart 3.13, Java 17. Android: compileSdk 36, minSdk 23, **targetSdk 34**. iOS mínimo 15. O APK de release usa assinatura de debug e o build iOS não é assinado: servem para testes, não para publicação. Para usar outro projeto Supabase, rode com `--dart-define-from-file=env.local.json` (modelo em `env.example.json`).

## Documentação

- `docs/ANALISE.md` — análise técnica e de UX, gargalos e próximos passos.
- `docs/TESTES-REGRESSAO.md` — suíte, cobertura e como executar.
- `docs/MVP2.md` — regras da importação de Excel.
- `docs/ARQUIVOS-E-DRIVE.md` — seleção de arquivos e Google Drive no emulador.
- `docs/endpoints.openapi.json` — RPCs usadas pelo app.
