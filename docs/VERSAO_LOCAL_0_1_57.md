# 0.1.57+58 — Spotify com Deezer opcional na importação

O diálogo de Deezer após o Spotify oferece **Fazer login depois**. A playlist pode ser importada com a conta Spotify, e a escolha de adiar vale até encerrar o app. **Cancelar** interrompe a operação pendente. As duas ações preservam a sessão Spotify.

O atalho Deezer continua disponível em Coleções, Conferência e Conexões. A conferência automática que depende de Deezer aguarda a conta. Links que exigem Deezer e comandos que precisam dessa fonte ainda solicitam login. O diálogo e as regras são compartilhados entre Windows e Android.

Em 09/11/2026, `flutter analyze` passou sem problemas. Os 57 testes essenciais e focados passaram, incluindo importação autenticada com respostas simuladas, adiamento sem segunda solicitação automática, cancelamento e o diálogo em 390 e 1360 px.

- Windows Release instalado como `0.1.57+58`. O instalador retornou 0 e o executável instalado corresponde ao pacote. A janela abriu, o atalho na Área de Trabalho aponta para o app instalado e a biblioteca conservou schema 16, 2 coleções e 200 faixas.
- Instalador `dist/Windows/Definitive-Downloader-0.1.57-Setup-Windows-x64.exe`. SHA-256 `63e45278dd9d35b067f61560f054a19f9578e22e35beb08e34aa02bdb8fb3824`.
- APK `dist/Android/Definitive-Downloader-0.1.57-Android-teste.apk`. SHA-256 `63f80532e9a5a9d79c3351e9759ee529d402ef00d05338aeb300affcf2b3049b`. APK debug assinado pelo esquema v2, ARM64 e x86-64. Atualização com `install -r` no AVD `Definitive_API_36`, pacote normal `br.com.definitivedownloader.app`, versionCode 58 e versionName 0.1.57.
- A primeira abertura após instalar atingiu o tempo limite de inicialização do Android. A segunda chegou à janela em primeiro plano e uma chamada subsequente confirmou a Activity já aberta e com foco.
- Entrega local sem release ou tag. A validação dessa mudança não usou contas reais.
