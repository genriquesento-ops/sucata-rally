package com.sucatarally;

import com.badlogic.gdx.Gdx;
import com.badlogic.gdx.Preferences;
import com.sucatarally.car.Part;
import com.sucatarally.car.Tier;

/** Progresso do jogador, salvo localmente no aparelho. */
public class SaveData {
    private final Preferences prefs = Gdx.app.getPreferences("sucata-rally");

    public int coins;
    public int bestDistance;
    private int tier;
    private final int[] levels = new int[Part.values().length];

    public SaveData() {
        coins = prefs.getInteger("coins", 0);
        bestDistance = prefs.getInteger("best", 0);
        tier = prefs.getInteger("tier", 0);
        for (Part p : Part.values()) levels[p.ordinal()] = prefs.getInteger("lvl_" + p.name(), 0);
    }

    public Tier tier() {
        return Tier.values()[tier];
    }

    public int level(Part part) {
        return levels[part.ordinal()];
    }

    public boolean canUpgrade(Part part) {
        return level(part) < tier().levelCap() && coins >= part.cost(level(part));
    }

    public void upgrade(Part part) {
        if (!canUpgrade(part)) return;
        coins -= part.cost(level(part));
        levels[part.ordinal()]++;
        persist();
    }

    /** Todas as peças no nível máximo do estágio atual? */
    public boolean partsMaxed() {
        for (Part p : Part.values()) if (level(p) < tier().levelCap()) return false;
        return true;
    }

    public boolean canEvolve() {
        Tier next = tier().next();
        return next != null && partsMaxed() && coins >= next.evolveCost;
    }

    public void evolve() {
        if (!canEvolve()) return;
        coins -= tier().next().evolveCost;
        tier++;
        persist();
    }

    public void persist() {
        prefs.putInteger("coins", coins);
        prefs.putInteger("best", bestDistance);
        prefs.putInteger("tier", tier);
        for (Part p : Part.values()) prefs.putInteger("lvl_" + p.name(), level(p));
        prefs.flush();
    }
}
