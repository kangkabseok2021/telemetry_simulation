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
