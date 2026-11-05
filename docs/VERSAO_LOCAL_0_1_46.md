# Coleções compostas e arquivos locais — 0.1.46 local

Pedido de 05/11/2026, conforme `PLANO_COLECOES_COMPOSTAS_2026_11_05.md`. Versão incrementada somente após implementar o conjunto. Releases, tags e push continuam suspensos pelo ciclo de feedback.

## Comportamento, na ordem das capturas

1. Retirado o cadeado da playlist. As proteções dos nomes/IDs após início e das posições concluídas continuam válidas; pendentes podem trocar de posição entre si.
2. Retirada a linha Grupos. Novo grupo está na fila de ícones de cada playlist; criar por ali inclui aquela playlist no grupo, na mesma transação SQLite, conforme resposta explícita do usuário. Filtros de grupo permanecem compactos; renomear/remover ficam acessíveis ao selecionar um grupo, inclusive em tela estreita.
3. Nova playlist aceita nome, grupo e **Link da playlist (opcional)**. Sem link cria vazia. Com link importa para a nova playlist usando o nome escolhido. Falha/cancelamento não deixam uma playlist extra incompleta.
4. Adicionar links aceita faixas individuais e playlists de Spotify, SoundCloud, Deezer, YouTube e YouTube Music, além de MP3 direto. Expande as listas antes de gravar, na ordem dos links e das faixas, preservando repetições. Acrescenta ao final. Fontes prontas participam da execução ativa; pendentes continuam para conferência. A escolha manual da versão é preservada. Links YouTube com parâmetro de playlist válido são interpretados como playlist; um vídeo sem esse parâmetro continua individual.
5. Arrastar MP3 para uma playlist na lista de coleções ou para sua área aberta cria cópias na pasta de mídia da playlist, após a última ocorrência. O botão **Adicionar MP3** usa a mesma operação com seleção de arquivos. Arquivos entram como locais concluídos, com título/artista/álbum das tags quando disponíveis, capa incorporada lida pelo player e nome de arquivo numerado com título antes de artista. Sem título, usa o nome do arquivo. Não reescreve tags, move originais, renumera concluídas ou sobrescreve mídia existente. Duplicatas são mantidas como ocorrências/cópias independentes. A M3U8 é atualizada.

Adicionar ou escutar não inicia download. Adições podem ser interrompidas sem parar uma transferência em andamento. Progresso é transitório; não foram acrescentadas instruções permanentes à tela.

## Estrutura e segurança dos arquivos

`PlaylistCatalog` compartilha o despacho dos importadores; `CollectionLinkComposer` expande/prepara o lote. `MusicLinkRepository` acrescenta ocorrências e vínculos da execução numa transação. Widgets encaminham intenções e apresentam estados, sem SQL/HTTP/IO.

`LocalMediaImporter` faz cópia incremental para staging dentro da pasta da playlist, inspeciona a cópia, reserva nomes exclusivos e publica os arquivos antes do registro. `LocalAudioInspector` separa a validação estrutural dos quadros MP3 e uma sondagem silenciosa com decoder nativo; seu player temporário não substitui o player do usuário. `LocalMediaRepository` registra ocorrência e histórico juntos, sem reenfileirar `localFile` para rede. Schema **15** protege a leitura desse novo tipo por versões antigas; a migração não altera valores anteriores ou arquivos.

Limites explícitos: 20 links por lote, 10.000 ocorrências por coleção; playlists precisam chegar completas. Para arquivos: 100 MP3 por lote, 200 MiB por arquivo, 1 GiB por lote, tags de até 4 MiB. As leituras de catálogo continuam limitadas pelos importadores existentes. Nenhum cookie/credencial foi procurado ou armazenado por esta mudança.

Erros/cancelamento comuns removem somente as novas cópias/staging da operação. Uma interrupção abrupta do processo durante a publicação pode deixar uma cópia sem registro; não há promessa de atomicidade entre filesystem e SQLite em queda do processo. Falha posterior ao atualizar a M3U8 informa o problema e preserva as cópias já registradas. A validação aceita quadros MPEG Layer III regulares e tags ID3; outros trailers como APEv2/free bitrate não foram validados. A sondagem nativa não equivale a decodificar integralmente cada amostra de todos os arquivos.

Dependência travada `desktop_drop 0.8.1`. O seletor de arquivos fornece a alternativa compartilhada com mobile. Núcleo Dart e layouts adaptativos foram exercitados; execução nativa Android/iOS e arraste real do Explorador para a janela Windows ainda não foram validados. O teste de arraste injeta o evento no canal do plugin e verifica widget/controlador/cópia; não é apresentado como um ensaio físico do gesto no Windows.

## Verificações

- `dart format`; suíte completa: **209 testes passaram, três optativos ignorados**. Após os ajustes finais de validação/título/link YouTube, os dez contratos de composição passaram novamente (um ensaio nativo optativo ignorado nessa rodada).
- Contratos cobrem criação vazia/composta/falha, grupo e inclusão atômicos, expansão/ordem/repetição, capacidade e cancelamento, mais de 20 ocorrências expandidas na execução, cópias e colisão de nomes, rollback, original preservado e adição durante download sem alterar a faixa ativa.
- Testes de interface em 1360 e 390 px exercitam campo opcional, expansão, evento de arraste pelo canal e seletor MP3. Grupos acessíveis também em 320 px. Layouts gerais de 320 a 1920 px; inspeção das capturas desktop e estreitas.
- Ensaio local optativo com **decoder nativo real**, SQLite e pastas isoladas: duas cópias de um MP3 sintético de quatro segundos; hashes iguais ao original, posições e caminhos corretos, itens disponíveis ao player. Repetido com título/artista/álbum/capa incorporados: todos preservados. Não é download de plataforma nem teste na biblioteca do usuário.
- Não foram introduzidos provedores novos ou alterado o worker nesta versão; os ensaios reais dos importadores de catálogo permanecem registrados nas versões 0.1.44/45. Composição mista nesta rodada foi verificada por contratos controlados.

Evidências privadas, logs e bancos de ensaio ficam fora do Git, em `%LOCALAPPDATA%/DefinitiveDownloaderDev/local-version-0.1.46`.

## Pacote e instalação

`flutter analyze --no-pub`: sem problemas. Build Windows Release e instalador 0.1.46 concluídos; `0.1.46+47` no pubspec e indicação 0.1.46 local no app. Registros nativos do plugin foram regenerados com o lockfile atual. Conferidos 185 arquivos de fonte/assets/testes contra o staging e preservado o SHA-256 do worker da 0.1.44.

Instalação silenciosa sobre o aplicativo existente, com backup e sem transferências ativas, terminou com código zero. Registro do Windows confirma 0.1.46; oito arquivos essenciais instalados (incluindo código Dart, plugin de arraste, áudio e worker) correspondem ao pacote por SHA-256. Atalho do aplicativo instalado preservado na Área de Trabalho. O instalador permanece na pasta privada de evidência, sem substituir o atalho.

Antes da atualização: duas coleções, 242 faixas, 12 registros de histórico; comparação após a instalação e antes da primeira abertura confirmou os mesmos valores e integridade SQLite. A migração 14 → 15 ocorre na primeira inicialização; neste ponto a sessão Windows estava bloqueada, impedindo reabrir/conferir a janela. Verificação visual nativa e comparação do banco após essa primeira abertura ficam pendentes do desbloqueio, solicitado ao usuário. Não foram criados dados de teste na biblioteca real.

SHA-256 do instalador fica registrado em `installer/SHA256SUMS.txt` nas evidências privadas. Nenhuma release, tag ou push foi realizada.
