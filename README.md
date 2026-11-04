# Sucata Rally (3D)

Jogo de corrida 3D com física para Android, feito em **Godot 4.7** (GDScript). Você dirige por um mundo procedural infinito, vai o mais longe possível com o combustível que tem, junta moedas e volta para a garagem para melhorar as peças e evoluir o carro.

## Como o jogo funciona

- **Mapa procedural 3D:** o terreno é gerado em pedaços de 48×48 m ao redor do carro e muda a cada corrida. Uma trilha de terra sinuosa segue em frente (+Z). Fora da trilha o terreno fica mais acidentado, e os morros crescem quanto mais longe você vai.
- **Regiões:** a cada 700 m o mapa muda de região, em ciclo: Campo → Deserto → Neve → Vulcão → Lua. Cada região tem céu, cor e aderência próprios, e a Lua tem gravidade baixa.
- **Fim da corrida:** acaba o combustível, o carro capota, ou você fica 15 s sem avançar. Galões aparecem na trilha, cada vez mais espaçados.
- **Peças:** Motor, Pneus, Suspensão, Tanque, Ímã de moedas e Nitro (boost mais forte; pouso perfeito dá mini-boost).
- **Manobras:** moedas extras por tempo no ar, pouso perfeito e passar raspando por pedras. Manobras encadeadas em até 3 s multiplicam (combo x2, x3…).
- **Missões:** 3 ativas, cada uma cumprida numa única corrida ("dê 3 saltos", "chegue à Neve"…). Ao completar, paga moedas e é trocada por uma mais difícil.
- **Visual e som:** um modelo de carro por estágio, 8 pinturas na garagem, sons e música gerados por código, dicas na primeira corrida e opções de qualidade para celulares fracos.
- **Mapa do dia:** mesma semente para todos no mesmo dia, com recorde próprio do dia.
- **Evolução:** Carrinho de Rolimã → Buggy → Picape → Monstro → Foguete. Cada estágio muda o carro e libera mais 5 níveis por peça.
- **Controles:** o carro acelera sozinho até o combustível acabar; você só dirige. Encoste o dedo em qualquer lugar da tela e arraste para os lados. No zigue-zague (movimento de "infinito"), a direção troca de lado logo que o dedo inverte. No PC, arraste com o mouse ou use as setas/A e D; ESC desiste. No ar, o carro se endireita sozinho.

## Estrutura

```
project.godot        configurações (renderizador Compatibility, paisagem)
export_presets.cfg   duas versões Android: "Android FOSS" e "Android Play"
scenes/main.tscn     cena inicial (só carrega scripts/main.gd)
scripts/
  game_data.gd   tabelas: peças, estágios, regiões e fórmulas (balanceamento aqui)
  save.gd        progresso salvo no aparelho (autoload "Save")
  platform.gd    ponte foss/play (autoload "Platform")
  main.gd        troca Garagem <-> Corrida; modo demo
  garage.gd      tela da garagem (com o carro 3D girando)
  run.gd         a corrida: câmera, combustível, fim de jogo, céu por região
  terrain.gd     terreno procedural em chunks (calculado em thread) + colisão; relevo por
                 região: colinas (Campo), platôs/dunas (Deserto), cristas (Neve, Vulcão),
                 crateras (Lua); distorção de domínio, umidade e cor de rocha nas encostas
  props.gd       árvores, cactos, pinheiros, pedras e cristais (grade com sorteio + MultiMesh),
                 e rampas, pedregulhos e placas de boost da trilha
  track.gd       trechos de 40 m da trilha (reta, lombadas, salto, rampa, pedras, boost)
                 escolhidos com Wave Function Collapse em 1D: regras de quem vem depois de quem
  missions.gd    missões (3 ativas, metas crescem a cada missão concluída)
  sound.gd       sons e música sintetizados por código (autoload "Sfx"), sem arquivos de áudio
  settings_panel.gd  opções: sensibilidade, volumes, vibração, qualidade gráfica, zerar progresso
  title_screen.gd    tela inicial
  car_showcase.gd    carro 3D girando (garagem e tela inicial)
  effects.gd     partículas: poeira, fogo do Foguete, chama do boost, brilho das moedas, neve, cinzas
  pickups.gd     moedas e galões
  car.gd         física do carro (VehicleBody3D)
  car_model.gd   visual do carro feito com formas simples
  hud.gd         HUD (distância, combustível, moedas, tela de fim)
  steer_control.gd  direção livre por arrasto (o "infinito")
tests/
  drive_test.gd  teste de física sem janela (aceleração/freio de cada estágio)
  look_test.gd   compara configurações de luz
  biome_shots.gd fotografa cada região e mede o tempo de geração dos chunks
  noise_range.gd mede a faixa do ruído celular (crateras)
  track_shots.gd confere as regras dos trechos e fotografa um de cada tipo
prototipo-2d-libgdx/  primeira versão 2D (ignorada pelo Godot)
```

