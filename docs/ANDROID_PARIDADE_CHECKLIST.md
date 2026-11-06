# Paridade completa Android — execução por funcionalidades

Pedido de 05/11/2026: todas as funções já operacionais do app devem funcionar no smartphone. A 0.1.49 é a base técnica; não encerra a implementação mobile. Esta lista é o acompanhamento de execução e será atualizada por evidência, sem marcar telas ou contratos como integrações concluídas.

Estados: **validado** (cenário Android executado), **parcial** (parte implementada ou validação faltante), **pendente** (integração faltante). “Validado” não significa todo aparelho/catálogo.

Orientação posterior de 06/11/2026: testes humanos no APK somente depois de implementar a paridade das funções já operacionais no desktop. Até lá, continuar com testes automatizados essenciais/focados e emulador isolado; não pedir login, desbloqueio de sessão ou conferência manual de cada APK. Cadastro externo de OAuth, ensaio de conta real e aparelho físico são evidências distintas, sem marcá-los como aprovados por fixtures.

## 1. Base Android e uso por toque

- [x] Projeto Android, APK versionado, marca, SQLite nativo e cofre — validado no emulador API 36.
- [x] Coleções/Downloads com teclado, telas em pé/deitadas e player interno a Músicas — widgets e rodada nativa.
- [x] Seleção de MP3 pelo sistema, cópia numerada, conservação do original e persistência após reabrir — validado com fixture local.
- [x] Player Android próprio: tocar arquivo local, fila, avançar/voltar, aleatório, repetir faixa/lista e volume — smoke nativo.
- [ ] Validar capas escolhidas por documentos, CSV real, texto ampliado, tablet e gestos de seleção/reordenação no aparelho.
- [ ] Testar todo o editor por toque: títulos, referência/ID, numeração, revisão e posições protegidas, sem depender de Ctrl/F2/clique direito.

## 2. Motor de fontes musicais — prioridade de implementação

- [x] Runtime Android CPython/FFmpeg/QuickJS, módulos portáveis travados por hash, processo/grupo próprios e codecs executados no emulador; nenhum EXE Windows.
- [x] SoundCloud: busca pública nativa, revalidar ID/duração/versão, áudio completo público, MP3 validado, capa/tags. Ensaio real sem conta com duas ocorrências da mesma faixa; não comprova todo catálogo.
- [x] YouTube Music: busca pública e download de áudio de catálogo com revalidação, MP3 completo e capa/tags — LEAP/Sick Sense, 4.801.742 bytes, sem conta. Regras de versão/explícita seguem o domínio; não é cobertura de todo catálogo.
- [ ] YouTube — parcial: núcleo compartilhado de link manual/aprovação implementado no Android; falta ensaio nativo separado de links manuais/videoclipes.
- [ ] Deezer — parcial: busca pública executada no Android e backend portátil dos blocos validado por vetor conhecido. Conexão/cofre/obtenção completos implementados no núcleo, mas ainda sem ensaio de sessão/arquivo real no Android.
- [ ] Preservar referência original, origem efetiva, tentativas por provedor e mensagens sanitizadas em todos os adaptadores.
- [ ] Fonte indisponível/DRM/prévia nunca pode produzir conclusão simulada; ouvir não confirma nem baixa.

## 3. Fila completa e integridade de arquivos

- [x] MP3 direto no Android: fila real com servidor HTTP local de fixture, 65.244 bytes, medições, tags e duração nativa. Não é obtenção de plataforma nem prova de todos os servidores públicos.
- [ ] Iniciar, pausar/limitar, parar e tentar novamente na UI — parcial: fila HTTP e pausa/retomada pelo controlador passaram no Android; SoundCloud teve pausa durante recebimento/cancelamento no processamento, sem grupo próprio restante. Falta rodada dos botões de parada/retry e demais estados no aparelho.
- [x] Extras prontos entram no final e são baixados na mesma execução: teste Android com link direto durante a primeira transferência, seguido de quatro conclusões.
- [x] Reordenar slots livres no Android: durante transferência e após substituição com lacuna; concluída conserva bytes/posição. Falhas/pausa/proteções também têm contratos focados compartilhados; nomes/IDs continuam protegidos.
- [x] Recuperação manual Android: arquivo do teste removido, revisão no primeiro clique, aprovação sem download e novo clique para obter. ID, posição e caminho conservados.
- [ ] Duplicatas — parcial: popup por toque com nova versão/Fazer para todos e exclusão autorizada passou no Android; mídia não substituída ficou idêntica e diário vazio. Manter/cancelar/interrupção contam com testes compartilhados, mas ainda sem rodada nativa separada de todos esses cenários.
- [ ] Publicação/histórico — parcial: cópias SoundCloud e fila HTTP Android tiveram duração/tags, conclusão SQLite e M3U8; reposição manual e preservação do arquivo não substituído também passaram. Falta interrupção/reconciliação de publicação no dispositivo e demais provedores/contas.
- [ ] Busca, filtros, ordenação, seleção, colunas ajustáveis/reset e listas contínuas com grande volume no dispositivo.

