#pragma once

#include <QObject>
#include <QString>
#include <QVariantMap>

// 终末地充能 HUD（zmd-charge-plus-for-linux）的精简设置页后端。
// 数据源是它自己的 ~/.local/share/EndfieldChargePlus/settings.json，
// 保存时只覆盖本页管理的字段，其余字段原样保留。
class ChargeController final : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool installed READ installed NOTIFY changed)
    Q_PROPERTY(bool running READ running NOTIFY changed)
    Q_PROPERTY(QString executable READ executable NOTIFY changed)
    Q_PROPERTY(QString settingsPath READ settingsPath CONSTANT)
    Q_PROPERTY(QVariantMap settings READ settings NOTIFY changed)
    Q_PROPERTY(QString error READ error NOTIFY changed)
public:
    explicit ChargeController(QObject *parent = nullptr, QString executable = {}, QString settingsPath = {});

    bool installed() const { return m_installed; }
    bool running() const { return m_running; }
    QString executable() const { return m_executable; }
    QString settingsPath() const { return m_settingsPath; }
    QVariantMap settings() const { return m_settings; }
    QString error() const { return m_error; }

    Q_INVOKABLE void refresh();
    Q_INVOKABLE bool launch();
    Q_INVOKABLE bool stop();
    Q_INVOKABLE bool openSettings();
    Q_INVOKABLE bool save(const QVariantMap &values);
    Q_INVOKABLE void clearError();

signals:
    void changed();
    void failed(const QString &reason);
    // 打开设置窗口前，HUD 应先收起，否则全屏 overlay 会挡住它。
    void settingsRequested();

private:
    QString detectExecutable() const;
    bool processRunning() const;
    void loadSettings();
    void setError(const QString &reason);

    QString m_executable;
    QString m_settingsPath;
    QVariantMap m_settings;
    QString m_error;
    bool m_installed = false;
    bool m_running = false;
};
