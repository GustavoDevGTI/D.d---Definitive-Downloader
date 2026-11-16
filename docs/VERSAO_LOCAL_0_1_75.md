# 0.1.75 — conexão Deezer ao importar playlists

Ao importar um link do Spotify, o D.d lê a playlist e então oferece a conexão com o Deezer. Ao importar um link de playlist do Deezer, a oferta aparece antes da leitura. A opção **Deixar para depois** continua aquela importação e volta a aparecer no próximo link de Spotify ou Deezer enquanto a conta estiver desconectada.

O diálogo também vale para **Nova playlist** e **Adicionar links** quando recebem links de playlists. Uma conexão Deezer válida é reutilizada. **Cancelar** encerra a importação sem gravar mudanças na playlist. Faixas Deezer importadas com a conexão adiada aguardam uma sessão válida para o download.

Os testes essenciais e focados cobriram a ordem Spotify → Deezer, a repetição do convite, o cancelamento e o diálogo em diferentes larguras. Passaram 57 testes, com dois ensaios opcionais ignorados.

O Windows e o emulador Android x86-64 foram atualizados para a 0.1.75+76. Os APKs ARM64 e x86-64 passaram pela validação de versão, ABI e assinatura. A verificação do convite usou contas simuladas.
