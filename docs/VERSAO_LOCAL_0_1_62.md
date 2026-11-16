# 0.1.62+63 — transcrição de playlists

Em **Músicas → Coleções**, abra **Transcrever playlist**, cole o link e leia a lista. A página mostra o total e as primeiras faixas. **Enviar para Coleções** guarda todas as ocorrências na ordem da origem. Em Coleções, a pessoa pode conferir as fontes, escolher as faixas para download e tocar os arquivos disponíveis.

A página HTML vem no pacote do D.d. Usa os leitores existentes de Deezer, YouTube, YouTube Music, SoundCloud e Spotify. O aplicativo valida o link, termina a leitura antes de mostrar a prévia e só grava depois da confirmação. Fechar a página cancela a leitura sem criar coleção. Nomes e artistas são exibidos como texto. A janela fica restrita à página local e o login Spotify abre pelo fluxo oficial existente.

O Spotify ainda exige uma conta autorizada no piloto e uma playlist que essa autorização permita ler. Abrir a página do D.d não concede acesso adicional. Na sondagem sem login, o HTML público e o player incorporado devolveram 30 e 50 referências distintas, respectivamente, para o mesmo link. O recurso não usa esses resultados como cópia completa. Sem migração de banco ou release no GitHub.

A análise estática e a sintaxe do JavaScript passaram. A rodada essencial e focada teve 50 casos aprovados, incluindo o caso de layout a 390 px em uma reexecução isolada após um timeout. A sondagem de três provedores ficou fora dessa rodada. A simulação de uma conta Spotify validou leitura completa, ordem e repetição, nenhuma gravação antes da confirmação, nenhuma chamada ao motor de mídia e recusa quando a origem muda durante a leitura.

No emulador `Definitive_API_36`, o APK x86-64 abriu a página, leu a playlist pública Deezer **En mode 60** e, após a confirmação, Coleções registrou **50 faixas · 0 baixadas**. Nenhuma conta foi conectada nesse ensaio. A versão Windows foi instalada e o executável confirmou 0.1.62+63. A janela web foi exercitada no emulador, não no Windows ou em um aparelho ARM64 físico.

| Pacote local | SHA-256 |
| --- | --- |
| `Definitive-Downloader-0.1.62-Setup-Windows-x64.exe` | `b59e9355a5088f149cc27cb060810683a469dde764d3a639e78ca882883a527e` |
| `Definitive-Downloader-0.1.62-Android-arm64-v8a-teste.apk` | `b5e4ab179657a944fbede73d76e71e433c70d1749db72c8aa05c32b5011f10fd` |
| `Definitive-Downloader-0.1.62-Android-x86_64-teste.apk` | `9337cb3cfcc06253f59dbbe670a81cae83a9b2ff15b17192d385ac4e5c2b85be` |
