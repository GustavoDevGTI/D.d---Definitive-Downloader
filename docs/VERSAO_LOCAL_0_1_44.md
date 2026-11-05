# SoundCloud integrado — versão local 0.1.44

Pedido de 05/11/2026: desconsiderar a pesquisa de outras plataformas e incorporar SoundCloud à experiência musical existente, após o ensaio real de extração. Releases continuam suspensas; a versão muda ao terminar os ajustes.

## Comportamento

- SoundCloud participa da busca de candidatos após Deezer/YouTube Music e antes da procura de videoclipes. Correspondência automática continua exigindo título, artista, duração, versão e estado explícito/limpo compatíveis. Uploader não é tratado como artista. O limite explícito sobe de 24 para 32 candidatos (até oito por fonte), incluindo a última alternativa de vídeo.
- Indicação de videoclipe no título SoundCloud exige revisão para seleção automática. Um link SoundCloud escolhido explicitamente continua sendo áudio da ocorrência informada, desde que o provedor confirme stream completo e ID; o texto do título não transforma o stream em vídeo.
- Faixas SoundCloud fornecidas por link ou por playlist pública mantêm a versão exata como fonte manual daquela ocorrência. Obtenção pública não exige uma nova conexão de conta e não usa o login do navegador. Prévias, bloqueios e ausência de áudio utilizável ficam pendentes com motivo; não são convertidos em fontes prontas nem trocados por fallback.
- Usuário pode escolher outra versão na conferência explicitamente. Busca, fallback e reinício não substituem uma fonte manual. Downloads já concluídos e segundo download conservam a exigência anterior de revisão manual.
- Fila, extras durante execução, prioridade, progresso, pausa, parada, histórico e M3U8 usam os casos existentes. Fallback de uma fonte automática só considera outra correspondência compatível e tem uma tentativa adicional limitada; fontes manuais ficam fixas. A identificação SoundCloud aparece no nome dos novos arquivos, na fila e na M3U8. Artista vazio não gera um nome fictício no arquivo.
- Arquivos locais continuam prioritários no player. Antes de baixar, SoundCloud oferece “Ouvir no SoundCloud”, abrindo a referência exata, como a escuta externa existente do YouTube Music. Ouvir não confirma correspondência nem inicia transferência. Não foi criado um player web oculto.

## Estrutura e validação da fonte

Domínio/capacidades, entrada, importação, matching, persistência e UI em Dart compartilhado. `soundcloud_catalog.py` separa metadados/busca públicos; `soundcloud_audio.py` coordena obtenção pelo yt-dlp, controles e decodificação. O worker Windows é recompilado e empacotado junto do app; não copiar o motor anterior durante a instalação.

Schema **14** adiciona `source_id` às ocorrências e candidatos. O ID da plataforma é distinto da chave SQLite e da posição. Migração preserva registros/caminhos existentes e atualiza o trigger de revisão para incluir esse campo. O candidato escolhido, a resposta pública da página e o áudio resolvido devem corresponder ao mesmo ID e referência; a duração deve ficar dentro de 2 s. Referências anteriores à integração continuam preservadas, sem reescrever fontes escolhidas.

O adaptador recusa privado, `SNIP`/`BLOCK`, transmissão, protocolos protegidos e formatos marcados como prévia. URLs temporárias e identificadores web de acesso não são persistidos em candidatos ou arquivos de evidência. Requisições são limitadas em tamanho/tempo; sem cookies, netrc, leitura do navegador ou segredo de conta. A origem de mídia deve ser SoundCloud/CDN permitido. A imagem usa arte fornecida pela faixa ou imagem do perfil quando não há arte, sem afirmar que isso seja capa do álbum original.

Transferência limitada a 80 MB, seguida de decodificação integral do recebido, conversão MP3, tags/capa e segunda decodificação. Publicação só após a validação. O arquivo final não é um stream de 30 segundos rotulado como música completa; transcodificação não melhora qualidade. Staging exclusivo e cancelamento pertencem somente ao trabalho iniciado pelo app.

