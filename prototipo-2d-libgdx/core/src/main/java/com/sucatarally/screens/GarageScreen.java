package com.sucatarally.screens;

import com.badlogic.gdx.Gdx;
import com.badlogic.gdx.Input;
import com.badlogic.gdx.ScreenAdapter;
import com.badlogic.gdx.graphics.Color;
import com.badlogic.gdx.graphics.g2d.BitmapFont;
import com.badlogic.gdx.graphics.g2d.SpriteBatch;
import com.badlogic.gdx.graphics.glutils.ShapeRenderer;
import com.badlogic.gdx.math.Matrix4;
import com.badlogic.gdx.math.Vector2;
import com.badlogic.gdx.utils.ScreenUtils;
import com.badlogic.gdx.utils.viewport.ExtendViewport;
import com.badlogic.gdx.utils.viewport.Viewport;
import com.sucatarally.SaveData;
import com.sucatarally.SucataRallyGame;
import com.sucatarally.car.CarRenderer;
import com.sucatarally.car.Part;
import com.sucatarally.car.Tier;
import com.sucatarally.ui.Ui;

/** Garagem: comprar melhorias, evoluir o carro e começar uma corrida. */
public class GarageScreen extends ScreenAdapter {
    private static final Color BG = Color.valueOf("211f29");
    private static final Color PANEL = Color.valueOf("2e2b3a");
    private static final Color SEGMENT_OFF = Color.valueOf("4a4658");
    private static final Color SEGMENT_ON = Color.valueOf("7cc04b");
    private static final float ROW_H = 96f;
    /** Pixels por metro no desenho do carro. */
    private static final float PREVIEW_SCALE = 78f;

    private final SucataRallyGame game;
    private final Viewport hud = new ExtendViewport(1280f, 720f);
    private final Ui.Button[] upgradeButtons = new Ui.Button[Part.values().length];
    private final Ui.Button runButton = new Ui.Button();
    private final Ui.Button evolveButton = new Ui.Button();
    private final Matrix4 previewMatrix = new Matrix4();
    private final Vector2 touch = new Vector2();
    private float time;

    public GarageScreen(SucataRallyGame game) {
        this.game = game;
        for (int i = 0; i < upgradeButtons.length; i++) upgradeButtons[i] = new Ui.Button();
        runButton.label = "CORRER!";
        runButton.color.set(Color.valueOf("d2652d"));
        evolveButton.color.set(Color.valueOf("8c3fd2"));
        Gdx.input.setCatchKey(Input.Keys.BACK, true);
    }

    @Override
    public void resize(int width, int height) {
        hud.update(width, height, true);
        float w = hud.getWorldWidth(), h = hud.getWorldHeight();
        float colX = w * 0.46f;
        for (int i = 0; i < upgradeButtons.length; i++) {
            float rowY = h - 150f - i * ROW_H;
            upgradeButtons[i].rect.set(w - 230f, rowY + 12f, 200f, ROW_H - 28f);
        }
        runButton.rect.set(w - 330f, 24f, 300f, 84f);
        evolveButton.rect.set(40f, 24f, colX - 80f, 84f);
    }

    @Override
    public void render(float delta) {
        time += delta;
        refreshButtons();
        if (handleInput()) return;
        draw();
    }

    private void refreshButtons() {
        SaveData save = game.save;
        int cap = save.tier().levelCap();
        for (Part p : Part.values()) {
            Ui.Button b = upgradeButtons[p.ordinal()];
            int level = save.level(p);
            b.label = level >= cap ? "MÁXIMO" : "Melhorar  " + p.cost(level);
            b.enabled = save.canUpgrade(p);
        }
        Tier next = save.tier().next();
        evolveButton.visible = next != null && save.partsMaxed();
        if (next != null) {
            evolveButton.label = "EVOLUIR: " + next.title + "  (" + next.evolveCost + ")";
            evolveButton.enabled = save.canEvolve();
        }
    }

