# Arquivos do aparelho e Google Drive

A planilha abre pelo seletor nativo de documentos. A foto oferece Galeria e Arquivos do aparelho ou nuvem. A leitura aceita stream sem caminho local e limita o tamanho real, além do tamanho informado pelo provedor. Fotos de até 5 MB são reduzidas para até 256 pixels no maior lado; o armazenamento de avatar continua limitado a 200 KB e restrito ao aparelho/conta.

A integração é com os provedores de arquivos do sistema. Não usa OAuth próprio, não lista toda a conta Google e não sincroniza automaticamente. Para Drive aparecer, o aplicativo Drive deve estar instalado, conectado e disponível no seletor.

## Emulador Android

1. Use um dispositivo virtual com imagem Google Play no Android Studio (ícone Play Store). Uma imagem somente Google APIs não garante a presença da Play Store.
2. Abra a Play Store no emulador, entre na conta de teste e instale Google Drive.
3. Abra o Drive e confirme que o arquivo está acessível.
4. No FinançaFácil, abra a importação. No menu lateral do seletor Android, escolha Drive e depois o Excel.
5. Para foto: Perfil → Alterar foto → Arquivos do aparelho ou nuvem → Drive.
6. Uma planilha nativa Google Sheets precisa ser exportada como Excel .xlsx antes da importação. Não é um arquivo Excel enquanto permanece no formato nativo.

Para arquivos locais, arraste o Excel ou imagem para o emulador; consulte Downloads no seletor.

## Homologação

Testar arquivo local e Drive; cancelar; perda de conexão; provedor sem caminho local; arquivo acima do limite; arquivo inválido; foto grande com proporção preservada; troca de conta. Criados sete testes do leitor e três do processamento de foto. Ainda não executados nesta revisão, pois o SDK Flutter está indisponível. Seletores nativos e Drive devem ser validados no aparelho/emulador.
