/*****************************************************************************
 * Copyright (C) 2020 VLC authors and VideoLAN
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
#include "systempalette.hpp"
#include <QGuiApplication>
#include <QPalette>
#include <QSettings>
#include <QFile>
#include <maininterface/mainctx.hpp>
#include <vlc_modules.h>
#include <vlc_picture.h>

namespace {

QColor setColorAlpha(const QColor& c1, float alpha)
{
    QColor c(c1);
    c.setAlphaF(alpha);
    return c;
}

#ifndef _WIN32
/**
 * function taken from QtBase gui/platform/unix/qgenericunixservices.cpp
 */
static inline QByteArray detectLinuxDesktopEnvironment()
{
    const QByteArray xdgCurrentDesktop = qgetenv("XDG_CURRENT_DESKTOP");
    if (!xdgCurrentDesktop.isEmpty())
        return xdgCurrentDesktop.toUpper(); // KDE, GNOME, UNITY, LXDE, MATE, XFCE...

    // Classic fallbacks
    if (!qEnvironmentVariableIsEmpty("KDE_FULL_SESSION"))
        return QByteArrayLiteral("KDE");
    if (!qEnvironmentVariableIsEmpty("GNOME_DESKTOP_SESSION_ID"))
        return QByteArrayLiteral("GNOME");

    // Fallback to checking $DESKTOP_SESSION (unreliable)
    QByteArray desktopSession = qgetenv("DESKTOP_SESSION");

    // This can be a path in /usr/share/xsessions
    int slash = desktopSession.lastIndexOf('/');
    if (slash != -1) {
        QSettings desktopFile(QFile::decodeName(desktopSession + ".desktop"), QSettings::IniFormat);
        desktopFile.beginGroup(QStringLiteral("Desktop Entry"));
        QByteArray desktopName = desktopFile.value(QStringLiteral("DesktopNames")).toByteArray();
        if (!desktopName.isEmpty())
            return desktopName;

        // try decoding just the basename
        desktopSession = desktopSession.mid(slash + 1);
    }

    if (desktopSession == "gnome")
        return QByteArrayLiteral("GNOME");
    else if (desktopSession == "xfce")
        return QByteArrayLiteral("XFCE");
    else if (desktopSession == "kde")
        return QByteArrayLiteral("KDE");

    return QByteArrayLiteral("UNKNOWN");
}

bool isGTKBasedEnvironment()
{
    QList<QByteArray> gtkBasedEnvironments{
        "GNOME",
        "X-CINNAMON",
        "UNITY",
        "MATE",
        "XFCE",
        "LXDE"
    };
    const QList<QByteArray> desktopNames = detectLinuxDesktopEnvironment().split(':');
    for (const QByteArray& desktopName: desktopNames)
    {
        if (gtkBasedEnvironments.contains(desktopName))
            return true;
    }
    return false;
}
#endif


static void PaletteChangedCallback(vlc_qt_theme_provider_t*, void* data)
{
    auto priv = static_cast<ExternalPaletteImpl*>(data);
    emit priv->paletteChanged();
}

static void MetricsChangedCallback(vlc_qt_theme_provider_t*, vlc_qt_theme_image_type type, void* data)
{
    auto priv = static_cast<ExternalPaletteImpl*>(data);
    assert(priv);
    priv->updateMetrics(type);
}


static void ReleaseVLCPictureCb(void* data)
{
    auto pic = static_cast<picture_t*>(data);
    if (pic)
        picture_Release(pic);
}


static void setColorRBGAInt(
    vlc_qt_theme_provider_t* obj,
    vlc_qt_theme_color_set set, vlc_qt_theme_color_section section,
    vlc_qt_theme_color_name name, vlc_qt_theme_color_state state,
    int r, int g, int b, int a)
{
    auto palette = static_cast<SystemPalette*>(obj->setColorData);
    QColor color(r,g,b,a);
    palette->setColor(
        static_cast<ColorContext::ColorSet>(set), static_cast<ColorContext::ColorSection>(section),
        static_cast<ColorContext::ColorName>(name), static_cast<ColorContext::ColorState>(state),
        color);
}

static void setColorRBGAFloat(
    vlc_qt_theme_provider_t* obj,
    vlc_qt_theme_color_set set, vlc_qt_theme_color_section section,
    vlc_qt_theme_color_name name, vlc_qt_theme_color_state state,
    double r, double g, double b, double a)
{
    auto palette = static_cast<SystemPalette*>(obj->setColorData);
    QColor color;
    color.setRgbF(r,g,b,a);
    palette->setColor(
        static_cast<ColorContext::ColorSet>(set), static_cast<ColorContext::ColorSection>(section),
        static_cast<ColorContext::ColorName>(name), static_cast<ColorContext::ColorState>(state),
        color);
}

}

//ExternalPaletteImpl

ExternalPaletteImpl::ExternalPaletteImpl(MainCtx* ctx, SystemPalette& palette, QObject* parent)
    : QObject(parent)
    , m_palette(palette)
    , m_ctx(ctx)
{
}

ExternalPaletteImpl::~ExternalPaletteImpl()
{
    if (m_provider)
    {
        if (m_provider->close)
            m_provider->close(m_provider);
        if (m_module)
            module_unneed(m_provider, m_module);
        vlc_object_delete(m_provider);
    }
}

