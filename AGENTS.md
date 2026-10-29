# Instruções do projeto

## Produto e prioridades

- Versionamento: usar versões incrementais `0.1.1`, `0.1.2` etc. para correções e pequenas melhorias; atualizar `pubspec.yaml`, versão do instalador, tag e notas de release em conjunto. Versões menores/maiores seguem a amplitude das mudanças. Não sobrescrever releases publicadas.
- Toda versão entregue exige release no GitHub para manter o histórico, conforme solicitação explícita de 29/10. Repositório do produto: `GustavoDevGTI/D.d---Definitive-Downloader`. Publicar o commit correspondente, tag `vX.Y.Z`, notas e artefatos com SHA-256; conferir a release publicada antes de declarar a entrega concluída. Não substituir assets ou tags publicados, nem criar tags retrospectivas com código de outra versão. Evidências locais e dados das contas não entram na publicação.
- Nome definido pelo usuário: **Definitive Downloader**. Abreviação oficial: **D.d**. Não inventar ou substituir o nome do produto; usar a abreviação em espaços compactos.
- A stack escolhida pelo usuário é Flutter/Dart. Manter interface, domínio e regras compartilháveis com mobile; o foco atual é a primeira versão desktop Windows.
- O produto é desktop **e** mobile. Um piloto Windows não reduz esse escopo. API compartilhada não significa credencial OAuth única: Google usa clientes próprios por tipo de plataforma no mesmo projeto; Spotify precisa dos retornos e identificadores das plataformas atendidas. Nunca reutilizar automaticamente o callback de loopback Windows no mobile.
- Suporte obrigatório no escopo desktop e mobile, além dos formatos tradicionais: `.dlc`, `.ccf`, `.rsdf`, `.metalink`, `.meta4`, `.nzb` e `.sfdl`, conforme `docs/FORMATOS_E_MULTIPLATAFORMA.md`. São requisitos planejados, ainda não implementados ou validados. Associação de extensão, leitura do arquivo e obtenção do conteúdo são capacidades distintas; não anunciar suporte completo só por aceitar a extensão.
- Cada nova feature deve contemplar desktop e mobile na mesma etapa, com núcleo Dart compartilhado e integrações por plataforma. O piloto Windows existente é uma entrega parcial; seu worker Python não constitui implementação mobile. Validar cada plataforma antes de declarar a feature concluída no produto.
- Identidade visual própria. Nunca copiar o visual de C2, JDownloader ou Spotify.
- Reestruturação atual: seguir `docs/REESTRUTURACAO_WIREFRAME_0_5_1.md`, com Início, Músicas, Vídeos e Fotos, Arquivos e Configurações. Captura e Downloads pertencem às categorias; não criar fila global duplicada. Preservar o tema nesta etapa estrutural e adaptar navegação/listas para mobile.
- Refino visual 0.1.3 em `docs/RELEASE_0_1_3.md`: seguir a organização do HTML v0.5.1 fornecido, com coleções acima da lista, painéis contornados e controles de captura espaçados. Os dados de teste foram limpos uma única vez a pedido do usuário, com backup; nunca repetir a limpeza automaticamente em uma atualização ou inicialização.
- A referência visual posterior é a sequência de prints desktop e mobile, aplicada em `docs/RELEASE_0_1_4.md`: Início com dois atalhos e três indicadores reais; Coleções em lista vertical antes da conferência; formulários de captura em painéis; tabela horizontal nas filas mobile; pastas e configurações em linhas. Os cantos mais arredondados das abas/campos seguem essa instrução explícita. Não copiar as molduras/legendas de simulação nem seus dados fictícios para produção.
- A direção visual mais recente foi solicitada em 29/10 e está em `docs/DIRECAO_VISUAL_0_1_6.md` e `docs/RELEASE_0_1_6.md`: ocupar a janela sem moldura/margem externa ou limite de 1240 px, visual mais pessoal em framboesa/azul e Manrope, controles de Downloads em uma fila de ícones com tooltips e rolagem horizontal mobile. Início sem caixas de indicadores, com Coleções/Arquivos e histórico recente real. Essa instrução substitui os tratamentos visuais anteriores nesses pontos; não altera funções ou autoriza dados fictícios.
- Correspondência e transferência têm estados distintos. Fonte manual é por ocorrência, persiste após reinício e não pode ser substituída pela busca ou fallback. Vínculos sem suporte de obtenção ficam pendentes; cadastrar uma URL não significa download ou extração disponível. Manter a restrição YouTube Music ATV na obtenção musical, inclusive manual.
- Schema v6 acrescenta estado de correspondência, fonte manual e histórico relacional de arquivos concluídos. Arquivos é histórico por pastas reais; não mover/excluir arquivos durante a migração nem apagar registros automaticamente quando o arquivo estiver indisponível.
- Schema v7 acrescenta prioridade e identificação da execução da fila; a prioridade nunca altera a posição original das ocorrências nem a M3U8. Controles 0.1.5 em `docs/RELEASE_0_1_5.md`: pausa limita a transferência atual e impede novas; parada preserva concluídos. Falhas ao limpar staging não podem mascarar cancelamento ou virar indisponibilidade de provedor/fallback. Rodada UI Windows 29/10 concluiu 10/10 Deezer; YouTube Music ATV teve ensaio real complementar pelo worker, separado da UI. Mobile segue sem motor nativo.
- Começar pelo fluxo musical: importar coleção, comparar faixas, revisar candidatos e preservar a ordem no resultado.
- Os testes iniciais foram sem conta. O usuário está pronto para vincular Spotify e YouTube; os cadastros começarão do zero, conforme `docs/CONFIGURACAO_DAS_CONTAS_DE_TESTE.md`. Nunca ler cookies ou procurar credenciais existentes; autenticação ocorre pelo fluxo oficial solicitado pelo usuário. Nunca pedir senha/token no chat.
- O Client ID público Spotify fornecido pelo usuário está em `features/connections/domain/spotify_auth.dart`. Login por PKCE, importação autenticada de 10 faixas e restauração da sessão em um reinício Windows foram confirmados conforme `docs/SPOTIFY_CONEXAO.md`. Renovação real após expiração, repetições reais, Google e mobile ainda exigem validação própria. Nunca registrar códigos de retorno ou tokens nas evidências; autorização e resultados reais devem ser distinguidos de testes sintéticos.
- Distinguir arquivo completo, prévia, metadados e simulação. Não apresentar fixture local como download de plataforma.
- Ensaios de áudio em `docs/TESTES_AUDIO_SPOTIFY.md`: spotDL externo gerou dez MP3s reais com capa e M3U8, após corrigir um candidato por duração. Em 28/10, a rodada direta terminou: três faixas no librespot e uma em cada motor Zotify autenticaram, mas falharam ao obter a chave do áudio, sem arquivo utilizável. Comparação concluída para esses casos Windows; não extrapolar para todo catálogo/versão/ambiente. Priorizar a alternativa com revisão e fonte real identificada. Motores não incorporados ao app. Identificadores nativos usados pelo upstream na pesquisa não substituem o cadastro próprio do produto.
- Reavaliação Deezer em `docs/REVISAO_C2_DEEZER.md`: o C2 implementa obtenção completa por sessão ARL e APIs internas, sem App ID de desenvolvedor. Isso é independente do cadastro OAuth público e não exige aprovação desse cadastro para ser investigado. Sete testes simulados passaram, mas nenhuma faixa real Deezer foi validada. O código atual anexa o cookie a um destino alheio no teste offline de preparação de requisição e persiste sessão em JSON; não copiar esses comportamentos. Não procurar cookies existentes nem pedir ARL no chat.
- Próxima direção: transferência de playlists integrada à interface própria, conforme `docs/TRANSFERENCIA_DE_PLAYLISTS.md`. Usar `GLOSSARY.md` para distinguir transferência, correspondência e download.
- Incluir no escopo Transferir, Compartilhar, Cópia de segurança, Gerar playlist com IA e Organizar, conforme `docs/FERRAMENTAS_DE_PLAYLISTS.md`. Entregar uma feature por vez, sem apresentar funções planejadas como disponíveis.
- Backup de playlists e cópia de mídia são opções distintas. Organização nunca remove repetições sem revisão; geração com IA exige faixas verificadas em catálogo e rascunho revisável.
- Uma gravação encontrada em catálogo não comprova arquivo baixável ou permissão de escrita. Habilitar capacidades por plataforma somente após validá-las com acesso próprio.
- Downloads musicais: excluir videoclipes, busca genérica do YouTube e fallback para vídeos. No YouTube Music aceitar apenas resultados `song` identificados como `MUSIC_VIDEO_TYPE_ATV`, reconferidos antes da obtenção. Tipo ausente ou diferente é bloqueado, inclusive em escolha manual. Não cortar/normalizar uma versão errada para fazê-la coincidir com a duração pedida.
- Integração atual em `docs/DOWNLOAD_MUSICAL_INTEGRADO.md`: adaptadores próprios em `runtime/music_worker`, chamados por operação pelo Flutter Windows. Não confundir com incorporação de spotDL/Zotify/librespot. Ensaio anterior pelo runner Flutter obteve 10/10 MP3s YouTube Music ATV em banco separado. A rodada posterior pela UI Windows concluiu a coleção real Teste: sete arquivos Deezer e três YouTube Music, todos com capa, duração e decodificação integral verificadas e M3U8 ordenada. Os três primeiros usaram a alternativa durante o diagnóstico, antes das correções do leitor de página e dos blocos Deezer; não concluir que essas três faixas sejam indisponíveis na Deezer. Conta Deezer informada como gratuita pelo usuário; conexão e restauração após um reinício foram confirmadas. Isso não comprova todo catálogo, outras contas, renovação após expiração ou mobile. A conexão solicita sessão somente no campo local mascarado e usa cofre; nunca inspecionar cookies existentes ou registrar credenciais. O worker Python Windows não resolve a implementação mobile.
- Iniciar o piloto por `INICIAR.cmd`, que sincroniza e abre o pacote local em `%LOCALAPPDATA%\DefinitiveDownloader\app`. A execução nativa pela UNC falhou ao carregar `_socket` no worker antes de qualquer consulta à conta, embora o runner Flutter não reproduzisse. O pacote local passou no diagnóstico nativo com sessão fictícia; não chamar esse diagnóstico de login real. Não recomendar alterar TLS, segurança do Windows ou fornecer ARL novamente antes de conferir a origem do erro.
- Schema v5 mantém o último resultado por provedor e ocorrência em `music_source_attempts`, com mensagem sanitizada; o fallback não pode apagar a causa da tentativa anterior. Nunca armazenar requisição, ARL, tokens ou URLs assinadas nessa tabela. O leitor Deezer decodifica somente o JSON da atribuição de estado, sem avaliar JavaScript. A transformação dos blocos tem vetor conhecido e teste de fragmentação independente dos chunks de rede.
- Identificar a origem efetiva Deezer ou YouTube Music na coluna da biblioteca, nas entradas M3U8 e nos nomes dos novos MP3s. O fallback deve refletir a fonte final. A coleção piloto já foi renomeada e seus caminhos atualizados, preservando os hashes dos arquivos. O build Flutter não deve sobrescrever o motor musical com uma cópia antiga do staging.

