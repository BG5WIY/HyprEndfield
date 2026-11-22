#include "wallpapercontroller.hpp"

#include <QCryptographicHash>
#include <QSet>
#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QFileInfo>
#include <QImage>
#include <QImageReader>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QPainter>
#include <QProcess>
#include <QStandardPaths>
#include <QThread>

#include <algorithm>

namespace {
constexpr int thumbWidth = 320;
constexpr int thumbHeight = 200;
const QString previewNames[] = {"preview.jpg", "preview.jpeg", "preview.png", "preview.gif"};
const QString staticSuffixes[] = {"jpg", "jpeg", "png", "webp", "avif", "bmp", "gif"};
const QString enginePattern = QStringLiteral("(^|/)linux-wallpaperengine( |$)");
}

WallpaperController::WallpaperController(QObject *parent, QString workshop, QString stateFile)
    : QObject(parent) {
    if (workshop.isEmpty()) {
        workshop = qEnvironmentVariable("WALLPAPER_WORKSHOP");
        if (workshop.isEmpty())
            workshop = QDir::homePath() + QStringLiteral("/.local/share/Steam/steamapps/workshop/content/431960");
    }
    m_workshop = workshop;
    if (stateFile.isEmpty()) {
        stateFile = QStandardPaths::writableLocation(QStandardPaths::GenericStateLocation)
                    + QStringLiteral("/waybar-endfield/wallpaper");
    }
    m_stateFile = stateFile;
    if (QFile file(m_stateFile); file.open(QIODevice::ReadOnly))
        m_current = QString::fromUtf8(file.readAll()).trimmed();
}

QString WallpaperController::shellQuote(const QString &value) {
    QString escaped = value;
    escaped.replace(QLatin1Char('\''), QStringLiteral("'\\''"));
    return QLatin1Char('\'') + escaped + QLatin1Char('\'');
}

// 后台进程的输出全部丢弃，否则会混进 HUD 自己的日志。
bool WallpaperController::runDetached(const QString &command) {
    return QProcess::startDetached(QStringLiteral("/bin/sh"),
                                   {QStringLiteral("-c"),
                                    QStringLiteral("exec %1 >/dev/null 2>&1 </dev/null").arg(command)});
}

QStringList WallpaperController::staticDirectories() {
    const auto override = qEnvironmentVariable("WALLPAPER_STATIC_DIRS");
    if (!override.isEmpty()) return override.split(QLatin1Char(':'), Qt::SkipEmptyParts);
    const auto home = QDir::homePath();
    return {home + QStringLiteral("/Pictures/wallpapers"),
            home + QStringLiteral("/Pictures/Wallpapers"),
            home + QStringLiteral("/图片/wallpapers"),
            home + QStringLiteral("/图片/壁纸"),
            home + QStringLiteral("/Wallpapers"),
            home + QStringLiteral("/wallpapers"),
            home + QStringLiteral("/Wallpaper"),
            home + QStringLiteral("/.local/share/wallpapers"),
            home + QStringLiteral("/.config/waybar-endfield/wallpapers")};
}

QString WallpaperController::readTitle(const QString &directory) {
    QFile file(directory + QStringLiteral("/project.json"));
    if (file.open(QIODevice::ReadOnly)) {
        const auto document = QJsonDocument::fromJson(file.readAll());
        const auto title = document.object().value(QStringLiteral("title")).toString().trimmed();
        if (!title.isEmpty()) return title;
    }
    return QFileInfo(directory).fileName();
}

