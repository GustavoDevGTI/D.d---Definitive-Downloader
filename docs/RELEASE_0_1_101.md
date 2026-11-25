# Definitive Downloader 0.1.101 — Windows

Consolida as entregas locais 0.1.96 a 0.1.101 no instalador Windows x64. Android permanece pausado, sem APK novo nesta publicação.

## Mudanças

- Importação e reprodução de arquivos de áudio locais em formatos como FLAC, WAV, M4A, AAC, OGG, Opus, WMA e AIFF, por seletor, arraste ou pasta. Leitura de título, artista e capa embutida em FLAC.
- Conversão opcional para MP3 pelo clique direito da faixa ou pela aba Informações, com qualidade de 128 a 320 kbps e destino escolhido. Preserva o original e a entrada na playlist; recusa sobrescrever um arquivo existente.
- Revisão de correspondência de uma faixa selecionada, inclusive já concluída, sem trocar automaticamente sua fonte ou arquivo. Retorno às coleções também em Capturar áudio e Downloads quando houver playlist aberta.
- Janela de conexão Deezer mais compacta. Após inserir playlist Spotify/Deezer, **Deixar para mais tarde** adia a conexão e permite continuar. Ao abrir por **Conectar Deezer**, permanece **Cancelar**. Botões sociais indisponíveis no formulário de entrada por e-mail/senha.
- Tratamento de transações SQLite preserva o erro original em falhas de limpeza; Windows usa a biblioteca SQLite distribuída com o app. Melhorias no uso de bibliotecas anteriores.
- Instalador mantém a identidade e o diretório da instalação anterior, com atalho de desinstalação no menu Iniciar. Biblioteca e mídias pessoais não são removidas pelo instalador.

## Validação e limites

Análise e testes focados das entregas locais aprovados. Na consolidação, a regressão offline aprovou **294 testes Dart** (3 opcionais ignorados) e **26 testes Python** (1 ignorado). O motor foi executado separadamente em ambiente privado com as dependências fixadas do projeto, pois o runtime padrão havia sido renovado e não continha esses módulos. O ensaio sintético de áudio local/conversão também foi habilitado na regressão.

Áudio local/conversão validado com arquivos sintéticos, incluindo FLAC 5.1/96 kHz. Não foram usados arquivos reais do usuário. MP3 exportado é estéreo a 48 kHz, com perdas; a capa embutida não é copiada para ele nesta versão. APE/WV têm caminho de suporte implementado, sem fixture de codec nesta rodada. Não há novo ensaio de login real Deezer. A execução do desinstalador isolado não foi validada; presença e atualização foram verificadas.

O pacote mantém o gateway de playlists já configurado no produto. Login e bibliotecas pessoais ficam fora dos arquivos publicados. O arquivo **SHA256SUMS.txt** acompanha o instalador.
