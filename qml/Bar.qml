import QtQuick
import QtQuick.Effects
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
    readonly property real iconCenterY: 28

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
        // A：旧内容淡出，图标/圆出现在中央
        ParallelAnimation {
            NumberAnimation { target: bar; property: "contentOpacity"; to: 0; duration: 140 }
            PropertyAction { target: bar; property: "iconX"; value: 0 }
            PropertyAction { target: bar; property: "iconOpacity"; value: 0 }
            PropertyAction { target: bar; property: "iconScale"; value: 0.5 }
            PropertyAction { target: bar; property: "circleOpacity"; value: 1 }
            PropertyAction { target: bar; property: "squareOpacity"; value: 0 }
            PropertyAction { target: bar; property: "titleOpacity"; value: 0 }
            PropertyAction { target: bar; property: "rippleScale"; value: 0.18 }
            PropertyAction { target: bar; property: "rippleOpacity"; value: 0 }
            NumberAnimation { target: bar; property: "pillHeight"; to: 90; duration: 260; easing.type: Easing.OutCubic }
            NumberAnimation { target: bar; property: "pillRadius"; to: 18; duration: 260; easing.type: Easing.InOutCubic }
        }
        // B：图标出现（中央）并开始左移；圆/圆环扩散
        ParallelAnimation {
            NumberAnimation { target: bar; property: "iconOpacity"; to: 1; duration: 120 }
            NumberAnimation { target: bar; property: "iconScale"; to: 1; duration: 220; easing.type: Easing.OutBack }
            NumberAnimation { target: bar; property: "rippleOpacity"; to: 0.5; duration: 160 }
            NumberAnimation { target: bar; property: "iconX"; to: -140; duration: 900; easing.type: Easing.OutCubic }
            // 扩散先快后慢，接近右端 25% 时几乎不动
            NumberAnimation { target: bar; property: "rippleScale"; from: 0.18; to: 2.6; duration: 900; easing.type: Easing.OutCubic }
            // 圆环扫过中央时标题缓慢淡入
            SequentialAnimation {
                PauseAnimation { duration: 420 }
                NumberAnimation { target: bar; property: "titleOpacity"; to: 1; duration: 460; easing.type: Easing.InOutCubic }
            }
            // 接近右端 25% 时圆环淡化
            SequentialAnimation {
                PauseAnimation { duration: 720 }
                NumberAnimation { target: bar; property: "rippleOpacity"; to: 0; duration: 180 }
            }
        }
        // C：图标继续移到最左，圆变方
        ParallelAnimation {
            NumberAnimation { target: bar; property: "iconX"; to: -245; duration: 240; easing.type: Easing.OutCubic }
            NumberAnimation { target: bar; property: "iconScale"; to: 0.56; duration: 240; easing.type: Easing.InOutCubic }
            NumberAnimation { target: bar; property: "circleOpacity"; to: 0; duration: 180 }
            NumberAnimation { target: bar; property: "squareOpacity"; to: 1; duration: 180 }
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
            anchors.top: parent.top
            width: 560
            height: bar.pillHeight
            radius: bar.pillRadius
            color: "#312F30"
            clip: true
        }

        // 圆 + 两个圆环：圆心跟随图标，只显示在 pill 的黑色背景内。
        // 用圆角遮罩而不是矩形 clip，边缘才会贴合 pill 的圆角。
        Item {
            id: rippleClip
            width: 560
            height: bar.pillHeight
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter

            Item {
                id: rippleSource
                anchors.fill: parent
                visible: false
                layer.enabled: true
                Item {
                    width: 1; height: 1
                    x: bar.iconCenterX
                    y: bar.iconCenterY
                    scale: bar.rippleScale
                    opacity: bar.rippleOpacity
                    Rectangle { width: 160; height: 160; radius: 80; anchors.centerIn: parent; color: "#656363" }
                    Rectangle { width: 220; height: 220; radius: 110; anchors.centerIn: parent; color: "transparent"; border.width: 5; border.color: "#656363" }
                    Rectangle { width: 280; height: 280; radius: 140; anchors.centerIn: parent; color: "transparent"; border.width: 3.5; border.color: "#656363" }
                }
            }

            MultiEffect {
                anchors.fill: parent
                source: rippleSource
                maskEnabled: true
                maskSource: rippleMask
                maskThresholdMin: 0.3
                maskSpreadAtMin: 1.0
            }

            Item {
                id: rippleMask
                anchors.fill: parent
                visible: false
                layer.enabled: true
                Rectangle { anchors.fill: parent; radius: bar.pillRadius; color: "white" }
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
            y: 12
            scale: bar.iconScale
            opacity: bar.iconOpacity
            Rectangle { anchors.fill: parent; radius: 16; color: "#E9E7E4"; opacity: bar.circleOpacity }
            Rectangle { width: 18; height: 18; radius: 4.5; anchors.centerIn: parent; color: "#E9E7E4"; opacity: bar.squareOpacity }
            Canvas {
                anchors.fill: parent
                property string glyph: bar.current.key
                onGlyphChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                    ctx.fillStyle = "#141313"
                    ctx.strokeStyle = "#141313"
                    ctx.lineWidth = 2
                    ctx.lineCap = "round"
                    const c = 16
                    switch (glyph) {
                    case "cpu":
                        ctx.fillRect(10, 10, 12, 12)
                        ctx.beginPath()
                        for (let i = 0; i < 3; ++i) {
                            const p = 11 + i * 5
                            ctx.moveTo(p, 10); ctx.lineTo(p, 5)
                            ctx.moveTo(p, 22); ctx.lineTo(p, 27)
                            ctx.moveTo(10, p); ctx.lineTo(5, p)
                            ctx.moveTo(22, p); ctx.lineTo(27, p)
                        }
                        ctx.stroke()
                        break
                    case "memory":
                        ctx.strokeRect(6, 11, 20, 10)
                        ctx.fillRect(8, 13, 2, 6)
                        ctx.fillRect(12, 13, 2, 6)
                        ctx.fillRect(16, 13, 2, 6)
                        ctx.fillRect(20, 13, 2, 6)
                        break
                    case "battery":
                        ctx.strokeRect(6, 10, 16, 12)
                        ctx.fillRect(22, 14, 2, 4)
                        ctx.fillRect(9, 13, 8, 6)
                        break
                    case "network":
                        ctx.beginPath()
                        ctx.arc(c, 24, 9, Math.PI * 1.15, Math.PI * 1.85)
                        ctx.stroke()
                        ctx.beginPath()
                        ctx.arc(c, 24, 14, Math.PI * 1.2, Math.PI * 1.8)
                        ctx.stroke()
                        ctx.beginPath()
                        ctx.arc(c, 24, 19, Math.PI * 1.25, Math.PI * 1.75)
                        ctx.stroke()
                        ctx.fillRect(c - 1.5, 12, 3, 3)
                        break
                    case "gpu":
                        ctx.strokeRect(7, 10, 18, 12)
                        ctx.fillRect(11, 14, 6, 4)
                        ctx.fillRect(19, 14, 3, 4)
                        ctx.beginPath()
                        ctx.moveTo(10, 22); ctx.lineTo(10, 26)
                        ctx.moveTo(16, 22); ctx.lineTo(16, 26)
                        ctx.moveTo(22, 22); ctx.lineTo(22, 26)
                        ctx.stroke()
                        break
                    case "disk":
                        ctx.strokeRect(6, 9, 20, 14)
                        ctx.fillRect(9, 12, 14, 3)
                        ctx.beginPath()
                        ctx.arc(21, 20, 1.6, 0, Math.PI * 2)
                        ctx.fill()
                        break
                    case "download":
                        ctx.beginPath()
                        ctx.moveTo(16, 6); ctx.lineTo(16, 20)
                        ctx.moveTo(10, 14); ctx.lineTo(16, 20); ctx.lineTo(22, 14)
                        ctx.stroke()
                        ctx.fillRect(9, 24, 14, 2)
                        break
                    case "upload":
                        ctx.beginPath()
                        ctx.moveTo(16, 20); ctx.lineTo(16, 6)
                        ctx.moveTo(10, 12); ctx.lineTo(16, 6); ctx.lineTo(22, 12)
                        ctx.stroke()
                        ctx.fillRect(9, 24, 14, 2)
                        break
                    case "time":
                        ctx.beginPath()
                        ctx.arc(c, c, 11, 0, Math.PI * 2)
                        ctx.stroke()
                        ctx.beginPath()
                        ctx.moveTo(c, c); ctx.lineTo(c, c - 6)
                        ctx.moveTo(c, c); ctx.lineTo(c + 5, c + 2)
                        ctx.stroke()
                        break
                    default:
                        ctx.beginPath()
                        ctx.moveTo(19, 6); ctx.lineTo(10, 18); ctx.lineTo(15, 18)
                        ctx.lineTo(12, 27); ctx.lineTo(23, 14); ctx.lineTo(17, 14)
                        ctx.closePath(); ctx.fill()
                    }
                }
            }
        }

        // 收缩态内容
        Item {
            id: content
            anchors.fill: pill
            opacity: bar.contentOpacity

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
                Item {
                    anchors.centerIn: parent
                    width: 24; height: 17
                    Rectangle {
                        x: 0; y: 0; width: 20; height: 17; radius: 2
                        color: "transparent"; border.width: 2
                        border.color: Appearance.accent("#C6CA4C")
                    }
                    Rectangle {
                        x: 21; y: 5; width: 3; height: 7; radius: 1
                        color: Appearance.accent("#C6CA4C")
                    }
                    Rectangle {
                        x: 3; y: 3; width: 14 * Math.max(0.05, bar.value.progress); height: 11; radius: 1
                        color: Appearance.accent("#C6CA4C")
                    }
                }
            }
        }
    }
}
