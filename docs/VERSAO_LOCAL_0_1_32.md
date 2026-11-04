# Definitive Downloader 0.1.32 — versão local

Identificação `0.1.32+33`, em 04/11/2026. Esclarecimento da regra durante a etapa anterior; sem release/tag/publicação remota.

## Regra esclarecida pelo usuário

As faixas já baixadas mantêm posição, nome, caminho e conteúdo. As demais podem trocar entre si as posições restantes livremente: com uma concluída no número 2, as pendentes 1 e 3 podem trocar, preservando o número 2. O arraste reorganiza apenas a sequência das ocorrências livres e a intercala nos slots livres, sem deslocar concluídas indiretamente.

A ocorrência em andamento fica temporariamente fixa para preservar o nome usado pelo receptor e a publicação do arquivo. Após parar ou falhar sem publicar arquivo, pode voltar a mudar de posição, inclusive após reiniciar o app. `queue_run` continua impedindo uma segunda tentativa automática na mesma rodada, mas não bloqueia mais a posição. Concluídas com arquivo indisponível conservam seu registro e posição. Um grupo que inclui concluídas/em andamento é recusado integralmente, sem modificar arquivos ou seleção.

Esta orientação substitui a 0.1.31 nos bloqueios de falha/parada, na passagem por uma posição protegida e na separação entre extras e originais. Nomes/links/IDs continuam usando o bloqueio da coleção após o início; a mudança solicitada é da posição. O gesto permanece em Músicas → Coleções, com mouse ou toque; esta versão não adiciona arraste à tabela Downloads.

## Fila e persistência

Antes de receber o primeiro item, `beginRun` cria um snapshot relacional dos IDs autorizados da seleção, com no máximo 10.000 ocorrências por coleção (seleção por IDs limitada a 100 como antes). Usa a tabela transitória existente `download_run_additions`, agora também com os originais, um registro por ocorrência. Não há migração/schema novo nem lista inteira em JSON. A inicialização curta bloqueia edição/adição concorrente até registrar a seleção; cancelar/pausar continua disponível.

Extras são acrescentados ao fim do snapshot por padrão. Depois podem ser movidos entre os pendentes originais; o editor redistribui os slots da execução da mesma coleção conforme a nova ordem. Slots de outras coleções permanecem intactos. O próximo item é reivindicado pelo ordinal do snapshot, revalidando suporte, autorização, estado e ocorrência ainda não tentada nesta rodada. Um comando de prioridade explícito posterior reorganiza os slots ainda não reivindicados, preservando a função anterior sem alterar a numeração da playlist.

Reordenação e reivindicação continuam transacionais. Se a faixa começa enquanto o usuário arrasta, o domínio recusa movê-la. A seleção usada pela execução é o snapshot, e arrastar não inicia downloads, não confirma fontes nem exclui repetições. Pausa/parada/limpeza da execução preservam as ocorrências; o snapshot transitório é removido no término ou reinício, como antes.

M3U8 gerada ao terminar usa a ordem persistida; nenhuma M3U8 existente é regravada pelo gesto isolado. O worker e as integrações com contas não foram alterados. Cálculos e regras são Dart compartilhado; execução nativa mobile permanece sem validação/motor próprios.

## Validação e instalação

- `dart format`: 108 arquivos, nenhum ajuste pendente. `flutter analyze`: nenhum problema. Suíte completa: 131 testes aprovados.
- Caso explícito do esclarecimento: pendentes 1 e 3 trocam mantendo a concluída 2 com mesmo número, caminho e bytes; a ordem persiste após reiniciar o banco. Tentativa falha/interrompida sem arquivo volta a ser móvel. Grupo contendo concluída continua recusado.
- Snapshot testado com originais e extras: extra pode passar à frente de um original pendente; próxima reivindicação segue a ordem, mantendo o slot dos extras de outra coleção. Testes anteriores de prioridade, cancelamento, pausa, adição durante download, autorização de vídeo, repetição e M3U8 continuam aprovados.
- Gestos de mouse em 900 px e toque em 390 px mantêm cobertura de arraste com a primeira faixa ativa. Layouts inspecionados em 1360 e 390 px. Os ensaios de arquivos usam fixtures locais; nenhum provedor real foi acessado nesta etapa e não há validação nativa mobile.
- Build Windows concluído. Os 123 arquivos de lib/test/assets/pubspec/lock conferem com o staging. Worker da 0.1.30 preservado por hash, sem alterações de motor ou dependências.
- Instalador local 0.1.32 gerado com SHA-256 registrado; aplicativo instalado `0.1.32+33`, registro Windows `0.1.32`, reaberto/respondendo e atalho conferido. Sem release/tag/publicação remota.
- Backup da instalação anterior preservado. Registros idênticos antes/depois da instalação e reabertura: 2 coleções, 242 faixas, 11 arquivos no histórico, 10 preferências, 2.183 candidatos, 11 tentativas e nenhum grupo. Schema 10 e `quick_check=ok`; nenhuma transferência ativa foi interrompida para instalar.
- Evidências privadas em `%LOCALAPPDATA%\DefinitiveDownloaderDev\local-version-0.1.32`, incluindo logs, layouts, backup e hashes. Não entram no repositório.
