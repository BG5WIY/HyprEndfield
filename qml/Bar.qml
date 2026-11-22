import QtQuick
import "Appearance.js" as Appearance

// 常驻顶部 bar：按 zmd-charge 的动画顺序复刻。
// 每个轮播项有自己的图标；图标先出现在中央，圆/圆环从图标扩散，
// 图标移到左侧 25%，标题在圆环扫过中央时淡入。
Item {
    id: bar
    width: parent ? parent.width : 600
    height: parent ? parent.height : 160

    // Bar 是独立的 QQuickWindow，拿不到 Main.qml 里的 FontLoader，单独加载。
    FontLoader { id: harmonyRegular; source: "qrc:/assets/fonts/HarmonyOS_Sans_Regular.ttf" }
    FontLoader { id: harmonyMedium; source: "qrc:/assets/fonts/HarmonyOS_Sans_Medium.ttf" }
    FontLoader { id: harmonyBold; source: "qrc:/assets/fonts/HarmonyOS_Sans_Bold.ttf" }

    readonly property var activity: activityController.state
    readonly property var latest: activity.latest || ({})
    readonly property var battery: batteryController.state
    property int index: 0
    readonly property var allProfiles: [
        { key: "cpu", title: qsTr("处理器"), tag: "/// PROCESSOR" },
        { key: "memory", title: qsTr("内存"), tag: "/// MEMORY" },
        { key: "battery", title: qsTr("电池"), tag: "/// BATTERY" },
        { key: "network", title: qsTr("网络"), tag: "/// NETWORK" },
        { key: "gpu", title: qsTr("显卡"), tag: "/// GRAPHICS" },
        { key: "disk", title: qsTr("磁盘"), tag: "/// STORAGE" },
        { key: "download", title: qsTr("下载"), tag: "/// DOWNLOAD" },
        { key: "upload", title: qsTr("上传"), tag: "/// UPLOAD" },
        { key: "time", title: qsTr("时间"), tag: "/// CLOCK" }
    ]
    readonly property var enabledKeys: {
        const raw = settingsController.barProfiles
        if (!raw) return []
        if (Array.isArray(raw)) return raw
        const out = []
        const count = raw.length || 0
        for (let i = 0; i < count; ++i) out.push(raw[i])
        return out
    }
    readonly property var profiles: {
        const list = enabledKeys.map(key => allProfiles.find(entry => entry.key === key)).filter(entry => !!entry)
        return list.length > 0 ? list : allProfiles
    }
    readonly property var current: profiles[Math.max(0, Math.min(profiles.length - 1, index))]

    readonly property real cpu: latest.cpu !== undefined && latest.cpu !== null && latest.cpu !== "" ? Number(latest.cpu) : NaN
    readonly property real gpu: latest.gpu !== undefined && latest.gpu !== null && latest.gpu !== "" ? Number(latest.gpu) : NaN
    readonly property real memUsed: Number(latest.memoryUsed || 0)
    readonly property real memTotal: Number(latest.memoryTotal || 0)
    readonly property real memPercent: memTotal > 0 ? memUsed / memTotal * 100 : NaN
    readonly property real download: Number(latest.download || 0)
    readonly property real upload: Number(latest.upload || 0)
    readonly property bool batteryAvailable: battery.available === true
    readonly property real batteryPercent: batteryAvailable ? Number(battery.percentage) : NaN
    readonly property bool charging: batteryAvailable && (battery.stateKey === "charging" || battery.stateKey === "full")

    function rate(value) {
        const n = Number(value) || 0
        if (n >= 1048576) return (n / 1048576).toFixed(1)
        if (n >= 1024) return (n / 1024).toFixed(0)
        return n.toFixed(0)
    }
    function rateUnit(value) {
        const n = Number(value) || 0
        return n >= 1048576 ? "MB/s" : n >= 1024 ? "KB/s" : "B/s"
    }
    function gigabyte(value) { return (Number(value) / 1073741824).toFixed(1) }
    function percentText(value) { return isNaN(value) ? "--" : String(Math.round(value)) }
    function progressOf(value) { return isNaN(value) ? 0 : Math.max(0, Math.min(1, value / 100)) }

    property int clockTick: 0
    Timer { interval: 1000; running: true; repeat: true; onTriggered: bar.clockTick++ }

    // 轮播定时器：间隔读设置项
    Timer {
        interval: Math.max(2, Number(settingsController.barInterval) || 6) * 1000
        running: true
        repeat: true
        onTriggered: bar.advance()
    }

    function valueFor(key, tick) {
        switch (key) {
        case "time":
            return { primary: Qt.formatTime(new Date(), "HH:mm"), secondary: "",
                     right: Qt.formatTime(new Date(), "ss"), suffix: "", progress: 0 }
        case "disk":
            return { primary: rate(latest.read), secondary: qsTr("读"),
                     right: rate(latest.write), suffix: qsTr("写"), progress: 0 }
        case "download":
            return { primary: rate(download), secondary: rateUnit(download), right: "", suffix: "", progress: 0 }
        case "upload":
            return { primary: rate(upload), secondary: rateUnit(upload), right: "", suffix: "", progress: 0 }
        case "memory":
            return { primary: isNaN(memPercent) ? "--" : gigabyte(memUsed),
                     secondary: memTotal > 0 ? "/" + gigabyte(memTotal) + " GB" : "",
                     right: percentText(memPercent), suffix: "%", progress: progressOf(memPercent) }
        case "battery":
            return { primary: percentText(batteryPercent),
                     secondary: charging ? qsTr("充电中") : (batteryAvailable ? qsTr("电池") : ""),
                     right: batteryAvailable ? (charging ? "AC" : "") : "",
                     suffix: "%", progress: progressOf(batteryPercent) }
        case "network":
            return { primary: rate(download), secondary: rateUnit(download),
                     right: rate(upload), suffix: rateUnit(upload).replace("/s", ""), progress: 0 }
        case "gpu":
            return { primary: isNaN(gpu) ? "--" : String(Math.round(gpu)), secondary: "",
                     right: percentText(gpu), suffix: "%", progress: progressOf(gpu) }
        default:
            return { primary: isNaN(cpu) ? "--" : String(Math.round(cpu)), secondary: "",
                     right: percentText(cpu), suffix: "%", progress: progressOf(cpu) }
        }
    }
    readonly property var value: valueFor(current.key, clockTick)

    // ── 动画状态 ────────────────────────────────────────────────────────
    property real pillScale: 0.6
    property real pillOpacity: 0
    property real pillHeight: 60
    property real pillRadius: 30
    property real iconX: 0            // 0=中央，-140=左侧 25%，-245=最左
    property real iconScale: 0.4
    property real iconOpacity: 0
    property real circleOpacity: 0
    property real squareOpacity: 0
    property real titleOpacity: 0
    property real contentOpacity: 0
    property real rippleScale: 0.15
    property real rippleOpacity: 0
    property bool animating: false

    // 圆/圆环的圆心跟随图标
    readonly property real iconCenterX: 280 + iconX
    readonly property real iconCenterY: pillHeight / 2

    function advance() {
        if (animating || profiles.length === 0) return
        if (!settingsController.barAnimation) {
            index = (index + 1) % profiles.length
            return
        }
        animating = true
        cycle.restart()
    }

    Component.onCompleted: {
        activityController.active = true
        batteryController.monitoring = true
        intro.start()
    }

    SequentialAnimation {
        id: intro
        ParallelAnimation {
            NumberAnimation { target: bar; property: "pillOpacity"; to: 1; duration: 180 }
            NumberAnimation { target: bar; property: "pillScale"; to: 1; duration: 320; easing.type: Easing.OutBack }
        }
        ScriptAction { script: { bar.advance() } }
    }

    // 原项目顺序：图标中央出现 → 图标+圆环左移并扩散 → 圆环扫过中央时标题淡入
    // → 圆环到右 25% 淡化、图标到最左 → 内容出现。
    SequentialAnimation {
        id: cycle
        PropertyAction { target: bar; property: "index"; value: (bar.index + 1) % bar.profiles.length }
        // A：旧内容淡出，图标回到正中央、缩到最小准备出现
        ParallelAnimation {
            NumberAnimation { target: bar; property: "contentOpacity"; to: 0; duration: 140 }
            PropertyAction { target: bar; property: "iconX"; value: 0 }
            PropertyAction { target: bar; property: "iconOpacity"; value: 0 }
            PropertyAction { target: bar; property: "iconScale"; value: 0.1 }
            PropertyAction { target: bar; property: "circleOpacity"; value: 1 }
            PropertyAction { target: bar; property: "squareOpacity"; value: 0 }
            PropertyAction { target: bar; property: "titleOpacity"; value: 0 }
            PropertyAction { target: bar; property: "rippleScale"; value: 0.18 }
            PropertyAction { target: bar; property: "rippleOpacity"; value: 0 }
            NumberAnimation { target: bar; property: "pillHeight"; to: 90; duration: 260; easing.type: Easing.OutCubic }
            NumberAnimation { target: bar; property: "pillRadius"; to: 18; duration: 260; easing.type: Easing.InOutCubic }
        }
        // B1：图标在 bar 正中央由小到大出现，圆环同步亮起
        ParallelAnimation {
            NumberAnimation { target: bar; property: "iconOpacity"; to: 1; duration: 100 }
            NumberAnimation { target: bar; property: "iconScale"; from: 0.1; to: 1; duration: 240; easing.type: Easing.OutBack }
            NumberAnimation { target: bar; property: "rippleOpacity"; to: 0.5; duration: 160 }
            NumberAnimation { target: bar; property: "rippleScale"; from: 0.18; to: 0.3; duration: 240; easing.type: Easing.OutCubic }
        }
        // B2：图标和圆环一起左移并扩大，圆环扫过中央时标题淡入
        ParallelAnimation {
            NumberAnimation { target: bar; property: "iconX"; to: -140; duration: 900; easing.type: Easing.OutCubic }
            NumberAnimation { target: bar; property: "rippleScale"; from: 0.3; to: 2.6; duration: 900; easing.type: Easing.OutCubic }
            SequentialAnimation {
                PauseAnimation { duration: 420 }
                NumberAnimation { target: bar; property: "titleOpacity"; to: 1; duration: 460; easing.type: Easing.InOutCubic }
            }
            SequentialAnimation {
                PauseAnimation { duration: 720 }
                NumberAnimation { target: bar; property: "rippleOpacity"; to: 0; duration: 180 }
            }
        }
        // C：图标继续移到最左，圆变方；圆环缩回图标周围并保留
        ParallelAnimation {
            NumberAnimation { target: bar; property: "iconX"; to: -245; duration: 240; easing.type: Easing.OutCubic }
            NumberAnimation { target: bar; property: "iconScale"; to: 0.56; duration: 240; easing.type: Easing.InOutCubic }
            NumberAnimation { target: bar; property: "circleOpacity"; to: 0; duration: 180 }
            NumberAnimation { target: bar; property: "squareOpacity"; to: 1; duration: 180 }
            // 圆环收回到图标周围并保留，动画结束后仍可见。
            NumberAnimation { target: bar; property: "rippleScale"; to: 0.6; duration: 300; easing.type: Easing.InOutCubic }
            NumberAnimation { target: bar; property: "rippleOpacity"; to: 0.5; duration: 240 }
        }
        // D：标题淡出，内容进入，pill 收回
        ParallelAnimation {
            NumberAnimation { target: bar; property: "titleOpacity"; to: 0; duration: 200 }
            NumberAnimation { target: bar; property: "contentOpacity"; to: 1; duration: 260; easing.type: Easing.OutCubic }
            NumberAnimation { target: bar; property: "pillHeight"; to: 60; duration: 300; easing.type: Easing.InOutCubic }
            NumberAnimation { target: bar; property: "pillRadius"; to: 30; duration: 300; easing.type: Easing.InOutCubic }
        }
        PauseAnimation { duration: 3200 }
        ScriptAction { script: { bar.animating = false } }
    }

    // ── 视觉 ────────────────────────────────────────────────────────────
    Item {
        id: pillHost
        anchors.horizontalCenter: parent.horizontalCenter
        y: 14
        width: 560
        height: 100
        scale: bar.pillScale * (Number(settingsController.barScale) || 1)
        opacity: bar.pillOpacity
        transformOrigin: Item.Top

        Rectangle {
            id: pill
            anchors.horizontalCenter: parent.horizontalCenter
            // 以 pill 中心为基准上下同时扩展：静息 60 高、顶部在 0，展开到 90 时向上 15。
            y: 30 - height / 2
            width: 560
            height: bar.pillHeight
            radius: bar.pillRadius
            color: "#312F30"
            clip: true
        }

        // 圆 + 两个圆环：Canvas 直接按 pill 的圆角半径裁剪，边缘与 pill 完全一致。
        Item {
            id: rippleClip
            width: 560
            height: bar.pillHeight
            y: pill.y
            x: pill.x

            Canvas {
                anchors.fill: parent
                property real iconCx: bar.iconCenterX
                property real iconCy: bar.iconCenterY
                property real spread: bar.rippleScale
                property real strength: bar.rippleOpacity
                property real corner: bar.pillRadius
                onIconCxChanged: requestPaint()
                onIconCyChanged: requestPaint()
                onSpreadChanged: requestPaint()
                onStrengthChanged: requestPaint()
                onCornerChanged: requestPaint()
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const r = Math.max(0, Math.min(corner, Math.min(width, height) / 2))
                    ctx.beginPath()
                    ctx.moveTo(r, 0)
                    ctx.lineTo(width - r, 0)
                    ctx.arcTo(width, 0, width, r, r)
                    ctx.lineTo(width, height - r)
                    ctx.arcTo(width, height, width - r, height, r)
                    ctx.lineTo(r, height)
                    ctx.arcTo(0, height, 0, height - r, r)
                    ctx.lineTo(0, r)
                    ctx.arcTo(0, 0, r, 0, r)
                    ctx.closePath()
                    ctx.clip()

                    ctx.globalAlpha = strength
                    const cx = iconCx
                    const cy = iconCy
                    ctx.fillStyle = "#7C7C7C"
                    ctx.beginPath()
                    ctx.arc(cx, cy, 45 * spread, 0, Math.PI * 2)
                    ctx.fill()
                    ctx.strokeStyle = "#7C7C7C"
                    ctx.lineWidth = 5
                    ctx.beginPath()
                    ctx.arc(cx, cy, 80 * spread, 0, Math.PI * 2)
                    ctx.stroke()
                    ctx.lineWidth = 3.5
                    ctx.beginPath()
                    ctx.arc(cx, cy, 120 * spread, 0, Math.PI * 2)
                    ctx.stroke()
                }
            }
        }

        // 标题（圆环扫过中央时淡入）
        Column {
            anchors.centerIn: pill
            y: 2
            spacing: 1
            opacity: bar.titleOpacity
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: bar.current.tag
                color: "#FFFFFF"; opacity: 0.4
                font.family: harmonyMedium.name; font.pixelSize: 9; font.letterSpacing: 2
                renderType: Text.CurveRendering
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: bar.current.title
                color: "#FFFFFF"
                font.family: harmonyBold.name; font.pixelSize: 24; font.weight: Font.Bold; font.letterSpacing: 2
                renderType: Text.CurveRendering
            }
        }

        // 图标：每项独立图形
        Item {
            id: icon
            width: 32; height: 32
            x: 280 - 16 + bar.iconX
            y: pill.y + (pill.height - height) / 2
            scale: bar.iconScale
            transformOrigin: Item.Center
            opacity: bar.iconOpacity
            Rectangle { anchors.fill: parent; radius: 16; color: "#E9E7E4"; opacity: bar.circleOpacity }
            Rectangle { width: 18; height: 18; radius: 4.5; anchors.centerIn: parent; color: "#E9E7E4"; opacity: bar.squareOpacity }
            BarGlyph {
                anchors.fill: parent
                glyphKey: bar.current.key
                color: "#141313"
            }
        }

        // 收缩态内容
        Item {
            id: content
            anchors.fill: pill
            opacity: bar.contentOpacity

            // 中央时钟
            Text {
                anchors.centerIn: parent
                text: bar.clockTick >= 0 ? Qt.formatTime(new Date(), "HH:mm") : ""
                color: "#F2F2F2"
                font.family: harmonyMedium.name
                font.pixelSize: 22
                font.weight: Font.Medium
                renderType: Text.CurveRendering
            }

            Row {
                x: 64
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3
                Text {
                    text: bar.value.primary
                    color: "#FFFFFF"
                    font.family: harmonyMedium.name; font.pixelSize: 26; font.weight: Font.Medium
                    renderType: Text.CurveRendering
                }
                Text {
                    text: bar.value.secondary
                    color: "#FFFFFF"; opacity: 0.55
                    font.family: harmonyMedium.name; font.pixelSize: 14; font.weight: Font.Medium
                    anchors.verticalCenter: parent.verticalCenter
                    renderType: Text.CurveRendering
                }
            }

            Row {
                anchors.right: badge.left
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1
                Text {
                    text: bar.value.right
                    color: "#FFFFFF"
                    font.family: harmonyMedium.name; font.pixelSize: 22; font.weight: Font.Medium
                    renderType: Text.CurveRendering
                }
                Text {
                    text: bar.value.suffix
                    color: "#FFFFFF"; opacity: 0.55
                    font.family: harmonyMedium.name; font.pixelSize: 13; font.weight: Font.Medium
                    anchors.verticalCenter: parent.verticalCenter
                    renderType: Text.CurveRendering
                }
            }

            Item {
                id: badge
                width: 46; height: 46
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                Rectangle { anchors.fill: parent; radius: 23; color: "#262425" }
                Canvas {
                    anchors.fill: parent
                    property real progress: bar.value.progress
                    onProgressChanged: requestPaint()
                    onPaint: {
                        const ctx = getContext("2d")
                        ctx.clearRect(0, 0, width, height)
                        if (progress <= 0) return
                        const c = width / 2, r = width / 2 - 3
                        ctx.strokeStyle = Appearance.accent("#C6CA4C")
                        ctx.lineWidth = 4.5
                        ctx.lineCap = "round"
                        ctx.beginPath()
                        ctx.arc(c, c, r, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * progress)
                        ctx.stroke()
                    }
                }
                BarGlyph {
                    anchors.centerIn: parent
                    width: 24; height: 24
                    glyphKey: bar.current.key
                    color: Appearance.accent("#C6CA4C")
                }
            }
        }
    }
}
