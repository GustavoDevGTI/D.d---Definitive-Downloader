# Definitive Downloader 0.1.7

Identidade oficial aplicada em 29/10/2026 a partir do guia de marca fornecido pelo usuário. Flutter `0.1.7+8`; a versão do instalador é derivada do pubspec.

## Mudanças

- Símbolo D.d com seta interna no D, derivado do guia rasterizado e preparado como traçado vetorial limpo. Assinatura Definitive em grafite e Downloader em framboesa, com Manrope empacotada. Cores aproximadas dos pixels do guia: não foram fornecidos códigos ou fonte vetorial originais.
- Logo compacta na sidebar, assinatura horizontal no Início e símbolo nos cabeçalhos das categorias mobile. Tipografia adaptada para o nome continuar legível em 320 px com texto ampliado.
- Framboesa e neutros substituem o azul de identidade. Painéis e campos têm contornos claros e cantos mais suaves; botões, seleções e progresso seguem a marca. Layout sem margem externa e toolbar de ícones preservados.
- Quatro variantes em SVG/PNG: principal, monocromática, suave e contorno. O desenho Flutter usa os mesmos contornos das exportações; não há modelo generativo recriando a logo. `tools/export_brand_assets_test.dart` faz a exportação vetorial explícita para PNG.
- ICO com nove resoluções (16, 20, 24, 32, 40, 48, 64, 128 e 256 px) no executável Windows, instalador e atalhos. O atalho aponta para o ícone próprio empacotado, em vez do ícone padrão Flutter.
- Scripts de build aceitam `-WorkspaceRoot` para execução a partir de cópia local quando a política do Windows bloqueia scripts na UNC. A política de execução e as configurações de segurança não foram alteradas.

Plano, referências e regras de uso em [IDENTIDADE_VISUAL_0_1_7.md](IDENTIDADE_VISUAL_0_1_7.md).

## Verificação

- `dart format --output=none --set-exit-if-changed lib test tools/export_brand_assets_test.dart`: 70 arquivos, sem diferenças.
- `flutter analyze --no-pub`: sem problemas.
- `flutter test --no-pub`: 67 testes aprovados.
- Exportação vetorial: um teste explícito aprovado, 44 PNGs gerados a partir do desenho nativo, quatro PNGs selecionados para os assets e ICO com nove frames. Variantes principal e monocromática revisadas visualmente.
- Layouts 1920×1080, 1360×820, 900×820, 900×600, 390×820 e 320×820, com texto 1,3× no último. Início e Downloads revisados em desktop/mobile. As capturas em `docs/images/brand-017-*` usam dados isolados e não representam downloads reais.
- `flutter build windows --release --no-pub`: executável Windows `0.1.7+8` gerado. Exportação, análise, testes e compilação têm logs locais em `docs/evidencias/brand-017-*`.

- Inno Setup: instalador `0.1.7` de 75681968 bytes compilado com o novo ícone. ZIP portátil completo validado, sem arquivos corrompidos, e SHA-256 gerados. O pacote mantém FFmpeg e sua licença. Instalador sem assinatura digital.
- Atualização real da instalação Windows concluída com saída 0. Processo `0.1.7+8` iniciado a partir de `%LOCALAPPDATA%/Programs/Definitive Downloader`. O atalho da Área de Trabalho aponta para essa instalação e para o ICO da marca; nenhum instalador foi colocado na Área de Trabalho.
- Executável, `data/app.so`, ICO e worker têm hashes iguais no pacote final, em `dist` e na instalação. O ICO contém nove frames PNG válidos. Motor preservado: SHA-256 `EFD3B3C8B74030F4A1336120EEC80995CBF7511E49B01B692A1AB6A8D86F19C7`.
- Antes e depois da atualização: uma coleção, dez faixas, dez registros de histórico, schema 7 e `quick_check=ok`. Nenhum download estava ativo ao atualizar. As credenciais não foram inspecionadas; restauração de conta é responsabilidade do próprio fluxo do aplicativo e não foi tratada como novo teste real de provedor.

A revisão não muda schema, contas, fontes ou motor de download; não há limpeza dos dados. Sem novo ensaio de provedores reais, build APK/IPA ou obtenção nativa mobile. A revisão visual foi feita nas capturas de widgets; abertura do processo instalado e caminhos do atalho foram conferidos separadamente.

## Distribuição

[Release v0.1.7](https://github.com/GustavoDevGTI/D.d---Definitive-Downloader/releases/tag/v0.1.7), com instalador Windows x64, ZIP portátil e `SHA256SUMS.txt`. Pacote local em `%LOCALAPPDATA%/DefinitiveDownloaderDev/release-017`; versões anteriores preservadas. Fontes e documentação correspondem à tag. Logs, dados e diagnósticos de contas permanecem locais e não são publicados.
