#pragma once

#include <QObject>
#include <QString>
#include <QStringList>
#include <QVariantList>

// 壁纸库：支持三种后端。
//   wallpaperengine —— Wallpaper Engine 创意工坊（Steam appid 431960），
//                       用 linux-wallpaperengine 渲染；命令与
//                       ~/.config/waybar-endfield/scripts/wallpaper-picker.sh 一致。
//   awww             —— 静态图片/动图，用 awww + awww-daemon 渲染。
//   custom           —— 用户自定义命令模板，{path} 会被替换成选中壁纸的路径。
// 壁纸切换会写 ~/.local/state/waybar-endfield/wallpaper，因此和原来的 Waybar
// 切换器可以互相接续（登录恢复仍由原脚本负责）。
class WallpaperController final : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantList wallpapers READ wallpapers NOTIFY changed)
    Q_PROPERTY(QString currentPath READ currentPath NOTIFY changed)
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)
    Q_PROPERTY(QString error READ error NOTIFY changed)
public:
    explicit WallpaperController(QObject *parent = nullptr, QString workshop = {}, QString stateFile = {});

    QVariantList wallpapers() const { return m_wallpapers; }
    QString currentPath() const { return m_current; }
    bool busy() const { return m_busy; }
    QString error() const { return m_error; }

    // backend: wallpaperengine / awww / custom（custom 与 awww 都列静态图片）
    Q_INVOKABLE void refresh(const QString &backend = QStringLiteral("wallpaperengine"));
    // command 只在 custom 后端使用；其余后端忽略。
    Q_INVOKABLE bool apply(const QString &path, const QString &backend, const QString &command);
    Q_INVOKABLE void clearError();

signals:
    void changed();
    void busyChanged();
    void applied(const QString &path);
    void failed(const QString &reason);

private:
    static QString thumbnailFor(const QString &source, const QString &cacheRoot);
    static QString readTitle(const QString &directory);
    static QStringList staticDirectories();
    static bool awwwDaemonRunning();
    static bool ensureAwwwDaemon();
    static bool runDetached(const QString &command);
    static QString shellQuote(const QString &value);

    QString detectScreen() const;
    void writeState(const QString &path);
    void setError(const QString &reason);
    void scanWorkshop();
    void scanStatic();
    void markCurrent(const QString &path);

    QString m_workshop;
    QString m_stateFile;
    QString m_current;
    QString m_error;
    QVariantList m_wallpapers;
    bool m_busy = false;
};
