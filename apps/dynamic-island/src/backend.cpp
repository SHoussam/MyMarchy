#include "backend.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QProcessEnvironment>
#include <QStandardPaths>

namespace {

QString resolveTool(const QString &name, const QStringList &fallbacks = {}) {
    const QString path = QStandardPaths::findExecutable(name);
    if (!path.isEmpty())
        return path;
    for (const auto &candidate : fallbacks) {
        if (QFileInfo::exists(candidate) && QFileInfo(candidate).isExecutable())
            return candidate;
    }
    return {};
}

QString firstNonEmpty(const QString &a, const QString &b) {
    const QString ta = a.trimmed();
    return ta.isEmpty() ? b.trimmed() : ta;
}

} // namespace

Backend::Options Backend::defaultOptions() {
    const QString home = QDir::homePath();
    const QString omarchyPath = qEnvironmentVariable("OMARCHY_PATH", "/usr/share/omarchy");

    Options opt;
    opt.configPath = home + "/.config/omarchy/dynamic-island.json";
    opt.hyprctl = resolveTool("hyprctl");
    opt.omarchyShell = resolveTool("omarchy-shell", {omarchyPath + "/bin/omarchy-shell"});
    opt.restartShellCmd = resolveTool("omarchy-restart-shell", {omarchyPath + "/bin/omarchy-restart-shell"});
    opt.toggleFocusCmd = resolveTool("omarchy-toggle-focus-mode", {home + "/.local/bin/omarchy-toggle-focus-mode"});
    opt.notifyCmd = resolveTool("omarchy-notification-send", {omarchyPath + "/bin/omarchy-notification-send"});
    return opt;
}

Backend::Backend(QObject *parent)
    : Backend(defaultOptions(), parent) {}

Backend::Backend(const Options &options, QObject *parent)
    : QObject(parent), m_opt(options) {
    init();
}

Backend::~Backend() {
    auto stopProc = [](QProcess &p, int waitMs) {
        if (p.state() != QProcess::NotRunning) {
            p.kill();
            p.waitForFinished(waitMs);
        }
    };
    stopProc(m_layerProc, 500);
    stopProc(m_ipcProc, 500);
    stopProc(m_actionProc, m_busyAction == QStringLiteral("restart") ? 5000 : 1000);
}

