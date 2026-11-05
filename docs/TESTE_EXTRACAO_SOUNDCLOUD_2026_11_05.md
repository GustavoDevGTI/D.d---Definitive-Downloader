# Extração real SoundCloud — 05/11/2026

Solicitação: tentar a extração direta após implementar SoundCloud como origem de metadados na 0.1.43. Ensaio isolado do aplicativo, usando o yt-dlp e FFmpeg já presentes no ambiente. Não foram lidos cookies, cofre ou perfis do navegador; nenhuma conta foi usada e nenhuma dependência foi atualizada.

## Resultado executado

Faixa pública [D-D-Dance](https://soundcloud.com/the-concept-band/the-concept-d-d-dance), ID `30510138`. A página informou acesso `ALLOW`, duração completa de **219.747 ms** e uploader The Royal Concept. O artista da gravação não estava confirmado nos metadados; não promovemos o uploader ao campo de artista.

1. Leitura pública de metadados; conferência de ID, acesso e duração antes da transferência.
2. yt-dlp **2026.10.26**, sem cache, cookies, netrc ou login: seleção de áudio sem marcador de prévia e sem DRM anunciado. Formato escolhido `hls_aac_160k`, AAC em M4A via HLS, 160 kb/s anunciados.
3. Arquivo recebido com **4.432.145 bytes**, duração medida de **219.661 ms**. FFmpeg decodificou o arquivo inteiro com `-xerror` sem falha.
4. Conversão pelo FFmpeg para MP3, com título, capa embutida e referência pública da origem em ID3. Uploader registrado separadamente; artista ausente não foi inventado. A conversão não representa ganho de qualidade.
5. MP3 final com **4.933.339 bytes**, duração medida de **219.690 ms** e uma capa APIC. Nova decodificação integral sem falha; título e capa relidos após gravar as tags.

As diferenças para a duração completa informada ficaram abaixo de 0,1 s, dentro do limite existente de 2 s. Esse conjunto verifica arquivo completo compatível com os metadados; não é medição perceptual nem comprovação de identidade com outra gravação.

Execução concluída em aproximadamente **9,44 s**. O arquivo MP3 foi copiado para a pasta de teste em Downloads, com SHA-256 conferido após a cópia. Scripts, JSON sanitizado e mídia ficam em evidência local, fora do repositório. Nenhum arquivo foi publicado ou inserido no histórico/biblioteca do usuário.

## Alcance e próxima integração

O ensaio comprova extração pública de **uma faixa específica**, sem sessão. Não comprova todas as músicas/playlists, conteúdo privado ou premium, acesso geográfico distinto, pausa/retomada, interrupção, renovação de URLs ou execução mobile.

O [extrator upstream](https://github.com/yt-dlp/yt-dlp/blob/master/yt_dlp/extractor/soundcloud.py) já oferece a base para resolver esses streams. A integração no produto ainda exige um provedor próprio, tratamento explícito de completo/prévia/bloqueado, revalidação por ocorrência, progresso/pausa/cancelamento, capas SoundCloud no transporte permitido e testes do arquivo final. O transporte de capas do worker atual aceita apenas as origens anteriores; não foi alterado silenciosamente para executar este ensaio.

Não houve alteração do executável, schema, worker instalado ou regras de fallback. O app permanece em **0.1.43**, sem nova versão/release. Não foram executados testes Flutter porque somente esta documentação foi acrescentada; a validação deste turno foi a transferência e decodificação real descrita acima.
