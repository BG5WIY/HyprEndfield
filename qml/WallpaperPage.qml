import QtQuick
import "ModuleNumbering.js" as ModuleNumbering
import "Appearance.js" as Appearance

// 壁纸库：右侧「壁纸」模块的中间页面。
// 布局沿用 CalendarPage 的板面（标题行 + 分隔线 + 内容区），内容换成缩略图网格。
// 顶部右侧可切换后端：Wallpaper Engine / awww / 自定义命令。
Item {
    id: wallpaperPage
    width: 590; height: 510
    property bool presented: false
    property bool reduceMotion: false
    readonly property var entries: wallpaperController.wallpapers
    readonly property string backend: settingsController.wallpaperBackend
    readonly property bool usesStaticImages: backend !== "wallpaperengine"
    readonly property int contentTop: backend === "custom" ? 102 : 81
    readonly property int contentHeight: backend === "custom" ? 268 : 300
    property string statusText: ""
    property string statusDetail: ""

    function titleFor(path) {
        const entry = entries.find(item => item.path === path)
        return entry ? entry.title : ""
    }
    function showStatus(text, detail) {
        statusText = text; statusDetail = detail || ""; statusTimer.restart()
    }
    function chooseBackend(key) {
        console.warn("wallpaper backend clicked:", key, "current:", backend)
        if (backend === key) return
        settingsController.set("wallpaperBackend", key)
        wallpaperController.clearError()
        wallpaperController.refresh(key)
        statusText = ""; statusDetail = ""
    }
    function saveCommand() {
        settingsController.set("wallpaperCommand", commandField.text)
        showStatus(qsTr("命令已保存"), commandField.text)
    }
    function emptyHint() {
        return usesStaticImages ? qsTr("没有找到静态壁纸（检查 ~/Pictures/wallpapers 等目录）")
                                : qsTr("没有找到 Wallpaper Engine 壁纸")
    }
    onPresentedChanged: {
        if (presented) {
            wallpaperController.clearError()
            wallpaperController.refresh(backend)
            commandField.text = settingsController.wallpaperCommand
        }
    }
    Connections {
        target: wallpaperController
        function onApplied(path) { wallpaperPage.showStatus(qsTr("已应用"), wallpaperPage.titleFor(path)) }
        function onFailed(reason) { wallpaperPage.showStatus(qsTr("切换失败"), reason) }
    }
    Timer { id: statusTimer; interval: 2000; onTriggered: { wallpaperPage.statusText = ""; wallpaperPage.statusDetail = "" } }

    Item {
        width: 590; height: 81
        Row {
            y: 1.75; spacing: 6
            Repeater {
                model: ["// HUD", "/", "WALLPAPER"]
                Text {
                    required property string modelData; required property int index
                    text: modelData; color: index === 2 ? Appearance.tone("#E6E6E6") : Appearance.tone("#8A8A8A")
                    font.family: harmonyRegular.name; font.pointSize: 10.5 * 0.75; font.letterSpacing: 0.63; renderType: Text.CurveRendering
                }
            }
        }
        Text {
            x: 549 - width; y: 1.75; text: ModuleNumbering.code("wallpaper"); color: Appearance.tone("#8A8A8A")
            font.family: harmonyRegular.name; font.pointSize: 10.5 * 0.75; font.letterSpacing: 0.63; renderType: Text.CurveRendering
        }
        Text {
            id: title; y: 20; height: 30; text: qsTr("壁纸"); color: Appearance.tone("#F4F4F4")
            font.family: harmonyBold.name; font.pixelSize: 26; font.weight: Font.Bold; font.letterSpacing: 2.08; renderType: Text.CurveRendering
        }
        Text {
            x: title.width + 12; y: title.y + title.baselineOffset - baselineOffset; text: "WALLPAPER"; color: Appearance.tone("#8A8A8A")
            font.family: harmonyMedium.name; font.pixelSize: 13; font.letterSpacing: 2.6; font.weight: Font.Medium; renderType: Text.CurveRendering
        }
        Row {
            x: 590 - width; y: 20; spacing: 6
            Repeater {
                model: [
                    { key: "wallpaperengine", label: qsTr("动态") },
                    { key: "awww", label: "awww" },
                    { key: "custom", label: qsTr("自定义") }
                ]
                Item {
                    required property var modelData
                    width: 58; height: 28
                    Rectangle {
                        anchors.fill: parent
                        color: wallpaperPage.backend === modelData.key ? Appearance.accent("#FFFA00") : "#242424"
                        border.width: 1
                        border.color: wallpaperPage.backend === modelData.key ? "#D9D300" : "#555555"
                    }
                    Rectangle {
                        visible: wallpaperPage.backend === modelData.key
                        x: width - 8; y: height - 7; width: 3; height: 3; color: "#161616"
                    }
                    Text {
                        anchors.centerIn: parent; text: modelData.label
                        color: wallpaperPage.backend === modelData.key ? "#111111" : "#EDEDED"
                        font.family: harmonyBold.name; font.pixelSize: 11; font.weight: Font.Bold
                        renderType: Text.CurveRendering
                    }
                    MouseArea {
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: wallpaperPage.chooseBackend(modelData.key)
                    }
                }
            }
        }
        Item {
            y: wallpaperPage.backend === "custom" ? 92 : 60; width: 590; height: 9
            Rectangle { y: 4; width: 590; height: 1; color: "#38FFFFFF" }
            Rectangle { y: 3; width: 56; height: 3; color: Appearance.accent("#FFFA00") }
            Repeater { model: 10; Rectangle { required property int index; x: 454 + index * 9; width: 1; height: 9; color: "#59FFFFFF" } }
            Rectangle { x: 590 - width; y: -2; width: counter.width + 7; height: 12; color: Appearance.tone("#151515") }
            Text {
                id: counter; x: 590 - width; y: -1.5; text: String(wallpaperPage.entries.length).padStart(2, "0") + qsTr(" 张壁纸")
                color: Appearance.accent("#FFFA00"); font.family: harmonyBold.name; font.pixelSize: 11; font.weight: Font.Bold; renderType: Text.CurveRendering
            }
        }
    }

    GridView {
        id: grid; objectName: "wallpaperGrid"
        x: 0; y: wallpaperPage.contentTop; width: 590; height: wallpaperPage.contentHeight
        clip: true
        cellWidth: 196; cellHeight: 146
        boundsBehavior: Flickable.StopAtBounds
        model: wallpaperPage.entries
        delegate: Item {
            required property var modelData
            width: 196; height: 146
            Rectangle {
                anchors.fill: parent; anchors.margins: 4; radius: 6
                color: hover.hovered ? "#14FFFFFF" : "transparent"
                border.width: modelData.current ? 2 : 1
                border.color: modelData.current ? Appearance.accent("#FFFA00")
                                                 : hover.hovered ? "#66FFFFFF" : "#2EFFFFFF"
            }
            Item {
                x: 9; y: 9; width: 168; height: 95; clip: true
                Image {
                    anchors.fill: parent; source: modelData.thumb
                    fillMode: Image.PreserveAspectCrop; asynchronous: true; cache: true; smooth: true
                }
            }
            Text {
                x: 10; y: 109; width: 166; height: 16; text: modelData.title
                color: Appearance.tone("#EDEDED"); elide: Text.ElideRight
                font.family: harmonyMedium.name; font.pixelSize: 12; font.weight: Font.Medium; renderType: Text.CurveRendering
            }
            Rectangle {
                visible: modelData.current
                x: 9; y: 129; width: 44; height: 13; radius: 2; color: Appearance.accent("#FFFA00")
                Text {
                    anchors.centerIn: parent; text: qsTr("当前"); color: "#1A1A1A"
                    font.family: harmonyBold.name; font.pixelSize: 9; font.weight: Font.Bold; renderType: Text.CurveRendering
                }
            }
            HoverHandler { id: hover }
            MouseArea {
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: wallpaperController.apply(modelData.path, wallpaperPage.backend, settingsController.wallpaperCommand)
            }
        }
    }

    Rectangle {
        x: 578; y: wallpaperPage.contentTop; width: 4; height: wallpaperPage.contentHeight
        visible: grid.contentHeight > grid.height
        color: Appearance.tone("#222222")
        Rectangle {
            width: 4; radius: 2; color: Appearance.accent("#FFFA00")
            height: Math.max(18, grid.height * grid.height / Math.max(1, grid.contentHeight))
            y: (grid.height - height) * (grid.contentY / Math.max(1, grid.contentHeight - grid.height))
        }
    }

    CalendarTextField {
        id: commandField
        objectName: "wallpaperCommand"
        x: 0; y: 56; width: 500; height: 30
        visible: wallpaperPage.backend === "custom"
        placeholder: qsTr("自定义命令，{path} 为选中壁纸路径，例如 awww img {path}")
        maximumLength: 400
        reduceMotion: wallpaperPage.reduceMotion
        onAccepted: wallpaperPage.saveCommand()
    }
    Item {
        x: 508; y: 56; width: 82; height: 30
        visible: wallpaperPage.backend === "custom"
        Rectangle {
            anchors.fill: parent; color: Appearance.accent("#FFFA00")
            border.width: 1; border.color: "#D9D300"
        }
        Rectangle { x: width - 9; y: height - 8; width: 4; height: 4; color: "#161616" }
        Text {
            anchors.centerIn: parent; text: qsTr("保存"); color: "#111111"
            font.family: harmonyBold.name; font.pixelSize: 11; font.weight: Font.Bold
            renderType: Text.CurveRendering
        }
        MouseArea {
            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: wallpaperPage.saveCommand()
        }
    }

    Text {
        y: wallpaperPage.contentTop + wallpaperPage.contentHeight + 4; width: 590; height: 14
        visible: wallpaperPage.entries.length === 0
        text: wallpaperPage.emptyHint()
        color: Appearance.tone("#8A8A8A"); font.family: harmonyRegular.name; font.pixelSize: 10; font.letterSpacing: 1
        renderType: Text.CurveRendering
    }
    Text {
        y: wallpaperPage.contentTop + wallpaperPage.contentHeight + 4; width: 500; height: 14
        text: wallpaperController.error.length > 0 ? wallpaperController.error
              : wallpaperController.busy ? qsTr("正在应用…")
              : wallpaperPage.statusText.length > 0 ? wallpaperPage.statusText + (wallpaperPage.statusDetail.length > 0 ? " · " + wallpaperPage.statusDetail : "")
              : qsTr("点击缩略图应用 · 滚轮浏览")
        color: wallpaperController.error.length > 0 ? "#FF8F78" : Appearance.tone("#8A8A8A")
        elide: Text.ElideRight
        font.family: harmonyRegular.name; font.pixelSize: 10; font.letterSpacing: 1; renderType: Text.CurveRendering
    }
}
