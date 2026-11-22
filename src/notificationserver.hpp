#pragma once

#include <QDBusAbstractAdaptor>
#include <QObject>
#include <QVariantList>

class NotificationServer;

// org.freedesktop.Notifications 的 D-Bus 适配器。
class NotificationsAdaptor final : public QDBusAbstractAdaptor
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.freedesktop.Notifications")
public:
    explicit NotificationsAdaptor(NotificationServer *server);

public slots:
    uint Notify(const QString &appName, uint replacesId, const QString &appIcon,
                const QString &summary, const QString &body, const QStringList &actions,
                const QVariantMap &hints, int expireTimeout);
    void CloseNotification(uint id);
    QStringList GetCapabilities();
    void GetServerInformation(QString &name, QString &vendor, QString &version, QString &specVersion);

signals:
    void NotificationClosed(uint id, uint reason);
    void ActionInvoked(uint id, const QString &action);

private:
    NotificationServer *m_server;
};

// 收通知、维护队列，供 HUD 的通知窗口显示。
class NotificationServer final : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVariantList notifications READ notifications NOTIFY notificationsChanged)
public:
    explicit NotificationServer(QObject *parent = nullptr);
    bool registerService();

    [[nodiscard]] QVariantList notifications() const { return m_notifications; }

    Q_INVOKABLE void close(int id);
    Q_INVOKABLE void closeAll();

signals:
    void notificationsChanged();

private:
    friend class NotificationsAdaptor;
    uint add(const QString &appName, uint replacesId, const QString &appIcon,
             const QString &summary, const QString &body, const QStringList &actions,
             const QVariantMap &hints, int expireTimeout);
    void remove(uint id, uint reason);

    QVariantList m_notifications;
    uint m_nextId = 1;
    NotificationsAdaptor *m_adaptor = nullptr;
};