## Arquitetura

- Não concentrar o aplicativo em um único arquivo. `main.dart` apenas inicializa e compõe dependências.
- Separar domínio, casos de uso/controle, infraestrutura e apresentação. Widgets não fazem SQL, HTTP, leitura de arquivos ou execução de processos.
- Usar módulos com interfaces pequenas e responsabilidades claras; evitar abstrações sem uso real.
- Persistência relacional em SQLite, com migrações, consultas parametrizadas, índices e transações curtas.
- Nunca persistir a playlist ou a fila inteira como um JSON em uma linha. Não carregar o banco inteiro para renderizar uma tela.
- Paginar listagens; atualizar apenas os registros alterados. Fazer parsing incremental ou impor limites explícitos a importações e respostas externas.
- Preservar a posição de cada ocorrência na playlist, inclusive repetições. Uma gravação pode aparecer mais de uma vez.
- Transferências entre contas têm estado e confirmação próprios, separados do download local. Reconciliar escritas remotas com resultado desconhecido antes de tentar novamente; não eliminar repetições intencionais.
- Regras de matching no domínio; não aceitar o primeiro resultado só porque a busca retornou algo. Considerar artista, título, duração e versão.
- Separar metadados solicitados dos metadados reais da fonte encontrada. Nunca prometer ganho de qualidade por transcodificação.
- Trabalho concluído exige arquivo validado e metadados verificados. Progresso de rede a 100% não encerra processamento.

