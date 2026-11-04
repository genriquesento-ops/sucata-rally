package com.sucatarally.screens;

import com.badlogic.gdx.Gdx;
import com.badlogic.gdx.Input;
import com.badlogic.gdx.ScreenAdapter;
import com.badlogic.gdx.graphics.Color;
import com.badlogic.gdx.graphics.GL20;
import com.badlogic.gdx.graphics.OrthographicCamera;
import com.badlogic.gdx.graphics.g2d.BitmapFont;
import com.badlogic.gdx.graphics.g2d.SpriteBatch;
import com.badlogic.gdx.graphics.glutils.ShapeRenderer;
import com.badlogic.gdx.math.MathUtils;
import com.badlogic.gdx.math.Vector2;
import com.badlogic.gdx.physics.box2d.Contact;
import com.badlogic.gdx.physics.box2d.ContactImpulse;
import com.badlogic.gdx.physics.box2d.ContactListener;
import com.badlogic.gdx.physics.box2d.Manifold;
import com.badlogic.gdx.physics.box2d.World;
import com.badlogic.gdx.utils.ScreenUtils;
import com.badlogic.gdx.utils.viewport.ExtendViewport;
import com.badlogic.gdx.utils.viewport.Viewport;
import com.sucatarally.SaveData;
import com.sucatarally.SucataRallyGame;
import com.sucatarally.car.Car;
import com.sucatarally.car.CarStats;
import com.sucatarally.ui.Ui;
import com.sucatarally.world.Biome;
import com.sucatarally.world.Pickup;
import com.sucatarally.world.Terrain;

/** Uma corrida: dirigir o mais longe possível até acabar o combustível ou capotar. */
public class GameScreen extends ScreenAdapter implements ContactListener {
    private static final float PHYSICS_STEP = 1f / 60f;
    private static final float START_X = 4f;
    private static final Color FUEL_RED = Color.valueOf("d23c3c");

    private final SucataRallyGame game;
    private final World world = new World(new Vector2(0f, -10f), true);
    private final Terrain terrain;
    private final Car car;

    private final OrthographicCamera cam = new OrthographicCamera();
    private final Viewport worldView = new ExtendViewport(24f, 13.5f, cam);
    private final Viewport hud = new ExtendViewport(1280f, 720f);
    private final Vector2 tmp = new Vector2();

    private float accumulator;
    private float fuel;
    private float distance;
    private float bestProgressX, stuckTimer, outOfFuelTimer;
    private int runCoins;
    private Biome biome = Biome.CAMPO;
    private float biomeToast = 2.5f;

    /** null enquanto a corrida está rolando. */
    private String endReason;
    private float endTimer;
    private int earned;
    private boolean newRecord;

    /** Acelera sozinho (usado pelo modo demo do desktop). */
    public boolean autoDrive;

    public GameScreen(SucataRallyGame game) {
        this.game = game;
        world.setContactListener(this);
        terrain = new Terrain(world, MathUtils.random.nextLong());
        terrain.update(-Terrain.CHUNK, 80f);

        CarStats stats = CarStats.from(game.save);
        car = new Car(world, stats, START_X, terrain.gen.height(START_X));
        fuel = stats.fuelCapacity;
        bestProgressX = START_X;
        cam.position.set(START_X + 3f, car.chassis.getPosition().y + 1.5f, 0f);
        Gdx.input.setCatchKey(Input.Keys.BACK, true);
    }

    @Override
    public void render(float delta) {
        delta = Math.min(delta, 0.1f);
        if (handleEndInput()) return;
        update(delta);
        draw();
    }

    // ---------------------------------------------------------------- lógica

    private void update(float delta) {
        boolean running = endReason == null;
        float throttle = running ? readThrottle() : 0f;
        if (running) fuel = Math.max(0f, fuel - delta * (0.35f + 0.65f * Math.abs(throttle)));
        car.drive(fuel > 0f ? throttle : 0f);

        Vector2 pos = car.chassis.getPosition();
        Biome b = Biome.at(pos.x);
        if (b != biome) {
            biome = b;
            biomeToast = 2.5f;
            world.setGravity(tmp.set(0f, -b.gravity));
        }
        biomeToast -= delta;

        accumulator += delta;
        while (accumulator >= PHYSICS_STEP) {
            world.step(PHYSICS_STEP, 8, 3);
            accumulator -= PHYSICS_STEP;
        }

        distance = Math.max(distance, car.chassis.getPosition().x - START_X);
        collectPickups(delta);
        if (running) checkEnd(delta);
        else endTimer += delta;

        followCamera(delta);
        float halfW = worldView.getWorldWidth() * cam.zoom / 2f;
        terrain.update(cam.position.x - halfW - 30f, cam.position.x + halfW + 40f);
    }

