# 0.1.64+65 — piloto TuneMyMusic no Windows

Em **Músicas → Coleções**, use **Importar por link** com uma playlist Spotify. Depois da conexão Deezer, o D.d abre o TuneMyMusic em uma janela interna. O piloto tenta avançar até a tela Spotify e preencher o campo com o link. Se a interface mudar, o botão **Copiar link** permite preencher o campo manualmente.

Use os controles do TuneMyMusic para carregar a playlist, autorizar o Spotify quando o site pedir e exportar em CSV. A janela recebe o CSV de origem reconhecida, verifica se o arquivo chegou com o tamanho informado e entrega a playlist à Conferência. Se o navegador interno não receber o arquivo, feche a janela e use **Abrir no navegador** e **Usar CSV exportado**.

O piloto usa os controles visíveis da [exportação pública do TuneMyMusic](https://www.tunemymusic.com/transfer/spotify-to-file). A confirmação e a exportação ainda dependem das ações no site. O Android segue com o fluxo externo da 0.1.63.

No [sandbox do MusicAPI](https://musicapi.com/docs/reference/get-public-playlist-items), uma consulta à playlist pública Today’s Top Hits retornou 50 faixas com nomes, artistas e duração sem conectar uma conta Spotify. O D.d ainda não usa o MusicAPI. A [leitura autenticada](https://musicapi.com/docs/get-started/quickstart-core) precisa de teste com playlist privada e credencial guardada em servidor. A [modalidade gerenciada em produção](https://musicapi.com/docs/get-started/sandbox-and-going-live) tem mínimo documentado de €500 por mês.

A compilação Windows, a análise estática e 38 testes essenciais e focados passaram. Um ensaio sintético confirmou que o importador aguarda o tamanho completo do CSV e que o cancelamento encerra a espera. A versão 0.1.64+65 foi instalada e abriu em **Músicas → Coleções**. A sessão Deezer estava desconectada durante a conferência da interface. O preenchimento na janela interna e a entrega do CSV pelo TuneMyMusic aguardam validação de ponta a ponta com contas reais.

SHA-256 do instalador Windows `f80c81ff12fc6fd0ce109f2886ed94e0ec15c6b22c4882c795e273d783f68233`.
