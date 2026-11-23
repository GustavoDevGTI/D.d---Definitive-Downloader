# Escala da interface desktop

Referência aprovada: controles de Downloads da 0.1.92. Aplicação geral na 0.1.93. As medidas são pixels lógicos do Flutter.

| Elemento | Medida de referência |
| --- | --- |
| Ação principal, secundária ou ícone de ação | Altura mínima de 40 px |
| Ícone de ação | 20 px |
| Cantos de controles e campos | Raio de 8 px |
| Texto de formulário e botão | 12 px, Manrope |
| Título da seção | 18 px |
| Campo de uma linha | Mínimo de 40 px, sem limitar campos multilinha |
| Margens laterais da área de trabalho | 14 px |
| Margem superior das páginas desktop | 24 px |
| Distância do título às abas | 12 px |
| Espaçamento entre ações | 4–8 px |
| Linhas em Coleções | 52 px na escala normal, capa de 32 px |
| Linhas de Downloads | 40 px na escala normal |
| Cabeçalhos de tabelas | 32 px |
| Linhas de navegação com título e descrição | Mínimo de 56 px |

As medidas comuns ficam em `lib/app/density.dart`, consumidas pelo tema e pelos componentes. `appTheme` padroniza botões, ícones, campos, listas e diálogos. Abas, filtros, capas e indicadores têm hierarquia própria; o controle de reprodução principal conserva sua forma circular. Identidade da marca, cores das playlists e azul das ações de download são preservados.

A barra de faixas reserva pelo menos 140 px de busca ao decidir se as ações cabem na mesma linha. O cálculo considera a quantidade de comandos e a largura real do texto de conferência na escala atual. Em telas estreitas, a busca pode ocupar uma linha própria. Contadores e rótulos de opções permitem ajuste de largura sem transbordar.

Listas musicais usam a mesma altura calculada para renderização, seleção por Ctrl/arraste, arraste de reordenação e revelação de linhas. Texto ampliado pode aumentar a altura das linhas. A lista mantém a virtualização e a rolagem contínua.

Os valores de toque continuam separados na definição de densidade. Esta entrega valida o Windows; o trabalho de Android permanece pausado.
