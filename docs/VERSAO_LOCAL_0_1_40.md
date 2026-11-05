# Versão local 0.1.40 — espaço e controles de Coleções

Pedido de 04/11/2026, seguindo os sete prints enviados. Versão incrementada somente após implementar o conjunto: **0.1.40+41**. Sem release/tag/push durante o ciclo local.

## Ajustes na ordem das imagens

1. Ações de ouvir/abrir/copiar em Informações alinhadas à esquerda, como nas versões candidatas. Permanecem após os dados da versão; ações de conferência continuam abaixo da pesquisa.
2. Lista ocupa a altura antes consumida pelo voltar separado e pela barra de controles em outra linha. No desktop, controles, busca, filtro e ordenação ficam em uma faixa. Linhas de 76 px com capa, título de até duas linhas e artista. Quatro faixas completas com player aberto são requisito verificado por teste.
3. Os mesmos controles de playlist preservam posição e estilo; estados desabilitados continuam honestos. Fontes manuais, escuta, download e conferência permanecem independentes.
4. Ouvir playlist usa fundo vinho `#A01F45` e ícone branco, com hover/foco/pressionamento compartilhados. Baixar continua verde funcional, sem mudar suas condições de habilitação.
5. Voltar às coleções vira ícone com tooltip junto ao nome da playlist, sem uma faixa externa reservada. Contagem aparece quando há seleção, com singular/plural correto.
6. Bloco do nome mostra somente posição/título e artista. Fonte e disponibilidade do arquivo ficam em coluna própria; duração e correspondência continuam ao lado no desktop. Em largura compacta, a célula lateral reúne fonte, duração, indicador de correspondência e estado do arquivo. Fonte manual continua identificada por ícone/tooltip, sem texto adicional sob o artista.
7. Primeiro botão de iniciar em Downloads usa `download_rounded`, igual a Baixar em Coleções. A ação e os estados de pausa/retomada não mudaram.

## Direção e estrutura

Preservar Manrope, fundo `#FAFAFC`, superfícies `#F3F4F6`, texto `#1E293B`, secundário `#6B7280`, framboesa `#C9345B` e vinho `#A01F45`. Sem novos painéis, bolhas ou sombras. Em telas estreitas, busca e controles usam duas linhas, com rolagem horizontal dos comandos quando necessário.

```text
← Nome da playlist                         seleção
[play] [download] [links] [revisão] Pesquisa  Filtro  Ordem
Faixa / artista       Fonte / arquivo  Duração  Correspondência
```

`CollectionTrackToolbar` concentra somente apresentação e callbacks dos comandos/filtros. `TrackSourceCell` apresenta metadados fora da identificação. `CollectionWorkspace` conserva navegação, debounce e coordenação; tabela conserva arraste, seleção e paginação. Ordem, IDs, repetições, fontes manuais e regras de downloads não foram alterados. Schema 12 sem migração.

## Validação e instalação

`dart format lib test/player_navigation_test.dart`: 106 arquivos. Análise estática sem apontamentos. Testes de layout verificaram quatro faixas totalmente dentro do viewport e play/pesquisa na mesma linha com player aberto em 1360 px; navegação também em 900 e 390 px. Capturas inspecionadas em 1360 e 320 px, incluindo texto ampliado. Regras e UI compartilhadas em Dart; validação de widget mobile não comprova execução nativa Android/iOS.

Uma primeira suíte teve timeout ao aguardar fechar o diálogo de grupo em 390 px, num teste sem alterações funcionais neste ciclo. O ensaio isolado passou 3/3; não foi identificada a causa dessa ocorrência. Resultado final da suíte e instalação registrados a seguir.

Suíte final completa: **172 testes aprovados**, análise sem apontamentos e compilação Windows release concluída. Fontes/assets/testes (160 arquivos) comparados com o staging; worker musical congelado preservado. Pacote e instalação conferidos por hash, EXE **0.1.40+41**, registro **0.1.40**, installer local com SHA-256. Atalho continua apontando ao app instalado.

Backup anterior preservado. Banco antes/depois idêntico (schema 12, `quick_check=ok`): 2 coleções, 242 ocorrências, 11 registros de arquivos, 10 preferências, 2183 candidatas, 11 tentativas e 0 grupos. Seleção alterada durante a conferência foi restaurada pela UI antes do comparativo final. Nenhum download iniciado ou arquivo real movido/excluído.

Conferência nativa em 1366 px: **cinco faixas inteiras visíveis** com player aberto; play vinho, comandos/pesquisa em uma linha, voltar ao lado do título, coluna Fonte/arquivo separada e ações de escuta à esquerda em Informações. Ícone de iniciar Downloads confirmado como seta de download. App deixado aberto em Coleções. Evidências privadas em `%LOCALAPPDATA%/DefinitiveDownloaderDev/local-version-0.1.40`.