    private float readThrottle() {
        if (autoDrive) return 1f;
        float t = 0f;
        if (Gdx.input.isKeyPressed(Input.Keys.RIGHT) || Gdx.input.isKeyPressed(Input.Keys.D)
                || Gdx.input.isKeyPressed(Input.Keys.UP) || Gdx.input.isKeyPressed(Input.Keys.W)) t += 1f;
        if (Gdx.input.isKeyPressed(Input.Keys.LEFT) || Gdx.input.isKeyPressed(Input.Keys.A)
                || Gdx.input.isKeyPressed(Input.Keys.DOWN) || Gdx.input.isKeyPressed(Input.Keys.S)) t -= 1f;
        // toque: metade direita da tela acelera, metade esquerda freia
        for (int i = 0; i < 5; i++) {
            if (Gdx.input.isTouched(i)) t += Gdx.input.getX(i) > Gdx.graphics.getWidth() / 2 ? 1f : -1f;
        }
        return MathUtils.clamp(t, -1f, 1f);
    }

    private void collectPickups(float delta) {
        Vector2 c = car.chassis.getPosition();
        float magnet = car.stats.magnetRadius;
        float reach = 0.9f + car.stats.tier.chassisW * 0.25f;
        for (int i = 0; i < terrain.pickups.size; i++) {
            Pickup p = terrain.pickups.get(i);
            if (p.taken) continue;
            float dx = c.x - p.x, dy = c.y - p.y;
            float d = (float) Math.sqrt(dx * dx + dy * dy);
            if (p.type == Pickup.Type.COIN && d < magnet && d > 0.01f) {
                float pull = Math.min(d, delta * 14f);
                p.x += dx / d * pull;
                p.y += dy / d * pull;
            }
            if (d < reach) {
                p.taken = true;
                if (p.type == Pickup.Type.COIN) runCoins += p.value;
                else fuel = car.stats.fuelCapacity;
            }
        }
    }

    private void checkEnd(float delta) {
        if (car.headHit) {
            finish("Capotou!");
            return;
        }
        float speed = car.chassis.getLinearVelocity().len();
        if (fuel <= 0f) {
            outOfFuelTimer = speed < 0.4f ? outOfFuelTimer + delta : 0f;
            if (outOfFuelTimer > 1.2f) {
                finish("Acabou o combustível");
                return;
            }
        }
        float x = car.chassis.getPosition().x;
        if (x > bestProgressX + 1f) {
            bestProgressX = x;
            stuckTimer = 0f;
        } else if ((stuckTimer += delta) > 10f) {
            finish("Atolado");
        }
    }

    private void finish(String reason) {
        endReason = reason;
        earned = runCoins + (int) (distance / 5f);
        SaveData save = game.save;
        save.coins += earned;
        newRecord = distance > save.bestDistance;
        if (newRecord) save.bestDistance = (int) distance;
        save.persist();
        game.services.onRunFinished((int) distance, earned);
    }

    /** @return true se trocou de tela (não continuar o frame). */
    private boolean handleEndInput() {
        boolean back = Gdx.input.isKeyJustPressed(Input.Keys.BACK) || Gdx.input.isKeyJustPressed(Input.Keys.ESCAPE);
        if (endReason == null) {
            if (back) finish("Desistiu");
            return false;
        }
        boolean confirm = Gdx.input.justTouched() || Gdx.input.isKeyJustPressed(Input.Keys.ENTER)
                || Gdx.input.isKeyJustPressed(Input.Keys.SPACE);
        if (back || (endTimer > 0.8f && confirm)) {
            game.showGarage();
            return true;
        }
        return false;
    }

    private void followCamera(float delta) {
        Vector2 p = car.chassis.getPosition();
        Vector2 v = car.chassis.getLinearVelocity();
        float tx = p.x + 3f + MathUtils.clamp(v.x * 0.3f, -2f, 6f);
        float ty = p.y + 1.5f;
        cam.position.x += (tx - cam.position.x) * Math.min(1f, delta * 5f);
        cam.position.y += (ty - cam.position.y) * Math.min(1f, delta * 3f);
        float targetZoom = 1f + MathUtils.clamp(v.len() / 40f, 0f, 0.6f);
        cam.zoom += (targetZoom - cam.zoom) * Math.min(1f, delta);
        cam.update();
    }

