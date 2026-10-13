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

import VLC.Style
import VLC.Dialogs

// VLC Redesign: one titled group of rows in the settings window.
ColumnLayout {
    id: root

    property string title
    property var rows: []

    signal restartRequired()
    signal actionRequested(string action)

    spacing: VLCStyle.margin_xxsmall

    // hide the whole section when none of its options exist on this build
    visible: rows.some(rowAvailable)

    function rowAvailable(row) {
        if (!row.option || ["colorScheme", "repeat", "skin", "action"].indexOf(row.kind) >= 0)
            return true
        return SettingsBridge.option(row.option).exists === true
    }

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.Window
    }

    T.Label {
        Layout.fillWidth: true
        Layout.topMargin: VLCStyle.margin_small
        Layout.bottomMargin: VLCStyle.margin_xxsmall
        text: root.title
        color: theme.fg.primary
        font.pixelSize: VLCStyle.fontSize_large
        font.weight: Font.Medium
    }

    Repeater {
        model: root.rows
        delegate: SettingsRow {
            required property var modelData
            Layout.fillWidth: true
            row: modelData
            onRestartRequired: root.restartRequired()
            onActionRequested: (action) => root.actionRequested(action)
        }
    }
}