## 4. Contas e importação de todas as origens presentes

- [ ] Spotify — parcial: retorno Android próprio e PKCE implementados; origem/state, cofre nativo, restauração, refresh, cancelamento/timeout passaram automaticamente com respostas sintéticas no Android. Falta confirmar cadastro externo do novo redirect e autenticação/renovação reais; não reutiliza callback Windows.
- [ ] Deezer com campo local mascarado e cofre Android; não ler nem copiar cookies/credenciais Windows.
- [ ] Importar playlists públicas Spotify, Deezer, YouTube, YouTube Music e SoundCloud integralmente, com páginas lidas na importação.
- [ ] Conta Spotify: playlists privadas/colaborativas e sessão restaurada no Android.
- [ ] Nova playlist vazia ou com link opcional; misturar listas/faixas/MP3, mantendo ordem e decisões de duplicatas.
- [ ] Conferência automática, candidata exata antes das alternativas, destaque/filtros, usar versão, informar fonte manual e referência exata.

## 5. Biblioteca, pastas e integração com Android

- [ ] Gestão completa de playlists/grupos/capas e pastas associadas por toque, preservando mídias nas operações apropriadas.
- [ ] Pastas públicas/SD — parcial: exportação explícita de cópia MP3/M3U8 via seletor SAF implementada; ensaio automático em pasta Documents pública com hashes e referências relativas. Permissão persistente durante a operação/recuperação. Destino direto de novas transferências em SAF e SD removível ainda pendentes; a cópia exportada é independente da biblioteca.
- [ ] Abrir pasta/localização — parcial: navegador de mídia do app com subir/abrir/compartilhar por FileProvider e exportar cópia. Navegação/exportação passaram no emulador; falta exercício separado do aplicativo receptor para Abrir/Compartilhar e gerenciadores de diferentes fabricantes.
- [x] Receber links e MP3 pelo Compartilhar: intents reais, revisão da coleção, cancelamento sem alterações e MP3 copiado/numerado sem download passaram automaticamente no Android. Caixa relacional limitada conserva recebidos; fluxos de múltiplos arquivos/restauração e duplicatas recebidas continuam com cenários nativos adicionais pendentes.
- [ ] Ausência/perda de permissão, SD removido e espaço insuficiente — pendentes. Arquivo recebido via content URI e proteção de conteúdo público desconhecido passaram: recuperação recusou apagar antes de qualquer exclusão; após remover só a sentinela de teste, limpou os documentos exatos do diário e concluiu a cópia. Não é ensaio de interrupção real do processo/SD.

## 6. Ciclo de vida e execução em segundo plano

- [x] Serviço de primeiro plano para trabalho ativo, notificação e controles de fila: HTTP completou duas ocorrências com Activity encerrada. Pausa/retomada pelo mesmo controlador das notificações passou; timeout e force-stop ainda exigem cenários próprios abaixo.
- [x] Serviço/sessão de mídia e player em segundo plano: MediaPlayer e motor persistem fora da Activity; avanço automático e transportes passaram com Activity encerrada/reaberta. Notificações de mídia e downloads coexistem; testes concedem permissão somente ao pacote isolado.
- [ ] Foco de áudio/fones já têm tratamento básico nativo; validar chamadas, desconexões e competição com outro áudio em aparelho físico.
- [ ] Ciclo de vida — parcial: encerrar/reabrir a Activity duas vezes conservou o mesmo Dart/MediaPlayer/fila e encerrou o serviço ao finalizar. Rotação/force-stop/morte do processo/fones e limites temporais do sistema ainda têm cenários próprios pendentes; não há autorestart de trabalho.
- [ ] Persistência e reconciliação após encerramento do processo/OS; retomada respeita aprovação manual e estados anteriores.

## 7. Critério de conclusão

Uma função só muda para validada após seu fluxo real no Android, com testes essenciais + focados. A regressão completa fica para impacto amplo suspeito ou release. Contas/provedores reais são ensaios separados, sem segredos em logs. Nada é removido do escopo para tornar o checklist verde.

Transferir entre contas, backup, IA, captura de outras categorias e formatos especiais que ainda são planejados no Windows permanecem no plano de produto; não são capacidades já entregues que possam ser anunciadas como portadas agora.

## Bloco em execução

Checkpoints 0.1.49/0.1.50: base e motor Android. Bloco 0.1.51: fila HTTP/MP3, extras/ordem, reposição e substituição. Bloco 0.1.52: contas e segundo plano. Bloco 0.1.53: Compartilhar recebido, navegação de mídia e exportação de cópia pública SAF; ver `VERSAO_LOCAL_0_1_53.md`. Próximos: destino direto SAF/SD, configuração externa de contas, importações públicas por origem e demais cenários de fila/UI/sistema abertos. Testes humanos adiados até a paridade implementada; fixtures não comprovam contas ou todo catálogo.
