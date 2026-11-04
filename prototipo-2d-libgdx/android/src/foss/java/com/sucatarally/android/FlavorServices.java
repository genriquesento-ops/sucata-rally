package com.sucatarally.android;

import com.sucatarally.PlatformServices;

/** Versão F-Droid: nada de rastreamento, anúncios ou serviços do Google. */
public class FlavorServices implements PlatformServices {
    @Override
    public String flavorName() {
        return "foss";
    }

    @Override
    public void onRunFinished(int distance, int coins) {
        // nada a fazer: tudo fica salvo só no aparelho
    }
}