## Segurança e robustez

- Não gravar segredos em configurações, banco, logs ou arquivos de evidência. Futuras sessões usam cofre do sistema.
- Validar esquema/domínio de links; limitar tamanho e tempo de respostas. Não enviar credenciais em redirecionamentos entre origens.
- Sanitizar nomes, verificar contenção na pasta de destino e usar escrita temporária com publicação atômica quando possível.
- Processos externos com argumentos estruturados e sem shell. Cancelamento deve afetar somente o trabalho iniciado pelo app.
- Rede, disco e parsing pesado não podem bloquear a interface. Declarar erros e indisponibilidade sem loops infinitos de retry.

## Design

- Tema claro, sóbrio, com superfícies brancas/cinzas frias e acento discreto.
- Preferir listas e tabelas com hierarquia e espaço útil; evitar mural de cartões, pílulas, bolhas, sombras e gradientes decorativos.
- Poucas ações principais, linguagem direta em português e estados de erro/ausência com orientação concreta.
- Tipografia legível, foco de teclado, atalhos, contraste e escala de texto adequados.
- Layout adaptativo: compartilhar identidade, não reduzir mecanicamente a tela desktop para mobile.

## Validação e entrega

- Executar `dart format`, `flutter analyze` e `flutter test` após mudanças relevantes. Compilar Windows antes de entregar um executável.
- Testar principalmente contratos e riscos: ordem/repetição, matching incorreto, paginação, persistência, interrupção e segurança de arquivos.
- Testes de provedores reais separados de fixtures; nunca chamar teste offline de download real.
- Conferir visualmente a interface em pelo menos duas larguras; corrigir overflow e controles inacessíveis.
- Registrar em `docs/` as decisões, resultados exatos e limitações. Não alegar sucesso de verificações não executadas.
- Manter dependências travadas em lockfile e artefatos de build fora do controle de versão. Não adicionar ferramentas globais ou trocar a stack por conveniência.