    /** @return true se trocou de tela. */
    private boolean handleInput() {
        if (Gdx.input.isKeyJustPressed(Input.Keys.BACK) || Gdx.input.isKeyJustPressed(Input.Keys.ESCAPE)) {
            Gdx.app.exit();
            return true;
        }
        if (Gdx.input.isKeyJustPressed(Input.Keys.ENTER) || Gdx.input.isKeyJustPressed(Input.Keys.SPACE)) {
            game.startRun();
            return true;
        }
        if (!Gdx.input.justTouched()) return false;
        hud.unproject(touch.set(Gdx.input.getX(), Gdx.input.getY()));
        if (runButton.hit(touch.x, touch.y)) {
            game.startRun();
            return true;
        }
        if (evolveButton.hit(touch.x, touch.y)) game.save.evolve();
        for (Part p : Part.values()) {
            if (upgradeButtons[p.ordinal()].hit(touch.x, touch.y)) game.save.upgrade(p);
        }
        return false;
    }

    private void draw() {
        ScreenUtils.clear(BG);
        hud.apply();
        float w = hud.getWorldWidth(), h = hud.getWorldHeight();
        float colX = w * 0.46f;
        SaveData save = game.save;
        Tier tier = save.tier();
        ShapeRenderer s = game.shapes;
        SpriteBatch batch = game.batch;
        BitmapFont font = game.font;

        s.setProjectionMatrix(hud.getCamera().combined);
        s.begin(ShapeRenderer.ShapeType.Filled);
        // vitrine do carro
        s.setColor(PANEL);
        s.rect(40f, 130f, colX - 80f, h - 250f);
        s.setColor(SEGMENT_OFF);
        float floorY = 130f + (h - 250f) * 0.32f;
        s.rect(40f, 130f, colX - 80f, floorY - 130f);
        // peças
        int cap = tier.levelCap();
        for (Part p : Part.values()) {
            float rowY = h - 150f - p.ordinal() * ROW_H;
            s.setColor(PANEL);
            s.rect(colX, rowY, w - colX - 20f, ROW_H - 12f);
            float segW = Math.min(26f, (w - colX - 300f) / cap - 4f);
            for (int k = 0; k < cap; k++) {
                s.setColor(k < save.level(p) ? SEGMENT_ON : SEGMENT_OFF);
                s.rect(colX + 20f + k * (segW + 4f), rowY + 16f, segW, 14f);
            }
            upgradeButtons[p.ordinal()].drawShape(s);
        }
        runButton.drawShape(s);
        evolveButton.drawShape(s);
        Ui.coin(s, w - 40f, h - 40f, 18f);
        s.end();

        // carro girando as rodas, desenhado em metros e ampliado
        float wheelBottom = -tier.wheelOffsetY() + tier.wheelR;
        previewMatrix.set(hud.getCamera().combined)
                .translate(colX / 2f, floorY + wheelBottom * PREVIEW_SCALE, 0f)
                .scale(PREVIEW_SCALE, PREVIEW_SCALE, 1f);
        s.setProjectionMatrix(previewMatrix);
        s.begin(ShapeRenderer.ShapeType.Filled);
        CarRenderer.drawPreview(s, tier, 0f, 0f, -time * 3f);
        s.end();

        batch.setProjectionMatrix(hud.getCamera().combined);
        batch.begin();
        Ui.left(batch, font, "SUCATA RALLY", 40f, h - 28f, 3.2f);
        Ui.right(batch, font, String.valueOf(save.coins), w - 70f, h - 26f, 2.4f);
        Ui.centered(batch, font, tier.title, colX / 2f, h - 150f, 2.2f);
        Ui.centered(batch, font, "Estágio " + (tier.ordinal() + 1) + " de " + Tier.values().length
                + "   |   Recorde: " + save.bestDistance + " m", colX / 2f, h - 190f, 1.3f);
        if (!evolveButton.visible && tier.next() != null) {
            Ui.centered(batch, font, "Leve todas as peças ao nível " + cap + " para evoluir", colX / 2f, 66f, 1.3f);
        }
        for (Part p : Part.values()) {
            float rowY = h - 150f - p.ordinal() * ROW_H;
            Ui.left(batch, font, p.title + "   " + save.level(p) + "/" + cap, colX + 20f, rowY + ROW_H - 22f, 1.7f);
            Ui.left(batch, font, p.description, colX + 20f, rowY + ROW_H - 52f, 1.1f);
            upgradeButtons[p.ordinal()].drawText(batch, font, 1.5f);
        }
        runButton.drawText(batch, font, 2.6f);
        evolveButton.drawText(batch, font, 1.5f);
        font.setColor(Color.GRAY);
        Ui.left(batch, font, "versão " + game.services.flavorName(), w - 640f, 50f, 1f);
        font.setColor(Color.WHITE);
        batch.end();
        font.getData().setScale(1f);
    }
}
