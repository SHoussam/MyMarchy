#include <QDir>
#include <QFile>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QSignalSpy>
#include <QTemporaryDir>
#include <QtTest>

#include "backend.h"
#include "theme.h"
#include "translator.h"

namespace {

QStringList *gCapturedWarnings = nullptr;
QtMessageHandler gPrevHandler = nullptr;

void captureQtWarnings(QtMsgType type, const QMessageLogContext &ctx, const QString &msg) {
    if (gCapturedWarnings && (type == QtWarningMsg || type == QtCriticalMsg || type == QtFatalMsg))
        gCapturedWarnings->append(msg);
    if (gPrevHandler)
        gPrevHandler(type, ctx, msg);
}

} // namespace

class DynamicIslandTests : public QObject {
    Q_OBJECT

private slots:
    void parseLayersJsonDetectsIslandAndGlow()
    {
        const QByteArray sample = R"({
            "HDMI-A-1": {
                "levels": {
                    "2": [
                        { "namespace": "dynamic-island-glow", "w": 730, "h": 136 },
                        { "namespace": "omarchy-bar", "w": 1536, "h": 30 }
                    ],
                    "3": [
                        { "namespace": "dynamic-island", "w": 730, "h": 136 }
                    ]
                }
            }
        })";

        const auto probe = Backend::parseLayersJson(sample);
        QVERIFY(probe.valid);
        QVERIFY(probe.islandAttached);
        QVERIFY(probe.glowAttached);
        QCOMPARE(probe.monitor, QString("HDMI-A-1"));
    }

    void parseLayersJsonDetectsMissingIsland()
    {
        const QByteArray sample = R"({
            "HDMI-A-1": {
                "levels": {
                    "2": [ { "namespace": "omarchy-bar", "w": 1536, "h": 30 } ]
                }
            }
        })";

        const auto probe = Backend::parseLayersJson(sample);
        QVERIFY(probe.valid);
        QVERIFY(!probe.islandAttached);
        QVERIFY(!probe.glowAttached);
        QVERIFY(probe.monitor.isEmpty());
    }

    void parseIpcStatusJsonReadsState()
    {
        const QByteArray sample = R"({
            "mode": "expanded",
            "page": "agent",
            "screen": "HDMI-A-1",
            "surfaceReady": true,
            "sessions": 2
        })";

        const auto status = Backend::parseIpcStatusJson(sample);
        QVERIFY(status.valid);
        QCOMPARE(status.mode, QString("expanded"));
        QCOMPARE(status.page, QString("agent"));
        QCOMPARE(status.screen, QString("HDMI-A-1"));
        QVERIFY(status.surfaceReady);
        QCOMPARE(status.sessions, 2);
    }

    void readHoverExpandConfigReadsFocusMode()
    {
        QTemporaryDir dir;
        const QString path = dir.filePath("dynamic-island.json");
        bool exists = true;
        QCOMPARE(Backend::readHoverExpandConfig(path, &exists), true);
        QVERIFY(!exists);

        write(path, R"({"hoverExpand": false})");
        QCOMPARE(Backend::readHoverExpandConfig(path, &exists), false);
        QVERIFY(exists);

        write(path, "{bad json");
        QCOMPARE(Backend::readHoverExpandConfig(path, &exists), true);
        QVERIFY(!exists);
    }

    void backendRefreshFocusAndReviveEscalation()
    {
        QTemporaryDir dir;
        const QString configPath = dir.filePath("dynamic-island.json");
        const QString layerState = dir.filePath("layers.json");
        const QString ipcState = dir.filePath("ipc.json");
        const QString hyprctl = dir.filePath("hyprctl");
        const QString shell = dir.filePath("omarchy-shell");
        const QString restart = dir.filePath("omarchy-restart-shell");
        const QString focus = dir.filePath("omarchy-toggle-focus-mode");

        write(configPath, R"({"hoverExpand": true})");
        write(layerState, R"({"DP-1":{"levels":{"2":[{"namespace":"dynamic-island-glow"}],"3":[{"namespace":"dynamic-island"}]}}})");
        write(ipcState, R"({"mode":"compact","page":"home","screen":"DP-1","surfaceReady":true})");

        writeScript(hyprctl, "#!/bin/sh\ncat '" + layerState.toUtf8() + "'\n");
        writeScript(shell, "#!/bin/sh\n"
                           "if [ \"$1\" = \"dynamicisland\" ] && [ \"$2\" = \"status\" ]; then cat '" + ipcState.toUtf8() + "'; exit 0; fi\n"
                           "if [ \"$1\" = \"dynamicisland\" ] && [ \"$2\" = \"recoverSurface\" ]; then exit 0; fi\n"
                           "exit 0\n");
        writeScript(restart, "#!/bin/sh\n"
                             "printf '{\"DP-1\":{\"levels\":{\"2\":[{\"namespace\":\"dynamic-island-glow\"}],\"3\":[{\"namespace\":\"dynamic-island\"}]}}}' > '" + layerState.toUtf8() + "'\n"
                             "printf '{\"mode\":\"compact\",\"page\":\"home\",\"screen\":\"DP-1\",\"surfaceReady\":true}' > '" + ipcState.toUtf8() + "'\n");
        writeScript(focus, "#!/bin/sh\n"
                           "printf '{\"hoverExpand\": false}\\n' > '" + configPath.toUtf8() + "'\n");

        Backend::Options opt;
        opt.configPath = configPath;
        opt.hyprctl = hyprctl;
        opt.omarchyShell = shell;
        opt.restartShellCmd = restart;
        opt.toggleFocusCmd = focus;
        opt.settleStepMs = 20;

        Backend backend(opt);
        QSignalSpy probesSpy(&backend, &Backend::probesFinished);
        backend.refresh();
        QVERIFY(probesSpy.wait(2000));

        QVERIFY(backend.layerAttached());
        QVERIFY(backend.glowAttached());
        QCOMPARE(backend.layerMonitor(), QString("DP-1"));
        QVERIFY(backend.ipcOnline());
        QCOMPARE(backend.stateLevel(), QString("ok"));
        QVERIFY(!backend.focusMode());

        // Focus mode toggle updates config & property.
        QSignalSpy actionSpy(&backend, &Backend::actionCompleted);
        backend.toggleFocusMode();
        QVERIFY(actionSpy.wait(2000));
        QCOMPARE(actionSpy.takeFirst().at(0).toBool(), true);
        QVERIFY(backend.focusMode());

        // Simulate surface detachment while IPC answers ok; recoverSurface leaves
        // it detached so Backend automatically escalates to restartShell().
        write(layerState, R"({"DP-1":{"levels":{"2":[]}}})");
        backend.reviveSurface();
        QVERIFY(actionSpy.wait(3000));
        QCOMPARE(actionSpy.takeFirst().at(0).toBool(), true);
        QVERIFY(backend.layerAttached());
        QCOMPARE(backend.stateLevel(), QString("ok"));
        QVERIFY(backend.lastError().isEmpty());
    }

    void backendSurfacesRestartErrorLoudly()
    {
        QTemporaryDir dir;
        const QString restart = dir.filePath("omarchy-restart-shell");
        writeScript(restart, "#!/bin/sh\necho 'Refusing to restart while locked.' >&2\nexit 1\n");

        Backend::Options opt;
        opt.configPath = dir.filePath("missing.json");
        opt.restartShellCmd = restart;

        Backend backend(opt);
        QSignalSpy actionSpy(&backend, &Backend::actionCompleted);
        backend.restartShell();
        QVERIFY(actionSpy.wait(2000));
        QCOMPARE(actionSpy.takeFirst().at(0).toBool(), false);
        QVERIFY(backend.lastError().contains("locked"));
    }

    void themeFallsBack()
    {
        QTemporaryDir dir;
        Theme theme(dir.path());
        QCOMPARE(theme.accent(), QString("#FFD60A"));
        QCOMPARE(theme.accentForeground(), QString("black"));
        QCOMPARE(theme.background(), QString("#0e0e10"));
    }

    void themeReadsAccentAndDarkBackground()
    {
        QTemporaryDir dir;
        QDir(dir.path()).mkpath("theme");
        write(dir.path() + "/theme/colors.toml", "accent = \"#112233\"\nbackground = \"#0c0b0c\"\nforeground = \"#fafcfb\"\n");

        Theme theme(dir.path());
        QCOMPARE(theme.accent(), QString("#112233"));
        QCOMPARE(theme.accentForeground(), QString("white"));
        QCOMPARE(theme.background(), QString("#0c0b0c"));
        QCOMPARE(theme.foreground(), QString("#fafcfb"));
    }

    void themeFollowsHyprlandRounding()
    {
        QTemporaryDir dir;
        const QString response = dir.filePath("response.json"), command = dir.filePath("hyprctl");
        writeScript(command, "#!/bin/sh\ncat '" + response.toUtf8() + "'\n");
        write(response, "{\"int\":0}");

        Theme theme(dir.path(), nullptr, command);
        QCOMPARE(theme.radius(), 0);
        write(response, "{\"int\":6}");
        QTRY_COMPARE(theme.radius(), 6);
    }

    void translatorFallsBackToEnglish()
    {
        QTemporaryDir dir;
        Translator translator(dir.path() + "/language", dir.path());
        QCOMPARE(translator.language(), QString("en"));
        QVERIFY(translator.translate("Main", "Restart Dynamic Island").isNull());
    }

    void translatorFollowsTheLanguageFile()
    {
        QTemporaryDir dir;
        write(dir.path() + "/language", "pt-BR\n");
        write(dir.path() + "/pt.json", R"({"Save": "Guardar", "Open": "Abrir"})");
        write(dir.path() + "/pt-BR.json", R"({"Save": "Salvar"})");

        Translator translator(dir.path() + "/language", dir.path());
        QCOMPARE(translator.language(), QString("pt-BR"));
        QCOMPARE(translator.translate("Main", "Save"), QString("Salvar"));
        QCOMPARE(translator.translate("Main", "Open"), QString("Abrir"));
        QVERIFY(translator.translate("Main", "Quit").isNull());
    }

    void translatorPicksPluralForms()
    {
        QTemporaryDir dir;
        write(dir.path() + "/language", "ru\n");
        write(dir.path() + "/en.json", R"({"%n clips": {"one": "%n clip", "other": "%n clips"}})");
        write(dir.path() + "/ru.json", R"({"%n clips": {"one": "%n клип", "few": "%n клипа", "many": "%n клипов", "other": "%n клипа"}})");

        Translator translator(dir.path() + "/language", dir.path());
        QCOMPARE(translator.translate("Main", "%n clips", nullptr, 21), QString("%n клип"));
        QCOMPARE(translator.translate("Main", "%n clips", nullptr, 22), QString("%n клипа"));
        QCOMPARE(translator.translate("Main", "%n clips", nullptr, 25), QString("%n клипов"));
        QCOMPARE(Translator::pluralCategory("ar", 11), QString("many"));
        QCOMPARE(Translator::pluralCategory("ja", 1), QString("other"));
    }

    void mainQmlLoadsWithoutWarnings()
    {
        QTemporaryDir dir;
        QQuickStyle::setStyle("Material");

        QStringList warnings;
        gCapturedWarnings = &warnings;
        gPrevHandler = qInstallMessageHandler(captureQtWarnings);

        Translator translator(dir.path() + "/language");
        Theme theme(dir.path());
        Backend::Options opt;
        opt.configPath = dir.filePath("dynamic-island.json");
        Backend backend(opt);

        QQmlApplicationEngine engine;
        engine.rootContext()->setContextProperty("translator", &translator);
        engine.rootContext()->setContextProperty("theme", &theme);
        engine.rootContext()->setContextProperty("backend", &backend);
        engine.load(QUrl("qrc:/Main.qml"));

        qInstallMessageHandler(gPrevHandler);
        gCapturedWarnings = nullptr;

        QVERIFY2(!engine.rootObjects().isEmpty(), "Failed to load qrc:/Main.qml");
        QVERIFY2(warnings.isEmpty(), qPrintable("Unexpected Qt/QML warnings:\n" + warnings.join('\n')));
    }

private:
    static void write(const QString &path, const QByteArray &contents)
    {
        QFile file(path);
        QVERIFY(file.open(QIODevice::WriteOnly));
        QCOMPARE(file.write(contents), contents.size());
    }

    static void writeScript(const QString &path, const QByteArray &contents)
    {
        write(path, contents);
        QVERIFY(QFile::setPermissions(path, QFile::ReadOwner | QFile::WriteOwner | QFile::ExeOwner));
    }
};

QTEST_MAIN(DynamicIslandTests)
#include "dynamic_island_tests.moc"
