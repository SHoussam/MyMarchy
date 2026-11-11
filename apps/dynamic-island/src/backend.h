#pragma once

#include <QFileSystemWatcher>
#include <QJsonObject>
#include <QObject>
#include <QProcess>
#include <QTimer>

class Backend : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool layerAttached READ layerAttached NOTIFY changed)
    Q_PROPERTY(bool glowAttached READ glowAttached NOTIFY changed)
    Q_PROPERTY(QString layerMonitor READ layerMonitor NOTIFY changed)
    Q_PROPERTY(bool ipcOnline READ ipcOnline NOTIFY changed)
    Q_PROPERTY(bool surfaceReady READ surfaceReady NOTIFY changed)
    Q_PROPERTY(QString islandMode READ islandMode NOTIFY changed)
    Q_PROPERTY(QString islandPage READ islandPage NOTIFY changed)
    Q_PROPERTY(QString islandScreen READ islandScreen NOTIFY changed)
    Q_PROPERTY(bool hoverExpand READ hoverExpand NOTIFY changed)
    Q_PROPERTY(bool focusMode READ focusMode NOTIFY changed)
    Q_PROPERTY(bool busy READ busy NOTIFY changed)
    Q_PROPERTY(QString busyAction READ busyAction NOTIFY changed)
    Q_PROPERTY(QString statusText READ statusText NOTIFY changed)
    Q_PROPERTY(QString lastError READ lastError NOTIFY changed)
    Q_PROPERTY(QString stateLevel READ stateLevel NOTIFY changed)

public:
    struct Options {
        QString configPath;
        QString hyprctl;
        QString omarchyShell;
        QString restartShellCmd;
        QString toggleFocusCmd;
        QString notifyCmd;
        bool autoPoll = false;
        int settleStepMs = 250;
    };

    struct LayerProbe {
        bool valid = false;
        bool islandAttached = false;
        bool glowAttached = false;
        QString monitor;
        QStringList allMonitors;
    };

    struct IpcStatus {
        bool valid = false;
        bool surfaceReady = false;
        QString mode;
        QString page;
        QString screen;
        int sessions = 0;
    };

    explicit Backend(QObject *parent = nullptr);
    explicit Backend(const Options &options, QObject *parent = nullptr);
    ~Backend() override;

    bool layerAttached() const { return m_layerAttached; }
    bool glowAttached() const { return m_glowAttached; }
    QString layerMonitor() const { return m_layerMonitor; }
    bool ipcOnline() const { return m_ipcOnline; }
    bool surfaceReady() const { return m_surfaceReady; }
    QString islandMode() const { return m_islandMode; }
    QString islandPage() const { return m_islandPage; }
    QString islandScreen() const { return m_islandScreen; }
    bool hoverExpand() const { return m_hoverExpand; }
    bool focusMode() const { return !m_hoverExpand; }
    bool busy() const { return m_busy; }
    QString busyAction() const { return m_busyAction; }
    QString statusText() const { return m_statusText; }
    QString lastError() const { return m_lastError; }
    QString stateLevel() const;
    bool healthy() const;

    void startPolling(int intervalMs = 2500);
    QJsonObject toJson() const;

    Q_INVOKABLE void refresh();
    Q_INVOKABLE void restartShell();
    Q_INVOKABLE void reviveSurface();
    Q_INVOKABLE void toggleExpand();
    Q_INVOKABLE void toggleFocusMode();
    Q_INVOKABLE void resetState();

    static Options defaultOptions();
    static LayerProbe parseLayersJson(const QByteArray &data);
    static IpcStatus parseIpcStatusJson(const QByteArray &data);
    static bool readHoverExpandConfig(const QString &path, bool *exists = nullptr);

signals:
    void changed();
    void probesFinished();
    void actionCompleted(bool ok);

private:
    void init();
    void setupWatcher();
    void readConfig();
    void launchRefreshProbes();
    void handleProbeFinished();
    void finishAction(bool ok, const QString &message = {}, const QString &error = {});
    void setError(const QString &error);
    void updateSummaryStatus();
    void sendToast(const QString &title, const QString &body);
    void configureProcessEnv(QProcess &proc) const;
    void runShellIpcAction(const QString &actionName, const QString &pendingStatus, const QStringList &args);
    void scheduleSettleCheck();

    Options m_opt;
    bool m_layerAttached = false;
    bool m_glowAttached = false;
    QString m_layerMonitor;
    bool m_ipcOnline = false;
    bool m_surfaceReady = false;
    QString m_islandMode = QStringLiteral("unknown");
    QString m_islandPage;
    QString m_islandScreen;
    bool m_hoverExpand = true;

    bool m_busy = false;
    QString m_busyAction;
    QString m_statusText;
    QString m_lastError;
    QString m_lastNotification;

    bool m_layerDone = true;
    bool m_ipcDone = true;
    int m_settleAttempt = 0;
    int m_settleMaxAttempts = 0;

    QProcess m_layerProc;
    QProcess m_ipcProc;
    QProcess m_actionProc;
    QTimer m_layerTimeout;
    QTimer m_ipcTimeout;
    QTimer m_actionTimeout;
    QTimer m_pollTimer;
    QTimer m_settleTimer;
    QTimer m_configDebounce;
    QFileSystemWatcher m_configWatcher;
};