bool ExternalPaletteImpl::init()
{
    QString preferedProvider;
#ifndef _WIN32
    if (isGTKBasedEnvironment())
        preferedProvider = "qt-themeprovider-gtk";
#endif

    m_provider = vlc_object_create<vlc_qt_theme_provider_t>(m_ctx->getIntf());
    if (!m_provider)
        return false;


    m_provider->paletteUpdated = PaletteChangedCallback;
    m_provider->paletteUpdatedData = this;

    m_provider->metricsUpdated = MetricsChangedCallback;
    m_provider->metricsUpdatedData = this;

    m_provider->setColorF = setColorRBGAFloat;
    m_provider->setColorInt = setColorRBGAInt;
    m_provider->setColorData = &m_palette;

    m_module = module_need(m_provider, "qt theme provider",
                           preferedProvider.isNull() ? nullptr : qtu(preferedProvider),
                           true);
    if (!m_module)
        return false;
    return true;
}

bool ExternalPaletteImpl::isThemeDark() const
{
    if (!m_provider->isThemeDark)
        return false;
    return m_provider->isThemeDark(m_provider);
}

bool ExternalPaletteImpl::hasCSDImages() const
{
    if (!m_provider->supportThemeImage)
        return false;
    return m_provider->supportThemeImage(m_provider, VLC_QT_THEME_IMAGE_TYPE_CSD_BUTTON);
}


QImage ExternalPaletteImpl::getCSDImage(vlc_qt_theme_csd_button_type type, vlc_qt_theme_csd_button_state state, bool maximized, bool active, int bannerHeight)
{
    if (!m_provider->getThemeImage)
        return {};
    vlc_qt_theme_image_setting imageSettings;
    imageSettings.windowScaleFactor = m_ctx->intfMainWindow()->devicePixelRatio();
    imageSettings.userScaleFacor = m_ctx->getIntfUserScaleFactor();
    imageSettings.u.csdButton.buttonType = type;
    imageSettings.u.csdButton.state = state;
    imageSettings.u.csdButton.maximized = maximized;
    imageSettings.u.csdButton.active = active;
    imageSettings.u.csdButton.bannerHeight = bannerHeight;
    picture_t* pic = m_provider->getThemeImage(m_provider, VLC_QT_THEME_IMAGE_TYPE_CSD_BUTTON, &imageSettings);
    if (!pic)
        return {};

    QImage::Format format = QImage::Format_Invalid;
    switch (pic->format.i_chroma)
    {
    case VLC_CODEC_ARGB:
        format = QImage::Format_ARGB32_Premultiplied;
        break;
    case VLC_CODEC_RGBA:
        format = QImage::Format_RGBA8888_Premultiplied;
        break;
    case VLC_CODEC_RGB24:
        format = QImage::Format_RGB888;
        break;
    default:
        msg_Err(m_ctx->getIntf(), "unexpected image format from theme provider");
        break;
    }

    return QImage(pic->p[0].p_pixels,
            pic->format.i_visible_width, pic->format.i_visible_height, pic->p[0].i_pitch,
            format,
            ReleaseVLCPictureCb, pic
            );
}

CSDMetrics* ExternalPaletteImpl::getCSDMetrics() const
{
    return m_csdMetrics.get();
}

int ExternalPaletteImpl::update()
{
    if (m_provider->updatePalette)
        return m_provider->updatePalette(m_provider);
    return VLC_EGENERIC;
}

void ExternalPaletteImpl::updateMetrics(vlc_qt_theme_image_type type)
{
    if (m_provider->getThemeMetrics)
    {
        if (type == VLC_QT_THEME_IMAGE_TYPE_CSD_BUTTON)
        {
            m_csdMetrics.reset();
            [&](){
                if (!m_provider->getThemeMetrics)
                    return;
                vlc_qt_theme_metrics metrics;
                memset(&metrics, 0, sizeof(metrics));
                bool ret = m_provider->getThemeMetrics(m_provider, VLC_QT_THEME_IMAGE_TYPE_CSD_BUTTON, &metrics);
                if (!ret)
                    return;
                m_csdMetrics = std::make_unique<CSDMetrics>();
                m_csdMetrics->interNavButtonSpacing = metrics.u.csd.interNavButtonSpacing;

                m_csdMetrics->csdFrameMarginLeft = metrics.u.csd.csdFrameMarginLeft;
                m_csdMetrics->csdFrameMarginRight = metrics.u.csd.csdFrameMarginRight;
                m_csdMetrics->csdFrameMarginTop = metrics.u.csd.csdFrameMarginTop;
                m_csdMetrics->csdFrameMarginBottom = metrics.u.csd.csdFrameMarginBottom;
            }();
            emit CSDMetricsChanged();
        }
    }
}

SystemPalette::SystemPalette(QObject* parent)
    : QObject(parent)
{

}

void SystemPalette::componentComplete()
{
    {
        assert(m_ctx);
        char* accentColor = var_InheritString(m_ctx->getIntf(), "qt-accent-color");
        assert(accentColor);

        if (!strcmp(accentColor, "default"))
        {
            // Use default
        }
#if QT_VERSION >= QT_VERSION_CHECK(6, 6, 0)
        else if (!strcmp(accentColor, "system"))
        {
            assert(qApp);
            const auto palette = qApp->palette();

            orange500 = palette.color(QPalette::Normal, QPalette::Accent);
            orange800 = orange500.lighter(150);
        }
#endif
        else
        {
            orange500 = QColor(accentColor);
            orange800 = orange500.lighter(150);
        }

        free(accentColor);
    }

    updatePalette();
}

