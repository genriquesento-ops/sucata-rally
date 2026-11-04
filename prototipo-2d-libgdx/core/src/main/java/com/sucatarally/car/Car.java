package com.sucatarally.car;

import com.badlogic.gdx.graphics.glutils.ShapeRenderer;
import com.badlogic.gdx.math.MathUtils;
import com.badlogic.gdx.math.Vector2;
import com.badlogic.gdx.physics.box2d.Body;
import com.badlogic.gdx.physics.box2d.BodyDef;
import com.badlogic.gdx.physics.box2d.CircleShape;
import com.badlogic.gdx.physics.box2d.FixtureDef;
import com.badlogic.gdx.physics.box2d.MassData;
import com.badlogic.gdx.physics.box2d.PolygonShape;
import com.badlogic.gdx.physics.box2d.Shape;
import com.badlogic.gdx.physics.box2d.World;
import com.badlogic.gdx.physics.box2d.joints.WheelJoint;
import com.badlogic.gdx.physics.box2d.joints.WheelJointDef;

/**
 * Carro físico: um chassi e duas rodas presas por WheelJoints (molas + motor).
 * A cabeça do piloto é um sensor: se encostar no chão, a corrida acaba.
 */
public class Car {
    public static final String CHASSIS = "chassis", WHEEL = "wheel", HEAD = "head";
    /** Partes do carro não colidem entre si. */
    private static final short GROUP = -1;
    private static final float GRAVITY = 10f;

    public final CarStats stats;
    public final Body chassis, rearWheel, frontWheel;
    private final WheelJoint rearJoint, frontJoint;
    private final float wheelSpeed, maxTorque;

    /** Atualizados pelo ContactListener da GameScreen. */
    public int wheelContacts;
    public boolean headHit;

    public Car(World world, CarStats stats, float x, float groundY) {
        this.stats = stats;
        Tier t = stats.tier;
        float chassisY = groundY - t.wheelOffsetY() + t.wheelR + 0.15f;

        BodyDef bd = new BodyDef();
        bd.type = BodyDef.BodyType.DynamicBody;
        bd.position.set(x, chassisY);
        chassis = world.createBody(bd);

        PolygonShape box = new PolygonShape();
        box.setAsBox(t.chassisW / 2f, t.chassisH / 2f);
        addFixture(chassis, box, 2f, 0.4f, false, CHASSIS);
        box.setAsBox(t.cabinW() / 2f, t.cabinH() / 2f,
                new Vector2(t.cabinOffsetX(), t.chassisH / 2f + t.cabinH() / 2f), 0f);
        addFixture(chassis, box, 0.4f, 0.4f, false, CHASSIS);
        box.dispose();

        CircleShape head = new CircleShape();
        head.setRadius(Tier.HEAD_RADIUS);
        head.setPosition(new Vector2(t.cabinOffsetX(), t.headOffsetY()));
        addFixture(chassis, head, 0f, 0f, true, HEAD);
        head.dispose();

        // centro de massa mais baixo = carro mais difícil de capotar
        MassData md = chassis.getMassData();
        md.center.y -= t.chassisH * 0.6f;
        chassis.setMassData(md);

        rearWheel = createWheel(world, x - t.wheelOffsetX(), chassisY + t.wheelOffsetY());
        frontWheel = createWheel(world, x + t.wheelOffsetX(), chassisY + t.wheelOffsetY());
        rearJoint = createJoint(world, rearWheel);
        frontJoint = createJoint(world, frontWheel);

        float mass = chassis.getMass() + rearWheel.getMass() + frontWheel.getMass();
        maxTorque = mass * GRAVITY * t.wheelR * stats.torqueFactor;
        wheelSpeed = stats.topSpeed / t.wheelR;
    }

    private static void addFixture(Body body, Shape shape, float density, float friction, boolean sensor, String tag) {
        FixtureDef fd = new FixtureDef();
        fd.shape = shape;
        fd.density = density;
        fd.friction = friction;
        fd.isSensor = sensor;
        fd.filter.groupIndex = GROUP;
        body.createFixture(fd).setUserData(tag);
    }

    private Body createWheel(World world, float x, float y) {
        BodyDef bd = new BodyDef();
        bd.type = BodyDef.BodyType.DynamicBody;
        bd.position.set(x, y);
        bd.angularDamping = 0.2f;
        Body wheel = world.createBody(bd);

        CircleShape circle = new CircleShape();
        circle.setRadius(stats.tier.wheelR);
        FixtureDef fd = new FixtureDef();
        fd.shape = circle;
        fd.density = 1f;
        fd.friction = stats.tireFriction;
        fd.restitution = 0.1f;
        fd.filter.groupIndex = GROUP;
        wheel.createFixture(fd).setUserData(WHEEL);
        circle.dispose();
        return wheel;
    }

    private WheelJoint createJoint(World world, Body wheel) {
        WheelJointDef jd = new WheelJointDef();
        jd.initialize(chassis, wheel, wheel.getPosition(), new Vector2(0f, 1f));
        jd.enableMotor = true;
        jd.frequencyHz = stats.springHz;
        jd.dampingRatio = stats.springDamping;
        return (WheelJoint) world.createJoint(jd);
    }

    /** @param throttle 1 = acelera, -1 = freia/ré, 0 = solto. */
    public void drive(float throttle) {
        if (throttle > 0f) {
            setMotor(-wheelSpeed, maxTorque); // girar no sentido horário leva o carro para a direita
        } else if (throttle < 0f) {
            setMotor(wheelSpeed * 0.4f, maxTorque);
        } else {
            setMotor(0f, maxTorque * 0.04f); // leve resistência ao rolar
        }

        // no ar, o acelerador e o freio giram o carro (dá para corrigir o pulo)
        if (wheelContacts == 0 && throttle != 0f && Math.abs(chassis.getAngularVelocity()) < 4f) {
            chassis.applyTorque(throttle * chassis.getInertia() * 7f, true);
        }
    }

    private void setMotor(float speed, float torque) {
        rearJoint.setMotorSpeed(speed);
        rearJoint.setMaxMotorTorque(torque);
        frontJoint.setMotorSpeed(speed);
        frontJoint.setMaxMotorTorque(torque * 0.7f);
    }

    public void draw(ShapeRenderer s) {
        Vector2 c = chassis.getPosition();
        CarRenderer.drawBody(s, stats.tier, c.x, c.y, chassis.getAngle() * MathUtils.radiansToDegrees);
        Vector2 r = rearWheel.getPosition(), f = frontWheel.getPosition();
        CarRenderer.drawWheel(s, stats.tier, r.x, r.y, rearWheel.getAngle());
        CarRenderer.drawWheel(s, stats.tier, f.x, f.y, frontWheel.getAngle());
    }
}
