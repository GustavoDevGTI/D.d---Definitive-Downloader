# Definitive Downloader 0.1.14

Edição de playlists e política de fontes solicitadas em 03/11/2026. Flutter `0.1.14+15`; versão do instalador derivada do pubspec.

## Playlist editável antes de iniciar

O menu de cada ocorrência permite editar nome, posição/número e link ou ID da plataforma, além de mover para cima/baixo. A numeração representa a posição de 1 até o total da coleção; mudar esse número desloca as demais ocorrências. Repetições e chaves primárias SQLite permanecem intactas, inclusive ao mover entre páginas.

O nome escolhido é armazenado em `custom_title`, separado do título solicitado e dos metadados da fonte. O nome personalizado é aplicado ao arquivo, título do MP3 e M3U8 nos novos downloads. Alterações de link/ID são catalogadas novamente e passam pela mesma política de matching do provedor. A edição e o movimento são atômicos: falha na validação não deixa posições intermediárias.

Ao reivindicar a primeira transferência, a coleção recebe bloqueio persistente de edição. Nomes e ordem permanecem bloqueados após pausa, parada, falha e reinício. A UI mostra cadeado e desativa a edição; o banco também verifica o bloqueio dentro da transação. Fontes podem continuar sendo conferidas nas ocorrências pendentes; fontes de itens em transferência ou concluídos não são substituídas.

O schema v9 acrescenta o bloqueio da coleção, nome personalizado, tipo de gravação e autorização da fonte. Coleções com transferência/histórico anterior são bloqueadas na migração. Nenhum arquivo existente é movido, renomeado ou excluído.

## Spotify, áudio e videoclipes

- Link de faixa Spotify lê metadados pela conta conectada e busca equivalentes em Deezer e YouTube Music. O matching considera título, artista, duração e versão; a URL Spotify não é apresentada como áudio baixável. Ambiguidade continua pendente de revisão.
- A busca automática prioriza faixas de áudio. Somente sem correspondência de áudio utilizável a operação separada pesquisa videoclipes OMV do catálogo YouTube Music. O resultado nunca é escolhido automaticamente. Se Deezer falhar na transferência, a alternativa de áudio YouTube Music continua prioritária; sem ela, videoclipes encontrados ficam para revisão.
- Ao escolher um videoclipe encontrado pela busca, a UI pede aprovação da versão, mostrando título, artista, link, duração encontrada e solicitada. O vínculo persiste com autorização `approvedVideo`, ligada à ocorrência e ao candidato catalogado. O motor exige essa autorização e reconfirma o tipo/ID antes de obter o áudio.
- Links `youtube.com/watch`, `m.youtube.com/watch`, `youtu.be` e YouTube Music inseridos manualmente representam a escolha da versão. Não há matching nem uma segunda aprovação de videoclipe. O vínculo usa `manualLink` e não é substituído por busca/fallback. Disponibilidade, identidade, duração e validação integral do áudio continuam obrigatórias; lives e filmes seguem bloqueados.
- A origem efetiva distingue YouTube de YouTube Music na interface, no nome do arquivo e no M3U8. A duração da versão escolhida é preservada; não há corte ou normalização para fazê-la coincidir com a gravação solicitada.

