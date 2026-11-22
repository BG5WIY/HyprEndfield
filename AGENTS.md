# AGENTS.md

给在本仓库工作的 AI 代理和贡献者的说明。当前分支在 EndfieldHUD 移植的基础上加了顶部状态栏和通知窗口。

## 构建

```bash
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build --target hyprendfield -j"$(nproc)"
```

依赖见 `CMakeLists.txt` 里的 Qt6 组件和 pkg-config 名称；额外需要 LayerShellQt（`layer-shell-qt`）和 `libvterm`。

## 测试

`tests/` 目录不随仓库发布，因此公开仓库只能用 `-DBUILD_TESTING=OFF` 配置。本地有 `tests/` 时可以用 `-DBUILD_TESTING=ON` 再跑 `ctest --test-dir build --output-on-failure`。

翻译一致性检查：`node tools/check-translations.mjs`（当前应为 0）。

## 结构

- `qml/` 界面，`src/` 数据和系统功能，`assets/` 素材，`shaders/` 表盘着色器，`tools/` 素材导入脚本。
- 新增模块时要同时检查：`CMakeLists.txt`、`src/main.cpp`、`qml/MenuScene.qml`、`qml/WatchShell.qml`、`SettingsController::defaultModules()`、`qml/SystemPage.qml`、`qml/ModuleNumbering.js` 和 `src/localization_catalog.inc`。

## 约定

- 界面文案用 `qsTr()`，并同步 `src/localization_catalog.inc` 的翻译条目，`tools/check-translations.mjs` 需要为 0。
- 设置项在 `src/settingscontroller.cpp` 的 defaults 中声明。列表类型（如 `barProfiles`）必须在 `normalized()` 里单独处理，否则会落到 `toString()` 分支变成空字符串。
- 常驻的 layer-shell 窗口（顶部状态栏、通知窗口）用 C++ 创建独立的 `QQuickWindow` + `LayerShellQt::Window`，**不要**在 `Main.qml` 里用嵌套 `Window`：HUD 以 `--background` 运行时主窗口隐藏，子窗口会一起不可见。
- 终端视图是独立的 `QQuickPaintedItem`，字体需要 Nerd Font 回退（系统里通常用 `MesloLGS NF`），否则 p10k 图标显示为方块。
- `/proc` 文件的 stat size 为 0，不要用 `QFile::atEnd()` 循环，用 `readAll()`。

## 顶部状态栏

- `qml/Bar.qml`：轮播时间线（图标中央出现 → 圆环扩散 → 标题淡入 → 图标左移 → 内容出现），每项图标在 `qml/BarGlyph.qml`，时钟在 pill 中央。
- `src/barwindow.cpp`：layer-shell 窗口。exclusive zone 只按静息 pill 高度预留，动画期间占位不变；输入区域限制在 pill，超出部分点击穿透；圆环用 Canvas 按 pill 半径裁圆角。
- 设置项：`barEnabled`、`barInterval`、`barAnimation`、`barScale`、`barProfiles`（数组，顺序即轮播顺序）、`gpuSource`（-1 自动，否则 DRM 卡索引）。
- `qml/BarPage.qml`：状态栏设置页（轮播项、显卡来源、缩放等）。
- GPU 数据在 `src/activitycollector.cpp` 的 `gpuCards`（每张 DRM 卡的 busy 和 `pp_dpm_sclk` 频率）。

## 通知窗口

- `src/notificationserver.cpp`：实现 `org.freedesktop.Notifications`（Notify/CloseNotification/GetCapabilities/GetServerInformation）。
- `src/notificationwindow.cpp` + `qml/NotificationWindow.qml`：右上角独立 layer-shell 窗口，HUD 风格（斜切左下角、斜纹、应用图标、数字高亮、关闭按钮）。
- 取代 mako，运行前需要停掉 mako（否则服务名被占用）；Hyprland 用 `hyprctl dispatch 'hl.dsp.send_shortcut({mods="SUPER", key="ESCAPE"})'` 测试。
