# UAV Telemetry & Simulation Control Station — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Qt 6 / C++17 desktop app that simulates a drone GCS — C++ waypoint engine feeds telemetry to a QML dark-mode dashboard via Q_PROPERTY signals.

**Architecture:** A `WaypointManager` interpolates a hardcoded 8-point route; `DroneSimulator` (QObject singleton) owns a 50ms QTimer, updates telemetry each tick, and exposes all values as Q_PROPERTYs to QML. Five QML components render the data using Canvas-based dials, a GPS track map, numeric readouts, and control buttons.

**Tech Stack:** C++17, Qt 6 (Core / Gui / Qml / Quick / Test), CMake 3.21+, QtTest — targets macOS + Linux.

---

## Spec Gap Fixed in This Plan

The spec's `MapPanel.qml` requires drawing future waypoints, but `DroneSimulator` had no way to expose the planned route to QML. Task 4 adds:
```cpp
Q_PROPERTY(QVariantList plannedRoute READ plannedRoute CONSTANT)
```
`plannedRoute()` returns all waypoints as `[{lat, lon}, ...]` — used by `MapPanel` for the dashed future-route overlay.

---

## File Map

| File | Created/Modified | Responsibility |
|---|---|---|
| `CMakeLists.txt` | Create | App + test build targets |
| `.gitignore` | Create | Ignore build/ and .superpowers/ |
| `src/telemetrydata.h` | Create | `TelemetryData` and `Waypoint` structs |
| `src/waypointmanager.h` | Create | `WaypointManager` class declaration |
| `src/waypointmanager.cpp` | Create | Route definition + interpolation |
| `src/dronesimulator.h` | Create | `DroneSimulator` QObject declaration |
| `src/dronesimulator.cpp` | Create | Timer loop, tick, signals |
| `src/main.cpp` | Create | App entry, singleton registration, QML load |
| `tests/tst_dronesimulator.cpp` | Create | All QtTest cases |
| `qml/ControlBar.qml` | Create | Start/Stop/Emergency buttons |
| `qml/TelemetryReadout.qml` | Create | Numeric cards + altitude sparkline |
| `qml/AttitudeDial.qml` | Create | Artificial horizon + compass canvas |
| `qml/MapPanel.qml` | Create | GPS track canvas |
| `qml/main.qml` | Create | Root window, layout, emergency overlay |
| `README.md` | Create | Build instructions + architecture notes |

---

## Task 1: Project Scaffold

**Files:**
- Create: `CMakeLists.txt`
- Create: `.gitignore`
- Create: `src/` `qml/` `tests/` directories

- [ ] **Step 1: Create directories**

```bash
cd /path/to/telemetry_simulation
mkdir -p src qml tests
```

- [ ] **Step 2: Write `.gitignore`**

```
build/
.superpowers/
*.user
.DS_Store
CMakeUserPresets.json
```

- [ ] **Step 3: Write `CMakeLists.txt`**

```cmake
cmake_minimum_required(VERSION 3.21)
project(telemetry_simulation VERSION 1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 REQUIRED COMPONENTS Core Gui Qml Quick Test)

# ── Main application ──────────────────────────────────────────────
qt_add_executable(telemetry_simulation
    src/main.cpp
    src/dronesimulator.cpp
    src/waypointmanager.cpp
)

qt_add_qml_module(telemetry_simulation
    URI UAV
    VERSION 1.0
    RESOURCE_PREFIX "/"
    QML_FILES
        qml/main.qml
        qml/MapPanel.qml
        qml/AttitudeDial.qml
        qml/TelemetryReadout.qml
        qml/ControlBar.qml
)

target_include_directories(telemetry_simulation PRIVATE src/)
target_link_libraries(telemetry_simulation PRIVATE
    Qt6::Core Qt6::Gui Qt6::Qml Qt6::Quick
)

# ── Unit tests ────────────────────────────────────────────────────
enable_testing()

qt_add_executable(tst_dronesimulator
    tests/tst_dronesimulator.cpp
    src/dronesimulator.cpp
    src/waypointmanager.cpp
)
target_include_directories(tst_dronesimulator PRIVATE src/)
target_link_libraries(tst_dronesimulator PRIVATE Qt6::Core Qt6::Test)
add_test(NAME DroneSimulatorTests COMMAND tst_dronesimulator)
```

- [ ] **Step 4: Create placeholder source files so CMake can configure**

`src/main.cpp`:
```cpp
int main(int, char**) { return 0; }
```

`src/telemetrydata.h`:
```cpp
#pragma once
```

`src/waypointmanager.h`:
```cpp
#pragma once
```

`src/waypointmanager.cpp`:
```cpp
#include "waypointmanager.h"
```

`src/dronesimulator.h`:
```cpp
#pragma once
```

`src/dronesimulator.cpp`:
```cpp
#include "dronesimulator.h"
```

`tests/tst_dronesimulator.cpp`:
```cpp
#include <QtTest>
class Placeholder : public QObject { Q_OBJECT };
QTEST_MAIN(Placeholder)
#include "tst_dronesimulator.moc"
```

`qml/main.qml`, `qml/MapPanel.qml`, `qml/AttitudeDial.qml`, `qml/TelemetryReadout.qml`, `qml/ControlBar.qml` — each containing:
```qml
import QtQuick
Item {}
```

- [ ] **Step 5: Verify CMake configures cleanly**

```bash
cmake -B build -DCMAKE_PREFIX_PATH=/path/to/Qt6
```

Expected: `-- Configuring done` and `-- Build files have been written to: .../build`. No errors.

> **Finding your Qt6 prefix on macOS (Homebrew):** `brew --prefix qt6`  
> **On Linux:** typically `/usr/lib/x86_64-linux-gnu/cmake` — or wherever `Qt6Config.cmake` lives.

- [ ] **Step 6: Commit**

```bash
git add CMakeLists.txt .gitignore src/ qml/ tests/
git commit -m "chore: project scaffold — CMake, dirs, placeholder sources"
```

---

## Task 2: TelemetryData and Waypoint Structs

**Files:**
- Modify: `src/telemetrydata.h`

- [ ] **Step 1: Write `src/telemetrydata.h`**

