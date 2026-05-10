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
