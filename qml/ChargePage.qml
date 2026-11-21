import QtQuick
import "ModuleNumbering.js" as ModuleNumbering
import "Appearance.js" as Appearance

// 充能 HUD（zmd-charge-plus-for-linux）的精简设置页。
// 读写它自己的 ~/.local/share/EndfieldChargePlus/settings.json；
// 完整设置仍通过「打开设置」拉起原程序。
Item {
    id: chargePage
    width: 590; height: 510
    property bool presented: false
    property bool reduceMotion: false
    readonly property var cfg: chargeController.settings
    readonly property bool installed: chargeController.installed
    readonly property bool running: chargeController.running
    property var draft: ({})
    property string statusText: ""
    property string statusDetail: ""

    readonly property var positionNames: [
        qsTr("左上"), qsTr("上中"), qsTr("右上"),
        qsTr("左中"), qsTr("居中"), qsTr("右中"),
        qsTr("左下"), qsTr("下中"), qsTr("右下")
    ]

    function resetDraft() {
        draft = {
            "globalScale": cfg.globalScale,
            "displayDuration": cfg.displayDuration,
            "hudOpacity": cfg.hudOpacity,
            "samplingInterval": cfg.samplingInterval,
            "autoCycle": cfg.autoCycle,
            "cycleSeconds": cfg.cycleSeconds,
            "alwaysVisible": cfg.alwaysVisible,
            "clickToCycle": cfg.clickToCycle,
            "hudPosition": cfg.hudPosition
        }
    }
    function setDraft(key, value) {
        const next = Object.assign({}, draft)
        next[key] = value
        draft = next
    }
    function showStatus(text, detail) {
        statusText = text; statusDetail = detail || ""; statusTimer.restart()
    }
    function saveSettings() {
        if (chargeController.save(draft)) {
            showStatus(qsTr("已保存"), qsTr("重启充能 HUD 后生效"))
            chargeController.refresh()
            resetDraft()
        }
    }
    onPresentedChanged: {
        if (presented) {
            chargeController.clearError()
            chargeController.refresh()
            resetDraft()
        }
    }
    Connections {
        target: chargeController
        function onChanged() { if (chargePage.presented) chargePage.resetDraft() }
        function onFailed(reason) { chargePage.showStatus(qsTr("操作失败"), reason) }
    }
    Timer { id: statusTimer; interval: 2500; onTriggered: { chargePage.statusText = ""; chargePage.statusDetail = "" } }

    Item {
        width: 590; height: 81
        Row {
            y: 1.75; spacing: 6
            Repeater {
                model: ["// HUD", "/", "CHARGE"]
                Text {
                    required property string modelData; required property int index
                    text: modelData; color: index === 2 ? Appearance.tone("#E6E6E6") : Appearance.tone("#8A8A8A")
                    font.family: harmonyRegular.name; font.pointSize: 10.5 * 0.75; font.letterSpacing: 0.63; renderType: Text.CurveRendering
                }
            }
        }
        Text {
            x: 549 - width; y: 1.75; text: ModuleNumbering.code("charge"); color: Appearance.tone("#8A8A8A")
            font.family: harmonyRegular.name; font.pointSize: 10.5 * 0.75; font.letterSpacing: 0.63; renderType: Text.CurveRendering
        }
        Text {
            id: title; y: 20; height: 30; text: qsTr("充能 HUD"); color: Appearance.tone("#F4F4F4")
            font.family: harmonyBold.name; font.pixelSize: 26; font.weight: Font.Bold; font.letterSpacing: 2.08; renderType: Text.CurveRendering
        }
        Text {
            x: title.width + 12; y: title.y + title.baselineOffset - baselineOffset; text: "CHARGE"; color: Appearance.tone("#8A8A8A")
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
                text: chargePage.installed ? (chargePage.running ? qsTr("运行中") : qsTr("未运行")) : qsTr("未安装")
                color: chargePage.running ? Appearance.accent("#FFFA00") : Appearance.tone("#8A8A8A")
                font.family: harmonyBold.name; font.pixelSize: 11; font.weight: Font.Bold; renderType: Text.CurveRendering
            }
        }
    }

    Item {
        visible: !chargePage.installed
        y: 96; width: 590; height: 300
        Column {
            width: 560; spacing: 8
            Text {
                width: 560; wrapMode: Text.WordWrap; text: qsTr("没有找到 endfield-charge-plus-for-linux。")
                color: Appearance.tone("#C9C9C9"); font.family: harmonyRegular.name; font.pixelSize: 12
                renderType: Text.CurveRendering
            }
            Text {
                width: 560; wrapMode: Text.WordWrap; text: qsTr("安装 AppImage / tar.gz 后放在 ~/.local/bin、/opt 或 ~/Applications，再按「刷新」。")
                color: Appearance.tone("#C9C9C9"); font.family: harmonyRegular.name; font.pixelSize: 12
                renderType: Text.CurveRendering
            }
            Text {
                width: 560; wrapMode: Text.WordWrap; text: qsTr("也可以用环境变量 ENDFIELD_CHARGE_PLUS 指定路径。")
                color: Appearance.tone("#8A8A8A"); font.family: harmonyRegular.name; font.pixelSize: 11
                renderType: Text.CurveRendering
            }
        }
        Rectangle {
            x: 0; y: 190; width: 110; height: 30; color: Appearance.accent("#FFFA00")
            Text { anchors.centerIn: parent; text: qsTr("刷新"); color: "#111111"; font.family: harmonyBold.name; font.pixelSize: 11; font.weight: Font.Bold; renderType: Text.CurveRendering }
            MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: chargeController.refresh() }
        }
    }

    Flickable {
        id: scroller
        visible: chargePage.installed
        y: 81; width: 590; height: 429
        contentWidth: width; contentHeight: content.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: content
            width: 590; spacing: 6

            Item {
                width: 590; height: 54
                Text {
                    x: 18; y: 8; width: 300
                    text: chargePage.cfg.profileName.length > 0 ? qsTr("当前方案：%1").arg(chargePage.cfg.profileName) : qsTr("尚未生成方案")
                    color: Appearance.tone("#EDEDED"); font.family: harmonyMedium.name; font.pixelSize: 13
                    renderType: Text.CurveRendering
                }
                Text {
                    x: 18; y: 28; width: 400
                    text: qsTr("%1 个方案 · %2").arg(chargePage.cfg.profileCount).arg(chargePage.running ? qsTr("正在运行") : qsTr("未运行"))
                    color: Appearance.tone("#8A8A8A"); font.family: harmonyRegular.name; font.pixelSize: 10; font.letterSpacing: 0.8
                    renderType: Text.CurveRendering
                }
                Row {
                    x: 590 - width; y: 12; spacing: 6
                    Repeater {
                        model: [
                            { key: "launch", label: qsTr("启动") },
                            { key: "settings", label: qsTr("打开设置") },
                            { key: "stop", label: qsTr("停止") }
                        ]
                        Item {
                            required property var modelData
                            width: 78; height: 30
                            Rectangle {
                                anchors.fill: parent
                                color: hover.hovered ? "#343434" : "#242424"
                                border.width: 1; border.color: hover.hovered ? "#666666" : "#444444"
                            }
                            Rectangle { x: 0; y: 7; width: 3; height: 16; color: Appearance.accent("#FFFA00") }
                            Text {
                                anchors.centerIn: parent; text: modelData.label
                                color: Appearance.tone("#EDEDED"); font.family: harmonyBold.name; font.pixelSize: 10; font.weight: Font.Bold
                                renderType: Text.CurveRendering
                            }
                            HoverHandler { id: hover }
                            MouseArea {
                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (modelData.key === "launch") chargeController.launch()
                                    else if (modelData.key === "settings") chargeController.openSettings()
                                    else chargeController.stop()
                                }
                            }
                        }
                    }
                }
            }

            HudSettingsRow {
                width: 590; title: qsTr("显示时长"); mode: "slider"
                sliderValue: chargePage.draft.displayDuration !== undefined ? chargePage.draft.displayDuration : 6
                sliderMinimum: 1; sliderMaximum: 30; sliderStep: 0.5; sliderFormat: "decimal"
                onSliderMoved: (value, final) => { if (final) chargePage.setDraft("displayDuration", value) }
            }
            HudSettingsRow {
                width: 590; title: qsTr("全局缩放"); mode: "slider"
                sliderValue: chargePage.draft.globalScale !== undefined ? chargePage.draft.globalScale : 0.8
                sliderMinimum: 0.4; sliderMaximum: 2.0; sliderStep: 0.05; sliderFormat: "scale"
                onSliderMoved: (value, final) => { if (final) chargePage.setDraft("globalScale", value) }
            }
            HudSettingsRow {
                width: 590; title: qsTr("不透明度"); mode: "slider"
                sliderValue: chargePage.draft.hudOpacity !== undefined ? chargePage.draft.hudOpacity * 100 : 100
                sliderMinimum: 20; sliderMaximum: 100; sliderStep: 1; sliderFormat: "percent"
                onSliderMoved: (value, final) => { if (final) chargePage.setDraft("hudOpacity", value / 100) }
            }
            HudSettingsRow {
                width: 590; title: qsTr("采样间隔"); mode: "slider"
                sliderValue: chargePage.draft.samplingInterval !== undefined ? chargePage.draft.samplingInterval : 1
                sliderMinimum: 0.5; sliderMaximum: 5; sliderStep: 0.1; sliderFormat: "decimal"
                onSliderMoved: (value, final) => { if (final) chargePage.setDraft("samplingInterval", value) }
            }
            HudSettingsRow {
                width: 590; title: qsTr("轮播间隔"); mode: "slider"
                sliderValue: chargePage.draft.cycleSeconds !== undefined ? chargePage.draft.cycleSeconds : 10
                sliderMinimum: 3; sliderMaximum: 120; sliderStep: 1; sliderFormat: "seconds"
                onSliderMoved: (value, final) => { if (final) chargePage.setDraft("cycleSeconds", value) }
            }
            HudSettingsRow {
                width: 590; title: qsTr("自动轮播"); mode: "toggle"
                switched: chargePage.draft.autoCycle === true
                onToggleRequested: value => chargePage.setDraft("autoCycle", value)
            }
            HudSettingsRow {
                width: 590; title: qsTr("始终可见"); mode: "toggle"
                switched: chargePage.draft.alwaysVisible === true
                onToggleRequested: value => chargePage.setDraft("alwaysVisible", value)
            }
            HudSettingsRow {
                width: 590; title: qsTr("点击切换"); mode: "toggle"
                switched: chargePage.draft.clickToCycle === true
                onToggleRequested: value => chargePage.setDraft("clickToCycle", value)
            }

            Item {
                width: 590; height: 96
                Text {
                    x: 18; y: 8; text: qsTr("显示位置"); color: Appearance.tone("#EDEDED")
                    font.family: harmonyMedium.name; font.pixelSize: 13; renderType: Text.CurveRendering
                }
                Grid {
                    x: 18; y: 30; columns: 3; columnSpacing: 6; rowSpacing: 6
                    Repeater {
                        model: chargePage.positionNames
                        Item {
                            required property string modelData; required property int index
                            width: 72; height: 24
                            Rectangle {
                                anchors.fill: parent
                                color: chargePage.draft.hudPosition === index ? Appearance.accent("#FFFA00") : "#242424"
                                border.width: 1
                                border.color: chargePage.draft.hudPosition === index ? "#D9D300" : "#444444"
                            }
                            Text {
                                anchors.centerIn: parent; text: modelData
                                color: chargePage.draft.hudPosition === index ? "#111111" : "#EDEDED"
                                font.family: harmonyBold.name; font.pixelSize: 9; font.weight: Font.Bold
                                renderType: Text.CurveRendering
                            }
                            MouseArea {
                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: chargePage.setDraft("hudPosition", index)
                            }
                        }
                    }
                }
            }

            Item {
                width: 590; height: 40
                Rectangle {
                    x: 0; y: 4; width: 120; height: 32; color: Appearance.accent("#FFFA00")
                    Text { anchors.centerIn: parent; text: qsTr("保存"); color: "#111111"; font.family: harmonyBold.name; font.pixelSize: 11; font.weight: Font.Bold; renderType: Text.CurveRendering }
                    MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: chargePage.saveSettings() }
                }
                Text {
                    x: 132; y: 12; width: 450
                    text: chargeController.error.length > 0 ? chargeController.error
                          : chargePage.statusText.length > 0 ? chargePage.statusText + (chargePage.statusDetail.length > 0 ? " · " + chargePage.statusDetail : "")
                          : qsTr("修改后点保存；重启充能 HUD 生效")
                    color: chargeController.error.length > 0 ? "#FF8F78" : Appearance.tone("#8A8A8A")
                    elide: Text.ElideRight; font.family: harmonyRegular.name; font.pixelSize: 10; font.letterSpacing: 0.8
                    renderType: Text.CurveRendering
                }
            }
        }
    }

    Rectangle {
        x: 578; y: 81; width: 4; height: 429
        visible: chargePage.installed && scroller.contentHeight > scroller.height
        color: Appearance.tone("#222222")
        Rectangle {
            width: 4; radius: 2; color: Appearance.accent("#FFFA00")
            height: Math.max(18, scroller.height * scroller.height / Math.max(1, scroller.contentHeight))
            y: (scroller.height - height) * (scroller.contentY / Math.max(1, scroller.contentHeight - scroller.height))
        }
    }
}
