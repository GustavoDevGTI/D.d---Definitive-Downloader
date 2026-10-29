# Ensaios isolados de áudio

Estes arquivos são ferramentas de investigação; não são importados por `lib/`, não alteram a biblioteca e não acrescentam um motor de download ao executável do D.d.

- `run_authenticated.dart`: reaproveita o listener PKCE validado, faz uma nova autorização e passa o token aos filhos por pipe anônimo. Não consulta o cofre, não persiste tokens e não passa segredos por argumentos.
- `librespot_probe.rs`: exemplo compilado dentro do checkout fixado de librespot. Testa sessão, client-token, login5, metadados e saída PCM pelo backend `pipe`. Os logs registram estados e posições no código; mensagens dinâmicas do provedor são descartadas.
- `python_session_probe.py`: exercita os motores librespot-python usados pelo Zotify original e pelo fork OAuth. Sessão e cache de credenciais desativados. A instrumentação de login5 registra somente status HTTP, tamanho, nomes de campos e enum de erro.
- `spotdl_isolated.py`: direciona a configuração do spotDL para uma pasta dedicada e vazia. Não carrega o perfil, os cookies ou a sessão existentes do usuário.
- `verify_outputs.py`: compara posições e durações com a coleção local por consulta SQLite somente leitura, verifica tags/capas e decodifica cada MP3 integralmente por FFmpeg. Uma duração fora do limite gera revisão, sem alteração do áudio.

O manifesto local `.tools/spotify-validation/sources.json` fixa as revisões consultadas. Configuração do runner: arquivo local de até 32 KiB contendo `output`, `trackId` e `engines` (nome, comando local, argumentos e extensão). Há retorno e Client ID opcionais para comparar o cadastro próprio com o modo nativo do upstream. Esses identificadores de pesquisa não devem ser transplantados para a identidade do produto.

O runner aplica timeout de sete minutos por motor; o probe Rust limita cada etapa de conexão e a duração da faixa. Sucesso de processo não significa sucesso de áudio: conferir os eventos, tamanho e decodificação do arquivo. Uma saída interrompida não é um download completo.

Em 28/10, após o usuário informar que a página não apareceu, o disparo sem acompanhamento por `rundll32` foi substituído por abertura padrão do Windows via `Start-Process`, com URL passada por variável exclusiva do filho e código de saída conferido. Saída zero não comprova página visível. O runner também emite `AUTHORIZATION_URL` para abertura manual; esse endereço contém somente parâmetros públicos de PKCE, nunca código, token ou verifier. Não persistir essa linha em logs de evidência. Não reutilizar o link após a tentativa expirar.

Para executar, usar `dart run tools/spotify_probe/run_authenticated.dart <config-local>` no workspace local com as dependências resolvidas. O usuário conclui pessoalmente eventuais páginas de autenticação. Nunca colar senha, token ou código no terminal/chat.

Nesta máquina, ferramentas Python empacotadas podem redirecionar instalações em AppData para o cache local do pacote Windows. Registrar o caminho efetivo informado pela ferramenta; não procurar credenciais em perfis alternativos.

Resultados e limites: `docs/TESTES_AUDIO_SPOTIFY.md`.
