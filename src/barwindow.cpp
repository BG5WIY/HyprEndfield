#include "barwindow.hpp"

#include <LayerShellQt/Window>
#include <QGuiApplication>
#include <QQmlComponent>
#include <QQmlEngine>
#include <QQuickItem>
#include <QQuickWindow>
#include <QScreen>

BarWindow::BarWindow(QQmlEngine *engine, QObject *parent)
    : QObject(parent), m_engine(engine) {
    m_window = new QQuickWindow;
    m_window->setColor(Qt::transparent);
    m_window->setFlags(Qt::FramelessWindowHint);
    m_window->setTitle(QStringLiteral("HyprEndfield Bar"));

    auto *layer = LayerShellQt::Window::get(m_window);
    layer->setScope(QStringLiteral("hyprendfield-bar"));
    layer->setLayer(LayerShellQt::Window::LayerTop);
    layer->setAnchors({LayerShellQt::Window::AnchorTop,
                       LayerShellQt::Window::AnchorLeft,
                       LayerShellQt::Window::AnchorRight});
    layer->setKeyboardInteractivity(LayerShellQt::Window::KeyboardInteractivityNone);
    // 悬浮 pill 不预留工作区，和原来的 zmd-charge bar 一致。
    layer->setExclusiveZone(0);

    const auto screen = QGuiApplication::primaryScreen();
    const auto width = screen ? screen->geometry().width() : 1920;
    m_window->resize(width, 160);

    QQmlComponent component(m_engine, QUrl(QStringLiteral("qrc:/qt/qml/HyprEndfield/qml/Bar.qml")));
    if (auto *item = qobject_cast<QQuickItem *>(component.create())) {
        item->setParentItem(m_window->contentItem());
        item->setWidth(width);
        item->setHeight(160);
    } else {
        qWarning() << "Bar.qml could not be created:" << component.errorString();
    }
    m_window->show();
}

void BarWindow::setEnabled(bool enabled) {
    if (m_enabled == enabled) return;
    m_enabled = enabled;
    if (m_window) m_window->setVisible(enabled);
    emit enabledChanged();
}
