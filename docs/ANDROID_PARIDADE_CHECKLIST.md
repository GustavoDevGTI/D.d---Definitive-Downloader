# Paridade completa Android — execução por funcionalidades

Pedido de 05/11/2026: todas as funções já operacionais do app devem funcionar no smartphone. A 0.1.49 é a base técnica; não encerra a implementação mobile. Esta lista é o acompanhamento de execução e será atualizada por evidência, sem marcar telas ou contratos como integrações concluídas.

Estados: **validado** (cenário Android executado), **parcial** (parte implementada ou validação faltante), **pendente** (integração faltante). “Validado” não significa todo aparelho/catálogo.

## 1. Base Android e uso por toque

- [x] Projeto Android, APK versionado, marca, SQLite nativo e cofre — validado no emulador API 36.
- [x] Coleções/Downloads com teclado, telas em pé/deitadas e player interno a Músicas — widgets e rodada nativa.
- [x] Seleção de MP3 pelo sistema, cópia numerada, conservação do original e persistência após reabrir — validado com fixture local.
- [x] Player Android próprio: tocar arquivo local, fila, avançar/voltar, aleatório, repetir faixa/lista e volume — smoke nativo.
- [ ] Validar capas escolhidas por documentos, CSV real, texto ampliado, tablet e gestos de seleção/reordenação no aparelho.
- [ ] Testar todo o editor por toque: títulos, referência/ID, numeração, revisão e posições protegidas, sem depender de Ctrl/F2/clique direito.

## 2. Motor de fontes musicais — prioridade de implementação

- [ ] Criar runtime Android de extração/processamento com executáveis/bibliotecas próprios da plataforma; nenhum EXE Windows.
- [ ] SoundCloud: busca exata, revalidar ID/duração/versão, obter áudio completo público, validar/transcodificar MP3 e incorporar capa/tags.
- [ ] YouTube Music: busca de áudio de catálogo, versões/explícita, revalidação e download.
- [ ] YouTube: links escolhidos manualmente e último recurso de videoclipe com aprovação específica.
- [ ] Deezer: busca/ISRC, conexão de sessão local/cofre, obtenção, transformação em blocos, validação e metadados.
- [ ] Preservar referência original, origem efetiva, tentativas por provedor e mensagens sanitizadas em todos os adaptadores.
- [ ] Fonte indisponível/DRM/prévia nunca pode produzir conclusão simulada; ouvir não confirma nem baixa.

## 3. Fila completa e integridade de arquivos

- [ ] Downloads de MP3 direto no Android, com bytes/tamanho/velocidade/tempo medidos.
- [ ] Iniciar, pausar/limitar, parar, cancelar processo próprio e tentar novamente por ocorrência.
- [ ] Extras entram no final durante a execução e são baixados na mesma rodada quando prontos.
- [ ] Reordenar somente slots livres; concluídas fixas; origem/nomes protegidos conforme regras existentes.
- [ ] Recuperar arquivo removido externamente: abrir conferência, exigir fonte e novo clique de download.
- [ ] Duplicatas com escolher existente/recebida e Fazer para todos, exclusão apenas autorizada e diário de recuperação.
- [ ] Publicação atômica, MP3 completo validado, capa/tags, M3U8 ordenada e histórico persistido.
- [ ] Busca, filtros, ordenação, seleção, colunas ajustáveis/reset e listas contínuas com grande volume no dispositivo.

## 4. Contas e importação de todas as origens presentes

- [ ] Spotify PKCE com retorno Android próprio, configuração no cadastro e autenticação/renovação reais.
- [ ] Deezer com campo local mascarado e cofre Android; não ler nem copiar cookies/credenciais Windows.
- [ ] Importar playlists públicas Spotify, Deezer, YouTube, YouTube Music e SoundCloud integralmente, com páginas lidas na importação.
- [ ] Conta Spotify: playlists privadas/colaborativas e sessão restaurada no Android.
- [ ] Nova playlist vazia ou com link opcional; misturar listas/faixas/MP3, mantendo ordem e decisões de duplicatas.
- [ ] Conferência automática, candidata exata antes das alternativas, destaque/filtros, usar versão, informar fonte manual e referência exata.

## 5. Biblioteca, pastas e integração com Android

- [ ] Gestão completa de playlists/grupos/capas e pastas associadas por toque, preservando mídias nas operações apropriadas.
- [ ] Escolher pastas públicas/SD com SAF, exportar mídias/M3U8 e manter permissões persistentes/revogáveis.
- [ ] Abrir pasta/localização e abrir/compartilhar arquivos com URI segura; não confundir pasta privada do app com pasta pública.
- [ ] Receber links/arquivos pelo Compartilhar do Android e escolher a coleção de destino com revisão.
- [ ] Ausência/perda de permissão, SD removido, espaço insuficiente e arquivos externos compartilhados.

## 6. Ciclo de vida e execução em segundo plano

- [ ] Serviço de primeiro plano para trabalho ativo, notificação e controles de fila.
- [ ] Serviço/sessão de mídia, controles na notificação/tela bloqueada e player em segundo plano.
- [ ] Foco de áudio/fones já têm tratamento básico nativo; validar chamadas, desconexões e competição com outro áudio em aparelho físico.
- [ ] Encerrar/rotacionar/reabrir não pode deixar processos, referências nativas ou transferências órfãs.
- [ ] Persistência e reconciliação após encerramento do processo/OS; retomada respeita aprovação manual e estados anteriores.

## 7. Critério de conclusão

Uma função só muda para validada após seu fluxo real no Android, com testes essenciais + focados. A regressão completa fica para impacto amplo suspeito ou release. Contas/provedores reais são ensaios separados, sem segredos em logs. Nada é removido do escopo para tornar o checklist verde.

Transferir entre contas, backup, IA, captura de outras categorias e formatos especiais que ainda são planejados no Windows permanecem no plano de produto; não são capacidades já entregues que possam ser anunciadas como portadas agora.

## Bloco em execução

Primeiro: concluir o checkpoint 0.1.49 e começar o runtime de extração/transcodificação Android, aproveitando biblioteca Android mantida e adaptadores D.d. A implementação do runtime não habilita automaticamente todos os provedores; cada operação preserva as validações existentes e passa por ensaio próprio. Depois, completar contas, armazenamento público e serviços sem interromper as regras compartilhadas.
