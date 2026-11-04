# Biblioteca musical — ciclo local de feedback

Direção do usuário em 04/11/2026. Documento de produto e desenho de implementação; não descreve funcionalidades já entregues. Releases suspensas neste ciclo até o usuário pedir consolidação. Base instalada ao iniciar: 0.1.26+27, schema 10.

## Objetivo

Coleções passa a administrar o acervo musical, com referência funcional em um gerenciador como Windows Media Player e identidade visual própria do Definitive Downloader. Permitir ouvir músicas baixadas, personalizar playlists e suas pastas e montar seleções combinando playlists importadas, músicas avulsas, arquivos baixados/importados e links de Spotify, Deezer, YouTube, YouTube Music e outras plataformas conforme suas capacidades reais.

O usuário esclareceu que “álbum” significa a pasta que guarda as mídias no app, não o álbum de origem do artista. O escopo é personalizar playlists e pastas: nomes, capas na interface, conteúdo, ordem e organização. As perguntas anteriores sobre tags e cópias foram formuladas sob uma interpretação incorreta; suas respostas não devem se transformar em edição automática de metadados ou duplicação obrigatória do acervo.

## Organização proposta

Dentro de Coleções, organizar Músicas, Playlists e Pastas, com busca, filtros e ações contextuais consistentes. A playlist apresenta a seleção e sua ordem; a pasta apresenta onde seus arquivos estão guardados. Importação passa a ser uma ação de entrada na biblioteca, sem dominar permanentemente a tela. Preservar a navegação principal do produto e Downloads dentro de Músicas.

- **Músicas:** acervo paginado, com título, artista, álbum, duração, origem e disponibilidade. Músicas já baixadas entram na biblioteca por seus arquivos existentes. Permitir importar arquivos escolhidos pelo usuário; qualquer varredura de pastas depende de uma pasta explicitamente escolhida.
- **Pastas:** locais que guardam as mídias, com nome, capa de identificação no app, conteúdo e vínculo com playlists. Distinguir uma pasta real dos grupos de organização já existentes. Ações de copiar/mover arquivos devem ter efeitos claros e atualizar os caminhos usados pela biblioteca, pelo histórico e pelo player. A capa da pasta/playlist é uma personalização da interface e não implica gravá-la dentro de cada arquivo.
- **Playlists:** seleção ordenada de ocorrências; misturar fontes, incluir outra playlist inteira ou parte dela, acrescentar arquivos e links, reordenar e remover da seleção. Repetições são preservadas e não removidas automaticamente. A mesma música pode participar de várias playlists sem exigir cópia do áudio.
- **Player:** barra persistente com capa, título/artista, anterior, reproduzir/pausar, próxima, posição/duração, volume, fila, repetição e aleatório. A música continua ao navegar. Mobile usa uma barra compacta que abre os controles completos.

Manter Manrope, fundo claro, listas e a paleta oficial. O foco é a biblioteca, com poucas ações principais; não copiar o visual de Windows Media Player ou de plataformas de streaming. Não criar controles falsos para capacidades pendentes.

## Mistura de fontes

Uma playlist pode reunir, por exemplo: faixas selecionadas de uma playlist Spotify, dois arquivos já baixados, um arquivo local escolhido e um link manual do YouTube. Cada ocorrência conserva a versão e a origem selecionadas.

Adicionar uma playlist a outra prepara uma cópia local das ocorrências selecionadas, preservando a ordem interna; não cria sincronização permanente nem altera a playlist original. Importações parciais continuam sinalizadas. Para grandes seleções, leitura e escrita em lotes, com limites explícitos e prévia antes de combinar.

Um link de plataforma é uma referência, não prova de arquivo reproduzível. Reprodução local, reprodução online, prévia e download têm capacidades independentes. A organização da playlist funciona sem baixar, e a escuta para conferência também deve funcionar sem criar um arquivo na biblioteca quando houver prévia ou reprodução online disponível. Nenhuma prévia deve aparecer como música completa. Outros provedores só são habilitados conforme leitura, reprodução, correspondência e obtenção forem implementadas e validadas separadamente.

Preservar a política existente: Spotify busca equivalentes; fonte manual fica fixada por ocorrência; YouTube manual representa escolha de versão; busca automática prioriza áudio e só oferece videoclipes ao fim, com aprovação. Não juntar automaticamente gravações distintas por título parecido.

## Escuta para comparar versões antes do download

Pedido explícito posterior de 04/11/2026: ouvir as versões alternativas recomendadas antes de aceitá-las; se a reprodução integrada não for possível, oferecer ao menos o link de referência. A ausência de uma correspondência exata não deve obrigar o usuário a baixar uma versão para conhecê-la.

Cada candidata deve apresentar título, artista/canal, plataforma, duração, tipo de versão e as ações compatíveis com sua capacidade real:

| Ação | Comportamento proposto |
| --- | --- |
| Ouvir | Reproduzir essa versão online ou um arquivo local já disponível, quando o modo for suportado e utilizável. Não dispara um download nem adiciona arquivo à biblioteca. |
| Ouvir prévia | Reproduzir um trecho disponibilizado pela fonte, identificado como prévia e com duração real. Não substitui a versão completa nem altera sua correspondência. |
| Abrir referência | Abrir a página pública da candidata exata no serviço/navegador. Expor também a opção de copiar o link. Usar o ID específico, não uma página de busca genérica. |
| Usar esta versão | Registrar a decisão sobre a candidata selecionada. É uma ação explícita e distinta da escuta; não inicia o download. Videoclipes sugeridos automaticamente continuam exigindo a aprovação da versão específica. |

