import QtQuick
import "Appearance.js" as Appearance

// HyprEndfield 通知内容（由 C++ 的 NotificationWindow 加载到独立 layer-shell 窗口）。
// 样式按 HUD 的「消息通知条」复刻：斜纹装饰 + 警告图标 + 标题 + 高亮数值 + 关闭按钮。
Item {
    id: root
    width: 360
    implicitHeight: column.height + 12

    readonly property color accent: Appearance.accent("#FFFA00")

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

                Rectangle {
                    id: card
                    anchors.fill: parent
                    height: Math.max(64, bodyColumn.height + 24)
                    color: "#F21A1A1A"
                    border.width: 1
                    border.color: "#444444"
                }

                // 左侧斜纹装饰
                Canvas {
                    width: 16
                    height: card.height
                    onPaint: {
                        const ctx = getContext("2d")
                        ctx.reset()
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

                // 警告图标
                Canvas {
                    x: 26
                    anchors.verticalCenter: parent.verticalCenter
                    width: 24; height: 24
                    onPaint: {
                        const ctx = getContext("2d")
                        ctx.reset()
                        ctx.fillStyle = root.accent
                        ctx.beginPath()
                        ctx.moveTo(12, 2)
                        ctx.lineTo(23, 21)
                        ctx.lineTo(1, 21)
                        ctx.closePath()
                        ctx.fill()
                        ctx.fillStyle = "#141414"
                        ctx.fillRect(10.8, 9, 2.4, 7)
                        ctx.fillRect(10.8, 17.5, 2.4, 2.2)
                    }
                }

                Column {
                    id: bodyColumn
                    x: 60
                    y: 12
                    width: card.width - 92
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
