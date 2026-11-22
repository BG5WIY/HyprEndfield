#include "barwindow.hpp"
#include "settingscontroller.hpp"

#include <LayerShellQt/Window>
#include <QGuiApplication>
#include <QQmlComponent>
#include <QQmlEngine>
#include <QQuickItem>
#include <QQuickWindow>
#include <QScreen>

BarWindow::BarWindow(QQmlEngine *engine, SettingsController *settings, QObject *parent)
    : QObject(parent), m_engine(engine), m_settings(settings) {
    m_window = new QQuickWindow;
    m_window->setColor(Qt::transparent);
    m_window->setFlags(Qt::FramelessWindowHint);
    m_window->setTitle(QStringLiteral("HyprEndfield Bar"));

    m_layer = LayerShellQt::Window::get(m_window);
    m_layer->setScope(QStringLiteral("hyprendfield-bar"));
    m_layer->setLayer(LayerShellQt::Window::LayerTop);
    // 只锚定顶部：窗口宽度由 pill 决定，compositor 水平居中，
    // 不再拉满整块屏幕宽度。
    m_layer->setAnchors({LayerShellQt::Window::AnchorTop});
    m_layer->setKeyboardInteractivity(LayerShellQt::Window::KeyboardInteractivityNone);

    m_window->resize(600, 160);

    QQmlComponent component(m_engine, QUrl(QStringLiteral("qrc:/qt/qml/HyprEndfield/qml/Bar.qml")));
    if (auto *item = qobject_cast<QQuickItem *>(component.create())) {
        m_item = item;
        m_item->setParentItem(m_window->contentItem());
        m_item->setWidth(600);
        m_item->setHeight(160);
    } else {
        qWarning() << "Bar.qml could not be created:" << component.errorString();
    }
    m_window->show();

    if (m_settings) {
        connect(m_settings, &SettingsController::preferenceChanged, this,
                [this](const QString &key, const QVariant &) {
                    if (key == QLatin1String("barScale")) updateGeometry();
                });
    }
    updateGeometry();
}

// 静息态按 pill 高度预留工作区；播放动画时占位不变，展开和波纹覆盖到
// 工作区里。输入区域只覆盖静息 pill，动画溢出部分和空白都不拦截点击。
void BarWindow::updateGeometry() {
    if (!m_window) return;
    const double raw = m_settings ? m_settings->value(QStringLiteral("barScale")).toDouble() : 1.0;
    const double scale = qBound(0.6, raw > 0 ? raw : 1.0, 1.5);
    const int pillWidth = qRound(560 * scale);
    const int windowWidth = pillWidth + 40;
    const int windowHeight = 160;
    const int restingBottom = qRound(14 + 60 * scale + 6);
    m_window->resize(windowWidth, windowHeight);
    if (m_layer) m_layer->setExclusiveZone(restingBottom);
    if (m_item) { m_item->setWidth(windowWidth); m_item->setHeight(windowHeight); }
    const QRect pillRect((windowWidth - pillWidth) / 2 - 8, 12, pillWidth + 16, qRound(60 * scale) + 8);
    m_window->setMask(QRegion(pillRect));
}

void BarWindow::setEnabled(bool enabled) {
    if (m_enabled == enabled) return;
    m_enabled = enabled;
    if (m_window) m_window->setVisible(enabled);
    emit enabledChanged();
}