QString WallpaperController::thumbnailFor(const QString &source, const QString &cacheRoot) {
    const QFileInfo info(source);
    if (!info.isReadable()) return {};
    const auto stamp = QStringLiteral("%1|%2|%3|%4")
                           .arg(source, QString::number(info.size()), QString::number(info.lastModified().toMSecsSinceEpoch()))
                           .arg(thumbWidth);
    const auto key = QString::fromLatin1(QCryptographicHash::hash(stamp.toUtf8(), QCryptographicHash::Md5).toHex().left(16));
    QDir cache(cacheRoot);
    cache.mkpath(QStringLiteral("."));
    const auto output = cache.filePath(QStringLiteral("thumb-") + key + QStringLiteral(".png"));
    if (QFileInfo::exists(output)) return output;

    QImageReader reader(source);
    reader.setAutoTransform(true);
    // GIF 只取第一帧；setScaledSize 让解码器直接缩小，避免整张 1920x1080 解出来。
    QSize target = reader.size();
    if (target.isValid()) target = target.scaled(thumbWidth, thumbHeight, Qt::KeepAspectRatio);
    if (target.isValid() && target.width() > 0 && target.height() > 0) reader.setScaledSize(target);
    QImage image = reader.read();
    if (image.isNull()) return {};

    QImage canvas(thumbWidth, thumbHeight, QImage::Format_ARGB32_Premultiplied);
    canvas.fill(QColor(QStringLiteral("#101110")));
    QPainter painter(&canvas);
    painter.setRenderHint(QPainter::SmoothPixmapTransform);
    const auto scaled = image.scaled(thumbWidth, thumbHeight, Qt::KeepAspectRatio, Qt::SmoothTransformation);
    painter.drawImage((thumbWidth - scaled.width()) / 2, (thumbHeight - scaled.height()) / 2, scaled);
    painter.end();
    if (!canvas.save(output, "PNG")) return {};
    return output;
}

void WallpaperController::scanWorkshop() {
    const QDir root(m_workshop);
    if (!root.exists()) return;
    const auto cacheRoot = QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + QStringLiteral("/wallpapers");
    const auto folders = root.entryInfoList(QDir::Dirs | QDir::NoDotAndDotDot, QDir::Name);
    for (const auto &folder : folders) {
        const QDir directory(folder.filePath());
        QString preview;
        for (const auto &name : previewNames) {
            const auto candidate = directory.filePath(name);
            if (QFileInfo::exists(candidate)) { preview = candidate; break; }
        }
        if (preview.isEmpty()) continue;
        const auto thumb = thumbnailFor(preview, cacheRoot);
        if (thumb.isEmpty()) continue;
        m_wallpapers.append(QVariantMap{
            {QStringLiteral("path"), folder.filePath()},
            {QStringLiteral("title"), readTitle(folder.filePath())},
            {QStringLiteral("thumb"), QUrl::fromLocalFile(thumb)},
            {QStringLiteral("current"), folder.filePath() == m_current},
        });
    }
}

void WallpaperController::scanStatic() {
    const auto cacheRoot = QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + QStringLiteral("/wallpapers");
    QSet<QString> seen;
    for (const auto &directory : staticDirectories()) {
        if (!QFileInfo(directory).isDir() || seen.contains(directory)) continue;
        seen.insert(directory);
        QDirIterator iterator(directory, QDir::Files, QDirIterator::Subdirectories);
        while (iterator.hasNext()) {
            const auto file = iterator.next();
            const auto suffix = QFileInfo(file).suffix().toLower();
            bool supported = false;
            for (const auto &candidate : staticSuffixes)
                if (suffix == candidate) { supported = true; break; }
            if (!supported) continue;
            const auto thumb = thumbnailFor(file, cacheRoot);
            if (thumb.isEmpty()) continue;
            m_wallpapers.append(QVariantMap{
                {QStringLiteral("path"), file},
                {QStringLiteral("title"), QFileInfo(file).fileName()},
                {QStringLiteral("thumb"), QUrl::fromLocalFile(thumb)},
                {QStringLiteral("current"), file == m_current},
            });
        }
    }
}

void WallpaperController::refresh(const QString &backend) {
    m_wallpapers.clear();
    if (backend == QLatin1String("wallpaperengine")) scanWorkshop();
    else scanStatic();
    std::sort(m_wallpapers.begin(), m_wallpapers.end(), [](const QVariant &a, const QVariant &b) {
        return a.toMap().value(QStringLiteral("title")).toString().localeAwareCompare(
                   b.toMap().value(QStringLiteral("title")).toString()) < 0;
    });
    emit changed();
}

