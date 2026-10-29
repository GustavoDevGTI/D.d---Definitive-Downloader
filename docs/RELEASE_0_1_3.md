# Definitive Downloader 0.1.3

Revisão de 28/10/2026. Aplicativo `0.1.3+4`. Referência de organização: arquivo HTML `definitive_downloader_wireframe_v051.html` fornecido pelo usuário. O HTML é um protótipo com dados e ações simulados; foi usado como referência de layout, sem incorporar suas simulações ao produto.

## Interface

Mantidos Flutter/Dart, Manrope, superfícies brancas, fundo frio e acento discreto. A área principal tem limites e margens desktop, menu de 210 px, abas em botões e painéis com contorno simples. Não foram adicionados temas, dependências ou animações decorativas.

- Início: acessos rápidos em duas colunas quando houver largura, resumo consultado no banco e atividades recentes.
- Coleções: importação, seletor horizontal de coleções e painéis de faixas/conferência na mesma tela. Em telas pequenas, lista compacta e conferência em painel secundário; páginas baixas permitem rolagem sem comprimir os controles.
- Faixas: título/artista agrupados, origem real visível, duração e estado de correspondência. Seleção continua independente do foco. O comando de seleção considera toda a pesquisa, inclusive outras páginas.
- Captura: título e orientação acima do formulário; campo e ação alinhados na largura desktop, empilhados com espaçamento no mobile. Filtros de vídeo/imagem usam checkboxes separados, sem pílulas amontoadas. Resultados e ações ficam em um painel próprio.
- Downloads: título da categoria, barra compacta contornada e área da fila delimitada. Janelas baixas permitem rolagem. O menu também rola quando necessário.
- Avisos: mensagens de uma operação já concluída são limpas ao trocar de categoria; mensagens de operações ativas continuam disponíveis.

Corrigida também a superfície Material dos painéis para preservar foco, hover e resposta visual de controles internos. Captura geral, vídeo/fotos, extração de páginas, pausa, prioridade e demais capacidades pendentes continuam indisponíveis, sem resultados fictícios.

## Limpeza autorizada dos dados de teste

O usuário confirmou a remoção apenas dos dados de teste, preservando contas, configurações e arquivos baixados. Após conferir ausência de transferência ativa e fechar o aplicativo:

- Criado snapshot SQLite consistente e validado com `quick_check` antes da limpeza, em `%LOCALAPPDATA%\DefinitiveDownloaderDev\backups\before-reset-tests-20261028-215952.sqlite3`.
- Removidas as coleções de teste `Entre linhas` e `Teste`: 2 coleções, 16 ocorrências e 16 entradas de histórico. Registros dependentes seguem as relações do banco.
- Estado final da biblioteca: 0 coleções, 0 faixas, 0 entradas de histórico; `quick_check` aprovado.
- Preferências comparadas antes/depois e preservadas. Cofre de contas não foi inspecionado ou alterado. Nenhum arquivo baixado foi excluído, movido ou renomeado.

A limpeza foi uma manutenção local autorizada; não foi adicionada uma rotina automática que apaga coleções ao atualizar ou abrir o app. Os testes automatizados continuam no projeto e usam bancos temporários.

## Validação e entrega

Resultados finais:

- `dart format --output=none --set-exit-if-changed lib test`: 67 arquivos, nenhuma alteração pendente.
- `flutter analyze --no-pub`: sem problemas.
- `flutter test --no-pub --reporter expanded`: **59 testes aprovados**.
- `flutter build windows --release --no-pub`: compilado com sucesso; versão do binário **0.1.3+4**.
- Inno Setup: instalador **0.1.3** compilado com sucesso. Não foi realizado ensaio de instalação limpa; instalador sem assinatura digital.
- `pubspec.lock` conferido e preservado. Worker musical com SHA-256 inalterado: `55D5FE1DF258BD241A91A2F7253821B8A48218720ACFA39AB6EEE4DBEF69D62D`.
- Aplicativo reaberto pelo `INICIAR.cmd`, executando o pacote local. Início exibiu contadores 0/0/0 e ausência de atividades recentes. Tela nativa de Vídeos e Fotos conferida visualmente, com campo/ação alinhados e filtros separados do painel de resultados.

Resultados finais em `docs/evidencias/refino-013-*.log`. Os testes de layout cobrem 1360×820, 900×820, 900×600, 390×820 e 320×820 (texto 1,3× no último). A captura tem verificações adicionais de separação entre campo, botão e filtros, e de rolagem em 320×400, 900×360 e 1360×600.

Capturas revisadas em `docs/images/refino-013-*`. São fixtures visuais isoladas, sem acesso a contas ou downloads reais de provedores. A estrutura mobile segue sem validação de login ou download nativo Android/iOS.

Versão do aplicativo/instalador: 0.1.3. As versões anteriores foram preservadas. O worker musical permanece inalterado. Artefatos locais em `%LOCALAPPDATA%\DefinitiveDownloaderDev\release-013`; não houve publicação remota. Tag `v0.1.3` pendente de vínculo com o repositório Git correto.
