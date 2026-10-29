# Ensaios de obtenção de áudio — 27 e 28/10/2026

O usuário pediu testar os caminhos discutidos antes de escolher transferência entre plataformas. Confirmou Premium ativo e autorizou autenticação local. Este relatório distingue importação de catálogo, sessão nativa, obtenção de áudio e geração de arquivo. O produto continua com seu Client ID próprio e a integração Spotify de leitura já validada.

Atualização de 28/10/2026: após o usuário informar que a página não apareceu, foi oferecido um link manual para a tentativa ativa. O usuário concluiu a autorização, o callback chegou e os cinco ensaios terminaram sem timeout. A comparação desta rodada está concluída: todos autenticaram; nenhum produziu áudio utilizável. O timeout anterior era uma pendência de abertura/retorno do navegador, não uma negativa do Spotify ou da conta.

## Escopo e método

Revisões consultadas:

| Projeto | Revisão |
| --- | --- |
| Zotify original | `08d844fe3e644ae6cd9bea34a3b4982e61129f33` |
| Zotify de Googolplexed0 | `b3256a54b7d4969896a636ae181489995297edec` |
| librespot Rust | `99b6088bf3ea028f90192676ac1a337fa4b2ed12` |
| spotDL | `58ced9af69dce17d33ff280bafbcc917a9dba0aa` |

As ferramentas estão fora do executável Flutter. Rust 1.99.1 foi instalado em diretório local, sem alterar o PATH global. librespot 0.8.0 compilou em release com `--locked --no-default-features --features native-tls,rodio-backend`; a CLI enumerou rodio, pipe e subprocess. O exemplo de teste foi compilado separadamente. O fork Zotify 0.21.2 foi instalado em um venv dedicado; sua dependência librespot-python resolveu a revisão `01abfc8ad012dbc40e90417e640faaf271ea2f98`. spotDL 4.6.0 usa yt-dlp 2026.10.26 e FFmpeg 7.1 local neste ensaio.

O primeiro alvo é a faixa Sick Sense, LEAP, duração Spotify 212.000 ms, da playlist Teste indicada pelo usuário. Não foram lidos cookies nem a sessão do D.d. O runner usa nova autorização PKCE, mantém token somente em memória e o entrega por stdin aos filhos. O listener conserva validação de estado, loopback e callback. Logs descartam corpos de respostas, mensagens dinâmicas e identificadores da conta.

O modo padrão de login do fork consulta um Client ID nativo e solicita escopos extensos, além de habilitar escuta em todas as interfaces. Não foi incorporado ao produto. O ensaio substitui somente a obtenção do grant pelo listener restrito e exercita os motores com os tokens novos em memória. Foram comparadas a autorização do cadastro D.d e a identidade nativa padrão do upstream; esta última não constitui uma credencial própria de distribuição do D.d.

## Caminhos diretos — rodada final concluída

Com o cadastro D.d, o librespot abriu uma sessão, mas a leitura nativa de metadados retornou `FailedPrecondition`; não houve arquivo. Os motores Python chegaram a um erro `AttributeError` no caminho de renovação login5, antes do stream. Isso não demonstra uma falha de senha do usuário.

Uma tentativa nativa anterior leu metadados e retornou `AUDIO_UNAVAILABLE`; outra expirou antes de receber autorização. Ambas foram preservadas como histórico. Em 28/10, a nova autorização chegou ao retorno loopback na porta 43822 e a rodada final executou os cinco ensaios abaixo, com sessão nova somente em memória.

| Motor / alvo | Sessão e renovação | Obtenção de áudio | Arquivo utilizável |
| --- | --- | --- | --- |
| librespot Rust / Sick Sense | Sessão, client-token e login5 confirmados; metadados 212.000 ms | `AesKeyError` seguido de falha de leitura/decodificação e `AUDIO_UNAVAILABLE` | 0 bytes |
| librespot Rust / Exit Music (For A Film) | Mesmas etapas confirmadas; metadados 267.186 ms | Mesmo resultado | 0 bytes |
| librespot Rust / Cold | Mesmas etapas confirmadas; metadados 203.633 ms | Mesmo resultado | 0 bytes |
| Motor do Zotify original / Sick Sense | login5 HTTP 200, mensagem `ok`, sessão confirmada | `RuntimeError` em `get_audio_key`, antes de abrir arquivo de saída | 0 bytes |
| Motor do fork OAuth Zotify / Sick Sense | login5 HTTP 200, mensagem `ok`, sessão confirmada | `RuntimeError` em `get_audio_key`, antes de abrir arquivo de saída | 0 bytes |

No Rust, o diagnóstico aponta `core/src/audio_key.rs:63`: o caminho do pacote `PacketType::AesKeyError`. O player tenta continuar sem a chave e termina em erro de leitura em `playback/src/player.rs:1198`, depois informa indisponibilidade. Nos dois motores Python, o traceback aponta o ramo de `get_audio_key` que lança erro após não receber uma chave utilizável. Não foram registrados valores de chaves, tokens ou mensagens dinâmicas do provedor.

Assim, nesta rodada a falha ocorre depois da autenticação, na obtenção da chave necessária para o áudio. A evidência não determina a causa interna do serviço, nem demonstra impossibilidade para todo o catálogo, outras versões ou outros ambientes. Também não equivale a testar todas as opções de CLI e formatos dos projetos. O resultado suficiente para o produto é que os motores avaliados não comprovaram um caminho direto utilizável neste ambiente. Não foram implementados contornos para esse erro.

Todos os cinco processos terminaram sem timeout, com zero bytes de áudio. O código de saída do harness pode ser zero mesmo após um evento de falha; a avaliação usa eventos e arquivo produzido. As repetições de avisos do decoder foram agregadas por posição no código em um relatório compacto. O runner passou a agregar esses avisos também nas execuções futuras, evitando listas extensas de entradas repetidas.

