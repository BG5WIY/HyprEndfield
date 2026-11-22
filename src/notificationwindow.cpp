#include "notificationwindow.hpp"
#include "notificationserver.hpp"

#include <LayerShellQt/Window>
#include <QQmlComponent>
#include <QQmlEngine>
#include <QQuickItem>
#include <QQuickWindow>

NotificationWindow::NotificationWindow(QQmlEngine *engine, NotificationServer *server, QObject *parent)
    : QObject(parent), m_engine(engine), m_server(server)
{
    m_window = new QQuickWindow;
    m_window->setColor(Qt::transparent);
    m_window->setFlags(Qt::FramelessWindowHint | Qt::WindowDoesNotAcceptFocus);
    m_window->resize(360, 120);

    m_layer = LayerShellQt::Window::get(m_window);
    m_layer->setScope(QStringLiteral("hyprendfield-notifications"));
    m_layer->setLayer(LayerShellQt::Window::LayerOverlay);
    m_layer->setAnchors({LayerShellQt::Window::AnchorTop, LayerShellQt::Window::AnchorRight});
    m_layer->setExclusiveZone(-1);
    m_layer->setKeyboardInteractivity(LayerShellQt::Window::KeyboardInteractivityNone);

    QQmlComponent component(engine, QUrl(QStringLiteral("qrc:/qt/qml/HyprEndfield/qml/NotificationWindow.qml")));
    if (auto *item = qobject_cast<QQuickItem *>(component.create())) {
        m_item = item;
        m_item->setParentItem(m_window->contentItem());
        m_item->setWidth(360);
        connect(m_item, &QQuickItem::implicitHeightChanged, this, &NotificationWindow::refresh);
    } else {
        qWarning("HyprEndfield: notification window QML failed: %s", qPrintable(component.errorString()));
    }

    connect(m_server, &NotificationServer::notificationsChanged, this, &NotificationWindow::refresh);
    m_window->setVisible(false);
}

void NotificationWindow::refresh()
{
    if (!m_window || !m_item) return;
    const int count = m_server->notifications().size();
    m_window->setVisible(count > 0);
    const int height = qCeil(m_item->implicitHeight());
    if (height > 0) {
        m_item->setHeight(height);
        m_window->resize(360, height);
    }
}
