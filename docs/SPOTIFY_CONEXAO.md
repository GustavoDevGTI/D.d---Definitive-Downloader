# Conexão Spotify — piloto D.d

Atualização de 27/10/2026. O proprietário forneceu o Client ID público do aplicativo Spotify. Ele está configurado em `lib/features/connections/domain/spotify_auth.dart`; não foi solicitado Client Secret. O fluxo implementado é de leitura de playlists, sem download de áudio Spotify ou escrita em contas.

## Fluxo implementado

1. Abrir **Conexões → Conectar Spotify** no aplicativo.
2. O D.d prepara PKCE S256 com verificador e estado aleatórios por tentativa, abre o navegador de sistema e espera o retorno.
3. O usuário faz login e concede a autorização na página oficial. O app pede `playlist-read-private` e `playlist-read-collaborative`.
4. No Windows, o retorno precisa estar cadastrado exatamente como `http://127.0.0.1:43821/callback`.
5. O D.d valida estado, método, origem de loopback, Host e caminho; troca o código por sessão e verifica o perfil básico para identificar a conta conectada.
6. A sessão é guardada pelo `flutter_secure_storage`, sem tokens em SQLite, logs ou arquivos de configuração comuns. O app pode restaurar e renovar a sessão.

Desconectar remove a sessão deste dispositivo. Revogação da autorização do aplicativo é gerenciada na conta Spotify; não apresentar remoção local como revogação remota.

## Importação autenticada

Depois de conectar, o campo de link usa a Web API autenticada. A leitura pública anterior continua disponível quando não há conexão e mantém sua identificação de resultado parcial.

- Ler metadados e total esperado antes de iniciar.
- Consultar `/v1/playlists/{id}/items` em páginas de 50, com limite de 10.000 ocorrências e respostas limitadas a 1 MB.
- Persistir em lotes locais de 100, preservando ordem e entradas repetidas.
- Manter uma ocorrência identificada como indisponível/não musical quando o Spotify não fornece uma faixa utilizável; não apagar posições silenciosamente.
- Conferir total das páginas e revisão `snapshot_id`, quando disponibilizada. Se houver mudança ou interrupção, desfazer a importação incompleta, inclusive lotes já gravados.
- Não usar URLs `next` remotas para decidir o destino de requisições autenticadas. O host e o recurso são construídos pelo adapter do Spotify.

Playlist indicada pelo usuário para o teste: `https://open.spotify.com/playlist/4PYxm8yonIPl6XxizOPYb1`. O endereço foi normalizado, retirando parâmetros de compartilhamento. A leitura pela conta autorizada foi concluída: coleção Teste, 10 faixas, sem entradas indisponíveis.

## Validações executadas

- **38 testes aprovados**, incluindo vetor PKCE do RFC, validação do callback, estado falso seguido de retorno válido, cancelamento, timeout/liberação da porta, persistência simulada, renovação simultânea, cancelamento durante troca de código e desconexão durante renovação.
- Importação sintética paginada com repetições, preservação de entrada indisponível e rollback quando a revisão da playlist muda.
- Layouts de 1360 e 900 pixels, incluindo abertura do diálogo Conexões.
- Análise estática sem problemas. Os testes de sessão usam credenciais sintéticas e não comprovam autenticação real.

Logs: `evidencias/spotify-tests.log`, `evidencias/spotify-analyze.log`, `evidencias/spotify-build.log` e `evidencias/spotify-tls.log`. A compilação Windows foi concluída e o executável abriu com a biblioteca preservada e acesso à tela Conexões. O plugin do cofre exigiu acrescentar o componente oficial ATL ao Visual Studio Build Tools; instalação concluída com código 0.

Durante a importação, os lotes já gravados ficam marcados como parciais até a conclusão do stream e suas verificações. Uma falha de stream remove a cópia incompleta; se o processo for encerrado antes da limpeza, a coleção remanescente continua explicitamente parcial.

## Certificados e ambiente

O cliente Dart inicialmente falhava na conexão TLS com `accounts.spotify.com`, enquanto o Windows validava essa cadeia. O módulo `core/network/platform_trust.dart` lê somente os certificados públicos dos repositórios ROOT existentes do Windows, em modo somente leitura, e os adiciona ao contexto do cliente. Não lê chaves privadas, não altera os repositórios e não aceita certificados inválidos por callback.

A verificação sem credenciais passou: servidor de login respondeu HTTP 200 e endpoint de perfil respondeu HTTP 401, esperado sem token. Essa verificação demonstra conectividade segura; não valida as permissões do Client ID ou da conta.

## Desktop e mobile

PKCE, sessão, transporte, importação e conferência permanecem separados do retorno de sistema. O adapter concreto deste piloto é Windows. Nos outros sistemas, o app informa que o login ainda não foi configurado; não reutiliza automaticamente o loopback Windows como login mobile. Clientes e retornos mobile continuam exigindo a preparação descrita em `CONFIGURACAO_DAS_CONTAS_DE_TESTE.md`.

## Verificação com conta real

O usuário concluiu a autorização e a interface do executável confirmou **Spotify conectado**. No fluxo de produção, esse estado ocorre após troca do código PKCE, conferência dos escopos, leitura do perfil e gravação da sessão no cofre. Nenhum token ou dado de identificação da conta foi registrado nas evidências.

A importação autenticada foi confirmada na janela nativa e no banco: Teste, 10 ocorrências nas posições 1 a 10, sem lacunas, todas com ISRC e endereço de capa, coleção completa. A playlist não contém repetições; essa propriedade não foi exercitada com conta real. A verificação local não substitui uma segunda comparação independente com a ordem na plataforma.

Após encerrar e reabrir o D.d, a biblioteca permaneceu e a conexão Spotify foi restaurada automaticamente, sem novo consentimento. Renovação após expiração ainda não foi exercitada com a conta real. Nenhum áudio foi obtido. Google/YouTube segue aguardando seu cadastro OAuth. Resultado e limites em [evidencias/spotify-conta-real.md](evidencias/spotify-conta-real.md).
