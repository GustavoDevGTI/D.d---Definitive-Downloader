# Levantamento de botões e densidade

Avaliação da interface 0.1.89, solicitada em 18/11/2026. As mudanças abaixo são propostas para uma próxima etapa visual.

| Área | O que revisar | Proposta |
| --- | --- | --- |
| Downloads | Até oito ações de 48 px, com contornos e fundos próprios, competem com busca e filtros. | Toolbar desktop de controles de 32–36 px. Separar iniciar/pausar/parar de manutenção da fila. Reunir opções ocasionais em menu. Preservar alvos de toque no celular. |
| Tabela de downloads | Cabeçalho de 56 px, linhas mínimas de 56 px, três linhas na célula Nome e scrollbars de 10 px criam a sensação de ampliação. | Experimentar cabeçalho de 32 px e linhas de 40 px no desktop. Usar duas linhas para música/artista e um indicador curto de playlist, com nome completo no tooltip. Scrollbars de 6 px. |
| Colunas | Muitos indicadores com larguras próprias reduzem o espaço do nome e truncam títulos do cabeçalho. | Destinar mais largura ao nome. Medidas e tempos alinhados. Disponibilizar escolha de colunas e lembrar a configuração. Manter o caminho completo acessível por tooltip/localização. |
| Conferência | Controles de confirmar, revisão, fonte manual, conexões e escuta usam tratamentos diferentes no mesmo painel. | Escolha de versão e confirmação com uma hierarquia explícita. Referência/copiar como utilitários discretos, alinhados numa única barra. |
| Ouvir e candidatas | Texto de escuta e ícones de referência usam alvos de 36 px, enquanto ações próximas usam 48 px. | Mesmo eixo e ritmo de espaçamento. Ícones com tamanho único por contexto. Ajustar alvos por desktop/toque. |
| Playlists | Menus e ações gerais foram simplificados na 0.1.89, mas a toolbar de faixas ainda tem vários ícones contornados. | Priorizar ouvir, baixar e conferir. Considerar uma ação Adicionar com escolhas de links/arquivos. Preservar rótulos acessíveis e atalhos. |
| Arquivos | O botão Pasta principal usa StadiumBorder, diferente dos botões retangulares das outras telas. Breadcrumbs e ações de arquivo variam de peso visual. | Acesso à pasta junto do breadcrumb. Utilitários consistentes e sem pílula destacada. |
| Configurações | Há painéis dentro de painéis e seletor de qualidade com raio de 24 px, além de opções informativas aparentando configuração. | Linhas diretas com separadores. Controles editáveis com tratamento consistente. Estados informativos legíveis e identificados. |
| Conexões | Ações de login, recuperar acesso, desconectar e fechar variam entre texto, preenchimento e contorno em vários diálogos. | Uma ação principal por etapa, recuperação como ação secundária e fechamento no mesmo lugar. |
| Diálogos e estados vazios | Botões locais definem padding, raio e alturas independentemente do tema compartilhado. | Consolidar alturas, raios e espaçamento no tema por contexto. Medir tamanho de texto e foco em telas estreitas. |

## Escala proposta para Downloads

A referência JDownloader 2 orienta a densidade de informação. A aplicação manteria sua identidade visual e as cores das playlists.

- Desktop padrão compacto com fonte de 11–12 px, cabeçalho de 32 px, linhas de 40 px e separadores sutis.
- Nome flexível, métricas curtas, texto numérico alinhado e detalhe extenso por tooltip.
- Modo confortável disponível para quem preferir linhas maiores.
- Celular com alvos de toque de 48 px, filtros numa linha e rolagem contida na tabela.
- Validar com 100%/125%/150% de escala do Windows, texto ampliado, nomes longos e filas grandes.

## Ordem sugerida

1. Densidade de Downloads e redistribuição das colunas.
2. Barra de ações de Downloads.
3. Conferência e controles de escuta.
4. Arquivos, Configurações e diálogos.

As bases observadas estão em download_table.dart, download_action_button.dart, download_workspace.dart, download_row_cells.dart, track_inspector.dart, listening_actions.dart, history_workspace.dart e settings_workspace.dart.
