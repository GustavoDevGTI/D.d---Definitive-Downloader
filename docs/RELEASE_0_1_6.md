# Definitive Downloader 0.1.6

Revisão visual de 29/10/2026 solicitada pelo usuário: retirar o espaço externo, reduzir os controles de Downloads a uma linha de ícones e dar ao aplicativo uma linguagem mais pessoal. Flutter `0.1.6+7`; o instalador deriva sua versão de `pubspec.yaml`.

## Design aplicado

- O aplicativo preenche a área disponível da janela. Retirados a margem externa de 12 px, a contenção de 1240 px e o contorno do aplicativo. A barra de título e a borda nativas do Windows permanecem; o padding interno serve somente à leitura e aos controles.
- Marca D.d maior, sidebar contínua de 204 px e navegação em framboesa. Superfícies brancas e frias, Manrope já empacotada e cores de apoio azul/framboesa. Nenhuma fonte ou imagem externa é carregada pelo app.
- Início com abertura mais informal, importação de playlist em destaque, dois atalhos para Coleções e Arquivos, três indicadores reais sem caixas e lista dos cinco arquivos mais recentes. No celular os indicadores continuam juntos, com tipografia compacta; a página rola normalmente.
- A captura continua nas categorias. Os atalhos do Início priorizam as funções já implementadas; o design não promove captura geral ou vídeos/fotos como disponíveis.
- Downloads: oito botões de ícones em uma linha, com alvos de 48 px, foco de teclado, tooltips e descrições semânticas. Iniciar, Pausar/Retomar, Parar, prioridades, Abrir pasta, Tentar novamente e Remover preservam as regras da versão 0.1.5. A linha rola horizontalmente quando necessário, sem agrupar os comandos em duas caixas.
- Filtros, abas, tabelas, conferência e configurações compartilham os novos acentos. O espaço recuperado pela toolbar fica disponível para a tabela. A navegação inferior mobile não usa sombra.

Pesquisa, tokens, wireframe e crítica das primeiras capturas em [DIRECAO_VISUAL_0_1_6.md](DIRECAO_VISUAL_0_1_6.md). Referências de organização consultadas: [Transmit](https://panic.com/transmit/) e [Things](https://culturedcode.com/things/). Não foram copiados seus layouts, identidades ou componentes.

## Verificação

- `dart format --output=none --set-exit-if-changed lib test`: 67 arquivos, sem alterações pendentes.
- `flutter analyze --no-pub`: sem problemas.
- `flutter test --no-pub`: 67 testes aprovados. Layouts 1920×1080, 1360×820, 900×820, 900×600, 390×820 e 320×820; texto 1,3× no último. Testes conferem preenchimento da janela, oito ícones na mesma linha e acesso ao último comando por rolagem horizontal. A suíte de captura também cobre janelas baixas.
- Capturas de widgets revisadas visualmente em desktop/mobile, com banco e metadados isolados. Elas não representam downloads reais novos. Amostras em `docs/images/design-016-*`.
- App nativo aberto pelo inicializador: Início com os dez registros e dez concluídos preservados. A conferência adicional pela automação de interface foi interrompida pelo usuário com Esc. Não houve novo teste de download de provedores nesta revisão visual.
- `flutter build windows --release --no-pub`: executável `0.1.6+7` gerado. Inno Setup compilou o instalador `0.1.6` de 75577706 bytes; o fim do log foi conferido posteriormente. Pacote final em `%LOCALAPPDATA%/DefinitiveDownloaderDev/release-016-final`. Instalação limpa não ensaiada; instalador sem assinatura digital.
- Motor musical preservado em relação à 0.1.5: SHA-256 `EFD3B3C8B74030F4A1336120EEC80995CBF7511E49B01B692A1AB6A8D86F19C7`. Sem dependências novas; `pubspec.lock` preservado.

Logs e evidências de conta permanecem locais em `docs/evidencias/` e não são publicados com o código. A publicação inclui somente fontes, documentação e capturas isoladas selecionadas; os binários ficam nos assets da release, fora do Git.

## Distribuição e histórico

Página da versão: [v0.1.6 no GitHub](https://github.com/GustavoDevGTI/D.d---Definitive-Downloader/releases/tag/v0.1.6). Distribuição de teste para Windows x64, com instalador, ZIP portátil completo e `SHA256SUMS.txt`.

O repositório já possuía v0.1.0 e v0.1.1. Esta versão registra também os avanços locais acumulados nas revisões 0.1.2–0.1.5, incluindo filas por categoria, fonte manual por ocorrência, histórico de arquivos, prioridade e controles de transferência. Não foram criadas tags retrospectivas usando o código atual.

Esta revisão não muda schema, autenticação, matching, fontes manuais ou motor de transferência. Não há limpeza de coleções, histórico ou arquivos. O motor Python Windows continua distinto de uma implementação mobile; sem novo ensaio de provedores, APK/IPA ou obtenção nativa no celular nesta versão.
