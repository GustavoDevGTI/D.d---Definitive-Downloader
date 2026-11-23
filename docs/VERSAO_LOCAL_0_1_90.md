# 0.1.90 — Capturar áudio

Em **Músicas → Capturar áudio**, cole o endereço de uma página ou mídia e escolha **Analisar link**. A lista encontrada permite selecionar os itens e acionar **Baixar MP3**. Os itens escolhidos formam uma playlist com a referência de origem e entram na fila musical.

- Análise e seleção independentes do download.
- Cancelamento da análise e descarte de respostas tardias.
- Áudio de páginas compatíveis e extração da faixa sonora de vídeos reconhecidos pelo motor.
- Conversão para MP3 com título, artista disponível e referência de origem nas tags.
- Uso da fila existente, com progresso, pausa, interrupção, histórico, publicação de arquivos e reprodução local.
- Preservação da escolha manual da fonte, sem troca automática por outra gravação.
- Limites de 50 itens por análise, resposta limitada por tamanho, 500 MB por mídia e duração máxima de 24 horas. A interface avisa quando há mais itens.
- Conteúdo protegido, transmissões em andamento e páginas que exigem acesso indisponível podem ser recusados. A extração depende da compatibilidade da página com o motor.

Os testes essenciais e focados Dart passaram em 52 casos. A rodada do motor executou 27 testes: 26 passaram e 1 foi ignorado. A seleção e o download foram exercitados em testes de interface de 320 e 1360 px. Uma página HTTP local com dois WAVs e um vídeo MP4 validou a seleção e a conversão do áudio do vídeo. Uma amostra pública por HTTPS teve download e decodificação completa, inclusive pelo executável Windows empacotado.

No emulador Android, um teste nativo isolado analisou uma página HTTP local com dois áudios, selecionou somente o segundo, concluiu a transferência pela fila compartilhada e validou o MP3 pelo leitor nativo. Esse ensaio não usa contas de plataformas. A ponte Android passou a aceitar a operação de análise. O emulador foi encerrado após a validação.

O Windows 0.1.90+91 foi compilado, instalado e aberto. Uma cópia privada do SQLite foi criada antes da instalação; a integridade e a preservação dos IDs anteriores de coleções, faixas e histórico foram verificadas depois. APKs de teste arm64-v8a e x86_64 foram compilados. Instalador, APKs e arquivos SHA-256 foram copiados para a pasta dist do projeto compartilhado e as cópias tiveram seus hashes conferidos. Sem publicação de release nesta entrega local.

O levantamento visual solicitado está em LEVANTAMENTO_VISUAL_BOTOES_E_DENSIDADE.md, com propostas para botões, contornos e densidade de Downloads. As propostas visuais pertencem à próxima etapa de refinamento.

Entrega local 0.1.90+91.
