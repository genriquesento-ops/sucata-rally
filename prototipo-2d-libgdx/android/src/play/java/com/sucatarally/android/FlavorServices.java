package com.sucatarally.android;

import com.sucatarally.PlatformServices;

/**
 * Versão Google Play. É aqui que entram integrações proprietárias
 * (placar do Play Games, anúncios opcionais etc.). As dependências delas vão em
 * {@code playImplementation} no android/build.gradle, assim a versão foss nunca as recebe.
 */
public class FlavorServices implements PlatformServices {
    @Override
    public String flavorName() {
        return "play";
    }

    @Override
    public void onRunFinished(int distance, int coins) {
        // TODO: enviar a distância para um placar online
    }
}
