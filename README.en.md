# HyprEndfield (upstream project: [EndfieldHUD](https://github.com/DDDuoDuo/EndfieldHUD))
<img width="2560" height="1440" alt="image" src="https://github.com/user-attachments/assets/2b3e0c09-18b4-426d-b2cf-ec177305d778" />

[简体中文](README.md) · **English** (Translated using DeepSeek)

# Linux users are welcome to file Issues / PRs

HyprEndfield ports the HUD interface of [EndfieldHUD](https://github.com/DDDuoDuo/EndfieldHUD) to Linux. The project uses C++20, Qt 6 / QML and LayerShellQt; it is developed and used daily on Arch Linux + Hyprland, and niri is supported as well.

The dial, cards, animations and assets follow the original project as closely as possible; the main dial uses EndfieldHUD's layered 3D assets. This repository currently ships source code only — there are no install packages.

## What it can do

- Display a full-screen HUD with a 3D dial, expand/collapse animations, parallax, tilt, themes, scaling, a clock, module ordering and show/hide toggles.
- Use notes, video notes, to-dos, drawing, the clipboard, the file shelf, the archive, the reader, the calendar, a quick terminal and app shortcuts.
- Control SPlayer and show its cover art, progress and lyrics; adjust audio devices and per-app volume.
- Process images and videos, draw on full-screen projections, show a dot-matrix background, place images and play videos.
- View storage, CPU, memory, GPU, network, battery and facility alerts, and use countdown/count-up focus modes.
- Link a Hypergryph account to show Endfield profile data and Arknights sanity; a standalone Linux custom profile card is also available.
- Play the “OrbiPom! MERGE!” mini-game and view the HUD's own event log.

The map module has been removed.

## Building and running

The complete dependency list lives in [CMakeLists.txt](CMakeLists.txt). Building requires CMake 3.25+, a C++20 compiler, Qt 6.8+, LayerShellQt, libpulse, libvterm 0.3.3+, Wayland, libsecret, PAM, libzip and GIO.

On Arch Linux you can install these packages:

```bash
sudo pacman -S --needed base-devel cmake ninja pkgconf \
  qt6-base qt6-declarative qt6-wayland qt6-shadertools \
  qt6-multimedia qt6-websockets qt6-webengine qt6-imageformats \
  layer-shell-qt libpulse libvterm wayland libsecret pam libzip glib2
```

Build and start:

```bash
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF
cmake --build build --target hyprendfield -j2
./build/bin/HyprEndfield --background
./build/bin/HyprEndfield --toggle
```

The program also accepts `--show`, `--hide` and `--quit`. Video features require FFmpeg, ffprobe and ffmpegthumbnailer; the storage page opens Dolphin by default; some file-paste operations require `wl-paste`.

## Desktop configuration

The HUD is a layer-shell Overlay surface that does not take focus like a normal window, so global hotkeys must be bound by the compositor. By default this project uses **Super + Esc** to open or close the HUD. Replace the program path below with your actual path.

Showing and hiding both go through the same `--toggle` command, which the single-instance socket forwards to the process that is already running.

### Hyprland

```lua
local hyprEndfield = "/absolute/path/to/HyprEndfield"

hl.bind("SUPER + ESCAPE", hl.dsp.exec_cmd(hyprEndfield .. " --toggle"))

hl.define_submap("hyprendfield", function()
    hl.bind("SUPER + ESCAPE", function()
        hl.dispatch(hl.dsp.submap("reset"))
        hl.dispatch(hl.dsp.exec_cmd(hyprEndfield .. " --toggle"))
    end)
    hl.bind("PRINT", hl.dsp.exec_cmd("hyprshot -m output"))
    hl.bind("CTRL + ALT + A", hl.dsp.exec_cmd("hyprshot -m region --clipboard-only --silent"))
end)

hl.layer_rule({
    name = "hyprendfield-frosted-background",
    match = { namespace = "^hyprendfield$" },
    blur = true,
    ignore_alpha = 0.1,
})
```

While the HUD is shown it switches to the `hyprendfield` submap and restores the normal keybinds when hidden.

### niri

niri's keybind table cannot be replaced at runtime, but niri supports `zwp_keyboard_shortcuts_inhibit_v1`: once the HUD gains focus it asks the compositor to inhibit shortcuts and releases them when hidden. So a single permanent binding is enough:

```kdl
binds {
    Mod+Escape allow-inhibiting=false { spawn "/absolute/path/to/HyprEndfield" "--toggle"; }
}
```

`allow-inhibiting=false` keeps this binding working while the HUD inhibits shortcuts; otherwise, once the HUD is open it could not be closed.

If this combination is already taken on your system (for example, it is bound to `toggle-keyboard-shortcuts-inhibit`), just pick another one, such as `Mod+Shift+Escape`.

To make the background blur work, add a layer-rule for this layer namespace:

```kdl
layer-rule {
    match namespace="^hyprendfield"
    geometry-corner-radius 8
    background-effect {
        xray false
        blur true
    }
}
```

Shortcut inhibition uses niri's `toggle-keyboard-shortcuts-inhibit` action, which is **a switch acting on the focused layer**, so it is only requested once the HUD has actually gained focus (see `ApplicationController::activateCompositorMode`). If focus has already moved elsewhere when exiting, the switch toggles the other way; opening the HUD again toggles it back, and the two cancel out. Pressing the action bound by niri yourself restores the default at any time.

### Other desktops

When neither desktop matches, the program still runs: the layer-shell part uses the standard protocol, global hotkeys must be bound by you, and shortcuts are not inhibited while the HUD is open (Esc only works when the HUD has focus). The window list inside the HUD (activity monitor) degrades to process-name matching on unsupported desktops.

## Not finished yet

- It has only been fully used on Arch Linux; Hyprland and niri are supported, other distributions and desktops need their own porting.
- There is no X11 backend, and no DEB, RPM, AUR or Flatpak package.
- Now-playing only recognizes SPlayer, and lyrics use SPlayer's dedicated interface.
- The “blur amount” slider does not take effect yet; the actual blur is controlled by the compositor's layer rules (Hyprland's `layer_rule`, niri's `layer-rule`).
- Media assembly does not support highlights, shadows, video stickers or HDR video export.
- The storage page only shows capacity information; it has no file categorization, large-file search, cleanup or partition operations.
- Focus timers keep running while the HUD is hidden and are not restored if the app exits.
- The update feature only checks for upstream commits; it does not download or install new versions automatically.

## Code navigation

[qml/](qml/) holds the interface, [src/](src/) holds data and system features, [assets/](assets/) holds assets, [shaders/](shaders/) holds the dial shaders, and [tools/](tools/) holds the asset import scripts.

### Program and main interface

- Program entry, single instance, tray and component registration: [src/main.cpp](src/main.cpp)
- Wayland layer, show/hide, screen selection and desktop integration (Hyprland submap / niri shortcut inhibition): [src/applicationcontroller.cpp](src/applicationcontroller.cpp), [qml/Main.qml](qml/Main.qml)
- Dial, menu and page loading: [qml/WatchShell.qml](qml/WatchShell.qml), [qml/MenuScene.qml](qml/MenuScene.qml)
- Card and menu geometry: [qml/MenuPlane.qml](qml/MenuPlane.qml), [qml/MenuCard.qml](qml/MenuCard.qml), [qml/MenuTile.qml](qml/MenuTile.qml), [qml/MenuGeometry.js](qml/MenuGeometry.js)
- 3D dial, camera, materials and shaders: [src/sourcedial.cpp](src/sourcedial.cpp), [assets/watch-dial/](assets/watch-dial/), [assets/watch/](assets/watch/), [shaders/](shaders/)
- Animation timing: [src/watchanimationcontroller.cpp](src/watchanimationcontroller.cpp), [assets/watch/clips.json](assets/watch/clips.json)
- System settings, display settings, module order and translations: [src/settingscontroller.cpp](src/settingscontroller.cpp), [qml/SystemPage.qml](qml/SystemPage.qml), [qml/DisplayPage.qml](qml/DisplayPage.qml), [src/localization_catalog.inc](src/localization_catalog.inc)
- MOD numbering: [qml/ModuleNumbering.js](qml/ModuleNumbering.js)

When adding a component, also check [CMakeLists.txt](CMakeLists.txt), `src/main.cpp`, `MenuScene.qml`, `WatchShell.qml`, `SettingsController::defaultModules()` and `SystemPage.qml`.

### Feature components

- Notes and video notes: [qml/NotesPage.qml](qml/NotesPage.qml), [qml/NotesWorkspace.qml](qml/NotesWorkspace.qml), [src/notescontroller.cpp](src/notescontroller.cpp)
- Clipboard: [qml/ClipboardPage.qml](qml/ClipboardPage.qml), [src/clipboardcontroller.cpp](src/clipboardcontroller.cpp)
- File shelf: [qml/FileShelfPage.qml](qml/FileShelfPage.qml), [src/fileshelfcontroller.cpp](src/fileshelfcontroller.cpp)
- Archive: [qml/ArchivePage.qml](qml/ArchivePage.qml), [src/archivecontroller.cpp](src/archivecontroller.cpp)
- Reader: [qml/ReaderPage.qml](qml/ReaderPage.qml), [src/readercontroller.cpp](src/readercontroller.cpp)
- Calendar and focus mode: [qml/CalendarPage.qml](qml/CalendarPage.qml), [src/calendarcontroller.cpp](src/calendarcontroller.cpp), [qml/FocusModePage.qml](qml/FocusModePage.qml), [src/focusmodecontroller.cpp](src/focusmodecontroller.cpp)
- Quick terminal: [qml/TerminalPage.qml](qml/TerminalPage.qml), [src/terminalsession.cpp](src/terminalsession.cpp), [src/terminalview.cpp](src/terminalview.cpp)
- Now playing and lyrics: [qml/NowPlayingPage.qml](qml/NowPlayingPage.qml), [src/nowplayingcontroller.cpp](src/nowplayingcontroller.cpp), [src/splayerlyrics.cpp](src/splayerlyrics.cpp)
- Volume: [qml/VolumePage.qml](qml/VolumePage.qml), [src/audiocontroller.cpp](src/audiocontroller.cpp)
- Media assembly: [qml/MediaAssemblyPage.qml](qml/MediaAssemblyPage.qml), [src/mediaeditor.cpp](src/mediaeditor.cpp), [src/mediaengine.cpp](src/mediaengine.cpp)
- Projection, drawing and dot-matrix background: [qml/ProjectionPage.qml](qml/ProjectionPage.qml), [qml/ProjectionWorkspace.qml](qml/ProjectionWorkspace.qml), [src/projectioncanvas.cpp](src/projectioncanvas.cpp)
- Storage, activity monitor and facility alerts: [qml/StoragePage.qml](qml/StoragePage.qml), [src/storagecontroller.cpp](src/storagecontroller.cpp), [qml/ActivityPage.qml](qml/ActivityPage.qml), [src/activitycollector.cpp](src/activitycollector.cpp), [src/facilitycontroller.cpp](src/facilitycontroller.cpp)
- Battery: [qml/BatteryBadge.qml](qml/BatteryBadge.qml), [src/batterycontroller.cpp](src/batterycontroller.cpp)
- The two profile cards: [qml/ProfilePage.qml](qml/ProfilePage.qml), [qml/MenuBadge.qml](qml/MenuBadge.qml), [qml/GameProfileBadge.qml](qml/GameProfileBadge.qml), [src/profilecontroller.cpp](src/profilecontroller.cpp)
- Account linking and sanity: [qml/AccountPage.qml](qml/AccountPage.qml), [src/accountcontroller.cpp](src/accountcontroller.cpp), [src/accountlogin.cpp](src/accountlogin.cpp), `src/endfield/modules/hypergryph_account_*`
- “OrbiPom! MERGE!”: [qml/OrbiPomPage.qml](qml/OrbiPomPage.qml), [src/orbipomcontroller.cpp](src/orbipomcontroller.cpp), [assets/orbipom/](assets/orbipom/)
- Event log: [qml/EventLogPage.qml](qml/EventLogPage.qml), [src/eventlogcontroller.cpp](src/eventlogcontroller.cpp), [src/endfield/modules/event_log.cpp](src/endfield/modules/event_log.cpp)
- App shortcuts: [qml/AppShortcutsPage.qml](qml/AppShortcutsPage.qml), [src/appshortcutscontroller.cpp](src/appshortcutscontroller.cpp)

## Porting entry points

When porting to another Linux distribution, install the corresponding development packages for the Qt components and pkg-config names listed in [CMakeLists.txt](CMakeLists.txt). If the protocol file is not in the default location, pass at build time:

```bash
-DWLR_DATA_CONTROL_PROTOCOL=/absolute/path/to/wlr-data-control-unstable-v1.xml
```

When porting to another desktop, start with these three places:

- HUD overlay, screen and shortcut mode: [src/applicationcontroller.cpp](src/applicationcontroller.cpp)
- Desktop window information (Hyprland `hyprctl clients` / niri `niri msg windows`): [src/activitycollector.cpp](src/activitycollector.cpp)
- Wayland clipboard: [src/clipboardcontroller.cpp](src/clipboardcontroller.cpp)

When changing the default software, the entry points are:

- SPlayer: [src/nowplayingcontroller.cpp](src/nowplayingcontroller.cpp), [src/splayerlyrics.cpp](src/splayerlyrics.cpp)
- Dolphin: [src/storagecontroller.cpp](src/storagecontroller.cpp), [src/fileshelfcontroller.cpp](src/fileshelfcontroller.cpp)
- Bash: [src/terminalsession.cpp](src/terminalsession.cpp)
- PulseAudio backend: [src/audiocontroller.cpp](src/audiocontroller.cpp)
- The `ARCH` and compositor name in the profile card (`appController.compositorName`): [qml/MenuBadge.qml](qml/MenuBadge.qml)

## Data locations

Settings are saved in `$XDG_CONFIG_HOME/HyprEndfield/HyprEndfield.conf`. Component data lives in `$XDG_DATA_HOME/HyprEndfield/` and Qt's HyprEndfield application data directory.

Account credentials and archive password verification records use the desktop's Secret Service. The Linux user password is only handed to PAM for verification. Clipboard history stays in memory only and is cleared when the app exits.

## Origin and licensing

The EndfieldHUD reference commit used for the port is [`e9a6bdc2`](https://github.com/DDDuoDuo/EndfieldHUD/tree/e9a6bdc2fe468008c830132715998161f002b902). The original project's [Chinese documentation](https://github.com/DDDuoDuo/EndfieldHUD/blob/e9a6bdc2fe468008c830132715998161f002b902/README.zh-CN.md) describes the macOS and Windows versions.

Licensing information is in [LICENSE](LICENSE), [src/endfield/LICENSE](src/endfield/LICENSE), [assets/settings/EndfieldHUD-LICENSE](assets/settings/EndfieldHUD-LICENSE), the [Matter.js license](assets/orbipom/Matter-LICENSE.txt) and the [HarmonyOS Sans license](assets/fonts/HarmonyOS-Sans-LICENSE.txt). This is an unofficial fan port; game assets, trademarks and third-party resources remain the property of their respective owners.
