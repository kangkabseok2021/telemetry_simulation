# UAV Drone Telemetry & Simulation Control Station — Design Spec

**Date:** 2026-05-10  
**Status:** Approved

---

## Overview

A desktop application simulating a drone ground control station (GCS). A C++ simulation engine generates waypoint-based telemetry at 50ms intervals; a Qt/QML dark-mode dashboard visualizes it in real-time. Demonstrates modern C++, Qt Signals/Slots, Q_PROPERTY, and QML custom components.

---

## Technology Decisions

| Concern | Choice | Reason |
|---|---|---|
| Qt version | Qt 6 | Modern QML, active LTS, `qt_add_qml_module` |
| Platform | macOS + Linux | CMake guards for both; no Windows packaging |
| Map widget | Custom QML Canvas | Zero extra deps; full visual control |
| Flight sim | Waypoint-based interpolation | Structured mission feel; testable |
| Testing | QtTest | Built into Qt; no FetchContent overhead |
| C++↔QML bridge | Q_PROPERTY + Q_INVOKABLE | Direct demonstration of Qt Signals/Slots |

---

## File Structure

```
telemetry_simulation/
├── CMakeLists.txt
├── src/
│   ├── main.cpp                  # QGuiApplication + QML engine + singleton registration
│   ├── dronesimulator.h/.cpp     # Core QObject: timer, telemetry properties, commands
│   ├── waypointmanager.h/.cpp    # Waypoint list + interpolation logic
│   └── telemetrydata.h           # Plain struct: one telemetry snapshot
├── qml/
│   ├── main.qml                  # Root Window, 3-column grid layout
│   ├── MapPanel.qml              # Canvas: GPS breadcrumb trail + waypoints + drone marker
│   ├── AttitudeDial.qml          # Canvas: artificial horizon dial (pitch, roll, yaw)
│   ├── TelemetryReadout.qml      # Numeric readouts: altitude, speed, battery, sparkline
│   └── ControlBar.qml            # Start / Stop / Emergency buttons
├── tests/
│   └── tst_dronesimulator.cpp    # QtTest: interpolation, battery, emergency, bounds
└── docs/
    └── superpowers/specs/
        └── 2026-05-10-telemetry-simulation-design.md
```

---

## Architecture

### Data Flow

```
QTimer (50ms)
  → DroneSimulator::onTick()
  → WaypointManager::interpolate(elapsed_ms)
  → returns TelemetryData { altitude, speed, pitch, roll, yaw, battery, lat, lon }
  → DroneSimulator updates m_current + appends to m_breadcrumbs
  → emits telemetryChanged()
  → QML bindings re-evaluate all Q_PROPERTYs
  → Canvas.requestPaint() triggers redraw on MapPanel + AttitudeDials
```

Emergency path: `triggerEmergency()` → stops timer → speed → 0 → emits `emergencyTriggered()` → QML flashes red alert overlay.

---

## C++ Backend

### `TelemetryData` (struct, `telemetrydata.h`)

Plain value struct. No Qt dependencies. Used internally by `DroneSimulator` and `WaypointManager`.

```cpp
struct TelemetryData {
    double altitude  = 0.0;   // meters
    double speed     = 0.0;   // km/h
    double pitch     = 0.0;   // degrees, +nose-up
    double roll      = 0.0;   // degrees, +right
    double yaw       = 0.0;   // degrees, 0–360 clockwise from north
    double battery   = 100.0; // percent
    double latitude  = 0.0;
    double longitude = 0.0;
};
```

### `WaypointManager` (`waypointmanager.h/.cpp`)

- Holds `std::vector<Waypoint>` (lat, lon, altitude, speed, heading)
- `interpolate(double elapsed_ms) → TelemetryData`: lerps position/altitude/speed between surrounding waypoints; derives pitch from altitude delta, roll from heading change rate
- Battery drains linearly from 100% over total mission duration
- Loop-capable: wraps back to waypoint 0 when route completes

### `DroneSimulator` (QObject singleton, `dronesimulator.h/.cpp`)

```cpp
class DroneSimulator : public QObject {
    Q_OBJECT
    Q_PROPERTY(double altitude   READ altitude   NOTIFY telemetryChanged)
    Q_PROPERTY(double speed      READ speed      NOTIFY telemetryChanged)
    Q_PROPERTY(double pitch      READ pitch      NOTIFY telemetryChanged)
    Q_PROPERTY(double roll       READ roll       NOTIFY telemetryChanged)
    Q_PROPERTY(double yaw        READ yaw        NOTIFY telemetryChanged)
    Q_PROPERTY(double battery    READ battery    NOTIFY telemetryChanged)
    Q_PROPERTY(double latitude   READ latitude   NOTIFY telemetryChanged)
    Q_PROPERTY(double longitude  READ longitude  NOTIFY telemetryChanged)
    Q_PROPERTY(bool   isRunning  READ isRunning  NOTIFY isRunningChanged)
    Q_PROPERTY(QVariantList breadcrumbs READ breadcrumbs NOTIFY telemetryChanged)
public:
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
    QVariantList                     m_breadcrumbs; // list of {lat, lon} maps
    qint64                           m_elapsedMs = 0;
    void onTick();
};
```

