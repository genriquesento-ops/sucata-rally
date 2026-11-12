# Sucata Rally — contexto para o Claude

Jogo de corrida 3D para Android em **Godot 4.7.2 (GDScript)**, inspirado no gênero de "carro que vai mais longe conforme evolui as peças" (original, não é cópia de nenhum jogo). Mapa procedural infinito, controle por arrasto (movimento de "infinito"), carro acelera sozinho até o combustível acabar.

## Sobre o usuário
- Fala **português (Brasil)**: responda e comente o código em português.
- PC com **pouca RAM** (~1–2 GB livres) e **disco C quase cheio**: tudo fica no disco **D**. Evite processos pesados e paralelos.
- Quer publicar no **F-Droid** (versão `foss`, 100% livre) e também ter uma versão **Google Play** (`play`).
- Costuma pedir "ajustar mais" sem detalhar: ofereça opções concretas e mostre screenshots do resultado.

## Montando num computador novo
O projeto foi criado em outro PC. Se os caminhos abaixo não existirem, monte assim (e atualize esta seção):
1. Descompacte o projeto numa pasta (ex.: `D:\sucata-rally`) e abra a sessão do Claude Code nela.
2. Godot 4.7.2: baixe `Godot_v4.7.2-stable_win64.exe.zip` em https://github.com/godotengine/godot/releases/tag/4.7.2-stable
   (confira o SHA512 em `SHA512-SUMS.txt` da mesma página). Para deixar tudo fora do disco C, crie um arquivo vazio
   `._sc_` ao lado do executável (modo autocontido).
3. Só para gerar APK: JDK 17+ (ex.: Eclipse Adoptium 21), Android SDK (platform 36, build-tools 36.1.0) e os export
   templates 4.7.2 (pelo editor: Editor → Gerenciar modelos de exportação, ou o `.tpz` da mesma página de releases).
   Chave de debug: `keytool -genkeypair -keystore debug.keystore -storepass android -alias androiddebugkey -keypass android -keyalg RSA -validity 10000 -dname "CN=Android Debug,O=Android,C=US"`.
4. Rode o `--import` (abaixo) antes do primeiro teste. As pastas `.godot/` e `build/` são geradas de novo.
5. O histórico completo da primeira sessão está em `docs/historico-sessao-1.zip`.

## Onde estão as coisas (no PC original)
- Projeto: `D:\sucata-rally`
- Godot (modo autocontido, templates Android dentro): `D:\Godot\editor\Godot_v4.7.2-stable_win64.exe` (e `..._console.exe` para linha de comando)
- Chave de debug Android: `D:\Godot\debug.keystore` (usuário `androiddebugkey`, senha `android`)
- Android SDK: `%LOCALAPPDATA%\Android\Sdk`; Java 21 em `JAVA_HOME`
- `prototipo-2d-libgdx/` é a primeira versão 2D (libGDX), ignorada pelo Godot (`.gdignore`)
- Git portátil (MinGit 2.56) em `D:\Git\cmd` (no PATH do usuário). Repositório público: https://github.com/genriquesento-ops/sucata-rally (branch `main`, login salvo pelo Git Credential Manager); finais de linha LF (`.gitattributes`).
- `docs/historico-*.zip` (conversas com o Claude) fica fora do git de propósito: é privado.

## Comandos úteis
```
# depois de criar/renomear scripts com class_name, reimportar:
D:\Godot\editor\Godot_v4.7.2-stable_win64_console.exe --headless --path D:\sucata-rally --import

# corrida automática com screenshots (save separado, não mexe no progresso real):
D:\Godot\editor\Godot_v4.7.2-stable_win64_console.exe --path D:\sucata-rally -- --demo=D:/sucata-rally/build/demo

# tour das telas (inicial, garagem, opções, 5 carros, dicas):
... --path D:\sucata-rally -- --demo-ui=D:/sucata-rally/build/demo

# armadilhas: leva o carro até óleo, serra e martelo e fotografa (+ reações de batida/desvio):
... --path D:\sucata-rally -- --demo-traps=D:/sucata-rally/build/traps

# testes: tests/drive_test.gd (física, --headless), trap_test.gd (cada armadilha dá o evento certo, --headless),
#         touch_test.tscn (toque na tela inicial abre a garagem; é cena, rodar sem --script),
#         stability_test.tscn (rabeada/giro do carro em 4 mapas fixos, sem toque; cena),
#         biome_shots.gd, track_shots.gd, look_test.gd, noise_range.gd
... --headless --path D:\sucata-rally --script res://tests/drive_test.gd

# APK (definir antes ANDROID_HOME e GODOT_ANDROID_KEYSTORE_DEBUG_PATH/USER/PASSWORD):
... --headless --path D:\sucata-rally --export-debug "Android FOSS" build/android/sucata-rally-foss.apk
```