```cpp
#pragma once

struct TelemetryData {
    double altitude  = 0.0;   // meters
    double speed     = 0.0;   // km/h
    double pitch     = 0.0;   // degrees, +nose-up
    double roll      = 0.0;   // degrees, +right-wing-down
    double yaw       = 0.0;   // degrees, 0–360 clockwise from north
    double battery   = 100.0; // percent
    double latitude  = 0.0;
    double longitude = 0.0;
};

struct Waypoint {
    double latitude;
    double longitude;
    double altitude;   // meters
    double speed;      // km/h at this leg
    double heading;    // degrees, direction to next waypoint
    double duration;   // ms to travel to next waypoint
};
```

- [ ] **Step 2: Verify build still compiles**

```bash
cmake --build build
```

Expected: builds without error.

- [ ] **Step 3: Commit**

```bash
git add src/telemetrydata.h
git commit -m "feat: add TelemetryData and Waypoint structs"
```

---

## Task 3: WaypointManager (TDD)

**Files:**
- Modify: `src/waypointmanager.h`
- Modify: `src/waypointmanager.cpp`
- Modify: `tests/tst_dronesimulator.cpp`

- [ ] **Step 1: Write `src/waypointmanager.h`**

```cpp
#pragma once
#include "telemetrydata.h"
#include <vector>

class WaypointManager {
public:
    WaypointManager();

    TelemetryData interpolate(double elapsedMs) const;
    double totalDuration() const { return m_totalDuration; }
    int waypointCount() const { return static_cast<int>(m_waypoints.size()); }
    const std::vector<Waypoint>& waypoints() const { return m_waypoints; }

private:
    std::vector<Waypoint> m_waypoints;
    double m_totalDuration = 0.0;
};
```

- [ ] **Step 2: Write stub `src/waypointmanager.cpp`** (compiles but returns defaults)

```cpp
#include "waypointmanager.h"
#include <cmath>
#include <algorithm>

WaypointManager::WaypointManager() {
    m_waypoints = {
        {37.7749, -122.4194,  50.0, 30.0,  45.0, 6000.0},
        {37.7900, -122.3950, 100.0, 45.0,  30.0, 6000.0},
        {37.8050, -122.3700, 150.0, 55.0,  10.0, 6000.0},
        {37.8200, -122.3600, 180.0, 60.0, 350.0, 6000.0},
        {37.8300, -122.3800, 160.0, 55.0, 270.0, 6000.0},
        {37.8200, -122.4100, 120.0, 45.0, 220.0, 6000.0},
        {37.8000, -122.4300,  80.0, 35.0, 190.0, 6000.0},
        {37.7749, -122.4194,  50.0, 30.0, 180.0, 6000.0},
    };
    for (const auto& wp : m_waypoints) m_totalDuration += wp.duration;
}

TelemetryData WaypointManager::interpolate(double /*elapsedMs*/) const {
    return TelemetryData{};   // stub — returns all zeros
}
```

- [ ] **Step 3: Write failing tests in `tests/tst_dronesimulator.cpp`**

Replace the entire file:

```cpp
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
```

- [ ] **Step 4: Build and run tests — expect failures**

```bash
cmake --build build && ctest --test-dir build -V
```

Expected output includes: `FAIL!` on most tests (stub returns all zeros).

- [ ] **Step 5: Implement `src/waypointmanager.cpp`**

```cpp
#include "waypointmanager.h"
#include <cmath>
#include <algorithm>

WaypointManager::WaypointManager() {
    m_waypoints = {
        {37.7749, -122.4194,  50.0, 30.0,  45.0, 6000.0},
        {37.7900, -122.3950, 100.0, 45.0,  30.0, 6000.0},
        {37.8050, -122.3700, 150.0, 55.0,  10.0, 6000.0},
        {37.8200, -122.3600, 180.0, 60.0, 350.0, 6000.0},
        {37.8300, -122.3800, 160.0, 55.0, 270.0, 6000.0},
        {37.8200, -122.4100, 120.0, 45.0, 220.0, 6000.0},
        {37.8000, -122.4300,  80.0, 35.0, 190.0, 6000.0},
        {37.7749, -122.4194,  50.0, 30.0, 180.0, 6000.0},
    };
    for (const auto& wp : m_waypoints) m_totalDuration += wp.duration;
}

TelemetryData WaypointManager::interpolate(double elapsedMs) const {
    // Wrap for continuous loop (position only — battery keeps draining)
    double t = std::fmod(elapsedMs, m_totalDuration);

    // Find the segment containing t
    double accumulated = 0.0;
    size_t segIdx = m_waypoints.size() - 1;
    for (size_t i = 0; i < m_waypoints.size(); ++i) {
        if (t < accumulated + m_waypoints[i].duration) {
            segIdx = i;
            break;
        }
        accumulated += m_waypoints[i].duration;
    }

    double segT = (t - accumulated) / m_waypoints[segIdx].duration;
    const Waypoint& from = m_waypoints[segIdx];
    const Waypoint& to   = m_waypoints[(segIdx + 1) % m_waypoints.size()];

    TelemetryData data;
    data.latitude  = from.latitude  + segT * (to.latitude  - from.latitude);
    data.longitude = from.longitude + segT * (to.longitude - from.longitude);
    data.altitude  = from.altitude  + segT * (to.altitude  - from.altitude);
    data.speed     = from.speed     + segT * (to.speed     - from.speed);
    data.yaw       = from.heading   + segT * (to.heading   - from.heading);

    // Pitch derived from altitude change across the segment (+ve = climbing)
    double altDelta = to.altitude - from.altitude;
    data.pitch = std::clamp(altDelta / 50.0 * 10.0, -20.0, 20.0);

    // Roll derived from heading change (+ve heading change = right turn = positive roll)
    double headDelta = to.heading - from.heading;
    data.roll = std::clamp(headDelta / 45.0 * 15.0, -30.0, 30.0);

    // Battery: 1% drain per 1000ms, floor at 0
    data.battery = std::max(0.0, 100.0 - elapsedMs / 1000.0);

    return data;
}
```

- [ ] **Step 6: Run tests — expect all pass**

```bash
cmake --build build && ctest --test-dir build -V
```

Expected:
```
PASS   : TestWaypointManager::testInterpolationAtStart()
PASS   : TestWaypointManager::testInterpolationMidSegment()
PASS   : TestWaypointManager::testInterpolationAtSegmentEnd()
PASS   : TestWaypointManager::testBatteryDrain()
PASS   : TestWaypointManager::testBatteryNeverExceedsBounds()
PASS   : TestWaypointManager::testTelemetryBounds()
```

- [ ] **Step 7: Commit**

