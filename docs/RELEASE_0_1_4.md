# Definitive Downloader 0.1.4

Revisão visual de 28/10/2026 guiada pelos oito prints enviados pelo usuário. Os números, nomes de arquivos e capacidades ilustrativas dos prints não são dados de produção. A moldura do navegador, o seletor Desktop/Mobile do protótipo e as legendas de simulação não fazem parte da interface nativa.

Direção: manter Manrope e o tema claro, com branco #FFFFFF, fundo #F5F7F9, texto #202A34, secundário #65717D e linhas #E1E6EB. Reduzir o menu para 184 px, usar D.d no espaço compacto, conteúdo com largura limitada e títulos de 20 px. Abas e campos têm cantos mais arredondados conforme os prints; painéis e listas mantêm contornos discretos e nenhum efeito decorativo.

Organização: dois atalhos no Início, visão geral em três indicadores reais e acesso às filas; Coleções em lista vertical antes da tela de faixas; captura com formulário e estado vazio em painéis separados; downloads com ferramentas compactas, filtros, contagem e atalho para nova captura; Arquivos por pastas reais; Configurações em linhas que abrem os detalhes existentes. Adaptar disposição e toque no mobile sem copiar a moldura desktop.

Nesta revisão não há limpeza automática de dados, mudança de schema ou implementação de motores pendentes. Autenticação, importação, matching e download existentes foram reaproveitados. A biblioteca continuou com 0 coleções e 0 registros de histórico, como estava após a limpeza anteriormente autorizada; nenhuma nova limpeza foi realizada.

## Comportamento e limites

- Os indicadores Registros/Baixando/Concluídos usam consultas agregadas reais. Registros corresponde às ocorrências visíveis com fonte ou vínculo manual; concluídos corresponde ao histórico visível. O valor pode diferir entre indicadores quando uma faixa recebe um novo vínculo ou possui arquivo já registrado.
- Coleções abre uma lista vertical paginada. Selecionar uma coleção abre a tabela e conferência; Voltar às coleções preserva as faixas e a seleção. Importar por link continua restrito ao Spotify, com CSV disponível. O botão + Nova direciona o foco para a importação, sem criar coleções fictícias.
- As filas musicais e de mídias compartilham componentes e continuam separadas. A tabela usa seleção múltipla circular e rolagem horizontal também em mobile, conforme os prints. Texto ampliado e janelas baixas podem exigir rolagem vertical. Capturar novo link abre a aba de captura da mesma categoria.
- Arquivos mostra somente pastas e registros reais do histórico, com navegação por subpastas, busca e Pasta principal. Arquivo movido/excluído permanece registrado e indicado como indisponível.
- As linhas de Configurações abrem o detalhe da opção. Pasta e conexões reutilizam as funções existentes. Qualidade, conversão, concorrência, notificações e captura pendentes não recebem controles de execução fictícios.
- Captura geral e download de vídeos/fotos, extração de páginas, pausa, prioridade, métricas de rede e formatos adicionais continuam indisponíveis. A restrição YouTube Music ATV permanece no fluxo musical.

## Verificação

- `dart format --output=none --set-exit-if-changed lib test`: 67 arquivos, nenhuma alteração pendente.
- `flutter analyze --no-pub`: sem problemas.
- `flutter test --no-pub --reporter expanded`: **59 testes aprovados** na revisão final.
- Layout: 1360×820, 900×820, 900×600, 390×820 e 320×820, com texto 1,3× no último. Captura também verificada em 320×400, 900×360 e 1360×600. Testados navegação, conexões em fixtures, seleção/foco, fonte manual, acesso da fila à captura e abertura dos detalhes de configuração.
- Capturas revisadas visualmente em `docs/images/reference-014-*`. Os metadados, referências de arquivos e contagens nessas capturas são fixtures isoladas, não downloads reais. Nenhuma conta real foi usada para testar a revisão.
- `flutter build windows --release --no-pub`: executável Windows **0.1.4+5** gerado.
- Inno Setup: instalador **0.1.4** compilado. Manifesto de arquivos conferido com o pacote; instalação limpa não ensaiada e instalador sem assinatura digital.
- App reaberto por `INICIAR.cmd`, com hash do executável e `data/app.so` iguais ao pacote da release. Início e Configurações conferidos na janela nativa.
- `pubspec.lock` preservado; sem dependências novas. Worker musical preservado, SHA-256 `55D5FE1DF258BD241A91A2F7253821B8A48218720ACFA39AB6EEE4DBEF69D62D`.

Logs em `docs/evidencias/reference-014-*.log`. Artefatos em `%LOCALAPPDATA%\DefinitiveDownloaderDev\release-014`, preservando as versões anteriores. Não houve publicação remota; tag `v0.1.4` continua pendente do vínculo com o repositório correto. Layout mobile validado em widgets, sem build APK/IPA ou validação de obtenção nativa no celular.
