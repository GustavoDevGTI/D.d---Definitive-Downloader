# Definitive Downloader 0.1.16

Animação de hover solicitada em 03/11/2026. Flutter `0.1.16+17`; instalador deriva a versão do pubspec.

Os controles de Downloads e os botões Adicionar links da coleção, fila e diálogo compartilham `ButtonHoverMotion`. O botão cresce até 108% no hover/foco e comprime até 94% ao pressionar; entrada, saída e retorno usam 160 ms com `easeOutCubic`. A transformação atua na pintura e não desloca os controles vizinhos. A barra reserva espaço para que o crescimento não seja cortado.

Estados vêm do próprio controlador do botão: animação não substitui o clique, teclado ou tooltip. Controles desabilitados ficam em escala neutra; a preferência de movimento reduzido desativa a transformação animada. As cores e os feedbacks da 0.1.15 permanecem, sem sombras/elevação.

## Validação

Os testes verificam tamanho intermediário e final após hover, retorno ao sair, compressão durante pressão, clique único preservado e geometria neutra com movimento reduzido ou botão desabilitado. Atualizações de estado durante a montagem do botão são adiadas para o fim do frame, evitando reconstrução do ancestral durante o build.

Layouts desktop/mobile e compactação de colunas continuam nos testes existentes. A revisão visual usa capturas com fixtures; não houve novo download real de provedor ou autenticação. Núcleo compartilhado Flutter; Android/iOS não foram compilados/executados e o motor musical mobile permanece pendente.

Formatação: 87 arquivos sem diferenças; análise estática sem problemas; 88 testes Flutter aprovados e build Windows release concluído. Layouts a 1920×1080, 1360×820, 900×820, 900×600, 390×820 e 320×820, com texto 1,3× no último. Hover revisado visualmente em 1360 e 320 px.

## Instalação e distribuição

Instalador executado com saída 0; aplicativo `0.1.16+17` aberto a partir da instalação local e atalho da Área de Trabalho conferido. Antes/depois: uma coleção, dez faixas, dez históricos, zero ativos, schema 9 e `quick_check=ok`. Backup local antes da atualização. Sem mudança de banco, matching, transferência ou contas; cookies/sessões não foram inspecionados.

100 arquivos de fontes/testes/assets idênticos ao staging compilado. Executável, `data/app.so`, ICO e worker idênticos por hash entre pacote e instalação. Worker preservado: SHA-256 `266B509F026A92827FA48E8335BF59865BB6B1B06552E56DB48276145D01D271`. ZIP verificado sem corrupção e sem banco, sessão ou transferência parcial. Evidências locais não entram na publicação. Capturas de widgets e conferência de versão/processo são verificações separadas; não houve automação visual nativa nesta rodada.

[Release v0.1.16](https://github.com/GustavoDevGTI/D.d---Definitive-Downloader/releases/tag/v0.1.16), com instalador Windows x64, ZIP portátil e `SHA256SUMS.txt`. Releases anteriores preservadas; instalador sem assinatura digital.

| Artefato | Bytes | SHA-256 |
| --- | ---: | --- |
| Setup Windows x64 | 75.728.290 | `8695bea8ac2425796310c269b50da47ac0d20b6bd04229a0c1956185651198b3` |
| ZIP Windows x64 | 99.527.010 | `e68b61168148a12ebea48d6d78c644d2e025a5691129dee7f987e65c30bf41a0` |
