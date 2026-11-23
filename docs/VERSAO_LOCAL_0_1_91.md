# 0.1.91 — Downloads mais compacto no Windows

Aplicação do ajuste de escala solicitado em 19/11/2026. A tabela aproveita mais a janela e seu conteúdo usa uma escala menor.

- Cabeçalho da tabela: 56 → 32 px.
- Linhas: 56 → 40 px na escala normal, com altura proporcional ao texto ampliado.
- Texto da tabela: 11 px; artista em segunda linha de 10 px. O nome da playlist permanece no tooltip e a identificação por cor continua na linha inteira e na faixa lateral.
- Ações da fila: 48 → 34 px, ícones de 18 px, hover e tooltips preservados. Removida a caixa externa da toolbar.
- Busca de 34 px na mesma linha dos controles também em janelas desktop menores. Filtros de 28 px logo abaixo.
- Margens laterais da área de Downloads: 28 → 14 px. Reduzidos os espaços do título, das abas e do rodapé para ampliar a tabela.
- Barras de rolagem de 6 px e trilho reservado de 8 px no desktop. Cabeçalho fixo e sincronização horizontal mantidos.
- Ordenação, redimensionamento, seleção por Ctrl/arraste, estados da fila e arquivos permanecem independentes do ajuste visual.

Escopo desta entrega: Windows. Android permanece pausado, sem emulador ou geração de APK.

Validação: análise estática sem problemas e 33 testes essenciais/focados aprovados, incluindo cabeçalho fixo, redimensionamento, rolagem até a última linha e seleção por Ctrl/arraste. O teste de janela completa mede a ampliação da tabela, a escala dos controles e o alinhamento da busca em 1366×768 e 1024×600. As capturas dessas duas janelas foram inspecionadas. O instalador Windows foi gerado e copiado ao projeto compartilhado com SHA-256 conferido.

Versão local 0.1.91+92, sem release no GitHub.

O aplicativo instalado foi atualizado para 0.1.91+92 e a aba Downloads foi aberta e conferida na janela real. A biblioteca teve backup privado antes da instalação; integridade SQLite e IDs anteriores de coleções, faixas e histórico foram preservados.
