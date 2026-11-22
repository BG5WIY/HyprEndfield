import QtQuick
import "Appearance.js" as Appearance

// HyprEndfield 通知内容（由 C++ 的 NotificationWindow 加载到独立 layer-shell 窗口）。
// 样式：左下角斜切、左侧斜纹、应用图标、标题 + 高亮数值 + 关闭按钮。
Item {
    id: root
    width: 360
    implicitHeight: column.height + 12

    readonly property color accent: Appearance.accent("#FFFA00")
    readonly property int cut: 14

    function highlight(text) {
        const escaped = String(text || "")
            .replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
        return escaped.replace(/(\d+(?:\.\d+)?\s*%?)/g, '<font color="' + accent + '">$1</font>')
    }

    Column {
        id: column
        x: 6
        y: 6
        width: parent.width - 12
        spacing: 6

        Repeater {
            model: notificationServer.notifications
            delegate: Item {
                required property var modelData
                width: column.width
                height: card.height

                // 卡片背景：左下角斜切
                Canvas {
                    id: card
                    width: parent.width
                    height: Math.max(64, bodyColumn.height + 24)
                    onPaint: {
                        const ctx = getContext("2d")
                        ctx.reset()
                        const cut = root.cut
                        ctx.beginPath()
                        ctx.moveTo(0, 0)
                        ctx.lineTo(width, 0)
                        ctx.lineTo(width, height)
                        ctx.lineTo(cut, height)
                        ctx.lineTo(0, height - cut)
                        ctx.closePath()
                        ctx.fillStyle = "#F21A1A1A"
                        ctx.fill()
                        ctx.strokeStyle = "#444444"
                        ctx.lineWidth = 1
                        ctx.stroke()
                    }
                    onHeightChanged: requestPaint()
                }

                // 左侧斜纹装饰（同样按切角裁剪）
                Canvas {
                    width: 16
                    height: card.height
                    onPaint: {
                        const ctx = getContext("2d")
                        ctx.reset()
                        const cut = root.cut
                        ctx.beginPath()
                        ctx.moveTo(0, 0)
                        ctx.lineTo(width, 0)
                        ctx.lineTo(width, height)
                        ctx.lineTo(0, height - cut)
                        ctx.closePath()
                        ctx.clip()
                        ctx.fillStyle = "#1A1A1A"
                        ctx.fillRect(0, 0, width, height)
                        ctx.strokeStyle = root.accent
                        ctx.lineWidth = 5
                        ctx.beginPath()
                        for (let y = -20; y < height + 20; y += 14) {
                            ctx.moveTo(0, y)
                            ctx.lineTo(width, y + width)
                        }
                        ctx.stroke()
                    }
                    onHeightChanged: requestPaint()
                }

                // 应用图标；找不到时用应用名首字母兜底
                Image {
                    x: 26
                    width: 32; height: 32
                    anchors.verticalCenter: parent.verticalCenter
                    source: (modelData.iconPath || "").length > 0 ? "file://" + modelData.iconPath : ""
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    visible: source !== "" && status === Image.Ready
                }
                Rectangle {
                    x: 26
                    width: 32; height: 32; radius: 4
                    anchors.verticalCenter: parent.verticalCenter
                    color: root.accent
                    visible: (modelData.iconPath || "").length === 0
                    Text {
                        anchors.centerIn: parent
                        text: (modelData.appName || "?").charAt(0).toUpperCase()
                        color: "#141414"
                        font.family: harmonyBold.name
                        font.pixelSize: 16
                        font.weight: Font.Bold
                        renderType: Text.CurveRendering
                    }
                }

                Column {
                    id: bodyColumn
                    x: 68
                    y: 12
                    width: card.width - 100
                    spacing: 3

                    Text {
                        width: parent.width
                        text: root.highlight(modelData.summary)
                        textFormat: Text.StyledText
                        color: "#F2F2F2"
                        font.family: harmonyMedium.name
                        font.pixelSize: 13
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        renderType: Text.CurveRendering
                    }
                    Text {
                        width: parent.width
                        visible: text.length > 0
                        text: root.highlight(modelData.body)
                        textFormat: Text.StyledText
                        color: "#B4B4B4"
                        font.family: harmonyRegular.name
                        font.pixelSize: 12
                        wrapMode: Text.Wrap
                        maximumLineCount: 3
                        elide: Text.ElideRight
                        renderType: Text.CurveRendering
                    }
                }

                Text {
                    x: card.width - 26
                    y: 10
                    text: "×"
                    color: closeHover.hovered ? root.accent : "#8A8A8A"
                    font.pixelSize: 15
                    renderType: Text.CurveRendering
                    HoverHandler { id: closeHover }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: notificationServer.close(modelData.id)
                    }
                }

                Timer {
                    interval: modelData.timeout > 0 ? modelData.timeout : 7000
                    running: true
                    repeat: false
                    onTriggered: notificationServer.close(modelData.id)
                }
            }
        }
    }

    FontLoader { id: harmonyRegular; source: "qrc:/assets/fonts/HarmonyOS_Sans_Regular.ttf" }
    FontLoader { id: harmonyMedium; source: "qrc:/assets/fonts/HarmonyOS_Sans_Medium.ttf" }
    FontLoader { id: harmonyBold; source: "qrc:/assets/fonts/HarmonyOS_Sans_Bold.ttf" }
}
