package com.sucatarally.car;

import com.badlogic.gdx.graphics.Color;

/**
 * Estágios de evolução do carro. Cada estágio muda o formato do carro
 * e libera mais 5 níveis para cada peça.
 */
public enum Tier {
    ROLIMA("Carrinho de Rolimã", 2.0f, 0.32f, 0.36f, "c8873a", 0),
    BUGGY("Buggy", 2.3f, 0.38f, 0.46f, "e8c547", 600),
    PICAPE("Picape", 2.7f, 0.48f, 0.50f, "3f8fd2", 3000),
    MONSTRO("Monstro", 2.8f, 0.52f, 0.72f, "8c3fd2", 10000),
    FOGUETE("Foguete", 3.2f, 0.42f, 0.55f, "e04848", 30000);

    public final String title;
    /** Medidas em metros. */
    public final float chassisW, chassisH, wheelR;
    public final Color color;
    /** Moedas para evoluir PARA este estágio. */
    public final int evolveCost;

    Tier(String title, float chassisW, float chassisH, float wheelR, String hex, int evolveCost) {
        this.title = title;
        this.chassisW = chassisW;
        this.chassisH = chassisH;
        this.wheelR = wheelR;
        this.color = Color.valueOf(hex);
        this.evolveCost = evolveCost;
    }

    public int levelCap() {
        return 5 * (ordinal() + 1);
    }

    public Tier next() {
        return ordinal() + 1 < values().length ? values()[ordinal() + 1] : null;
    }

    // Posições relativas ao centro do chassi, compartilhadas pela física e pelo desenho.

    public float wheelOffsetX() {
        return chassisW * 0.36f;
    }

    public float wheelOffsetY() {
        return -chassisH / 2f - wheelR * 0.35f;
    }

    public float cabinOffsetX() {
        return -chassisW * 0.08f;
    }

    public float cabinW() {
        return chassisW * 0.4f;
    }

    public float cabinH() {
        return 0.5f;
    }

    public float headOffsetY() {
        return chassisH / 2f + cabinH() + 0.12f;
    }

    public static final float HEAD_RADIUS = 0.25f;
}
