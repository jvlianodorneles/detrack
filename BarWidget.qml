import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Engine.js" as Engine

BarWidget {
  id: root
  moduleName: "dorneles.detrack"

  readonly property bool showTrackerBadge: setting("showTrackerBadge", false)
  readonly property string iconStyle: setting("iconStyle", "shield")

  property int lastTrackersRemoved: 0
  property string lastCleanedUrl: ""

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

  function open() {
    if (panelLoader.item) {
      panelLoader.item.open()
    }
  }

  function close() {
    if (panelLoader.item) panelLoader.item.close()
  }

  function togglePanel() {
    if (root.opened) {
      root.close()
    } else {
      root.open()
    }
  }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  // Background process for silent direct clipboard clean (right click / IPC)
  Process {
    id: pasteProc
    running: false
    command: ["wl-paste", "--no-newline"]
    stdout: StdioCollector {
      id: pasteStdout
      waitForEnd: true
      onStreamFinished: {
        var raw = String(text || "").trim()
        if (raw.length > 0) {
          var res = Engine.cleanUrl(raw)
          if (res.isValid) {
            root.lastTrackersRemoved = res.trackersCount
            root.lastCleanedUrl = res.cleanedUrl
            // Write back to clipboard
            Quickshell.execDetached(["wl-copy", res.cleanedUrl])
            // Send desktop notification
            var notifMsg = res.trackersCount > 0
              ? ("Removed " + res.trackersCount + " tracker" + (res.trackersCount > 1 ? "s" : "") + " (" + res.charsSaved + " chars saved)")
              : "URL is clean"
            Quickshell.execDetached(["notify-send", "-a", "DeTrack", "-i", "security-high", "DeTrack URL Cleaned", notifMsg + "\n" + res.cleanedUrl])
          } else {
            Quickshell.execDetached(["notify-send", "-a", "DeTrack", "-i", "dialog-warning", "DeTrack", "Clipboard does not contain a valid URL"])
          }
        }
      }
    }
  }

  function cleanClipboardDirect() {
    pasteProc.running = false
    pasteProc.command = ["wl-paste", "--no-newline"]
    pasteProc.running = true
  }

  // Loader for popup panel
  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  // IPC handler for keybindings and shell commands
  IpcHandler {
    target: "dorneles.detrack"

    function toggle(): void { root.togglePanel() }
    function open(): void { root.open() }
    function close(): void { root.close() }
    function clean(): void { root.cleanClipboardDirect() }
  }

  function getBarIcon() {
    switch (root.iconStyle) {
      case "link": return "󰌹"   // nf-md-link
      case "qrcode": return "󰐳" // nf-md-qrcode
      case "shield":
      default: return "󰒃"       // nf-md-shield_check
    }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: (root.showTrackerBadge && root.lastTrackersRemoved > 0)
      ? (root.getBarIcon() + " " + root.lastTrackersRemoved)
      : root.getBarIcon()
    active: root.opened
    fontSize: Style.bar.iconFont
    tooltipText: "DeTrack (URL Cleaner & QR)\n• Click: Open Cleaned URL & QR Code\n• Right-click: Direct Clean Clipboard"

    onPressed: function(btn) {
      if (btn === Qt.RightButton) {
        root.cleanClipboardDirect()
      } else {
        root.togglePanel()
      }
    }
  }
}
