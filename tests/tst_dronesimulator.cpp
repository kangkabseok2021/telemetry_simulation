#include <QtTest>
#include "waypointmanager.h"

class TestWaypointManager : public QObject {
    Q_OBJECT

private slots:
    void testInterpolationAtStart();
    void testInterpolationMidSegment();
    void testInterpolationAtSegmentEnd();
    void testBatteryDrain();
    void testBatteryNeverExceedsBounds();
    void testTelemetryBounds();
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
        QVERIFY(d.altitude >= 49.0);   // min waypoint alt = 50
        QVERIFY(d.altitude <= 181.0);  // max waypoint alt = 180
        QVERIFY(d.speed >= 29.0);      // min waypoint speed = 30
        QVERIFY(d.speed <= 61.0);      // max waypoint speed = 60
        QVERIFY(d.pitch >= -30.0 && d.pitch <= 30.0);
        QVERIFY(d.roll  >= -30.0 && d.roll  <= 30.0);
        QVERIFY(d.battery >= 0.0 && d.battery <= 100.0);
    }
}

QTEST_MAIN(TestWaypointManager)
#include "tst_dronesimulator.moc"
