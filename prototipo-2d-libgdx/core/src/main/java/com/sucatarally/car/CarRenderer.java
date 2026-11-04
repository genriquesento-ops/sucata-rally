package com.sucatarally.car;

import com.badlogic.gdx.graphics.Color;
import com.badlogic.gdx.graphics.glutils.ShapeRenderer;
import com.badlogic.gdx.math.MathUtils;

/** Desenha o carro só com formas geométricas (sem imagens), em unidades de metro. */
public final class CarRenderer {
    private static final Color TMP = new Color();
    private static final Color TIRE = Color.valueOf("222222");
    private static final Color RIM = Color.valueOf("9a9a9a");
    private static final Color GLASS = Color.valueOf("bfe3f2");
    private static final Color SKIN = Color.valueOf("f1c27d");
    private static final Color HELMET = Color.valueOf("f5f5f5");
    private static final Color FLAME = Color.valueOf("ffb030");

    private CarRenderer() {
    }

    /** Chassi, cabine e piloto. Precisa estar entre shapes.begin(Filled) e end(). */
    public static void drawBody(ShapeRenderer s, Tier t, float x, float y, float degrees) {
        float w = t.chassisW, h = t.chassisH;

        if (t == Tier.FOGUETE) {
            s.setColor(FLAME);
            part(s, x, y, degrees, -w / 2f - 0.25f, 0f, 0.5f, h * 0.6f);
        }

        s.setColor(GLASS);
        part(s, x, y, degrees, t.cabinOffsetX(), h / 2f + t.cabinH() / 2f, t.cabinW(), t.cabinH());

        float cos = MathUtils.cosDeg(degrees), sin = MathUtils.sinDeg(degrees);
        float hx = t.cabinOffsetX(), hy = t.headOffsetY();
        float headX = x + hx * cos - hy * sin, headY = y + hx * sin + hy * cos;
        s.setColor(SKIN);
        s.circle(headX, headY, Tier.HEAD_RADIUS, 16);
        s.setColor(HELMET);
        s.arc(headX, headY, Tier.HEAD_RADIUS, degrees, 180f, 12);

        s.setColor(t.color);
        part(s, x, y, degrees, 0f, 0f, w, h);
        s.setColor(TMP.set(t.color).mul(0.7f, 0.7f, 0.7f, 1f));
        part(s, x, y, degrees, 0f, -h * 0.3f, w, h * 0.4f);
        if (t.ordinal() >= Tier.PICAPE.ordinal()) {
            s.setColor(Color.WHITE);
            part(s, x, y, degrees, w * 0.15f, h * 0.15f, w * 0.35f, h * 0.15f);
        }
    }

    public static void drawWheel(ShapeRenderer s, Tier t, float x, float y, float radians) {
        float r = t.wheelR;
        s.setColor(TIRE);
        s.circle(x, y, r, 20);
        s.setColor(RIM);
        s.circle(x, y, r * 0.55f, 16);
        s.setColor(TIRE);
        float sx = MathUtils.cos(radians) * r * 0.5f, sy = MathUtils.sin(radians) * r * 0.5f;
        s.rectLine(x - sx, y - sy, x + sx, y + sy, r * 0.16f);
    }

    /** Carro parado (garagem). (x, y) é o centro do chassi. */
    public static void drawPreview(ShapeRenderer s, Tier t, float x, float y, float wheelRadians) {
        drawBody(s, t, x, y, 0f);
        drawWheel(s, t, x - t.wheelOffsetX(), y + t.wheelOffsetY(), wheelRadians);
        drawWheel(s, t, x + t.wheelOffsetX(), y + t.wheelOffsetY(), wheelRadians);
    }

    /** Retângulo deslocado (offX, offY) do centro do chassi, girando junto com ele. */
    private static void part(ShapeRenderer s, float cx, float cy, float degrees, float offX, float offY, float w, float h) {
        float x = cx + offX - w / 2f, y = cy + offY - h / 2f;
        s.rect(x, y, cx - x, cy - y, w, h, 1f, 1f, degrees);
    }
}