void Backend::init() {
    m_statusText = tr("Checking Dynamic Island...");

    m_layerTimeout.setSingleShot(true);
    m_layerTimeout.setInterval(1500);
    connect(&m_layerTimeout, &QTimer::timeout, &m_layerProc, &QProcess::kill);

    m_ipcTimeout.setSingleShot(true);
    m_ipcTimeout.setInterval(1500);
    connect(&m_ipcTimeout, &QTimer::timeout, &m_ipcProc, &QProcess::kill);

    m_actionTimeout.setSingleShot(true);
    connect(&m_actionTimeout, &QTimer::timeout, &m_actionProc, &QProcess::kill);

    m_configDebounce.setSingleShot(true);
    m_configDebounce.setInterval(80);
    connect(&m_configWatcher, &QFileSystemWatcher::fileChanged, this, [this] { m_configDebounce.start(); });
    connect(&m_configWatcher, &QFileSystemWatcher::directoryChanged, this, [this] { m_configDebounce.start(); });
    connect(&m_configDebounce, &QTimer::timeout, this, [this] {
        setupWatcher();
        readConfig();
        emit changed();
    });

    connect(&m_layerProc, &QProcess::errorOccurred, this, [this](QProcess::ProcessError) {
        m_layerTimeout.stop();
        m_layerDone = true;
        handleProbeFinished();
    });
    connect(&m_layerProc, &QProcess::finished, this, [this](int code, QProcess::ExitStatus status) {
        m_layerTimeout.stop();
        const QByteArray raw = m_layerProc.readAllStandardOutput();
        if (code == 0 && status == QProcess::NormalExit) {
            const LayerProbe probe = parseLayersJson(raw);
            if (probe.valid) {
                m_layerAttached = probe.islandAttached;
                m_glowAttached = probe.glowAttached;
                m_layerMonitor = probe.monitor;
            }
        }
        m_layerDone = true;
        handleProbeFinished();
    });

    connect(&m_ipcProc, &QProcess::errorOccurred, this, [this](QProcess::ProcessError) {
        m_ipcTimeout.stop();
        m_ipcOnline = false;
        m_surfaceReady = false;
        m_islandMode = QStringLiteral("unknown");
        m_islandPage.clear();
        m_islandScreen.clear();
        m_ipcDone = true;
        handleProbeFinished();
    });
    connect(&m_ipcProc, &QProcess::finished, this, [this](int code, QProcess::ExitStatus status) {
        m_ipcTimeout.stop();
        const QByteArray raw = m_ipcProc.readAllStandardOutput();
        if (code == 0 && status == QProcess::NormalExit) {
            const IpcStatus parsed = parseIpcStatusJson(raw);
            if (parsed.valid) {
                m_ipcOnline = true;
                m_surfaceReady = parsed.surfaceReady;
                m_islandMode = parsed.mode.isEmpty() ? QStringLiteral("compact") : parsed.mode;
                m_islandPage = parsed.page;
                m_islandScreen = parsed.screen;
            } else {
                m_ipcOnline = false;
                m_surfaceReady = false;
                m_islandMode = QStringLiteral("unknown");
                m_islandPage.clear();
                m_islandScreen.clear();
            }
        } else {
            m_ipcOnline = false;
            m_surfaceReady = false;
            m_islandMode = QStringLiteral("unknown");
            m_islandPage.clear();
            m_islandScreen.clear();
        }
        m_ipcDone = true;
        handleProbeFinished();
    });

    connect(&m_actionProc, &QProcess::errorOccurred, this, [this](QProcess::ProcessError err) {
        m_actionTimeout.stop();
        const QString msg = err == QProcess::FailedToStart
            ? tr("Failed to start %1").arg(m_actionProc.program())
            : tr("Command failed: %1").arg(m_actionProc.errorString());
        finishAction(false, msg, msg);
    });

    connect(&m_actionProc, &QProcess::finished, this, [this](int code, QProcess::ExitStatus status) {
        m_actionTimeout.stop();
        const QString stderrText = QString::fromUtf8(m_actionProc.readAllStandardError());
        const QString stdoutText = QString::fromUtf8(m_actionProc.readAllStandardOutput());
        const QString errDetail = firstNonEmpty(stderrText, stdoutText);

        if (m_busyAction == QStringLiteral("restart")) {
            if (code != 0 || status != QProcess::NormalExit) {
                const QString msg = errDetail.isEmpty()
                    ? tr("Shell restart exited with code %1").arg(code)
                    : errDetail;
                finishAction(false, tr("Shell restart failed"), msg);
                return;
            }
            m_settleAttempt = 0;
            m_settleMaxAttempts = 12;
            m_statusText = tr("Waiting for Dynamic Island surface...");
            emit changed();
            launchRefreshProbes();
            m_settleTimer.start(m_opt.settleStepMs);
            return;
        }

        if (m_busyAction == QStringLiteral("revive")) {
            if (code != 0 || status != QProcess::NormalExit) {
                // IPC is unreachable or crashed: fall back to a full shell restart.
                m_busy = false;
                m_busyAction.clear();
                m_statusText = tr("IPC unreachable — restarting shell...");
                emit changed();
                restartShell();
                return;
            }
            m_settleAttempt = 0;
            m_settleMaxAttempts = 4;
            m_statusText = tr("Confirming surface re-attachment...");
            emit changed();
            launchRefreshProbes();
            m_settleTimer.start(m_opt.settleStepMs);
            return;
        }

        if (code != 0 || status != QProcess::NormalExit) {
            const QString msg = errDetail.isEmpty()
                ? tr("Action failed (exit %1)").arg(code)
                : errDetail;
            finishAction(false, tr("Command failed"), msg);
            return;
        }

        readConfig();
        launchRefreshProbes();

        QString doneMsg = tr("Done");
        if (m_busyAction == QStringLiteral("toggle"))
            doneMsg = tr("Toggled Dynamic Island");
        else if (m_busyAction == QStringLiteral("focus"))
            doneMsg = m_hoverExpand ? tr("Focus Mode disabled (hover opens)")
                                    : tr("Focus Mode enabled (click only)");
        else if (m_busyAction == QStringLiteral("reset"))
            doneMsg = tr("Dynamic Island state reset");

        finishAction(true, doneMsg);
    });

    m_settleTimer.setSingleShot(true);
    connect(&m_settleTimer, &QTimer::timeout, this, &Backend::scheduleSettleCheck);

    connect(&m_pollTimer, &QTimer::timeout, this, &Backend::refresh);

    setupWatcher();
    readConfig();
    if (m_opt.autoPoll)
        startPolling();
}

