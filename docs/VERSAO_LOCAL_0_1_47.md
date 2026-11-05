# Revisão de duplicatas ao adicionar links — 0.1.47 local

Pedido de 05/11/2026, com esclarecimento explícito: manter a versão existente descarta a recebida; escolher a nova exclui a antiga e seu arquivo atual, e acrescenta a nova junto das demais recebidas. Não renumerar as outras faixas já baixadas. Esta escolha explícita substitui a preservação automática de repetições somente para as ocorrências revisadas nesta operação. Releases continuam suspensas.

## Comportamento

- Adicionar links, tanto em Coleções quanto em Downloads, verifica as faixas/playlist(s) recebidas contra a coleção de destino e contra faixas já aceitas no mesmo lote. Não compara a biblioteca inteira nem mistura playlists independentes.
- Duplicatas abrem um popup central, com as versões existente e recebida, título, artista, origem/referência, duração, álbum e indicação explícita/limpa quando disponíveis. Nenhuma opção vem selecionada. A opção **Fazer para todos** repete a escolha nas próximas duplicatas **deste lote**, sem persistir uma política para importações futuras.
- **Manter a existente:** a recebida não entra. As demais novas seguem em ordem, sem reservar número para as descartadas. Repetições que já existiam permanecem; não há limpeza automática da coleção anterior.
- **Usar a nova versão:** as ocorrências existentes correspondentes mostradas no popup saem, e seus arquivos locais atuais e registros correspondentes de histórico são removidos. A recebida entra na posição relativa da lista nova, depois da maior posição que restar na coleção. Outras faixas e arquivos mantêm número, ID e caminho. Não deslocar concluídas para preencher lacunas internas anteriores. IDs novos não reutilizam os IDs removidos na operação.
- Se várias ocorrências existentes corresponderem à recebida, o popup informa a quantidade; manter conserva essas ocorrências, enquanto usar a nova substitui o conjunto mostrado. A apresentação limita os detalhes iniciais a dez ocorrências e informa o restante, evitando milhares de widgets para uma repetição extrema.
- A revisão completa precede qualquer remoção/adição. Cancelar em qualquer pergunta deixa a coleção e os arquivos intactos. Somente as recebidas escolhidas passam pela preparação/busca de fontes; descartar uma duplicata evita trabalho externo desnecessário.
- Durante revisão, a transferência atual pode terminar; a próxima aguarda a conclusão/cancelamento da operação. Escolher substituir a faixa ativa aguarda sua finalização (ou parada), com cancelamento e limite de espera de cinco minutos. Novas fontes prontas entram ao final da mesma execução, conforme a regra dos extras; sem execução ativa não começa download ao adicionar.
- A importação inicial para uma playlist nova mantém as repetições da lista original. Arraste/seletor de arquivos locais não recebeu deduplicação neste pedido de links colados.

## Identificação e limites

Identificação por ISRC válido, referência/ID nativo da plataforma (YouTube e YouTube Music compartilham o ID de vídeo), ou título e artista completos normalizados quanto a caixa, acentos, pontuação e espaços. Comparar também a referência da fonte efetiva quando disponível. Não aceitar somente um título sem artista, não aproximar por trechos de nomes e não apagar qualificadores como Live/Remix. Não é reconhecimento por impressão acústica; duas URLs de MP3 diferentes sem metadados comuns não comprovam que sejam a mesma gravação. A escolha continua explícita, inclusive com diferenças de duração ou versão.

Limites de 20 links e 10.000 ocorrências expandidas por lote/coleção permanecem. A capacidade final considera as remoções escolhidas. Ler somente a coleção alvo, com teto explícito. Indexação em mapas e intervalos de cooperação com o event loop evitam um laço longo sem devolver a interface ao usuário.

## Estrutura, arquivos e recuperação

`CollectionDuplicates` planeja escolhas sem IO. `CollectionLinkAddition` coordena revisão, preparação das escolhidas, espera da faixa ativa, publicação e exportação. `MusicLinkRepository` revalida as ocorrências e faz exclusões/adições e vínculos da execução em uma transação curta. Widgets apenas mostram escolhas e encaminham decisões. A fila tem espera explícita para a mutação revisada.

Schema **16** acrescenta o diário relacional `music_replacement_files`, sem alterar os dados anteriores na migração. A versão antiga é movida para staging na mesma pasta antes da transação. Cancelamento/falha restauram o arquivo; após commit, finalizar sua exclusão. Em interrupção abrupta, a inicialização usa o diário para restaurar quando a ocorrência antiga ainda existe, ou concluir sua remoção quando o commit já a excluiu. Não varrer/apagar arquivos por prefixo sem registro. Verificar pasta canônica e contenção, recusar arquivo redirecionado, mídia externa à pasta da playlist ou usada por outra ocorrência. Originais externos de MP3 importado nunca são alvo; a exclusão alcança somente a cópia da coleção.

O player libera a versão substituída e a remove da sua fila, preservando os demais itens. A M3U8 é atualizada para deixar de apontar para a versão excluída. Falhas de finalização/exportação ficam informadas e mantêm o diário quando necessário; não há promessa de exclusão física concluída enquanto o filesystem recusar a operação. Registros históricos de outras publicações não substituídas e arquivos fora do escopo não são apagados.

Núcleo, popup adaptativo e operações de arquivo são Dart compartilhado. Execução nativa mobile permanece pendente de validação; o motor Python Windows não foi alterado.

## Verificações

- Suíte completa final: **226 testes passaram**, três optativos ignorados. Os **17 contratos de duplicatas** incluem a falha de exportação sem mensagem enganosa sobre o diário.
- Casos: manter/nova por ocorrência e Fazer para todos; ordem/numeração das recebidas; preservação de outras concluídas; cancelamento depois de uma escolha; rollback de SQL com restauração do arquivo; IDs não reutilizados; arquivo compartilhado/externo recusado; diário antes/depois do commit e retomada; preparação somente das escolhidas; fila aguardando revisão e substituta entrando ao final da mesma execução; liberação da versão no player; migração 15 → 16.
- UI do popup em 1360 e 390 px, com fontes/ícones reais e foco/seleção explícitos. Capturas inspecionadas; teste não criou dados na biblioteca real. Os ensaios de cópia/exclusão/recuperação usaram arquivos sintéticos locais e filesystem/SQLite reais, sem download de plataforma.
- `dart format` sem mudanças pendentes; análise estática sem problemas e build Windows Release concluído. O pacote corresponde às fontes atuais; worker anterior preservado. Evidências, artefatos e bancos de ensaio permanecem fora do Git em `%LOCALAPPDATA%/DefinitiveDownloaderDev/local-version-0.1.47`.

## Instalação local

`0.1.47+48` no pubspec, 0.1.47 no rodapé e no instalador. Conferidos **190 arquivos** de fontes/testes/assets contra o staging. Instalador e arquivo SHA256SUMS na pasta privada de evidências, sem publicar release/tag/push. Atualização silenciosa do aplicativo instalado concluída com código zero; oito hashes essenciais correspondem ao pacote. Atalho do app instalado preservado.

Backup anterior e comparação após a instalação, antes de abrir: duas coleções, 242 faixas, 12 registros de histórico, sem transferências ativas, integridade SQLite `ok` e valores anteriores preservados. Não foi executada substituição na biblioteca real. A sessão Windows voltou a ficar bloqueada durante a preparação; desbloqueio solicitado ao usuário. Primeira abertura/migração 15 → 16 e inspeção visual nativa do popup ficam pendentes do desbloqueio. Não apresentar os testes de widget como inspeção dessa janela real.