```bash
git add src/waypointmanager.h src/waypointmanager.cpp tests/tst_dronesimulator.cpp
git commit -m "feat: implement WaypointManager with waypoint interpolation (all tests pass)"
```

---

## Task 4: DroneSimulator (TDD)

**Files:**
- Modify: `src/dronesimulator.h`
- Modify: `src/dronesimulator.cpp`
- Modify: `tests/tst_dronesimulator.cpp`

- [ ] **Step 1: Write `src/dronesimulator.h`**

```cpp
#pragma once
#include "telemetrydata.h"
#include "waypointmanager.h"
#include <QObject>
#include <QTimer>
#include <QVariantList>
#include <memory>

class DroneSimulator : public QObject {
    Q_OBJECT
    Q_PROPERTY(double altitude    READ altitude    NOTIFY telemetryChanged)
    Q_PROPERTY(double speed       READ speed       NOTIFY telemetryChanged)
    Q_PROPERTY(double pitch       READ pitch       NOTIFY telemetryChanged)
    Q_PROPERTY(double roll        READ roll        NOTIFY telemetryChanged)
    Q_PROPERTY(double yaw         READ yaw         NOTIFY telemetryChanged)
    Q_PROPERTY(double battery     READ battery     NOTIFY telemetryChanged)
    Q_PROPERTY(double latitude    READ latitude    NOTIFY telemetryChanged)
    Q_PROPERTY(double longitude   READ longitude   NOTIFY telemetryChanged)
    Q_PROPERTY(bool   isRunning   READ isRunning   NOTIFY isRunningChanged)
    Q_PROPERTY(QVariantList breadcrumbs  READ breadcrumbs  NOTIFY telemetryChanged)
    Q_PROPERTY(QVariantList plannedRoute READ plannedRoute CONSTANT)

public:
    explicit DroneSimulator(QObject *parent = nullptr);

    double altitude()  const { return m_current.altitude; }
    double speed()     const { return m_current.speed; }
    double pitch()     const { return m_current.pitch; }
    double roll()      const { return m_current.roll; }
    double yaw()       const { return m_current.yaw; }
    double battery()   const { return m_current.battery; }
    double latitude()  const { return m_current.latitude; }
    double longitude() const { return m_current.longitude; }
    bool   isRunning() const { return m_timer->isActive(); }
    QVariantList breadcrumbs()  const { return m_breadcrumbs; }
    QVariantList plannedRoute() const;

    Q_INVOKABLE void start();
    Q_INVOKABLE void stop();
    Q_INVOKABLE void triggerEmergency();

signals:
    void telemetryChanged();
    void isRunningChanged();
    void emergencyTriggered();

private:
    std::unique_ptr<QTimer>          m_timer;
    std::unique_ptr<WaypointManager> m_waypoints;
    TelemetryData                    m_current;
    QVariantList                     m_breadcrumbs;
    qint64                           m_elapsedMs = 0;

    void onTick();
};
```

- [ ] **Step 2: Write stub `src/dronesimulator.cpp`** (compiles, methods exist, no logic)

```cpp
#include "dronesimulator.h"

DroneSimulator::DroneSimulator(QObject *parent)
    : QObject(parent)
    , m_timer(std::make_unique<QTimer>(this))
    , m_waypoints(std::make_unique<WaypointManager>())
{}

QVariantList DroneSimulator::plannedRoute() const { return {}; }
void DroneSimulator::start() {}
void DroneSimulator::stop() {}
void DroneSimulator::triggerEmergency() {}
void DroneSimulator::onTick() {}
```

- [ ] **Step 3: Add DroneSimulator tests to `tests/tst_dronesimulator.cpp`**

Add this class and its test methods after the `TestWaypointManager` class (before `QTEST_MAIN`). Also add the necessary include at the top.

At the top of the file, add:
```cpp
#include "dronesimulator.h"
```

Add this new class before `QTEST_MAIN`:
```cpp
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
```

Replace the `QTEST_MAIN` line at the bottom:
```cpp
// Run both test classes
int main(int argc, char *argv[]) {
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
```