void Backend::configureProcessEnv(QProcess &proc) const {
    QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
    if (!env.contains(QStringLiteral("OMARCHY_PATH")) || env.value(QStringLiteral("OMARCHY_PATH")).isEmpty())
        env.insert(QStringLiteral("OMARCHY_PATH"), QStringLiteral("/usr/share/omarchy"));
    const QString home = QDir::homePath();
    const QString curPath = env.value(QStringLiteral("PATH"));
    const QString localBin = home + QStringLiteral("/.local/bin");
    const QString omarchyBin = env.value(QStringLiteral("OMARCHY_PATH")) + QStringLiteral("/bin");
    QStringList parts = curPath.split(':', Qt::SkipEmptyParts);
    if (!parts.contains(localBin))
        parts.prepend(localBin);
    if (!parts.contains(omarchyBin))
        parts.append(omarchyBin);
    env.insert(QStringLiteral("PATH"), parts.join(':'));
    proc.setProcessEnvironment(env);
}

void Backend::startPolling(int intervalMs) {
    m_pollTimer.setInterval(intervalMs);
    if (!m_pollTimer.isActive())
        m_pollTimer.start();
    refresh();
}

QString Backend::stateLevel() const {
    if (m_busy)
        return QStringLiteral("busy");
    if (m_layerAttached && m_ipcOnline)
        return QStringLiteral("ok");
    if (m_layerAttached || m_ipcOnline)
        return QStringLiteral("degraded");
    return QStringLiteral("offline");
}

bool Backend::healthy() const {
    return m_layerAttached && m_ipcOnline;
}

QJsonObject Backend::toJson() const {
    QJsonObject obj;
    obj.insert(QStringLiteral("healthy"), healthy());
    obj.insert(QStringLiteral("stateLevel"), stateLevel());
    obj.insert(QStringLiteral("layerAttached"), m_layerAttached);
    obj.insert(QStringLiteral("glowAttached"), m_glowAttached);
    obj.insert(QStringLiteral("layerMonitor"), m_layerMonitor);
    obj.insert(QStringLiteral("ipcOnline"), m_ipcOnline);
    obj.insert(QStringLiteral("surfaceReady"), m_surfaceReady);
    obj.insert(QStringLiteral("mode"), m_islandMode);
    obj.insert(QStringLiteral("page"), m_islandPage);
    obj.insert(QStringLiteral("screen"), m_islandScreen);
    obj.insert(QStringLiteral("hoverExpand"), m_hoverExpand);
    obj.insert(QStringLiteral("focusMode"), focusMode());
    obj.insert(QStringLiteral("statusText"), m_statusText);
    obj.insert(QStringLiteral("lastError"), m_lastError);
    return obj;
}

