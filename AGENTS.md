# Orientações para contribuição

- Produto: Definitive Downloader (D.d), Flutter/Dart, desktop e mobile; o piloto atual é Windows.
- Evoluir uma funcionalidade por vez, preservando ordem e ocorrências repetidas.
- Separar domínio, interface, persistência e infraestrutura; não armazenar playlists inteiras em JSON.
- Nunca registrar credenciais em fontes, banco, logs ou evidências. Usar cofre do sistema.
- Identificar a fonte efetiva do áudio e bloquear videoclipes no fluxo musical.
- Versões incrementais para correções e pequenas melhorias: 0.1.1, 0.1.2 etc. Atualizar pubspec.yaml, tag, instalador e notas da release em conjunto; nunca sobrescrever uma release publicada.
- Executar dart format, flutter analyze, flutter test e compilar o Windows para distribuição. Preservar dados de usuário durante atualização e desinstalação.