Remove the `#include "tst_dronesimulator.moc"` line and replace with:
```cpp
#include "tst_dronesimulator.moc"
```
(keep it — it's still needed at the end)

- [ ] **Step 4: Build and run — expect DroneSimulator tests to fail**

```bash
cmake --build build && ctest --test-dir build -V
```

Expected: WaypointManager tests still pass; DroneSimulator tests fail (`testStartSetsIsRunning`, `testEmergencyStopsAndSignals`, `testTelemetryChangedEmittedOnTick`).

- [ ] **Step 5: Implement `src/dronesimulator.cpp`**

```cpp
#include "dronesimulator.h"
#include <QVariantMap>

DroneSimulator::DroneSimulator(QObject *parent)
    : QObject(parent)
    , m_timer(std::make_unique<QTimer>(this))
    , m_waypoints(std::make_unique<WaypointManager>())
{
    connect(m_timer.get(), &QTimer::timeout, this, &DroneSimulator::onTick);
    m_timer->setInterval(50);
    m_current = m_waypoints->interpolate(0.0);
}

QVariantList DroneSimulator::plannedRoute() const {
    QVariantList route;
    for (const auto& wp : m_waypoints->waypoints()) {
        QVariantMap point;
        point[QStringLiteral("lat")] = wp.latitude;
        point[QStringLiteral("lon")] = wp.longitude;
        route.append(point);
    }
    return route;
}

void DroneSimulator::start() {
    if (!m_timer->isActive()) {
        m_timer->start();
        emit isRunningChanged();
    }
}

void DroneSimulator::stop() {
    if (m_timer->isActive()) {
        m_timer->stop();
        emit isRunningChanged();
    }
}

void DroneSimulator::triggerEmergency() {
    bool wasRunning = m_timer->isActive();
    m_timer->stop();
    m_current.speed = 0.0;
    if (wasRunning) emit isRunningChanged();
    emit emergencyTriggered();
    emit telemetryChanged();
}

void DroneSimulator::onTick() {
    m_elapsedMs += 50;
    m_current = m_waypoints->interpolate(static_cast<double>(m_elapsedMs));

    QVariantMap point;
    point[QStringLiteral("lat")] = m_current.latitude;
    point[QStringLiteral("lon")] = m_current.longitude;
    m_breadcrumbs.append(point);

    emit telemetryChanged();
}
```

- [ ] **Step 6: Run all tests — expect all pass**

```bash
cmake --build build && ctest --test-dir build -V
```

Expected: all 10 test functions PASS, exit code 0.

- [ ] **Step 7: Commit**

```bash
git add src/dronesimulator.h src/dronesimulator.cpp tests/tst_dronesimulator.cpp
git commit -m "feat: implement DroneSimulator with timer, signals, emergency protocol (all tests pass)"
```

---

## Task 5: main.cpp

**Files:**
- Modify: `src/main.cpp`

- [ ] **Step 1: Write `src/main.cpp`**

```cpp
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlEngine>
#include "dronesimulator.h"

int main(int argc, char *argv[]) {
    QGuiApplication app(argc, argv);

    qmlRegisterSingletonType<DroneSimulator>("UAV", 1, 0, "Drone",
        [](QQmlEngine *, QJSEngine *) -> QObject * {
            return new DroneSimulator();
        });

    QQmlApplicationEngine engine;
    const QUrl url(QStringLiteral("qrc:/UAV/qml/main.qml"));

    QObject::connect(&engine, &QQmlApplicationEngine::objectCreated,
        &app, [url](QObject *obj, const QUrl &objUrl) {
            if (!obj && url == objUrl)
                QCoreApplication::exit(-1);
        }, Qt::QueuedConnection);

    engine.load(url);
    return app.exec();
}
```

- [ ] **Step 2: Rebuild to verify main.cpp compiles cleanly**

```bash
cmake --build build
```

Expected: builds without error (the app won't launch yet — `main.qml` is still a stub).

- [ ] **Step 3: Commit**

```bash
git add src/main.cpp
git commit -m "feat: wire main.cpp — QML engine, DroneSimulator singleton registration"
```

---

## Task 6: ControlBar.qml

**Files:**
- Modify: `qml/ControlBar.qml`

- [ ] **Step 1: Write `qml/ControlBar.qml`**

```qml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import UAV 1.0

Rectangle {
    id: root
    implicitHeight: 44
    color: "#0b1520"

    RowLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 10

        Button {
            id: startBtn
            text: "▶ START SIMULATION"
            enabled: !Drone.isRunning
            onClicked: Drone.start()
            background: Rectangle {
                color: startBtn.down ? "#0a2a10" : "#0f3d1a"
                border.color: "#2aff2a"
                border.width: 1
                radius: 4
                opacity: startBtn.enabled ? 1.0 : 0.4
            }
            contentItem: Text {
                text: startBtn.text
                color: "#2aff2a"
                font.pixelSize: 11
                font.family: "Courier New"
                font.letterSpacing: 1
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                opacity: startBtn.enabled ? 1.0 : 0.4
            }
        }

        Button {
            id: stopBtn
            text: "■ STOP"
            enabled: Drone.isRunning
            onClicked: Drone.stop()
            background: Rectangle {
                color: stopBtn.down ? "#2a0a0a" : "#3d0f0f"
                border.color: "#ff4444"
                border.width: 1
                radius: 4
                opacity: stopBtn.enabled ? 1.0 : 0.4
            }
            contentItem: Text {
                text: stopBtn.text
                color: "#ff4444"
                font.pixelSize: 11
                font.family: "Courier New"
                font.letterSpacing: 1
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                opacity: stopBtn.enabled ? 1.0 : 0.4
            }
        }

        Button {
            id: emergencyBtn
            text: "⚠ EMERGENCY"
            onClicked: Drone.triggerEmergency()
            background: Rectangle {
                color: emergencyBtn.down ? "#2a1a00" : "#3d2008"
                border.color: "#ff9500"
                border.width: 1
                radius: 4
            }
            contentItem: Text {
                text: emergencyBtn.text
                color: "#ff9500"
                font.pixelSize: 11
                font.family: "Courier New"
                font.letterSpacing: 1
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }

        Item { Layout.fillWidth: true }

        Text {
            text: "UPDATE RATE: 50ms"
            color: "#4a9eff"
            font.pixelSize: 10
            font.family: "Courier New"
        }

        Text {
            id: simTimerLabel
            property int seconds: 0
            text: "SIM TIME: " + Qt.formatTime(new Date(seconds * 1000), "mm:ss")
            color: "#8a9bb0"
            font.pixelSize: 10
            font.family: "Courier New"

            Timer {
                interval: 1000
                running: Drone.isRunning
                repeat: true
                onTriggered: simTimerLabel.seconds++
            }

            Connections {
                target: Drone
                function onEmergencyTriggered() { simTimerLabel.seconds = 0 }
            }
        }
    }
}
```

- [ ] **Step 2: Rebuild**

```bash
cmake --build build
```

Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add qml/ControlBar.qml
git commit -m "feat: ControlBar.qml — Start/Stop/Emergency buttons wired to DroneSimulator"
```

---

## Task 7: TelemetryReadout.qml

**Files:**
- Modify: `qml/TelemetryReadout.qml`

- [ ] **Step 1: Write `qml/TelemetryReadout.qml`**

```qml
import QtQuick
import QtQuick.Layouts
import UAV 1.0

ColumnLayout {
    id: root
    spacing: 6
    width: 180

    Text {
        text: "TELEMETRY"
        color: "#4a9eff"
        font.pixelSize: 9
        font.letterSpacing: 2
        font.family: "Courier New"
        Layout.alignment: Qt.AlignHCenter
    }

    // ── Altitude ────────────────────────────────────────────
    Rectangle {
        color: "#0d1a2e"
        border.color: "#1a3050"
        border.width: 1
        radius: 6
        Layout.fillWidth: true
        implicitHeight: 68

        Column {
            anchors { fill: parent; margins: 8 }
            spacing: 2
            Text { text: "ALTITUDE"; color: "#8a9bb0"; font.pixelSize: 8; font.letterSpacing: 1; font.family: "Courier New" }
            Text { text: Drone.altitude.toFixed(0); color: "#00e5ff"; font.pixelSize: 22; font.bold: true; font.family: "Courier New" }
            Text { text: "meters"; color: "#4a9eff"; font.pixelSize: 9; font.family: "Courier New" }
            Rectangle {
                width: parent.width; height: 3; color: "#0a1525"; radius: 2
                Rectangle {
                    width: Math.max(0, Math.min(parent.width * Drone.altitude / 200.0, parent.width))
                    height: parent.height; color: "#00e5ff"; radius: 2
                    Behavior on width { NumberAnimation { duration: 80 } }
                }
            }
        }
    }

    // ── Speed ───────────────────────────────────────────────
    Rectangle {
        color: "#0d1a2e"; border.color: "#1a3050"; border.width: 1; radius: 6
        Layout.fillWidth: true; implicitHeight: 68
        Column {
            anchors { fill: parent; margins: 8 }
            spacing: 2
            Text { text: "SPEED"; color: "#8a9bb0"; font.pixelSize: 8; font.letterSpacing: 1; font.family: "Courier New" }
            Text { text: Drone.speed.toFixed(0); color: "#4aff91"; font.pixelSize: 22; font.bold: true; font.family: "Courier New" }
            Text { text: "km/h"; color: "#4a9eff"; font.pixelSize: 9; font.family: "Courier New" }
            Rectangle {
                width: parent.width; height: 3; color: "#0a1525"; radius: 2
                Rectangle {
                    width: Math.max(0, Math.min(parent.width * Drone.speed / 100.0, parent.width))
                    height: parent.height; color: "#4aff91"; radius: 2
                    Behavior on width { NumberAnimation { duration: 80 } }
                }
            }
        }
    }

    // ── Battery ─────────────────────────────────────────────
    Rectangle {
        color: "#0d1a2e"; border.color: "#1a3050"; border.width: 1; radius: 6
        Layout.fillWidth: true; implicitHeight: 72
        Column {
            anchors { fill: parent; margins: 8 }
            spacing: 4
            Text { text: "BATTERY"; color: "#8a9bb0"; font.pixelSize: 8; font.letterSpacing: 1; font.family: "Courier New" }
            Text {
                text: Drone.battery.toFixed(0) + "%"
                color: Drone.battery > 50 ? "#ffd700" : (Drone.battery > 20 ? "#ff9500" : "#ff4444")
                font.pixelSize: 22; font.bold: true; font.family: "Courier New"
            }
            Rectangle {
                width: parent.width; height: 8; color: "#0a1525"; radius: 3
                border.color: "#2a4060"; border.width: 1
                Rectangle {
                    width: Math.max(0, Math.min(parent.width * Drone.battery / 100.0, parent.width))
                    height: parent.height
                    color: Drone.battery > 50 ? "#ffd700" : (Drone.battery > 20 ? "#ff9500" : "#ff4444")
                    radius: 3
                    Behavior on width { NumberAnimation { duration: 80 } }
                }
            }
        }
    }

    // ── Altitude Sparkline ───────────────────────────────────
    Rectangle {
        color: "#0d1a2e"; border.color: "#1a3050"; border.width: 1; radius: 6
        Layout.fillWidth: true; implicitHeight: 60

        Text {
            anchors { top: parent.top; left: parent.left; topMargin: 6; leftMargin: 8 }
            text: "ALT HISTORY"
            color: "#8a9bb0"; font.pixelSize: 8; font.letterSpacing: 1; font.family: "Courier New"
        }

        Canvas {
            id: sparkline
            anchors { fill: parent; topMargin: 18; margins: 8 }
            property var samples: []

            Connections {
                target: Drone
                function onTelemetryChanged() {
                    sparkline.samples.push(Drone.altitude)
                    if (sparkline.samples.length > 60) sparkline.samples.shift()
                    sparkline.requestPaint()
                }
            }

            onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                ctx.fillStyle = "#0a1525"
                ctx.fillRect(0, 0, width, height)

                if (samples.length < 2) return

                var maxAlt = 200.0, minAlt = 0.0
                ctx.strokeStyle = "#4a9eff"
                ctx.lineWidth = 1.5
                ctx.beginPath()
                for (var i = 0; i < samples.length; i++) {
                    var x = (i / (samples.length - 1)) * width
                    var y = height - ((samples[i] - minAlt) / (maxAlt - minAlt)) * height
                    if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y)
                }
                ctx.stroke()

                // Current dot
                var lx = width
                var ly = height - ((samples[samples.length - 1] - minAlt) / (maxAlt - minAlt)) * height
                ctx.fillStyle = "#00e5ff"
                ctx.beginPath()
                ctx.arc(lx, ly, 2.5, 0, Math.PI * 2)
                ctx.fill()
            }
        }
    }

    Item { Layout.fillHeight: true }
}
```

- [ ] **Step 2: Rebuild**

```bash
cmake --build build
```

- [ ] **Step 3: Commit**

```bash
git add qml/TelemetryReadout.qml
git commit -m "feat: TelemetryReadout.qml — altitude/speed/battery cards + sparkline"
```

---

## Task 8: AttitudeDial.qml

**Files:**
- Modify: `qml/AttitudeDial.qml`

- [ ] **Step 1: Write `qml/AttitudeDial.qml`**

```qml
import QtQuick
import UAV 1.0

