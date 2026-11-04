# Definitive Downloader 0.1.31 — versão local

Identificação `0.1.31+32`, em 04/11/2026. Sem release, tag ou publicação remota.

## Ordem das faixas ainda não iniciadas

Pedido posterior: permitir trocar as faixas 2 e 3 mesmo depois de a faixa 1 começar. Em Músicas → Coleções, o arraste deixa de depender do bloqueio global da coleção. Somente ocorrências ainda não iniciadas podem mudar de posição; a numeração delas acompanha a nova ordem. Os próximos trabalhos originais usam essas posições, mantendo a prioridade independente já existente. Ordenar uma coluna em Downloads continua sendo apenas uma mudança da visualização; esta versão não adiciona arraste à aba Downloads.

Nomes e links/IDs continuam protegidos pelo bloqueio da coleção. A faixa já reivindicada pela fila mantém sua posição, mesmo depois de pausa, falha, parada ou reinício. São considerados o `queue_run` persistido, o estado, caminho existente e mensagens históricas de interrupção. Não é necessário migrar o schema. Nenhum arquivo concluído ou ativo é renomeado, movido ou regravado.

O movimento ocorre em `BEGIN IMMEDIATE`, assim como a reivindicação da próxima faixa. A transação reavalia as duas ocorrências, a seleção quando aplicável e todas as posições protegidas: se a próxima faixa começou durante o gesto, o movimento é recusado. Mover uma pendente através de uma posição protegida também é recusado, evitando deslocar a faixa protegida indiretamente. Apenas posições realmente alteradas passam pelo estágio temporário negativo. IDs, fontes, metadados e repetições são preservados; o limite é de 10.000 ocorrências da coleção.

Durante a execução, o arraste move uma faixa por vez. As caixas/Ctrl não mudam a seleção que está alimentando a fila, e um arraste não desmarca trabalhos pendentes. Fora da execução, mantém-se o arraste em grupo das faixas selecionadas; incluir uma ocorrência protegida recusa todo o movimento. A mesma regra de domínio e o gesto de toque se aplicam ao layout mobile.

Extras continuam após as originais enquanto pertencem à execução ativa. Podem ser reorganizados entre si: os slots de inserção global são redistribuídos apenas entre as ocorrências da mesma coleção, mantendo o lugar dos extras de outras coleções. Um movimento que colocaria extras antes das originais durante a execução é recusado. Uma falha no movimento aparece imediatamente em popup central, inclusive com a transferência em andamento; não sobrescreve os avisos da própria transferência.

A M3U8 gerada ao terminar usa a nova ordem persistida. M3U8 já existente não é regravada pelo arraste isoladamente. Ainda não se trata da organização independente da biblioteca planejada em `DIRECAO_BIBLIOTECA_MUSICAL.md`.

## Validação e instalação

- `dart format`: 107 arquivos, nenhum ajuste pendente. `flutter analyze`: nenhum problema. Suíte completa: 130 testes aprovados.
- Teste controlado da execução usando os MP3s sintéticos locais: com o primeiro item retido, arrastar o terceiro para antes do segundo mantém o primeiro em execução e resulta em 1 → 3 → 2. Arquivos novos seguem as posições 001/002/003 e a M3U8 acompanha a nova ordem. Nenhum provedor real foi acessado neste ensaio.
- Testes de mouse em 900 px e toque em 390 px exercitam o arraste durante a execução, sem arraste na faixa já iniciada. Cobertura adicional de reinício/parada, tentativa de cruzar posição protegida, seleção com ocorrência iniciada, nomes ainda bloqueados e ordem global de extras de outra coleção.
- Layouts inspecionados em 1360 e 390 px. Isto não comprova execução nativa mobile nem implementa seu motor musical.
- Build Windows concluído. Os 122 arquivos de lib/test/assets/pubspec/lock conferem com o staging. Worker da 0.1.30 preservado por hash; sem alteração no protocolo, no motor ou nas dependências.
- Instalador local 0.1.31 gerado com SHA-256 registrado; aplicativo instalado `0.1.31+32`, registro Windows `0.1.31`, reaberto/respondendo e atalho conferido. Sem release/tag/publicação remota.
- Backup anterior preservado. Registros idênticos antes/depois da instalação e da reabertura: 2 coleções, 242 faixas, 11 arquivos no histórico, 10 preferências, 2.183 candidatos, 11 tentativas e nenhum grupo. Schema 10 e `quick_check=ok`; nenhuma transferência ativa foi interrompida para instalar.
- Evidências privadas em `%LOCALAPPDATA%\DefinitiveDownloaderDev\local-version-0.1.31`, incluindo logs, layouts, backup e hashes. Não entram no repositório.
