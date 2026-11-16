# 0.1.66 — importação pública com Trackhop no servidor

Com a URL do serviço incluída na compilação, **Músicas → Coleções → Importar por link** lê playlists públicas do Spotify no Windows e no Android. O D.d envia o identificador da playlist, descartando parâmetros de compartilhamento. Uma leitura completa abre a Conferência, preserva a ordem e as repetições e deixa o download sob comando da pessoa. A busca automática roda com as fontes disponíveis. A conexão Deezer continua disponível para usar essa fonte.

Para playlists privadas, a Conexão Trackhop pessoal e o CSV continuam disponíveis. Sem a URL do serviço na compilação, o app oferece o fluxo local da 0.1.65.

## Implantação

O serviço é uma aplicação Node sem dependências externas. A composição em `services/playlist-gateway` roda o Trackhop, o leitor do D.d e o HTTPS. Use um host Docker com um domínio apontado para ele e portas 80/443 acessíveis.

1. Em `services/playlist-gateway`, crie um `.env` local com `DD_TRACKHOP_ADMIN_PASSWORD` e execute `docker compose up -d trackhop`. A administração do Trackhop fica em `127.0.0.1:8080` no servidor. Para administrar remotamente, encaminhe essa porta por SSH.
2. Conecte **Spotify (web)** no Trackhop com uma conta gratuita administrada para este serviço. Em **Ferramentas → API**, gere um token. Adicione `DD_TRACKHOP_TOKEN` e `DD_PLAYLIST_DOMAIN` (somente o domínio) ao `.env`. A sessão e o token ficam no servidor. [Guia do Trackhop](https://trackhop.org/guide/docker#spotify-and-deezer-without-a-key-unofficial)
3. Execute `docker compose up -d`. Confira `GET /health` via HTTPS e `GET /v1/spotify/playlists/<id>` com uma playlist pública longa conhecida. Compare o total e a ordem. Confira também que uma playlist privada recebe 404.
4. Defina `DD_PLAYLIST_GATEWAY=https://<domínio>` no ambiente de compilação do Windows e do Android. O mesmo endereço pode ser passado a `tools/build_windows.ps1` e `tools/build_android.ps1` com `-PlaylistGateway`.

O gateway verifica acesso anônimo e total na página pública antes de chamar a rota de faixas do Trackhop. Uma leitura ambígua, incompleta ou fora dos limites é recusada. A rota só aceita o ID Spotify, entrega metadados e limita o volume de consultas. A sessão de Spotify (web) é a do servidor e pode precisar de renovação.

## Verificação

`node --test services/playlist-gateway/server.test.mjs` executa o contrato do servidor com Trackhop simulado. Para verificar o acesso real à página pública com um Trackhop simulado de 500 faixas, rode o mesmo comando com `DD_GATEWAY_LIVE_PUBLIC=1`.

Os quatro testes do servidor passaram, incluindo a consulta real à página pública com o Trackhop simulado. Um ensaio HTTPS local, com certificado de teste restrito ao cliente de teste, ligou o leitor Dart ao serviço Node e confirmou 151 ocorrências, a ordem, as repetições e a recusa de uma playlist sem acesso público. A análise estática e 95 testes Flutter essenciais e focados passaram, com três ignorados.

O Windows 0.1.66+67 foi instalado e abriu, com atalho verificado. O APK 0.1.66+67 x86_64 foi instalado no emulador dedicado e mostrou a tela inicial. Os pacotes locais foram compilados sem a URL de produção. A publicação HTTPS e a leitura real pelo conector Spotify (web) do Trackhop ainda aguardam host e sessão do serviço. A composição Docker não foi iniciada neste ambiente.

| Pacote local | SHA-256 |
| --- | --- |
| Instalador Windows x64 | `99aa41467f4758df7aea4811ef44be35df95e44be135371030db2c213f9da906` |
| APK ARM64 | `654011dba8df88d1e8366841bdc436e29913108b1fe1ed89c95c6f673331e3a3` |
| APK x86_64 | `8801c32c04b896f212b4ab9dccdd98ecac4959ce378829d329268d770b1f1d68` |
