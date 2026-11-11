# 0.1.59+60 — cores das playlists

Em **Músicas → Coleções**, cada playlist recebe uma cor ao ser criada ou importada. O botão **Editar playlist** abre o nome e a opção **Cor da playlist**. A roda aceita clique, toque e arraste. O centro oferece tons claros e a borda, tons escuros. O código hexadecimal permite escolher a cor pelo teclado. Se outra playlist já usar o tom, o seletor pede outra escolha.

Em **Músicas → Downloads**, o fundo suave, a amostra e o nome da playlist identificam a origem da faixa. O botão **Cor** agrupa as linhas por cor e inverte a ordenação a cada clique. A ordenação é da tabela. O botão de reset restaura a exibição padrão.

O schema 17 atribui cores às playlists existentes e guarda a escolha junto aos metadados da coleção. A atualização da cor invalida apenas os registros daquela playlist na lista contínua. As tabelas de faixas e históricos preservam seus dados.

A análise estática passou. A rodada essencial e focada cobriu 130 testes, com novas execuções dos casos de interface e da lista de 10 mil faixas após os ajustes. A edição da playlist passou a 1360, 390 e 320 px. As linhas coloridas foram conferidas a 1100 e 390 px.

A versão foi instalada no Windows e no emulador `Definitive_API_36`. A migração do Windows preservou as duas playlists, as 200 faixas e os dois registros do histórico. A migração do banco vazio do emulador passou, e o botão **Cor** foi aberto em Downloads.

| Pacote local | SHA-256 |
| --- | --- |
| `Definitive-Downloader-0.1.59-Setup-Windows-x64.exe` | `5cbcdf9c053e8ce7bd835b518968180f4321f1631f74a70cb1e712016bd82396` |
| `Definitive-Downloader-0.1.59-Android-teste.apk` | `cbe13b8464d6075f6a63da7783bfde7c3ec486a140fac2f7753016c29701268f` |
