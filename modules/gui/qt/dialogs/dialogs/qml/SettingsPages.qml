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
import QtQml

// VLC Redesign: content of the settings window, following the "Settings - *"
// frames of Juxtopposed's Figma file. Every row is bound to a VLC option (rows
// whose option does not exist on this build are hidden) or to an action.
//
// Row fields:
//   label, help       text shown in the row (help: optional tooltip)
//   option            VLC configuration name
//   kind              optional; one of
//                       "auto" (default, chosen from the option type), "toggle",
//                       "invertedToggle", "choice", "slider", "number", "text",
//                       "password", "file", "savefile", "directory", "color",
//                       "listItem" (item in a module list, see `item`),
//                       "colorScheme", "accent", "repeat", "skin", "action"
//   item              listItem: module name inside the list option
//   unit, scale       slider/number: display unit and factor (value * scale)
//   step              slider: step in display units
//   choices           choice: explicit [{value, text}] (otherwise from the option)
//   action, button    action: action id and button text
//   restart           true when a restart is needed for the change to apply
QtObject {
    readonly property var pages: [
        { group: qsTr("App"), id: "general", title: qsTr("General"), heading: qsTr("Global Settings"),
          sections: [
            { title: qsTr("Appearance"), rows: [
                { label: qsTr("Theme"), kind: "colorScheme" },
                { label: qsTr("Accent color"), kind: "accent", option: "qt-accent-color", restart: true }
            ]},
            { title: qsTr("Startup"), rows: [
                { label: qsTr("Check for updates automatically"), option: "qt-updates-notif",
                  help: qsTr("Unofficial builds have no update server, so this is off by default.") }
            ]},
            { title: qsTr("Diagnostics"), rows: [
                { label: qsTr("Save a log"), option: "file-logging", restart: true },
                { label: qsTr("Log file"), option: "logfile", kind: "savefile", restart: true },
                { label: qsTr("Log details"), option: "log-verbose" },
                { label: qsTr("Log format"), option: "logmode" },
                { label: qsTr("Collect playback statistics"), option: "stats" },
                { label: qsTr("Open configurations folder"), kind: "action", action: "openConfigFolder", button: qsTr("Open") },
                { label: qsTr("Reset all settings"), kind: "action", action: "resetAll", button: qsTr("Reset") }
            ]}
          ],
          advanced: [
            { label: qsTr("Write to the system log"), option: "syslog" },
            { label: qsTr("Include debug messages in the system log"), option: "syslog-debug" },
            { label: qsTr("System log identity"), option: "syslog-ident" },
            { label: qsTr("System log facility"), option: "syslog-facility" }
          ]
        },
        { group: qsTr("App"), id: "interface", title: qsTr("Interface"), heading: qsTr("Interface Settings"),
          sections: [
            { title: qsTr("Skin"), rows: [
                { label: qsTr("Use a custom skin"), kind: "skin", restart: true,
                  help: qsTr("Uses the classic skinnable interface instead of this one.") },
                { label: qsTr("Skin file"), option: "skins2-last", kind: "file", restart: true }
            ]},
            { title: qsTr("Window"), rows: [
                { label: qsTr("Play video inside main window"), option: "embedded-video" },
                { label: qsTr("Resize window to fit video"), option: "qt-video-autoresize" },
                { label: qsTr("Keep window above other windows"), option: "video-on-top" },
                { label: qsTr("Use the system title bar"), option: "qt-titlebar", restart: true },
                { label: qsTr("Show the file name in the title bar"), option: "qt-name-in-title" },
                { label: qsTr("Open fullscreen on"), option: "qt-fullscreen-screennumber" }
            ]},
            { title: qsTr("Playback Controls"), rows: [
                { label: qsTr("Start in compact mode"), option: "qt-minimal-view" },
                { label: qsTr("Keep the controls around the video"), option: "qt-pin-controls" },
                { label: qsTr("Hide controls after"), option: "mouse-hide-timeout", kind: "slider", unit: "s", scale: 0.001, step: 0.5 },
                { label: qsTr("Show controls in fullscreen"), option: "qt-fs-controller" }
            ]},
            { title: qsTr("Notifications and System Tray"), rows: [
                { label: qsTr("Show a system tray icon"), option: "qt-system-tray", restart: true },
                { label: qsTr("Start minimized to the tray"), option: "qt-start-minimized" },
                { label: qsTr("Show a popup when the track changes"), option: "qt-notification" }
            ]}
          ],
          advanced: [
            { label: qsTr("Window opacity"), option: "qt-opacity", kind: "slider", unit: "%", scale: 100, step: 5 },
            { label: qsTr("Pause video when window is minimized"), option: "qt-pause-minimized" },
            { label: qsTr("Allow the app icon to change"), option: "qt-icon-change" },
            { label: qsTr("Fullscreen controls opacity"), option: "qt-fs-opacity", kind: "slider", unit: "%", scale: 100, step: 5 },
            { label: qsTr("Fullscreen controls sensitivity"), option: "qt-fs-sensitivity", kind: "number", unit: "px" },
            { label: qsTr("Edit the control bar"), kind: "action", action: "toolbarEditor", button: qsTr("Edit") }
          ]
        },
        { group: qsTr("App"), id: "privacy", title: qsTr("Privacy"), heading: qsTr("Privacy Settings"),
          sections: [
            { title: qsTr("History"), rows: [
                { label: qsTr("Save recently played items"), option: "save-recentplay" },
                { label: qsTr("Remember the playback position"), option: "restore-playback-pos" },
                { label: qsTr("Remember track and subtitle choices"), option: "restore-playback-states" },
                { label: qsTr("Clear history now"), kind: "action", action: "clearHistory", button: qsTr("Clear") }
            ]},
            { title: qsTr("Network"), rows: [
                { label: qsTr("Fetch titles and cover art from the internet"), option: "metadata-network-access" },
                { label: qsTr("Submit played tracks to Last.fm"), kind: "listItem", option: "control", item: "audioscrobbler", restart: true },
                { label: qsTr("Last.fm username"), option: "lastfm-username" },
                { label: qsTr("Last.fm password"), option: "lastfm-password", kind: "password" },
                { label: qsTr("Last.fm submission URL"), option: "scrobbler-url" }
            ]}
          ],
          advanced: []
        },
        { group: qsTr("App"), id: "controls", title: qsTr("Controls"), heading: qsTr("Mouse, Keyboard & Remote Controls"),
          sections: [
            { title: qsTr("Keyboard Shortcuts"), rows: [
                { label: qsTr("Keyboard shortcuts"), kind: "action", action: "advancedPreferences", button: qsTr("Edit Keyboard Shortcuts") }
            ]},
            { title: qsTr("Skip Amounts"), rows: [
                { label: qsTr("Very short skip"), option: "extrashort-jump-size", kind: "number", unit: "s" },
                { label: qsTr("Short skip"), option: "short-jump-size", kind: "number", unit: "s" },
                { label: qsTr("Medium skip"), option: "medium-jump-size", kind: "number", unit: "s" },
                { label: qsTr("Long skip"), option: "long-jump-size", kind: "number", unit: "s" }
            ]},
            { title: qsTr("Mouse"), rows: [
                { label: qsTr("Scroll wheel"), option: "hotkeys-y-wheel-mode" },
                { label: qsTr("Horizontal scroll"), option: "hotkeys-x-wheel-mode" }
            ]},
            { title: qsTr("Remotes"), rows: [
                { label: qsTr("Web remote control"), kind: "listItem", option: "extraintf", item: "http", restart: true,
                  help: qsTr("Lets other devices control VLC from a browser. Set a password before you turn this on.") },
                { label: qsTr("Web remote password"), option: "http-password", kind: "password", restart: true },
                { label: qsTr("Port"), option: "http-port", kind: "number", restart: true }
            ]}
          ],
          advanced: []
        },
        { group: qsTr("Media"), id: "playback", title: qsTr("Playback"), heading: qsTr("Playback Preferences"),
          sections: [
            { title: qsTr("Startup"), rows: [
                { label: qsTr("Continue where you left off"), option: "restore-playback-pos" },
                { label: qsTr("Start playing as soon as a file opens"), option: "playlist-autostart" },
                { label: qsTr("Default playback speed"), option: "rate", kind: "slider", unit: "x", step: 0.25,
                  min: 0.25, max: 2 }
            ]},
            { title: qsTr("Tracks"), rows: [
                { label: qsTr("Preferred video quality"), option: "preferred-resolution" },
                { label: qsTr("Preferred menu language"), option: "menu-language" },
                { label: qsTr("Default audio track"), option: "audio-track", kind: "number" },
                { label: qsTr("Default subtitle track"), option: "sub-track", kind: "number" }
            ]},
            { title: qsTr("Order"), rows: [
                { label: qsTr("Repeat"), kind: "repeat" },
                { label: qsTr("Shuffle"), option: "random" },
                { label: qsTr("Stop after each item"), option: "play-and-stop" },
                { label: qsTr("Quit when playback finishes"), option: "play-and-exit" }
            ]},
            { title: qsTr("Seeking"), rows: [
                { label: qsTr("Seek faster, less precisely"), option: "input-fast-seek" }
            ]},
            { title: qsTr("Files & Discs"), rows: [
                { label: qsTr("Default optical drive"), option: "dvd" },
                { label: qsTr("Repair damaged AVI files"), option: "avi-index" },
                { label: qsTr("Load matching .mkv files from the same folder"), option: "mkv-preload-local-dir" }
            ]}
          ],
          advanced: [
            { label: qsTr("Time-shift buffer folder"), option: "input-timeshift-path", kind: "directory" },
            { label: qsTr("Time-shift buffer granularity"), option: "input-timeshift-granularity", kind: "number" }
          ]
        },
        { group: qsTr("Media"), id: "video", title: qsTr("Video"), heading: qsTr("Video Defaults"),
          sections: [
            { title: qsTr("Output"), rows: [
                { label: qsTr("Enable video"), option: "video" },
                { label: qsTr("Start videos in fullscreen"), option: "fullscreen" },
                { label: qsTr("Stop the screensaver during playback"), option: "disable-screensaver" },
                { label: qsTr("Play video as desktop wallpaper"), option: "video-wallpaper" }
            ]},
            { title: qsTr("Picture"), rows: [
                { label: qsTr("Adjust the picture"), kind: "listItem", option: "video-filter", item: "adjust" },
                { label: qsTr("Hue"), option: "hue", kind: "slider", unit: "°", step: 1 },
                { label: qsTr("Brightness"), option: "brightness", kind: "slider", step: 0.01 },
                { label: qsTr("Contrast"), option: "contrast", kind: "slider", step: 0.01 },
                { label: qsTr("Saturation"), option: "saturation", kind: "slider", step: 0.01 },
                { label: qsTr("Gamma"), option: "gamma", kind: "slider", step: 0.01 },
                { label: qsTr("Reset picture"), kind: "action", action: "resetPicture", button: qsTr("Reset") }
            ]},
            { title: qsTr("Deinterlacing"), rows: [
                { label: qsTr("Deinterlacing"), option: "deinterlace" },
                { label: qsTr("Method"), option: "deinterlace-mode" }
            ]},
            { title: qsTr("Framing"), rows: [
                { label: qsTr("Aspect ratio"), option: "aspect-ratio" },
                { label: qsTr("Crop"), option: "crop" },
                { label: qsTr("Scale video to the window"), option: "autoscale" },
                { label: qsTr("Zoom"), option: "zoom", kind: "slider", unit: "x", step: 0.25, min: 0.25, max: 4 },
                { label: qsTr("Position in the window"), option: "align" }
            ]},
            { title: qsTr("Snapshots"), rows: [
                { label: qsTr("Save to"), option: "snapshot-path", kind: "directory" },
                { label: qsTr("File name prefix"), option: "snapshot-prefix" },
                { label: qsTr("Format"), option: "snapshot-format" },
                { label: qsTr("Number files sequentially"), option: "snapshot-sequential" },
                { label: qsTr("Show a preview after capture"), option: "snapshot-preview" }
            ]}
          ],
          advanced: [
            { label: qsTr("Custom aspect ratios"), option: "custom-aspect-ratios" },
            { label: qsTr("Custom crop ratios"), option: "custom-crop-ratios" },
            { label: qsTr("Monitor pixel aspect ratio"), option: "monitor-par" }
          ]
        },
        { group: qsTr("Media"), id: "audio", title: qsTr("Audio"), heading: qsTr("Audio Defaults"),
          sections: [
            { title: qsTr("Output"), rows: [
                { label: qsTr("Enable audio"), option: "audio" },
                { label: qsTr("Output module"), option: "aout", restart: true },
                { label: qsTr("Speaker setup"), option: "stereo-mode" }
            ]},
            { title: qsTr("Volume"), rows: [
                { label: qsTr("Maximum volume"), option: "qt-max-volume", kind: "slider", unit: "%", step: 5 },
                { label: qsTr("Remember last volume"), option: "volume-save" },
                { label: qsTr("Volume step"), option: "volume-step", kind: "number" }
            ]},
            { title: qsTr("Loudness"), rows: [
                { label: qsTr("Normalize loudness"), kind: "listItem", option: "audio-filter", item: "normvol" },
                { label: qsTr("Target level"), option: "norm-max-level", kind: "number" },
                { label: qsTr("Replay gain"), option: "audio-replay-gain-mode" },
                { label: qsTr("Replay gain preamp"), option: "audio-replay-gain-preamp", kind: "number", unit: "dB" }
            ]},
            { title: qsTr("Effects"), rows: [
                { label: qsTr("Equalizer"), kind: "listItem", option: "audio-filter", item: "equalizer" },
                { label: qsTr("Equalizer preset"), option: "equalizer-preset" },
                { label: qsTr("Open the equalizer"), kind: "action", action: "equalizer", button: qsTr("Open Equalizer") },
                { label: qsTr("Two-pass equalizer"), option: "equalizer-2pass" },
                { label: qsTr("Spatial audio"), kind: "listItem", option: "audio-filter", item: "spatializer" },
                { label: qsTr("Stereo widening"), kind: "listItem", option: "audio-filter", item: "stereo_widen" },
                { label: qsTr("Compressor"), kind: "listItem", option: "audio-filter", item: "compressor" },
                { label: qsTr("Chorus/flanger"), kind: "listItem", option: "audio-filter", item: "chorus_flanger" },
                { label: qsTr("Karaoke"), kind: "listItem", option: "audio-filter", item: "karaoke" }
            ]},
            { title: qsTr("Tracks"), rows: [
                { label: qsTr("Preferred audio language"), option: "audio-language" },
                { label: qsTr("Audio delay"), option: "audio-desync", kind: "number", unit: "ms" }
            ]},
            { title: qsTr("Visualization"), rows: [
                { label: qsTr("Visualizer"), option: "audio-visual" }
            ]}
          ],
          advanced: [
            { label: qsTr("Detect Dolby Surround"), option: "force-dolby-surround" },
            { label: qsTr("Media role"), option: "role" },
            { label: qsTr("Visualization width"), option: "effect-width", kind: "number", unit: "px" },
            { label: qsTr("Visualization height"), option: "effect-height", kind: "number", unit: "px" }
          ]
        },
        { group: qsTr("Media"), id: "subtitles", title: qsTr("Subtitles"), heading: qsTr("Subtitle Defaults"),
          sections: [
            { title: qsTr("Tracks & Languages"), rows: [
                { label: qsTr("Enable subtitles"), option: "spu" },
                { label: qsTr("Preferred language"), option: "sub-language" },
                { label: qsTr("Text encoding"), option: "subsdec-encoding" }
            ]},
            { title: qsTr("Loading Subtitles"), rows: [
                { label: qsTr("Load subtitle files automatically"), option: "sub-autodetect-file" },
                { label: qsTr("File name matching"), option: "sub-autodetect-fuzzy" }
            ]},
            { title: qsTr("Appearance"), rows: [
                { label: qsTr("Font"), option: "freetype-font" },
                { label: qsTr("Font size"), option: "sub-text-scale", kind: "slider", unit: "%", step: 5 },
                { label: qsTr("Bold"), option: "freetype-bold" },
                { label: qsTr("Text color"), option: "freetype-color", kind: "color" },
                { label: qsTr("Text opacity"), option: "freetype-opacity", kind: "slider", step: 5 },
                { label: qsTr("Outline thickness"), option: "freetype-outline-thickness" },
                { label: qsTr("Outline color"), option: "freetype-outline-color", kind: "color" },
                { label: qsTr("Shadow opacity"), option: "freetype-shadow-opacity", kind: "slider", step: 5 },
                { label: qsTr("Shadow color"), option: "freetype-shadow-color", kind: "color" },
                { label: qsTr("Shadow distance"), option: "freetype-shadow-distance", kind: "slider", step: 0.01 },
                { label: qsTr("Background opacity"), option: "freetype-background-opacity", kind: "slider", step: 5 },
                { label: qsTr("Background color"), option: "freetype-background-color", kind: "color" },
                { label: qsTr("Distance from the bottom"), option: "sub-margin", kind: "number", unit: "px" }
            ]},
            { title: qsTr("On-Screen Messages"), rows: [
                { label: qsTr("Show feedback for shortcuts"), option: "osd" },
                { label: qsTr("Show filename when a video starts"), option: "video-title-show" },
                { label: qsTr("Show filename for"), option: "video-title-timeout", kind: "slider", unit: "s", scale: 0.001, step: 0.5, min: 1, max: 10 }
            ]}
          ],
          advanced: [
            { label: qsTr("Load subtitles from these folders"), option: "sub-autodetect-path" },
            { label: qsTr("Shadow angle"), option: "freetype-shadow-angle", kind: "number", unit: "°" },
            { label: qsTr("Text direction"), option: "freetype-text-direction" },
            { label: qsTr("Monospace font"), option: "freetype-monofont" }
          ]
        },
        { group: qsTr("Media"), id: "library", title: qsTr("Library"), heading: qsTr("Playlists, Folders & Files"),
          sections: [
            { title: qsTr("Opening Files"), rows: [
                { label: qsTr("Only allow one VLC window"), option: "one-instance" },
                { label: qsTr("Apply to files opened from the file manager"), option: "one-instance-when-started-from-file" },
                { label: qsTr("Add to the playlist instead of replacing it"), option: "playlist-enqueue" },
                { label: qsTr("When opening a folder"), option: "recursive" },
                { label: qsTr("Show hidden files"), option: "show-hiddenfiles" }
            ]},
            { title: qsTr("Metadata & Artwork"), rows: [
                { label: qsTr("Fetch titles and artwork from the internet"), option: "metadata-network-access" },
                { label: qsTr("Use the media library"), option: "media-library", restart: true }
            ]}
          ],
          advanced: []
        },
        { group: qsTr("System"), id: "network", title: qsTr("Network"), heading: qsTr("Network Connections & Security"),
          sections: [
            { title: qsTr("Buffering"), rows: [
                { label: qsTr("Local files"), option: "file-caching", kind: "number", unit: "ms" },
                { label: qsTr("Discs"), option: "disc-caching", kind: "number", unit: "ms" },
                { label: qsTr("Network streams"), option: "network-caching", kind: "number", unit: "ms" },
                { label: qsTr("Live capture"), option: "live-caching", kind: "number", unit: "ms" }
            ]},
            { title: qsTr("Proxy"), rows: [
                { label: qsTr("HTTP proxy"), option: "http-proxy" },
                { label: qsTr("HTTP proxy password"), option: "http-proxy-pwd", kind: "password" }
            ]},
            { title: qsTr("Security"), rows: [
                { label: qsTr("Verify certificates against the system trust store"), option: "gnutls-system-trust" },
                { label: qsTr("Cipher preference"), option: "gnutls-priorities" }
            ]}
          ],
          advanced: []
        },
        { group: qsTr("System"), id: "performance", title: qsTr("Performance"), heading: qsTr("Performance Settings"),
          sections: [
            { title: qsTr("Decoding"), rows: [
                { label: qsTr("Hardware-accelerated decoding"), option: "dec-dev" },
                { label: qsTr("Skip the H.264 loop filter"), option: "avcodec-skiploopfilter" },
                { label: qsTr("Decoding threads"), option: "avcodec-threads", kind: "number",
                  help: qsTr("0 lets VLC decide.") }
            ]},
            { title: qsTr("Smooth Playback"), rows: [
                { label: qsTr("Drop frames when the system can't keep up"), option: "drop-late-frames" },
                { label: qsTr("Give VLC real-time priority"), option: "high-priority", restart: true }
            ]}
          ],
          advanced: [
            { label: qsTr("Clock synchronisation"), option: "clock-synchro" },
            { label: qsTr("Clock jitter"), option: "clock-jitter", kind: "number", unit: "ms" }
          ]
        },
        { group: qsTr("System"), id: "recording", title: qsTr("Recording"), heading: qsTr("Recording, Casting & Streaming Out"),
          sections: [
            { title: qsTr("Recording"), rows: [
                { label: qsTr("Save recordings to"), option: "input-record-path", kind: "directory" },
                { label: qsTr("Record without re-encoding when possible"), option: "input-record-native" }
            ]},
            { title: qsTr("Casting"), rows: [
                { label: qsTr("Cast quality"), option: "sout-chromecast-conversion-quality" }
            ]},
            { title: qsTr("Streaming"), rows: [
                { label: qsTr("Play locally while streaming"), option: "sout-display" },
                { label: qsTr("Include audio"), option: "sout-audio" },
                { label: qsTr("Include video"), option: "sout-video" },
                { label: qsTr("Include subtitles"), option: "sout-spu" },
                { label: qsTr("Encoding preset"), option: "sout-x264-preset" },
                { label: qsTr("Tuning"), option: "sout-x264-tune" }
            ]}
          ],
          advanced: []
        },
        { group: qsTr("System"), id: "extensions", title: qsTr("Extensions"), heading: qsTr("Add-ons & Scripts"),
          sections: [
            { title: qsTr("Add-ons"), rows: [
                { label: qsTr("Installed plugins, extensions and add-ons"), kind: "action", action: "addons", button: qsTr("Manage") }
            ]}
          ],
          advanced: []
        }
    ]
}
