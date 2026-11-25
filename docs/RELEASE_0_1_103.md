# Definitive Downloader 0.1.103 — Windows

Corrige dois bloqueios relacionados ao uso de playlists salvas: falha de gravação SQLite e exclusão indisponível durante a conferência.

## Biblioteca gravável

O erro mostrado na importação pertence a SQLITE_CANTOPEN (código primário 14). Foi reproduzida uma biblioteca que continuava legível, mas falhava no INSERT quando seu journal não podia ser criado (código estendido 526, da mesma família 14). A causa exata da restrição no outro computador não foi inspecionada; não se atribui a falha a corrupção, antivírus ou permissões específicas sem evidência.

O Windows passa a usar uma pasta própria em **LOCALAPPDATA/Definitive Downloader/Library**. A biblioteca D.d anterior em Roaming é copiada automaticamente por snapshot consistente, abrindo a origem somente para leitura. O banco antigo permanece intacto. A migração conserva IDs, playlists, faixas, seleção, preferências e histórico; os caminhos dos áudios continuam iguais. Quando não houver biblioteca D.d anterior, mantém a recuperação do formato histórico Trama.

A cópia é validada antes de publicar. O backup inclui dados confirmados ainda no WAL. Um lock serializa aberturas simultâneas; a publicação Windows usa MoveFileExW sem substituir arquivo existente. Não se desabilitam o journal ou a proteção transacional, não se esvazia o banco e não é necessário reimportar as playlists. A seleção de uma pasta temporária inválida, isoladamente, não reproduziu o problema no ensaio inicial.

## Exclusão durante conferência

O menu de gerenciamento também era inteiramente desabilitado enquanto a conferência rodava. Agora é possível escolher **Excluir playlist** nesse estado. Após a confirmação, o app cancela a conferência daquela playlist, aguarda a operação terminar e só então remove seus registros. Conferências de outras playlists continuam; uma playlist ainda na fila de conferência é retirada da fila antes de excluir.

Arquivos baixados e histórico são preservados. Transferências em andamento continuam protegidas. Não se habilitam indiscriminadamente edição de fontes/nomes e outras mutações concorrentes.

## Validação

Os ensaios de importação/exclusão com journal inacessível e de botão de excluir durante conferência foram observados falhando antes da correção e passaram depois. Também passaram snapshot com WAL confirmado, caminho com acento/emoji, aberturas simultâneas e recusa de substituir uma biblioteca local existente. Análise sem problemas; regressão offline com **304 testes Dart aprovados** (3 opcionais ignorados) e **26 testes Python aprovados** (1 ignorado). Sem conta real, banco de outra pessoa ou emulador Android.

Compilação e instalador Windows concluídos; 0.1.103+104 instalada e iniciada localmente. Uma verificação somente leitura comparou IDs, posições, seleção, caminhos dos concluídos e histórico entre a biblioteca anterior e a cópia local, confirmando preservação e integridade. O banco original continua no local anterior. O instalador e SHA-256 acompanham a publicação.

Referências técnicas: [arquivos auxiliares SQLite](https://www.sqlite.org/tempfiles.html), [códigos de erro](https://www.sqlite.org/rescode.html), [API de backup](https://www.sqlite.org/backup.html), [publicação Windows](https://learn.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-movefileexw).
