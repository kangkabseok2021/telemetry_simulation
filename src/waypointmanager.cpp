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
