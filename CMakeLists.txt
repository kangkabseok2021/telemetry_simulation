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

qt_add_resources(telemetry_simulation "config"
    PREFIX "/"
    FILES qtquickcontrols2.conf
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
