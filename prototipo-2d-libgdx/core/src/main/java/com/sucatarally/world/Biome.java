package com.sucatarally.world;

import com.badlogic.gdx.graphics.Color;

/** Regiões do mapa. Se repetem em ciclo, mas o terreno fica mais difícil a cada volta. */
public enum Biome {
    CAMPO("Campo", "5a8f3c", "7cc04b", "7ec8f0", "d8f0ff", 0.9f, 10f),
    DESERTO("Deserto", "c9a25a", "e6c378", "f0b46a", "fde6b8", 0.65f, 10f),
    NEVE("Neve", "aebfd0", "ffffff", "6f8fb8", "dfe9f5", 0.35f, 10f),
    VULCAO("Vulcão", "3b2a2a", "e0552b", "2a1414", "8a3a22", 0.85f, 11f),
    LUA("Lua", "6d6d78", "a9a9b5", "05050f", "1d1d38", 0.7f, 4f);

    /** Comprimento de cada região em metros. */
    public static final float LENGTH = 700f;

    public final String title;
    public final Color ground, surface, skyTop, skyBottom, hills;
    public final float friction, gravity;

    Biome(String title, String ground, String surface, String skyTop, String skyBottom, float friction, float gravity) {
        this.title = title;
        this.ground = Color.valueOf(ground);
        this.surface = Color.valueOf(surface);
        this.skyTop = Color.valueOf(skyTop);
        this.skyBottom = Color.valueOf(skyBottom);
        this.hills = new Color(this.skyBottom).lerp(this.ground, 0.45f);
        this.friction = friction;
        this.gravity = gravity;
    }

    public static Biome at(float x) {
        if (x < 0f) return CAMPO;
        return values()[(int) (x / LENGTH) % values().length];
    }
}