Item {
    id: root
    property double value: 0.0
    property string mode: "horizon"   // "horizon" or "compass"
    property string label: "DIAL"

    implicitWidth: 120
    implicitHeight: 140

    Text {
        id: labelText
        anchors { top: parent.top; horizontalCenter: parent.horizontalCenter }
        text: root.label
        color: "#8a9bb0"
        font.pixelSize: 9; font.letterSpacing: 1; font.family: "Courier New"
    }

    Canvas {
        id: dialCanvas
        anchors { top: labelText.bottom; topMargin: 4; horizontalCenter: parent.horizontalCenter }
        width: 90; height: 90

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            if (root.mode === "horizon") drawHorizon(ctx)
            else drawCompass(ctx)
        }

        function drawHorizon(ctx) {
            var cx = width / 2, cy = height / 2, r = width / 2 - 2

            // Clip to circle
            ctx.save()
            ctx.beginPath()
            ctx.arc(cx, cy, r, 0, Math.PI * 2)
            ctx.clip()

            // Rotate for attitude value
            ctx.translate(cx, cy)
            ctx.rotate(root.value * Math.PI / 180)
            ctx.translate(-cx, -cy)

            // Sky and ground
            ctx.fillStyle = "#1a3a5c"
            ctx.fillRect(0, 0, width, cy)
            ctx.fillStyle = "#3d2008"
            ctx.fillRect(0, cy, width, height)

            // Horizon line
            ctx.strokeStyle = "#ffd700"
            ctx.lineWidth = 1.5
            ctx.beginPath()
            ctx.moveTo(0, cy)
            ctx.lineTo(width, cy)
            ctx.stroke()

            ctx.restore()

            // Fixed aircraft symbol (unrotated)
            ctx.strokeStyle = "#ffffff"
            ctx.lineWidth = 1.5
            ctx.beginPath(); ctx.moveTo(cx - 20, cy); ctx.lineTo(cx - 8, cy); ctx.stroke()
            ctx.beginPath(); ctx.moveTo(cx + 8,  cy); ctx.lineTo(cx + 20, cy); ctx.stroke()
            ctx.beginPath(); ctx.moveTo(cx, cy - 6); ctx.lineTo(cx, cy + 6); ctx.stroke()

            // Outer ring
            ctx.strokeStyle = "#1a3050"
            ctx.lineWidth = 2
            ctx.beginPath()
            ctx.arc(cx, cy, r, 0, Math.PI * 2)
            ctx.stroke()

            // Centre dot
            ctx.fillStyle = "#00e5ff"
            ctx.beginPath(); ctx.arc(cx, cy, 2, 0, Math.PI * 2); ctx.fill()
        }

        function drawCompass(ctx) {
            var cx = width / 2, cy = height / 2, r = width / 2 - 2

            // Background circle
            ctx.fillStyle = "#0a1525"
            ctx.beginPath(); ctx.arc(cx, cy, r, 0, Math.PI * 2); ctx.fill()

            // Outer ring
            ctx.strokeStyle = "#1a3050"
            ctx.lineWidth = 2
            ctx.beginPath(); ctx.arc(cx, cy, r, 0, Math.PI * 2); ctx.stroke()

            // Cardinal labels
            var cardinals = [
                ["N",   0, "#ff4444"],
                ["E",  90, "#8a9bb0"],
                ["S", 180, "#8a9bb0"],
                ["W", 270, "#8a9bb0"]
            ]
            ctx.font = "8px 'Courier New'"
            ctx.textAlign = "center"
            ctx.textBaseline = "middle"
            for (var i = 0; i < cardinals.length; i++) {
                var ang = (cardinals[i][1] - 90) * Math.PI / 180
                ctx.fillStyle = cardinals[i][2]
                ctx.fillText(cardinals[i][0],
                    cx + (r - 10) * Math.cos(ang),
                    cy + (r - 10) * Math.sin(ang))
            }

            // Needle (rotated to heading)
            var needleAng = (root.value - 90) * Math.PI / 180
            var tipX  = cx + (r - 18) * Math.cos(needleAng)
            var tipY  = cy + (r - 18) * Math.sin(needleAng)
            var tailX = cx + (r - 18) * Math.cos(needleAng + Math.PI)
            var tailY = cy + (r - 18) * Math.sin(needleAng + Math.PI)

            ctx.strokeStyle = "#ff4444"; ctx.lineWidth = 2
            ctx.beginPath(); ctx.moveTo(cx, cy); ctx.lineTo(tipX, tipY); ctx.stroke()
            ctx.strokeStyle = "#4a9eff"; ctx.lineWidth = 1.5
            ctx.beginPath(); ctx.moveTo(cx, cy); ctx.lineTo(tailX, tailY); ctx.stroke()

            ctx.fillStyle = "#00e5ff"
            ctx.beginPath(); ctx.arc(cx, cy, 3, 0, Math.PI * 2); ctx.fill()
        }
    }

    Text {
        anchors { top: dialCanvas.bottom; topMargin: 4; horizontalCenter: parent.horizontalCenter }
        text: root.value.toFixed(1) + "°"
        color: "#00e5ff"
        font.pixelSize: 13; font.bold: true; font.family: "Courier New"
    }

    Connections {
        target: Drone
        function onTelemetryChanged() { dialCanvas.requestPaint() }
    }
}
```

- [ ] **Step 2: Rebuild**

```bash
cmake --build build
```

- [ ] **Step 3: Commit**

```bash
git add qml/AttitudeDial.qml
git commit -m "feat: AttitudeDial.qml — artificial horizon and compass canvas components"
```

---

## Task 9: MapPanel.qml

**Files:**
- Modify: `qml/MapPanel.qml`

- [ ] **Step 1: Write `qml/MapPanel.qml`**

```qml
import QtQuick
import UAV 1.0

