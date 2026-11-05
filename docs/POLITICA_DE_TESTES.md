# Validação por risco e escopo

Solicitação de 05/11/2026: reduzir tempo, tokens e repetição nas atualizações locais. Esta política substitui a exigência implícita de repetir toda a suíte/conferência a cada pequena alteração. Não elimina testes existentes nem reduz os critérios de release.

## Núcleo essencial: em toda mudança

Cinco arquivos, atualmente 19 contratos rápidos, sem contas ou provedores externos:

| Arquivo | Risco protegido |
| --- | --- |
| `architecture_test.dart` | Ciclos e dependências indevidas entre camadas. |
| `matching_test.dart` | Artista/gravação/duração incorretos aceitos automaticamente. |
| `music_policy_test.dart` | Tipo de mídia, autorização e metadados por ocorrência. |
| `repository_test.dart` | Ordem, repetições, persistência, importação interrompida e M3U8. |
| `download_test.dart` | MP3 local/HTTP loopback, medições reais, conteúdo inválido e nomes seguros. |

Executar uma vez junto dos focados, não novamente por grupo ou no build do mesmo código. Os arquivos são deduplicados pelo runner. A quantidade de testes pode mudar; o manifesto é a fonte da seleção, não uma meta fixa de contagem.

## Focados: somente o que mudou

`tools/test_suites.json` agrupa os testes existentes sem movê-los ou quebrar fixtures compartilhadas:

| Área (`-Area`) | Quando selecionar |
| --- | --- |
| `collections` | Organização, edição/ordem, mistura de links/MP3 e duplicatas. |
| `imports` | Parsing e entrada de faixas/playlists, formatos e provedores de origem. |
| `matching` | Candidatos, escolha de fonte, revisão e autorização de versões. |
| `downloads` | Execução, pausa/cancelamento/extras, métricas, colunas, recuperação. |
| `player` | Fila/reprodução, navegação, arquivos/capas e controles de áudio. |
| `connections` | Spotify, PKCE, sessão e importação autenticada simulada. |
| `storage` | Schema/migração, consultas e persistência, inclusive diário de substituição. |
| `ui_collections`, `ui_downloads`, `ui_player`, `ui_common` | Somente a interface/gesto afetado. Somar a área de comportamento se ela também mudou. |
| `worker` | Contratos Dart e testes Python offline do motor. |

Pode selecionar várias áreas ou um arquivo específico com `-TestFiles`. Para um bug pontual, preferir o teste que o reproduz mais o essencial; não executar todos os grupos por precaução. Se uma alteração compartilhada tiver impacto real em mais módulos, incluir os respectivos grupos. Um teste novo precisa entrar no grupo adequado ou ser passado explicitamente; nada deve ficar sem classificação.

Rodar os focados durante o trabalho. Depois de passarem, não repetir sem nova alteração/falha relevante. Corrigir só documentação após a validação não invalida resultados do aplicativo. Formatar Dart alterado e analisar uma vez; não gerar testes que apenas espelhem ajustes visuais triviais.

## Regressão: suspeita de bug ou antes de release

`-Profile Regression` executa toda a suíte Flutter e todos os testes Python offline em `runtime/music_worker`. Inclui arquivos novos automaticamente. A matriz geral de telas (`layout_test.dart`) e os testes amplos de custo (`update_cost_test.dart`) ficam fora da rotina; podem ser chamados diretamente se o bug os envolver.

Antes de publicar no GitHub, exigir regressão completa do código que será publicado. Se uma suspeita estiver restrita a uma feature, começar pelo grupo/arquivo dela; ampliar só quando a investigação indicar impacto cruzado. Não programar rodadas completas periódicas sem solicitação.

Testes reais de provedores, login, download/extração e decoder nativo continuam optativos, separados e com evidências próprias. Executar somente os relevantes a uma integração alterada, suspeita concreta ou validação de release. Não repetir toda a bateria de contas/provedores em uma alteração visual. Os perfis rotineiros removem temporariamente flags de ensaios optativos e de geração de capturas do ambiente, restaurando-as ao final. Probes reais e capturas específicas são executados explicitamente fora desses perfis, conforme a documentação da feature. Passar testes offline não comprova download real ou funcionamento mobile nativo.

