#include <QtTest>
#include "waypointmanager.h"
#include "dronesimulator.h"

class TestWaypointManager : public QObject {
    Q_OBJECT

private slots:
    void testInterpolationAtStart();
    void testInterpolationMidSegment();
    void testInterpolationAtSegmentEnd();
    void testBatteryDrain();
    void testBatteryNeverExceedsBounds();
    void testTelemetryBounds();
    void testYawMidSegment();
    void testYawHeadingWrap();
};

void TestWaypointManager::testInterpolationAtStart() {
    WaypointManager mgr;
    TelemetryData d = mgr.interpolate(0.0);
    QVERIFY(qAbs(d.latitude  - 37.7749) < 1e-6);
    QVERIFY(qAbs(d.longitude + 122.4194) < 1e-6);
    QVERIFY(qAbs(d.altitude  - 50.0) < 1e-6);
    QCOMPARE(d.battery, 100.0);
}

void TestWaypointManager::testInterpolationMidSegment() {
    WaypointManager mgr;
    // t=3000ms is exactly halfway through the first 6000ms segment
    TelemetryData d = mgr.interpolate(3000.0);
    double midLat = (37.7749 + 37.7900) / 2.0;
    double midAlt = (50.0 + 100.0) / 2.0;
    QVERIFY(qAbs(d.latitude - midLat) < 1e-6);
    QVERIFY(qAbs(d.altitude - midAlt) < 1e-6);
}

void TestWaypointManager::testInterpolationAtSegmentEnd() {
    WaypointManager mgr;
    // t=6000ms is the start of the 2nd segment → position of waypoint[1]
    TelemetryData d = mgr.interpolate(6000.0);
    QVERIFY(qAbs(d.latitude  - 37.7900) < 1e-6);
    QVERIFY(qAbs(d.longitude + 122.3950) < 1e-6);
}

void TestWaypointManager::testBatteryDrain() {
    WaypointManager mgr;
    TelemetryData d0    = mgr.interpolate(0.0);
    TelemetryData d1000 = mgr.interpolate(1000.0);
    TelemetryData d5000 = mgr.interpolate(5000.0);
    QCOMPARE(d0.battery, 100.0);
    QVERIFY(d1000.battery < d0.battery);
    QVERIFY(d5000.battery < d1000.battery);
}

void TestWaypointManager::testBatteryNeverExceedsBounds() {
    WaypointManager mgr;
    // Sample every 1 second for 120 seconds (well past full drain)
    for (int i = 0; i <= 120; ++i) {
        TelemetryData d = mgr.interpolate(static_cast<double>(i) * 1000.0);
        QVERIFY(d.battery >= 0.0);
        QVERIFY(d.battery <= 100.0);
    }
}

void TestWaypointManager::testTelemetryBounds() {
    WaypointManager mgr;
    // Sample 100 points across one full route loop
    for (int i = 0; i <= 100; ++i) {
        double t = (mgr.totalDuration() * i) / 100.0;
        TelemetryData d = mgr.interpolate(t);
        QVERIFY(d.altitude >= 49.999);   // min waypoint alt = 50
        QVERIFY(d.altitude <= 180.001);  // max waypoint alt = 180
        QVERIFY(d.speed >= 29.999);      // min waypoint speed = 30
        QVERIFY(d.speed <= 60.001);      // max waypoint speed = 60
        QVERIFY(d.pitch >= -30.0 && d.pitch <= 30.0);
        QVERIFY(d.roll  >= -30.0 && d.roll  <= 30.0);
        QVERIFY(d.battery >= 0.0 && d.battery <= 100.0);
    }
}

void TestWaypointManager::testYawMidSegment() {
    WaypointManager mgr;
    // Segment 0→1: heading 45° → 30°, midpoint at t=3000ms
    TelemetryData d = mgr.interpolate(3000.0);
    QVERIFY(qAbs(d.yaw - 37.5) < 1e-6);
}

void TestWaypointManager::testYawHeadingWrap() {
    WaypointManager mgr;
    // Segment 2→3: heading 10° → 350°, shortest arc is -20° (left turn near north)
    // Midpoint at t=15000ms → expected yaw ≈ 0° (or 360°, which after normalization is ~0)
    // After fix: yaw should be near north (~0°), NOT near south (~180°)
    TelemetryData d = mgr.interpolate(15000.0);
    // yaw should be in the north quadrant, not the south quadrant
    QVERIFY(d.yaw < 45.0 || d.yaw > 315.0);

    // At t=18000ms (end of seg 2→3): heading goes from 10° to 350°, shortest arc = -20°
    // result should be 350° (normalized), NOT -10°
    TelemetryData dEnd = mgr.interpolate(18000.0);
    QVERIFY(dEnd.yaw >= 0.0);   // must never be negative
    QVERIFY(dEnd.yaw < 360.0);  // must be in [0, 360)
    QVERIFY(qAbs(dEnd.yaw - 350.0) < 1e-6);  // should be exactly 350°
}

class TestDroneSimulator : public QObject {
    Q_OBJECT

private slots:
    void testStartSetsIsRunning();
    void testStopClearsIsRunning();
    void testEmergencyStopsAndSignals();
    void testTelemetryChangedEmittedOnTick();
};

void TestDroneSimulator::testStartSetsIsRunning() {
    DroneSimulator sim;
    QVERIFY(!sim.isRunning());
    sim.start();
    QVERIFY(sim.isRunning());
    sim.stop();
}

void TestDroneSimulator::testStopClearsIsRunning() {
    DroneSimulator sim;
    sim.start();
    QVERIFY(sim.isRunning());
    sim.stop();
    QVERIFY(!sim.isRunning());
}

void TestDroneSimulator::testEmergencyStopsAndSignals() {
    DroneSimulator sim;
    sim.start();
    QVERIFY(sim.isRunning());

    QSignalSpy emergencySpy(&sim, &DroneSimulator::emergencyTriggered);
    QSignalSpy runningSpy(&sim, &DroneSimulator::isRunningChanged);

    sim.triggerEmergency();

    QVERIFY(!sim.isRunning());
    QCOMPARE(emergencySpy.count(), 1);
    QVERIFY(runningSpy.count() >= 1);
    QCOMPARE(sim.speed(), 0.0);
}

void TestDroneSimulator::testTelemetryChangedEmittedOnTick() {
    DroneSimulator sim;
    QSignalSpy spy(&sim, &DroneSimulator::telemetryChanged);

    sim.start();
    // Wait up to 200ms for at least 2 ticks (timer fires every 50ms)
    QTRY_VERIFY_WITH_TIMEOUT(spy.count() >= 2, 200);
    sim.stop();
}

int main(int argc, char *argv[]) {
    QCoreApplication app(argc, argv);
    int status = 0;
    {
        TestWaypointManager t;
        status |= QTest::qExec(&t, argc, argv);
    }
    {
        TestDroneSimulator t;
        status |= QTest::qExec(&t, argc, argv);
    }
    return status;
}
#include "tst_dronesimulator.moc"
