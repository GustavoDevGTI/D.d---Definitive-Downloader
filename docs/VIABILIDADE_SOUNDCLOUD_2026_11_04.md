# SoundCloud como fonte e origem de playlists

Avaliação de 04/11/2026, sobre a versão local 0.1.42. Pedido: verificar o necessário para usar SoundCloud no mesmo fluxo de Deezer/YouTube Music e aceitar playlists. Esta etapa é pesquisa e ensaio de metadados; não habilita uma nova fonte no app, não altera versão, schema ou motor instalado.

## Resultado

Há caminho técnico para links de faixa, busca, playlists e consulta de versões. O `yt-dlp==2026.10.26` já presente no ambiente/motor possui extratores `soundcloud`, `soundcloud:set` e `soundcloud:search`. Portanto não é necessário acrescentar outro downloader só para estudar esse provedor. Suporte da biblioteca não significa integração concluída no D.d, capacidade mobile ou permissão universal de download. [Código upstream](https://github.com/yt-dlp/yt-dlp/blob/master/yt_dlp/extractor/soundcloud.py).

O app ainda rejeita esse provedor em `MusicLink`, `SourceKind`, parser de candidatos e protocolo do worker. Importação de playlists permanece específica do Spotify; o player também não reconhece referências SoundCloud. A inclusão é transversal, não se resolve adicionando um domínio à caixa de links.

## Dois caminhos de acesso

| Caminho | Requisitos e alcance | Limitação para o produto |
| --- | --- | --- |
| API oficial | Aplicativo próprio, Client ID/Secret; cadastro atualmente exige Artist Pro. Público usa Client Credentials; acesso da conta usa OAuth/PKCE. | O segredo exigido também para desktop/mobile deve ficar em serviço seguro, fora do executável. Não executamos cadastro ou autenticação. |
| Extrator existente no yt-dlp | No ensaio público, busca, lista e faixa responderam sem conta ou credenciais próprias. | Usa interface web interna, sujeita a mudanças; não substitui cadastro OAuth próprio nem comprova acesso privado, reprodução ou download. |

Fontes oficiais: [cadastro](https://developers.soundcloud.com/docs/api/register-app.html), [autenticação](https://developers.soundcloud.com/docs/api/guide#authentication). O ensaio público não leu cookies, cofre ou perfis do navegador; cache do extrator desativado e nenhuma dependência atualizada.

Os termos da **API oficial** restringem armazenamento/offline e agregação de reprodução com outros serviços, além de exigirem respeito às limitações do uploader. Assim, esse caminho não deve ser prometido como motor genérico de exportação de MP3. A disponibilidade técnica do extrator é uma constatação distinta dessas condições. [Termos, Content and Privacy / Caching and Downloading](https://developers.soundcloud.com/docs/api/terms-of-use).

O site oferece arquivo original por faixa quando o criador habilita o download e o usuário entra na conta; não oferece um arquivo de download da playlist inteira. Importar a lista no D.d e resolver cada ocorrência são operações distintas. [Ajuda oficial](https://help.soundcloud.com/hc/en-us/articles/115003448787-Downloading-tracks).

## Ensaios reais executados

Scripts e JSON sanitizado estão em evidência local privada, fora do repositório. Foram consultas de metadados/formato com `download=False` e `skip_download=True`, sem transferência de áudio.

1. Playlist pública [The Royal Concept EP](https://soundcloud.com/the-concept-band/sets/the-royal-concept-ep): título e seis ocorrências retornadas na ordem `75206121`, `47127625`, `47127627`, `30510138`, `47127629`, `47127631`. Segundo ensaio com teto 101 voltou a retornar seis, sem atingir o teto. A referência de testes upstream previa cinco: usar o resultado atual, sem assumir que uma playlist permanece igual ao fixture antigo.
2. Busca pública com dois resultados: IDs `30510138` e `139060543`, títulos, uploaders, referências e durações distintos. Prova de consulta; não prova de matching correto.
3. Faixa pública [D-D-Dance](https://soundcloud.com/the-concept-band/the-concept-d-d-dance), ID `30510138`: título, capa, duração 219,657 s e uploader `The Royal Concept`; campos `artist`/`artists` ausentes. Formatos anunciados HLS AAC em M4A, 96 e 160 kb/s. Não houve escuta, transferência, decodificação ou validação de áudio completo.
4. A tentativa inicial restrita a HTTP MP3 falhou. Com seleção padrão, os metadados anunciaram HLS AAC. Logo não fixar MP3 como requisito da fonte nem interpretar esse primeiro erro como faixa ausente. A saída MP3 exigiria transcodificação, sem ganho de qualidade.

A listagem plana da playlist devolveu IDs/referências, sem título, artista e duração por faixa; a última ocorrência veio somente por ID/API. O importador precisa completar metadados antes de considerar a importação pronta. Não eliminar entradas incompletas nem fazer essa consulta depender de rolar a tabela.

Não foram testados: playlist privada, login/renovação, link curto, playlist grande ou repetida, indisponíveis, rate limit, reprodução integrada, obtenção de arquivo original/stream ou mobile. A leitura das seis ocorrências não comprova todas essas capacidades.

## Implementação necessária, em ordem

1. **Fonte e links compartilhados em Dart.** Acrescentar `soundcloud` a tipos e validações, referência estável de faixa/playlist e IDs separados da posição. Aceitar `/autor/faixa` e `/autor/sets/lista`; links curtos exigem resolução limitada com revalidação do destino. Links privados podem conter segredo: não persistir como referência pública ou emitir em logs. Configurar acesso privado somente por fluxo próprio, sem procurar cookies existentes.
2. **Adaptador de metadados com capacidades explícitas.** Separar busca, leitura de faixa, playlist, reprodução completa, prévia, bloqueio e download. Uploader não é automaticamente o artista da gravação. Preservar campos solicitados e encontrados, ausência de ISRC/explicit e identificação de remixes/covers. Tratar timeout, 403/404/429 e cancelamento sem retry infinito. Na API oficial, seguir os cabeçalhos de quota e `Retry-After`, não números fixos. [Limites oficiais](https://developers.soundcloud.com/docs/api/rate-limits).
3. **Importador comum de playlists.** Desacoplar o comando de Spotify, despachar por origem e emitir `TrackDraft` por ocorrência. SoundCloud público primeiro: completar toda a lista até o limite existente de 10.000, com concorrência limitada, progresso, ordem e repetições preservadas. Uma ocorrência indisponível continua identificada. A paginação de rede acontece na importação; a UI continua em rolagem contínua. O modelo oficial expõe resolução de links e leitura das faixas da playlist. [OpenAPI](https://github.com/soundcloud/api/blob/master/openapi/api.yaml).
4. **Conferência e fontes manuais.** Inserir candidatos SoundCloud no fluxo existente. Sugestões automáticas exigem título, artista, duração e versão suficientemente confirmados; metadados insuficientes ficam para revisão. Proposta: consultar SoundCloud depois das duas fontes atuais de áudio e antes do último recurso de videoclipe. Link manual fixa a versão daquela ocorrência; não substituir por fallback. Cadastro na playlist não torna a fonte automaticamente baixável.
5. **Escuta e referência.** Local continua prioritário. Manter Ouvir, Ouvir prévia, Abrir referência, Copiar link e Usar esta versão independentes. Resolver URLs temporárias somente quando necessário e não salvá-las como referência permanente. O widget oficial é alternativa de escuta em componente web visível, com testes por plataforma; não é arquivo MP3 para o player local. [Widget](https://developers.soundcloud.com/docs/api/html5-widget). A API diferencia `playable`, `preview` e `blocked`; não marcar trecho como gravação completa. [Guia](https://developers.soundcloud.com/docs/api/guide#playing-tracks).
6. **Obtenção e validação separadas.** Antes de habilitar a capacidade, definir o caminho de obtenção adequado e validá-lo com mídia própria/autorizada. Revalidar ID, acesso, formato e duração; distinguir original, stream e prévia; respeitar bloqueios. Adaptar pausa/parada/progresso, staging, metadados, capa, nome e M3U8 com origem SoundCloud. Conclusão exige arquivo decodificável e duração verificada, não apenas URL ou 100% de rede. O worker atual só implementa os provedores anteriores.
7. **Desktop/mobile e critérios de entrega.** Parser, importação, regras e capacidades compartilhados em Dart. O Python Windows não oferece execução mobile; cada plataforma precisa de adaptador e validação próprios. Testar persistência/reinício, ordem/repetição, listas grandes, indisponíveis, matching incorreto, extras durante execução e cancelamento. Não declarar suporte completo no produto apenas com um ensaio Windows.

Próxima unidade implementável: importação de playlists públicas SoundCloud e links individuais com metadados/referência, seguida de conferência; habilitar reprodução e download somente após os respectivos ensaios. A avaliação atual não altera o aplicativo instalado, mantido em 0.1.42, nem cria release.
