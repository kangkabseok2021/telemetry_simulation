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
