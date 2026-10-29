# Security policy

## Reporting a problem

Please report security problems privately through GitHub:
**Security → Report a vulnerability** on this repository. Don't open a public issue for them.

Include what you found, how to reproduce it, and the Peekaboo Keys version (🧸 menu → About).
You'll get a reply within a week.

## Supported versions

Only the latest release gets fixes. Update from the
[latest release](https://github.com/Sravankumartangudu/peekaboo-keys/releases/latest).

## What Peekaboo Keys handles

- **No network.** The app makes no network calls: no accounts, analytics, ads or updates. The
  only link is the GitHub button in About, which opens your browser.
- **Stored on your Mac:** settings in the app's preferences (`com.stangudu.peekabookeys`). Family
  photos and recorded voices in `~/Library/Application Support/Peekaboo Keys/Family`, a folder only
  your user account can read (0700, files 0600). Removing a family member deletes their files.
- **Microphone:** only while you record a family member's voice in Settings, after macOS asks.
- **Accessibility (optional, strong lock):** used only while playing, for an event tap that keeps
  keys inside the play screen. Keys are turned into play and never stored or sent anywhere. The
  tap is removed when play ends, and macOS disables it by itself if the app stalls or quits.
- **Kiosk mode:** while playing, the app hides the Dock and menu bar and blocks app switching
  through standard macOS presentation options, and keeps the display awake. Both end with play.
- **Status files:** small local files in `~/.nexus/` (a heartbeat with the name, version and
  ready / playing, and a copy of the 🧸 menu) for Nexus, the author's local app monitor. They hold
  no personal data and never leave the Mac.
