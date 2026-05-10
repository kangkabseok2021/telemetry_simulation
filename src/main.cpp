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
