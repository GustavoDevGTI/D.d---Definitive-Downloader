# 0.1.101 — Adiamento da conexão após importar playlist

Entrega local Windows 0.1.101+102.

Na oferta opcional de conexão após inserir uma playlist Spotify ou Deezer, a ação secundária passa a ser somente **Deixar para mais tarde**. Ela retorna a decisão de adiamento e permite prosseguir; não aparece também um Cancelar concorrente. Essa distinção usa o contexto `allowLater`, que o catálogo de playlists já fornece às duas origens.

Ao abrir por **Conectar Deezer** na coleção ou na área de importação, permanece **Cancelar**, retornando cancelamento. A ação principal de entrada e o restante da autenticação permanecem iguais.

## Validação

Análise sem problemas. Essenciais e focados: 37 testes aprovados. As duas origens foram exercitadas em 390/1360 px, verificando ausência da ação oposta e retorno exato de adiamento/cancelamento. Imagens de ambas as variantes desktop foram inspecionadas; ações alinhadas e sem duplicação. Sem login real ou emulador.

Compilação e instalador Windows concluídos. Versão 0.1.101+102 instalada e iniciada; instalador copiado ao compartilhamento com SHA-256 `588622cee3e362dba8fa15816e1a0e1163f09986acf1ede07e4bc70b135605a5`. Sem publicação no GitHub ou APK nesta etapa.
