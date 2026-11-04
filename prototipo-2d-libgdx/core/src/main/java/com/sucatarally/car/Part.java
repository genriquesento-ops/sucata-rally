package com.sucatarally.car;

/** Peças que o jogador melhora na garagem. */
public enum Part {
    MOTOR("Motor", "Mais velocidade e força", 40),
    TIRES("Pneus", "Mais aderência nas subidas", 30),
    SUSPENSION("Suspensão", "Amortece pulos e buracos", 30),
    TANK("Tanque", "Mais combustível", 35),
    MAGNET("Ímã", "Puxa moedas de longe", 25);

    public final String title;
    public final String description;
    private final int baseCost;

    Part(String title, String description, int baseCost) {
        this.title = title;
        this.description = description;
        this.baseCost = baseCost;
    }

    /** Preço para ir do nível {@code level} para o próximo. */
    public int cost(int level) {
        return Math.round(baseCost * (float) Math.pow(1.38, level));
    }
}
