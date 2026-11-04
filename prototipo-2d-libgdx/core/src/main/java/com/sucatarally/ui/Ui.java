package com.sucatarally.ui;

import com.badlogic.gdx.graphics.Color;
import com.badlogic.gdx.graphics.g2d.BitmapFont;
import com.badlogic.gdx.graphics.g2d.GlyphLayout;
import com.badlogic.gdx.graphics.g2d.SpriteBatch;
import com.badlogic.gdx.graphics.glutils.ShapeRenderer;
import com.badlogic.gdx.math.Rectangle;

/** Interface desenhada à mão (sem skins/imagens): botões e textos. */
public final class Ui {
    public static final Color COIN = Color.valueOf("ffd23f");
    public static final Color COIN_DARK = Color.valueOf("d9a400");
    private static final GlyphLayout LAYOUT = new GlyphLayout();

    private Ui() {
    }

    public static class Button {
        public final Rectangle rect = new Rectangle();
        public String label = "";
        public boolean enabled = true;
        public boolean visible = true;
        public final Color color = new Color(Color.valueOf("3a7d44"));

        public boolean hit(float x, float y) {
            return visible && enabled && rect.contains(x, y);
        }

        public void drawShape(ShapeRenderer s) {
            if (!visible) return;
            s.setColor(enabled ? color : Color.DARK_GRAY);
            s.rect(rect.x, rect.y, rect.width, rect.height);
            s.setColor(0f, 0f, 0f, 0.25f);
            s.rect(rect.x, rect.y, rect.width, 6f);
        }

        public void drawText(SpriteBatch batch, BitmapFont font, float scale) {
            if (!visible) return;
            font.setColor(enabled ? Color.WHITE : Color.LIGHT_GRAY);
            centered(batch, font, label, rect.x + rect.width / 2f, rect.y + rect.height / 2f + 3f, scale);
            font.setColor(Color.WHITE);
        }
    }

    /** Texto centralizado em (cx, cy). */
    public static void centered(SpriteBatch batch, BitmapFont font, String text, float cx, float cy, float scale) {
        font.getData().setScale(scale);
        LAYOUT.setText(font, text);
        font.draw(batch, LAYOUT, cx - LAYOUT.width / 2f, cy + LAYOUT.height / 2f);
    }

    /** Texto alinhado à direita terminando em x. */
    public static void right(SpriteBatch batch, BitmapFont font, String text, float x, float y, float scale) {
        font.getData().setScale(scale);
        LAYOUT.setText(font, text);
        font.draw(batch, LAYOUT, x - LAYOUT.width, y);
    }

    public static void left(SpriteBatch batch, BitmapFont font, String text, float x, float y, float scale) {
        font.getData().setScale(scale);
        font.draw(batch, text, x, y);
    }

    public static void coin(ShapeRenderer s, float x, float y, float r) {
        s.setColor(COIN_DARK);
        s.circle(x, y, r, 16);
        s.setColor(COIN);
        s.circle(x, y, r * 0.75f, 16);
    }
}
