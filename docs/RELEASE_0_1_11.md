# Definitive Downloader 0.1.11

Pastas de Arquivos com o mesmo destaque das coleções, conforme a imagem enviada em 03/11/2026. Flutter `0.1.11+12`; o instalador deriva a versão do pubspec.

## Mudança

- Pastas deixam o painel cinza e usam fundo rosa suave `#FDE7ED`, contorno e ícones rosa `#C9345B`. Hover, foco e pressão usam vinho `#A01F45` com conteúdo branco.
- Ícone de pasta e chevron reforçam a navegação. Contagem usa “1 arquivo” / “N arquivos”; o caminho completo continua no tooltip.
- Coleções e pastas compartilham `WorkspaceNavigationButton`, evitando divergência de cores, foco, tamanho e adaptação. Título permite duas linhas e metadados quebram conforme a largura e a escala de texto.
- A abertura das pastas, histórico, busca e paginação permanecem iguais. Linhas dos arquivos mantêm seus estados de disponibilidade e ações. Nenhuma orientação permanente ou função nova.

Widgets compartilhados atendem desktop e mobile; logo e paleta oficiais preservadas.

## Validação

- `dart format --output=none --set-exit-if-changed lib test tools/export_brand_assets_test.dart`: 70 arquivos, sem diferenças.
- `flutter analyze --no-pub`: sem problemas. `flutter test --no-pub`: 67 testes aprovados. A suíte existente captura também o hover das pastas quando a exportação visual está habilitada.
- Layouts a 1920×1080, 1360×820, 900×820, 900×600, 390×820 e 320×820; texto 1,3× no último. Pastas revisadas visualmente em 1360 e 320 px, incluindo hover desktop; coleções conferidas após compartilhar o componente. Capturas `docs/images/folders-0111-*` usam fixtures isoladas, sem downloads reais.
- Windows release `0.1.11+12` compilado. Fontes, testes, assets, pubspec, lockfile e ícone correspondem à cópia compilada; dependências preservadas. Logs de build inicial e final mantidos localmente.
- Inno Setup: instalador de 75665860 bytes. ZIP portátil validado sem corrupção e SHA-256 dos dois artefatos registrado. Instalador sem assinatura digital; FFmpeg e licenças preservados.
- Atualização real concluída com saída 0. Processo `0.1.11+12` iniciado em `%LOCALAPPDATA%/Programs/Definitive Downloader`; atalho da Área de Trabalho aponta para a instalação e o ícone da marca. Nenhum instalador colocado na Área de Trabalho.
- Executável, `data/app.so`, ICO e worker têm hashes iguais na instalação, pacote e `dist`. Worker preservado: SHA-256 `EFD3B3C8B74030F4A1336120EEC80995CBF7511E49B01B692A1AB6A8D86F19C7`.
- Banco antes/depois: uma coleção, dez faixas, dez registros de histórico, zero downloads ativos, schema 7 e `quick_check=ok`. Credenciais e cookies não foram inspecionados. Evidências locais em `docs/evidencias/folders-0111-*`, fora do controle de versão.

A revisão visual usa widgets; versão, processo e atalho da instalação foram conferidos separadamente. Não houve automação visual nativa ou ensaio independente de ativação por teclado nesta rodada.

Sem mudanças no banco, matching ou motor musical. Não houve novo ensaio de provedores reais. Layout mobile em widgets não equivale a build Android/iOS ou motor nativo mobile.

## Distribuição

[Release v0.1.11](https://github.com/GustavoDevGTI/D.d---Definitive-Downloader/releases/tag/v0.1.11), com instalador Windows x64, ZIP portátil e SHA-256. Versões anteriores preservadas. Evidências locais e dados de contas não entram na publicação.
