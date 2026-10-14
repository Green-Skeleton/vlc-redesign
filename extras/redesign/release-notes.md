An unofficial build of VLC 4 (development version) with the interface restyled after Juxtopposed's "VLC Redesign" Figma Community design.

### How to install

You need 64-bit Windows 10 or 11.

1. Download the file below that ends in `-win64.zip`.
2. Right-click it, choose **Extract All...**, then **Extract**.
3. Open the extracted folder, then `vlc-4.0.0-dev`, and double-click **vlc.exe**.

There's no installer. Settings stay in the `portable` folder next to `vlc.exe`, so this won't touch a VLC you already have. To uninstall, delete the folder.

- If Windows says "Windows protected your PC", click **More info**, then **Run anyway**. The build isn't code-signed.
- The first launch can take about half a minute while Windows scans the new files.
- If Windows Firewall asks about network access, you can click **Cancel**. Playback works either way.

To check the download, run `Get-FileHash .\VLC-Redesign-unofficial-*-win64.zip` in PowerShell and compare the result with `SHA256SUMS.txt`.

### What's in this build

- The design's dark and light themes, accent colours, Inter font and icon set
- The redesigned player: single-row control bar, orange play button, thick seek bar and the wedge volume control
- A new Settings window with 13 pages, search and advanced options
- A three-step welcome window on first launch
- The update check is off, and online artwork lookups only run if you agree to them

VLC 4 is still in development, so expect the occasional bug.

Design by Juxtopposed (CC BY 4.0). VLC by VideoLAN and the VLC contributors (GPL v2 or later). Inter by Rasmus Andersson (SIL OFL 1.1). Not affiliated with or endorsed by VideoLAN or Juxtopposed. See the README for the full list of changes and what isn't done yet.
