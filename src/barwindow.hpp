#pragma once

#include <QObject>

class QQmlEngine;
class QQuickItem;
class QQuickWindow;
class SettingsController;
namespace LayerShellQt { class Window; }

// 常驻 layer-shell 顶部 bar：复刻 zmd-charge 的动画 pill（出现/展开/波纹/
// 轮播切换），数据来自 HUD 自己的 activityController / batteryController。
// Waybar 用的是 wlr-layer-shell，这里通过 LayerShellQt 走同一个协议。
class BarWindow final : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool enabled READ enabled WRITE setEnabled NOTIFY enabledChanged)
public:
    explicit BarWindow(QQmlEngine *engine, SettingsController *settings, QObject *parent = nullptr);

    bool enabled() const { return m_enabled; }
    void setEnabled(bool enabled);

signals:
    void enabledChanged();

private:
    void updateGeometry();

    QQmlEngine *m_engine;
    SettingsController *m_settings = nullptr;
    QQuickWindow *m_window = nullptr;
    QQuickItem *m_item = nullptr;
    LayerShellQt::Window *m_layer = nullptr;
    bool m_enabled = true;
};
