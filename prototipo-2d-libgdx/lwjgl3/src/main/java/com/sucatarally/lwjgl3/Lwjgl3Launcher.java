package com.sucatarally.lwjgl3;

import com.badlogic.gdx.Gdx;
import com.badlogic.gdx.backends.lwjgl3.Lwjgl3Application;
import com.badlogic.gdx.backends.lwjgl3.Lwjgl3ApplicationConfiguration;
import com.badlogic.gdx.graphics.Pixmap;
import com.badlogic.gdx.graphics.PixmapIO;
import com.sucatarally.PlatformServices;
import com.sucatarally.SucataRallyGame;

import java.util.zip.Deflater;

/**
 * Versão desktop, para testar rápido sem celular.
 * Com {@code --demo <pasta>} o jogo acelera sozinho, tira screenshots e fecha.
 */
public class Lwjgl3Launcher {
    public static void main(String[] args) {
        Lwjgl3ApplicationConfiguration config = new Lwjgl3ApplicationConfiguration();
        config.setTitle("Sucata Rally");
        config.setWindowedMode(1280, 720);
        config.useVsync(true);
        config.setForegroundFPS(60);
        boolean demo = args.length >= 2 && args[0].equals("--demo");
        new Lwjgl3Application(demo ? new DemoGame(args[1]) : new SucataRallyGame(PlatformServices.DESKTOP), config);
    }

    private static class DemoGame extends SucataRallyGame {
        private final String outDir;
        private float time;
        private int step;

        DemoGame(String outDir) {
            super(PlatformServices.DESKTOP);
            this.outDir = outDir;
        }

        @Override
        public void render() {
            super.render();
            time += Gdx.graphics.getDeltaTime();
            if (step == 0 && time > 1.5f) {
                capture("1-garagem");
                startRun().autoDrive = true;
            } else if (step == 1 && time > 6f) {
                capture("2-corrida");
            } else if (step == 2 && time > 14f) {
                capture("3-corrida");
            } else if (step == 3 && time > 30f) {
                capture("4-final");
                Gdx.app.exit();
            }
        }

        private void capture(String name) {
            int w = Gdx.graphics.getBackBufferWidth(), h = Gdx.graphics.getBackBufferHeight();
            Pixmap pixmap = Pixmap.createFromFrameBuffer(0, 0, w, h);
            PixmapIO.writePNG(Gdx.files.absolute(outDir + "/" + name + ".png"), pixmap, Deflater.DEFAULT_COMPRESSION, true);
            pixmap.dispose();
            step++;
        }
    }
}