Quando UI mudar, conferir o fluxo afetado em duas larguras; não reproduzir a navegação inteira. Usar a janela instalada quando o risco exigir comportamento nativo (por exemplo, acessibilidade do slider, plugin, arraste externo ou áudio). Não pedir desbloqueio do Windows apenas para repetir uma conferência ampla sem relação com a mudança. Registrar o que foi e não foi conferido.

## Comandos

Em um workspace Flutter **local, atualizado e com dependências preparadas**:

```powershell
# Só o núcleo rápido
./tools/test_project.ps1 -Profile Essential

# Núcleo e área alterada, numa única execução
./tools/test_project.ps1 -Area collections
./tools/test_project.ps1 -Area collections,ui_collections
./tools/test_project.ps1 -TestFiles test/collection_duplicates_test.dart

# Ver a seleção sem executar nada
./tools/test_project.ps1 -Area player -ListOnly
./tools/test_project.ps1 -Profile Regression -ListOnly

# Toda a regressão offline; Python deve ter as dependências do motor
./tools/test_project.ps1 -Profile Regression
```

O runner não instala dependências. Aceita `-FlutterPath`, `-PythonPath` e `-WorkspaceRoot`. Sem áreas/arquivos, Local executa apenas o essencial e informa essa limitação; isso não comprova que a feature alterada foi validada. Área desconhecida ou arquivo inexistente gera erro, sem trocar silenciosamente para a suíte completa ou ignorar o teste.

No projeto UNC, não chamar Flutter com cwd na rede: sincronizar `lib`, `test`, `assets`, pubspec/lock, opções de análise e estes dois arquivos de ferramentas com o estágio local preparado; passar `-WorkspaceRoot` apontando para ele. Não testar cópia antiga. Se dependências mudaram, preparar o estágio novamente. O build Windows já prepara o estágio e copia o runner/manifesto automaticamente; para `worker`/Regression também copia seus fontes e testes.

```powershell
# Build e testes locais proporcionais à mudança
./tools/build_windows.ps1 -TestAreas collections

# Código idêntico já passou nos testes e na análise: não repetir
./tools/build_windows.ps1 -SkipTests -SkipAnalysis

# Preparação de release, com regressão completa
./tools/build_windows.ps1 -TestProfile Regression
```

O build sem áreas usa somente o essencial e informa isso. O perfil Regression não pode ser combinado com SkipTests. Não passar flags de skip para encobrir falhas; só reutilizar resultados concretos do mesmo código. Instalação/versionamento seguem a política do ciclo local. Alterar apenas este processo e documentação não gera uma versão nova do aplicativo.

## Verificação desta mudança de processo

- Essencial executado pelo runner no estágio local atualizado: **19 testes passaram**, cinco arquivos; aproximadamente **7,8 segundos** incluindo a inicialização do Flutter nesta rodada (o runner do Flutter indicou cerca de dois segundos para os testes). Medida pontual, sem promessa de tempo fixo.
- Planejamento dos 12 grupos conferido sem executar suas suítes: essencial presente, arquivos deduplicados e matriz geral de telas ausente da seleção rotineira. Todos os 43 arquivos de teste atuais estão classificados; testes novos sem grupo/seleção explícita geram erro no perfil local. Regression enumera todos automaticamente e inclui o motor offline.
- Parser PowerShell dos dois scripts sem erros. Casos negativos de área desconhecida e caminho inválido recusados. Com um comando sintético que retorna código 7, o runner propagou a falha; flags de probe/captura foram suprimidas durante a execução e restauradas ao terminar. Regression com SkipTests foi recusado antes de iniciar build.
- Não executados nesta mudança: regressão Flutter completa, testes Python do motor, ensaios de conta/provedor, capturas, conferência nativa e build/instalação do aplicativo. Nenhum arquivo Dart, schema, dependência, versão ou dado do app foi alterado.

Logs privados em `%LOCALAPPDATA%/DefinitiveDownloaderDev/validation-policy-2026-11-05`, fora do Git.
