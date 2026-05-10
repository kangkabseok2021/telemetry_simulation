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
