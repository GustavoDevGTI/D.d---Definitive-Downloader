# Playlists públicas e campo de importação — 0.1.45 local

Etapa inicial autorizada após a matriz de plataformas de 05/11/2026: completar a entrada de playlists Deezer, YouTube e YouTube Music antes de ampliar para novos serviços. Pedido posterior: retirar os nomes de plataformas do campo. Releases permanecem suspensas.

## Comportamento

- Importar playlist despacha Spotify, SoundCloud, Deezer, YouTube e YouTube Music. O campo mostra somente **“Cole o link da playlist”**, com o rótulo existente Link da playlist ou faixa; sem lista de plataformas dentro dele. Faixa SoundCloud continua aceita nesse fluxo anterior.
- Deezer: URL completa de playlist, inclusive com prefixo de idioma; leitura paginada em lotes de até 100, conferência do total e checksum ao terminar. Nunca seguir `next` para outro destino: reconstruir endpoint e índice localmente.
- YouTube/YouTube Music: playlists públicas finitas; consulta pública web sem conta/cookies. A interface YouTube Music permanece uma origem distinta. Leitor contempla renderers antigos e o formato novo `lockupViewModel`, continuations novas/antigas e tipos ATV/OMV. Identidade da playlist deve corresponder à solicitada.
- Todas as páginas são carregadas na importação, com limite de 10.000 ocorrências, cancelamento e progresso. Não depende de rolar a tabela. Continuation repetida, resposta desconhecida, truncamento detectado ou mudança Deezer abortam a importação; a coleção existente não é alterada. Listagem visual continua virtualizada.
- Preservar ordem e repetições. Fontes dessas playlists representam a versão indicada pelo usuário e são fixadas por ocorrência; pesquisa e fallback não trocam por outra versão. Vídeo musical escolhido na playlist YouTube é manual, distinto de vídeo sugerido por busca automática, que mantém aprovação específica. O motor reconfere identidade, duração, disponibilidade e bloqueio de lives/filmes antes de publicar mídia.
- Entradas indisponíveis ou sem duração musical confirmada permanecem com posição/referência e motivo para conferência. O importador não cria fonte pronta para essas entradas. Resposta do catálogo não comprova áudio baixável.
- Sem motor musical, a fonte permanece pendente. Deezer requer também conexão existente. Ao reabrir uma coleção após obter esses requisitos, preparar somente fontes manuais válidas, sem pesquisa/substituição, download automático ou aprovação de uma revisão. Fontes marcadas para revisão/recuperação não são promovidas por esse caminho.
- Nenhum download inicia ao importar. Para faixas prontas, selecionar e usar Baixar; pendências exigem escolha na conferência. Nenhum arquivo antigo é renomeado/movido.

## Estrutura

`PublicPlaylistLink` valida/canoniza a origem; `DeezerPlaylistCatalog` e `YouTubePlaylistCatalog` leem a lista; `YouTubePlaylistPage` interpreta páginas e produz `TrackDraft`. Reutilizar o transporte limitado de catálogo: HTTPS, origens/endpoints explícitos, sem redirecionamentos, sem credenciais, timeout por resposta e teto de 2 MiB (catálogo) / 8 MiB (browse). JSON e parsing YouTube rodam em isolate com entrada escalar/serializável, sem capturar HttpClient/SecurityContext/callback de UI.

O controlador só despacha e coordena progresso/cancelamento. Widgets não fazem HTTP, SQL ou execução de processo. Não houve dependência nova nem alteração do motor Python. Schema continua **14**; não é necessária migração. Importadores e regras são Dart compartilhado, sem SDK específico de desktop. Execução Android/iOS não validada nesta etapa; seus motores musicais continuam pendentes.

O YouTube é um leitor de interface web interna, sujeito a mudanças; não é apresentado como a API pública oficial nem exige cadastro Google só para ler uma playlist pública. A implementação foi confrontada com as respostas reais e o [leitor upstream](https://github.com/yt-dlp/yt-dlp/blob/master/yt_dlp/extractor/youtube/_tab.py); a [API pública de listas](https://developers.google.com/youtube/data/reference/rest/v3/playlistItems/list) é um caminho alternativo com cadastro/cota próprios. Não foram reaproveitados IDs de aplicativos de terceiros.

## Verificação realizada

Onze contratos novos passaram: canonicalização/validação de destino, paginação, repetição, indisponível, snapshot Deezer alterado, próxima página alheia, truncamento/loop/identidade YouTube, formato moderno, cancelamento, persistência da autorização manual e ausência de motor, retomada após conexão sem buscar outra fonte.

Ensaio real optativo separado, pelo transporte Dart e `LibraryController.importPlaylist`, com SQLite em pasta de evidência isolada:

| Origem | Lista pública | Resultado |
| --- | --- | --- |
| Deezer | En mode 60, ID 908622995 | 50 ocorrências; nove indisponíveis marcadas pendentes; referências e contagem persistidas. |
| YouTube | Pop Music Playlist, ID PLMC9KNkIncKtPzgY-5rmhvj7fax8fdxoj | 200 ocorrências, incluindo as duas que a consulta inicial padrão ocultava; continuations lidas e total conferido. |
| YouTube Music | Mesma referência de lista | 200 ocorrências; fonte da interface musical preservada. |

O ensaio passou em cerca de dez segundos, sem conta/cookies, áudio ou alterações à biblioteca do usuário. Todos os registros ficaram no banco isolado. A consulta inicial YouTube trazia 198 entradas; o parâmetro de inclusão de vídeos ocultos usado no upstream passou a retornar as 200. Isso não comprova a disponibilidade de áudio de cada uma: no retorno observado, elas tinham metadados; a validação final continua com o motor no download.

Limites: playlists privadas, mixes/radio dinâmicos, outros tipos de URL, todos os catálogos/regiões e variações web não foram validados universalmente. O leitor não promete recuperar metadados que a plataforma não fornece. As demais plataformas da matriz continuam pesquisa, sem anúncio de integração nesta versão.

Suíte determinística completa: **197 testes Flutter aprovados**, dois ensaios de rede optativos ignorados deliberadamente. O ensaio real de importação descrito acima foi executado separadamente e aprovado. Formatação conferida; análise estática final sem problemas; Windows Release compilado em 58,7 s. A suíte completa antecedeu somente a atualização do número da versão e a remoção de um import redundante do teste; nenhuma regra de execução mudou depois dela.

Inspecionadas capturas em **1360 e 390 px**, sem overflow/controles inacessíveis na área alterada; os testes de layout também exercitaram 1920, 900 e 320 px. Dados dessas capturas são fixtures de layout, distintos das importações públicas reais.

Entrega local **0.1.45+46** instalada e reaberta em Músicas → Coleções. Registro Windows confirmado em 0.1.45, atalho da Área de Trabalho apontando para o executável instalado, campo em foco conferido na janela nativa sem nomes de plataformas. Instalador compilado em 53,688 s; SHA-256 guardado com as evidências locais. Fontes/recursos/testes do staging comparados com o workspace (177 arquivos); binários instalados conferidos com o pacote, incluindo o motor SoundCloud 0.1.44 preservado sem recompilação ou substituição por staging antigo.

Backup anterior à atualização preservado fora do repositório. Verificação antes/depois e após reinício: schema 14, `quick_check` íntegro, sete tabelas com as mesmas contagens/valores anteriores (exceto a revisão derivada de lista, omitida do comparador), incluindo 2 coleções, 242 ocorrências e 11 registros de histórico; IDs de fonte incluídos na comparação. Não houve importação de teste ou download na biblioteca real. Sem release, tag ou push.
