# Definitive Downloader 0.1.88

## Windows e Android

- Conexão Deezer com entrada por e-mail e senha na página oficial, captura automática da sessão e validação antes de salvar no cofre do dispositivo.
- Opção de definir a senha Deezer pelo e-mail da conta, inclusive para contas criadas com Google.
- Ajuste do espaço do botão de conferência da playlist em telas estreitas.

## Importação de pastas no Android

- Botão **Importar pasta** em **Músicas → Coleções → Minhas coleções**.
- Criação de uma playlist com o nome da pasta escolhida pelo seletor do Android.
- Inclusão dos áudios das subpastas, em ordem alfabética por caminho.
- Cópias próprias da playlist com preservação dos arquivos originais e dos formatos compatíveis.
- Validação do formato pelo sistema e leitura dos metadados disponíveis.
- Limites de 200 MB por áudio, 1 GB por pasta e 10.000 faixas.

## Pacotes

- Instalador Windows x64.
- APK Android ARM64 para celulares.
- APK Android x86_64 para emuladores e dispositivos compatíveis.
- Arquivo SHA256SUMS.txt com as somas dos três pacotes.

## Verificações e pendências

A importação pelo seletor real do APK Android instalado criou uma playlist com dois WAVs, incluindo uma subpasta, ignorou o arquivo TXT e conservou os hashes dos originais. A instalação e a abertura da versão foram verificadas no emulador. Os quatro testes de interface da composição de coleções passaram.

O executor do APK isolado teve timeout na abertura do processo. O login Deezer com conta real continua aguardando o teste prático.

Na preparação da publicação, a análise estática completa passou. A regressão Dart terminou com 272 testes aprovados e 3 ignorados. O motor offline executou 20 testes, com 1 ignorado. O instalador Windows 0.1.88 foi compilado e instalado, com cópia privada verificada da biblioteca anterior. Os três pacotes têm SHA-256 registrados.