QString WallpaperController::detectScreen() const {
    if (const auto override = qEnvironmentVariable("WALLPAPER_SCREEN"); !override.isEmpty()) return override;
    if (!qEnvironmentVariableIsEmpty("HYPRLAND_INSTANCE_SIGNATURE")) {
        QProcess process;
        process.start(QStringLiteral("hyprctl"), {QStringLiteral("-j"), QStringLiteral("monitors")});
        if (process.waitForFinished(1500) && process.exitCode() == 0) {
            const auto monitors = QJsonDocument::fromJson(process.readAllStandardOutput()).array();
            for (const auto &monitor : monitors) {
                const auto object = monitor.toObject();
                if (object.value(QStringLiteral("focused")).toBool())
                    return object.value(QStringLiteral("name")).toString();
            }
        }
    } else if (!qEnvironmentVariableIsEmpty("NIRI_SOCKET")) {
        QProcess process;
        process.start(QStringLiteral("niri"), {QStringLiteral("msg"), QStringLiteral("--json"), QStringLiteral("focused-output")});
        if (process.waitForFinished(1500) && process.exitCode() == 0) {
            const auto name = QJsonDocument::fromJson(process.readAllStandardOutput()).object().value(QStringLiteral("name")).toString();
            if (!name.isEmpty()) return name;
        }
    }
    return QStringLiteral("DP-3");
}

void WallpaperController::writeState(const QString &path) {
    if (m_stateFile.isEmpty()) return;
    QDir().mkpath(QFileInfo(m_stateFile).absolutePath());
    QFile file(m_stateFile);
    if (file.open(QIODevice::WriteOnly | QIODevice::Truncate)) file.write(path.toUtf8() + '\n');
}

bool WallpaperController::awwwDaemonRunning() {
    QProcess process;
    process.start(QStringLiteral("pgrep"), {QStringLiteral("-x"), QStringLiteral("awww-daemon")});
    return process.waitForFinished(1000) && process.exitCode() == 0;
}

bool WallpaperController::ensureAwwwDaemon() {
    if (awwwDaemonRunning()) return true;
    // 交给合成器启动：daemon 继承桌面会话的完整环境，也不会随 HUD 退出而结束。
    // Hyprland 的 Lua 配置下 dispatch 参数按 Lua 解析，先试传统 exec，再退回
    // hl.dsp.exec_cmd；niri 用 spawn action。
    if (!qEnvironmentVariableIsEmpty("HYPRLAND_INSTANCE_SIGNATURE")) {
        QProcess legacy;
        legacy.start(QStringLiteral("hyprctl"), {QStringLiteral("dispatch"), QStringLiteral("exec awww-daemon")});
        if (!legacy.waitForFinished(2000) || legacy.exitCode() != 0)
            QProcess::execute(QStringLiteral("hyprctl"),
                              {QStringLiteral("dispatch"), QStringLiteral("hl.dsp.exec_cmd(\"awww-daemon\")")});
    } else if (!qEnvironmentVariableIsEmpty("NIRI_SOCKET")) {
        QProcess::execute(QStringLiteral("niri"),
                          {QStringLiteral("msg"), QStringLiteral("action"), QStringLiteral("spawn"),
                           QStringLiteral("--"), QStringLiteral("awww-daemon")});
    } else {
        runDetached(QStringLiteral("awww-daemon"));
    }
    // 等 daemon 建好 socket；awww query 成功即视为就绪。
    for (int attempt = 0; attempt < 20; ++attempt) {
        QThread::msleep(150);
        QProcess query;
        query.start(QStringLiteral("awww"), {QStringLiteral("query")});
        const bool finished = query.waitForFinished(1000);
        if (finished && query.exitCode() == 0) { qWarning() << "awww: daemon ready after" << attempt; return true; }
    }
    return false;
}

