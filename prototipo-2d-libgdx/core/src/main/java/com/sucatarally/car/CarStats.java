package com.sucatarally.car;

import com.sucatarally.SaveData;

/** Números de desempenho do carro, calculados a partir do estágio e dos níveis das peças. */
public final class CarStats {
    public final Tier tier;
    /** Velocidade máxima em m/s. */
    public final float topSpeed;
    /** Multiplicador de torque relativo ao peso do carro (1 = sobe ladeiras moderadas). */
    public final float torqueFactor;
    public final float tireFriction;
    public final float springHz;
    public final float springDamping;
    /** Combustível em segundos de acelerador. */
    public final float fuelCapacity;
    public final float magnetRadius;

    public CarStats(Tier tier, int motor, int tires, int suspension, int tank, int magnet) {
        this.tier = tier;
        int t = tier.ordinal();
        topSpeed = 5f + 0.9f * motor + 1.5f * t;
        torqueFactor = 0.55f + 0.07f * motor + 0.05f * t;
        tireFriction = 0.7f + 0.08f * tires;
        springHz = 3.5f + 0.25f * suspension;
        springDamping = Math.min(0.9f, 0.5f + 0.03f * suspension);
        fuelCapacity = 18f + 5f * tank + 4f * t;
        magnetRadius = 1.2f + 0.6f * magnet;
    }

    public static CarStats from(SaveData s) {
        return new CarStats(s.tier(), s.level(Part.MOTOR), s.level(Part.TIRES),
                s.level(Part.SUSPENSION), s.level(Part.TANK), s.level(Part.MAGNET));
    }
}
