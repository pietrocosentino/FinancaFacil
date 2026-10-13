# Validação ampliada — 13/10/2026

## Executado nesta revisão

278 verificações PostgreSQL passaram em PGlite local, com IDs UUID e inteiros. Incluem autorização por usuário, importação, atomicidade, duplicatas, desfazer protegido, exclusão mensal, encerramento e limites. Os cenários novos usam 500 linhas fictícias, erro na última linha e tentativa de 501 linhas.

Tempo total do cenário de carga (importar + reenvio + desfazer + falhas): UUID 1048 ms; inteiro 924 ms. Não representa latência da nuvem, concorrência real PostgreSQL nem desempenho no celular.

46 verificações de contratos dos sete endpoints e variáveis de ambiente passaram. A carga adicional inclui cinco lotes de 100 linhas com gerador determinístico (semente 42), conferência da soma em centavos e 27 variações inválidas, sempre verificando rollback.

## Supabase remoto — executado

Projeto Finança Fácil: ACTIVE_HEALTHY. As sete funções RPC existem, com os parâmetros esperados, search_path restrito e execução bloqueada para anon/permitida para authenticated. As seis tabelas financeiras têm RLS ativo e políticas presentes; isso não substitui teste completo de cada política com sessões reais.

Chamadas HTTP reais a preview_finance_import e delete_finance_entry com chave pública, sem sessão de usuário: ambas retornaram 401. Não houve alteração de dados remotos. Resultados em http-smoke-results.json.

## Criado e ainda não executado nesta revisão

`test/stress_regression_test.dart`: limite Excel 500/501, soma de 100 mil lançamentos, 100 leituras concorrentes com cinco requisições, 1200 parcelas únicas, calendário 2020–2100, valores não finitos/zero/negativos.

Foram adicionados cinco testes de contrato para HTTP 401/403/429/500/503 e nova tentativa idempotente. O SDK Flutter não está instalado neste ambiente; a tentativa de obtenção do SDK retornou 404. Os números de testes Flutter das entregas anteriores não são uma execução desta revisão. A revisão remota verificou estrutura/permissões SQL e duas chamadas HTTP sem sessão. Nenhum teste com usuário autenticado ou em aparelho foi realizado.

## Execução completa no Windows

Na raiz do projeto, execute no PowerShell: `powershell -ExecutionPolicy Bypass -File .\tools\validation\run-tests.ps1`. O script usa C:\dev\flutter\bin\flutter.bat; para outro SDK, passe `-Flutter CAMINHO`. Requer Node/npm. Ele interrompe na primeira falha e salva logs, cobertura e resultado do build Android em test-results. O APK fica no diretório habitual do Flutter. O build iOS exige macOS e está no workflow. O script não foi executado neste Linux sem Flutter/PowerShell.

## Como executar

Na raiz: `npm ci --prefix tools/database` e `npm test --prefix tools/database`.
Na pasta flutter_project: `flutter pub get`, `flutter analyze --no-fatal-infos` e `flutter test --coverage`.
O workflow existente executa banco, análise, suíte Flutter e cobertura antes do build.

## Ambiente e endpoints

Os endpoints RPC existentes estão descritos em `docs/endpoints.openapi.json`. Eles são publicados pelo Supabase ao executar os scripts SQL já fornecidos; não foi criado outro servidor nem aplicado SQL remoto nesta revisão.

Copie `env.example.json` para `env.local.json`, preencha URL e chave pública e rode:
`flutter run --debug -d emulator-5554 --dart-define-from-file=env.local.json`.
O arquivo `.env.example` documenta as variáveis; Flutter não lê `.env` automaticamente. Sem parâmetros, permanece a configuração pública atual para compatibilidade. Nunca coloque service_role ou senha do banco no app. As alterações de variáveis exigem reconstrução.

## Homologação pendente

- Android e iOS: compilação, instalação, seletor de arquivo e notificações reais.
- Telas pequenas/fontes ampliadas, temas claro/escuro, teclado e leitor de tela.
- Login, recuperação, troca de conta e expiração da sessão.
- Finanças cadastra; Extrato consulta/edita/exclui; perfil abre sobre a tela atual.
- Perda de rede durante gravação e retomada; cliques repetidos na confirmação.
- Planilhas inválidas, fórmulas, datas/valores brasileiros e categorias incompatíveis.
- Importação de 500 linhas em homologação e isolamento entre duas contas fictícias.
- Concorrência real de duas importações com mesmo hash e duas edições do mesmo mês.
- Medição de memória/CPU e fluidez em modo profile no aparelho, com histórico extenso.

Não há promessa de todos os cenários possíveis: testes locais não substituem validação nativa, rede e banco real.

## Correção após análise no Windows

Corrigidos os oito avisos reportados: bloco no leitor Excel, initialValue nos três dropdowns e ordenação dos imports no teste de carga. O runner captura o código de saída mesmo quando o Windows PowerShell 5.1 recebe stderr nativo. A análise Flutter e o script PowerShell corrigidos ainda precisam ser reexecutados no Windows.
