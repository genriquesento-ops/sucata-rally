# Como criar trechos e obstáculos

A trilha é uma sequência de trechos de 40 m. Cada **tipo de trecho** está descrito em
`data/trechos.json`, e é possível criar um trecho novo só editando esse arquivo.
A ordem dos trechos é sorteada na largada com **Wave Function Collapse** em 1D, seguindo as
regras `depois` de cada trecho.

## Campos de um trecho

| campo | o que faz | exemplo |
|---|---|---|
| `id` | nome único do trecho | `"oleo"` |
| `peso` | chance no sorteio: `[base, extra]`. O peso é base + extra × dificuldade, e a dificuldade vai de 0 (até 300 m) a 1 (bem longe). | `[0.5, 0.8]` |
| `desde` | não aparece antes desta distância, em metros | `300` |
| `regioes` | só aparece nestas regiões | `["Neve"]` |
| `depois` | ids dos trechos que podem vir logo depois deste | `["reta", "pedras"]` |
| `moedas` | `false` tira a fileira de moedas do chão | `false` |
| `dica` | dica mostrada na primeira vez que o trecho aparece. Os textos ficam em `TIPS`, em `run.gd`. | `"oil"` |
| `altura` | relevo da trilha (veja abaixo) | |
| `faixa_aviso` | pinta de amarelo a trilha entre estes metros | `[11, 15]` |
| `arcos` | arcos de moedas no ar: `x` (deslocamento do centro), `de`, `ate`, `altura` | |
| `objetos` | rampas, pedras, armadilhas... (veja abaixo) | |

### Altura
- `{"onda": {"de": 5, "ate": 35, "periodo": 6, "amplitude": 0.5}}` faz lombadas.
- `{"pontos": [[metro, altura, curva], ...]}` liga os pontos, e a curva de cada pedaço pode ser:
  - `"linear"`, o padrão;
  - `"suave"`;
  - `"acelera"`, que começa reto e empina. É boa para a subida de um salto.

## Campos de um objeto

Um número fixo ou `[mín, máx]`, que é sorteado.

| campo | o que faz |
|---|---|
| `tipo` | qual objeto: `rampa`, `pedregulho`, `boost`, `oleo`, `gelo`, `lava`, `serra`, `martelo`, `barril`, `vento` |
| `z` | posição ao longo do trecho (0 a 40 m) |
| `x` | distância do centro da trilha (negativo = um lado, positivo = outro) |
| `x_escolha` | sorteia um valor desta lista em vez de usar `x` |
| `quantidade` | quantos objetos iguais colocar |
| `chance` | probabilidade de aparecer (0 a 1) |
| `escala` | tamanho |
| `alinhar` | `true` vira o objeto na direção da trilha |
| `girar` | `true` gira o objeto ao acaso |
| `inclinacao` | inclinação para a frente, em graus (rampa: -14) |
| `altura_extra` | metros acima do chão |
| `no_chao` | `true` deita o objeto na inclinação do chão (manchas: óleo, gelo, lava) |
| `amostrar_chao` | `[de, ate]`: mede a altura do chão a cada metro, em z, de `de` a `ate` metros a partir do objeto. É para obstáculos que andam pela trilha seguirem o relevo (barril). |
| `faixa_livre` | `{"faixas": [-3, 0, 3], "folga": 2.4}` sorteia uma faixa que fica sempre livre. Os objetos que cairiam nela são empurrados para o lado. |
| `arco` | arco de moedas depois do objeto: `de`, `ate` (metros a partir dele) e `altura` |
| `params` | ajustes do próprio obstáculo, por exemplo `serra`: `amplitude`, `periodo`; `martelo`: `angulo`, `periodo`; `barril`: `velocidade`; `vento`: `ligado`, `desligado` (segundos); `oleo`/`gelo`: `aderencia`, `segundos`, `giro` |
| `longe` | como o objeto fica na dificuldade máxima (bem longe), misturado conforme a distância: `chance` e `quantidade` passam a ser esse valor, e `params` são multiplicados. Ex.: `{"params": {"periodo": 0.6}}` deixa a serra 40% mais rápida lá longe. |

## Criando um tipo de obstáculo novo (código)

1. Crie um script em `scripts/obstacles/` que comece com `extends Obstacle` e monte o
   obstáculo em `_build()`. Use os ajudantes de `obstacle.gd`: `_mesh`, `_box`, `_cylinder`
   e `_trigger`.
2. Desenhe a malha em `Props._build()` (`props.gd`) com um nome novo.
3. Registre o tipo em `TYPES` de `scripts/obstacles/factory.gd`. É a fábrica, e é só uma linha.
   Um mesmo script pode servir a vários tipos, com `params` padrão diferentes. Exemplo: o
   `gelo` usa o script do óleo, com outra malha e menos derrapagem.
4. Use o tipo num trecho de `data/trechos.json`.

### Regras
- **Movimento:** obstáculos que se mexem calculam a posição pelo `clock`, o tempo desde a
  largada, e não somando `delta`. Assim ficam sincronizados e iguais para todos no mapa do dia.
- **Colisão:** use `StaticBody3D` para o que é parado, `AnimatableBody3D` para o que se mexe e
  empurra o carro, e `Area3D` (via `_trigger`) para gatilhos como óleo e boost. A física do
  Godot calcula as colisões, então não precisa de AABB nem de círculo à mão.
- **Eventos:** para avisar a corrida, use `_emit("evento", dados)`. Os eventos que a corrida
  já entende (em `Run.on_obstacle`) são:
  - `boost`;
  - `near` (passou raspando);
  - `dodge` com `{"text", "coins"}` (desviou);
  - `oil`, `ice`;
  - `lava` com `{"fuel"}` (fração do tanque que queima);
  - `wind`;
  - `hit` (bateu).
