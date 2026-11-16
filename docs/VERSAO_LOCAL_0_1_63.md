# 0.1.63+64 — buscar músicas de uma playlist Spotify

Em **Músicas → Coleções**, cole um link Spotify de playlist e toque em **Importar por link**. Se a Deezer estiver desconectada, o D.d pede a conexão primeiro. Em **Abrir TuneMyMusic**, o D.d copia o link para a área de transferência e abre o serviço no navegador. Entre no Spotify, cole o link no TuneMyMusic, selecione a playlist e exporte para CSV.

Volte ao D.d e escolha **Usar CSV exportado**. No Android, também é possível enviar o arquivo pelo sistema quando o navegador oferece **Abrir com** ou **Compartilhar** com um tipo CSV reconhecido. O D.d pede confirmação antes de importar um arquivo recebido de outro app.

O CSV traz a lista para a biblioteca. As faixas entram na ordem do arquivo, com repetições e com os identificadores que o arquivo fornecer. Exporte uma playlist por vez. O D.d abre a Conferência, consulta Deezer, YouTube Music e SoundCloud pelo título e artista e apresenta os resultados por faixa. Para faixas sem duração conhecida, o áudio com título e artista compatíveis fica para revisão antes de sugerir videoclipes. Download depende de uma ação posterior da pessoa.

O TuneMyMusic é usado pela [exportação pública](https://www.tunemymusic.com/transfer/spotify-to-file). A pessoa autoriza o acesso no Spotify e escolhe a exportação. O D.d lê o arquivo recebido localmente. A ligação direta com a API Spotify continua no piloto separado. Sem migração de schema.

A análise estática passou. No conjunto essencial e focado, 46 testes passaram na primeira rodada e um excedeu o tempo limite enquanto os builds e o emulador rodavam. Esse teste passou na repetição isolada. Os testes de importação e correspondência usaram CSV e resultados de busca sintéticos; não houve autorização de contas nem exportação real do TuneMyMusic.

No emulador com o D.d 0.1.63+64, **Importar por link** mostrou **Conectar Deezer** primeiro. O Android reconheceu o app como destino de **Abrir com** e **Compartilhar** para `text/csv`. Um CSV sintético aberto por URI do MediaStore mostrou **Conferir faixas**, e a confirmação pediu Deezer antes de importar. A conexão foi cancelada no ensaio. APKs locais:

| Plataforma | Tamanho | SHA-256 |
| --- | ---: | --- |
| Android ARM64 | 65,5 MiB | `327cc7e0c43694b4bd6635b6b3fe072db8d025259e865243ae245e2ac63b5215` |
| Android x86-64 | 68,6 MiB | `5e503a9ff426ef4fb0245ce0a11e7270cc11eb6dbfbd665a93fb5a8f6806f987` |

O Windows foi compilado e atualizado localmente para 0.1.63+64. SHA-256 do instalador: `12bc697f8b70fd68d51b11e723cd0c26e1429484cb2ea4a40b924b9a4594c43d`. Nenhuma release ou tag foi publicada.
