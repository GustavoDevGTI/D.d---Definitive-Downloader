# 0.1.65 — playlists Spotify pelo Trackhop

O D.d consulta o conector **Spotify (web)** do Trackhop em modo de leitura. Ao colar o link, importa as faixas na ordem recebida, inclusive repetições. Se o Trackhop informar um total, o D.d verifica se a quantidade retornada corresponde a ele. A Conferência usa os metadados salvos e o download continua sendo uma ação separada.

## Windows

1. Instale e abra a versão do Trackhop Desktop distribuída pelo projeto. Use o conector **Spotify (web)** disponível nessa edição. A configuração dessa sessão acontece no Trackhop. [Guia do Trackhop Desktop](https://trackhop.org/guide/desktop)
2. No Trackhop, abra **Ferramentas → API** e gere um token. No D.d, abra **Músicas → Coleções → Conexões**, mantenha o endereço local `http://127.0.0.1:8642`, cole o token do Trackhop e clique em **Conectar Trackhop**.
3. Em **Importar por link**, cole o link da playlist Spotify. O D.d só guarda o endereço e o token do Trackhop no cofre do sistema.

O conector do Trackhop usa a interface do player web e pode mudar com o Spotify. O guia do servidor descreve a configuração manual da sessão nas versões em que ela é exigida. [Configuração Spotify (web)](https://trackhop.org/guide/docker#spotify-and-deezer-without-a-key-unofficial)

## Android

- Com um servidor Trackhop configurado, use seu endereço HTTPS e o token em **Conexões**. Depois cole o link no D.d. [API do Trackhop](https://trackhop.org/guide/docker#api)
- No próprio celular, conecte Spotify (web) no Trackhop Android, exporte a playlist em CSV e abra ou compartilhe o arquivo com o D.d. Também é possível selecionar o CSV na tela de Coleções. O Trackhop Bridge publicado verifica a assinatura do aplicativo chamador e não atende chamadas do D.d. [Exportação no Trackhop](https://trackhop.org/guide/export-playlist-csv) · [Interface de conectores](https://trackhop.org/plugins)

## Validação local

- 97 testes essenciais e focados passaram, com três ignorados pelo perfil. O servidor de teste simulou uma playlist de 151 faixas e uma resposta incompleta. O teste de CSV cobriu ordem, repetição, título com vírgula, artista, álbum, duração em milissegundos e ISRC.
- Windows 0.1.65+66 instalado e aberto pelo executável instalado. O atalho da Área de Trabalho aponta para esse executável. APK x86_64 0.1.65+66 instalado no emulador dedicado. A tela de Conexões mostrou o Trackhop e a abertura de um CSV sintético pelo Android chegou ao diálogo de confirmação, cancelado ao final.
- A leitura de playlist com conta Spotify real e a conexão do APK a um servidor Trackhop em HTTPS ainda aguardam teste de ponta a ponta.

| Pacote | Tamanho | SHA-256 |
| --- | ---: | --- |
| Instalador Windows x64 | 79,11 MiB | `6defe559509468b0c39988e7887ae0a4832bcc264fd0ebd9f216958eebf3dc82` |
| APK de teste ARM64 | 65,48 MiB | `02782aef84de4414aebde5cd35922cbc21f9a9ae946df70825fa9bf648ce1273` |
| APK de teste x86_64 | 68,57 MiB | `f054159bfb7f9e527a0999ecc6ef17fe9262b10fc6ee3f12a92da92aaa3689e1` |
