# 0.1.60+61 — APK Android menor

O piloto Android usa Dart compilado antecipadamente e gera um APK por arquitetura. **ARM64** é o pacote para celulares ARM de 64 bits. **x86-64** é o pacote do emulador atual. Os dois usam o identificador e a assinatura de teste da versão anterior, com código 61. A variante de integração continua em modo debug com o identificador separado.

O Android continua usando MediaPlayer. A biblioteca libmpv fica na dependência Windows, na mesma versão anterior. Os pacotes de FFmpeg, CPython e QuickJS continuam disponíveis localmente em cada APK.

| Pacote | Bytes | Redução em relação ao APK 0.1.59 |
| --- | ---: | ---: |
| 0.1.59 universal de teste | 232.248.214 | |
| 0.1.60 ARM64 | 68.688.385 | 70,4% |
| 0.1.60 x86-64 | 71.927.883 | 69,0% |

O build confere o manifesto, a assinatura e a presença das bibliotecas necessárias para cada arquitetura. Cada APK tem limite de 80 MiB. O arquivo ARM64 ainda contém 35,4 MB de FFmpeg e 14,1 MB de CPython.

A análise estática e 44 testes essenciais e de Android passaram. O APK x86-64 atualizou a instalação 0.1.59 com `install -r` no emulador dedicado. A tela Conexões habilitou a ação Deezer após a verificação local do motor, que executa o codec MP3 e o vetor de criptografia. O APK ARM64 passou na inspeção do manifesto, das bibliotecas e da assinatura. A execução em um celular ARM64 fica para a validação em dispositivo físico.

## Artefatos locais

| Pacote | SHA-256 |
| --- | --- |
| `Definitive-Downloader-0.1.60-Android-arm64-v8a-teste.apk` | `ff8e28fc9ec12e9e10486c9230e8f42a0890cf4b8635ba2db02f7cefaf6a8dc3` |
| `Definitive-Downloader-0.1.60-Android-x86_64-teste.apk` | `5dee698e3065a850de4379d3117678697916c978938ba6202dccedfbfba3bf7d` |
