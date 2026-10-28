# Definitive Downloader (D.d)

Piloto Windows em Flutter/Dart para importar playlists Spotify, encontrar faixas na Deezer e no YouTube Music e salvar MP3s com capa e playlist M3U8. A origem efetiva aparece na interface e no nome do arquivo. Videoclipes são excluídos pelo filtro de faixas do catálogo YouTube Music.

## Usar no Windows

Baixe o pacote ZIP da release, extraia todos os arquivos e execute `INICIAR.cmd`. O programa copia o pacote para a pasta local do usuário e mantém a biblioteca e as sessões separadas. Spotify usa autenticação oficial PKCE; o acesso do aplicativo Spotify em modo de desenvolvimento pode limitar o uso a usuários autorizados e às regras vigentes do provedor. A conexão Deezer exige uma sessão própria inserida localmente; nunca envie senhas ou sessões a terceiros. A busca YouTube Music não exige login nesta versão.

Esta é uma versão inicial testada no Windows; Android, iOS e transferência remota de playlists ainda não estão disponíveis. As integrações dependem de serviços externos e podem mudar ou variar por região e conta.

## Construir

Use Flutter, Visual Studio Build Tools com C++ e o SDK Windows. Execute `tools/build_windows.ps1` em uma cópia local do projeto. Para o motor, instale as dependências de `runtime/music_worker/requirements.txt` num ambiente Python isolado, incluindo PyInstaller 6.16.0, e execute `tools/build_music_engine.ps1 -Python <python-do-ambiente> -WorkspaceRoot <projeto>`. O motor e o FFmpeg ficam na pasta `music_engine` ao lado do executável.

Validação: `dart format`, `flutter analyze`, `flutter test` e testes do worker Python. O banco usa SQLite relacional; ocorrências repetidas e ordem são preservadas. Não guarde credenciais no repositório.

## Componentes de terceiros

As dependências mantêm suas próprias licenças. O pacote Windows inclui FFmpeg 7.1 essentials da Gyan, GPL-3.0-or-later, e o respectivo texto de licença. Fonte e build: https://github.com/GyanD/codexffmpeg/releases/tag/7.1 ; commit FFmpeg indicado pelo fornecedor: https://github.com/FFmpeg/FFmpeg/commit/b08d7969c5 . Fonte Manrope: `assets/fonts/OFL.txt`.
