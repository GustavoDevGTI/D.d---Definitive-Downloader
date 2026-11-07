# 0.1.56+57 — contas no fluxo musical, Windows e Android

Entrega local de 06/11/2026. Sem release/tag no GitHub. A paridade Android continua em andamento; não solicitar testes humanos do APK antes de completar as funções operacionais.

## Fluxo aplicado

- Um link Spotify válido oferece login após a colagem; importar, criar playlist com link, acrescentar links e informar fonte manual também verificam a conta antes de ler/modificar a coleção. Primeiro Spotify por PKCE no navegador oficial, depois Deezer como fonte principal. Contas já conectadas não são solicitadas novamente. Cancelar conserva a playlist; cancelar a etapa Deezer não cancela uma autorização/restauração Spotify independente.
- O leitor público/parcial do Spotify foi desativado, inclusive seu método legado. A leitura passa pelo importador autenticado, com paginação, posição, repetições e verificação do snapshot. Não transformar recusa da API em importação anônima. O acesso Spotify continua sujeito às permissões realmente concedidas pela plataforma.
- Deezer usa uma janela de login dentro do D.d, sem campo de ARL. A janela é privada; Windows cria ambiente WebView2 próprio e temporário, Android usa o WebView pertencente ao app. Não acessa perfis/cookies do navegador externo. O gerenciador nativo captura somente `arl` do domínio Deezer HTTPS daquele fluxo. A sessão é verificada pelo motor antes de fechar a janela e validada novamente antes de gravar no cofre. Cookie anônimo ou inválido não é prova de conta conectada. Não são lidas senhas de formulário.
- Sessão e cookies não são impressos, enviados ao chat ou gravados em evidências. A janela restringe navegação principal, não aceita conteúdo misto/arquivos e não concede câmera/microfone. Consulta periódica é limitada a cinco minutos, sem repetir indefinidamente uma sessão recusada. Ao fechar, limpa cookies e tenta remover apenas seu próprio perfil temporário, com contenção e tentativas limitadas.
- Atalhos compactos Spotify/Deezer ficam junto às ações de importação e conferência, inclusive no painel móvel. Desaparecem individualmente quando a conexão é concluída e reaparecem ao desconectar. Conectar pela conferência refaz a busca da faixa quando ela admite alternativas; não substitui uma fonte manual protegida, não confirma correspondência e não inicia download. Conexões continua disponível para gerenciar as contas.
- Correspondência que precise da fonte principal e downloads Deezer ainda sem sessão solicitam conexão. A reposição de mídia apagada continua exigindo revisão, escolha explícita e outro comando de download. MP3 direto/local e fontes públicas independentes não exigem uma conta Deezer sem necessidade.
- Resposta explícita posterior: YouTube Music mantém a busca pública, com conta somente quando necessária. YouTube/SoundCloud públicos continuam pelos adaptadores existentes. Não foram fabricados logins Google/SoundCloud inexistentes: conteúdo restrito que dependa dessas integrações permanece indisponível. O texto antigo que dizia não aceitar videoclipes foi retirado; aprovação de versão segue o domínio.

## Verificação e infraestrutura

- Análise estática sem problemas no código funcional. Essencial + contas/Spotify/recuperação: **43 testes passaram** antes do último ajuste de isolamento do cancelamento. Resultado final focado registrado abaixo.
- Android API 36, pacote `.integration`: WebView real em modo privado, cookie HttpOnly sintético no próprio perfil, captura pela origem permitida, recusa de domínio impostor e limpeza passaram. Nenhuma conta foi autenticada nesse teste.
- Windows Release: `--check-login-webview` executou o mesmo contrato no WebView2 real e terminou com código 0/`DD_WEB_LOGIN_OK`. Não abre banco da biblioteca, cofre ou perfil de navegador existente. O encerramento produziu aviso nativo de classe de janela Chromium, sem falha do processo; não é prova de login real.
- Biblioteca `flutter_inappwebview` travada em **6.2.0-beta.3**, com subpacotes/hashes no lockfile. A estável 6.1.5 falhou com AGP 9 por sua configuração ProGuard antiga; foi usada a correção upstream, sem alterar o cache do Pub, reduzir o SDK ou contornar TLS. A versão beta exige atenção na consolidação/release; não foi tratada como validação de todos os métodos de autenticação social.
- Build Windows reutiliza o estágio curto `%LOCALAPPDATA%/Ddb`, evitando o limite de caminho do MSBuild. NuGet 6.11.1 é uma ferramenta local, travada por SHA-256 e assinatura Microsoft; PATH muda só no processo de build. Sem instalação global, alteração de política do Windows ou novo emulador. Licenças dos componentes nativos acompanham o pacote em `licenses/webview`.
- Referências primárias: [gerenciador nativo de cookies](https://inappwebview.dev/docs/cookie-manager/), [pacote e versões upstream](https://pub.dev/packages/flutter_inappwebview/versions), [WebView2 Runtime](https://learn.microsoft.com/en-us/microsoft-edge/webview2/concepts/distribution).

## Evidência final e artefatos

- Após isolar o cancelamento de cada conta, **27 testes essenciais/focados passaram** na rodada final, incluindo o novo caso de cancelar Deezer durante restauração Spotify. São rodadas sobrepostas, não 70 testes distintos. O último ajuste não alterou o adaptador nativo já exercitado; não foi repetida a matriz inteira de provedores/UI.
- Windows atualizado pelo instalador local, saída 0, executável instalado idêntico ao pacote e `ProductVersion 0.1.56+57`. Aplicativo reiniciado. Backup SQLite privado anterior à atualização; comparação posterior conservou **schema 16, 2 coleções e 242 faixas**, sem transferência ativa. Dados, arquivos baixados e sessões do cofre não foram limpos.
- Android atualizado por `install -r` e aberto no mesmo AVD `Definitive_API_36`, pacote normal, versionCode 57/0.1.56, mínimo API 24/target 36, ARM64/x86-64. Assinatura debug v2 conferida; biblioteca preservada. Não é release Play Store nem convite de teste humano.
- APK `dist/Android/Definitive-Downloader-0.1.56-Android-teste.apk`: SHA-256 `f8162f9efd3075d39301ec22eab5df2825461c8e98d2342d04a35dc616e454f3`.
- Instalador `dist/Windows/Definitive-Downloader-0.1.56-Setup-Windows-x64.exe`: SHA-256 `c182751f3a663a97ff07d97ee420463a768b2fb1eb4d03042e8c73f810f9a214`.

## Limites preservados

Capturar uma sessão sintética não autentica uma conta Deezer, não prova login por Google/Facebook/Apple dentro do WebView e não valida obtenção Deezer real no Android. Cadastro externo do retorno Spotify Android, contas reais, demais importações por origem e casos físicos de SD/fones continuam no checklist. Os binários são locais; não há release/tag nem convite de teste humano antecipado do APK.
