package com.sucatarally;

import com.badlogic.gdx.Game;
import com.badlogic.gdx.Screen;
import com.badlogic.gdx.graphics.Texture;
import com.badlogic.gdx.graphics.g2d.BitmapFont;
import com.badlogic.gdx.graphics.g2d.SpriteBatch;
import com.badlogic.gdx.graphics.glutils.ShapeRenderer;
import com.sucatarally.screens.GameScreen;
import com.sucatarally.screens.GarageScreen;

public class SucataRallyGame extends Game {
    public final PlatformServices services;
    public SaveData save;
    public SpriteBatch batch;
    public ShapeRenderer shapes;
    public BitmapFont font;

    public SucataRallyGame(PlatformServices services) {
        this.services = services;
    }

    @Override
    public void create() {
        save = new SaveData();
        batch = new SpriteBatch();
        shapes = new ShapeRenderer();
        font = new BitmapFont();
        font.getRegion().getTexture().setFilter(Texture.TextureFilter.Linear, Texture.TextureFilter.Linear);
        font.setUseIntegerPositions(false);
        showGarage();
    }

    public void showGarage() {
        switchTo(new GarageScreen(this));
    }

    public GameScreen startRun() {
        GameScreen screen = new GameScreen(this);
        switchTo(screen);
        return screen;
    }

    /** Troca de tela e libera a anterior. Quem chama deve retornar logo em seguida. */
    private void switchTo(Screen next) {
        Screen old = getScreen();
        setScreen(next);
        if (old != null) old.dispose();
    }

    @Override
    public void dispose() {
        super.dispose();
        if (getScreen() != null) getScreen().dispose();
        batch.dispose();
        shapes.dispose();
        font.dispose();
    }
}
