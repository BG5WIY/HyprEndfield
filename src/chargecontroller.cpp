#include "chargecontroller.hpp"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QProcess>
#include <QRegularExpression>
#include <QStandardPaths>

namespace {
const QString programName = QStringLiteral("endfield-charge-plus-for-linux");
}

ChargeController::ChargeController(QObject *parent, QString executable, QString settingsPath)
    : QObject(parent) {
    if (!executable.isEmpty()) m_executable = executable;
    if (settingsPath.isEmpty()) {
        const auto data = qEnvironmentVariable("XDG_DATA_HOME");
        const auto base = data.isEmpty() ? QDir::homePath() + QStringLiteral("/.local/share") : data;
        settingsPath = base + QStringLiteral("/EndfieldChargePlus/settings.json");
    }
    m_settingsPath = settingsPath;
    refresh();
}

QString ChargeController::detectExecutable() const {
    const auto override = qEnvironmentVariable("ENDFIELD_CHARGE_PLUS");
    if (!override.isEmpty() && QFileInfo(override).isExecutable()) return override;

    const auto onPath = QStandardPaths::findExecutable(programName);
    if (!onPath.isEmpty()) return onPath;

    const QStringList candidates{
        QDir::homePath() + QStringLiteral("/.local/bin/") + programName,
        QStringLiteral("/usr/local/bin/") + programName,
        QStringLiteral("/usr/bin/") + programName,
        QStringLiteral("/opt/endfield-charge-plus/") + programName,
        QStringLiteral("/opt/EndfieldChargePlus/") + programName,
    };
    for (const auto &candidate : candidates)
        if (QFileInfo(candidate).isExecutable()) return candidate;

    // AppImage 发行版：在常见目录里找名字里带 Endfield / Charge 的 AppImage。
    const QStringList folders{QDir::homePath() + QStringLiteral("/Applications"),
                              QDir::homePath() + QStringLiteral("/Downloads"),
                              QDir::homePath() + QStringLiteral("/.local/bin")};
    for (const auto &folder : folders) {
        const QDir directory(folder);
        if (!directory.exists()) continue;
        const auto files = directory.entryInfoList({QStringLiteral("*.AppImage")}, QDir::Files, QDir::Name);
        for (const auto &file : files) {
            const auto name = file.fileName();
            if (name.contains(QStringLiteral("ndfield"), Qt::CaseInsensitive)
                || name.contains(QStringLiteral("harge"), Qt::CaseInsensitive))
                return file.absoluteFilePath();
        }
    }
    return {};
}

bool ChargeController::processRunning() const {
    if (!m_installed) return false;
    const auto name = QFileInfo(m_executable).fileName();
    const auto pattern = QRegularExpression::escape(name);
    QProcess process;
    process.start(QStringLiteral("pgrep"), {QStringLiteral("-f"), pattern});
    return process.waitForFinished(1200) && process.exitCode() == 0;
}

void ChargeController::loadSettings() {
    m_settings.clear();
    QJsonObject root;
    QFile file(m_settingsPath);
    const bool exists = file.exists();
    if (exists && file.open(QIODevice::ReadOnly)) {
        const auto document = QJsonDocument::fromJson(file.readAll());
        root = document.object();
    }
    const auto custom = root.value(QStringLiteral("CustomHud")).toObject();
    const auto profiles = custom.value(QStringLiteral("Profiles")).toArray();
    const auto activeId = custom.value(QStringLiteral("ActiveProfileId")).toString();
    QString profileName;
    for (const auto &entry : profiles) {
        const auto profile = entry.toObject();
        if (profile.value(QStringLiteral("Id")).toString() == activeId) {
            profileName = profile.value(QStringLiteral("Name")).toString();
            break;
        }
    }
    if (profileName.isEmpty() && !profiles.isEmpty())
        profileName = profiles.first().toObject().value(QStringLiteral("Name")).toString();

    m_settings = {
        {QStringLiteral("installed"), m_installed},
        {QStringLiteral("running"), m_running},
        {QStringLiteral("settingsExists"), exists},
        {QStringLiteral("hudEnabled"), root.value(QStringLiteral("HudEnabled")).toBool(true)},
        {QStringLiteral("globalScale"), root.value(QStringLiteral("GlobalScale")).toDouble(0.8)},
        {QStringLiteral("displayDuration"), root.value(QStringLiteral("DisplayDurationSeconds")).toDouble(6.0)},
        {QStringLiteral("hudOpacity"), root.value(QStringLiteral("HudOpacity")).toDouble(1.0)},
        {QStringLiteral("alwaysVisible"), root.value(QStringLiteral("AlwaysVisible")).toBool(false)},
        {QStringLiteral("clickToCycle"), root.value(QStringLiteral("ClickToCycle")).toBool(false)},
        {QStringLiteral("samplingInterval"), root.value(QStringLiteral("SamplingIntervalSeconds")).toDouble(1.0)},
        {QStringLiteral("autoCycle"), custom.value(QStringLiteral("AutoCycle")).toBool(false)},
        {QStringLiteral("cycleSeconds"), custom.value(QStringLiteral("CycleSeconds")).toInt(10)},
        {QStringLiteral("hudPosition"), root.value(QStringLiteral("HudPosition")).toInt(1)},
        {QStringLiteral("hudCustomX"), root.value(QStringLiteral("HudCustomX")).toInt(0)},
        {QStringLiteral("hudCustomY"), root.value(QStringLiteral("HudCustomY")).toInt(0)},
        {QStringLiteral("profileName"), profileName},
        {QStringLiteral("profileCount"), profiles.size()},
    };
}