Backend::LayerProbe Backend::parseLayersJson(const QByteArray &data) {
    LayerProbe result;
    const QJsonDocument doc = QJsonDocument::fromJson(data);
    if (!doc.isObject())
        return result;

    result.valid = true;
    const QJsonObject root = doc.object();
    for (auto monIt = root.begin(); monIt != root.end(); ++monIt) {
        const QString monitorName = monIt.key();
        result.allMonitors.append(monitorName);
        const QJsonObject levels = monIt.value().toObject().value(QStringLiteral("levels")).toObject();
        for (auto lvIt = levels.begin(); lvIt != levels.end(); ++lvIt) {
            const QJsonArray arr = lvIt.value().toArray();
            for (const QJsonValue &entryVal : arr) {
                const QString ns = entryVal.toObject().value(QStringLiteral("namespace")).toString();
                if (ns == QStringLiteral("dynamic-island")) {
                    result.islandAttached = true;
                    result.monitor = monitorName;
                } else if (ns == QStringLiteral("dynamic-island-glow")) {
                    result.glowAttached = true;
                }
            }
        }
    }
    return result;
}

Backend::IpcStatus Backend::parseIpcStatusJson(const QByteArray &data) {
    IpcStatus result;
    const QJsonDocument doc = QJsonDocument::fromJson(data);
    if (!doc.isObject())
        return result;

    const QJsonObject obj = doc.object();
    if (!obj.contains(QStringLiteral("mode")))
        return result;

    result.valid = true;
    result.mode = obj.value(QStringLiteral("mode")).toString();
    result.page = obj.value(QStringLiteral("page")).toString();
    result.screen = obj.value(QStringLiteral("screen")).toString();
    result.surfaceReady = obj.value(QStringLiteral("surfaceReady")).toBool(false);
    result.sessions = obj.value(QStringLiteral("sessions")).toInt(0);
    return result;
}

bool Backend::readHoverExpandConfig(const QString &path, bool *exists) {
    QFile file(path);
    if (!file.exists()) {
        if (exists) *exists = false;
        return true;
    }
    if (!file.open(QIODevice::ReadOnly)) {
        if (exists) *exists = false;
        return true;
    }
    const QJsonDocument doc = QJsonDocument::fromJson(file.readAll());
    if (!doc.isObject()) {
        if (exists) *exists = false;
        return true;
    }
    if (exists) *exists = true;
    const QJsonObject obj = doc.object();
    return obj.contains(QStringLiteral("hoverExpand"))
        ? obj.value(QStringLiteral("hoverExpand")).toBool(true)
        : true;
}

void Backend::setupWatcher() {
    const QStringList existing = m_configWatcher.files() + m_configWatcher.directories();
    if (!existing.isEmpty())
        m_configWatcher.removePaths(existing);

    const QString dir = QFileInfo(m_opt.configPath).absolutePath();
    if (QFileInfo::exists(dir))
        m_configWatcher.addPath(dir);
    if (QFileInfo::exists(m_opt.configPath))
        m_configWatcher.addPath(m_opt.configPath);
}

void Backend::readConfig() {
    m_hoverExpand = readHoverExpandConfig(m_opt.configPath);
}

void Backend::refresh() {
    readConfig();
    launchRefreshProbes();
}

