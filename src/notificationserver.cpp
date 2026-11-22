#include "notificationserver.hpp"

#include <QDBusConnection>
#include <QDateTime>
#include <QDir>
#include <QIcon>
#include <QPixmap>
#include <QStandardPaths>
#include <QVariantMap>

namespace {
constexpr int defaultTimeout = 7000;
constexpr int maxVisible = 5;
}

NotificationsAdaptor::NotificationsAdaptor(NotificationServer *server)
    : QDBusAbstractAdaptor(server), m_server(server)
{
}

uint NotificationsAdaptor::Notify(const QString &appName, uint replacesId, const QString &appIcon,
                                  const QString &summary, const QString &body,
                                  const QStringList &actions, const QVariantMap &hints,
                                  int expireTimeout)
{
    return m_server->add(appName, replacesId, appIcon, summary, body, actions, hints, expireTimeout);
}

void NotificationsAdaptor::CloseNotification(uint id)
{
    m_server->remove(id, 3);
}

QStringList NotificationsAdaptor::GetCapabilities()
{
    return {QStringLiteral("body"), QStringLiteral("body-markup"), QStringLiteral("actions")};
}

void NotificationsAdaptor::GetServerInformation(QString &name, QString &vendor,
                                                QString &version, QString &specVersion)
{
    name = QStringLiteral("HyprEndfield");
    vendor = QStringLiteral("HyprEndfield");
    version = QStringLiteral("1.0");
    specVersion = QStringLiteral("1.2");
}

NotificationServer::NotificationServer(QObject *parent) : QObject(parent)
{
    m_adaptor = new NotificationsAdaptor(this);
}

bool NotificationServer::registerService()
{
    auto bus = QDBusConnection::sessionBus();
    if (!bus.isConnected()) {
        qWarning("HyprEndfield: session bus unavailable, notifications disabled");
        return false;
    }
    if (!bus.registerService(QStringLiteral("org.freedesktop.Notifications"))) {
        qWarning("HyprEndfield: org.freedesktop.Notifications already owned (is mako running?)");
        return false;
    }
    return bus.registerObject(QStringLiteral("/org/freedesktop/Notifications"), this,
                              QDBusConnection::ExportAdaptors);
}

uint NotificationServer::add(const QString &appName, uint replacesId, const QString &appIcon,
                             const QString &summary, const QString &body,
                             const QStringList &actions, const QVariantMap &hints,
                             int expireTimeout)
{
    const uint id = replacesId != 0 ? replacesId : m_nextId++;
    const int timeout = expireTimeout < 0 ? defaultTimeout : expireTimeout;

    // 用通知的 app_icon（找不到时退回应用名）解析出图标文件给 QML 显示。
    QString iconPath;
    QString iconName = appIcon;
    if (iconName.isEmpty()) iconName = appName.toLower();
    if (iconName.endsWith(QLatin1String(".desktop"))) iconName.chop(8);
    if (!iconName.isEmpty()) {
        const QIcon icon = QIcon::fromTheme(iconName);
        if (!icon.isNull()) {
            const QString directory = QStandardPaths::writableLocation(QStandardPaths::CacheLocation)
                                      + QStringLiteral("/notification-icons");
            QDir().mkpath(directory);
            const QString path = directory + QLatin1Char('/')
                                 + QString(iconName).replace(QLatin1Char('/'), QLatin1Char('_')) + QStringLiteral(".png");
            icon.pixmap(64, 64).save(path);
            iconPath = path;
        }
    }

    const QVariantMap entry{
        {QStringLiteral("id"), id},
        {QStringLiteral("appName"), appName},
        {QStringLiteral("appIcon"), appIcon},
        {QStringLiteral("iconPath"), iconPath},
        {QStringLiteral("summary"), summary},
        {QStringLiteral("body"), body},
        {QStringLiteral("actions"), actions},
        {QStringLiteral("timeout"), timeout},
        {QStringLiteral("urgency"), hints.value(QStringLiteral("urgency"), 1).toInt()},
        {QStringLiteral("received"), QDateTime::currentMSecsSinceEpoch()},
    };

    int index = -1;
    for (int i = 0; i < m_notifications.size(); ++i)
        if (m_notifications.at(i).toMap().value(QStringLiteral("id")).toUInt() == id) { index = i; break; }
    if (index >= 0) m_notifications.replace(index, entry);
    else m_notifications.append(entry);

    while (m_notifications.size() > maxVisible) m_notifications.removeFirst();
    qWarning("notification received: %s / %s (total %d)", qUtf8Printable(summary), qUtf8Printable(body), int(m_notifications.size()));
    emit notificationsChanged();
    return id;
}

void NotificationServer::remove(uint id, uint reason)
{
    for (int i = 0; i < m_notifications.size(); ++i) {
        if (m_notifications.at(i).toMap().value(QStringLiteral("id")).toUInt() != id) continue;
        m_notifications.removeAt(i);
        emit notificationsChanged();
        emit m_adaptor->NotificationClosed(id, reason);
        return;
    }
}

void NotificationServer::close(int id)
{
    remove(uint(id), 3);
}

void NotificationServer::closeAll()
{
    const auto entries = m_notifications;
    for (const auto &entry : entries) remove(entry.toMap().value(QStringLiteral("id")).toUInt(), 2);
}