ColorSchemeModel::ColorScheme SystemPalette::source() const
{
    return m_source;
}

QImage SystemPalette::getCSDImage(vlc_qt_theme_csd_button_type type, vlc_qt_theme_csd_button_state state, bool maximized, bool active, int bannerHeight)
{
    if (!hasCSDImage())
        return QImage();
    assert(m_palettePriv);
    return m_palettePriv->getCSDImage(type, state, maximized, active, bannerHeight);

}

CSDMetrics* SystemPalette::getCSDMetrics() const
{
    if (!m_palettePriv)
        return nullptr;
    return m_palettePriv->getCSDMetrics();
}

bool SystemPalette::hasCSDImage() const
{
    if (!m_palettePriv)
        return false;
    return m_palettePriv->hasCSDImages();
}

void SystemPalette::setSource(ColorSchemeModel::ColorScheme source)
{
    if (m_source == source)
        return;
    m_source = source;

    updatePalette();
    emit sourceChanged();
}

void SystemPalette::setCtx(MainCtx* ctx)
{
    if (ctx == m_ctx)
        return;
    m_ctx = ctx;
    emit ctxChanged();
    updatePalette();
}

void SystemPalette::updatePalette()
{
    m_palettePriv.reset();
    switch(m_source)
    {
    case ColorSchemeModel::System:
        makeSystemPalette();
        break;
    case ColorSchemeModel::Day:
        makeLightPalette();
        break;
    case ColorSchemeModel::Night:
        makeDarkPalette();
        break;
    default:
        break;
    }

    if (m_palettePriv)
    {
        connect(
            m_palettePriv.get(), &ExternalPaletteImpl::paletteChanged,
            this, &SystemPalette::updatePalette);
        connect(
            m_palettePriv.get(), &ExternalPaletteImpl::CSDMetricsChanged,
            this, &SystemPalette::CSDMetricsChanged);
    }
    emit paletteChanged();

    bool hasCSDImage = m_palettePriv && m_palettePriv->hasCSDImages();
    if (m_hasCSDImage != hasCSDImage)
    {
        m_hasCSDImage = hasCSDImage;
        emit hasCSDImageChanged();
    }
}

static quint64 makeKey(ColorContext::ColorSet colorSet, ColorContext::ColorSection section,
                       ColorContext::ColorName name, ColorContext::ColorState state)
{
    static_assert(VQTC_STATE_COUNT < (1<<4), "");
    static_assert(VQTC_SECTION_COUNT < (1<<4), "");
    static_assert(VQTC_NAME_COUNT < (1<<8), "");
    static_assert(VQTC_SET_COUNT < (1<<16), "");
    return  (colorSet << 16)
        + (name << 8)
        + (section << 4)
        + state;
}

void SystemPalette::setColor(ColorContext::ColorSet colorSet,  ColorContext::ColorSection section,
                             ColorContext::ColorName name, ColorContext::ColorState state, QColor color)
{

    quint64 key = makeKey(colorSet, section, name, state);
    m_colorMap[key] = color;
}


QColor SystemPalette::getColor(ColorContext::ColorSet colorSet, ColorContext::ColorSection section,
                               ColorContext::ColorName name, ColorContext::ColorState state) const
{
    typedef ColorContext C;

    quint64 key = makeKey(colorSet, section, name, state);
    auto it = m_colorMap.find(key);
    if (it != m_colorMap.cend())
        return *it;
    //we don't have the role explicitly set, fallback to the normal state
    key = makeKey(colorSet, section, name, C::Normal);
    it = m_colorMap.find(key);
    if (it != m_colorMap.cend())
        return *it;
    //we don't have the role explicitly set, fallback to the colorSet View
    //TODO do we want finer hierarchy?
    if (colorSet != C::View)
    {
        return getColor(C::View, section, name, state);
    }
    else
    {
        //nothing matches, that's probably an issue, return an ugly color
        return Qt::magenta;
    }
}


