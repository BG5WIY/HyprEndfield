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
    m_layer->setAnchors({LayerShellQt::Window::AnchorTop,
                         LayerShellQt::Window::AnchorLeft,
                         LayerShellQt::Window::AnchorRight});
    m_layer->setKeyboardInteractivity(LayerShellQt::Window::KeyboardInteractivityNone);

    const auto screen = QGuiApplication::primaryScreen();
    const auto width = screen ? screen->geometry().width() : 1920;
    m_window->resize(width, 160);

    QQmlComponent component(m_engine, QUrl(QStringLiteral("qrc:/qt/qml/HyprEndfield/qml/Bar.qml")));
    if (auto *item = qobject_cast<QQuickItem *>(component.create())) {
        m_item = item;
        m_item->setParentItem(m_window->contentItem());
        m_item->setWidth(width);
        m_item->setHeight(110);
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

// bar 占位（exclusive zone），窗口不会被覆盖；输入区域再限制到 pill 附近，
// 避免整块透明 surface 抢走点击。
void BarWindow::updateGeometry() {
    if (!m_window) return;
    const double raw = m_settings ? m_settings->value(QStringLiteral("barScale")).toDouble() : 1.0;
    const double scale = qBound(0.6, raw > 0 ? raw : 1.0, 1.5);
    const int width = qRound(560 * scale) + 24;
    const int windowHeight = qRound(14 + 90 * scale + 10);
    m_window->resize(m_window->width(), windowHeight);
    if (m_layer) m_layer->setExclusiveZone(windowHeight);
    if (m_item) m_item->setHeight(windowHeight);
    const QRect pillRect((m_window->width() - width) / 2, 10, width, windowHeight - 10);
    m_window->setMask(QRegion(pillRect));
}

void BarWindow::setEnabled(bool enabled) {
    if (m_enabled == enabled) return;
    m_enabled = enabled;
    if (m_window) m_window->setVisible(enabled);
    emit enabledChanged();
}
