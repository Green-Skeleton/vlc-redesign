/*****************************************************************************
 * settings_bridge.cpp: VLC configuration access for the QML settings window
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
#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#include "settings_bridge.hpp"

#include <vlc_common.h>
#include <vlc_configuration.h>
#include <vlc_plugin.h>

#include <QDesktopServices>
#include <QDir>
#include <QFileDialog>
#include <QRegularExpression>
#include <QUrl>
#include <QVariantList>

#include <cfloat>
#include <cstdint>
#include <cstdlib>

namespace {

QString typeName(int type)
{
    switch (type)
    {
    case CONFIG_ITEM_BOOL:            return QStringLiteral("bool");
    case CONFIG_ITEM_INTEGER:         return QStringLiteral("int");
    case CONFIG_ITEM_RGB:             return QStringLiteral("color");
    case CONFIG_ITEM_FLOAT:           return QStringLiteral("float");
    case CONFIG_ITEM_PASSWORD:        return QStringLiteral("password");
    case CONFIG_ITEM_KEY:             return QStringLiteral("key");
    case CONFIG_ITEM_MODULE:
    case CONFIG_ITEM_MODULE_CAT:      return QStringLiteral("module");
    case CONFIG_ITEM_MODULE_LIST:
    case CONFIG_ITEM_MODULE_LIST_CAT: return QStringLiteral("modulelist");
    case CONFIG_ITEM_LOADFILE:        return QStringLiteral("file");
    case CONFIG_ITEM_SAVEFILE:        return QStringLiteral("savefile");
    case CONFIG_ITEM_DIRECTORY:       return QStringLiteral("directory");
    case CONFIG_ITEM_FONT:            return QStringLiteral("font");
    default:
        return IsConfigStringType(type) ? QStringLiteral("string") : QString();
    }
}

QStringList splitList(const QString &list)
{
    static const QRegularExpression sep(QStringLiteral("[:,]"));
    QStringList items = list.split(sep, Qt::SkipEmptyParts);
    for (QString &item : items)
        item = item.trimmed();
    items.removeAll(QString());
    return items;
}

} // namespace

SettingsBridge::SettingsBridge(qt_intf_t *intf, QObject *parent)
    : QObject(parent)
    , m_intf(intf)
{
}

QVariantMap SettingsBridge::option(const QString &name) const
{
    QVariantMap out;
    const QByteArray key = name.toUtf8();
    const module_config_t *item = config_FindConfig(key.constData());
    if (!item || typeName(item->i_type).isEmpty())
    {
        out.insert(QStringLiteral("exists"), false);
        return out;
    }

    out.insert(QStringLiteral("exists"), true);
    out.insert(QStringLiteral("name"), name);
    out.insert(QStringLiteral("type"), typeName(item->i_type));
    out.insert(QStringLiteral("text"), item->psz_text ? qtr(item->psz_text) : name);
    out.insert(QStringLiteral("longText"), item->psz_longtext ? qtr(item->psz_longtext) : QString());
    out.insert(QStringLiteral("value"), value(name));

    QVariantList choices;
    if (IsConfigIntegerType(item->i_type))
    {
        out.insert(QStringLiteral("defaultValue"), QVariant::fromValue<qlonglong>(item->orig.i));
        if (item->min.i > INT32_MIN && item->max.i < INT32_MAX && item->min.i < item->max.i)
        {
            out.insert(QStringLiteral("min"), QVariant::fromValue<qlonglong>(item->min.i));
            out.insert(QStringLiteral("max"), QVariant::fromValue<qlonglong>(item->max.i));
        }

        int64_t *values = nullptr;
        char **texts = nullptr;
        const ssize_t count = config_GetIntChoices(key.constData(), &values, &texts);
        for (ssize_t i = 0; i < count; ++i)
        {
            choices.append(QVariantMap{ { QStringLiteral("value"), QVariant::fromValue<qlonglong>(values[i]) },
                                        { QStringLiteral("text"), qfu(texts[i]) } });
            free(texts[i]);
        }
        free(values);
        free(texts);
    }
    else if (IsConfigFloatType(item->i_type))
    {
        out.insert(QStringLiteral("defaultValue"), static_cast<double>(item->orig.f));
        if (item->min.f > -FLT_MAX && item->max.f < FLT_MAX && item->min.f < item->max.f)
        {
            out.insert(QStringLiteral("min"), static_cast<double>(item->min.f));
            out.insert(QStringLiteral("max"), static_cast<double>(item->max.f));
        }
    }
    else
    {
        out.insert(QStringLiteral("defaultValue"), item->orig.psz ? qfu(item->orig.psz) : QString());

        char **values = nullptr;
        char **texts = nullptr;
        const ssize_t count = config_GetPszChoices(key.constData(), &values, &texts);
        for (ssize_t i = 0; i < count; ++i)
        {
            choices.append(QVariantMap{ { QStringLiteral("value"), values[i] ? qfu(values[i]) : QString() },
                                        { QStringLiteral("text"), texts[i] ? qfu(texts[i]) : QString() } });
            free(values[i]);
            free(texts[i]);
        }
        free(values);
        free(texts);
    }
    out.insert(QStringLiteral("choices"), choices);
    return out;
}

QVariant SettingsBridge::value(const QString &name) const
{
    const QByteArray key = name.toUtf8();
    const int type = config_GetType(key.constData());
    if (type == 0)
        return QVariant();

    if (type == VLC_VAR_BOOL)
        return config_GetInt(key.constData()) != 0;
    if (type == VLC_VAR_INTEGER)
        return QVariant::fromValue<qlonglong>(config_GetInt(key.constData()));
    if (type == VLC_VAR_FLOAT)
        return static_cast<double>(config_GetFloat(key.constData()));

    char *psz = config_GetPsz(key.constData());
    const QString str = psz ? qfu(psz) : QString();
    free(psz);
    return str;
}

bool SettingsBridge::setValue(const QString &name, const QVariant &newValue)
{
    const QByteArray key = name.toUtf8();
    const module_config_t *item = config_FindConfig(key.constData());
    if (!item)
        return false;

    if (item->i_type == CONFIG_ITEM_BOOL)
    {
        config_PutInt(key.constData(), newValue.toBool() ? 1 : 0);
    }
    else if (IsConfigIntegerType(item->i_type))
    {
        bool ok = false;
        qlonglong v = newValue.toLongLong(&ok);
        if (!ok)
            return false;
        if (item->min.i < item->max.i)
            v = qBound<qlonglong>(item->min.i, v, item->max.i);
        config_PutInt(key.constData(), v);
    }
    else if (IsConfigFloatType(item->i_type))
    {
        bool ok = false;
        double v = newValue.toDouble(&ok);
        if (!ok)
            return false;
        if (item->min.f < item->max.f)
            v = qBound<double>(item->min.f, v, item->max.f);
        config_PutFloat(key.constData(), static_cast<float>(v));
    }
    else if (IsConfigStringType(item->i_type))
    {
        const QByteArray str = newValue.toString().toUtf8();
        config_PutPsz(key.constData(), str.constData());
    }
    else
    {
        return false;
    }

    emit changed(name);
    return true;
}

void SettingsBridge::resetOption(const QString &name)
{
    const QByteArray key = name.toUtf8();
    const module_config_t *item = config_FindConfig(key.constData());
    if (!item)
        return;

    if (IsConfigIntegerType(item->i_type))
        config_PutInt(key.constData(), item->orig.i);
    else if (IsConfigFloatType(item->i_type))
        config_PutFloat(key.constData(), item->orig.f);
    else if (IsConfigStringType(item->i_type))
        config_PutPsz(key.constData(), item->orig.psz);
    emit changed(name);
}

bool SettingsBridge::listContains(const QString &name, const QString &item) const
{
    return splitList(value(name).toString()).contains(item);
}

bool SettingsBridge::setListContains(const QString &name, const QString &item, bool enabled)
{
    QStringList items = splitList(value(name).toString());
    if (enabled == items.contains(item))
        return true;
    if (enabled)
        items.append(item);
    else
        items.removeAll(item);
    return setValue(name, items.join(QLatin1Char(':')));
}

void SettingsBridge::save()
{
    config_SaveConfigFile(m_intf);
}

void SettingsBridge::resetAll()
{
    config_ResetAll();
    config_SaveConfigFile(m_intf);
    emit allChanged();
}

void SettingsBridge::openConfigFolder() const
{
    char *dir = config_GetUserDir(VLC_USERDATA_DIR);
    if (!dir)
        return;
    const QString path = qfu(dir);
    free(dir);
    QDir().mkpath(path);
    QDesktopServices::openUrl(QUrl::fromLocalFile(path));
}

QString SettingsBridge::pickFile(const QString &title, const QString &current, bool forSaving) const
{
    const QString file = forSaving ? QFileDialog::getSaveFileName(nullptr, title, current)
                                   : QFileDialog::getOpenFileName(nullptr, title, current);
    return QDir::toNativeSeparators(file);
}

QString SettingsBridge::pickDirectory(const QString &title, const QString &current) const
{
    return QDir::toNativeSeparators(QFileDialog::getExistingDirectory(nullptr, title, current));
}