## Verificações

- Worker: **18 testes Python aprovados**, incluindo rejeição de prévia/protocolo protegido/destino alheio, ID trocado antes da transferência, controle de bytes/pausa e resultado sem URLs temporárias.
- Flutter: **186 testes aprovados**, com um ensaio de rede optativo separado (ignorado na suíte determinística). Casos novos verificam ID e fonte manual persistidos, recusa de resposta com outro ID, preservação de arquivo já publicado, pendência de prévia, mudança explícita de fonte, lote/repetição e integridade de migrações. Testes de resposta falsa do motor são contratos, não downloads reais.
- Busca real pelo executável novo: oito candidatos SoundCloud retornados sem conta, incluindo metadados com artista vazio que precisam de revisão automática. Isso não comprova identidade com qualquer faixa solicitada.

Ensaio integrado real Windows pelo Flutter e worker compilado: duas ocorrências de D-D-Dance, ID `30510138`, publicadas como MP3s distintos, com histórico de dois registros e M3U8 preservando repetição/ordem. Registrados 28 eventos de progresso; solicitada pausa inicial e retomada. Terceira transferência cancelada durante pausa: nenhum terceiro MP3 publicado e os concluídos preservados. Sem conta e com SQLite/pasta separados da biblioteca do usuário. O ensaio optativo passou em 34 s.

Dois problemas reais encontrados e corrigidos antes da entrega: o SoundCloud retornou HLS em `playback.media-streaming.soundcloud.cloud`, acrescentado especificamente aos destinos permitidos; e o Windows do ambiente de teste expôs caminhos AppData lógico/físico diferentes entre os processos. A publicação agora compara destinos resolvidos por `resolveSymbolicLinks`, mantendo a proibição de arquivos fora do staging. O teste contratual também verifica recusa de um arquivo externo à pasta temporária. Não houve alteração de TLS ou segurança do Windows.

Quando o motor não está disponível na plataforma, a importação mantém fonte/ID mas fica pendente e não habilita download. Isso não transforma o worker Python em motor mobile.

Identificação incrementada após implementar o conjunto: **0.1.44+45**. Formatação e análise estática finais sem problemas; build Windows Release concluído. Após o último ajuste na regra de título SoundCloud, os 11 testes direcionados de fonte/matching passaram (o ensaio de rede continuou optativo e separado). Inspeção das capturas em 1360 e 390 px, sem novos controles inacessíveis/overflow.

Verificação independente dos dois MP3s reais: 4.933.617 bytes cada, 219.690 ms medidos, uma capa APIC e referência pública da origem confirmados. Os hashes iguais comprovaram o mesmo arquivo de áudio em caminhos distintos; não houve deduplicação das ocorrências. Nenhuma pasta temporária permaneceu após cancelar o terceiro trabalho.

Instalação local concluída e registro Windows confirmado em **0.1.44**. O atalho da Área de Trabalho aponta para o executável instalado. Binários instalados conferidos com o pacote, incluindo o motor recompilado (SHA-256 `1bf6501224b2775f336ee565dfa8ddbea4f8953af929e8f5e3b6e3a5720148e8`). Backup anterior preservado fora do repositório; comparação antes/depois confirmou todos os valores anteriores das sete tabelas verificadas, incluindo 242 ocorrências e 11 registros de histórico, com schema 14 e `quick_check` íntegro. Não foram inseridos ensaios na biblioteca real. A janela instalada foi localizada em execução, mas estava minimizada; a tentativa final de captura não produziu imagem devido à minimização/atividade do usuário. A validação visual em duas larguras descrita acima corresponde às capturas anteriores do pacote de desenvolvimento. Sem publicação de release, tag ou push.

Núcleo e componentes estreitos compartilhados com mobile, mas execução nativa Android/iOS e motor de obtenção mobile continuam sem implementação/validação. A entrega Windows não é comprovação de suporte completo mobile.
