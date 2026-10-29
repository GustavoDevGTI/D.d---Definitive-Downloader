# Paleta oficial — Definitive Downloader

Os códigos abaixo foram fornecidos pelo usuário na imagem de paleta em 29/10/2026. São os valores oficiais, aplicados a partir da versão 0.1.8. Substituem as aproximações extraídas do primeiro guia rasterizado na 0.1.7.

| Cor | Código | Aplicação |
| --- | --- | --- |
| Rosa principal | `#C9345B` | Logo principal, botões de ação, progresso |
| Vinho escuro | `#A01F45` | Hover, foco e pressão das ações principais; navegação/abas ativas |
| Azul-marinho | `#23273F` | Sidebar, assinatura da marca e variante monocromática |
| Azul acinzentado | `#5B6B85` | Ícones de apoio e controles secundários |
| Texto principal | `#1E293B` | Títulos, corpo e valores |
| Texto secundário | `#6B7280` | Descrições e legendas |
| Borda / divisores | `#E5E7EB` | Linhas, separadores e contornos |
| Fundo principal | `#FAFAFC` | Área principal da interface |
| Fundo destacado | `#FDE7ED` | Seleção, abas e destaques suaves |
| Fundo de cards | `#F3F4F6` | Painéis, cabeçalhos de tabelas e superfícies |

## Aplicação

- Tokens compartilhados em `lib/app/theme.dart`; as cores relevantes do `ColorScheme` são explícitas, evitando tons de apoio gerados automaticamente a partir do rosa. Branco é preservado nos campos e nas linhas das listas para hierarquia e legibilidade. Cores semânticas de sucesso/erro continuam distinguindo resultados.
- A barra lateral desktop é azul-marinho; a seleção usa vinho com texto e ícones brancos. A assinatura aparece em branco sobre esse fundo, preservando o símbolo rosa e a leitura em tamanho compacto. No conteúdo claro, a assinatura mantém azul-marinho e rosa.
- No mobile, a navegação inferior mantém superfície clara, ícones secundários azul acinzentado e seleção vinho. Identidade e navegação são compartilhadas sem comprimir a sidebar desktop.
- Ícones nativos, SVGs e PNGs usam os mesmos valores oficiais e o traçado da logo já aprovado. Sem mudanças na geometria, na tipografia Manrope ou na estrutura das telas.
- Hover/foco/pressão usam vinho; foco de teclado e tooltips permanecem disponíveis. Estados desabilitados permanecem distintos dos ativos.

As molduras e textos explicativos da referência são documentação da marca; não são componentes a reproduzir no aplicativo.
