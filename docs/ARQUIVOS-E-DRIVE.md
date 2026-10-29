# Arquivos do aparelho e Google Drive

A planilha abre pelo seletor nativo de documentos. A foto oferece Galeria e Arquivos do aparelho ou nuvem. A leitura aceita stream sem caminho local e limita o tamanho real, além do tamanho informado pelo provedor. Fotos de até 5 MB são reduzidas para até 256 pixels no maior lado; o armazenamento de avatar continua limitado a 200 KB e restrito ao aparelho/conta.

A integração é com os provedores de arquivos do sistema. Não há login Google dentro do FinançaFácil, não se lista toda a conta e não há sincronização automática: o app chama o seletor de arquivos do Drive e recebe somente o arquivo escolhido. Para isso, o Drive precisa estar instalado, com uma conta Google conectada e o arquivo disponível para essa conta.

## Emulador Android

1. Use um dispositivo virtual com imagem Google Play no Android Studio (ícone Play Store). Uma imagem somente Google APIs não garante a presença da Play Store.
2. Entre em uma conta de teste na Play Store e no aplicativo Google Drive; confirme que a conta aparece no Drive e que o arquivo está acessível.
3. No FinançaFácil, abra a importação e escolha Google Drive. Se o Drive fechar sem abrir o seletor, confirme a conta no próprio Drive e abra-o uma vez antes de tentar novamente.
4. Para foto: Perfil → Alterar foto → Google Drive.
5. Uma planilha nativa Google Sheets precisa ser exportada como Excel .xlsx antes da importação. Não é um arquivo Excel enquanto permanece no formato nativo.

Para arquivos locais, arraste o Excel ou imagem para o emulador; consulte Downloads no seletor.

## Homologação

Testar arquivo local e Drive; cancelar; perda de conexão; provedor sem caminho local; arquivo acima do limite; arquivo inválido; foto grande com proporção preservada; troca de conta. Criados sete testes do leitor e três do processamento de foto. Ainda não executados nesta revisão, pois o SDK Flutter está indisponível. Seletores nativos e Drive devem ser validados no aparelho/emulador.
