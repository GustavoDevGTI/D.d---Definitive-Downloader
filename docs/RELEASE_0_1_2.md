# Definitive Downloader 0.1.2

Preparação local de 28/10/2026. Aplicativo `0.1.2+3`; especificação de interface Wireframe v0.5.1. Release anterior preservada. Sem publicação remota ou tag Git: o workspace atual não contém um repositório Git.

## Alterações

- Navegação Início, Músicas, Vídeos e Fotos, Arquivos e Configurações, com abas e navegação inferior em telas pequenas.
- Coleções e tabela/lista de faixas reorganizadas, com pesquisa, paginação, seleção múltipla e conferência independente da seleção para download.
- Fonte manual persistida por ocorrência; busca e fallback não a substituem. Correspondência e download têm estados separados.
- Downloads por categoria reutilizam componentes e serviços, com controles compactos e operações limitadas às capacidades reais.
- Histórico relacional por pastas e subpastas, preservando referências a arquivos movidos/excluídos e sem mover os arquivos existentes.
- Configurações centralizadas e resumo de atividades consultado nos dados existentes.

Schema SQLite v6 com migração transacional dos registros existentes. Spotify PKCE, cofre, importadores, matching, download musical, capa e M3U8 foram reaproveitados. Sem dependências novas; `pubspec.lock` preservado. O motor musical permanece idêntico ao pacote anterior.

## Limites

Captura geral de áudio/páginas e vídeos/fotos, importação de álbuns, reprodução de prévias, pausa, prioridade, métricas de rede e configurações ainda sem suporte permanecem indisponíveis. Informar uma página/videoclipe salva somente um vínculo pendente; não habilita extração ou fallback para vídeo.

Mobile recebeu a estrutura responsiva e testes de widgets. Não foi gerado APK/IPA nem validado login, worker ou download nativo mobile. Os sete formatos adicionais seguem planejados. Não houve novo teste com contas reais ou alteração dos arquivos da coleção piloto.

## Validação

- `dart format lib test`: executado; verificação final de formatação sem alterações pendentes.
- `flutter analyze --no-pub`: sem problemas.
- `flutter test --no-pub --reporter expanded`: **54 testes aprovados** na execução final, sem falhas; log em `evidencias/wireframe-tests.log`.
- Layout: quatro larguras, 1360/900/390/320 px; texto 1,3× em 320 px; quatro testes finais aprovados. Capturas revisadas visualmente.
- `flutter build windows --release --no-pub`: executável Windows compilado; versão do binário `0.1.2+3`.
- Instalador Inno Setup: **compilado com sucesso**, versão 0.1.2; instalador, pacote portátil, notas e `SHA256SUMS.txt` em `%LOCALAPPDATA%\DefinitiveDownloaderDev\release-012`. Instalação limpa não ensaiada nesta revisão.

Detalhes dos componentes, migração e limitações em [REESTRUTURACAO_WIREFRAME_0_5_1.md](REESTRUTURACAO_WIREFRAME_0_5_1.md).
