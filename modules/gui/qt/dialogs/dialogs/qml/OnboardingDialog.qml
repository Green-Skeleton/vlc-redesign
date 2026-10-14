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
import QtQuick.Window
import QtQuick.Templates as T
import QtQuick.Layouts

import VLC.MainInterface
import VLC.Widgets as Widgets
import VLC.Style
import VLC.Dialogs

// VLC Redesign: first-run welcome window following the "Onboarding" frames of
// the Figma design: welcome and media folder, theme and colour, keyboard
// shortcuts. It replaces VLC's first-run wizard and asks for the same
// privacy consent (fetching metadata from the internet).
WindowDialog {
    id: root

    title: qsTr("Welcome to VLC")
    modal: true

    width: VLCStyle.dp(1090, VLCStyle.scale) * 0.85
    height: VLCStyle.dp(759, VLCStyle.scale) * 0.85
    minimumWidth: VLCStyle.dp(760, VLCStyle.scale)
    minimumHeight: VLCStyle.dp(560, VLCStyle.scale)

    standardButtons: T.DialogButtonBox.NoButton

    property int step: 0
    readonly property int stepCount: 3
    property string mediaFolder: ""
    property bool allowNetwork: false // opt-in: nothing is looked up online unless ticked
    property bool finished: false

    function finish() {
        SettingsBridge.setValue("metadata-network-access", allowNetwork)
        if (mediaFolder.length > 0 && MainCtx.mediaLibraryAvailable) {
            const folders = Qt.createQmlObject("import VLC.MediaLibrary; MLFolderModel {}", root)
            folders.ctx = MainCtx
            folders.add(mediaFolder.indexOf("file:") === 0 ? mediaFolder : "file:///" + mediaFolder.replace(/\\/g, "/"))
            folders.destroy()
        }
        SettingsBridge.setValue("qt-privacy-ask", false)
        SettingsBridge.save()
        if (MainCtx.mediaLibraryAvailable)
            MainCtx.mediaLibrary.reload()
        finished = true
        close()
    }

    // closing the window early still records that the welcome was shown,
    // but keeps VLC's privacy default (no network access) as nothing was agreed to
    onClosing: {
        if (!finished) {
            SettingsBridge.setValue("qt-privacy-ask", false)
            SettingsBridge.save()
        }
    }

    // Shortcut key as shown on screen, from the configured hotkey ("Shift+Right" -> ["SHIFT", "→"])
    function keyCaps(option) {
        const value = SettingsBridge.value(option)
        if (!value)
            return []
        const symbols = { "Left": "←", "Right": "→", "Up": "↑", "Down": "↓", "Space": qsTr("Space") }
        return String(value).split("\t")[0].split("+").filter(k => k.length > 0)
                .map(k => symbols[k] || (k.length === 1 ? k.toUpperCase() : k.toUpperCase()))
    }

    contentComponent: Rectangle {
        color: Qt.darker(theme.bg.primary, 1.8)
        radius: VLCStyle.dp(10, VLCStyle.scale)

        readonly property ColorContext colorContext: ColorContext {
            id: theme
            palette: VLCStyle.palette
            colorSet: ColorContext.Window
        }

        StackLayout {
            id: pages
            anchors.fill: parent
            anchors.margins: VLCStyle.margin_xlarge
            anchors.bottomMargin: VLCStyle.dp(80, VLCStyle.scale)
            currentIndex: root.step

            // ---------------------------------------------------- 1: welcome
            ColumnLayout {
                spacing: VLCStyle.margin_normal

                Item { Layout.fillHeight: true; Layout.fillWidth: true }

                Widgets.BannerCone {
                    color: theme.accent
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: VLCStyle.dp(48, VLCStyle.scale)
                    Layout.preferredHeight: VLCStyle.dp(48, VLCStyle.scale)
                }

                T.Label {
                    Layout.alignment: Qt.AlignHCenter
                    text: qsTr("Welcome to VLC!")
                    color: theme.fg.primary
                    font.pixelSize: VLCStyle.dp(32, VLCStyle.scale)
                    font.weight: Font.Light
                }

                T.Label {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.maximumWidth: VLCStyle.dp(620, VLCStyle.scale)
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignLeft
                    lineHeight: 1.3
                    text: qsTr("VLC is a free and open source cross-platform multimedia player and framework that plays most multimedia files as well as DVDs, Audio CDs, VCDs, and various streaming protocols.")
                    color: theme.fg.secondary
                    font.pixelSize: VLCStyle.fontSize_large
                }

                ColumnLayout {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.maximumWidth: VLCStyle.dp(620, VLCStyle.scale)
                    Layout.fillWidth: true
                    Layout.topMargin: VLCStyle.margin_large
                    spacing: VLCStyle.margin_xsmall
                    visible: MainCtx.mediaLibraryAvailable

                    T.Label {
                        text: qsTr("Choose a media folder to get started with")
                        color: theme.fg.secondary
                        font.pixelSize: VLCStyle.fontSize_normal
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: VLCStyle.margin_xsmall

                        Widgets.TextFieldExt {
                            id: folderField
                            Layout.fillWidth: true
                            placeholderText: qsTr("No folder selected")
                            text: root.mediaFolder
                            onEditingFinished: root.mediaFolder = text
                        }

                        Widgets.ButtonExt {
                            text: qsTr("Browse")
                            onClicked: {
                                const dir = SettingsBridge.pickDirectory(qsTr("Choose a media folder"), root.mediaFolder)
                                if (dir.length > 0)
                                    root.mediaFolder = dir
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.maximumWidth: VLCStyle.dp(620, VLCStyle.scale)
                    Layout.fillWidth: true
                    Layout.topMargin: VLCStyle.margin_normal
                    spacing: VLCStyle.margin_small

                    Widgets.CheckBoxExt {
                        id: networkBox
                        checked: root.allowNetwork
                        onCheckedChanged: root.allowNetwork = checked
                    }

                    T.Label {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        text: qsTr("Fetch titles and cover art from the internet. VLC never collects personal data, but this shares the names of your media with online metadata services.")
                        color: theme.fg.secondary
                        font.pixelSize: VLCStyle.fontSize_normal

                        TapHandler { onTapped: networkBox.toggle() }
                    }
                }

                Item { Layout.fillHeight: true; Layout.fillWidth: true }
            }

            // ---------------------------------------------------- 2: theme and colour
            ColumnLayout {
                spacing: VLCStyle.margin_large

                Item { Layout.fillHeight: true; Layout.fillWidth: true }

                T.Label {
                    Layout.alignment: Qt.AlignHCenter
                    text: qsTr("Select your preferred theme and color.")
                    color: theme.fg.primary
                    font.pixelSize: VLCStyle.dp(24, VLCStyle.scale)
                    font.weight: Font.Light
                }

                Row {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: VLCStyle.margin_large
                    spacing: VLCStyle.margin_xlarge

                    Repeater {
                        model: [ { scheme: 1, text: qsTr("Light"), a: "#d5d5d5", b: "#d5d5d5" },
                                 { scheme: 2, text: qsTr("Dark"), a: "#262626", b: "#262626" },
                                 { scheme: 0, text: qsTr("System"), a: "#262626", b: "#d5d5d5" } ]
                        delegate: Column {
                            id: themeTile
                            required property var modelData
                            readonly property bool selected: MainCtx.colorScheme.scheme === modelData.scheme
                            spacing: VLCStyle.margin_small

                            T.AbstractButton {
                                id: tile
                                width: VLCStyle.dp(110, VLCStyle.scale)
                                height: width
                                onClicked: MainCtx.colorScheme.setData(MainCtx.colorScheme.index(themeTile.modelData.scheme, 0), true, Qt.CheckStateRole)
                                Accessible.name: themeTile.modelData.text

                                background: Rectangle {
                                    radius: VLCStyle.dp(14, VLCStyle.scale)
                                    color: "transparent"
                                    border.width: themeTile.selected || tile.visualFocus ? VLCStyle.dp(4, VLCStyle.scale) : 0
                                    border.color: theme.accent

                                    Rectangle {
                                        id: swatchTile
                                        anchors.fill: parent
                                        anchors.margins: VLCStyle.dp(8, VLCStyle.scale)
                                        radius: VLCStyle.dp(8, VLCStyle.scale)
                                        color: themeTile.modelData.a

                                        // split in half for "System"; the right half is a
                                        // clipped copy so its corners stay rounded
                                        Item {
                                            visible: themeTile.modelData.a !== themeTile.modelData.b
                                            x: parent.width / 2
                                            width: parent.width / 2
                                            height: parent.height
                                            clip: true

                                            Rectangle {
                                                x: -parent.x
                                                width: swatchTile.width
                                                height: swatchTile.height
                                                radius: swatchTile.radius
                                                color: themeTile.modelData.b
                                            }
                                        }
                                    }
                                }
                            }

                            T.Label {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: themeTile.modelData.text
                                color: themeTile.selected ? theme.fg.primary : theme.fg.secondary
                                font.pixelSize: VLCStyle.fontSize_large
                            }
                        }
                    }
                }

                T.Label {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: VLCStyle.margin_large
                    text: qsTr("Accent color (applies after restarting VLC)")
                    color: theme.fg.secondary
                    font.pixelSize: VLCStyle.fontSize_normal
                }

                Row {
                    id: accentRow
                    Layout.alignment: Qt.AlignHCenter
                    spacing: VLCStyle.margin_normal
                    property int revision: 0
                    readonly property string current: { revision; return String(SettingsBridge.value("qt-accent-color") || "default").toLowerCase() }

                    Repeater {
                        model: ["default", "#c2401f", "#a08a1e", "#2e8b3a", "#1f8fa6", "#2f5bd3", "#6c3fd1", "#c2408c", "#888888"]
                        delegate: T.AbstractButton {
                            id: dot
                            required property string modelData
                            readonly property bool selected: accentRow.current === modelData
                            width: VLCStyle.dp(36, VLCStyle.scale)
                            height: width
                            onClicked: {
                                SettingsBridge.setValue("qt-accent-color", modelData)
                                accentRow.revision++
                            }
                            Accessible.name: modelData === "default" ? qsTr("Default orange") : modelData
                            background: Rectangle {
                                radius: width / 2
                                color: dot.modelData === "default" ? "#d37918" : dot.modelData
                                border.width: dot.selected || dot.visualFocus ? VLCStyle.dp(3, VLCStyle.scale) : 0
                                border.color: theme.fg.primary
                            }
                        }
                    }
                }

                Item { Layout.fillHeight: true; Layout.fillWidth: true }
            }

            // ---------------------------------------------------- 3: keyboard shortcuts
            ColumnLayout {
                spacing: VLCStyle.margin_normal

                T.Label {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.bottomMargin: VLCStyle.margin_normal
                    text: qsTr("Learn the basic keyboard shortcuts.")
                    color: theme.fg.primary
                    font.pixelSize: VLCStyle.dp(24, VLCStyle.scale)
                    font.weight: Font.Light
                }

                GridLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    columns: 2
                    columnSpacing: VLCStyle.margin_xlarge
                    rowSpacing: VLCStyle.margin_small

                    Repeater {
                        model: [
                            { text: qsTr("Play / Pause"), keys: [["key-play-pause"]] },
                            { text: qsTr("Toggle Fullscreen"), keys: [["key-toggle-fullscreen"]] },
                            { text: qsTr("Seek Backward / Forward"), keys: [["key-jump-short"], ["key-jump+short"]] },
                            { text: qsTr("Increase / Decrease Volume"), keys: [["key-vol-up"], ["key-vol-down"]] },
                            { text: qsTr("Previous / Next Item"), keys: [["key-prev"], ["key-next"]] },
                            { text: qsTr("Previous / Next Frame"), keys: [["key-frame-previous"], ["key-frame-next"]] },
                            { text: qsTr("Cycle Subtitle Track"), keys: [["key-subtitle-track"]] },
                            { text: qsTr("Cycle Audio Track"), keys: [["key-audio-track"]] },
                            { text: qsTr("Take a Snapshot"), keys: [["key-snapshot"]] },
                            { text: qsTr("Record"), keys: [["key-record"]] }
                        ]
                        delegate: RowLayout {
                            id: shortcut
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: VLCStyle.margin_small

                            T.Label {
                                Layout.preferredWidth: VLCStyle.dp(200, VLCStyle.scale)
                                text: shortcut.modelData.text
                                color: theme.fg.secondary
                                font.pixelSize: VLCStyle.fontSize_normal
                                elide: Text.ElideRight
                            }

                            Repeater {
                                model: shortcut.modelData.keys
                                delegate: Row {
                                    id: combo
                                    required property var modelData
                                    required property int index
                                    spacing: VLCStyle.dp(4, VLCStyle.scale)

                                    T.Label {
                                        visible: combo.index > 0
                                        text: "/"
                                        color: theme.fg.secondary
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Repeater {
                                        model: root.keyCaps(combo.modelData[0])
                                        delegate: Rectangle {
                                            required property string modelData
                                            width: Math.max(VLCStyle.dp(34, VLCStyle.scale), capLabel.implicitWidth + VLCStyle.margin_small * 2)
                                            height: VLCStyle.dp(34, VLCStyle.scale)
                                            radius: VLCStyle.dp(6, VLCStyle.scale)
                                            color: Qt.lighter(theme.bg.primary, 1.3)
                                            border.color: theme.border
                                            border.width: VLCStyle.dp(1, VLCStyle.scale)

                                            T.Label {
                                                id: capLabel
                                                anchors.centerIn: parent
                                                text: parent.modelData
                                                color: theme.fg.primary
                                                font.pixelSize: VLCStyle.fontSize_normal
                                            }
                                        }
                                    }
                                }
                            }

                            Item { Layout.fillWidth: true }
                        }
                    }
                }
            }
        }

        // ---------------------------------------------------- footer
        RowLayout {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: VLCStyle.margin_xlarge
            spacing: VLCStyle.margin_small

            T.Label {
                visible: root.step === root.stepCount - 1
                text: qsTr("Find the full list in Settings, Controls.")
                color: theme.fg.secondary
                font.pixelSize: VLCStyle.fontSize_normal
            }

            Row {
                visible: root.step < root.stepCount - 1
                spacing: VLCStyle.dp(6, VLCStyle.scale)
                Repeater {
                    model: root.stepCount
                    delegate: Rectangle {
                        required property int index
                        width: VLCStyle.dp(8, VLCStyle.scale)
                        height: width
                        radius: width / 2
                        color: index === root.step ? theme.accent : theme.border
                    }
                }
            }

            Item { Layout.fillWidth: true }

            Widgets.ButtonExt {
                visible: root.step > 0
                text: qsTr("Back")
                onClicked: root.step -= 1
            }

            Widgets.ActionButtonPrimary {
                text: root.step === root.stepCount - 1 ? qsTr("Finish") : qsTr("Next")
                onClicked: {
                    if (root.step === root.stepCount - 1)
                        root.finish()
                    else
                        root.step += 1
                }
            }
        }
    }
}