Rectangle {
    id: root
    color: "#0d1a2e"
    border.color: "#1a3050"
    border.width: 1
    radius: 6
    clip: true

    // ── Header ────────────────────────────────────────────────
    Rectangle {
        id: header
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: 26; color: "transparent"
        border.color: "#1a3050"; border.width: 0

        Row {
            anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
            spacing: 8
            Text { text: "GPS TRACK"; color: "#4a9eff"; font.pixelSize: 9; font.letterSpacing: 2; font.family: "Courier New" }
        }
        Row {
            anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
            spacing: 8
            Text { text: "LAT " + Drone.latitude.toFixed(4) + "°"; color: "#8a9bb0"; font.pixelSize: 9; font.family: "Courier New" }
            Text { text: "LON " + Drone.longitude.toFixed(4) + "°"; color: "#8a9bb0"; font.pixelSize: 9; font.family: "Courier New" }
        }
        Rectangle { anchors { bottom: parent.bottom; left: parent.left; right: parent.right }; height: 1; color: "#1a3050" }
    }

    // ── Map Canvas ────────────────────────────────────────────
    Canvas {
        id: mapCanvas
        anchors { top: header.bottom; bottom: parent.bottom; left: parent.left; right: parent.right; margins: 4 }

        // Bounding box matching the hardcoded waypoints in WaypointManager
        readonly property double minLat:  37.7700
        readonly property double maxLat:  37.8350
        readonly property double minLon: -122.4350
        readonly property double maxLon: -122.3550

        function lonToX(lon) {
            return (lon - minLon) / (maxLon - minLon) * width  * 0.86 + width  * 0.07
        }
        function latToY(lat) {
            return height - ((lat - minLat) / (maxLat - minLat) * height * 0.86 + height * 0.07)
        }

        Connections {
            target: Drone
            function onTelemetryChanged() { mapCanvas.requestPaint() }
        }

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)

            // Background
            ctx.fillStyle = "#0a1525"
            ctx.fillRect(0, 0, width, height)

            // Grid
            ctx.strokeStyle = "#1a3050"
            ctx.lineWidth = 0.5
            for (var i = 1; i < 4; i++) {
                ctx.beginPath(); ctx.moveTo(width * i / 4, 0); ctx.lineTo(width * i / 4, height); ctx.stroke()
                ctx.beginPath(); ctx.moveTo(0, height * i / 4); ctx.lineTo(width, height * i / 4); ctx.stroke()
            }

            var route = Drone.plannedRoute
            var trail = Drone.breadcrumbs

            // ── Planned route (dashed) ────────────────────────
            if (route.length > 1) {
                ctx.strokeStyle = "#4a9eff"
                ctx.lineWidth = 1
                ctx.setLineDash([5, 4])
                ctx.globalAlpha = 0.35
                ctx.beginPath()
                for (var r = 0; r < route.length; r++) {
                    var rx = lonToX(route[r].lon), ry = latToY(route[r].lat)
                    if (r === 0) ctx.moveTo(rx, ry); else ctx.lineTo(rx, ry)
                }
                // Close loop back to first
                ctx.lineTo(lonToX(route[0].lon), latToY(route[0].lat))
                ctx.stroke()
                ctx.setLineDash([])
                ctx.globalAlpha = 1.0

                // Waypoint markers
                for (var w = 0; w < route.length; w++) {
                    var wx = lonToX(route[w].lon), wy = latToY(route[w].lat)
                    ctx.strokeStyle = "#2a5080"; ctx.lineWidth = 1.5
                    ctx.beginPath(); ctx.arc(wx, wy, 4, 0, Math.PI * 2); ctx.stroke()
                }

                // Start marker (green)
                ctx.fillStyle = "#4aff91"
                ctx.beginPath(); ctx.arc(lonToX(route[0].lon), latToY(route[0].lat), 5, 0, Math.PI * 2); ctx.fill()
            }

            // ── Completed breadcrumb trail ────────────────────
            if (trail.length > 1) {
                ctx.strokeStyle = "#4a9eff"
                ctx.lineWidth = 2
                ctx.setLineDash([])
                ctx.beginPath()
                for (var b = 0; b < trail.length; b++) {
                    var bx = lonToX(trail[b].lon), by = latToY(trail[b].lat)
                    if (b === 0) ctx.moveTo(bx, by); else ctx.lineTo(bx, by)
                }
                ctx.stroke()
            }

            // ── Drone marker ──────────────────────────────────
            var dx = lonToX(Drone.longitude), dy = latToY(Drone.latitude)
            var headRad = (Drone.yaw - 90) * Math.PI / 180

            // Heading arrow
            ctx.strokeStyle = "#00e5ff"; ctx.lineWidth = 1.5
            ctx.beginPath()
            ctx.moveTo(dx, dy)
            ctx.lineTo(dx + Math.cos(headRad) * 16, dy + Math.sin(headRad) * 16)
            ctx.stroke()

            // Glow ring
            ctx.fillStyle = "rgba(0, 229, 255, 0.15)"
            ctx.beginPath(); ctx.arc(dx, dy, 10, 0, Math.PI * 2); ctx.fill()

            // Drone dot
            ctx.fillStyle = "#00e5ff"
            ctx.beginPath(); ctx.arc(dx, dy, 5, 0, Math.PI * 2); ctx.fill()
        }
    }
}
```

- [ ] **Step 2: Rebuild**

```bash
cmake --build build
```

- [ ] **Step 3: Commit**

```bash
git add qml/MapPanel.qml
git commit -m "feat: MapPanel.qml — GPS track canvas with planned route, breadcrumbs, drone marker"
```

---

## Task 10: main.qml

**Files:**
- Modify: `qml/main.qml`

- [ ] **Step 1: Write `qml/main.qml`**

```qml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import UAV 1.0

