/*****************************************************************************
 * settings_bridge.hpp: VLC configuration access for the QML settings window
 *****************************************************************************
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
#ifndef VLC_QT_SETTINGS_BRIDGE_HPP
#define VLC_QT_SETTINGS_BRIDGE_HPP

#include <QObject>
#include <QString>
#include <QVariant>

#include "qt.hpp"

/**
 * Exposes VLC configuration options to QML ("VLC Redesign" settings window).
 *
 * Options are addressed by their configuration name (e.g. "video-on-top").
 * Unknown names are reported with exists=false so the UI can hide them,
 * which keeps the settings pages valid across VLC versions and platforms.
 */
class SettingsBridge : public QObject
{
    Q_OBJECT

public:
    explicit SettingsBridge(qt_intf_t *intf, QObject *parent = nullptr);

    /**
     * Describes an option:
     *  exists, name, type ("bool", "int", "color", "float", "string",
     *  "password", "file", "savefile", "directory", "font", "module",
     *  "modulelist", "key"), value, defaultValue, min, max (scalars with a
     *  range), choices ([{value, text}]), text, longText.
     */
    Q_INVOKABLE QVariantMap option(const QString &name) const;

    Q_INVOKABLE QVariant value(const QString &name) const;

    /** Effective value, including command-line overrides (var_Inherit). */
    Q_INVOKABLE QVariant inherited(const QString &name) const;

    /** Sets an option; returns false if it does not exist or the type does not match. */
    Q_INVOKABLE bool setValue(const QString &name, const QVariant &value);

    Q_INVOKABLE void resetOption(const QString &name);

    /** Comma/colon separated module lists such as "audio-filter". */
    Q_INVOKABLE bool listContains(const QString &name, const QString &item) const;
    Q_INVOKABLE bool setListContains(const QString &name, const QString &item, bool enabled);

    /** Writes vlcrc. Settings are applied immediately but only persisted here. */
    Q_INVOKABLE void save();

    Q_INVOKABLE void resetAll();

    Q_INVOKABLE void openConfigFolder() const;

    /** Native file pickers; return an empty string when cancelled. */
    Q_INVOKABLE QString pickFile(const QString &title, const QString &current, bool forSaving) const;
    Q_INVOKABLE QString pickDirectory(const QString &title, const QString &current) const;

signals:
    void changed(const QString &name);
    void allChanged();

private:
    qt_intf_t *m_intf;
};

#endif // VLC_QT_SETTINGS_BRIDGE_HPP
