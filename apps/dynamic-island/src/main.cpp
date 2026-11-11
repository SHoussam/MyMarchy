// dynamic-island — Omarchy desktop companion & instant recovery tool for Dynamic Island.

#include <QCoreApplication>
#include <QEventLoop>
#include <QGuiApplication>
#include <QIcon>
#include <QJsonDocument>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QTimer>
#include <QUrl>
#include <cstdio>

#include "backend.h"
#include "theme.h"
#include "translator.h"

namespace {

void printUsage() {
    std::fputs(
        "Usage: dynamic-island [OPTION]\n\n"
        "Control and recover the Omarchy Dynamic Island shell plugin.\n\n"
        "Options:\n"
        "      --open         Launch the desktop control window (default)\n"
        "      --restart      Restart the Omarchy shell and confirm surface attachment\n"
        "      --revive       Rebuild the Dynamic Island Wayland layer surface cleanly\n"
        "      --toggle       Toggle expanded / compact island view\n"
        "      --focus        Toggle Focus Mode (disable or enable hover-to-expand)\n"
        "      --reset        Clear stuck alerts/sessions and collapse the island\n"
        "      --status       Print current Dynamic Island layer and IPC status\n"
        "      --json         With --status (or alone), output JSON status\n"
        "  -v, --version      Show version information\n"
        "  -h, --help         Show this help text\n",
        stdout);
}

int runCli(int argc, char *argv[], const QString &action, bool json) {
    qputenv("QT_QPA_PLATFORM", "offscreen");
    QCoreApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("dynamic-island"));
    app.setApplicationVersion(QStringLiteral("0.1.0"));

    Translator translator;
    app.installTranslator(&translator);

    Backend backend;
    QEventLoop loop;
    QTimer guard;
    guard.setSingleShot(true);

    bool ok = false;
    QObject::connect(&guard, &QTimer::timeout, &loop, [&]() {
        ok = false;
        loop.quit();
    });

    if (action == QStringLiteral("status")) {
        guard.start(3500);
        QObject::connect(&backend, &Backend::probesFinished, &loop, [&]() {
            ok = true;
            loop.quit();
        });
        QTimer::singleShot(0, &backend, &Backend::refresh);
        loop.exec();
        guard.stop();

        if (!ok) {
            std::fputs("Timed out probing Dynamic Island status.\n", stderr);
            return 1;
        }
        if (json) {
            const QByteArray out = QJsonDocument(backend.toJson()).toJson(QJsonDocument::Indented);
            std::fwrite(out.constData(), 1, static_cast<size_t>(out.size()), stdout);
        } else {
            const QString surface = backend.layerAttached()
                ? QStringLiteral("attached (%1)").arg(backend.layerMonitor().isEmpty() ? QStringLiteral("unknown") : backend.layerMonitor())
                : QStringLiteral("detached");
            const QString glow = backend.glowAttached() ? QStringLiteral("attached") : QStringLiteral("detached");
            const QString ipc = backend.ipcOnline() ? QStringLiteral("online") : QStringLiteral("offline");
            const QString focus = backend.focusMode() ? QStringLiteral("on (click only)") : QStringLiteral("off (hover opens)");
            std::fprintf(stdout,
                         "Status:     %s\n"
                         "Surface:    %s (glow: %s)\n"
                         "Shell IPC:  %s (surfaceReady=%s)\n"
                         "Mode:       %s%s\n"
                         "Focus Mode: %s\n",
                         backend.statusText().toUtf8().constData(),
                         surface.toUtf8().constData(),
                         glow.toUtf8().constData(),
                         ipc.toUtf8().constData(),
                         backend.surfaceReady() ? "true" : "false",
                         backend.islandMode().toUtf8().constData(),
                         backend.islandPage().isEmpty() ? "" : QStringLiteral(" / %1").arg(backend.islandPage()).toUtf8().constData(),
                         focus.toUtf8().constData());
        }
        return 0;
    }

    guard.start(action == QStringLiteral("restart") || action == QStringLiteral("revive") ? 70000 : 5000);
    QObject::connect(&backend, &Backend::actionCompleted, &loop, [&](bool succeeded) {
        ok = succeeded;
        loop.quit();
    });