void SystemPalette::makeLightPalette()
{
    m_isDark = false;

    m_colorMap.clear();

    typedef ColorContext C;

    // "VLC Redesign" light colour styles (Figma community file by Juxtopposed).
    // Names mirror the dark palette so both themes share one mapping.
    const QColor bgB2       {"#dedede"}; // Light/BG/B2
    const QColor bgB1       {"#ededed"}; // Light/BG/A1  - content background
    const QColor bgA5       {"#f6f6f6"}; //              - inputs
    const QColor bgA4       {"#dddddd"}; // Light/BG/A2  - window chrome, top bar, control bar
    const QColor bgA3       {"#d5d5d5"}; // Light/BG/A3  - hover
    const QColor bgA2       {"#e7e7e7"}; // Light/BG/B1  - cards, sidebar
    const QColor bgA1       {"#cfcfcf"}; //              - selection
    const QColor accentFill {"#d8ba9a"}; // Light/BG/Accent Bright - seek bar progress
    const QColor dividerDim {"#c4c4c4"}; //              - separators
    const QColor dividerBr  {"#9b9b9b"}; // Light/Divider/Bright
    const QColor fg1        {"#161616"}; // Light/FG/B1  - primary text
    const QColor fg2        {"#2e2e2e"}; // Light/FG/A2
    const QColor fgA1       {"#3c3c3c"}; // Light/FG/A1  - secondary text
    const QColor fgA3       {"#6b6b6b"}; // Light/FG/A3
    const QColor fgA4       {"#888888"}; // Light/BG/A5  - disabled
    const QColor fgB1       {"#161616"}; //              - text on accent
    const QColor accentDim  {"#965916"}; // Light/Accent/Dim
    const QColor accent = orange500;     // Light/Accent/Main is #e8851a; VLC uses one accent for both themes

    {
        C::ColorSet CS = C::View;
        setColor(CS, C::Bg, C::Primary, C::Normal, bgB1 );
        setColor(CS, C::Bg, C::Secondary, C::Normal, bgA4 );

        setColor(CS, C::Fg, C::Primary, C::Normal, fg1 );
        setColor(CS, C::Fg, C::Primary, C::Disabled, fgA3 );

        setColor(CS, C::Fg, C::Secondary, C::Normal, fgA1);

        setColor(CS, C::Bg, C::Negative, C::Normal, QColor(Qt::darkRed));
        setColor(CS, C::Fg, C::Negative, C::Normal, QColor("#e5534b"));

        setColor(CS, C::Bg, C::Neutral, C::Normal, accentFill);
        setColor(CS, C::Fg, C::Neutral, C::Normal, accent);

        setColor(CS, C::Bg, C::Positive, C::Normal, QColor(Qt::darkGreen));
        setColor(CS, C::Fg, C::Positive, C::Normal, QColor("#57ab5a"));

        setColor(CS, C::Decoration, C::VisualFocus, C::Normal, setColorAlpha(fg1, 0.0) );
        setColor(CS, C::Decoration, C::VisualFocus, C::Focused, fg1 );

        setColor(CS, C::Decoration, C::Border, C::Normal, dividerBr );
        setColor(CS, C::Decoration, C::Border, C::Focused, fgA3 );
        setColor(CS, C::Decoration, C::Border, C::Hovered, fgA3 );
        setColor(CS, C::Decoration, C::Border, C::Disabled, setColorAlpha(dividerBr, 0.0) );

        setColor(CS, C::Decoration, C::Shadow, C::Normal, setColorAlpha(Qt::black, 0.18));

        setColor(CS, C::Decoration, C::Separator, C::Normal, dividerDim);

        setColor(CS, C::Decoration, C::Accent, C::Normal, accent);
        setColor(CS, C::Fg, C::Link, C::Normal, accent);
    }

    //window banner & miniplayer
    {
        C::ColorSet CS = C::Window;
        setColor(CS, C::Bg, C::Primary, C::Normal, bgA4);
        setColor(CS, C::Bg, C::Secondary, C::Normal, bgA4);
        setColor(CS, C::Decoration, C::Border, C::Normal, dividerDim);
    }

    //badges
    {
        C::ColorSet CS = C::Badge;
        setColor(CS, C::Bg, C::Primary, C::Normal, setColorAlpha(fg1, 0.85));
        setColor(CS, C::Fg, C::Primary, C::Normal, fgB1);
    }

    //tab button (sidebar / top bar navigation)
    {
        C::ColorSet CS = C::TabButton;
        setColor(CS, C::Bg, C::Primary, C::Normal, setColorAlpha(bgA1, 0.0));
        setColor(CS, C::Bg, C::Primary, C::Focused, bgA1);
        setColor(CS, C::Bg, C::Primary, C::Hovered, bgA1);

        setColor(CS, C::Fg, C::Primary, C::Normal, fgA1);
        setColor(CS, C::Fg, C::Primary, C::Focused, fg1);
        setColor(CS, C::Fg, C::Primary, C::Hovered, fg1);
        setColor(CS, C::Fg, C::Primary, C::Disabled, fgA4);
        setColor(CS, C::Fg, C::Secondary, C::Normal, fg1);
    }

    //tool button
    {
        C::ColorSet CS = C::ToolButton;
        setColor(CS, C::Bg, C::Primary, C::Normal, Qt::transparent);
        setColor(CS, C::Bg, C::Primary, C::Hovered, bgA1);
        setColor(CS, C::Bg, C::Primary, C::Focused, bgA1);
        setColor(CS, C::Bg, C::Secondary, C::Normal, bgB2);

        setColor(CS, C::Fg, C::Primary, C::Normal, fgA1);
        setColor(CS, C::Fg, C::Primary, C::Focused, fg1);
        setColor(CS, C::Fg, C::Primary, C::Hovered, fg1);
        setColor(CS, C::Fg, C::Primary, C::Disabled, fgA4);
        setColor(CS, C::Fg, C::Secondary, C::Normal, fg1);

        setColor(CS, C::Decoration, C::Border, C::Normal, Qt::transparent);
        setColor(CS, C::Decoration, C::Border, C::Focused, Qt::transparent);
        setColor(CS, C::Decoration, C::Border, C::Hovered, Qt::transparent);
        setColor(CS, C::Decoration, C::Border, C::Disabled, Qt::transparent);
    }

    //menubar
    {
        C::ColorSet CS = C::MenuBar;
        setColor(CS, C::Bg, C::Primary, C::Normal, setColorAlpha(bgA1, 0.0));
        setColor(CS, C::Bg, C::Primary, C::Focused, bgA1);
        setColor(CS, C::Bg, C::Primary, C::Hovered, bgA1);
        setColor(CS, C::Fg, C::Primary, C::Normal, fg2);
        setColor(CS, C::Fg, C::Primary, C::Disabled, fgA4);
    }

    //Item (list rows, grid cards)
    {
        C::ColorSet CS = C::Item;
        setColor(CS, C::Bg, C::Primary, C::Normal, setColorAlpha(bgA3, 0.0));
        setColor(CS, C::Bg, C::Primary, C::Focused, bgA3);
        setColor(CS, C::Bg, C::Primary, C::Hovered, bgA3);

        setColor(CS, C::Bg, C::Highlight, C::Normal, bgA1);
        setColor(CS, C::Bg, C::Highlight, C::Focused, bgA1);
        setColor(CS, C::Bg, C::Highlight, C::Hovered, bgA1);
        setColor(CS, C::Fg, C::Highlight, C::Normal, fg1);

        setColor(CS, C::Fg, C::Primary, C::Normal, fg2);
        setColor(CS, C::Fg, C::Secondary, C::Normal, fgA3);

        setColor(CS, C::Decoration, C::Indicator, C::Normal, fgA3);
    }

    //Accent Buttons (play button, primary actions)
    {
        C::ColorSet CS = C::ButtonAccent;
        setColor(CS, C::Bg, C::Primary, C::Normal, accent);
        setColor(CS, C::Bg, C::Primary, C::Hovered, orange800);
        setColor(CS, C::Bg, C::Primary, C::Focused, orange800);
        setColor(CS, C::Bg, C::Primary, C::Pressed, accentDim);
        setColor(CS, C::Bg, C::Primary, C::Disabled, bgA1);

        setColor(CS, C::Fg, C::Primary, C::Normal, fgB1);
        setColor(CS, C::Fg, C::Primary, C::Disabled, fgA3);

        setColor(CS, C::Decoration, C::Border, C::Normal, Qt::transparent);
        setColor(CS, C::Decoration, C::Border, C::Focused, Qt::transparent);
        setColor(CS, C::Decoration, C::Border, C::Hovered, Qt::transparent);
        setColor(CS, C::Decoration, C::Border, C::Disabled, Qt::transparent);
    }

    //Standard Buttons
    {
        C::ColorSet CS = C::ButtonStandard;
        setColor(CS, C::Bg, C::Primary, C::Normal, Qt::transparent);
        setColor(CS, C::Bg, C::Primary, C::Hovered, bgA1);
        setColor(CS, C::Bg, C::Primary, C::Focused, bgA1);

        setColor(CS, C::Fg, C::Primary, C::Normal, fgA1);
        setColor(CS, C::Fg, C::Primary, C::Focused, fg1);
        setColor(CS, C::Fg, C::Primary, C::Hovered, fg1);
        setColor(CS, C::Fg, C::Primary, C::Disabled, fgA4);

        setColor(CS, C::Decoration, C::Border, C::Normal, Qt::transparent);
        setColor(CS, C::Decoration, C::Border, C::Focused, Qt::transparent);
        setColor(CS, C::Decoration, C::Border, C::Hovered, Qt::transparent);
        setColor(CS, C::Decoration, C::Border, C::Disabled, Qt::transparent);
    }

    //tooltip
    {
        C::ColorSet CS = C::Tooltip;
        setColor(CS, C::Bg, C::Primary, C::Normal, bgA1);
        setColor(CS, C::Fg, C::Primary, C::Normal, fg1);
    }

    //slider: grey track, light-orange progress, orange handle
    {
        C::ColorSet CS = C::Slider;
        setColor(CS, C::Bg, C::Primary, C::Normal, QColor("#b3b3b3")); // Light/BG/A4
        setColor(CS, C::Bg, C::Primary, C::Focused, QColor("#b3b3b3"));
        setColor(CS, C::Bg, C::Primary, C::Hovered, QColor("#b3b3b3"));
        setColor(CS, C::Bg, C::Secondary, C::Normal, accentFill);

        setColor(CS, C::Fg, C::Primary, C::Normal, accent);
        setColor(CS, C::Fg, C::Positive, C::Normal, "#0F7B0F");  //FIXME
        setColor(CS, C::Fg, C::Neutral, C::Normal, "#9D5D00");  //FIXME
        setColor(CS, C::Fg, C::Negative, C::Normal, "#C42B1C");  //FIXME
    }

    //Combo box
    {
        C::ColorSet CS = C::ComboBox;
        setColor(CS, C::Fg, C::Primary, C::Normal, fg1);
        setColor(CS, C::Bg, C::Primary, C::Normal, bgA5);
        setColor(CS, C::Bg, C::Secondary, C::Normal, bgA2);
        setColor(CS, C::Decoration, C::Border, C::Normal, dividerBr);
        setColor(CS, C::Decoration, C::Border, C::Hovered, dividerBr);
        setColor(CS, C::Decoration, C::Border, C::Focused, accent);
    }

    //TextField
    {
        C::ColorSet CS = C::TextField;
        setColor(CS, C::Bg, C::Primary, C::Normal, bgA5);
        setColor(CS, C::Decoration, C::Border, C::Normal, dividerDim );
        setColor(CS, C::Decoration, C::Border, C::Focused, accent );
        setColor(CS, C::Decoration, C::Border, C::Hovered, dividerBr );
        setColor(CS, C::Decoration, C::Border, C::Disabled, setColorAlpha(dividerDim, 0.0) );

        setColor(CS, C::Bg, C::Highlight, C::Normal, accentDim);
        setColor(CS, C::Fg, C::Highlight, C::Normal, fg1);
    }

    //Switch (Figma "Toggle")
    {
        C::ColorSet CS = C::Switch;
        setColor(CS, C::Bg, C::Primary, C::Normal, bgA2);
        setColor(CS, C::Fg, C::Primary, C::Normal, fgA3);
        setColor(CS, C::Decoration, C::Border, C::Normal, dividerBr);
        setColor(CS, C::Bg, C::Secondary, C::Normal, accentFill);
        setColor(CS, C::Fg, C::Secondary, C::Normal, accent);
    }

    //Spinbox
    {
        C::ColorSet CS = C::SpinBox;
        setColor(CS, C::Bg, C::Primary, C::Normal, bgA5);
        setColor(CS, C::Decoration, C::Border, C::Normal, dividerDim );
        setColor(CS, C::Decoration, C::Border, C::Focused, accent );
        setColor(CS, C::Decoration, C::Border, C::Hovered, dividerBr );
        setColor(CS, C::Decoration, C::Border, C::Disabled, setColorAlpha(dividerDim, 0.0) );

        setColor(CS, C::Bg, C::Highlight, C::Normal, accentDim);
        setColor(CS, C::Fg, C::Highlight, C::Normal, fg1);
    }
}

