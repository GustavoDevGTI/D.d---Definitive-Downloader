# 0.1.67 — piloto de importação pública com CheckLeaked

O D.d reutiliza o endereço HTTPS de importação da 0.1.66. O serviço do piloto roda em Cloudflare Workers e consulta a CheckLeaked pelo RapidAPI. Em **Músicas → Coleções → Importar por link**, a pessoa cola uma playlist pública e vai à Conferência. A busca usa as fontes disponíveis e o download continua sob comando separado.

## Contas e ativação

- O administrador entra no [RapidAPI](https://rapidapi.com/airaudoeduardo/api/spotify81/pricing) e ativa o plano anunciado de 1.000 chamadas mensais. A franquia é compartilhada pelo piloto. Confira as condições de cobrança exibidas no cadastro. Use uma assinatura dedicada ao piloto para que o contador do Worker cubra o uso da chave.
- O administrador autoriza a publicação na conta Cloudflare do projeto e habilita um endereço `workers.dev`. O Worker guarda a chave RapidAPI como segredo `DD_RAPIDAPI_KEY`.
- A pessoa que cola uma playlist pública dispensa contas Spotify, RapidAPI e Cloudflare. O D.d permite conectar Deezer para habilitar o áudio dessa fonte. A conexão pessoal Trackhop e a importação por CSV continuam disponíveis para playlists privadas.

## Publicação

1. No diretório `services/playlist-gateway`, com Wrangler autenticado na conta do projeto, execute `wrangler deploy`. O arquivo `wrangler.jsonc` define a rota e o armazenamento do limite de chamadas.
2. Defina `DD_RAPIDAPI_KEY` como segredo pelo painel Cloudflare ou pelo comando interativo `wrangler secret put DD_RAPIDAPI_KEY`.
3. Acesse `/health` no endereço do Worker para confirmar que o segredo está presente. Em seguida, valide uma playlist pública em `/v1/spotify/playlists/<id>`.
4. O endereço publicado é o padrão dos builds Windows e Android. Para testar outro serviço, passe o endereço HTTPS com `-PlaylistGateway` nos scripts de compilação. Para migrar depois ao Trackhop mantendo o mesmo endereço, o Worker pode encaminhar a rota ao serviço da 0.1.66.

## Leitura e limites

- Uma chamada lê os metadados e até uma chamada por bloco de 100 lê os itens. Para 232 faixas, são quatro chamadas. As páginas são verificadas contra o total antes de entregar a lista.
- Título, artistas, duração, álbum, capa disponível, ISRC e indicação de explícito seguem quando presentes. O serviço preserva a ordem e as repetições. Itens locais, episódios e entradas sem metadados suficientes entram na contagem de itens deixados de fora.
- O Worker reserva no máximo 900 chamadas em 31 dias corridos. Reservas continuam contabilizadas em caso de cancelamento ou erro. Quando a API informa saldo, o Worker também o verifica. O limite por origem é de seis importações por minuto em cada ponto da Cloudflare.
- O piloto aceita até 4.500 itens por playlist para respeitar o limite de subconsultas do Workers Free. Playlists maiores podem ser importadas por CSV.

## Verificação

Os testes Node de importação e do serviço Trackhop existente rodam com `node --test services/playlist-gateway/*.test.mjs`. O ensaio de runtime com Miniflare usa a configuração do Worker e o armazenamento SQLite local, com respostas simuladas da CheckLeaked.

A análise estática Windows/Android e 98 testes Flutter essenciais e focados passaram, com três ignorados. Dez testes Node passaram. O ensaio HTTPS local ligou o leitor Dart ao Worker e recebeu 232 ocorrências na ordem do servidor simulado. O ensaio concorrente de reservas atingiu o teto de 900 sem ultrapassá-lo. O Wrangler validou a configuração em modo de teste.

A página pública da playlist **Fifa definitivo** confirmou 232 faixas em uma sessão anônima.

O Windows 0.1.67+68 foi instalado e abriu com o atalho verificado durante a rodada local. Após a autorização, o Worker `dd-playlists` foi publicado em `https://dd-playlists.dd-playlist-worker.workers.dev`. Os pacotes Windows, Android ARM64 e Android x86_64 foram recompilados com esse endereço. O APK x86_64 foi instalado no emulador dedicado.

Após o cadastro de `DD_RAPIDAPI_KEY` como segredo, `/health` respondeu HTTP 200. O Worker leu as 232 faixas da **Fifa definitivo** pela CheckLeaked via RapidAPI, com capa e duração em todas e zero itens ignorados. A ordem das primeiras 100 faixas coincidiu com a lista pública exibida pelo Spotify. O leitor Dart no Windows também importou as 232 faixas por HTTPS. O instalador Windows com o endereço publicado foi gerado, e a execução automática do instalador foi bloqueada pela política da ferramenta.

Um teste Flutter de interface no Windows acionou **Importar por link** com o serviço real e confirmou a abertura da Conferência com as 232 faixas e zero solicitações de login. A instalação isolada de teste no Android excedeu o tempo limite no ADB. O modo alternativo instalou o pacote, mas o Android registrou timeout na inicialização do processo de teste. O APK de uso normal com o endereço publicado está instalado no emulador. A validação nativa da importação continua pendente.

Na instalação Windows, a comparação por SHA-256 com a compilação configurada identificou `data/app.so` como o único arquivo diferente no conjunto compilado. A atualização substituiu esse arquivo após fechar o app e guardar cópias do binário e da biblioteca SQLite. Na janela reaberta, **Importar por link** abriu a Conferência com 232 faixas da **Fifa definitivo**, todas com capa e duração, sem solicitar login. A biblioteca confirmou a importação completa como uma nova coleção e manteve as duas coleções anteriores, incluindo seus dois downloads concluídos. A busca automática gravou as primeiras correspondências do YouTube Music. O ensaio terminou com a busca em andamento, antes de solicitar qualquer download na nova coleção.
