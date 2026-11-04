package com.sucatarally.world;

import com.badlogic.gdx.math.MathUtils;

/**
 * Gerador procedural: a altura do chão é uma função pura de x e da semente.
 * Assim qualquer pedaço do mapa pode ser gerado a qualquer momento e sempre encaixa com o vizinho.
 */
public final class TerrainGen {
    /** Comprimento (m) da reta plana no início. */
    private static final float START_FLAT = 15f;

    public final long seed;

    public TerrainGen(long seed) {
        this.seed = seed;
    }

    /** 0 no começo, tende a 1 quanto mais longe: morros maiores e mais irregulares. */
    public static float difficulty(float x) {
        return 1f - (float) Math.exp(-Math.max(0f, x) / 2500f);
    }

    public float height(float x) {
        if (x <= START_FLAT) return 0f;
        float d = difficulty(x);
        float h = noise(x / 70f, 0) * (5f + 16f * d)
                + noise(x / 22f, 1) * (1.2f + 5f * d)
                + noise(x / 7f, 2) * (0.15f + 1.1f * d);
        float blend = Math.min(1f, (x - START_FLAT) / 40f);
        return h * blend;
    }

    /** Silhueta dos morros do fundo (só visual). */
    public float background(float x) {
        return noise(x / 45f, 7) * 5f + noise(x / 15f, 8) * 1.5f;
    }

    /** Value noise 1D suavizado, de -1 a 1. */
    private float noise(float t, int octave) {
        int i = MathUtils.floor(t);
        float f = t - i;
        float u = f * f * (3f - 2f * f);
        return MathUtils.lerp(hash(i, octave), hash(i + 1, octave), u);
    }

    private float hash(int i, int octave) {
        long h = seed + i * 0x9E3779B97F4A7C15L + octave * 0xD1B54A32D192ED03L;
        h = (h ^ (h >>> 30)) * 0xBF58476D1CE4E5B9L;
        h = (h ^ (h >>> 27)) * 0x94D049BB133111EBL;
        h ^= h >>> 31;
        return ((h >>> 40) / (float) (1 << 24)) * 2f - 1f;
    }
}
