# C2: obtenção de áudio Deezer sem cadastro de desenvolvedor

Revisão em 28/10/2026 do repositório `Jjunior-san/C2-VIDEODOWNLOADER`, commit `c1df70537baa0a3d2707adefd58fae781ed3a093`. Fontes e hashes preservados no manifesto de evidência. Nenhum código foi incorporado ao D.d.

## Resposta à hipótese

**Sim: há um caminho de download completo que não exige App ID, Client Secret ou cadastro próprio no portal de desenvolvedores.** Ele usa a sessão da conta Deezer, representada por ARL, e serviços internos do player. Continua utilizando APIs e autenticação; dispensa as credenciais de aplicativo da API pública.

O módulo de autenticação já existia na cópia examinada anteriormente: seu texto normalizado permanece igual. A análise original registrava esse caminho e seus problemas, mas as conclusões recentes sobre dependência de cadastro de API não o destacaram suficientemente. Não confundir cadastro OAuth para integração pública com esse cliente baseado em sessão.

| Acesso | Como aparece no C2 | O que comprova |
| --- | --- | --- |
| Catálogo público | Consultas a `api.deezer.com`, inclusive por ISRC | Identificação de músicas e links de prévias; não entrega automaticamente uma faixa completa |
| Sessão de usuário | ARL fornecido à aplicação e conferência da conta | Pode habilitar o caminho autenticado; não exige cadastro de desenvolvedor |
| Obtenção completa | Cliente dos serviços internos de mídia | Existe implementação que tenta obter e gravar o conteúdo completo; funcionamento atual exige ensaio real |

## Fluxo efetivamente conectado à fila

1. `queue_service.py:124` distingue `deezer_full` e `deezer_preview` pela presença de ARL nas opções. A validade efetiva é conferida posteriormente pelo motor.
2. `deezer_auth.py:76` consulta a sessão e as capacidades informadas pela conta. O fluxo usa tokens temporários devolvidos pelo serviço, sem um App ID próprio.
3. O mesmo módulo obtém informações da faixa, solicita mídia do tipo completo e trata o stream recebido, incluindo a transformação dos blocos protegidos. Não usa YouTube como substituição nesse ramo.
4. `queue_service.py:349` chama `download_and_decrypt_track`; depois solicita metadados/capa ao módulo de biblioteca. Há tratamento para MP3 e FLAC.

O formato pedido segue as capacidades que o código interpreta da conta. Há seleção de MP3/FLAC e uma tentativa de formato inferior quando FLAC falha. Essas opções e os nomes de plano na interface não comprovam que uma conta gratuita, paga ou determinada faixa consiga receber qualquer formato hoje.

Sem sessão, o caminho usual é a prévia pública. Se uma faixa explícita não tiver prévia, existe um ramo específico de busca no YouTube; outros casos sem prévia podem ser ignorados. Portanto, um arquivo obtido a partir de um link Deezer nem sempre veio de seu stream completo.

