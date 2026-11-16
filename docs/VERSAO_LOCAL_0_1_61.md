# 0.1.61+62 — importar playlists de um arquivo do Spotify

1. Entre no Spotify em [Privacidade da conta](https://www.spotify.com/br-pt/account/privacy/) e solicite **Baixe seus dados → Dados da conta**. O Spotify prepara a exportação.
2. Quando o pacote chegar, extraia os arquivos e localize `Playlist1.json` ou outro `Playlist*.json`. [O Spotify descreve o conteúdo dos dados da conta](https://support.spotify.com/br-pt/article/understanding-your-data/).
3. No D.d, entre em **Músicas → Coleções**, use o ícone de importar arquivo ao lado de **Conexões** e selecione o JSON. Se houver várias playlists com músicas, escolha a que deseja importar. O mesmo seletor continua aceitando CSV.

O arquivo é lido no dispositivo. O importador guarda o nome, artistas, álbuns e referências de faixa que estiverem presentes, mantendo a ordem e as repetições. Episódios e arquivos locais sem áudio no pacote ficam fora da importação. O limite é de 5 MiB por JSON e 10.000 faixas por playlist. O aplicativo não envia o arquivo e não pede conexão de Spotify ou Deezer ao importar ou abrir essa coleção. Conferir fontes e baixar mídia continuam sendo operações separadas. O formato não oferece sincronização com a playlist original.

O login feito no site do Spotify dá acesso à página ao titular. Ler a conta diretamente pelo D.d é uma integração distinta. A importação local não usa o OAuth, o painel de desenvolvedor, cookies externos ou leitura automatizada do Web Player. A importação por link autenticada anterior permanece separada. Sem mudança no schema 17.

A análise estática e os 44 testes da rodada essencial e focada passaram. O teste com JSON sintético confirmou cancelamento sem criar coleção, escolha de uma playlist, preservação de repetições e reabertura sem chamadas de login ou do motor musical. Nenhuma conta real foi usada nessa validação.

No emulador `Definitive_API_36`, o APK x86-64 atualizado abriu o seletor de documentos do Android, mostrou duas playlists do arquivo sintético e importou a selecionada com duas ocorrências e zero downloads, sem pedir conta. A versão Windows foi instalada e reaberta; o registro e o executável confirmam 0.1.61. A versão ARM64 foi empacotada e inspecionada, sem ensaio em celular físico.

| Pacote local | SHA-256 |
| --- | --- |
| `Definitive-Downloader-0.1.61-Setup-Windows-x64.exe` | `1fd519d6d92bbafe9fc7e9df8dc7b99a08502425e034c620945dd83d72767553` |
| `Definitive-Downloader-0.1.61-Android-arm64-v8a-teste.apk` | `deeb0b324dcd9b706c08cb3f83600ce1de1a5937b77c19b45d0f8ae94dab3743` |
| `Definitive-Downloader-0.1.61-Android-x86_64-teste.apk` | `2b0f92952f15a90351d3b5e9761e07aa60f8c31f6858f74e08a826eba2a35fdd` |

Entrega local, sem tag ou release no GitHub.
