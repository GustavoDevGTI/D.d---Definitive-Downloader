# Cadastro das integrações desktop e mobile

Data: 27/10/2026. O cadastro começou do zero. O usuário já forneceu o Client ID público Spotify, configurado no D.d; a tela Conexões e o fluxo PKCE Windows foram implementados, compilados e abertos. Login real, importação autenticada da playlist Teste com 10 faixas e restauração da sessão após reinício foram confirmados. Google permanece aguardando cadastro. Acompanhar em [SPOTIFY_CONEXAO.md](SPOTIFY_CONEXAO.md).

O **D.d é desktop e mobile**. A primeira credencial Desktop serve ao piloto Windows e não limita o produto ou o projeto Google a esse sistema. Compartilhar Flutter/Dart não elimina as configurações de autenticação específicas por plataforma.

Ordem de preparação:

| Ordem | Integração | O que obter |
| --- | --- | --- |
| 1 | Spotify | Cadastro do D.d, redirect do piloto e Client ID. |
| 2 | Google / YouTube | Projeto com YouTube Data API v3 e cliente OAuth Windows; clientes mobile quando seus identificadores e assinaturas estiverem definidos. |
| 3 | Deezer | Confirmar acesso próprio para OAuth/escrita; a pesquisa pública continua independente desse cadastro. |

## 1. Spotify