void ChargeController::refresh() {
    m_executable = m_executable.isEmpty() ? detectExecutable() : m_executable;
    if (!QFileInfo(m_executable).isExecutable()) m_executable = detectExecutable();
    m_installed = QFileInfo(m_executable).isExecutable();
    m_running = processRunning();
    loadSettings();
    emit changed();
}

bool ChargeController::launch() {
    if (!m_installed) {
        setError(tr("Endfield Charge Plus is not installed"));
        return false;
    }
    if (processRunning()) {
        refresh();
        return true;
    }
    if (!QProcess::startDetached(m_executable, {})) {
        setError(tr("Cannot start Endfield Charge Plus"));
        return false;
    }
    m_running = true;
    m_settings[QStringLiteral("running")] = true;
    emit changed();
    return true;
}

bool ChargeController::stop() {
    if (!m_installed) return false;
    if (!processRunning()) {
        m_running = false;
        m_settings[QStringLiteral("running")] = false;
        emit changed();
        return true;
    }
    const auto name = QFileInfo(m_executable).fileName();
    QProcess::execute(QStringLiteral("pkill"), {QStringLiteral("-f"), QRegularExpression::escape(name)});
    m_running = false;
    m_settings[QStringLiteral("running")] = false;
    emit changed();
    return true;
}

bool ChargeController::openSettings() {
    if (!m_installed) {
        setError(tr("Endfield Charge Plus is not installed"));
        return false;
    }
    // 再次启动会通知已在运行的实例打开设置窗口；未运行时先拉起来。
    if (!QProcess::startDetached(m_executable, {})) {
        setError(tr("Cannot open Endfield Charge Plus settings"));
        return false;
    }
    m_running = true;
    m_settings[QStringLiteral("running")] = true;
    emit changed();
    return true;
}

bool ChargeController::save(const QVariantMap &values) {
    QFile file(m_settingsPath);
    if (!file.exists()) {
        setError(tr("Run Endfield Charge Plus once to create its settings file"));
        return false;
    }
    if (!file.open(QIODevice::ReadOnly)) {
        setError(tr("Cannot read Endfield Charge Plus settings"));
        return false;
    }
    const auto document = QJsonDocument::fromJson(file.readAll());
    file.close();
    auto root = document.object();

    root[QStringLiteral("GlobalScale")] = values.value(QStringLiteral("globalScale"), 0.8).toDouble();
    root[QStringLiteral("DisplayDurationSeconds")] = values.value(QStringLiteral("displayDuration"), 6.0).toDouble();
    root[QStringLiteral("HudOpacity")] = values.value(QStringLiteral("hudOpacity"), 1.0).toDouble();
    root[QStringLiteral("AlwaysVisible")] = values.value(QStringLiteral("alwaysVisible"), false).toBool();
    root[QStringLiteral("ClickToCycle")] = values.value(QStringLiteral("clickToCycle"), false).toBool();
    root[QStringLiteral("SamplingIntervalSeconds")] = values.value(QStringLiteral("samplingInterval"), 1.0).toDouble();
    root[QStringLiteral("HudPosition")] = values.value(QStringLiteral("hudPosition"), 1).toInt();

    auto custom = root.value(QStringLiteral("CustomHud")).toObject();
    custom[QStringLiteral("AutoCycle")] = values.value(QStringLiteral("autoCycle"), false).toBool();
    custom[QStringLiteral("CycleSeconds")] = values.value(QStringLiteral("cycleSeconds"), 10).toInt();
    root[QStringLiteral("CustomHud")] = custom;

    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        setError(tr("Cannot write Endfield Charge Plus settings"));
        return false;
    }
    file.write(QJsonDocument(root).toJson(QJsonDocument::Indented));
    file.close();
    m_error.clear();
    loadSettings();
    emit changed();
    return true;
}

void ChargeController::clearError() {
    if (m_error.isEmpty()) return;
    m_error.clear();
    emit changed();
}

void ChargeController::setError(const QString &reason) {
    m_error = reason;
    emit failed(reason);
    emit changed();
}
