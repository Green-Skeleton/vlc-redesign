/*****************************************************************************
 * Copyright (C) 2021 VLC authors and VideoLAN
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
import QtQuick.Layouts
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Widgets as Widgets
import VLC.Style

Window {
    id: root

    transientParent: MainCtx.intfMainWindow

    flags: Qt.Dialog

    property bool modal: false
    modality: modal ? Qt.ApplicationModal : Qt.NonModal

    width: VLCStyle.appWidth * 0.75
    height: VLCStyle.appHeight * 0.85

    color: theme.bg.primary

    property alias contentComponent: loader.sourceComponent
    // Combination of T.DialogButtonBox.StandardButton flags. Only Ok, Cancel,
    // Close and Apply are supported.
    property int standardButtons: T.DialogButtonBox.Ok | T.DialogButtonBox.Cancel
    property alias colorContext: layout.colorContext

    signal accepted()
    signal rejected(bool byButton)
    signal applied()
    signal discarded()
    signal reset()

    onAccepted: hide()
    onRejected: (byButton) => {
        if (byButton)
            hide()
    }
    onApplied: hide()
    onDiscarded: hide()
    onReset: hide()

    onClosing: {
        rejected(false)
    }

    property bool _placed: false

    function open() {
        // VLC Redesign: centre on the first showing so the title bar is
        // never off-screen
        if (!_placed) {
            x = Screen.virtualX + Math.max(0, (Screen.desktopAvailableWidth - width) / 2)
            y = Screen.virtualY + Math.max(0, (Screen.desktopAvailableHeight - height) / 2)
            _placed = true
        }
        show()
    }

    Component.onCompleted: {
        if (MainCtx.createWindowWithoutRedirectionSurface) { // Win32
            const ret = MainCtx.createWindowWithoutRedirectionSurface(this)
            if (!ret)
                console.debug("MainCtx::createWindowWithoutRedirectionSurface(): returned false for window", this)
        }
    }

    ColumnLayout {
        id: layout
        anchors.fill: parent
        anchors.margins: VLCStyle.margin_small


        readonly property ColorContext colorContext: ColorContext {
            palette: VLCStyle.palette
            colorSet: ColorContext.Window
        }

        Loader {
            id: loader
            Layout.fillHeight: true
            Layout.fillWidth: true

            clip: true
            sourceComponent: contentComponent
        }

        // VLC Redesign: plain button row instead of QtQuick.Controls'
        // DialogButtonBox, which is not part of the Windows build.
        RowLayout {
            id: buttonBox

            Layout.fillWidth: true
            Layout.minimumHeight: VLCStyle.icon_normal

            visible: root.standardButtons !== T.DialogButtonBox.NoButton
            spacing: VLCStyle.margin_small

            Item { Layout.fillWidth: true }

            Widgets.ButtonExt {
                visible: (root.standardButtons & T.DialogButtonBox.Apply) !== 0
                text: qsTr("Apply")
                onClicked: root.applied()
            }

            Widgets.ButtonExt {
                visible: (root.standardButtons & T.DialogButtonBox.Cancel) !== 0
                text: qsTr("Cancel")
                onClicked: root.rejected(true)
            }

            Widgets.ButtonExt {
                visible: (root.standardButtons & T.DialogButtonBox.Close) !== 0
                text: qsTr("Close")
                onClicked: root.rejected(true)
            }

            Widgets.ButtonExt {
                visible: (root.standardButtons & T.DialogButtonBox.Ok) !== 0
                text: qsTr("OK")
                onClicked: root.accepted()
            }
        }
    }
}
