# Versão local 0.1.39 — espaço na identificação da faixa

Pedido de 04/11/2026: aproveitar o vazio ao lado da capa ou centralizar conteúdo no painel da faixa.

Plano visual: manter fundo branco, Manrope, texto `#1E293B`, secundário `#6B7280`, ações `#A01F45` e identidade framboesa. Usar a largura disponível para uma identificação horizontal, sem acrescentar cartões, caixas ou orientações.

```text
Painel com largura suficiente     Painel estreito / texto ampliado
Capa | Música e artista                    Capa
     | Estado de download             Música e artista
Detalhes alinhados                    Estado de download
Ações de escuta centralizadas         Detalhes e ações
```

`TrackIdentity` reúne capa e identificação. A partir de 340 px internos, com escala de texto normal, título/artista/estado ficam ao lado da capa, alinhados ao centro vertical dela. Em menos espaço ou texto ampliado, ficam centralizados abaixo da capa. Títulos continuam quebrando linha, sem truncar informações.

Detalhes têm menor espaçamento vertical e coluna de rótulos limitada a 140 px, liberando largura aos valores. As ações de escuta em Informações ficam centralizadas. Todos os campos, buscas e controles de conferência são preservados, assim como as distinções entre arquivo, correspondência e prévia. Schema 12, sem alterações em playlists, mídia ou download.

Removido o espaçamento inferior genérico das abas somente neste painel e compactado o divisor entre seções. Com largura interna abaixo de 340 px e texto ampliado, rótulos ficam acima dos valores para evitar palavras quebradas em letras isoladas. Os demais usos das abas mantêm o espaçamento anterior.

Versão incrementada após os ajustes para **0.1.39+40**, sem release/tag/push no ciclo local.

Validação: `dart format lib` em 103 arquivos; `flutter analyze --no-pub` sem apontamentos; `flutter test --no-pub` com 172 testes aprovados. Capturas de Informações em 390 px e Conferência em 320 px/texto ampliado foram inspecionadas; a suíte também cobriu 1920, 1360 e 900 px. A imagem estreita levou à correção da quebra excessiva dos rótulos antes da validação final. UI compartilhada em Dart; testes de widgets mobile não equivalem à execução nativa Android/iOS.

Compilação Windows release concluída. 158 arquivos do staging conferidos com os fontes/assets/testes; worker musical preservado. Installer local com SHA-256 registrado, EXE **0.1.39+40**, registro **0.1.39** e hashes da instalação conferidos. Backup anterior preservado; comparativo integral do banco antes/depois idêntico, schema 12 e `quick_check=ok`.

Conferência nativa em 1366 px com Portrait of a Blank Slate: capa e identificação lado a lado, detalhes compactos, ações centralizadas e álbum/ISRC/coleção visíveis sem a rolagem anterior. Nenhum campo removido, download iniciado ou arquivo alterado. App deixado aberto em Informações da faixa. Evidências privadas em `%LOCALAPPDATA%/DefinitiveDownloaderDev/local-version-0.1.39`.