Rodadas de instrumentação com erro no próprio observador Python foram descartadas como prova de falha do provedor. Esses erros foram corrigidos sem alterar o motor de autenticação ou de áudio. Não interpretar saída de processo zero como áudio obtido: os eventos da etapa é que definem o resultado.

## Alternativa externa já verificada

spotDL executou a busca e obtenção da primeira faixa, com configuração vazia, sem autenticação e sem cookies. O log identificou a fonte real como [YouTube Music](https://music.youtube.com/watch?v=t6mBCPA2eCQ), e não Spotify.

Verificação independente com Mutagen e decodificação integral por FFmpeg:

| Propriedade | Resultado |
| --- | --- |
| Arquivo | Sick Sense.mp3 |
| Tamanho | 3.520.263 bytes |
| Duração | 212,040 s; diferença de 0,040 s para o catálogo Spotify |
| Áudio | MP3, 128 kbps, 48 kHz |
| Tags | Sick Sense / LEAP / Dark Habits |
| Capa embutida | 1 quadro APIC, 122.310 bytes |
| Decodificação completa | FFmpeg terminou com código 0 |
| SHA-256 | `9e4f6900127f90765f37f627cea9a22b9844076a068751db0043a3cf71a6024f` |

Tags e duração compatíveis são evidência útil, mas não uma comparação acústica com o master Spotify. Metadados copiados do Spotify não transformam a fonte do áudio em Spotify.

### Playlist completa pela alternativa

O spotDL concluiu 10/10 arquivos em 258,9 segundos, usando fontes YouTube/YouTube Music, sem conta ou cookies. A inspeção independente encontrou capa e decodificação completa nos dez. Nove tinham diferença de duração inferior a dois segundos; a primeira escolha para Escapism., posição 7, tinha 193,608 s contra 189,889 s do Spotify. Ela foi marcada para revisão, mesmo com título e artista esperados nas tags.

Uma busca explícita no catálogo YouTube Music encontrou a faixa de Father Of Peace, álbum Escapism., duração de catálogo 3:10, ID `gEJaZLnXsIY`. A nova obtenção vinculou explicitamente esse endereço à faixa Spotify original, sem cortar ou acelerar o áudio. O MP3 resultante tem 189,936 s, diferença de 0,047 s, e uma capa APIC. O candidato anterior foi preservado entre os artefatos de pesquisa.

Os dez arquivos finais foram copiados para `C:\Users\gustavoborges\Downloads\Definitive Downloader\Testes\Spotify - Teste - fontes YouTube`, com nomes numerados e `Teste.m3u8` com dez entradas na sequência original. Uma nova verificação dos arquivos exportados confirmou 10/10 decodificações, 10/10 capas e nenhuma posição faltante ou fora do limite de duração adotado. A maior diferença foi 0,54 s. Isso valida os arquivos e a compatibilidade dos metadados/durações deste ensaio, sem garantir identidade acústica ou sucesso em outras playlists.

Evidências:

- `evidencias/spotify-spotdl-live.log`: primeira faixa.
- `evidencias/spotify-spotdl-playlist-live.log`: processamento de dez faixas e suas fontes reais.
- `evidencias/spotify-spotdl-corrected-07.log`: candidato corrigido de Escapism.
- `evidencias/spotify-alternative-playlist.json`: verificação inicial que sinalizou a posição 7.
- `evidencias/spotify-alternative-final.json` e `spotify-alternative-final-verification.json`: resultado exportado e sua verificação independente.
- `evidencias/spotify-audio-sources.json`: revisões dos repositórios.
- `evidencias/spotify-direct-native.log`: histórico da tentativa que expirou; não é prova de execução dos motores.
- `evidencias/spotify-direct-final-2026-10-28.json`: cinco ensaios concluídos, eventos, locais de diagnóstico agregados e hashes dos relatórios brutos locais; sem segredos.

## Caminhos oficiais e limites de cobertura

- [Web API](https://developer.spotify.com/documentation/web-api): leitura real de playlist já confirmada; não há operação documentada de exportar faixa completa como MP3.
- [Web Playback SDK](https://developer.spotify.com/documentation/web-playback-sdk): interface de reprodução em navegador; a documentação não oferece exportação de arquivo. Não foi implementado um player Web neste ensaio.
- [Offline Premium](https://support.spotify.com/us/article/listen-offline/): reprodução offline pelo cliente Spotify, sem integração documentada de exportação para o D.d. O cache do cliente oficial não foi inspecionado ou modificado.
- [librespot](https://github.com/librespot-org/librespot), [Zotify original](https://github.com/zotify-dev/zotify), [fork OAuth](https://github.com/Googolplexed0/zotify) e [spotDL](https://github.com/spotDL/spotify-downloader): foram avaliadas as famílias discutidas, com testes de execução conforme descrito acima. Isso não equivale a testar todos os forks ou serviços de terceiros existentes na internet.

Não foi gravado áudio do sistema: uma captura geral poderia incluir sons de outros aplicativos e não comprovaria exportação do arquivo da plataforma. Não foram criados contornos para respostas de acesso negado, alteradas proteções ou aceitos certificados inválidos. Mobile não foi executado nesta investigação Windows.

Ferramentas reproduzíveis em `tools/spotify_probe/`. Resultado da comparação no Windows: alternativa externa validada para dez arquivos com capa e playlist ordenada; cinco ensaios diretos concluídos sem produzir áudio utilizável. Para a primeira função musical do D.d, priorizar importação Spotify seguida de correspondência, revisão e obtenção por fonte externa identificada. Os motores experimentais não foram incorporados ao D.d; o app continua com as capacidades descritas no README.
