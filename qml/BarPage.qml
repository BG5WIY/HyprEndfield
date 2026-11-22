import QtQuick
import "ModuleNumbering.js" as ModuleNumbering
import "Appearance.js" as Appearance

// 内置顶部状态栏（layer-shell bar）的设置页。
// 轮播项、间隔、缩放、动画直接写 settingsController，Bar.qml 实时生效。
Item {
    id: barPage
    width: 590; height: 510
    property bool presented: false
    property bool reduceMotion: false

    readonly property var profileDefs: [
        { key: "cpu", label: qsTr("处理器") },
        { key: "memory", label: qsTr("内存") },
        { key: "battery", label: qsTr("电池") },
        { key: "network", label: qsTr("网络") },
        { key: "gpu", label: qsTr("显卡") },
        { key: "disk", label: qsTr("磁盘") },
        { key: "download", label: qsTr("下载") },
        { key: "upload", label: qsTr("上传") },
        { key: "time", label: qsTr("时间") }
    ]

    // QStringList 从 C++ 过来是 sequence 类型，不一定是 JS Array，
    // 统一复制成真正的数组再操作。
    function asArray(raw) {
        if (!raw) return []
        if (Array.isArray(raw)) return raw.slice()
        const out = []
        const count = raw.length || 0
        for (let i = 0; i < count; ++i) out.push(raw[i])
        return out
    }
    function barProfileList() {
        return asArray(settingsController.barProfiles)
    }
    function profileEnabled(key) {
        return barProfileList().indexOf(key) >= 0
    }
    function setProfile(key, on) {
        const list = barProfileList()
        const index = list.indexOf(key)
        if (on && index < 0) list.push(key)
        if (!on && index >= 0) list.splice(index, 1)
        // 至少保留一项，否则 bar 没有可轮播的内容。
        if (list.length === 0) return
        settingsController.set("barProfiles", list)
    }
    function moveProfile(key, delta) {
        const list = barProfileList()
        const index = list.indexOf(key)
        if (index < 0) return
        const target = Math.max(0, Math.min(list.length - 1, index + delta))
        if (index === target) return
        list.splice(index, 1)
        list.splice(target, 0, key)
        settingsController.set("barProfiles", list)
    }

    Item {
        width: 590; height: 81
        Row {
            y: 1.75; spacing: 6
            Repeater {
                model: ["// HUD", "/", "STATUSBAR"]
                Text {
                    required property string modelData; required property int index
                    text: modelData; color: index === 2 ? Appearance.tone("#E6E6E6") : Appearance.tone("#8A8A8A")
                    font.family: harmonyRegular.name; font.pointSize: 10.5 * 0.75; font.letterSpacing: 0.63; renderType: Text.CurveRendering
                }
            }
        }
        Text {
            x: 549 - width; y: 1.75; text: ModuleNumbering.code("bar"); color: Appearance.tone("#8A8A8A")
            font.family: harmonyRegular.name; font.pointSize: 10.5 * 0.75; font.letterSpacing: 0.63; renderType: Text.CurveRendering
        }
        Text {
            id: title; y: 20; height: 30; text: qsTr("状态栏"); color: Appearance.tone("#F4F4F4")
            font.family: harmonyBold.name; font.pixelSize: 26; font.weight: Font.Bold; font.letterSpacing: 2.08; renderType: Text.CurveRendering
        }
        Text {
            x: title.width + 12; y: title.y + title.baselineOffset - baselineOffset; text: "STATUSBAR"; color: Appearance.tone("#8A8A8A")
            font.family: harmonyMedium.name; font.pixelSize: 13; font.letterSpacing: 2.6; font.weight: Font.Medium; renderType: Text.CurveRendering
        }
        Item {
            y: 60; width: 590; height: 9
            Rectangle { y: 4; width: 590; height: 1; color: "#38FFFFFF" }
            Rectangle { y: 3; width: 56; height: 3; color: Appearance.accent("#FFFA00") }
            Repeater { model: 10; Rectangle { required property int index; x: 454 + index * 9; width: 1; height: 9; color: "#59FFFFFF" } }
            Rectangle { x: 590 - width; y: -2; width: counter.width + 7; height: 12; color: Appearance.tone("#151515") }
            Text {
                id: counter; x: 590 - width; y: -1.5
                text: settingsController.barEnabled ? qsTr("已启用") : qsTr("已停用")
                color: settingsController.barEnabled ? Appearance.accent("#FFFA00") : Appearance.tone("#8A8A8A")
                font.family: harmonyBold.name; font.pixelSize: 11; font.weight: Font.Bold; renderType: Text.CurveRendering
            }
        }
    }

    Flickable {
        id: scroller
        y: 81; width: 590; height: 429
        contentWidth: width; contentHeight: content.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: content
            width: 590; spacing: 6

            Item {
                width: 590; height: 26
                Text {
                    x: 18; y: 10; text: qsTr("轮播项"); color: Appearance.tone("#EDEDED")
                    font.family: harmonyMedium.name; font.pixelSize: 13; renderType: Text.CurveRendering
                }
                Text {
                    x: 100; y: 12; text: qsTr("(开关控制显示，箭头调整轮播顺序)")
                    color: Appearance.tone("#8A8A8A")
                    font.family: harmonyRegular.name; font.pixelSize: 9; renderType: Text.CurveRendering
                }
            }

            Column {
                width: 590; spacing: 4
                Repeater {
                    model: barPage.profileDefs
                    delegate: Item {
                        required property var modelData
                        readonly property bool active: barPage.profileEnabled(modelData.key)
                        width: 590; height: 34
                        Rectangle {
                            anchors.fill: parent
                            color: hover.hovered ? "#2E2E2E" : "#1E1E1E"
                            border.width: 1
                            border.color: active ? Appearance.accent("#FFFA00") : "#3A3A3A"
                        }
                        Rectangle {
                            x: 10; y: 8; width: 4; height: 18
                            visible: active
                            color: Appearance.accent("#FFFA00")
                        }
                        Text {
                            x: 24; anchors.verticalCenter: parent.verticalCenter
                            text: modelData.label
                            color: active ? Appearance.tone("#EDEDED") : Appearance.tone("#8A8A8A")
                            font.family: harmonyMedium.name; font.pixelSize: 12; renderType: Text.CurveRendering
                        }
                        // 整行都能切换显示；箭头按钮声明在后面（上层），优先响应。
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: barPage.setProfile(modelData.key, !barPage.profileEnabled(modelData.key))
                        }
                        Item {
                            anchors.right: parent.right; anchors.rightMargin: 78
                            anchors.verticalCenter: parent.verticalCenter
                            width: 21; height: 21
                            z: 2
                            Rectangle { anchors.fill: parent; color: upHover.hovered ? "#3A3A3A" : "#262626" }
                            Text { anchors.centerIn: parent; text: "↑"; color: Appearance.tone("#C9C9C9"); font.pixelSize: 11 }
                            HoverHandler { id: upHover }
                            MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: barPage.moveProfile(modelData.key, -1) }
                        }
                        Item {
                            anchors.right: parent.right; anchors.rightMargin: 50
                            anchors.verticalCenter: parent.verticalCenter
                            width: 21; height: 21
                            z: 2
                            Rectangle { anchors.fill: parent; color: downHover.hovered ? "#3A3A3A" : "#262626" }
                            Text { anchors.centerIn: parent; text: "↓"; color: Appearance.tone("#C9C9C9"); font.pixelSize: 11 }
                            HoverHandler { id: downHover }
                            MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: barPage.moveProfile(modelData.key, 1) }
                        }
                        Rectangle {
                            anchors.right: parent.right; anchors.rightMargin: 14
                            anchors.verticalCenter: parent.verticalCenter
                            width: 26; height: 14; radius: 7
                            color: active ? Appearance.accent("#FFFA00") : "#3A3A3A"
                            Rectangle {
                                width: 10; height: 10; radius: 5; y: 2
                                x: active ? 14 : 2
                                color: active ? "#111111" : "#777777"
                            }
                        }
                        HoverHandler { id: hover }
                    }
                }
            }

            Item {
                width: 590; height: 26
                Text {
                    x: 18; y: 10; text: qsTr("显卡来源"); color: Appearance.tone("#EDEDED")
                    font.family: harmonyMedium.name; font.pixelSize: 13; renderType: Text.CurveRendering
                }
                Text {
                    x: 100; y: 12; text: qsTr("(自动选择占用最高的显卡)")
                    color: Appearance.tone("#8A8A8A")
                    font.family: harmonyRegular.name; font.pixelSize: 9; renderType: Text.CurveRendering
                }
            }

            Row {
                width: 590; spacing: 6
                Repeater {
                    model: {
                        const cards = activityController.state.latest.gpuCards || []
                        const options = [{ value: -1, label: qsTr("自动") }]
                        for (const card of cards) options.push({ value: card.index, label: "GPU " + card.index })
                        return options
                    }
                    delegate: Item {
                        required property var modelData
                        readonly property bool active: Number(settingsController.gpuSource) === Number(modelData.value)
                        width: 130; height: 34
                        Rectangle {
                            anchors.fill: parent
                            color: active ? "#2E2E2E" : "#1E1E1E"
                            border.width: 1
                            border.color: active ? Appearance.accent("#FFFA00") : "#3A3A3A"
                        }
                        Text {
                            anchors.centerIn: parent
                            text: modelData.label
                            color: active ? Appearance.accent("#FFFA00") : Appearance.tone("#C9C9C9")
                            font.family: harmonyMedium.name; font.pixelSize: 12
                            renderType: Text.CurveRendering
                        }
                        MouseArea {
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: settingsController.set("gpuSource", modelData.value)
                        }
                    }
                }
            }

            HudSettingsRow {
                width: 590; title: qsTr("显卡索引"); mode: "slider"
                sliderValue: Number(settingsController.gpuSource)
                sliderMinimum: -1; sliderMaximum: 8; sliderStep: 1; sliderFormat: "decimal"
                onSliderMoved: (value, final) => { if (final) settingsController.set("gpuSource", Math.round(value)) }
            }

            Item { width: 590; height: 4 }

            HudSettingsRow {
                width: 590; title: qsTr("启用状态栏"); mode: "toggle"
                switched: settingsController.barEnabled
                onToggleRequested: value => settingsController.set("barEnabled", value)
            }
            HudSettingsRow {
                width: 590; title: qsTr("切换动画"); mode: "toggle"
                switched: settingsController.barAnimation
                onToggleRequested: value => settingsController.set("barAnimation", value)
            }
            HudSettingsRow {
                width: 590; title: qsTr("轮播间隔"); mode: "slider"
                sliderValue: Number(settingsController.barInterval) || 6
                sliderMinimum: 2; sliderMaximum: 60; sliderStep: 1; sliderFormat: "seconds"
                onSliderMoved: (value, final) => { if (final) settingsController.set("barInterval", Math.round(value)) }
            }
            HudSettingsRow {
                width: 590; title: qsTr("整体缩放"); mode: "slider"
                sliderValue: Number(settingsController.barScale) || 1
                sliderMinimum: 0.6; sliderMaximum: 1.5; sliderStep: 0.05; sliderFormat: "scale"
                onSliderMoved: (value, final) => { if (final) settingsController.set("barScale", value) }
            }

            Item { width: 590; height: 6 }
        }
    }

    Rectangle {
        x: 578; y: 81; width: 4; height: 429
        visible: scroller.contentHeight > scroller.height
        color: Appearance.tone("#222222")
        Rectangle {
            width: 4; radius: 2; color: Appearance.accent("#FFFA00")
            height: Math.max(18, scroller.height * scroller.height / Math.max(1, scroller.contentHeight))
            y: (scroller.height - height) * (scroller.contentY / Math.max(1, scroller.contentHeight - scroller.height))
        }
    }
}
