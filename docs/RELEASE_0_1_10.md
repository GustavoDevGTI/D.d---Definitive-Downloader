# Definitive Downloader 0.1.10

Destaque das coleções solicitado em 03/11/2026: as linhas cinzas pareciam pouco interativas. Flutter `0.1.10+11`; instalador deriva a versão do pubspec.

## Mudança

As coleções passam a usar botões de largura total com fundo rosa suave `#FDE7ED`, contorno e ícones rosa `#C9345B`, título em `#1E293B` e metadados com menor ênfase. Um ícone musical identifica a coleção e o chevron destaca a abertura. Manrope, lista vertical e cantos de 12 px preservados.

Hover, foco e pressão usam fundo vinho `#A01F45` com texto e ícones brancos. O botão nativo mantém semântica, foco e ativação por teclado. Nome aceita duas linhas e metadados quebram conforme o espaço e a escala de texto, sem altura fixa. Não foram adicionadas orientações permanentes, sombras, gradientes ou novas funções.

O tratamento fica restrito às coleções clicáveis; painéis informativos, tabelas e outros controles mantêm sua hierarquia. A abertura da coleção, paginação e dados continuam iguais. Widgets compartilhados atendem desktop e mobile; a paleta e logo oficiais permanecem conforme `PALETA_OFICIAL_0_1_8.md`.

## Validação

- `dart format --output=none --set-exit-if-changed lib test tools/export_brand_assets_test.dart`: 70 arquivos, sem diferenças.
- `flutter analyze --no-pub`: sem problemas. `flutter test --no-pub`: 67 testes aprovados, incluindo abertura de coleções e navegação para conferência/downloads.
- Layouts a 1920×1080, 1360×820, 900×820, 900×600, 390×820 e 320×820; texto 1,3× no último. Coleções revisadas visualmente em 1360 e 320 px; hover capturado por ponteiro real do teste de widgets em 1360 px. Capturas `docs/images/collections-0110-*` usam fixtures, sem downloads reais.
- `flutter build windows --release --no-pub`: Windows `0.1.10+11` compilado. Fontes, testes, assets, lockfile e ícone correspondem à cópia compilada; dependências preservadas.
- Inno Setup: instalador de 75671355 bytes. ZIP portátil validado sem corrupção e SHA-256 dos dois arquivos registrado. Instalador sem assinatura digital; FFmpeg e licenças preservados.
- Atualização real com saída 0; processo `0.1.10+11` iniciado da instalação em `%LOCALAPPDATA%/Programs/Definitive Downloader`. Atalho da Área de Trabalho aponta para essa instalação e o ícone da marca; nenhum instalador colocado na Área de Trabalho.
- Executável, `data/app.so`, ICO e worker conferidos por hash entre pacote, `dist` e instalação. Worker preservado: SHA-256 `EFD3B3C8B74030F4A1336120EEC80995CBF7511E49B01B692A1AB6A8D86F19C7`.
- Banco antes/depois: uma coleção, dez faixas, dez registros de histórico, zero downloads ativos, schema 7 e `quick_check=ok`. Credenciais e cookies não foram inspecionados. Logs e diagnósticos locais em `docs/evidencias/collections-0110-*`, fora do controle de versão.

A revisão visual usa capturas de widgets; versão, processo e atalho da instalação foram conferidos separadamente. Não houve automação visual nativa nesta rodada, nem ensaio independente de ativação por teclado.

Esta revisão não altera banco, matching, fontes ou motor de download. Sem novo teste real de provedores; validação mobile em widgets não equivale a build Android/iOS ou motor nativo mobile.

## Distribuição

[Release v0.1.10](https://github.com/GustavoDevGTI/D.d---Definitive-Downloader/releases/tag/v0.1.10), com instalador Windows x64, ZIP portátil e SHA-256. Versões anteriores preservadas. Dados e diagnósticos de contas permanecem locais.
