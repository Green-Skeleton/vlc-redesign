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

// VLC Redesign: settings window following the "Settings - *" frames of the
// Figma design. Changes are written to VLC's configuration as they are made
// and saved to disk when the window closes.
WindowDialog {
    id: root

    title: qsTr("Settings")
    modal: false

    width: Math.min(VLCStyle.dp(1048, VLCStyle.scale), Screen.width * 0.9)
    height: Math.min(VLCStyle.dp(800, VLCStyle.scale), Screen.height * 0.85)
    minimumWidth: VLCStyle.dp(720, VLCStyle.scale)
    minimumHeight: VLCStyle.dp(480, VLCStyle.scale)

    standardButtons: T.DialogButtonBox.Close

    property int pageIndex: 0
    property string searchText: ""
    property bool restartNeeded: false

    readonly property var pages: settingsPages.pages

    SettingsPages { id: settingsPages }

    function openPage(id) {
        for (let i = 0; i < pages.length; ++i) {
            if (pages[i].id === id) {
                pageIndex = i
                break
            }
        }
        open()
    }

    onAccepted: SettingsBridge.save()
    onRejected: SettingsBridge.save()
    onVisibleChanged: if (!visible) SettingsBridge.save()

    function runAction(action) {
        switch (action) {
        case "openConfigFolder":
            SettingsBridge.openConfigFolder()
            break
        case "resetAll":
            SettingsBridge.resetAll()
            root.restartNeeded = true
            break
        case "resetPicture":
            for (const name of ["hue", "brightness", "contrast", "saturation", "gamma"])
                SettingsBridge.resetOption(name)
            break
        case "clearHistory":
            if (MainCtx.mediaLibraryAvailable) {
                const model = Qt.createQmlObject("import VLC.MediaLibrary; MLRecentMediaModel {}", root)
                model.ml = MainCtx.mediaLibrary
                model.clearHistory()
                model.destroy()
            }
            break
        case "equalizer":
            DialogsProvider.extendedDialog()
            break
        case "addons":
            DialogsProvider.pluginDialog()
            break
        case "toolbarEditor":
            DialogsProvider.showToolbarEditorDialog()
            break
        case "advancedPreferences":
            DialogsProvider.advancedPrefsDialog()
            break
        }
    }

    // rows matching the search, across every page
    function searchResults(text) {
        const needle = text.toLowerCase()
        const out = []
        for (const page of pages) {
            const rows = []
            for (const section of page.sections)
                for (const row of section.rows)
                    if (row.label.toLowerCase().indexOf(needle) >= 0)
                        rows.push(row)
            for (const row of page.advanced)
                if (row.label.toLowerCase().indexOf(needle) >= 0)
                    rows.push(row)
            if (rows.length > 0)
                out.push({ title: page.title, rows: rows })
        }
        return out
    }

    contentComponent: RowLayout {
        spacing: 0

        readonly property ColorContext colorContext: ColorContext {
            id: theme
            palette: VLCStyle.palette
            colorSet: ColorContext.Window
        }

        // ------------------------------------------------------------ sidebar
        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: VLCStyle.dp(220, VLCStyle.scale)
            color: Qt.lighter(theme.bg.primary, 1.24)
            radius: VLCStyle.dp(10, VLCStyle.scale)

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: VLCStyle.margin_small
                spacing: VLCStyle.margin_xxsmall

                Widgets.TextFieldExt {
                    id: searchField
                    Layout.fillWidth: true
                    placeholderText: qsTr("Search settings")
                    onTextChanged: root.searchText = text
                }

                ListView {
                    id: pageList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.topMargin: VLCStyle.margin_xsmall
                    clip: true
                    model: root.pages
                    currentIndex: root.pageIndex
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Column {
                        id: pageEntry
                        required property var modelData
                        required property int index
                        width: ListView.view.width

                        readonly property bool showGroup: index === 0 || root.pages[index - 1].group !== modelData.group

                        T.Label {
                            visible: pageEntry.showGroup
                            width: parent.width
                            topPadding: pageEntry.index === 0 ? 0 : VLCStyle.margin_small
                            bottomPadding: VLCStyle.margin_xxsmall
                            leftPadding: VLCStyle.margin_xsmall
                            text: pageEntry.modelData.group
                            color: theme.fg.secondary
                            font.pixelSize: VLCStyle.fontSize_normal
                        }

                        T.ItemDelegate {
                            id: pageDelegate
                            width: parent.width
                            height: VLCStyle.dp(36, VLCStyle.scale)
                            readonly property bool current: pageEntry.index === root.pageIndex && root.searchText.length === 0

                            onClicked: {
                                root.pageIndex = pageEntry.index
                                searchField.text = ""
                            }

                            background: Rectangle {
                                radius: VLCStyle.dp(6, VLCStyle.scale)
                                color: pageDelegate.current ? theme.bg.secondary
                                     : pageDelegate.hovered ? Qt.lighter(theme.bg.primary, 1.4) : "transparent"
                            }

                            contentItem: T.Label {
                                leftPadding: VLCStyle.margin_small
                                verticalAlignment: Text.AlignVCenter
                                text: pageEntry.modelData.title
                                color: pageDelegate.current ? theme.accent : theme.fg.primary
                                font.pixelSize: VLCStyle.fontSize_large
                                font.weight: pageDelegate.current ? Font.Medium : Font.Normal
                            }
                        }
                    }
                }

                Widgets.ButtonExt {
                    Layout.fillWidth: true
                    text: qsTr("All preferences…")
                    onClicked: root.runAction("advancedPreferences")
                }
            }
        }

        // ------------------------------------------------------------ content
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: VLCStyle.margin_large
            spacing: VLCStyle.margin_small

            T.Label {
                Layout.fillWidth: true
                text: root.searchText.length > 0 ? qsTr("Search results")
                                                 : root.pages[root.pageIndex].heading
                color: theme.fg.primary
                font.pixelSize: VLCStyle.fontSize_xlarge
                font.weight: Font.DemiBold
            }

            T.Label {
                Layout.fillWidth: true
                visible: root.restartNeeded
                text: qsTr("Restart VLC to apply some of your changes.")
                color: theme.accent
                font.pixelSize: VLCStyle.fontSize_normal
            }

            Flickable {
                id: flick
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentHeight: pageColumn.implicitHeight + VLCStyle.margin_large
                boundsBehavior: Flickable.StopAtBounds
                T.ScrollBar.vertical: Widgets.ScrollBarExt { }

                Connections {
                    target: root
                    function onPageIndexChanged() { flick.contentY = 0 }
                    function onSearchTextChanged() { flick.contentY = 0 }
                }

                ColumnLayout {
                    id: pageColumn
                    width: flick.width - VLCStyle.margin_normal
                    spacing: VLCStyle.margin_normal

                    readonly property var page: root.pages[root.pageIndex]
                    readonly property var sections: root.searchText.length > 0 ? root.searchResults(root.searchText)
                                                                               : page.sections
                    property bool showAdvanced: false

                    Connections {
                        target: root
                        function onPageIndexChanged() { pageColumn.showAdvanced = false }
                    }

                    Repeater {
                        model: pageColumn.sections
                        delegate: SettingsSection {
                            required property var modelData
                            Layout.fillWidth: true
                            title: modelData.title
                            rows: modelData.rows
                            onRestartRequired: root.restartNeeded = true
                            onActionRequested: (action) => root.runAction(action)
                        }
                    }

                    T.Label {
                        Layout.fillWidth: true
                        visible: root.searchText.length > 0 && pageColumn.sections.length === 0
                        text: qsTr("No settings match \"%1\".").arg(root.searchText)
                        color: theme.fg.secondary
                    }

                    // "Advanced Options" bar from the design
                    T.ItemDelegate {
                        id: advancedToggle
                        Layout.fillWidth: true
                        Layout.preferredHeight: VLCStyle.dp(40, VLCStyle.scale)
                        visible: root.searchText.length === 0 && pageColumn.page.advanced.length > 0
                        onClicked: pageColumn.showAdvanced = !pageColumn.showAdvanced

                        background: Rectangle {
                            radius: VLCStyle.dp(6, VLCStyle.scale)
                            color: advancedToggle.hovered ? Qt.lighter(theme.bg.primary, 1.4)
                                                          : Qt.lighter(theme.bg.primary, 1.24)
                        }
                        contentItem: Item {
                            Row {
                                anchors.centerIn: parent
                                spacing: VLCStyle.margin_xsmall

                                T.Label {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: pageColumn.showAdvanced ? qsTr("Hide Advanced Options") : qsTr("Advanced Options")
                                    color: theme.fg.secondary
                                    font.pixelSize: VLCStyle.fontSize_normal
                                }

                                Widgets.IconLabel {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: pageColumn.showAdvanced ? VLCIcons.chevron_up : VLCIcons.chevron_down
                                    color: theme.fg.secondary
                                    font.pixelSize: VLCStyle.icon_small
                                }
                            }
                        }
                    }

                    SettingsSection {
                        Layout.fillWidth: true
                        visible: root.searchText.length === 0 && pageColumn.showAdvanced
                        title: qsTr("Advanced Options")
                        rows: pageColumn.page.advanced
                        onRestartRequired: root.restartNeeded = true
                        onActionRequested: (action) => root.runAction(action)
                    }
                }
            }
        }
    }
}