A separação ATV/OMV e a busca `videos` seguem a [documentação de ytmusicapi](https://ytmusicapi.readthedocs.io/en/latest/reference/search.html) e a [descrição dos tipos de conteúdo](https://github.com/sigma67/ytmusicapi/blob/main/docs/source/faq.rst).

Extras continuam disponíveis tanto na coleção quanto em Downloads, antes e durante a execução. A inclusão permanece ao final e fontes prontas entram na mesma execução ativa, conforme 0.1.13. O bloqueio da edição não bloqueia a inclusão de extras. O formulário manual foi simplificado para um link, sem as antigas orientações de indisponibilidade de videoclipes.

## Validação

- Formatação: 84 arquivos em `lib`/`test`, sem diferenças. `flutter analyze --no-pub`: sem problemas. Suíte Flutter final: 86 testes aprovados. Motor Python: 9 testes aprovados.
- Contratos: movimentos em ambos os sentidos através de páginas, duplicatas e PKs preservados, nome em arquivo/M3U8, busca por nome personalizado, rollback, troca de ID da plataforma, bloqueio da coleção após reivindicação e após reinício, migração v8→v9 e migrações anteriores. Inclusão de extras durante transferência e cancelamento permanecem cobertos.
- Política: áudio antes de vídeos; nenhum videoclipe escolhido automaticamente; aprovação por ocorrência/candidato; duração solicitada separada da escolhida; URLs inválidas/credenciais bloqueadas; link manual do YouTube e tipo ausente aceitos sem matching; lives e autorização ausente recusadas.
- UI e capturas isoladas em 1920×1080, 1360×820, 900×820, 900×600, 390×820 e 320×820, com texto 1,3× no último. Editor e aprovação revisados visualmente em 1360 e 320 px; cancelamento da aprovação não altera a fonte. Capturas publicadas usam fixtures, sem dados de contas.
- Metadados reais pelo catálogo Dart: link curto `qWNQUvIk954` foi canonizado para YouTube e identificado como OMV de 200.000 ms.
- Ensaio real sem conta, fora da biblioteca: o link manual desse videoclipe gerou MP3 de 4.444.557 bytes, 200.098 ms, com capa, decodificação integral e título personalizado conferido no ID3. É validação do adaptador Python, separada da UI.
- Motor Windows empacotado: o mesmo videoclipe sem autorização foi bloqueado sem criar mídia; com `approvedVideo`, gerou MP3 de 4.404.126 bytes, 200.098 ms, capa, decodificação integral e nome personalizado. Ensaios separados; nenhuma mídia de provedor integra o repositório ou a release. Spotify individual e mudanças de matching foram exercitados com fixtures, sem novo login ou ensaio real de conta nesta rodada.
- Build Windows release concluído. Worker reconstruído e preservado pelo build Flutter: SHA-256 `266B509F026A92827FA48E8335BF59865BB6B1B06552E56DB48276145D01D271`.

- Atualização real com instalador: saída 0. Aplicativo `0.1.14+15` aberto a partir da instalação local; atalho da Área de Trabalho aponta para o executável e o ícone da marca.
- Antes/depois: uma coleção, dez faixas, dez históricos, zero ativos; schema 8→9 e `quick_check=ok`. A coleção histórica ficou bloqueada, conforme a nova regra. Backup SQLite local antes da atualização. Contas e cookies não foram inspecionados.
- 97 arquivos de fontes/testes/assets idênticos à cópia compilada; fontes do worker idênticos ao staging de sua compilação. Executável, `data/app.so`, ICO e worker idênticos por hash entre pacote e instalação. ZIP validado sem corrupção e inspecionado sem banco, sessão ou transferência parcial.
- Logs, relatórios, backup e mídia dos ensaios permanecem em diretório local de evidências, fora do repositório e dos assets publicados. A revisão visual usa capturas de widgets; versão/processo/atalho da instalação foram conferidos separadamente, sem automação visual nativa.

## Distribuição

[Release v0.1.14](https://github.com/GustavoDevGTI/D.d---Definitive-Downloader/releases/tag/v0.1.14), com instalador Windows x64, ZIP portátil e `SHA256SUMS.txt`. Versões anteriores preservadas; instalador sem assinatura digital.

| Artefato | Bytes | SHA-256 |
| --- | ---: | --- |
| Setup Windows x64 | 75.736.875 | `f0103c2f0e23da4a4a1263517deaafa1fe1b93f0f8d072061e80f53eb9cbc545` |
| ZIP Windows x64 | 99.525.656 | `234618dca9334503e0e6fa3cd91b81e5563acfefef054be82ffe97b833c0bb89` |


## Limites

Entrega do piloto Windows. Núcleo Dart, persistência e UI são compartilhados, com layout mobile testado por widgets. Android/iOS não foram compilados/executados; o worker Python não implementa obtenção musical mobile. Aprovação de uma versão não garante disponibilidade permanente do provedor. Captura geral de páginas, vídeos/fotos e métricas de rede mantêm as capacidades anteriores. Não houve download real pela UI nesta rodada; os ensaios reais descritos são do adaptador e do executável do motor.