    QTimer::singleShot(0, &backend, [&]() {
        if (action == QStringLiteral("restart"))
            backend.restartShell();
        else if (action == QStringLiteral("revive"))
            backend.reviveSurface();
        else if (action == QStringLiteral("toggle"))
            backend.toggleExpand();
        else if (action == QStringLiteral("focus"))
            backend.toggleFocusMode();
        else if (action == QStringLiteral("reset"))
            backend.resetState();
    });

    loop.exec();
    guard.stop();

    if (json) {
        QJsonObject obj = backend.toJson();
        obj.insert(QStringLiteral("ok"), ok);
        const QByteArray out = QJsonDocument(obj).toJson(QJsonDocument::Indented);
        std::fwrite(out.constData(), 1, static_cast<size_t>(out.size()), stdout);
        return ok ? 0 : 1;
    }

    if (ok) {
        std::fprintf(stdout, "%s\n", backend.statusText().toUtf8().constData());
        return 0;
    }

    const QString err = backend.lastError().isEmpty() ? backend.statusText() : backend.lastError();
    std::fprintf(stderr, "Error: %s\n", err.toUtf8().constData());
    return 1;
}

} // namespace

int main(int argc, char *argv[]) {
    bool openGui = false;
    bool json = false;
    QString action;

    for (int i = 1; i < argc; ++i) {
        const QString arg = QString::fromLocal8Bit(argv[i]);
        if (arg == QStringLiteral("-h") || arg == QStringLiteral("--help") || arg == QStringLiteral("help")) {
            printUsage();
            return 0;
        }
        if (arg == QStringLiteral("-v") || arg == QStringLiteral("--version")) {
            std::puts("dynamic-island 0.1.0");
            return 0;
        }
        if (arg == QStringLiteral("--open") || arg == QStringLiteral("open") || arg == QStringLiteral("--gui")) {
            openGui = true;
        } else if (arg == QStringLiteral("--json")) {
            json = true;
        } else if (arg == QStringLiteral("--status") || arg == QStringLiteral("status")) {
            action = QStringLiteral("status");
        } else if (arg == QStringLiteral("--restart") || arg == QStringLiteral("restart")) {
            action = QStringLiteral("restart");
        } else if (arg == QStringLiteral("--revive") || arg == QStringLiteral("revive")) {
            action = QStringLiteral("revive");
        } else if (arg == QStringLiteral("--toggle") || arg == QStringLiteral("toggle")) {
            action = QStringLiteral("toggle");
        } else if (arg == QStringLiteral("--focus") || arg == QStringLiteral("focus")) {
            action = QStringLiteral("focus");
        } else if (arg == QStringLiteral("--reset") || arg == QStringLiteral("reset")) {
            action = QStringLiteral("reset");
        } else {
            std::fprintf(stderr, "Unknown option: %s\n", arg.toUtf8().constData());
            printUsage();
            return 2;
        }
    }

    if (json && action.isEmpty())
        action = QStringLiteral("status");

    if (!action.isEmpty() && !openGui)
        return runCli(argc, argv, action, json);

    QGuiApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("dynamic-island"));
    app.setApplicationVersion(QStringLiteral("0.1.0"));

    // Matches the window to dynamic-island.desktop, so the compositor (Wayland app_id),
    // dock, and launcher pick up the installed icon.
    app.setDesktopFileName(QStringLiteral("dynamic-island"));
    app.setWindowIcon(QIcon::fromTheme(QStringLiteral("dynamic-island")));

    QQuickStyle::setStyle(QStringLiteral("Material"));

    // Installed before anything is translated, and every qsTr() binding is
    // re-evaluated when the Omarchy language changes.
    Translator translator;
    app.installTranslator(&translator);

    Theme theme;
    Backend backend;
    backend.startPolling();

    QQmlApplicationEngine engine;
    QObject::connect(&translator, &Translator::changed, &engine, &QQmlEngine::retranslate);
    engine.rootContext()->setContextProperty(QStringLiteral("translator"), &translator);
    engine.rootContext()->setContextProperty(QStringLiteral("theme"), &theme);
    engine.rootContext()->setContextProperty(QStringLiteral("backend"), &backend);
    engine.load(QUrl(QStringLiteral("qrc:/Main.qml")));
    if (engine.rootObjects().isEmpty())
        return 1;

    return app.exec();
}
