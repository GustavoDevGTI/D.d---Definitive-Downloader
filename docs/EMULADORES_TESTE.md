# Emulador de testes reutilizável — 06/11/2026

Usar um único AVD dedicado para o Downloader: `Definitive_API_36`, porta 5560 (`emulator-5560`). Não criar nomes por versão, data ou rodada de testes; não usar os AVDs da Galeria para testes do D.d.

`./tools/start-test-emulator.ps1` reutiliza a instância existente ou inicia o mesmo AVD sem carregar/salvar snapshots. Não cria AVDs, não usa `-wipe-data` e não apaga aplicativos, contas ou mídia. Se faltar o AVD, restaurar exatamente o nome padrão pelo Device Manager; não criar variantes para contornar uma falha. Se a porta estiver ocupada por outro AVD, falha sem encerrar dispositivos.

`tools/test_android.ps1` chama esse iniciador automaticamente quando o dispositivo é `emulator-5560`. Os wrappers de segundo plano e armazenamento também preparam essa mesma instância antes de verificar sua identidade. Dispositivos explicitamente informados continuam sujeitos às proteções próprias de cada teste.

O iniciador conserva o AVD entre rodadas. Apenas snapshots antigos do próprio AVD são limpos antes de uma inicialização, quando não existe processo dele em execução. Se a instância já estiver aberta, ela é preservada. Logs ficam em `%LOCALAPPDATA%\Android\TestDevices\Downloader`, com nomes fixos para a última inicialização.

## Verificações desta manutenção

- Confirmado o reaproveitamento de `Definitive_API_36` já aberto, sem reinício nem novo processo.
- Configuração alterada para cold boot e gravação automática de snapshots desativada.
- Snapshot antigo de RAM (2,5 GiB) bloqueado pelo processo atual: mantido; será removido pelo iniciador na primeira abertura com o AVD parado.
- Os scripts foram analisados sintaticamente. Esta manutenção das ferramentas não representa execução nem aprovação da suíte do aplicativo.

## Armazenamento local dos AVDs — correção posterior em 06/11/2026

A limpeza de snapshots deixou margem insuficiente na cota corporativa: os arquivos ram.img podem voltar a ser criados mesmo com -no-snapshot. Por isso, os dados dos dois AVDs foram movidos com o avdmanager instalado para `%LOCALAPPDATA%\Android\avd`, área excluída da cota de perfil. A política corporativa não foi alterada.

`ANDROID_AVD_HOME` do usuário aponta para esse local. O iniciador também seleciona explicitamente esse diretório quando encontra o registro do AVD, inclusive quando chamado por aplicativos abertos antes da mudança da variável. Os arquivos .ini em `%USERPROFILE%\.android\avd` permanecem como registros de compatibilidade e apontam para o novo local; não criar cópias dos discos nesse diretório antigo.

Preservar nomes e portas: `Galeria_Codex_Test_36` / 5554 e `Definitive_API_36` / 5560. Reutilizar os dispositivos existentes. Não usar -wipe-data nem criar versões por rodada para resolver falhas.

Verificações: hashes SHA-256 dos discos userdata e sdcard iguais antes/depois da movimentação; backing files QCOW2 resolvidos no novo diretório e sem corrupção indicada pelo qemu-img; ambos os AVDs iniciaram e retornaram sys.boot_completed=1. Os 54 contratos das ferramentas da Galeria passaram, e -List -UnitOnly não abriu outro dispositivo. Não foi executada a suíte funcional dos aplicativos nesta manutenção de armazenamento.

## Caches dos testes fora da cota — 06/11/2026

- AVDs e snapshots: `%LOCALAPPDATA%\Android\avd`.
- Logs dos iniciadores: `%LOCALAPPDATA%\Android\TestDevices`.
- Cache, distribuições e logs globais do Gradle: `%LOCALAPPDATA%\Gradle`, por `GRADLE_USER_HOME`. Os runners Windows definem a variável explicitamente para também atender aplicativos abertos antes dessa configuração.
- O antigo `%USERPROFILE%\.gradle` é somente uma junção de compatibilidade para a área local; não armazena outra cópia do cache.
- As áreas de compilação do Downloader (`DdbAndroid`, `Ddb` e `DefinitiveDownloaderDev`) já estão em `%LOCALAPPDATA%`; os relatórios da Galeria permanecem no projeto na rede Y:, também fora do perfil local.
- Não recriar discos AVD nem caches físicos em `%USERPROFILE%`. Não alterar a política de cota do domínio.
- A pasta `.dd-android-sockets` conserva apenas sockets transitórios de tamanho zero, necessários para contornar a falha de Java/AF_UNIX na área virtualizada do aplicativo. Não mover esses sockets para AppData sem validar a conexão loopback.