ApplicationWindow {
    id: root
    visible: true
    width: 1200
    height: 720
    minimumWidth: 900
    minimumHeight: 600
    title: "UAV Telemetry & Simulation Control Station"
    color: "#080d14"

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ── Status bar ─────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            height: 32; color: "#0b1520"

            RowLayout {
                anchors { fill: parent; margins: 10 }
                spacing: 10

                Rectangle { width: 8; height: 8; radius: 4; color: "#00e5ff" }

                Text {
                    text: "UAV CONTROL STATION"
                    color: "#4a9eff"
                    font.pixelSize: 11; font.letterSpacing: 2; font.bold: true; font.family: "Courier New"
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: "MISSION: WAYPOINT ROUTE A"
                    color: "#4aff91"
                    font.pixelSize: 10; font.family: "Courier New"
                }

                Rectangle {
                    width: 8; height: 8; radius: 4
                    color: Drone.isRunning ? "#ff4500" : "#444444"
                }

                Text {
                    text: Drone.isRunning ? "LIVE" : "IDLE"
                    color: Drone.isRunning ? "#ff4500" : "#444444"
                    font.pixelSize: 10; font.letterSpacing: 1; font.family: "Courier New"
                }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: "#1a3050" }

        // ── Main 3-column area ─────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: 8
            spacing: 8

            // Left column: attitude dials
            ColumnLayout {
                spacing: 8
                Layout.preferredWidth: 140
                Layout.fillHeight: true

                Text {
                    text: "ATTITUDE"
                    color: "#4a9eff"
                    font.pixelSize: 9; font.letterSpacing: 2; font.family: "Courier New"
                    Layout.alignment: Qt.AlignHCenter
                }

                Rectangle {
                    Layout.fillWidth: true; height: 1; color: "#1a3050"
                    Layout.bottomMargin: 2
                }

                AttitudeDial { label: "PITCH";   mode: "horizon";  value: Drone.pitch; Layout.alignment: Qt.AlignHCenter }
                AttitudeDial { label: "ROLL";    mode: "horizon";  value: Drone.roll;  Layout.alignment: Qt.AlignHCenter }
                AttitudeDial { label: "HEADING"; mode: "compass";  value: Drone.yaw;   Layout.alignment: Qt.AlignHCenter }

                Item { Layout.fillHeight: true }
            }

            // Center: GPS map
            MapPanel {
                Layout.fillWidth: true
                Layout.fillHeight: true
            }

            // Right: telemetry readout
            TelemetryReadout {
                Layout.preferredWidth: 185
                Layout.fillHeight: true
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: "#1a3050" }

        // ── Control bar ─────────────────────────────────────
        ControlBar { Layout.fillWidth: true }
    }

    // ── Emergency overlay ───────────────────────────────────
    Rectangle {
        id: emergencyOverlay
        anchors.fill: parent
        color: "#70ff0000"
        visible: false
        z: 100

        Column {
            anchors.centerIn: parent
            spacing: 16

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "⚠  EMERGENCY PROTOCOL ACTIVATED"
                color: "#ffffff"
                font.pixelSize: 26; font.bold: true; font.family: "Courier New"; font.letterSpacing: 2
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Click anywhere to dismiss"
                color: "rgba(255,255,255,0.6)"
                font.pixelSize: 13; font.family: "Courier New"
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: emergencyOverlay.visible = false
        }

        Connections {
            target: Drone
            function onEmergencyTriggered() { emergencyOverlay.visible = true }
        }
    }
}
```

- [ ] **Step 2: Build the full app**

```bash
cmake --build build
```

Expected: no errors.

- [ ] **Step 3: Launch the app and verify the dashboard**

```bash
./build/telemetry_simulation
```

Expected:
- Dark window opens (1200×720) with status bar, 3-column layout, control bar
- IDLE indicator in top-right
- Click **▶ START SIMULATION** — dials animate, map draws breadcrumbs, telemetry values update
- Click **■ STOP** — animation freezes, IDLE status returns
- Click **⚠ EMERGENCY** — red overlay appears, speed drops to 0; click overlay to dismiss
- Battery readout decreases over time; bar turns orange at 50%, red at 20%

- [ ] **Step 4: Run tests one final time to confirm nothing regressed**

```bash
ctest --test-dir build -V
```

Expected: all tests PASS.

- [ ] **Step 5: Commit**

```bash
git add qml/main.qml
git commit -m "feat: main.qml — root window wiring all panels, emergency overlay"
```

---

## Task 11: README.md

**Files:**
- Create: `README.md`

- [ ] **Step 1: Write `README.md`**

```markdown
# UAV Telemetry & Simulation Control Station