void Backend::launchRefreshProbes() {
    if (!m_layerDone || !m_ipcDone)
        return;

    m_layerDone = false;
    m_ipcDone = false;

    if (!m_opt.hyprctl.isEmpty() && m_layerProc.state() == QProcess::NotRunning) {
        configureProcessEnv(m_layerProc);
        m_layerProc.start(m_opt.hyprctl, {QStringLiteral("layers"), QStringLiteral("-j")});
        m_layerTimeout.start();
    } else if (m_opt.hyprctl.isEmpty()) {
        m_layerAttached = false;
        m_glowAttached = false;
        m_layerMonitor.clear();
        m_layerDone = true;
    }

    if (!m_opt.omarchyShell.isEmpty() && m_ipcProc.state() == QProcess::NotRunning) {
        configureProcessEnv(m_ipcProc);
        QProcessEnvironment env = m_ipcProc.processEnvironment();
        env.insert(QStringLiteral("OMARCHY_SHELL_IPC_TIMEOUT"), QStringLiteral("0.8s"));
        m_ipcProc.setProcessEnvironment(env);
        m_ipcProc.start(m_opt.omarchyShell, {QStringLiteral("dynamicisland"), QStringLiteral("status")});
        m_ipcTimeout.start();
    } else if (m_opt.omarchyShell.isEmpty()) {
        m_ipcOnline = false;
        m_surfaceReady = false;
        m_ipcDone = true;
    }

    if (m_layerDone && m_ipcDone)
        handleProbeFinished();
}

void Backend::handleProbeFinished() {
    if (!m_layerDone || !m_ipcDone)
        return;

    if (!m_busy)
        updateSummaryStatus();
    emit changed();
    emit probesFinished();
}

void Backend::updateSummaryStatus() {
    if (m_opt.hyprctl.isEmpty() || m_opt.omarchyShell.isEmpty()) {
        m_statusText = tr("Required Omarchy tools missing");
        return;
    }
    if (m_layerAttached && m_ipcOnline) {
        const QString screen = m_layerMonitor.isEmpty() ? m_islandScreen : m_layerMonitor;
        m_statusText = screen.isEmpty()
            ? tr("Running normally")
            : tr("Running on %1").arg(screen);
    } else if (m_ipcOnline && !m_layerAttached) {
        m_statusText = tr("Surface detached — press Space or V to recover");
    } else if (m_layerAttached && !m_ipcOnline) {
        m_statusText = tr("Layer present, shell IPC unresponsive");
    } else {
        m_statusText = tr("Dynamic Island stopped — press Space to restart");
    }
}

void Backend::setError(const QString &error) {
    m_lastError = error;
    emit changed();
}

void Backend::finishAction(bool ok, const QString &message, const QString &error) {
    m_busy = false;
    m_busyAction.clear();
    if (ok) {
        m_lastError.clear();
        if (!message.isEmpty())
            m_statusText = message;
        else
            updateSummaryStatus();
    } else {
        m_lastError = error;
        if (!message.isEmpty())
            m_statusText = message;
    }
    emit changed();
    emit actionCompleted(ok);
}

void Backend::sendToast(const QString &title, const QString &body) {
    if (m_opt.notifyCmd.isEmpty())
        return;
    QProcess::startDetached(m_opt.notifyCmd, {QStringLiteral("-g"), QStringLiteral("🏝"), title, body});
}

void Backend::scheduleSettleCheck() {
    if (!m_busy)
        return;

    if (!m_layerDone || !m_ipcDone) {
        m_settleTimer.start(100);
        return;
    }

    if (m_busyAction == QStringLiteral("revive")) {
        if (m_layerAttached && m_ipcOnline) {
            const QString mon = m_layerMonitor.isEmpty() ? tr("active display") : m_layerMonitor;
            finishAction(true, tr("Surface rebuilt on %1").arg(mon));
            return;
        }
        ++m_settleAttempt;
        if (m_settleAttempt < m_settleMaxAttempts) {
            launchRefreshProbes();
            m_settleTimer.start(m_opt.settleStepMs);
            return;
        }
        // Surface did not come back on its own; escalate to full shell restart.
        m_busy = false;
        m_busyAction.clear();
        restartShell();
        return;
    }

    if (m_busyAction == QStringLiteral("restart")) {
        if (m_layerAttached && m_ipcOnline) {
            const QString mon = m_layerMonitor.isEmpty() ? tr("active display") : m_layerMonitor;
            const QString msg = tr("Dynamic Island restarted on %1").arg(mon);
            sendToast(QStringLiteral("Dynamic Island"), msg);
            finishAction(true, msg);
            return;
        }
        ++m_settleAttempt;
        if (m_settleAttempt < m_settleMaxAttempts) {
            launchRefreshProbes();
            m_settleTimer.start(m_opt.settleStepMs);
            return;
        }
        if (m_ipcOnline && !m_layerAttached) {
            finishAction(false,
                         tr("Shell restarted, but Dynamic Island surface stayed detached"),
                         tr("Shell IPC responded, yet no dynamic-island Wayland layer attached."));
        } else {
            finishAction(false,
                         tr("Dynamic Island did not respond after restart"),
                         tr("Timed out waiting for dynamic-island layer and IPC."));
        }
    }
}

