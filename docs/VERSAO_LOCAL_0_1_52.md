# 0.1.52+53 — contas e execução Android fora da janela

Checkpoint local de 06/11/2026, sem release/tag. Windows instalado permanece 0.1.48. Pedido posterior: continuar automaticamente a implementação e só realizar testes humanos no APK depois de todas as funções desktop operacionais estarem implementadas no mobile. Não pedir rodadas manuais de APK/login a cada checkpoint.

## Implementação

- `AndroidSpotifyAuthorization` escolhe explicitamente o callback `http://127.0.0.1:43822/android/spotify/callback`. Windows conserva `http://127.0.0.1:43821/callback`. O listener seguro é compartilhado; a escolha/configuração de plataforma é separada. Navegador externo, PKCE S256, sem client secret/cookies; cofre e refresh continuam pelos módulos existentes.
- Callback verifica origem/porta/caminho, state único, ausência de fragmento/credenciais e ambiguidades entre erro/código. Listener é liberado em sucesso, cancelamento e timeout; cancelar durante o bind impede abrir o navegador. Nenhum código/token entra em logs, banco de evidências ou mensagem refletida no HTML.
- `DdApplication` possui um `AndroidRuntime`: FlutterEngine, áudio e motor de fontes. `MainActivity` fornece a janela e documentos, mas não destrói o motor ao ser encerrada. SQLite/fila e regras permanecem Dart. Não criar outro isolate ou outra fila para serviço, nem outra instância de player ao reabrir.
- `DdWorkService`, tipos dataSync/mediaPlayback, notificação de trabalho ativo, MediaSession e controles de reprodução/fila. Quando música e downloads coexistem, cada conjunto tem notificação própria. Encerrar a reprodução limpa também a fila transitória do player, sem alterar biblioteca/downloads. Ao sair de Músicas, o módulo continua pausando e transportes não o reativam fora da categoria.
- CPU lock limitado/renovado somente para download ativo; MediaPlayer possui seu wake mode. Pausa de mídia sem download remove o serviço após dez minutos, mantendo acesso pela notificação enquanto o sistema a conservar. Sem boot receiver/autorestart. Timeout do sistema interrompe trabalho, libera serviço e impede relançamento em background. Reiniciar o app conserva as regras de recuperação existentes; não aprova reposição nem inicia download sozinho.
- Permissão de notificações solicitada uma vez, ao iniciar trabalho, sem bloqueio em caso de recusa. Os testes concedem essa permissão só ao pacote `.integration`, nunca à instalação principal. O serviço respeita as restrições do Android; não há alteração de segurança ou otimização de bateria do aparelho.

## Automação

- Essencial + conexões: 35 testes passaram. Depois, regressão focada de cancelamento antecipado: 9 testes de autorização passaram, incluindo o caso novo. Windows conserva sua implementação de transporte/retorno pela mesma interface.
- Essencial + player/ponte/navegação/custo: 40 testes passaram. Após adicionar Fechar player pela notificação, ponte/player passaram em 13 testes. A ponte não envia os 200 ticks simulados como atualizações de estado geral.
- Android real no emulador API 36 x86-64: callback loopback, cofre, refresh, restauração, cancelamento e timeout passaram com códigos/tokens/respostas **sintéticos**. Não é login de conta real nem configuração do cadastro Spotify.
- Segundo plano automático: Activity encerrada e reaberta duas vezes por SystemNavigator/ADB, mesmo isolate e fila. Áudio continuou e avançou automaticamente; sessão, pausa/reprodução e fechamento responderam. Dois HTTP de fixture concluíram com Activity encerrada; notificações de mídia/download coexistiram e pausa/retomada da fila funcionou. Serviço finalizou ao cessar o trabalho. Nenhuma conta/biblioteca pessoal foi utilizada.
- A automação passou a esperar troca de faixa **e** player preparado/reproduzindo; trocar o índice ocorre antes de abrir o próximo áudio. Uma repetição foi necessária para corrigir essa condição do teste, sem mascarar indisponibilidade real. Não repetidos os downloads reais de SoundCloud/YouTube Music, pois seus adaptadores não mudaram.
- Análise estática final sem problemas; scripts PowerShell conferidos pelo parser. Regressão completa não executada, conforme política de essenciais/focados.

## Configuração externa e pendências

O novo redirect precisa ser autorizado no cadastro do Client ID usado no APK. O identificador público atual pode atender as plataformas com retornos próprios, ou o build Android pode fornecer outro `SPOTIFY_CLIENT_ID` público; nunca incluir client secret ou copiar tokens Windows. **Cadastro e autorização reais ainda não validados.** Não apresentar o teste sintético como acesso a playlists privadas de uma conta real.

Seguem no checklist SAF/pastas públicas/SD, compartilhamento de links/arquivos recebido, importação por todas as origens, sessão/arquivo Deezer reais, tabelas/gestos e cenários de encerramento do processo/OS. Nenhuma pendência foi removida para antecipar testes humanos.

## Reproduzir somente os focados

No estágio Android local preparado:

```powershell
./tools/test_android.ps1 -TestFile integration_test/android_connections_test.dart
./tools/test_android_background.ps1
```

O segundo runner aceita apenas o emulador `Definitive_API_36`, sem contas. O observador reabre exclusivamente a Activity do pacote `.integration` após cada marcador esperado; não interage com outros aplicativos. Registros ficam fora do Git. Não rodar esses ensaios a cada alteração visual sem relação com o ciclo de vida.

Referências primárias: [PKCE Spotify](https://developer.spotify.com/documentation/web-api/tutorials/code-pkce-flow), [redirects aceitos e portas](https://developer.spotify.com/documentation/web-api/concepts/redirect_uri), [RFC 8252 para apps nativos/loopback](https://www.rfc-editor.org/rfc/rfc8252#section-7.3), [FlutterEngine mantido fora da Activity](https://api.flutter.dev/javadoc/io/flutter/embedding/android/FlutterActivity.html), [tipos de serviço Android](https://developer.android.com/develop/background-work/services/fgs/service-types) e [timeout dataSync](https://developer.android.com/develop/background-work/services/fgs/timeout).

Pacote final debug com assinatura v2 verificada: `br.com.definitivedownloader.app`, versão 0.1.52/versionCode 53, mínimo API 24/target 36, ARM64/x86-64 e runtimes nativos conferidos. SHA-256: `47ecae0c98454e6c296ea3c52174a732d2b33c196935deb27b42f6a7eb2a9d58`. Artefato local em `dist/Android`, sem release/tag e sem substituir artefatos anteriores. Não é entrega para testes humanos nem paridade completa.

O primeiro empacotamento encontrou o ambiente Python de desenvolvimento apontando para uma versão do runtime do host removida por atualização. Foi preservado backup da configuração local e ajustada a referência para a mesma versão/ABI 3.12.14 disponível, sem instalar pacotes globais. Sem caminho explícito, o build procura um Python funcional nas alternativas locais conhecidas; os módulos Android continuam travados por hash, separados do ambiente host.