Fontes primárias: [motor Deezer](https://github.com/Jjunior-san/C2-VIDEODOWNLOADER/blob/c1df70537baa0a3d2707adefd58fae781ed3a093/deezer_auth.py), [fila](https://github.com/Jjunior-san/C2-VIDEODOWNLOADER/blob/c1df70537baa0a3d2707adefd58fae781ed3a093/queue_service.py), [metadados e capas](https://github.com/Jjunior-san/C2-VIDEODOWNLOADER/blob/c1df70537baa0a3d2707adefd58fae781ed3a093/audio_library.py).

## Spotify para Deezer

O C2 também já conecta as duas plataformas: `discover` percorre as faixas Spotify e chama `match_spotify_track_to_deezer`, em `spotify_catalog.py:367`. Primeiro procura por ISRC; depois tenta título/artista. A correspondência entra no ramo completo ou de prévia conforme a sessão Deezer. Se não encontrar correspondência, a fila prepara busca no YouTube.

O desenho se aproxima do objetivo do D.d, mas o matching precisa de revisão. A alternativa textual pode devolver o primeiro resultado sem um limiar demonstrado de artista, duração e versão. Também pode trocar o marcador `explicit` do candidato por causa da solicitação original, o que não transforma o áudio encontrado em versão explícita. Esses comportamentos não devem ser copiados.

Na construção da fila Spotify, o helper recebe uma lista unitária a cada correspondência. Como ele enumera posições desde 1 em cada chamada, os números das ocorrências podem reiniciar. A ordem original deve ser um dado explícito no D.d, preservado entre provedores, inclusive quando houver falhas ou repetições.

Fonte: [matching Spotify/Deezer](https://github.com/Jjunior-san/C2-VIDEODOWNLOADER/blob/c1df70537baa0a3d2707adefd58fae781ed3a093/spotify_catalog.py#L367) e ramo Spotify da fila.

## Problemas concretos para o reaproveitamento

| Achado | Evidência | Implicação para D.d |
| --- | --- | --- |
| Sessão em texto simples | `youtube_downloader_app.py:4786` inclui ARL nas preferências; `save_user_settings` serializa essas preferências em JSON | Cofre do sistema e referências de sessão; não incluir o segredo na fila |
| Cookie sem escopo de domínio | `create_deezer_session` cria cookies sem domínio; a mesma sessão é usada no endereço de mídia retornado | Separar autenticação e transporte de mídia, restringir destinos e redirecionamentos |
| Conclusão sem inspeção integral do arquivo | O motor publica o arquivo temporário após consumir o stream; não há nessa função uma decodificação integral que comprove áudio válido | Validar contêiner, duração e decodificação antes de concluir |
| Matching e posições frágeis | Seleção textual permissiva e numeração reiniciada em chamadas unitárias | Revisão de candidatos e posição independente da fonte |
| Documentação contraditória | `THIRD_PARTY_NOTICES.md` afirma que não incorpora ARL/descriptografia, enquanto o código contém ambos | Usar o código como evidência de implementação, sem adotar as declarações como prova |

O teste do cookie foi estritamente offline: preparou uma requisição para `example.invalid` com uma sessão fictícia e verificou somente a presença do nome do cookie no cabeçalho. A preparação anexaria ARL ao domínio alheio. Não houve tráfego, nem leitura ou uso de um cookie real.

Fontes: [preferências e interface](https://github.com/Jjunior-san/C2-VIDEODOWNLOADER/blob/c1df70537baa0a3d2707adefd58fae781ed3a093/youtube_downloader_app.py), motor Deezer e [avisos de terceiros](https://github.com/Jjunior-san/C2-VIDEODOWNLOADER/blob/c1df70537baa0a3d2707adefd58fae781ed3a093/THIRD_PARTY_NOTICES.md).

## Verificação executada e limites

- Snapshot da revisão atual, com hashes dos arquivos relevantes.
- Sete testes existentes de `tests/test_deezer_auth.py` aprovados em 1,27 s. Cobrem funções com dados fictícios, respostas simuladas e operações locais; não obtêm uma música do catálogo.
- Verificação offline do escopo de cookies com valor fictício, sem tráfego de rede.
- Nenhum login Deezer, cookie real, licença de conta, URL de mídia autenticada ou arquivo completo foi obtido neste ensaio. Não foi procurada uma sessão existente na máquina.

Evidências: `evidencias/c2-deezer-2026-10-28-manifest.json`, `evidencias/c2-deezer-2026-10-28-tests.log` e `evidencias/c2-deezer-cookie-scope.json`.

## Decisão para o projeto

O cadastro de aplicativo Deezer não é pré-requisito técnico desse caminho do C2. A hipótese de uma fonte Deezer completa permanece aberta e merece validação própria, distinta do Spotify e das prévias públicas.

Antes de habilitar isso no D.d, o ensaio precisa demonstrar uma faixa real completa com conta própria, qualidade efetiva, duração, capa, falhas e expiração da sessão. A solução deve ficar num adaptador separado, usar armazenamento seguro e manter as regras compartilhadas de correspondência/ordem. Autenticação mobile requer integração própria; esse código Python não comprova um caminho móvel pronto. Não transportar cookies de navegador por descoberta automática nem solicitar ARL no chat.

Continuam válidos os dez MP3s externos já testados. Eles não eliminam a investigação Deezer, e a existência deste módulo não deve ser apresentada como download Deezer já validado para o D.d.
