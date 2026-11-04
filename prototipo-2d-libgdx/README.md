# Sucata Rally

Jogo 2D de corrida com física para Android. Você dirige um carro por um mapa procedural infinito, vai o mais longe possível com o combustível que tem, junta moedas e volta para a garagem para melhorar as peças e evoluir o carro.

## Como o jogo funciona

- **Mapa procedural:** cada corrida gera um mapa novo a partir de uma semente aleatória. Os morros ficam maiores e mais irregulares quanto mais longe você vai.
- **Regiões:** o mapa passa por 5 regiões, uma a cada 700 m, e o ciclo se repete: Campo → Deserto → Neve → Vulcão → Lua. Cada região tem atrito próprio, e a Lua tem gravidade baixa.
- **Fim da corrida:** a corrida termina quando acaba o combustível, quando o piloto bate a cabeça no chão (capotou) ou quando o carro fica atolado. Galões de combustível aparecem cada vez mais espaçados.
- **Peças:** Motor, Pneus, Suspensão, Tanque e Ímã. Cada nível custa mais moedas.
- **Evolução:** com todas as peças no nível máximo do estágio atual, você pode evoluir o carro: Carrinho de Rolimã → Buggy → Picape → Monstro → Foguete. Cada evolução muda o carro e libera mais 5 níveis por peça.
- **Controles:** no celular, a metade direita da tela acelera e a esquerda freia ou dá ré. No ar, os mesmos controles giram o carro. No PC, use as setas, WASD ou ESC.

## Estrutura

```
core/     lógica do jogo (Java + libGDX + Box2D), compartilhada por tudo
  car/      carro físico, peças, estágios, desenho
  world/    gerador de terreno, chunks, regiões, moedas/combustível
  screens/  Garagem e Corrida
lwjgl3/   versão desktop (para testar rápido no PC)
android/  versão Android, com duas variantes:
  src/foss/  F-Droid: 100% software livre
  src/play/  Google Play: lugar para serviços proprietários (opcional)
assets/   imagens/sons (compartilhado)
fastlane/ textos da loja (o F-Droid lê daqui)
```

### Por que duas variantes?
O F-Droid compila o app a partir do código-fonte e **proíbe** Google Play Services, Firebase, anúncios e analytics proprietários. Por isso:
- o código comum fica em `core/` e conversa com a plataforma pela interface `PlatformServices`;
- `foss` implementa tudo sem dependências proprietárias;
- `play` pode usar SDKs da Google, desde que declarados como `playImplementation` em `android/build.gradle` e nunca como `implementation`.

## Rodando

O build foi configurado para gastar pouca RAM: 1 GB para o Gradle, sem daemon e com um worker só (veja `gradle.properties`).

```bash
gradlew.bat lwjgl3:run
```

```bash
gradlew.bat android:assembleFossDebug
```

```bash
gradlew.bat android:assemblePlayDebug
```

Os APKs ficam em `android/build/outputs/apk/`. Para instalar no celular, ative a depuração USB e rode `adb install -r <arquivo.apk>`.

Modo demo (acelera sozinho e salva screenshots numa pasta):

```bash
gradlew.bat lwjgl3:run --args="--demo C:/caminho/da/pasta"
```

Requisitos: JDK 17+ e Android SDK (platform 36, build-tools 36.1.0). O caminho do SDK vai em `local.properties`, que não deve ir para o git.

## Publicando no F-Droid (resumo)

1. Suba o código para um repositório público (GitLab, Codeberg ou GitHub) com o arquivo `LICENSE`.
2. Crie uma tag de versão, por exemplo `v0.1.0`, e aumente `versionCode` e `versionName` em `android/build.gradle` a cada versão.
3. Abra uma "Request For Packaging" ou um merge request em https://gitlab.com/fdroid/fdroiddata usando o rascunho em [`docs/fdroid-metadata.yml`](docs/fdroid-metadata.yml), que já aponta para a variante `foss`.
4. Os textos e capturas da loja ficam em `fastlane/metadata/android/`.

Regras completas: https://f-droid.org/docs/Inclusion_Policy/

## Próximos passos sugeridos
- Sons (motor, moeda, batida) e arte própria em `assets/`, sempre com licença livre (CC0/CC-BY).
- Partículas de poeira e fumaça, e câmera tremendo nas batidas.
- Medalhas por distância e "mapa do dia" com semente fixa.
- Mais peças: nitro, chassi reforçado, para-quedas.