Abra o [Spotify Developer Dashboard](https://developer.spotify.com/dashboard) e entre com a conta que será proprietária do aplicativo. Em Development Mode, essa conta precisa de Premium. [Condições oficiais](https://developer.spotify.com/documentation/web-api/concepts/quota-modes).

Crie o aplicativo e use estes valores para o piloto:

| Campo | Valor |
| --- | --- |
| App name | `Definitive Downloader — Testes` |
| App description | `Aplicativo desktop e mobile em desenvolvimento para importar, conferir e transferir minhas playlists entre plataformas.` |
| Redirect URI do piloto Windows | `http://127.0.0.1:43821/callback` |
| API utilizada, caso solicitada | `Web API` |
| Website | Se opcional, deixar vazio; não usar o endereço do C2 como se fosse o site do Definitive Downloader. |

O usuário deve ler e aceitar pessoalmente os termos apresentados pelo provedor ao criar o cadastro. Depois, obter **Client ID**, disponível nas configurações. Para Spotify usaremos PKCE; o Client Secret não precisa ser compartilhado para esse fluxo. [Cadastro de app](https://developer.spotify.com/documentation/web-api/concepts/apps), [PKCE](https://developer.spotify.com/documentation/web-api/tutorials/code-pkce-flow).

Se outra conta Spotify for usada no teste, incluí-la na lista de usuários autorizados do app. A playlist piloto deve pertencer à conta autorizada ou ser colaborativa com ela, respeitando as restrições do modo de acesso.

O callback acima é uma escolha do projeto para o piloto Windows. A porta estava livre na checagem local; isso não garante disponibilidade futura. O listener OAuth só é iniciado durante uma tentativa de conexão. O endereço utiliza loopback explícito, conforme o requisito do Spotify, que não aceita `localhost` como redirect. Não trocar caminho, porta ou barra final independentemente da configuração implementada. [Regras de redirect](https://developer.spotify.com/documentation/web-api/concepts/redirect_uri).

**Mobile no Spotify:** usar o mesmo cadastro de produto quando adequado e acrescentar os retornos autorizados e identificadores Android/iOS correspondentes. O cadastro aceita Android Package e Bundle IDs. A Web API fornece os recursos de catálogo/playlists; seu nome não significa que o aplicativo deva ser um site. PKCE é adequado a clientes móveis sem segredo privilegiado. Os callbacks móveis serão definidos com a integração de sistema; não copiar o loopback Windows como solução universal. [Configurações de app](https://developer.spotify.com/documentation/web-api/concepts/apps), [PKCE](https://developer.spotify.com/documentation/web-api/tutorials/code-pkce-flow).

## 2. Google / YouTube

No [Google Cloud Console](https://console.cloud.google.com/), criar ou selecionar um projeto dedicado ao piloto, por exemplo `Definitive Downloader Testes`. Ativar **YouTube Data API v3** na biblioteca de APIs. [Preparação oficial do YouTube](https://developers.google.com/youtube/data/quickstart/python).

Manter esse projeto para os clientes desktop/mobile do mesmo ambiente de testes. A API e a identificação do produto ficam no projeto; os clientes OAuth representam as instalações em cada tipo de plataforma:

| Plataforma | Tipo de cliente Google | Configuração específica |
| --- | --- | --- |
| Windows | Desktop app | Retorno local pelo fluxo de desktop. |
| Android | Android | Nome do pacote/application ID e SHA-1 do certificado de assinatura correto. Teste e distribuição podem exigir cadastros distintos conforme a assinatura. |
| iOS, se incluído nos alvos de lançamento | iOS | Bundle ID real do aplicativo e integração de retorno prevista pelo SDK adotado. |

[Tipos de credenciais](https://developers.google.com/workspace/guides/create-credentials), [assinatura Android](https://developers.google.com/android/guides/client-auth), [acesso a APIs no iOS](https://developers.google.com/identity/sign-in/ios/api-access).

Em Google Auth Platform:

1. Configurar o nome do aplicativo, por exemplo `Definitive Downloader — Testes`, e os contatos reais do proprietário.
2. Para teste com conta pessoal, escolher público **External/Externo**, manter o aplicativo em testes e adicionar a própria conta Google aos usuários de teste.
3. O usuário revisa e aceita as políticas apresentadas pelo Google.
4. Para o piloto Windows, em **Clients/Clientes**, criar cliente OAuth do tipo **Desktop app/Aplicativo para computador**, nome `Definitive Downloader Windows`. Acrescentar os clientes Android e iOS conforme os alvos configurados; não substituir o cliente desktop por um cliente Web para tentar atender a todos.
5. Baixar o JSON gerado e guardá-lo localmente, fora dos fontes do projeto. Informar somente o caminho local quando formos configurar o Definitive Downloader; não colar o conteúdo no chat.

O JSON pequeno de configuração do cliente não é um backup de playlists nem uma fila. Sua importação futura deve validar formato e tamanho, extrair somente os campos previstos e guardar dados sensíveis no local adequado. Não adicioná-lo ao repositório ou às evidências.

Para cliente desktop, não criar um cliente Web só para procurar o campo de redirect URI. O retorno de loopback é tratado pelo fluxo de desktop. Uma chave de API isolada não substitui OAuth para criar playlists na conta. [OAuth desktop](https://developers.google.com/identity/protocols/oauth2/native-app), [consentimento e usuários de teste](https://developers.google.com/workspace/guides/configure-oauth-consent).

O Google mantém loopback para desktop, mas bloqueou esse fluxo para os tipos de cliente Android/iOS. Mobile deve usar o fluxo suportado pelo provedor e pelo sistema. [Guia oficial de migração](https://developers.google.com/identity/protocols/oauth2/resources/loopback-migration).

Antes de cadastrar o mobile, definir os identificadores definitivos do projeto Flutter e obter os certificados do build correspondente. Os alvos Android/iOS ainda não foram criados/validados neste workspace; não preencher identificadores fictícios para concluir o cadastro. Os testes devem registrar separadamente o resultado em cada plataforma.

## 3. Deezer — acesso autenticado a confirmar

O piloto atual possui **Conexões → Deezer** com campo local mascarado para uma sessão própria. A pessoa autentica no site oficial e informa manualmente o ARL somente no D.d; não é solicitado pelo chat nem procurado automaticamente pelo app. A sessão é validada e guardada no cofre do sistema. Isso usa os serviços internos da conta, sem App ID de desenvolvedor. Em 28/10, o usuário concluiu a conexão com conta informada como gratuita; a restauração após reinício e sete faixas completas foram verificadas na interface Windows. Isso não comprova escrita remota de playlists ou disponibilidade universal. Estado em [DOWNLOAD_MUSICAL_INTEGRADO.md](DOWNLOAD_MUSICAL_INTEGRADO.md).

**Atualização de 28/10/2026:** o C2 também possui um cliente de sessão ARL que tenta obter faixas completas pelos serviços internos do player, sem App ID próprio. Esse caminho é distinto da API pública/OAuth descrita abaixo e não depende de aprovar um cadastro de desenvolvedor. Sua execução com conta própria ainda não foi validada; não procurar cookies existentes nem solicitar ARL pelo chat. Análise do fluxo, testes e problemas em [REVISAO_C2_DEEZER.md](REVISAO_C2_DEEZER.md).

Deezer também possui API. A exigência de cadastro/autorização depende da operação:

| Operação | Acesso previsto |
| --- | --- |
| Pesquisar o catálogo público | A consulta limitada de teste em 27/10/2026 respondeu HTTP 200 com uma faixa, sem credenciais. Não foi obtido áudio. |
| Acessar dados privados, criar ou editar playlists da conta | Requer acesso autenticado do aplicativo, incluindo App ID e autorização do usuário via OAuth, com permissões adequadas. Cadastro e escrita ainda não foram validados para o D.d. |
| Obter MP3 completo | Pesquisa de catálogo, conta conectada e token não comprovam disponibilidade de arquivo completo. Esse caminho permanece uma validação separada. |

A Deezer informou oficialmente em outubro de 2025 a suspensão de criação de novos acessos por particulares. Não foi confirmada reabertura nesta pesquisa; as páginas de cadastro e referência OAuth não puderam ser consultadas pela ferramenta. Portanto, verificar acesso próprio com a plataforma antes de prometer transferência para contas Deezer. [Resposta da Deezer](https://en.deezercommunity.com/features-feedback-44/api-auth-impossible-80857?postid=254887).

Uma resposta pública de catálogo não demonstra que o cadastro de aplicativos está aberto. Não usar credenciais ou App IDs de aplicativos terceiros para contornar essa dependência. Spotify e Google seguem primeiro; a busca Deezer já existente pode continuar como consulta de catálogo.

## 4. O que será usado para configurar o app

- Client ID do aplicativo Spotify: identificador público do app, não é senha nem token de sessão.
- Caminho local do arquivo de configuração OAuth desktop do Google.
- Link de uma playlist Spotify própria, pequena e dedicada ao teste, quando chegar a etapa de importação.

Não são necessários senha, cookie ou token enviados pelo chat. A autorização das contas ocorrerá nas páginas oficiais. No piloto Windows, voltará para o listener local iniciado pelo Definitive Downloader; no mobile, para a integração de retorno suportada pelo sistema/provedor.

## 5. Primeiro teste após a implementação

1. Validar callback, PKCE, timeout e negação de autorização com testes locais antes de conectar uma conta real.
2. Conectar Spotify com leitura das playlists necessárias e importar a playlist piloto, conferindo total, ordem e ocorrências.
3. Conectar Google/YouTube com os escopos que a função realmente exige; apresentar as permissões antes do consentimento.
4. Preparar correspondências, revisar e criar uma nova playlist privada apenas quando essa execução for iniciada pelo usuário.
5. Ler o destino de volta e confirmar sequência, identidade das gravações e repetições quando suportadas.

O usuário realizou o cadastro Spotify, forneceu o Client ID público e concluiu a autorização. A importação autenticada da playlist Teste (10 faixas) e a restauração da conexão após reinício foram confirmadas. Não foi solicitada senha ou Client Secret. Google e transferência remota permanecem pendentes, conforme o relatório de cada integração.