Tudo é montado em código, sem cenas complexas no editor. Isso facilita ler, revisar e trocar peças. Para colocar modelos do Blender, troque as funções de `car_model.gd` por cenas `.glb`.

### Versões foss e play
- O código do jogo é o mesmo nas duas. A diferença está no **Custom Features** de cada preset (`foss` ou `play`), lido em `platform.gd` com `OS.has_feature()`.
- Plugins proprietários (Play Games, anúncios) só podem ser ativados no preset **Android Play**. O preset **Android FOSS** não pode ter nada proprietário: é o que vai para o F-Droid.

## Rodando

Godot 4.7.2 está em `D:\Godot\editor\`, em **modo autocontido**: o arquivo `._sc_` ao lado do executável faz o Godot guardar as configurações e os templates em `D:\Godot\editor\editor_data\`, e não no disco C. Abra o editor e importe a pasta deste projeto, ou use a linha de comando:

```bash
D:\Godot\editor\Godot_v4.7.2-stable_win64.exe --path .
```

Modo demo (dirige sozinho, salva screenshots e fecha; usa um save separado):

```bash
D:\Godot\editor\Godot_v4.7.2-stable_win64_console.exe --path . -- --demo=C:/caminho/da/pasta
```

Teste de física sem janela:

```bash
D:\Godot\editor\Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/drive_test.gd
```

### Gerando o APK
Os templates de exportação Android já estão instalados em `D:\Godot\editor\editor_data\export_templates\4.7.2.stable`. Também foi criada uma chave de debug em `D:\Godot\debug.keystore` (usuário `androiddebugkey`, senha `android`). No editor, use **Projeto → Exportar**. Pela linha de comando:

```bash
D:\Godot\editor\Godot_v4.7.2-stable_win64_console.exe --headless --path . --export-debug "Android FOSS" build/android/sucata-rally-foss.apk
```

Para a linha de comando funcionar, defina antes as variáveis `ANDROID_HOME`, `GODOT_ANDROID_KEYSTORE_DEBUG_PATH`, `GODOT_ANDROID_KEYSTORE_DEBUG_USER` e `GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD`. Instale no celular com `adb install -r build/android/sucata-rally-foss.apk`.

## F-Droid com Godot
O F-Droid compila tudo a partir do código-fonte, **inclusive a própria engine**. O APK gerado com os templates oficiais baixados serve para testar e para a Google Play, mas não para o F-Droid. Para publicar lá, a receita do F-Droid precisa:
1. compilar os export templates do Godot 4.7.2 a partir do código-fonte (SCons + Android NDK);
2. exportar o preset **Android FOSS** com esses templates.

Isso é mais trabalhoso que no libGDX, mas é possível. O ideal é preparar e testar essa receita antes de pedir a inclusão. Os textos da loja já estão em `fastlane/metadata/android/pt-BR/`.

## Próximos passos sugeridos
- Testar num celular de verdade (desempenho e tamanho dos botões).
- Sons: motor variando com a velocidade, moeda, batida.
- Árvores, pedras e cactos procedurais por região (com MultiMesh, que é leve).
- Partículas de poeira nas rodas e rastro do Foguete.
- Rampas e pontes na trilha, e um "mapa do dia" com semente fixa.
- Modelos de carro feitos no Blender (`.glb`) no lugar das caixas.