## Arquitetura (scripts/)
- `main.gd` troca telas (TitleScreen → Garage → Run) e tem os modos demo.
- Autoloads: `Save` (save.gd: progresso, missões, mapa do dia, opções, dicas vistas), `Platform` (foss/play via `OS.has_feature`), `Sfx` (sound.gd: sons e música sintetizados por código).
- `game_data.gd`: tabelas e balanceamento (peças, estágios, regiões, fórmulas de stats).
- `terrain.gd`: chunks 48 m gerados em thread (WorkerThreadPool); relevo por região (domain warp, ridged, terraços, crateras), umidade, cor de rocha. Altura é função pura de (x, z).
- `track.gd`: trechos de 40 m lidos de **`data/trechos.json`** (perfil de altura, objetos, moedas, dica, regras "depois") e sequenciados com WFC 1D. `placements()` dá a posição determinística dos objetos de um trecho (usada pelo cenário, moedas e piloto automático). Guia dos campos: `docs/trechos.md`.
- `scripts/obstacles/`: **fábrica** (`factory.gd`, registro tipo → script) e um script por elemento da trilha, todos `extends Obstacle`: rampa, pedregulho, boost, óleo/gelo (mesmo script), lava, serra (rola de lado), martelo (pêndulo), barril (rola contra o carro), vento (ventilador em rajadas). Trechos com `regioes` só aparecem naquela região (gelo na Neve, lava no Vulcão, ventania no Deserto, pulos na Lua). Os que se mexem usam `Obstacle.clock` (tempo da corrida), não somam delta. Avisam a corrida com `_emit()` → `Run.on_obstacle()`. Gatilhos são `Area3D` na camada 2 (só o carro).
- `props.gd`: objetos do cenário (grade com sorteio + MultiMesh) e as malhas de tudo (`Props.mesh(nome)`), inclusive dos obstáculos.
- `car.gd` (VehicleBody3D, frente = +Z), `car_model.gd` (visual por estágio + pinturas), `car_showcase.gd`.
- `run.gd`: corrida, manobras/combo, ré automática, boost, dicas, câmera, fim de corrida + missões.
- `hud.gd`, `steer_control.gd` (direção por arrasto), `garage.gd`, `settings_panel.gd`, `title_screen.gd`, `missions.gd`, `pickups.gd`, `effects.gd`, `ui_kit.gd`.
- `achievements.gd` (conquistas sobre `Save.totals`, somados no fim de cada corrida; "t_<tipo>" = armadilhas por tipo, "r_<n>" = chegadas à região n) e `achievements_panel.gd` (tela aberta pelo botão "Conquistas" da garagem).
- Galões em 130, 312, 552, 869, 1287, 1839 m… (`pickups.gd`), sempre na faixa livre do trecho; abaixo de 25% de tanque o HUD avisa a distância até o próximo.

## Lições aprendidas
- Renderizador **Compatibility**: tonemap filmic + ambiente do céu deixam tudo pálido → usar tonemap linear e luz ambiente por cor.
- `engine_force` do VehicleBody3D é em Newtons (≈ massa × aceleração), ao contrário do que sugere a documentação.
- Ruído celular do Godot (RETURN_DISTANCE) vai de 0 a ~1, mediana ~0,45.
- Não nomear métodos `_set`/`_get` (sobrescrevem os virtuais de Object).
- Tipos inferidos de valores Variant (`var x := dict[...]`) dão erro de parse: declarar o tipo.
- Screenshots do demo travam o frame (~140 ms): não confundir com problema de desempenho.
- Teleportar um RigidBody/VehicleBody em movimento: usar `PhysicsServer3D.body_set_state` (só `global_transform` às vezes é desfeito).

## Estado atual e próximos passos
Tudo funcionando no PC (testado por screenshots e logs do demo). **Ainda não testado num celular real.**
Próximos passos sugeridos: gerar APK e testar no celular (desempenho, tamanho dos botões, sons); receita do F-Droid (compilar templates do Godot a partir do código-fonte); git + repositório público com LICENSE (MIT).
