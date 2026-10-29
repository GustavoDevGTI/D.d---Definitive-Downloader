# Definitive Downloader 0.1.8

Paleta oficial enviada pelo usuário em 29/10/2026. Flutter `0.1.8+9`; o instalador deriva a versão do pubspec. Os códigos da imagem substituem as aproximações da 0.1.7, preservando o traçado da logo e a tipografia Manrope.

## Mudanças

- Rosa `#C9345B` nas ações principais e na logo; vinho `#A01F45` nos estados de hover, foco e pressão dos botões principais, nas abas ativas e na seleção da navegação.
- Sidebar desktop azul-marinho `#23273F`, com assinatura branca legível e símbolo rosa. Navegação mobile clara, seleção vinho e ícones secundários `#5B6B85`.
- Texto `#1E293B`, descrições `#6B7280`, divisórias `#E5E7EB`, fundo `#FAFAFC`, seleção suave `#FDE7ED` e painéis `#F3F4F6`. Campos e linhas de listas brancos mantêm a hierarquia. Cores de sucesso/erro continuam semânticas.
- ColorScheme, painéis, listas, tabelas, filtros e formulários compartilham os tokens. Layout sem margem externa, funções e toolbar horizontal de ícones preservados.
- SVGs, quatro PNGs e ICO com nove resoluções atualizados a partir do mesmo desenho Flutter; executável, instalador e atalhos Windows usam esse ícone.

Referência e regras em [PALETA_OFICIAL_0_1_8.md](PALETA_OFICIAL_0_1_8.md). Não foram copiados os quadros ou legendas explicativas da imagem para a interface.

## Validação

- `dart format --output=none --set-exit-if-changed lib test tools/export_brand_assets_test.dart`: 70 arquivos, sem diferenças.
- `flutter analyze --no-pub`: sem problemas. `flutter test --no-pub`: 67 testes aprovados.
- Exportação explícita: um teste aprovado, 44 PNGs renderizados; os quatro assets e o ICO de nove resoluções foram atualizados. Pixels das variantes principal, monocromática e suave conferidos com os valores oficiais.
- Testes de layout a 1920×1080, 1360×820, 900×820, 900×600, 390×820 e 320×820; texto 1,3× no último. Início e Downloads revisados visualmente em 1360 e 320 px, com tabelas e toolbar roláveis. Capturas `docs/images/palette-018-*` usam fixtures isoladas, sem novos downloads reais.
- Build Windows release `0.1.8+9` compilado. Fontes Flutter, testes, assets, lockfile e ícone conferidos com a cópia compilada. Nenhuma dependência alterada.
- Inno Setup compilado: instalador de 75678134 bytes. ZIP portátil validado sem arquivos corrompidos; SHA-256 dos dois artefatos registrado em `SHA256SUMS.txt`. Instalador sem assinatura digital; FFmpeg e licenças preservados.
- Atualização real da instalação concluída com saída 0. App `0.1.8+9` aberto de `%LOCALAPPDATA%/Programs/Definitive Downloader`, com atalho da Área de Trabalho apontando para essa instalação e para o ICO da marca. Nenhum instalador colocado na Área de Trabalho.
- Executável, `data/app.so`, ICO e worker têm hashes iguais na instalação, pacote e `dist`. Worker preservado com SHA-256 `EFD3B3C8B74030F4A1336120EEC80995CBF7511E49B01B692A1AB6A8D86F19C7`.
- Banco antes/depois: uma coleção, dez faixas, dez registros de histórico, zero transferências ativas, schema 7 e `quick_check=ok`. Credenciais e cookies não foram inspecionados. Logs e diagnósticos locais em `docs/evidencias/palette-018-*`, fora do controle de versão.

A revisão visual usa capturas de widgets. Processo instalado, versão e caminhos do atalho foram conferidos separadamente; não houve ensaio visual nativo por automação de UI nesta rodada.

Esta revisão não muda schema, contas, ordem das playlists ou motor musical. Não há limpeza dos dados, novo ensaio de provedores reais ou implementação de motor nativo mobile. A validação visual mobile em widgets não equivale a instalação Android/iOS.

## Distribuição

[Release v0.1.8](https://github.com/GustavoDevGTI/D.d---Definitive-Downloader/releases/tag/v0.1.8), com instalador Windows x64, ZIP portátil e `SHA256SUMS.txt`. Versões anteriores preservadas. Dados e evidências de contas permanecem locais.
