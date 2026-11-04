package com.sucatarally;

/**
 * Ponte entre o jogo (core) e cada plataforma/variante.
 * A versão foss implementa tudo como "não faz nada"; a versão play pode ligar serviços da Google.
 */
public interface PlatformServices {
    /** Nome da variante (foss, play, desktop), só para exibir. */
    String flavorName();

    /** Chamado ao fim de cada corrida. */
    void onRunFinished(int distance, int coins);

    PlatformServices DESKTOP = new PlatformServices() {
        @Override
        public String flavorName() {
            return "desktop";
        }

        @Override
        public void onRunFinished(int distance, int coins) {
        }
    };
}
