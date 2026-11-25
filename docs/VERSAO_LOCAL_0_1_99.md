# 0.1.99 — Áudio local em vários formatos e conversão para MP3

Entrega local Windows 0.1.99+100. Sem publicação ou trabalho no Android nesta etapa.

## Importação e reprodução

O seletor **Adicionar arquivos de áudio**, o arraste de arquivos e a importação de pastas passam pelo mesmo conjunto de formatos: MP3, FLAC, WAV, M4A (AAC/ALAC), AAC, OGG, Opus, WMA, AIFF/AIF, APE e WavPack/WV. O decodificador confere o conteúdo e a duração; uma extensão aceita não transforma arquivo corrompido ou vídeo em áudio compatível.

A importação mantém uma cópia numerada na pasta da playlist, conserva o original e registra a faixa como mídia local concluída. A reprodução usa o arquivo local e os controles já existentes do player. Limites: 2 GiB por arquivo, 10 GiB por lote, 100 arquivos avulsos ou 10.000 faixas na importação de pasta. Não há transcodificação automática na importação.

FLAC tem leitura limitada de comentários Vorbis (título, artista, álbum) e capa PNG/JPEG embutida. Outros contêineres usam metadados textuais do decodificador quando não há ID3. Não se escreve nas tags originais. A recuperação de substituições explícitas aceita também os formatos novos, conservando o diário e as verificações de propriedade dos arquivos.

## Converter para MP3

Disponível em **Informações** e no menu de clique direito da faixa local concluída, quando o arquivo não é MP3. O usuário escolhe 128, 192, 256 ou 320 kbps e o destino no seletor de salvar. O FFmpeg já distribuído com o Windows gera uma cópia estéreo a 48 kHz, inclusive a partir de FLAC multicanal/alta resolução. A conversão para MP3 tem perdas; não altera o original nem substitui automaticamente a entrada na playlist.

O processo usa argumentos estruturados, demuxer fixo por formato, acesso apenas a arquivo/pipe e processo próprio cancelável. Valida a duração de saída e publica somente após sucesso. Recusa sobrescrever arquivos existentes. Cancelamento/falha limpa somente o staging que aquela conversão criou. Os metadados textuais são transferidos quando suportados; capa embutida não é copiada para o MP3 nesta versão. O MP3 exportado pode ser adicionado normalmente à playlist depois.

## Validação

Análise sem problemas. Essenciais e focados: 73 testes aprovados, com um ensaio antigo dependente de entrada externa ignorado. Os testes de codec/conversão usam exclusivamente arquivos gerados pelo FFmpeg em pasta temporária: FLAC 5.1/96 kHz, WAV 24 bits, M4A/AAC, OGG/Vorbis, Opus, WMA e AIFF. Importaram e reproduziram pelo motor local com volume zero; a posição avançou em cada formato. A conversão FLAC → MP3 preservou o hash do original, os registros da playlist e o título.

Também passaram cópia/ordem/prioridade local, comentários/capa FLAC com entrada truncada, recusa de sobrescrita, cancelamento prévio, cancelamento do seletor e diálogo em 390/900 px, além dos contratos existentes de biblioteca, player, duplicatas e capas. Sem emulador, conta de plataforma ou arquivos reais recebidos pelo usuário. Os resultados não equivalem à validação do acervo pessoal ou de todo perfil de codec existente; APE/WV têm caminho implementado, sem fixture de codec nesta rodada.

Compilação e instalador Windows concluídos. Versão 0.1.99+100 instalada e iniciada; instalador copiado ao compartilhamento, com SHA-256 `88d44447ff71c9052154a3c4502deaf0ef47c6a84f2e46d4f1c08b74a87955fe`. Sem publicação no GitHub.
