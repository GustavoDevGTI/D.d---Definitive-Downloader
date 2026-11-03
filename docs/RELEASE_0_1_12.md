# Definitive Downloader 0.1.12

Padronização dos formulários de links solicitada em 03/11/2026. Flutter `0.1.12+13`; instalador deriva a versão do pubspec.

## Mudança

Importar playlist, Capturar áudio e Capturar mídias passam a compartilhar `LinkEntryPanel`, em vez de montar campos e ações com estilos diferentes.

- Mesmo título, painel neutro com padding de 16 px, campo branco com rótulo e cantos de 12 px e espaçamento de 12 px até as ações.
- Ação principal preenchida, em rosa quando habilitada, com hover/foco vinho. Ações secundárias contornadas e ícones discretos; mínimo de 48 px e tipografia comuns.
- Ações alinhadas à esquerda e com quebra em linhas no mobile. Importação mantém Conexões e CSV dentro da mesma área de ações; captura usa a mesma posição para Analisar link.
- Campo, título e rótulo da ação continuam próprios de cada operação. Captura segue indisponível, com botão desabilitado e aviso curto. Nenhuma capacidade planejada foi habilitada pela revisão visual.
- Controller, foco e envio por teclado da playlist preservados. Sem novas orientações permanentes, alterações de logo/paleta ou mudanças no fluxo de download.

A regra de consistência entre funções parecidas passa a constar em `AGENTS.md`. O componente é compartilhado entre desktop e mobile.

## Validação

- `dart format --output=none --set-exit-if-changed lib test tools/export_brand_assets_test.dart`: 71 arquivos, sem diferenças.
- `flutter analyze --no-pub`: sem problemas. `flutter test --no-pub`: 67 testes aprovados na rodada final, incluindo espaçamento campo/ação, navegação e captura desabilitada. A verificação existente foi adaptada de OutlinedButton para FilledButton.
- Layouts a 1920×1080, 1360×820, 900×820, 900×600, 390×820 e 320×820; texto 1,3× no último. Importação e captura revisadas visualmente em 1360 e 320 px. A primeira revisão levou ao ajuste final de tipografia e altura dos controles; os layouts foram novamente verificados. Capturas `docs/images/forms-0112-*` usam fixtures, sem downloads reais.
- Windows release `0.1.12+13` compilado. Fontes, testes, assets, pubspec, lockfile e ícone correspondem à cópia compilada; dependências preservadas. Logs das rodadas inicial/final permanecem locais.
- Inno Setup: instalador de 75675679 bytes. ZIP portátil validado sem corrupção e SHA-256 dos dois artefatos registrado. Instalador sem assinatura digital; FFmpeg e licenças preservados.
- Atualização real com saída 0; processo `0.1.12+13` iniciado em `%LOCALAPPDATA%/Programs/Definitive Downloader`. Atalho da Área de Trabalho aponta para a instalação e o ícone da marca; nenhum instalador colocado na Área de Trabalho.
- Executável, `data/app.so`, ICO e worker conferidos por hash entre pacote, `dist` e instalação. Worker preservado: SHA-256 `EFD3B3C8B74030F4A1336120EEC80995CBF7511E49B01B692A1AB6A8D86F19C7`.
- Banco antes/depois: uma coleção, dez faixas, dez registros de histórico, zero downloads ativos, schema 7 e `quick_check=ok`. Credenciais e cookies não foram inspecionados. Evidências locais em `docs/evidencias/forms-0112-*`, fora do controle de versão.

A revisão visual usa capturas de widgets; versão, processo e atalho da instalação foram conferidos separadamente. Não houve automação visual nativa nesta rodada.

Sem alterações no banco, matching ou motor musical. Não houve novo ensaio real de provedores. Layout mobile em widgets não equivale a build Android/iOS ou motor nativo mobile.

## Distribuição

[Release v0.1.12](https://github.com/GustavoDevGTI/D.d---Definitive-Downloader/releases/tag/v0.1.12), com instalador Windows x64, ZIP portátil e SHA-256. Versões anteriores preservadas; dados e evidências de contas permanecem locais.
