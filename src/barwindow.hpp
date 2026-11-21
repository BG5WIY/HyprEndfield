#pragma once

#include <QObject>

class QQmlEngine;
class QQuickWindow;

// 常驻 layer-shell 顶部 bar：复刻 zmd-charge 的动画 pill（出现/展开/波纹/
// 轮播切换），数据来自 HUD 自己的 activityController / batteryController。
// Waybar 用的是 wlr-layer-shell，这里通过 LayerShellQt 走同一个协议。
class BarWindow final : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool enabled READ enabled WRITE setEnabled NOTIFY enabledChanged)
public:
    explicit BarWindow(QQmlEngine *engine, QObject *parent = nullptr);

    bool enabled() const { return m_enabled; }
    void setEnabled(bool enabled);

signals:
    void enabledChanged();

private:
    QQmlEngine *m_engine;
    QQuickWindow *m_window = nullptr;
    bool m_enabled = true;
};
