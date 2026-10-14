/*****************************************************************************
 * Copyright (C) 2026 VLC authors and VideoLAN
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * ( at your option ) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
 *****************************************************************************/
import QtQuick
import QtQuick.Templates as T
import QtQuick.Layouts

import VLC.MainInterface
import VLC.Widgets as Widgets
import VLC.Style
import VLC.Dialogs

// VLC Redesign: one settings row (label on the left, control on the right),
// bound to a VLC configuration option through SettingsBridge.
RowLayout {
    id: root

    property var row: ({})

    signal restartRequired()
    signal actionRequested(string action)

    readonly property var opt: row.option ? SettingsBridge.option(row.option) : ({ exists: false })

    readonly property string kind: {
        const k = row.kind || "auto"
        if (["colorScheme", "accent", "repeat", "skin", "action", "listItem", "color",
             "password", "file", "savefile", "directory", "invertedToggle"].indexOf(k) >= 0)
            return k
        if (!opt.exists)
            return "none"
        const hasChoices = opt.choices && opt.choices.length > 0
        if (k === "slider" && (opt.min !== undefined || row.min !== undefined))
            return "slider"
        if (k === "number" && !hasChoices)
            return "number"
        if (k === "toggle" || opt.type === "bool")
            return "toggle"
        if (hasChoices)
            return "choice"
        switch (opt.type) {
        case "int": case "float": return (opt.min !== undefined && k === "slider") ? "slider" : "number"
        case "color": return "color"
        case "password": return "password"
        case "file": case "savefile": case "directory": return opt.type
        default: return "text"
        }
    }

    readonly property bool available: kind !== "none"
        && !(row.option && !opt.exists && ["colorScheme", "repeat", "skin", "action"].indexOf(kind) < 0)

    // fixed control column so every control lines up on the right
    property real controlWidth: VLCStyle.dp(300, VLCStyle.scale)

    visible: available
    spacing: VLCStyle.margin_normal
    Layout.minimumHeight: VLCStyle.dp(40, VLCStyle.scale)

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.Window
    }

    // revision bump so bindings re-read values after programmatic changes
    property int revision: 0
    Connections {
        target: SettingsBridge
        function onChanged(name) { if (name === root.row.option) root.revision++ }
        function onAllChanged() { root.revision++ }
    }

    function current() {
        root.revision // dependency
        return row.option ? SettingsBridge.value(row.option) : undefined
    }

    function apply(value) {
        if (SettingsBridge.setValue(row.option, value) && row.restart)
            root.restartRequired()
    }

    // ------------------------------------------------------------ label
    ColumnLayout {
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        Layout.alignment: Qt.AlignVCenter
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            spacing: VLCStyle.margin_xsmall

            T.Label {
                text: root.row.label
                color: theme.fg.secondary
                font.pixelSize: VLCStyle.fontSize_normal
                elide: Text.ElideRight
                Layout.fillWidth: true
                Layout.maximumWidth: implicitWidth
            }

            Widgets.IconLabel {
                id: helpIcon
                Layout.fillWidth: false
                readonly property string helpText: root.row.help || (root.opt.longText || "")
                visible: helpText.length > 0 && helpText !== root.row.label
                text: VLCIcons.info
                color: theme.fg.secondary
                font.pixelSize: VLCStyle.icon_small * 1.3

                HoverHandler { id: helpHover }
                T.ToolTip.visible: helpHover.hovered
                T.ToolTip.text: helpText
                T.ToolTip.delay: VLCStyle.delayToolTipAppear
            }

            Item { Layout.fillWidth: true }
        }

        T.Label {
            visible: root.row.restart === true
            text: qsTr("Applies after restarting VLC")
            color: theme.fg.secondary
            opacity: 0.7
            font.pixelSize: VLCStyle.fontSize_small
        }
    }

    // ------------------------------------------------------------ control
    Loader {
        Layout.preferredWidth: root.controlWidth
        Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
        sourceComponent: {
            switch (root.kind) {
            case "toggle": case "invertedToggle": case "listItem": case "skin": return toggleComponent
            case "choice": case "repeat": return choiceComponent
            case "slider": return sliderComponent
            case "number": return numberComponent
            case "file": case "savefile": case "directory": return pathComponent
            case "color": return colorComponent
            case "colorScheme": return colorSchemeComponent
            case "accent": return accentComponent
            case "action": return actionComponent
            case "password": case "text": return textComponent
            default: return null
            }
        }
    }

    // Toggle from the Figma "Toggle" component: ON/OFF pill with a square knob
    Component {
        id: toggleComponent

        Item {
            implicitHeight: VLCStyle.dp(28, VLCStyle.scale)

            readonly property bool checked: {
                root.revision
                switch (root.kind) {
                case "invertedToggle": return !root.current()
                case "listItem": return SettingsBridge.listContains(root.row.option, root.row.item)
                case "skin": return SettingsBridge.value("intf") === "skins"
                default: return !!root.current()
                }
            }

            function toggle() {
                const v = !checked
                switch (root.kind) {
                case "invertedToggle": root.apply(!v); break
                case "listItem":
                    if (SettingsBridge.setListContains(root.row.option, root.row.item, v) && root.row.restart)
                        root.restartRequired()
                    break
                case "skin":
                    SettingsBridge.setValue("intf", v ? "skins" : "")
                    root.restartRequired()
                    break
                default: root.apply(v)
                }
                root.revision++
            }

            T.AbstractButton {
                id: sw
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: VLCStyle.dp(60, VLCStyle.scale)
                height: VLCStyle.dp(28, VLCStyle.scale)
                focusPolicy: Qt.StrongFocus
                onClicked: parent.toggle()
                Accessible.role: Accessible.CheckBox
                Accessible.checked: parent.checked
                Accessible.name: root.row.label

                background: Rectangle {
                    radius: VLCStyle.dp(6, VLCStyle.scale)
                    color: sw.parent.checked ? Qt.darker(theme.accent, 3.8) : Qt.lighter(theme.bg.primary, 1.3)
                    border.color: sw.visualFocus ? theme.visualFocus : "transparent"
                    border.width: VLCStyle.dp(1, VLCStyle.scale)

                    Rectangle {
                        width: parent.height - VLCStyle.dp(6, VLCStyle.scale)
                        height: width
                        radius: VLCStyle.dp(4, VLCStyle.scale)
                        anchors.verticalCenter: parent.verticalCenter
                        x: sw.parent.checked ? parent.width - width - VLCStyle.dp(3, VLCStyle.scale) : VLCStyle.dp(3, VLCStyle.scale)
                        color: sw.parent.checked ? theme.accent : theme.fg.secondary
                        Behavior on x { NumberAnimation { duration: VLCStyle.duration_short } }
                    }

                    T.Label {
                        anchors.verticalCenter: parent.verticalCenter
                        x: sw.parent.checked ? VLCStyle.dp(8, VLCStyle.scale) : parent.width - width - VLCStyle.dp(6, VLCStyle.scale)
                        text: sw.parent.checked ? qsTr("ON") : qsTr("OFF")
                        color: sw.parent.checked ? theme.accent : theme.fg.secondary
                        font.pixelSize: VLCStyle.fontSize_small
                        font.weight: Font.Medium
                    }
                }
            }
        }
    }

    // Dropdown (choices from the option, or the repeat mode)
    Component {
        id: choiceComponent

        Widgets.ComboBoxExt {
            id: combo
            implicitHeight: VLCStyle.dp(34, VLCStyle.scale)
            textRole: "text"
            valueRole: "value"

            model: root.kind === "repeat"
                   ? [ { value: "off", text: qsTr("Off") }, { value: "all", text: qsTr("Repeat all") }, { value: "one", text: qsTr("Repeat one") } ]
                   : (root.row.choices || root.opt.choices)

            function sync() {
                root.revision
                let v
                if (root.kind === "repeat")
                    v = SettingsBridge.value("repeat") ? "one" : (SettingsBridge.value("loop") ? "all" : "off")
                else
                    v = root.current()
                for (let i = 0; i < model.length; ++i) {
                    if (String(model[i].value) === String(v)) {
                        currentIndex = i
                        return
                    }
                }
                currentIndex = -1
            }

            Component.onCompleted: sync()
            Connections {
                target: root
                function onRevisionChanged() { combo.sync() }
            }

            onActivated: (index) => {
                const v = model[index].value
                if (root.kind === "repeat") {
                    SettingsBridge.setValue("loop", v === "all")
                    SettingsBridge.setValue("repeat", v === "one")
                } else {
                    root.apply(v)
                }
            }
        }
    }

    // Slider with the current value printed on the right
    Component {
        id: sliderComponent

        RowLayout {
            spacing: VLCStyle.margin_small
            readonly property real factor: root.row.scale || 1
            readonly property bool integral: root.opt.type === "int" || root.opt.type === "bool"

            Widgets.SliderExt {
                id: slider
                Layout.fillWidth: true
                from: (root.row.min !== undefined ? root.row.min : root.opt.min * parent.factor)
                to: (root.row.max !== undefined ? root.row.max : root.opt.max * parent.factor)
                stepSize: root.row.step || 0
                value: { root.revision; return Number(root.current()) * parent.factor }
                onMoved: {
                    const v = value / parent.factor
                    root.apply(parent.integral ? Math.round(v) : v)
                }
            }

            T.Label {
                Layout.preferredWidth: VLCStyle.dp(56, VLCStyle.scale)
                horizontalAlignment: Text.AlignRight
                text: {
                    const v = slider.value
                    const shown = (root.row.step && root.row.step >= 1) || parent.integral && parent.factor === 1
                                  ? Math.round(v) : Math.round(v * 100) / 100
                    return shown + (root.row.unit ? (root.row.unit === "x" ? "x" : " " + root.row.unit) : "")
                }
                color: theme.fg.secondary
                font.pixelSize: VLCStyle.fontSize_normal
            }
        }
    }

    // Number entry
    Component {
        id: numberComponent

        RowLayout {
            spacing: VLCStyle.margin_xsmall

            Widgets.TextFieldExt {
                id: numberField
                Layout.fillWidth: true
                inputMethodHints: Qt.ImhFormattedNumbersOnly
                validator: root.opt.type === "float" ? doubleValidator : intValidator
                // floats are stored as single precision; show at most 3 decimals
                function shown() {
                    const v = Number(root.current())
                    return root.opt.type === "float" ? String(Math.round(v * 1000) / 1000) : String(v)
                }
                text: { root.revision; return shown() }
                onEditingFinished: {
                    const v = root.opt.type === "float" ? parseFloat(text) : parseInt(text, 10)
                    if (!isNaN(v))
                        root.apply(v)
                    text = shown()
                }
                IntValidator { id: intValidator; bottom: root.opt.min !== undefined ? root.opt.min : -2147483647; top: root.opt.max !== undefined ? root.opt.max : 2147483647 }
                DoubleValidator { id: doubleValidator; notation: DoubleValidator.StandardNotation }
            }

            T.Label {
                visible: !!root.row.unit
                text: root.row.unit || ""
                color: theme.fg.secondary
                font.pixelSize: VLCStyle.fontSize_normal
            }
        }
    }

    // Free text / password
    Component {
        id: textComponent

        Widgets.TextFieldExt {
            echoMode: root.kind === "password" ? TextInput.Password : TextInput.Normal
            text: { root.revision; return root.current() || "" }
            onEditingFinished: if (text !== (root.current() || "")) root.apply(text)
        }
    }

    // File or folder path with a Browse button
    Component {
        id: pathComponent

        RowLayout {
            spacing: VLCStyle.margin_xsmall

            Widgets.TextFieldExt {
                id: pathField
                Layout.fillWidth: true
                text: { root.revision; return root.current() || "" }
                onEditingFinished: if (text !== (root.current() || "")) root.apply(text)
            }

            Widgets.ButtonExt {
                text: qsTr("Browse")
                onClicked: {
                    const chosen = root.kind === "directory"
                                   ? SettingsBridge.pickDirectory(root.row.label, pathField.text)
                                   : SettingsBridge.pickFile(root.row.label, pathField.text, root.kind === "savefile")
                    if (chosen.length > 0)
                        root.apply(chosen)
                }
            }
        }
    }

    // RGB colour: swatch and hex entry
    Component {
        id: colorComponent

        RowLayout {
            spacing: VLCStyle.margin_xsmall

            function hex(v) {
                let s = Number(v).toString(16)
                while (s.length < 6) s = "0" + s
                return "#" + s.toUpperCase()
            }

            Rectangle {
                width: VLCStyle.dp(28, VLCStyle.scale)
                height: width
                radius: VLCStyle.dp(4, VLCStyle.scale)
                color: colorField.acceptableInput ? colorField.text : "transparent"
                border.color: theme.border
            }

            Widgets.TextFieldExt {
                id: colorField
                Layout.fillWidth: true
                validator: RegularExpressionValidator { regularExpression: /#[0-9A-Fa-f]{6}/ }
                text: { root.revision; return parent.hex(root.current()) }
                onEditingFinished: if (acceptableInput) root.apply(parseInt(text.substring(1), 16))
            }
        }
    }

    // Theme: System / Light / Dark segmented control
    Component {
        id: colorSchemeComponent

        Row {
            spacing: VLCStyle.dp(2, VLCStyle.scale)
            layoutDirection: Qt.RightToLeft

            Repeater {
                model: [ { scheme: 2, text: qsTr("Dark") }, { scheme: 1, text: qsTr("Light") }, { scheme: 0, text: qsTr("System") } ]
                delegate: T.AbstractButton {
                    id: seg
                    required property var modelData
                    readonly property bool selected: MainCtx.colorScheme.scheme === modelData.scheme
                    width: VLCStyle.dp(90, VLCStyle.scale)
                    height: VLCStyle.dp(32, VLCStyle.scale)
                    onClicked: MainCtx.colorScheme.setData(MainCtx.colorScheme.index(modelData.scheme, 0), true, Qt.CheckStateRole)
                    background: Rectangle {
                        radius: VLCStyle.dp(6, VLCStyle.scale)
                        color: seg.selected ? Qt.darker(theme.accent, 3.8) : Qt.lighter(theme.bg.primary, 1.3)
                        border.color: seg.visualFocus ? theme.visualFocus : "transparent"
                    }
                    contentItem: T.Label {
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        text: seg.modelData.text
                        color: seg.selected ? theme.accent : theme.fg.secondary
                        font.pixelSize: VLCStyle.fontSize_normal
                    }
                }
            }
        }
    }

    // Accent colour swatches from the design ("default" keeps VLC Redesign orange)
    Component {
        id: accentComponent

        Flow {
            spacing: VLCStyle.dp(4, VLCStyle.scale)
            layoutDirection: Qt.RightToLeft
            readonly property string value: { root.revision; return root.current() || "default" }

            Repeater {
                model: ["#888888", "#c2408c", "#6c3fd1", "#2f5bd3", "#1f8fa6", "#2e8b3a", "#a08a1e", "#c2401f", "default"]
                delegate: T.AbstractButton {
                    id: swatch
                    required property string modelData
                    readonly property bool selected: parent.value.toLowerCase() === modelData
                    width: VLCStyle.dp(26, VLCStyle.scale)
                    height: width
                    onClicked: root.apply(modelData)
                    Accessible.name: modelData === "default" ? qsTr("Default orange") : modelData
                    background: Rectangle {
                        radius: VLCStyle.dp(4, VLCStyle.scale)
                        color: swatch.modelData === "default" ? "#d37918" : swatch.modelData
                        border.width: swatch.selected || swatch.visualFocus ? VLCStyle.dp(2, VLCStyle.scale) : 0
                        border.color: theme.fg.primary
                    }
                }
            }
        }
    }

    // Button that runs an action of the settings window
    Component {
        id: actionComponent

        Item {
            implicitHeight: VLCStyle.dp(34, VLCStyle.scale)
            property bool armed: false // destructive actions need a second click

            Widgets.ButtonExt {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: parent.armed ? qsTr("Click again to confirm") : root.row.button
                onClicked: {
                    if (root.row.action === "resetAll" && !parent.armed) {
                        parent.armed = true
                        return
                    }
                    parent.armed = false
                    root.actionRequested(root.row.action)
                }
            }
        }
    }
}
