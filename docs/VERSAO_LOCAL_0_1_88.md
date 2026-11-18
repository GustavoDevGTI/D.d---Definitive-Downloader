# 0.1.88 — importação de pasta no Android

Em **Músicas → Coleções → Minhas coleções**, toque em **Importar pasta** e escolha uma pasta de áudio no seletor do Android. O D.d cria uma playlist com o nome da pasta e inclui os áudios das subpastas em ordem alfabética por caminho. As cópias da playlist conservam os formatos e metadados disponíveis.

A leitura usa apenas a pasta autorizada no seletor. As cópias temporárias são removidas depois da importação. A operação conserva os arquivos originais e usa os limites de 200 MB por áudio, 1 GB por pasta e 10.000 faixas.

O Android verifica o formato pelo tipo de mídia reconhecido pelo sistema e carrega título, artista e álbum das tags disponíveis. Os APKs de teste ARM64 e x86_64 foram compilados e seus SHA-256 foram verificados. O APK x86_64 foi instalado e aberto no emulador Definitive_API_36. A análise dos arquivos alterados e os quatro testes de interface da composição de coleções passaram.

O teste pelo seletor real no APK x86_64 criou uma playlist com dois WAVs, um na raiz e outro em subpasta, ignorou um TXT e exibiu as faixas nas posições 1 e 2 como baixadas. Os SHA-256 dos originais permaneceram iguais. A playlist e as cópias de ensaio foram removidas ao final. O executor Flutter do APK isolado teve timeout na abertura do processo.

Preparação da release em 18/11/2026 com análise estática completa aprovada, 272 testes Dart aprovados e 3 ignorados, além de 20 testes offline do motor, com 1 ignorado. Instalador Windows 0.1.88+89 compilado e instalado com cópia privada verificada da biblioteca anterior. Detalhes da publicação em RELEASE_0_1_88.md.