    // ---------------------------------------------------------------- desenho

    private void draw() {
        ScreenUtils.clear(0f, 0f, 0f, 1f);
        worldView.apply();
        ShapeRenderer s = game.shapes;
        s.setProjectionMatrix(cam.combined);
        s.begin(ShapeRenderer.ShapeType.Filled);
        float halfW = worldView.getWorldWidth() * cam.zoom / 2f;
        float halfH = worldView.getWorldHeight() * cam.zoom / 2f;
        float left = cam.position.x - halfW, right = cam.position.x + halfW;
        float bottom = cam.position.y - halfH, top = cam.position.y + halfH;

        drawBackground(s, left, right, bottom, top);
        drawTerrain(s, left, right, bottom);
        drawMarkers(s, left, right);
        drawPickups(s, left, right);
        car.draw(s);
        s.end();

        drawHud();
    }

    private void drawBackground(ShapeRenderer s, float left, float right, float bottom, float top) {
        s.rect(left, bottom, right - left, top - bottom, biome.skyBottom, biome.skyBottom, biome.skyTop, biome.skyTop);
        // morros ao fundo andam mais devagar que a câmera (paralaxe)
        s.setColor(biome.hills);
        float shift = cam.position.x * 0.6f;
        float base = cam.position.y + 0.5f;
        for (float x = MathUtils.floor(left); x < right + 1f; x += 1f) {
            float y1 = base + terrain.gen.background(x - shift);
            float y2 = base + terrain.gen.background(x + 1f - shift);
            s.triangle(x, y1, x + 1f, y2, x, bottom);
            s.triangle(x + 1f, y2, x + 1f, bottom, x, bottom);
        }
    }

    private void drawTerrain(ShapeRenderer s, float left, float right, float bottom) {
        float floor = bottom - 1f;
        for (Terrain.Chunk chunk : terrain.chunks) {
            float[] pts = chunk.points;
            if (pts[pts.length - 2] < left || pts[0] > right) continue;
            for (int i = 0; i < pts.length - 2; i += 2) {
                float x1 = pts[i], y1 = pts[i + 1], x2 = pts[i + 2], y2 = pts[i + 3];
                if (x2 < left || x1 > right) continue;
                s.setColor(chunk.biome.ground);
                s.triangle(x1, y1, x2, y2, x1, Math.min(floor, y1 - 1f));
                s.triangle(x2, y2, x2, Math.min(floor, y2 - 1f), x1, Math.min(floor, y1 - 1f));
                s.setColor(chunk.biome.surface);
                s.rectLine(x1, y1, x2, y2, 0.3f);
            }
        }
    }

    /** Placas de início de região e bandeira do recorde. */
    private void drawMarkers(ShapeRenderer s, float left, float right) {
        int first = Math.max(1, MathUtils.ceil(left / Biome.LENGTH));
        for (int k = first; k * Biome.LENGTH < right; k++) {
            float x = k * Biome.LENGTH, y = terrain.gen.height(x);
            s.setColor(Color.DARK_GRAY);
            s.rect(x - 0.06f, y, 0.12f, 3f);
            s.setColor(Biome.at(x).surface);
            s.rect(x + 0.06f, y + 2.2f, 1.2f, 0.7f);
        }
        float best = START_X + game.save.bestDistance;
        if (game.save.bestDistance > 0 && best > left && best < right) {
            float y = terrain.gen.height(best);
            s.setColor(Color.WHITE);
            s.rect(best - 0.05f, y, 0.1f, 2.6f);
            s.setColor(FUEL_RED);
            s.triangle(best + 0.05f, y + 2.6f, best + 0.05f, y + 1.9f, best + 0.9f, y + 2.25f);
        }
    }

    private void drawPickups(ShapeRenderer s, float left, float right) {
        for (Pickup p : terrain.pickups) {
            if (p.taken || p.x < left - 1f || p.x > right + 1f) continue;
            if (p.type == Pickup.Type.COIN) {
                Ui.coin(s, p.x, p.y, 0.3f);
            } else {
                s.setColor(FUEL_RED);
                s.rect(p.x - 0.28f, p.y - 0.35f, 0.56f, 0.7f);
                s.setColor(Color.DARK_GRAY);
                s.rect(p.x - 0.1f, p.y + 0.35f, 0.2f, 0.14f);
                s.setColor(Color.WHITE);
                s.rect(p.x - 0.16f, p.y - 0.05f, 0.32f, 0.1f);
            }
        }
    }

