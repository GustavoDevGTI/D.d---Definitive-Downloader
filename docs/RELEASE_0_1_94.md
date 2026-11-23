# Definitive Downloader 0.1.94

Consolida as entregas locais 0.1.89 a 0.1.94, com captura de áudio por URL e uma escala visual consistente para o desktop.

## Interface e playlists

- Botões de ação de 40 px, ícones de 20 px e medidas compartilhadas no tema.
- Coleções com linhas de 52 px e capas de 32 px; busca e comandos na mesma linha quando há espaço.
- Downloads com cabeçalho de 32 px, linhas de 40 px e maior aproveitamento da janela.
- Mais espaço no topo das páginas e entre a marca e os atalhos do Início. Abas alinhadas à seta de voltar.
- Ações de importação reunidas em Outras opções; Nova playlist junto da busca e Gerenciar em cada playlist.
- Configurações, Arquivos, Conferência, diálogos e player ajustados à mesma escala. As cores das playlists foram preservadas.
- Barras de comandos adaptadas à largura e ao texto ampliado, com espaço reservado para digitar na busca. Textos de seleção e opções de importação permanecem dentro das margens em telas estreitas.

## Capturar áudio

Em Músicas → Capturar áudio, informe uma URL, analise a página, selecione os itens e escolha Baixar MP3. Somente os itens selecionados entram na fila. A análise não inicia downloads.

- Extração do áudio de mídias reconhecidas pelo motor, incluindo vídeos compatíveis.
- Referência de origem e metadados disponíveis preservados; escolha da fonte mantida na fila.
- Limites de 50 itens por análise, 500 MB por mídia e duração máxima de 24 horas.
- A disponibilidade depende da página. Conteúdo protegido e transmissões ao vivo são recusados.

## Pacotes e verificação

Instalador Windows x64 e APKs Android ARM64/x86_64 com assinatura de teste. As somas dos três pacotes estão em SHA256SUMS.txt.

O Android foi compilado sem execução de testes no emulador, conforme solicitado. A validação desta consolidação se concentra no Windows; a compilação dos APKs não comprova o funcionamento de todas as operações em um celular.

Análise estática sem problemas. A regressão terminou com 280 testes Dart aprovados e 3 ignorados. No motor offline, 26 testes passaram e 1 foi ignorado, incluindo captura por página HTTP local e extração de áudio de vídeo. Os casos de telas estreitas e texto ampliado foram reproduzidos e corrigidos antes da consolidação.
