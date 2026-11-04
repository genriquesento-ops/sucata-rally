package com.sucatarally.world;

import com.badlogic.gdx.math.RandomXS128;
import com.badlogic.gdx.physics.box2d.Body;
import com.badlogic.gdx.physics.box2d.BodyDef;
import com.badlogic.gdx.physics.box2d.ChainShape;
import com.badlogic.gdx.physics.box2d.EdgeShape;
import com.badlogic.gdx.physics.box2d.FixtureDef;
import com.badlogic.gdx.physics.box2d.World;
import com.badlogic.gdx.utils.Array;

/**
 * Mapa infinito dividido em pedaços (chunks). Só os pedaços perto da câmera existem na física:
 * os da frente são criados e os de trás destruídos, então a memória usada fica sempre pequena.
 */
public class Terrain {
    public static final String GROUND = "ground";
    public static final float CHUNK = 32f;
    public static final float STEP = 0.5f;

    public static class Chunk {
        public final int index;
        public final Biome biome;
        /** x0, y0, x1, y1, ... */
        public final float[] points;
        final Body body;

        Chunk(int index, Biome biome, float[] points, Body body) {
            this.index = index;
            this.biome = biome;
            this.points = points;
            this.body = body;
        }
    }

    public final TerrainGen gen;
    public final Array<Chunk> chunks = new Array<>();
    public final Array<Pickup> pickups = new Array<>();
    private final World world;
    private int nextChunk = -1;
    private float nextFuelX = 110f;

    public Terrain(World world, long seed) {
        this.world = world;
        this.gen = new TerrainGen(seed);
        createStartWall();
    }

    /** Garante o mapa gerado até {@code generateToX} e descarta o que ficou antes de {@code keepFromX}. */
    public void update(float keepFromX, float generateToX) {
        while (nextChunk * CHUNK < generateToX) createChunk(nextChunk++);
        while (chunks.size > 1 && (chunks.first().index + 1) * CHUNK < keepFromX) {
            world.destroyBody(chunks.removeIndex(0).body);
        }
        for (int i = pickups.size - 1; i >= 0; i--) {
            Pickup p = pickups.get(i);
            if (p.taken || p.x < keepFromX) pickups.removeIndex(i);
        }
    }

    private void createChunk(int index) {
        float x0 = index * CHUNK;
        int n = (int) (CHUNK / STEP) + 1;
        float[] pts = new float[n * 2];
        for (int i = 0; i < n; i++) {
            float x = x0 + i * STEP;
            pts[i * 2] = x;
            pts[i * 2 + 1] = gen.height(x);
        }
        Biome biome = Biome.at(x0);

        ChainShape shape = new ChainShape();
        shape.createChain(pts);
        Body body = world.createBody(new BodyDef());
        FixtureDef fd = new FixtureDef();
        fd.shape = shape;
        fd.friction = biome.friction;
        body.createFixture(fd).setUserData(GROUND);
        shape.dispose();

        chunks.add(new Chunk(index, biome, pts, body));
        spawnPickups(index, x0);
    }

    private void spawnPickups(int index, float x0) {
        if (index < 1) return;
        RandomXS128 rnd = new RandomXS128(gen.seed * 31L + index);

        // fileira de moedas; valem mais quanto mais longe
        if (rnd.nextFloat() < 0.75f) {
            int count = 4 + rnd.nextInt(5);
            float spacing = 1.3f;
            float start = x0 + 2f + rnd.nextFloat() * (CHUNK - count * spacing - 4f);
            int value = 1 + (int) (x0 / 400f);
            for (int k = 0; k < count; k++) {
                float px = start + k * spacing;
                pickups.add(new Pickup(Pickup.Type.COIN, px, gen.height(px) + 0.9f, value));
            }
        }

        // galões de combustível cada vez mais espaçados
        while (nextFuelX < x0 + CHUNK) {
            if (nextFuelX >= x0) {
                pickups.add(new Pickup(Pickup.Type.FUEL, nextFuelX, gen.height(nextFuelX) + 0.8f, 0));
            }
            nextFuelX += 120f + nextFuelX * 0.07f;
        }
    }

    private void createStartWall() {
        EdgeShape edge = new EdgeShape();
        edge.set(-CHUNK, 0f, -CHUNK, 50f);
        Body wall = world.createBody(new BodyDef());
        wall.createFixture(edge, 0f).setUserData(GROUND);
        edge.dispose();
    }
}
