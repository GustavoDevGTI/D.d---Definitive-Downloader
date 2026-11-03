# Definitive Downloader 0.1.13

Gerenciador de downloads e inclusão de faixas extras solicitados em 03/11/2026. Flutter `0.1.13+14`; o instalador deriva a versão do pubspec.

## Interface

- Controles em uma única barra branca contornada. Cada ícone tem botão próprio, borda rosa, fundo suave e tooltip; iniciar usa rosa preenchido, estados ativos usam vinho. A barra mantém rolagem horizontal nas telas estreitas.
- Pesquisa em Downloads por nome, artista, nome da fonte, coleção e caminho. Contagem e paginação usam a mesma consulta parametrizada, com páginas de 40; a busca alcança itens fora da página atual. Seleção é reiniciada ao pesquisar.
- Colunas redimensionáveis pelo divisor do cabeçalho, inclusive por arraste no toque. Teclado permite ajustar com as setas; duplo clique restaura a coluna e o botão de colunas restaura o conjunto. Larguras são limitadas e salvas individualmente nas preferências SQLite, sem armazenar a fila em JSON.
- Ícone de adicionar links na coleção e na barra de Downloads, com o mesmo diálogo de destino e entrada multilinha. Até 20 links por lote e 10.000 ocorrências por coleção; repetições intencionais são preservadas.

## Links e execução

Faixas Spotify usam a conta conectada para ler metadados e o matching existente para buscar equivalentes em Deezer e YouTube Music. Spotify não fornece uma URL de áudio nesta integração. Ambiguidade ou indisponibilidade mantém a ocorrência pendente de revisão.

Links completos de faixas Deezer e YouTube Music ATV fixam a fonte por ocorrência, sem substituição automática. O catálogo confere ID, duração, disponibilidade e tipo. Deezer depende da conexão e do motor de transferência; vínculos sem capacidade disponível ficam pendentes. MP3 direto aceita endereço HTTP/HTTPS estável sem credenciais, parâmetros ou fragmentos; o arquivo continua sujeito à validação de áudio no download. Links de compartilhamento encurtados e links genéricos de vídeos não foram acrescentados nesta etapa.

Novas ocorrências são acrescentadas ao final da coleção. Durante uma execução ativa, fontes prontas entram depois da seleção inicial, mantendo a ordem de inclusão mesmo que sua prioridade seja maior. A execução aguarda inclusões já iniciadas antes de encerrar. Parada preserva os extras prontos para uma execução posterior e não inicia outra transferência. Arquivos concluídos e M3U8 continuam em ordem de ocorrência.

Schema v8 acrescenta `queue_added` e a tabela relacional transitória `download_run_additions`; a inclusão do lote e sua participação na execução são atômicas. A migração não move arquivos, limpa coleções ou altera contas. Larguras usam as preferências existentes.

Consulta de metadados é Dart compartilhado, com domínios permitidos, limites de resposta/tempo e sem credenciais em consultas públicas. O protocolo de player musical segue a estrutura usada por [ytmusicapi](https://github.com/sigma67/ytmusicapi); a distinção de resultados de catálogo está na [documentação de pesquisa](https://ytmusicapi.readthedocs.io/en/latest/reference/search.html).

## Validação

- `dart format --output=none --set-exit-if-changed lib test`: 81 arquivos sem alterações. Análise estática final sem problemas.
- Suíte final: 78 testes aprovados, incluindo arraste/teclado/duplo clique, busca e limpeza na UI, paginação, restauração das larguras, rollback do lote, duplicatas, migrações v2/v5/v6/v7, inclusão durante transferência e parada durante inclusão. Os ensaios de execução usam áudio sintético isolado; não são downloads de provedores.
- Layouts em 1920×1080, 1360×820, 900×820, 900×600, 390×820 e 320×820, com texto 1,3× no último. Revisão visual do gerenciador e diálogo em 1360 e 320 px. Capturas publicadas usam fixtures.
- Consulta pública real: Deezer `3135556` e YouTube Music `JhulBGMA7G4` identificaram “Harder, Better, Faster, Stronger”, com 226.000 ms em ambas. O ID `qWNQUvIk954` retornou tipo OMV e foi recusado, conforme a política desta etapa. São leituras de catálogo; não houve novo download real nem nova autenticação. Spotify individual e matching dos extras foram exercitados com fixtures.

- Windows release compilado; 94 arquivos de fontes/testes/assets conferidos por hash contra a cópia compilada. Versão nativa `0.1.13+14`.
- Instalador gerado e atualização real com saída 0. App instalado aberto, com janela “Definitive Downloader” e atalho da Área de Trabalho apontando para o executável instalado e o ICO da marca.
- Executável, `data/app.so`, ICO e worker idênticos por SHA-256 entre pacote e instalação. Worker anterior preservado, SHA-256 `EFD3B3C8B74030F4A1336120EEC80995CBF7511E49B01B692A1AB6A8D86F19C7`.
- Banco antes/depois: uma coleção, dez faixas, dez históricos, zero ativos; schema 7 → 8 e `quick_check=ok`. Backup SQLite local antes da atualização. Sessões e cookies não foram inspecionados, e nenhum dado da biblioteca entrou na publicação.
- ZIP portátil verificado sem corrupção; pacote inspecionado sem banco, arquivos de sessão ou transferências parciais. Evidências de build, instalação e hashes ficam locais em `release-evidence-0.1.13`, fora do repositório. A revisão visual usa widgets; processo/versão/atalho foram conferidos separadamente, sem automação visual nativa nesta rodada.

## Distribuição

[Release v0.1.13](https://github.com/GustavoDevGTI/D.d---Definitive-Downloader/releases/tag/v0.1.13), com instalador, ZIP portátil e `SHA256SUMS.txt`. Releases anteriores preservadas. Instalador sem assinatura digital.

| Artefato | Bytes | SHA-256 |
| --- | ---: | --- |
| Setup Windows x64 | 75.721.182 | `20eca4e47d92656036d18945edad6c0ac87daba4ebdbcea875d26fb7e0ffe576` |
| ZIP Windows x64 | 99.510.586 | `b1af335fa6c38094a1b9da80f7ff289e9b673c138f6763c891a464981678ad56` |


## Limites

Entrega do piloto Windows. Interface, persistência e catalogação permanecem compartilhadas em Dart, com layouts mobile exercitados por widgets. Não houve build ou execução Android/iOS; o motor Python Windows não implementa obtenção musical mobile. Métricas de rede, captura geral de páginas, vídeos/fotos e formatos planejados continuam com as capacidades anteriores.