void SystemPalette::makeDarkPalette()
{
    m_isDark = true;

    m_colorMap.clear();

    typedef ColorContext C;

    // "VLC Redesign" dark colour styles (Figma community file by Juxtopposed)
    const QColor bgB2       {"#090909"}; // Dark/BG/B2
    const QColor bgB1       {"#0e0e0e"}; // Dark/BG/B1   - content background
    const QColor bgA5       {"#151515"}; // Dark/BG/A5   - inputs
    const QColor bgA4       {"#191919"}; // Dark/BG/A4   - window chrome, top bar, control bar
    const QColor bgA3       {"#1b1b1b"}; // Dark/BG/A3   - hover
    const QColor bgA2       {"#1f1f1f"}; // Dark/BG/A2   - cards, sidebar
    const QColor bgA1       {"#222222"}; // Dark/BG/A1   - selection
    const QColor accentFill {"#371f06"}; // Dark/BG/Accent Bright - seek bar progress
    const QColor dividerDim {"#222222"}; // Dark/Divider/Dim
    const QColor dividerBr  {"#373737"}; // Dark/Divider/Bright
    const QColor fg1        {"#eaeaea"}; // Dark/FG/1
    const QColor fg2        {"#c6c6c6"}; // Dark/FG/2
    const QColor fgA1       {"#969696"}; // Dark/FG/A1
    const QColor fgA3       {"#6b6b6b"}; // Dark/FG/A3
    const QColor fgA4       {"#404040"}; // Dark/FG/A4
    const QColor fgB1       {"#161616"}; // Dark/FG/B1   - text on accent
    const QColor accentDim  {"#ab6314"}; // Dark/Accent/Dim
    const QColor accent = orange500;     // Dark/Accent/Main (overridable with --qt-accent-color)

    {
        C::ColorSet CS = C::View;
        setColor(CS, C::Bg, C::Primary, C::Normal, bgB1 );
        setColor(CS, C::Bg, C::Secondary, C::Normal, bgA4 );

        setColor(CS, C::Fg, C::Primary, C::Normal, fg1 );
        setColor(CS, C::Fg, C::Primary, C::Disabled, fgA3 );

        setColor(CS, C::Fg, C::Secondary, C::Normal, fgA1);

        setColor(CS, C::Bg, C::Negative, C::Normal, QColor(Qt::darkRed));
        setColor(CS, C::Fg, C::Negative, C::Normal, QColor("#e5534b"));

        setColor(CS, C::Bg, C::Neutral, C::Normal, accentFill);
        setColor(CS, C::Fg, C::Neutral, C::Normal, accent);

        setColor(CS, C::Bg, C::Positive, C::Normal, QColor(Qt::darkGreen));
        setColor(CS, C::Fg, C::Positive, C::Normal, QColor("#57ab5a"));

        setColor(CS, C::Decoration, C::VisualFocus, C::Normal, setColorAlpha(fg1, 0.0) );
        setColor(CS, C::Decoration, C::VisualFocus, C::Focused, fg1 );

        setColor(CS, C::Decoration, C::Border, C::Normal, dividerBr );
        setColor(CS, C::Decoration, C::Border, C::Focused, fgA3 );
        setColor(CS, C::Decoration, C::Border, C::Hovered, fgA3 );
        setColor(CS, C::Decoration, C::Border, C::Disabled, setColorAlpha(dividerBr, 0.0) );

        setColor(CS, C::Decoration, C::Shadow, C::Normal, setColorAlpha(Qt::black, 0.35));

        setColor(CS, C::Decoration, C::Separator, C::Normal, dividerDim);

        setColor(CS, C::Decoration, C::Accent, C::Normal, accent);
        setColor(CS, C::Fg, C::Link, C::Normal, accent);
    }

    //window banner & miniplayer
    {
        C::ColorSet CS = C::Window;
        setColor(CS, C::Bg, C::Primary, C::Normal, bgA4);
        setColor(CS, C::Bg, C::Secondary, C::Normal, bgA4);
        setColor(CS, C::Decoration, C::Border, C::Normal, dividerDim);
    }

    //badges
    {
        C::ColorSet CS = C::Badge;
        setColor(CS, C::Bg, C::Primary, C::Normal, setColorAlpha(fg1, 0.85));
        setColor(CS, C::Fg, C::Primary, C::Normal, fgB1);
    }

    //tab button (sidebar / top bar navigation)
    {
        C::ColorSet CS = C::TabButton;
        setColor(CS, C::Bg, C::Primary, C::Normal, setColorAlpha(bgA1, 0.0));
        setColor(CS, C::Bg, C::Primary, C::Focused, bgA1);
        setColor(CS, C::Bg, C::Primary, C::Hovered, bgA1);

        setColor(CS, C::Fg, C::Primary, C::Normal, fgA1);
        setColor(CS, C::Fg, C::Primary, C::Focused, fg1);
        setColor(CS, C::Fg, C::Primary, C::Hovered, fg1);
        setColor(CS, C::Fg, C::Primary, C::Disabled, fgA4);
        setColor(CS, C::Fg, C::Secondary, C::Normal, fg1);
    }

    //tool button
    {
        C::ColorSet CS = C::ToolButton;
        setColor(CS, C::Bg, C::Primary, C::Normal, Qt::transparent);
        setColor(CS, C::Bg, C::Primary, C::Hovered, bgA1);
        setColor(CS, C::Bg, C::Primary, C::Focused, bgA1);
        setColor(CS, C::Bg, C::Secondary, C::Normal, bgB2);

        setColor(CS, C::Fg, C::Primary, C::Normal, fgA1);
        setColor(CS, C::Fg, C::Primary, C::Focused, fg1);
        setColor(CS, C::Fg, C::Primary, C::Hovered, fg1);
        setColor(CS, C::Fg, C::Primary, C::Disabled, fgA4);
        setColor(CS, C::Fg, C::Secondary, C::Normal, fg1);

        setColor(CS, C::Decoration, C::Border, C::Normal, Qt::transparent);
        setColor(CS, C::Decoration, C::Border, C::Focused, Qt::transparent);
        setColor(CS, C::Decoration, C::Border, C::Hovered, Qt::transparent);
        setColor(CS, C::Decoration, C::Border, C::Disabled, Qt::transparent);
    }

    //menubar
    {
        C::ColorSet CS = C::MenuBar;
        setColor(CS, C::Bg, C::Primary, C::Normal, setColorAlpha(bgA1, 0.0));
        setColor(CS, C::Bg, C::Primary, C::Focused, bgA1);
        setColor(CS, C::Bg, C::Primary, C::Hovered, bgA1);
        setColor(CS, C::Fg, C::Primary, C::Normal, fg2);
        setColor(CS, C::Fg, C::Primary, C::Disabled, fgA4);
    }

    //Item (list rows, grid cards)
    {
        C::ColorSet CS = C::Item;
        setColor(CS, C::Bg, C::Primary, C::Normal, setColorAlpha(bgA3, 0.0));
        setColor(CS, C::Bg, C::Primary, C::Focused, bgA3);
        setColor(CS, C::Bg, C::Primary, C::Hovered, bgA3);

        setColor(CS, C::Bg, C::Highlight, C::Normal, bgA1);
        setColor(CS, C::Bg, C::Highlight, C::Focused, bgA1);
        setColor(CS, C::Bg, C::Highlight, C::Hovered, bgA1);
        setColor(CS, C::Fg, C::Highlight, C::Normal, fg1);

        setColor(CS, C::Fg, C::Primary, C::Normal, fg2);
        setColor(CS, C::Fg, C::Secondary, C::Normal, fgA3);

        setColor(CS, C::Decoration, C::Indicator, C::Normal, fgA3);
    }

    //Accent Buttons (play button, primary actions)
    {
        C::ColorSet CS = C::ButtonAccent;
        setColor(CS, C::Bg, C::Primary, C::Normal, accent);
        setColor(CS, C::Bg, C::Primary, C::Hovered, orange800);
        setColor(CS, C::Bg, C::Primary, C::Focused, orange800);
        setColor(CS, C::Bg, C::Primary, C::Pressed, accentDim);
        setColor(CS, C::Bg, C::Primary, C::Disabled, bgA1);

        setColor(CS, C::Fg, C::Primary, C::Normal, fgB1);
        setColor(CS, C::Fg, C::Primary, C::Disabled, fgA3);

        setColor(CS, C::Decoration, C::Border, C::Normal, Qt::transparent);
        setColor(CS, C::Decoration, C::Border, C::Focused, Qt::transparent);
        setColor(CS, C::Decoration, C::Border, C::Hovered, Qt::transparent);
        setColor(CS, C::Decoration, C::Border, C::Disabled, Qt::transparent);
    }

    //Standard Buttons
    {
        C::ColorSet CS = C::ButtonStandard;
        setColor(CS, C::Bg, C::Primary, C::Normal, Qt::transparent);
        setColor(CS, C::Bg, C::Primary, C::Hovered, bgA1);
        setColor(CS, C::Bg, C::Primary, C::Focused, bgA1);

        setColor(CS, C::Fg, C::Primary, C::Normal, fgA1);
        setColor(CS, C::Fg, C::Primary, C::Focused, fg1);
        setColor(CS, C::Fg, C::Primary, C::Hovered, fg1);
        setColor(CS, C::Fg, C::Primary, C::Disabled, fgA4);

        setColor(CS, C::Decoration, C::Border, C::Normal, Qt::transparent);
        setColor(CS, C::Decoration, C::Border, C::Focused, Qt::transparent);
        setColor(CS, C::Decoration, C::Border, C::Hovered, Qt::transparent);
        setColor(CS, C::Decoration, C::Border, C::Disabled, Qt::transparent);
    }

    //tooltip
    {
        C::ColorSet CS = C::Tooltip;
        setColor(CS, C::Bg, C::Primary, C::Normal, bgA1);
        setColor(CS, C::Fg, C::Primary, C::Normal, fg1);
    }

    //slider: black track, dark-orange progress, orange handle
    {
        C::ColorSet CS = C::Slider;
        setColor(CS, C::Bg, C::Primary, C::Normal, Qt::black);
        setColor(CS, C::Bg, C::Primary, C::Focused, Qt::black);
        setColor(CS, C::Bg, C::Primary, C::Hovered, Qt::black);
        setColor(CS, C::Bg, C::Secondary, C::Normal, accentFill);

        setColor(CS, C::Fg, C::Primary, C::Normal, accent);
        setColor(CS, C::Fg, C::Positive, C::Normal, "#0F7B0F");  //FIXME
        setColor(CS, C::Fg, C::Neutral, C::Normal, "#9D5D00");  //FIXME
        setColor(CS, C::Fg, C::Negative, C::Normal, "#C42B1C");  //FIXME
    }

    //Combo box
    {
        C::ColorSet CS = C::ComboBox;
        setColor(CS, C::Fg, C::Primary, C::Normal, fg1);
        setColor(CS, C::Bg, C::Primary, C::Normal, bgA5);
        setColor(CS, C::Bg, C::Secondary, C::Normal, bgA2);
        setColor(CS, C::Decoration, C::Border, C::Normal, dividerBr);
        setColor(CS, C::Decoration, C::Border, C::Hovered, dividerBr);
        setColor(CS, C::Decoration, C::Border, C::Focused, accent);
    }

    //TextField
    {
        C::ColorSet CS = C::TextField;
        setColor(CS, C::Bg, C::Primary, C::Normal, bgA5);
        setColor(CS, C::Decoration, C::Border, C::Normal, dividerDim );
        setColor(CS, C::Decoration, C::Border, C::Focused, accent );
        setColor(CS, C::Decoration, C::Border, C::Hovered, dividerBr );
        setColor(CS, C::Decoration, C::Border, C::Disabled, setColorAlpha(dividerDim, 0.0) );

        setColor(CS, C::Bg, C::Highlight, C::Normal, accentDim);
        setColor(CS, C::Fg, C::Highlight, C::Normal, fg1);
    }

    //Switch (Figma "Toggle")
    {
        C::ColorSet CS = C::Switch;
        setColor(CS, C::Bg, C::Primary, C::Normal, bgA2);
        setColor(CS, C::Fg, C::Primary, C::Normal, fgA3);
        setColor(CS, C::Decoration, C::Border, C::Normal, dividerBr);
        setColor(CS, C::Bg, C::Secondary, C::Normal, accentFill);
        setColor(CS, C::Fg, C::Secondary, C::Normal, accent);
    }

    //Spinbox
    {
        C::ColorSet CS = C::SpinBox;
        setColor(CS, C::Bg, C::Primary, C::Normal, bgA5);
        setColor(CS, C::Decoration, C::Border, C::Normal, dividerDim );
        setColor(CS, C::Decoration, C::Border, C::Focused, accent );
        setColor(CS, C::Decoration, C::Border, C::Hovered, dividerBr );
        setColor(CS, C::Decoration, C::Border, C::Disabled, setColorAlpha(dividerDim, 0.0) );

        setColor(CS, C::Bg, C::Highlight, C::Normal, accentDim);
        setColor(CS, C::Fg, C::Highlight, C::Normal, fg1);
    }
}

void SystemPalette::makeSystemPalette()
{
    if (!m_ctx)
    {
        //can't initialise system palette, fallback to default
        makeLightPalette();
        return;
    }

    auto palette = std::make_unique<ExternalPaletteImpl>(m_ctx, *this);
    if (!palette->init())
    {
        //can't initialise system palette, fallback to default
        makeLightPalette();
        return;
    }

    // VLC Redesign: "System" follows the system's dark/light setting but keeps
    // the design's palettes instead of the platform colours. The provider is
    // kept so system theme changes still trigger an update.
    if (palette->isThemeDark())
        makeDarkPalette();
    else
        makeLightPalette();

    m_palettePriv = std::move(palette);
}
