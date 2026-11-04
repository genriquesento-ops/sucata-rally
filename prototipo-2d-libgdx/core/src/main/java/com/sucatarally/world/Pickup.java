package com.sucatarally.world;

public class Pickup {
    public enum Type { COIN, FUEL }

    public final Type type;
    public final int value;
    public float x, y;
    public boolean taken;

    public Pickup(Type type, float x, float y, int value) {
        this.type = type;
        this.x = x;
        this.y = y;
        this.value = value;
    }
}