void Backend::restartShell() {
    if (m_busy)
        return;
    if (m_opt.restartShellCmd.isEmpty()) {
        setError(tr("omarchy-restart-shell was not found in PATH."));
        emit actionCompleted(false);
        return;
    }

    m_busy = true;
    m_busyAction = QStringLiteral("restart");
    m_lastError.clear();
    m_statusText = tr("Restarting shell and Dynamic Island...");
    emit changed();

    configureProcessEnv(m_actionProc);
    m_actionTimeout.setInterval(65000);
    m_actionProc.start(m_opt.restartShellCmd, {});
    m_actionTimeout.start();
}

void Backend::reviveSurface() {
    if (m_busy)
        return;
    if (m_opt.omarchyShell.isEmpty()) {
        restartShell();
        return;
    }

    m_busy = true;
    m_busyAction = QStringLiteral("revive");
    m_lastError.clear();
    m_statusText = tr("Rebuilding Dynamic Island surface...");
    emit changed();

    configureProcessEnv(m_actionProc);
    QProcessEnvironment env = m_actionProc.processEnvironment();
    env.insert(QStringLiteral("OMARCHY_SHELL_IPC_TIMEOUT"), QStringLiteral("1.5s"));
    m_actionProc.setProcessEnvironment(env);
    m_actionTimeout.setInterval(2500);
    m_actionProc.start(m_opt.omarchyShell, {QStringLiteral("dynamicisland"), QStringLiteral("recoverSurface")});
    m_actionTimeout.start();
}

void Backend::runShellIpcAction(const QString &actionName, const QString &pendingStatus, const QStringList &args) {
    if (m_busy)
        return;
    if (m_opt.omarchyShell.isEmpty()) {
        setError(tr("omarchy-shell was not found in PATH."));
        emit actionCompleted(false);
        return;
    }

    m_busy = true;
    m_busyAction = actionName;
    m_lastError.clear();
    m_statusText = pendingStatus;
    emit changed();

    configureProcessEnv(m_actionProc);
    m_actionTimeout.setInterval(3000);
    m_actionProc.start(m_opt.omarchyShell, args);
    m_actionTimeout.start();
}

void Backend::toggleExpand() {
    runShellIpcAction(QStringLiteral("toggle"),
                      tr("Toggling Dynamic Island..."),
                      {QStringLiteral("dynamicisland"), QStringLiteral("toggle")});
}

void Backend::resetState() {
    runShellIpcAction(QStringLiteral("reset"),
                      tr("Resetting Dynamic Island state..."),
                      {QStringLiteral("dynamicisland"), QStringLiteral("reset")});
}

void Backend::toggleFocusMode() {
    if (m_busy)
        return;
    if (m_opt.toggleFocusCmd.isEmpty()) {
        setError(tr("omarchy-toggle-focus-mode was not found."));
        emit actionCompleted(false);
        return;
    }

    m_busy = true;
    m_busyAction = QStringLiteral("focus");
    m_lastError.clear();
    m_statusText = tr("Toggling Focus Mode...");
    emit changed();

    configureProcessEnv(m_actionProc);
    m_actionTimeout.setInterval(3000);
    m_actionProc.start(m_opt.toggleFocusCmd, {});
    m_actionTimeout.start();
}
