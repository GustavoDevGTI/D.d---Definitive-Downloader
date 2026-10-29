# Identidade visual 0.1.7

O guia de marca enviado pelo usuário em 29/10/2026 é a nova referência oficial. O símbolo D.d com seta interna substitui a abreviação tipográfica simples e o ícone padrão do Flutter. O nome permanece Definitive Downloader.

## Plano antes da implementação

Paleta derivada visualmente do guia PNG: framboesa `#B83657`, grafite `#272B3D`, fundo `#F8F9FB`, superfície `#FFFFFF`, contorno `#E7E9EF` e fundo de destaque `#FBEFF3`. As cores são aproximações de pixels do guia rasterizado, que não informa códigos oficiais. Manrope continua como fonte empacotada; nome da marca com peso 700 e textos funcionais com a escala existente.

Símbolo: traçado vetorial derivado do maior ícone do guia, preservando D, seta, ponto e d. O fundo é uma forma quadrada arredondada. A exportação limpa usa cor sólida, sem reproduzir a textura da imagem de apresentação. Não usar as molduras, legendas ou exemplos de aplicação do guia como elementos da interface.

Layout: aplicação segue ocupando toda a janela. Assinatura compacta na sidebar, assinatura horizontal no Início e símbolo no cabeçalho mobile das categorias. Nome em grafite/framboesa como no lockup enviado. Botões e seleção em framboesa; o azul deixa de ser cor de identidade. Contornos claros e cantos suaves nos painéis e campos; sem sombras ou gradientes decorativos na interface.

```text
sidebar: [símbolo] Definitive     | [símbolo] Definitive Downloader
                  Downloader    | conteúdo do Início

mobile:  [símbolo] Músicas
         abas / toolbar de ícones / tabela
         navegação inferior
```

Revisão do plano: manter a tela funcional da 0.1.6 e concentrar a mudança na marca. Não transformar o guia em um mural de cartões, não recriar a logo com outra tipografia desenhada por IA e não adicionar funções ou dados de demonstração à biblioteca real. SVG e desenho nativo compartilham o traçado; PNG e ICO são exportações desse desenho para os contextos que exigem bitmap.

## Variações e plataformas

Variações principal, monocromática, fundo suave e contorno seguem os usos exemplificados no guia. O app usa desenho Flutter compartilhado, e o Windows recebe ICO com múltiplas resoluções no executável, instalador e atalho. PNGs e SVGs ficam disponíveis em `assets/brand/` para integrações mobile futuras. A validação visual mobile usa widgets; não equivale a um build ou instalação Android/iOS.