A desktop Ground Control Station (GCS) simulator built with **C++17** and **Qt 6 / QML**.
A C++ simulation engine generates waypoint-based flight telemetry at 50 ms intervals;
a dark-mode QML dashboard visualises it in real-time.

## Architecture

```
WaypointManager          — pure C++ interpolation engine; no Qt dependency
    ↓ TelemetryData
DroneSimulator (QObject) — owns QTimer, exposes Q_PROPERTYs, receives Q_INVOKABLE commands
    ↓ signals / QML bindings
QML Dashboard            — five components: MapPanel, AttitudeDial ×3, TelemetryReadout, ControlBar
```

**Key design choices:**
- `WaypointManager` is a plain C++ class — easy to unit-test without a Qt event loop
- `DroneSimulator` is a QML singleton registered via `qmlRegisterSingletonType`; QML never owns it
- All telemetry is funnelled through a single `telemetryChanged()` signal — one connection per component
- Canvas-based custom components avoid third-party widget dependencies

## Requirements

- Qt 6.2+ (Core, Gui, Qml, Quick, Test)
- CMake 3.21+
- C++17 compiler (GCC 9+ / Clang 11+ / AppleClang 13+)

## Build

```bash
# macOS (Homebrew Qt 6)
cmake -B build -DCMAKE_PREFIX_PATH=$(brew --prefix qt6)

# Linux (Qt 6 installed to /opt/Qt/6.x.x)
cmake -B build -DCMAKE_PREFIX_PATH=/opt/Qt/6.x.x/gcc_64

cmake --build build -j$(nproc)
```

## Run

```bash
./build/telemetry_simulation
```

## Tests

```bash
ctest --test-dir build -V
```

All four test suites cover:
- Waypoint interpolation accuracy (position lerp, mid-segment, segment boundary)
- Battery drain (monotonic, bounded 0–100%)
- `DroneSimulator` start/stop/emergency state and signal emission
- Telemetry physical bounds across a full route loop

## Controls

| Button | Action |
|---|---|
| ▶ START SIMULATION | Begins 50 ms telemetry loop |
| ■ STOP | Pauses simulation |
| ⚠ EMERGENCY | Stops immediately, zeroes speed, flashes red overlay |

## Project Structure

```
src/               C++ backend (WaypointManager, DroneSimulator, main)
qml/               QML components (MapPanel, AttitudeDial, TelemetryReadout, ControlBar, main)
tests/             QtTest suite (tst_dronesimulator.cpp)
docs/superpowers/  Design spec and implementation plan
```
```

- [ ] **Step 2: Final build + test verification**

```bash
cmake --build build && ctest --test-dir build
```

Expected: `100% tests passed`.

- [ ] **Step 3: Final commit**

```bash
git add README.md
git commit -m "docs: add README with architecture overview and build instructions"
```

---

## Self-Review

### Spec Coverage Check

| Spec requirement | Task |
|---|---|
| TelemetryData struct | Task 2 |
| WaypointManager + interpolation | Task 3 |
| DroneSimulator Q_PROPERTYs | Task 4 |
| Q_INVOKABLE start/stop/emergency | Task 4 |
| `emergencyTriggered` signal | Task 4 |
| `breadcrumbs` QVariantList property | Task 4 |
| `plannedRoute` (spec gap fixed) | Task 4 |
| `std::unique_ptr` / RAII / no raw new | Task 4 |
| main.cpp singleton registration | Task 5 |
| ControlBar.qml with 3 styled buttons | Task 6 |
| TelemetryReadout with progress bars | Task 7 |
| Battery bar color changes | Task 7 |
| Altitude sparkline Canvas | Task 7 |
| AttitudeDial horizon mode | Task 8 |
| AttitudeDial compass mode | Task 8 |
| MapPanel breadcrumb trail | Task 9 |
| MapPanel future waypoints (dashed) | Task 9 |
| MapPanel drone marker + heading arrow | Task 9 |
| main.qml 3-column layout | Task 10 |
| Emergency red overlay | Task 10 |
| Connections → requestPaint() | Tasks 8–10 |
| testWaypointInterpolation | Task 3 |
| testBatteryDrain | Task 3 |
| testEmergencyStop | Task 4 |
| testTelemetryBounds | Task 3 |
| CMakeLists app + test targets | Task 1 |
| README with architecture + build | Task 11 |

**No gaps found.**

### Placeholder Scan

No TBD, TODO, or incomplete sections found.

### Type Consistency

All method names consistent throughout:
- `WaypointManager::interpolate(double)` — defined Task 3, used Tasks 3+4
- `DroneSimulator::plannedRoute()` — declared Task 4, used MapPanel Task 9
- `DroneSimulator::breadcrumbs()` — declared Task 4, used MapPanel Task 9
- `Drone.isRunning` / `Drone.start()` / `Drone.stop()` / `Drone.triggerEmergency()` — consistent Tasks 5–10
