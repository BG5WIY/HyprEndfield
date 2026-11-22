import QtQuick
import "Appearance.js" as Appearance

// 常驻顶部 bar：按 zmd-charge 的 HudAnimations 时间线复刻动画 pill。
// 数据来自 HyprEndfield 自己的 activityController / batteryController，
// 由 BarWindow 放进 wlr-layer-shell（top 层）窗口，不占工作区。
Item {
    id: bar
    width: parent ? parent.width : 600
    height: parent ? parent.height : 160

    readonly property var activity: activityController.state
    readonly property var latest: activity.latest || ({})
    readonly property var battery: batteryController.state
    property int index: 0
    readonly property var allProfiles: [
        { key: "cpu", title: qsTr("处理器"), tag: "/// PROCESSOR" },
        { key: "memory", title: qsTr("内存"), tag: "/// MEMORY" },
        { key: "battery", title: qsTr("电池"), tag: "/// BATTERY" },
        { key: "network", title: qsTr("网络"), tag: "/// NETWORK" },
        { key: "gpu", title: qsTr("显卡"), tag: "/// GRAPHICS" }
    ]
    readonly property var enabledKeys: settingsController.barProfiles || []
    readonly property var profiles: {
        const list = allProfiles.filter(entry => enabledKeys.indexOf(entry.key) >= 0)
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

    function valueFor(key) {
        switch (key) {
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
    readonly property var value: valueFor(current.key)

    // ── 动画状态（时间线来自 zmd-charge HudAnimations，6s 基准） ────────
    property real pillScale: 0.6
    property real pillOpacity: 0
    property real pillHeight: 60
    property real pillRadius: 30
    property real iconX: 0
    property real iconScale: 0.4
    property real iconOpacity: 0
    property real circleOpacity: 0
    property real squareOpacity: 0
    property real titleOpacity: 0
    property real contentOpacity: 0
    property real numberY: 8
    property real rippleScale: 0.15
    property real rippleOpacity: 0
    property bool animating: false

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

    // 首次出现：pill 从 0.6 弹到 1，然后进入一次完整切换。
    SequentialAnimation {
        id: intro
        PauseAnimation { duration: 240 }
        ParallelAnimation {
            NumberAnimation { target: bar; property: "pillOpacity"; to: 1; duration: 180 }
            NumberAnimation { target: bar; property: "pillScale"; to: 1; duration: 320; easing.type: Easing.OutBack }
        }
        ParallelAnimation {
            NumberAnimation { target: bar; property: "iconOpacity"; to: 1; duration: 180 }
            NumberAnimation { target: bar; property: "iconScale"; from: 0.4; to: 1.12; duration: 240; easing.type: Easing.OutBack }
            NumberAnimation { target: bar; property: "circleOpacity"; to: 1; duration: 180 }
        }
        ScriptAction { script: { bar.advance() } }
    }

    // 每次轮播：展开（标题+波纹）→ 图标左移/变方形 → 收拢 → 内容进入。
    SequentialAnimation {
        id: cycle
        // 展开
        ParallelAnimation {
            NumberAnimation { target: bar; property: "contentOpacity"; to: 0; duration: 200 }
            NumberAnimation { target: bar; property: "titleOpacity"; to: 1; duration: 260; easing.type: Easing.OutCubic }
            NumberAnimation { target: bar; property: "iconX"; to: 0; duration: 300; easing.type: Easing.OutCubic }
            NumberAnimation { target: bar; property: "iconScale"; to: 1; duration: 240; easing.type: Easing.OutBack }
            NumberAnimation { target: bar; property: "circleOpacity"; to: 1; duration: 200 }
            NumberAnimation { target: bar; property: "squareOpacity"; to: 0; duration: 200 }
            NumberAnimation { target: bar; property: "pillHeight"; to: 90; duration: 320; easing.type: Easing.OutBack }
            NumberAnimation { target: bar; property: "pillRadius"; to: 18; duration: 320; easing.type: Easing.InOutCubic }
            ScriptAction { script: { ripple.restart() } }
        }
        PauseAnimation { duration: 220 }
        PropertyAction { target: bar; property: "index"; value: (bar.index + 1) % bar.profiles.length }
        // 收拢：图标左移、圆变方
        ParallelAnimation {
            NumberAnimation { target: bar; property: "titleOpacity"; to: 0; duration: 200 }
            NumberAnimation { target: bar; property: "iconX"; to: -245; duration: 420; easing.type: Easing.OutCubic }
            NumberAnimation { target: bar; property: "iconScale"; to: 0.56; duration: 380; easing.type: Easing.InOutCubic }
            NumberAnimation { target: bar; property: "circleOpacity"; to: 0; duration: 240 }
            NumberAnimation { target: bar; property: "squareOpacity"; to: 1; duration: 240 }
            NumberAnimation { target: bar; property: "pillHeight"; to: 60; duration: 380; easing.type: Easing.InOutCubic }
            NumberAnimation { target: bar; property: "pillRadius"; to: 30; duration: 380; easing.type: Easing.InOutCubic }
        }
        // 内容进入
        ParallelAnimation {
            NumberAnimation { target: bar; property: "contentOpacity"; to: 1; duration: 260; easing.type: Easing.OutCubic }
            NumberAnimation { target: bar; property: "numberY"; from: 8; to: 0; duration: 260; easing.type: Easing.OutCubic }
        }
        PauseAnimation { duration: 3600 }
        ScriptAction { script: { bar.animating = false } }
    }

    ParallelAnimation {
        id: ripple
        NumberAnimation { target: bar; property: "rippleScale"; from: 0.15; to: 1; duration: 780; easing.type: Easing.OutCubic }
        NumberAnimation { target: bar; property: "rippleOpacity"; from: 0.55; to: 0; duration: 780; easing.type: Easing.OutCubic }
    }

    Timer {
        interval: Math.max(2, Number(settingsController.barInterval) || 6) * 1000
        running: true
        repeat: true
        onTriggered: bar.advance()
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
        transformOrigin: Item.Center

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

        // 波纹：内实心 / 中环 / 外环
        Item {
            anchors.centerIn: pill
            width: 1; height: 1
            scale: bar.rippleScale
            opacity: bar.rippleOpacity
            Rectangle { width: 160; height: 160; radius: 80; anchors.centerIn: parent; color: "#656363" }
            Rectangle { width: 220; height: 220; radius: 110; anchors.centerIn: parent; color: "transparent"; border.width: 5; border.color: "#656363" }
            Rectangle { width: 280; height: 280; radius: 140; anchors.centerIn: parent; color: "transparent"; border.width: 3.5; border.color: "#656363" }
        }

        // 展开时的标题（tagline + title）
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 54
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

        // 图标：中心（圆）↔ 左侧（方）
        Item {
            id: icon
            width: 32; height: 32
            x: 280 - 16 + bar.iconX
            y: 12
            scale: bar.iconScale
            opacity: bar.iconOpacity
            Rectangle {
                anchors.fill: parent; radius: 16
                color: "#E9E7E4"; opacity: bar.circleOpacity
            }
            Rectangle {
                width: 18; height: 18; radius: 4.5
                anchors.centerIn: parent
                color: "#E9E7E4"; opacity: bar.squareOpacity
            }
            Canvas {
                anchors.fill: parent
                opacity: Math.max(bar.circleOpacity, bar.squareOpacity)
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                    ctx.fillStyle = "#141313"
                    ctx.beginPath()
                    ctx.moveTo(19, 6); ctx.lineTo(10, 18); ctx.lineTo(15, 18)
                    ctx.lineTo(12, 27); ctx.lineTo(23, 14); ctx.lineTo(17, 14)
                    ctx.closePath(); ctx.fill()
                }
            }
        }

        // 收缩态内容：主值、副值、右侧值、徽章
        Item {
            id: content
            anchors.fill: pill
            opacity: bar.contentOpacity
            y: bar.numberY

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
