# Definitive Downloader 0.1.27 — versão local

Identificação `0.1.27+28`, solicitada em 04/11/2026 para acompanhar o ciclo de feedback sem publicar release. A indicação da interface recebe o sufixo local; pubspec, binário Windows e instalador usam a mesma numeração. Sem tag, push ou release nesta entrega.

Inclui os ajustes de busca automática, linhas para revisão, pesquisa/filtros/ordenação e barra de rolagem descritos em [Ajustes locais de Músicas](AJUSTES_LOCAIS_MUSICAS_2026_11_04.md).

Pedido posterior sobre a localização dos controles: confirmar correspondência, marcar revisão e informar fonte manual ficam dentro de Conferência, logo abaixo de Buscar outras versões e acima das candidatas. Nas faixas com fonte manual, as ações ficam abaixo do vínculo; nas concluídas, permanece a consulta da fonte. Essa mesma organização atende desktop e mobile. A barra da playlist mantém apenas download das selecionadas, adição de músicas por links, acesso aos downloads e menu de reconferência.

## Ações

| Controle | Função |
| --- | --- |
| Baixar selecionadas | Inicia o download das ocorrências selecionadas que tenham uma fonte pronta e abre Downloads. |
| Adicionar links | Acrescenta novas ocorrências à playlist. |
| Abrir downloads musicais | Abre o gerenciador de downloads de Músicas. |
| Confirmar correspondência | Confirma a candidata selecionada, ou a fonte já identificada; não inicia download. Videoclipe sugerido exige aprovação específica. |
| Marcar para revisão | Marca a ocorrência para reavaliar sua fonte, retirando sua elegibilidade para download até ser confirmada. |
| Informar link manualmente | Define a fonte prioritária da ocorrência focada; não cria uma nova música na playlist. Quando já existe vínculo, oferece editar/remover. |
| Mais ações da playlist | Oferece Rever correspondências, para refazer a busca da coleção; preserva fontes manuais e concluídas. |

Estados desabilitados continuam respeitando ausência de seleção/candidata, operação ocupada e disponibilidade real da fonte. Os tooltips identificam os ícones.

## Validação e instalação

Código formatado, análise estática sem problemas e build Windows release concluído. Os seis testes de layout foram executados novamente a 1920×1080, 1360×820, 900×820, 900×600, 390×820 e 320×820, com 1,3× de texto na menor largura; todos passaram. Capturas desktop/mobile inspecionadas para conferir a localização dos controles abaixo da pesquisa. Reutilizada a validação funcional anterior de 116 testes, sem nova alteração de regra de correspondência/download. Android/iOS nativos não validados nesta etapa.

Instalador local 0.1.27 gerado e executado com saída 0, atualizando também o cadastro de Aplicativos do Windows. Executável instalado com ProductVersion 0.1.27+28; interface 0.1.27 · local. App reaberto da instalação, processo e atalho conferidos.

Backup local de SQLite, executável e app.so antes de instalar. Schema 10 e quick_check=ok; zero downloads ativos. Banco preservado integralmente por hash antes/depois e após reabrir: duas coleções, 242 ocorrências, dez históricos, dez preferências, 2183 candidatos, dez tentativas e zero grupos. Nenhum arquivo musical movido ou removido, nenhuma credencial inspecionada.

118 fontes/testes/assets iguais ao staging compilado; hashes de executável, app.so, flutter_windows.dll, ICO e worker iguais entre pacote e instalação. Worker preservado com SHA-256 266B509F026A92827FA48E8335BF59865BB6B1B06552E56DB48276145D01D271. Pacote, instalador, capturas e backup guardados somente em diretório local privado. Sem tag, push ou release.