    private void drawHud() {
        hud.apply();
        float w = hud.getWorldWidth(), h = hud.getWorldHeight();
        ShapeRenderer s = game.shapes;
        SpriteBatch batch = game.batch;
        BitmapFont font = game.font;
        boolean running = endReason == null;

        Gdx.gl.glEnable(GL20.GL_BLEND);
        s.setProjectionMatrix(hud.getCamera().combined);
        s.begin(ShapeRenderer.ShapeType.Filled);
        float barW = 360f, barH = 26f, barX = w / 2f - barW / 2f, barY = h - 52f;
        float f = fuel / car.stats.fuelCapacity;
        s.setColor(0f, 0f, 0f, 0.45f);
        s.rect(barX - 4f, barY - 4f, barW + 8f, barH + 8f);
        s.setColor(f < 0.25f ? FUEL_RED : f < 0.5f ? Ui.COIN : Color.valueOf("4caf50"));
        s.rect(barX, barY, barW * f, barH);
        Ui.coin(s, w - 40f, h - 38f, 16f);
        if (running) {
            s.setColor(1f, 1f, 1f, 0.14f);
            s.rect(20f, 20f, 200f, 150f);
            s.rect(w - 220f, 20f, 200f, 150f);
        } else {
            s.setColor(0f, 0f, 0f, 0.6f);
            s.rect(0f, 0f, w, h);
        }
        s.end();

        batch.setProjectionMatrix(hud.getCamera().combined);
        batch.begin();
        Ui.left(batch, font, (int) distance + " m", 24f, h - 22f, 2.6f);
        Ui.left(batch, font, "Recorde: " + game.save.bestDistance + " m", 24f, h - 68f, 1.4f);
        Ui.centered(batch, font, "COMBUSTÍVEL", w / 2f, barY + barH / 2f, 1.2f);
        Ui.right(batch, font, String.valueOf(runCoins), w - 66f, h - 22f, 2.2f);
        if (running) {
            Ui.centered(batch, font, "FREIO", 120f, 95f, 1.8f);
            Ui.centered(batch, font, "ACELERAR", w - 120f, 95f, 1.8f);
            if (biomeToast > 0f) {
                font.setColor(1f, 1f, 1f, Math.min(1f, biomeToast));
                Ui.centered(batch, font, biome.title, w / 2f, h * 0.72f, 3.2f);
                font.setColor(Color.WHITE);
            }
        } else {
            Ui.centered(batch, font, endReason, w / 2f, h * 0.72f, 3.4f);
            Ui.centered(batch, font, (int) distance + " m" + (newRecord ? "  -  NOVO RECORDE!" : ""), w / 2f, h * 0.58f, 2.4f);
            Ui.centered(batch, font, "+" + earned + " moedas  (" + runCoins + " coletadas + bônus de distância)", w / 2f, h * 0.48f, 1.6f);
            if (endTimer > 0.8f) Ui.centered(batch, font, "Toque para voltar à garagem", w / 2f, h * 0.3f, 1.6f);
        }
        batch.end();
        font.getData().setScale(1f);
    }

    // ---------------------------------------------------------------- colisões

    @Override
    public void beginContact(Contact contact) {
        Object a = contact.getFixtureA().getUserData(), b = contact.getFixtureB().getUserData();
        if (pair(a, b, Car.HEAD, Terrain.GROUND)) car.headHit = true;
        if (pair(a, b, Car.WHEEL, Terrain.GROUND)) car.wheelContacts++;
    }

    @Override
    public void endContact(Contact contact) {
        Object a = contact.getFixtureA().getUserData(), b = contact.getFixtureB().getUserData();
        if (pair(a, b, Car.WHEEL, Terrain.GROUND)) car.wheelContacts = Math.max(0, car.wheelContacts - 1);
    }

    private static boolean pair(Object a, Object b, String x, String y) {
        return (x.equals(a) && y.equals(b)) || (y.equals(a) && x.equals(b));
    }

    @Override
    public void preSolve(Contact contact, Manifold oldManifold) {
    }

    @Override
    public void postSolve(Contact contact, ContactImpulse impulse) {
    }

    @Override
    public void resize(int width, int height) {
        worldView.update(width, height);
        hud.update(width, height, true);
    }

    @Override
    public void pause() {
        // Android: ao sair do app no meio da corrida, encerra e salva as moedas
        if (endReason == null) finish("Pausado");
    }

    @Override
    public void dispose() {
        world.dispose();
    }
}
