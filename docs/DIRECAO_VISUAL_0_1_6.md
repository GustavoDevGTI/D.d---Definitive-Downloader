# Direção visual 0.1.6

Pedido de 29/10/2026: ocupar a janela inteira, simplificar Downloads para uma linha de ícones e tornar o D.d mais pessoal e jovem. Esta direção substitui a contenção e os painéis de indicadores das referências 0.1.4/0.1.5; preserva a organização funcional e os dados reais.

## Pesquisa e proposta

Referências primárias consultadas: [Transmit](https://panic.com/transmit/), organização de uma ferramenta de transferência, e [Things](https://culturedcode.com/things/), apresentação de um aplicativo pessoal em desktop/mobile. São referências de clareza e navegação; não serão copiados seus componentes, marcas ou paletas.

Paleta: papel frio `#F7F8FC`, branco `#FFFFFF`, tinta `#25283D`, secundário `#677084`, framboesa `#B93655` e azul `#3864A5`. O framboesa aparece na marca e na ação principal; o azul identifica músicas. Superfícies de apoio claras, sem gradientes e sombras.

Tipografia: Manrope existente, títulos de 28–34 px no Início, títulos funcionais de 22 px, leitura de 12–14 px. Manter a fonte já empacotada evita dependências externas. Alinhamento à esquerda, poucas linhas de texto, contraste e foco de teclado.

Estrutura:

```text
marca / menu | Início
             | O que vem pra coleção?          ação para importar
             | [Minhas coleções] [Meus arquivos]
             | registros    baixando    concluídos
             | Downloads: Músicas / Vídeos e fotos
             | Arquivos recentes, somente registros reais

Downloads    | título / total
             | ▶  Ⅱ  ■  |  ↑  ↓  |  pasta  repetir  remover
             | filtros
             | tabela com espaço para os arquivos
```

Desktop: sidebar encostada à janela, sem margem externa, borda ou largura máxima do aplicativo. Manter apenas o padding interno de leitura. Mobile: navegação inferior, ações adaptadas à largura, indicadores com quebra e toolbar de ícones em linha horizontal rolável com alvos de 48 px.

## Revisão antes de implementar

A primeira organização ainda repetia o painel administrativo com cartões de números. Foi substituída por uma faixa de indicadores sem caixas e uma lista de arquivos recentes. Na crítica da primeira captura, o título promocional e a ênfase em capturas ainda planejadas foram retirados. A frase de abertura ficou direta e os dois atalhos passaram a priorizar Coleções e Arquivos, que já funcionam. Captura continua nas respectivas categorias. A personalidade vem da marca D.d, da tipografia e do acento framboesa; não de mascotes, imagens de catálogo fictícias ou novas funções.

Não acrescentar player, recomendações, estatísticas inventadas ou captura disponível onde ainda não existe. Tooltips e descrições acessíveis preservam a explicação dos comandos sem os botões textuais grandes. Estados desabilitados continuam reais.
