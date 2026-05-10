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