bool WallpaperController::apply(const QString &path, const QString &backend, const QString &command) {
    if (m_busy) return false;
    const QFileInfo info(path);
    if (!info.isDir() && !info.isFile()) {
        setError(tr("Wallpaper not found: %1").arg(path));
        return false;
    }
    const bool isEngine = backend == QLatin1String("wallpaperengine");
    const bool isAwww = backend == QLatin1String("awww");
    const bool isCustom = backend == QLatin1String("custom");
    if (isCustom && command.trimmed().isEmpty()) {
        setError(tr("Set a custom wallpaper command first"));
        return false;
    }

    m_busy = true;
    emit busyChanged();
    m_error.clear();
    emit changed();
    if (qEnvironmentVariableIsEmpty("XDG_SESSION_TYPE")) qputenv("XDG_SESSION_TYPE", "wayland");

    // 从桌面会话自启时该变量存在；手工调试启动时补一个，否则引擎会拒绝启动。

    // awww 和自定义命令都不经过 Wallpaper Engine，先清掉它的图层避免叠加。
    if (!isEngine) {
        QProcess::execute(QStringLiteral("pkill"), {QStringLiteral("-f"), enginePattern});
        QThread::msleep(200);
    }

    if (isEngine) {
        // awww 的图层会盖住 Wallpaper Engine，切回动态壁纸前先撤掉它。
        if (awwwDaemonRunning()) {
            QProcess::execute(QStringLiteral("awww"), {QStringLiteral("kill")});
            QThread::msleep(150);
        }
        QProcess::execute(QStringLiteral("pkill"), {QStringLiteral("-f"), enginePattern});
        QThread::msleep(250);
        const auto screen = detectScreen();
        const QStringList arguments{QStringLiteral("--screen-root"), screen,
                                    QStringLiteral("--fps"), QStringLiteral("165"),
                                    QStringLiteral("--fullscreen-pause-only-active"),
                                    QStringLiteral("--scaling"), QStringLiteral("fill"),
                                    QStringLiteral("--clamp"), QStringLiteral("border"),
                                    path};
        QStringList quoted;
        for (const auto &argument : arguments) quoted << shellQuote(argument);
        if (!runDetached(QStringLiteral("linux-wallpaperengine ") + quoted.join(QLatin1Char(' ')))) {
            m_busy = false;
            emit busyChanged();
            setError(tr("Cannot start linux-wallpaperengine"));
            return false;
        }
    } else if (isAwww) {
        if (!ensureAwwwDaemon()) {
            m_busy = false;
            emit busyChanged();
            setError(tr("Cannot start awww-daemon"));
            return false;
        }
        if (!runDetached(QStringLiteral("awww img ") + shellQuote(path))) {
            m_busy = false;
            emit busyChanged();
            setError(tr("Cannot run awww"));
            return false;
        }
    } else {
        QString executed = command.trimmed();
        if (executed.contains(QStringLiteral("{path}"))) executed.replace(QStringLiteral("{path}"), shellQuote(path));
        else executed += QLatin1Char(' ') + shellQuote(path);
        if (!runDetached(executed)) {
            m_busy = false;
            emit busyChanged();
            setError(tr("Cannot run the custom wallpaper command"));
            return false;
        }
    }

    writeState(path);
    m_current = path;

    // 复刻原脚本的后置钩子：matugen 取色、overview 模糊缓存。
    QString hookSource = path;
    if (info.isDir()) {
        const QDir directory(info.filePath());
        for (const auto &name : previewNames) {
            const auto candidate = directory.filePath(name);
            if (QFileInfo::exists(candidate)) { hookSource = candidate; break; }
        }
    }
    const auto hook = QDir::homePath() + QStringLiteral("/.config/waybar-endfield/scripts/wallpaper-hook.sh");
    if (QFileInfo(hook).isExecutable() && qEnvironmentVariable("WALLPAPER_OVERVIEW", "1") != QLatin1String("0"))
        runDetached(QStringLiteral("bash ") + shellQuote(hook) + QLatin1Char(' ') + shellQuote(hookSource));
    if (!QStandardPaths::findExecutable(QStringLiteral("matugen")).isEmpty()
        && qEnvironmentVariable("WALLPAPER_MATUGEN", "1") != QLatin1String("0"))
        runDetached(QStringLiteral("matugen image ") + shellQuote(hookSource) + QStringLiteral(" --source-color-index 0"));

    markCurrent(path);
    m_busy = false;
    emit busyChanged();
    emit changed();
    emit applied(path);
    return true;
}

void WallpaperController::markCurrent(const QString &path) {
    for (auto &entry : m_wallpapers) {
        auto map = entry.toMap();
        map[QStringLiteral("current")] = map.value(QStringLiteral("path")).toString() == path;
        entry = map;
    }
}

void WallpaperController::clearError() {
    if (m_error.isEmpty()) return;
    m_error.clear();
    emit changed();
}

void WallpaperController::setError(const QString &reason) {
    m_error = reason;
    emit failed(reason);
    emit changed();
}