Quando não houver reprodução interna disponível, mostrar Abrir referência como ação útil, em vez de um botão Ouvir permanentemente cinza. Um erro de escuta oferece a referência pública e não invalida automaticamente a candidata. Uma faixa pode ser organizável, consultável ou reproduzível sem estar pronta para download. Estados de reprodução nunca devem alterar seleção de download, prioridade, fonte manual ou autorização de videoclipe.

O link original da ocorrência e o link de cada candidata têm papéis separados e devem permanecer identificáveis. Abrir/escutar uma candidata não substitui o original; só Usar esta versão muda a correspondência. Referências são URLs públicas canônicas; URLs temporárias de streaming, tokens e cookies não são links de referência. Vínculos de referência não comprovam equivalência entre gravações.

Situação atual inspecionada: `Candidate.pageUrl` já identifica a página da candidata e `previewUrl` existe no modelo. A conferência ainda não apresenta uma ação de referência por candidata e não há player integrado. Este documento registra o comportamento pretendido, não uma implementação entregue.

Viabilidade pesquisada nas fontes dos provedores: o [YouTube IFrame Player](https://developers.google.com/youtube/iframe_api_reference) oferece reprodução incorporada, mas a incorporação pode ser bloqueada por vídeo e requer integração/validação em cada plataforma. O [Spotify Web Playback SDK](https://developer.spotify.com/documentation/web-playback-sdk/reference) é uma integração de navegador e exige Spotify Premium; a conexão de importação existente não comprova reprodução. Prévias são opcionais e dependem da fonte e versão consultadas. Nenhuma destas capacidades foi validada dentro do D.d nesta etapa.

## Separação necessária da fila de downloads

Hoje `tracks` reúne a ocorrência da coleção, a fonte, o caminho e o estado da transferência; `editing_locked` bloqueia nomes e IDs depois do início. O pedido posterior aplicado na versão local 0.1.31 libera o arraste de ocorrências ainda não iniciadas, mantendo a posição das já iniciadas. Essa exceção não implementa uma organização da biblioteca independente da execução ou dos arquivos.

Na evolução proposta, separar referências da biblioteca, arquivos e pastas locais, ocorrências em playlists, execução de downloads e fila de reprodução. Uma ocorrência pode referenciar uma música com fontes de catálogo e arquivos locais associados, sem exigir download repetido. Remover da playlist não exclui o arquivo. Exclusão física é uma ação distinta e informa as referências afetadas.

A execução iniciada preserva a versão, posição e nomes utilizados no download. A biblioteca ganha sua própria organização editável; mudanças nela não renomeiam trabalhos em andamento nem alteram retroativamente arquivos, histórico ou M3U8 já produzida. Exportar a organização atual é uma nova ação. O bloqueio antigo não deve ser simplesmente retirado do editor que serve ao download; esta separação ainda requer implementação e migração testada.

Módulos com interfaces pequenas para biblioteca/organização, gestão de pastas/arquivos e reprodução. Widgets apresentam estado e despacham ações; não fazem SQL, leitura de arquivos ou execução de processos. Modelos e regras compartilhados em Dart, com integrações nativas por plataforma. Não expandir indefinidamente o `LibraryController`.

## Personalização e efeitos nos arquivos

Nome, capa e ordem da playlist pertencem à organização no app. Renomear uma playlist e renomear sua pasta são ações com alcances diferentes: a interface deve deixar claro quando o caminho físico será alterado. A versão 0.1.26 preserva o nome da pasta ao renomear a coleção; mudar isso exige uma operação própria, com atualização consistente das referências.

Para reorganização física, preparar a operação, mostrar o destino e os arquivos afetados e lidar com colisões de nomes, arquivos em reprodução, indisponibilidade, permissão negada e interrupção. Copiar preserva o original; mover atualiza todas as referências afetadas. Preservar o áudio e registrar resultados parciais com recuperação. Nenhuma migração move arquivos ou altera suas tags automaticamente. Editor de tags de álbuns de artistas não é parte deste pedido.

## Ordem proposta para os ciclos rápidos

1. Referência pública por candidata para comparação imediata, seguida de reprodução local integrada e escuta/prévia online conforme capacidades reais. Testar que escutar/abrir referência não confirma a versão nem inicia downloads; distinguir prévia de faixa completa. Na reprodução local, testar troca, busca de posição, pausa, fim de faixa, arquivo ausente e navegação.
2. Biblioteca e playlists independentes da execução: reutilizar músicas locais, importar arquivos e combinar seleções com referências de plataformas, mantendo ordem e repetições.
3. Personalização de playlists e pastas associadas: nomes, capas no app, conteúdo e organização; operações físicas próprias para copiar/mover/renomear pastas, com prévia e recuperação.
4. Ampliar as entradas de catálogo e provedores, um por vez, conforme capacidades reais.

Cada etapa deve produzir um ajuste local pequeno, testável pelo usuário, sem releases durante o ciclo. Layout desktop/mobile e regras compartilhadas acompanham cada etapa; validação nativa Windows não comprova Android/iOS.

## Pesquisa inicial de reprodução

Documentação dos mantenedores consultada em 04/11/2026:

- [media_kit](https://pub.dev/packages/media_kit): interface Dart/Flutter para áudio e vídeo, com bibliotecas nativas por plataforma e controles/playlist. Candidato a ensaio local; depende de avaliar empacotamento, formatos e comportamento real em Windows/mobile.
- [just_audio](https://pub.dev/packages/just_audio): controles de áudio e sequenciamento; Windows requer uma implementação adicional.
- [just_audio_windows](https://pub.dev/packages/just_audio_windows): implementação baseada no WinRT MediaPlayer, declara arquivos locais, seek, volume, playlist e shuffle.

Nenhum pacote foi instalado ou validado neste estudo. A escolha depende de um ensaio de reprodução real, licenças, distribuição e suporte nas plataformas do produto. Documentação de um pacote não comprova reprodução no app.
