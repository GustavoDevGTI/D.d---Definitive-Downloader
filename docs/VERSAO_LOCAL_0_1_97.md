# 0.1.97 — Rever correspondência da faixa selecionada

Correção Windows 0.1.97+98 para o aviso “0 faixa(s) preparada(s). 0 para revisão” ao tentar conferir novamente uma faixa já confirmada/baixada.

O botão acionava a preparação automática de pendentes. Uma ocorrência já confirmada não entrava nessa busca, e o resumo vazio dava a impressão de que ela tinha sido conferida novamente. O teste de regressão observou a ausência da nova chamada de busca antes da correção.

Com uma única faixa selecionada e visível, o botão passa a **Rever correspondência**. Essa ação abre a aba Correspondência e pesquisa versões para aquela ocorrência, independentemente de já haver fonte confirmada. Os resultados ficam na Conferência, sem popup genérico de sucesso. Nenhum resultado e erros continuam sendo informados.

Para uma faixa concluída, as alternativas são de consulta/comparação: não há rádio de escolha ou botão de substituir a versão. A fonte, o arquivo, a posição, o histórico e o estado de recuperação permanecem preservados; a ação não inicia downloads. Fontes manuais também permanecem preservadas ao comparar. O fluxo explícito de baixar novamente continua separado e exige a escolha manual da fonte e um novo comando de download.

Ao abrir uma faixa concluída normalmente, Informações continua sendo a aba inicial. Somente o pedido explícito de rever abre Correspondência. Sem uma única seleção visível, **Iniciar conferência** continua preparando pendentes. Uma playlist sem pendências recebe mensagem específica, em lugar do resumo numérico vazio.

## Validação

Análise sem problemas. Núcleo essencial + conferência/recuperação: 43 testes aprovados. O teste que reproduz a imagem falhou antes da correção porque não havia nova chamada de busca e passou depois, preservando bytes do arquivo de fixture, estado concluído, caminho, fonte e recuperação.

O botão e o painel foram exercitados em 900 e 390 px: abertura explícita de Correspondência, campo de busca visível, candidatas disponíveis para consulta e ausência de rádio/botão de substituição para concluída. Os testes de abrir concluída normalmente em Informações e exigir decisão manual para baixar novamente continuaram passando.

Compilação Windows Release e instalador concluídos. Aplicativo instalado e iniciado, com versão 0.1.97+98 conferida; instalador copiado à pasta compartilhada e validado por SHA-256 `e72570d9f777e236c76886dfb89cf45059ecf9ff15c7463fe12dcea6bff55bc8`.

Sem contas reais, emulador, APK ou publicação nesta entrega local. As buscas e o arquivo dos testes são fixtures; não constituem novo ensaio de download de plataforma.