**Modern C++ practices:** `std::unique_ptr` (RAII), `const`-correct accessors, `std::vector` + range-for, no raw `new`/`delete`.

**Registration in `main.cpp`:**
```cpp
qmlRegisterSingletonType<DroneSimulator>("UAV", 1, 0, "Drone",
    [](QQmlEngine *, QJSEngine *) -> QObject * {
        return new DroneSimulator();
    });
```

---

## QML Frontend

### `main.qml`

Root `ApplicationWindow` with dark background (`#080d14`). Three-column `RowLayout`:
- Left: `AttitudeDial` × 3 (pitch, roll, yaw) in a `ColumnLayout`
- Center: `MapPanel` (fills remaining space)
- Right: `TelemetryReadout` column

`ControlBar` anchored to bottom. `Connections` block listens for `Drone.emergencyTriggered` to show a red overlay `Rectangle`.

### `AttitudeDial.qml`

Parameterized component: `property string label`, `property double value`, `property string mode` (`"horizon"` or `"compass"`).

- Horizon mode (pitch/roll): `Canvas` draws sky (blue) / ground (brown) split, horizon line rotated by value, fixed aircraft symbol overlay
- Compass mode (yaw): `Canvas` draws cardinal labels, rotating needle

### `MapPanel.qml`

`Canvas` component. On `telemetryChanged`:
1. Clears canvas, draws grid
2. Iterates `Drone.breadcrumbs` → draws completed trail as polyline
3. Draws future waypoints as dashed circles
4. Draws drone marker (filled circle + heading arrow) at current lat/lon

Coordinate mapping: linear scale from bounding box of all waypoints to canvas pixel space.

### `TelemetryReadout.qml`

`ColumnLayout` of labeled value cards. Each card: label (small caps), large numeric value, unit label, thin progress bar. Battery card changes bar color: green > 50%, yellow 20–50%, red < 20%.

Altitude sparkline: `Canvas` that appends to a local JS array (capped at 60 samples) on each `telemetryChanged`, redraws polyline.

### `ControlBar.qml`

Three `Button` components styled with colored borders. `onClicked` calls `Drone.start()`, `Drone.stop()`, `Drone.triggerEmergency()` respectively. Status text shows update rate and sim elapsed time.

---

## Testing (`tests/tst_dronesimulator.cpp`)

| Test | What it verifies |
|---|---|
| `testWaypointInterpolation` | Position lerp at t=0, t=0.5, t=1.0 between two waypoints |
| `testBatteryDrain` | Battery decreases monotonically across ticks |
| `testEmergencyStop` | `triggerEmergency()` sets `isRunning=false`, emits signal |
| `testTelemetryBounds` | Altitude/speed/pitch/roll stay within physical limits across full route |

All tests use `QVERIFY` / `QCOMPARE`. `QSignalSpy` used for signal emission tests.

---

## CMake Build

```cmake
cmake_minimum_required(VERSION 3.21)
project(telemetry_simulation VERSION 1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS Core Gui Qml Quick)

qt_add_executable(telemetry_simulation
    src/main.cpp
    src/dronesimulator.cpp
    src/waypointmanager.cpp
)

qt_add_qml_module(telemetry_simulation
    URI UAV
    VERSION 1.0
    QML_FILES
        qml/main.qml
        qml/MapPanel.qml
        qml/AttitudeDial.qml
        qml/TelemetryReadout.qml
        qml/ControlBar.qml
)

target_link_libraries(telemetry_simulation PRIVATE Qt6::Core Qt6::Gui Qt6::Qml Qt6::Quick)

# Tests
enable_testing()
qt_add_executable(tst_dronesimulator tests/tst_dronesimulator.cpp src/dronesimulator.cpp src/waypointmanager.cpp)
target_link_libraries(tst_dronesimulator PRIVATE Qt6::Core Qt6::Test)
add_test(NAME DroneSimulatorTests COMMAND tst_dronesimulator)
```

Build instructions:
```bash
cmake -B build -DCMAKE_PREFIX_PATH=/path/to/Qt6
cmake --build build
ctest --test-dir build
./build/telemetry_simulation
```

---

## Out of Scope

- Real GPS hardware input
- Network telemetry (MAVLink, etc.)
- Multi-drone support
- Windows build
- Map tile rendering (Qt Location)
