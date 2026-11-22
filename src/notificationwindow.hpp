#pragma once

#include <QObject>

class QQmlEngine;
class QQuickItem;
class QQuickWindow;
class NotificationServer;
namespace LayerShellQt { class Window; }

// 独立的 layer-shell 通知窗口（不挂在 HUD 主窗口下，
// 所以 HUD 在后台时通知也能显示在右上角）。
class NotificationWindow final : public QObject
{
    Q_OBJECT
public:
    explicit NotificationWindow(QQmlEngine *engine, NotificationServer *server, QObject *parent = nullptr);

private:
    void refresh();

    QQmlEngine *m_engine;
    NotificationServer *m_server;
    QQuickWindow *m_window = nullptr;
    QQuickItem *m_item = nullptr;
    LayerShellQt::Window *m_layer = nullptr;
};
