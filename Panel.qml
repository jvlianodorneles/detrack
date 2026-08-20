import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Engine.js" as Engine
import "QRCode.js" as QRCodeLib

Panel {
  id: root
  moduleName: "dorneles.detrack"
  ipcTarget: "dorneles.detrack"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  // State
  property string originalUrl: ""
  property string cleanedUrl: ""
  property var trackersRemoved: []
  property int trackersCount: 0
  property int charsSaved: 0
  property string domain: ""
  property bool hasUrl: false
  property bool isCopied: false
  property var qrMatrix: []

  // Watch Omarchy clipboard-history.json for instant synchronous capture
  property FileView historyFile: FileView {
    path: Quickshell.env("HOME") + "/.local/state/omarchy/clipboard-history.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      try {
        var hist = JSON.parse(text())
        if (hist && hist.length > 0) {
          for (var i = 0; i < Math.min(hist.length, 5); i++) {
            if (hist[i].type === "text" && hist[i].text) {
              root.processInput(hist[i].text)
              break
            }
          }
        }
      } catch (e) {}
    }
  }

  // Direct clipboard read via wl-paste
  Process {
    id: clipboardProc
    command: ["wl-paste", "--type", "text", "--no-newline"]
    stdout: StdioCollector {
      id: clipboardStdout
      waitForEnd: true
      onStreamFinished: {
        var clipText = String(text || "").trim()
        if (clipText.length > 0) {
          root.processInput(clipText)
        }
      }
    }
  }

  function fetchFromClipboard() {
    historyFile.reload()
    clipboardProc.running = false
    clipboardProc.command = ["wl-paste", "--type", "text", "--no-newline"]
    clipboardProc.running = true
  }

  // Step 1: Clean URL -> Step 2: Generate QR Code from Cleaned URL
  function processInput(rawText) {
    if (!rawText || rawText.length === 0) {
      root.hasUrl = false
      root.originalUrl = ""
      root.cleanedUrl = ""
      root.trackersRemoved = []
      root.trackersCount = 0
      root.charsSaved = 0
      root.domain = ""
      root.qrMatrix = []
      qrCanvas.requestPaint()
      return
    }

    // 1. First perform the cleaning
    var res = Engine.cleanUrl(rawText)
    if (res.isValid && res.cleanedUrl && res.cleanedUrl.length > 0) {
      root.hasUrl = true
      root.originalUrl = res.originalUrl
      root.cleanedUrl = res.cleanedUrl
      root.trackersRemoved = res.trackersRemoved
      root.trackersCount = res.trackersCount
      root.charsSaved = res.charsSaved
      root.domain = res.domain

      // 2. Then generate QR-Code with the CLEANED URL
      try {
        root.qrMatrix = QRCodeLib.generateMatrix(res.cleanedUrl, "M")
      } catch (e) {
        try {
          root.qrMatrix = QRCodeLib.generateMatrix(res.cleanedUrl, "L")
        } catch (err) {
          root.qrMatrix = []
        }
      }
    } else {
      root.hasUrl = false
      root.originalUrl = rawText
      root.cleanedUrl = ""
      root.trackersRemoved = []
      root.trackersCount = 0
      root.charsSaved = 0
      root.domain = ""
      root.qrMatrix = []
    }
    qrCanvas.requestPaint()
  }

  function copyCleanedUrl() {
    if (!root.hasUrl || !root.cleanedUrl) return
    Quickshell.execDetached(["wl-copy", root.cleanedUrl])
    root.isCopied = true
    copiedResetTimer.restart()
  }

  function openInBrowser() {
    if (!root.hasUrl || !root.cleanedUrl) return
    Quickshell.execDetached(["xdg-open", root.cleanedUrl])
    root.close()
  }

  Timer {
    id: copiedResetTimer
    interval: 1800
    repeat: false
    onTriggered: {
      root.isCopied = false
    }
  }

  function open() {
    root.fetchFromClipboard()
    root.controller.show()
  }

  function close() {
    root.controller.hide()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open()
  }

  onOpenedChanged: {
    if (root.opened) {
      root.fetchFromClipboard()
    }
  }

  Component.onCompleted: {
    root.fetchFromClipboard()
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem || (hostWidget ? hostWidget : null)
    owner: root.barIdentity
    bar: root.bar || (hostWidget ? hostWidget.bar : null)
    open: root.opened
    contentWidth: panel.fittedContentWidth(Style.space(250))
    contentHeight: panel.fittedContentHeight(Style.space(285), Style.space(310))

    Item {
      anchors.fill: parent
      focus: true

      Keys.onPressed: function(event) {
        if (event.key === Qt.Key_C || (event.key === Qt.Key_C && (event.modifiers & Qt.ControlModifier))) {
          root.copyCleanedUrl()
          event.accepted = true
        } else if (event.key === Qt.Key_B || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
          root.openInBrowser()
          event.accepted = true
        } else if (event.key === Qt.Key_P || event.key === Qt.Key_R) {
          root.fetchFromClipboard()
          event.accepted = true
        } else if (event.key === Qt.Key_Escape) {
          root.close()
          event.accepted = true
        }
      }

      ColumnLayout {
        anchors.fill: parent
        spacing: Style.space(8)

        // ------------------------------------------------ Header
        RowLayout {
          Layout.fillWidth: true
          Layout.preferredHeight: Style.space(24)
          spacing: Style.space(6)

          // App Title + Icon
          RowLayout {
            spacing: Style.space(5)
            Layout.alignment: Qt.AlignVCenter

            Text {
              text: "󰒃" // Shield check
              color: Color.accent
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.title3
            }

            Text {
              text: "DETRACK"
              color: Color.popups.text
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.body
              font.bold: true
              font.letterSpacing: 1
            }
          }

          // Trackers removed badge
          Rectangle {
            visible: root.trackersCount > 0
            Layout.preferredHeight: Style.space(18)
            Layout.preferredWidth: trackerBadgeText.implicitWidth + Style.space(10)
            radius: Style.radius(9)
            color: Util.alpha(Color.accent, 0.18)
            border.color: Util.alpha(Color.accent, 0.4)
            border.width: 1

            Text {
              id: trackerBadgeText
              anchors.centerIn: parent
              text: "-" + root.trackersCount
              color: Color.accent
              font.family: "Monospace, monospace"
              font.pixelSize: Style.font.caption
              font.bold: true
            }
          }

          Item { Layout.fillWidth: true }

          // Re-read clipboard button
          Rectangle {
            Layout.preferredWidth: Style.space(24)
            Layout.preferredHeight: Style.space(24)
            radius: Style.radius(4)
            color: refreshMouseArea.pressed ? Util.alpha(Color.foreground, 0.15) : (refreshMouseArea.containsMouse ? Util.alpha(Color.foreground, 0.08) : "transparent")

            Text {
              anchors.centerIn: parent
              text: "󰑐"
              color: refreshMouseArea.containsMouse ? Color.accent : Color.muted
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.caption
            }

            MouseArea {
              id: refreshMouseArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.fetchFromClipboard()
            }

            PanelToolTip {
              visible: refreshMouseArea.containsMouse
              text: "Re-read from clipboard (P / R)"
            }
          }

          // Close button
          Rectangle {
            Layout.preferredWidth: Style.space(24)
            Layout.preferredHeight: Style.space(24)
            radius: Style.radius(4)
            color: closeMouseArea.pressed ? Util.alpha(Color.foreground, 0.15) : (closeMouseArea.containsMouse ? Util.alpha(Color.foreground, 0.08) : "transparent")

            Text {
              anchors.centerIn: parent
              text: "󰅖"
              color: closeMouseArea.containsMouse ? Color.urgent : Color.muted
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.caption
            }

            MouseArea {
              id: closeMouseArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.close()
            }

            PanelToolTip {
              visible: closeMouseArea.containsMouse
              text: "Close (Esc)"
            }
          }
        }

        // ------------------------------------------------ QR Code Card
        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: Style.space(200)
          radius: Style.radius(8)
          color: Util.alpha(Color.background, 0.5)
          border.color: Util.alpha(Color.foreground, 0.12)
          border.width: 1

          // White container for camera contrast
          Rectangle {
            id: qrWhiteBox
            anchors.centerIn: parent
            width: Style.space(180)
            height: Style.space(180)
            radius: Style.radius(6)
            color: "#ffffff"
            border.color: "#d0d0d0"
            border.width: 1

            Canvas {
              id: qrCanvas
              anchors.fill: parent
              anchors.margins: Style.space(8)
              antialiasing: false

              onWidthChanged: requestPaint()
              onHeightChanged: requestPaint()
              onVisibleChanged: requestPaint()

              Connections {
                target: root
                function onQrMatrixChanged() { qrCanvas.requestPaint() }
                function onHasUrlChanged() { qrCanvas.requestPaint() }
              }

              onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)

                if (width <= 0 || height <= 0) return

                if (!root.hasUrl || !root.qrMatrix || root.qrMatrix.length === 0) {
                  ctx.fillStyle = "#888888"
                  ctx.font = "11px sans-serif"
                  ctx.textAlign = "center"
                  ctx.textBaseline = "middle"
                  ctx.fillText("No URL in clipboard", width / 2, height / 2)
                  return
                }

                var matrix = root.qrMatrix
                var count = matrix.length
                if (count === 0) return

                var cellSize = width / count

                ctx.fillStyle = "#000000"
                for (var r = 0; r < count; r++) {
                  for (var c = 0; c < count; c++) {
                    if (matrix[r][c]) {
                      ctx.fillRect(Math.floor(c * cellSize), Math.floor(r * cellSize), Math.ceil(cellSize), Math.ceil(cellSize))
                    }
                  }
                }
              }
            }

            // Click QR Code to copy
            MouseArea {
              anchors.fill: parent
              cursorShape: root.hasUrl ? Qt.PointingHandCursor : Qt.ArrowCursor
              onClicked: root.copyCleanedUrl()
            }

            PanelToolTip {
              visible: parent.containsMouse && root.hasUrl
              text: root.cleanedUrl ? ("Click to copy:\n" + root.cleanedUrl) : "Click to copy"
            }
          }
        }

        // ------------------------------------------------ Action Buttons Row (COPY / BROWSE)
        RowLayout {
          Layout.fillWidth: true
          Layout.preferredHeight: Style.space(28)
          spacing: Style.space(8)

          // COPY BUTTON
          Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Style.space(28)
            radius: Style.radius(6)
            color: !root.hasUrl ? Util.alpha(Color.foreground, 0.05) : (copyMouseArea.pressed ? Qt.darker(Color.accent, 1.25) : Color.accent)
            opacity: root.hasUrl ? 1.0 : 0.4

            RowLayout {
              anchors.centerIn: parent
              spacing: Style.space(5)

              Text {
                text: root.isCopied ? "󰄬" : "󰅍" // Check or Copy
                color: root.hasUrl ? "#ffffff" : Color.muted
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.caption
                font.bold: true
              }

              Text {
                text: root.isCopied ? "COPIED!" : "COPY"
                color: root.hasUrl ? "#ffffff" : Color.muted
                font.family: "Monospace, monospace"
                font.bold: true
                font.pixelSize: Style.font.caption
                font.letterSpacing: 1
              }
            }

            MouseArea {
              id: copyMouseArea
              anchors.fill: parent
              enabled: root.hasUrl
              cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
              onClicked: root.copyCleanedUrl()
            }

            PanelToolTip {
              visible: copyMouseArea.containsMouse
              text: "Copy cleaned URL to clipboard (C)"
            }
          }

          // BROWSE BUTTON
          Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Style.space(28)
            radius: Style.radius(6)
            color: !root.hasUrl ? Util.alpha(Color.foreground, 0.05) : (browseMouseArea.pressed ? Util.alpha(Color.foreground, 0.2) : (browseMouseArea.containsMouse ? Util.alpha(Color.foreground, 0.12) : Util.alpha(Color.foreground, 0.08)))
            border.color: Util.alpha(Color.foreground, 0.15)
            border.width: 1
            opacity: root.hasUrl ? 1.0 : 0.4

            RowLayout {
              anchors.centerIn: parent
              spacing: Style.space(5)

              Text {
                text: "󰖟" // Browser icon
                color: root.hasUrl ? Color.popups.text : Color.muted
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.caption
              }

              Text {
                text: "BROWSE"
                color: root.hasUrl ? Color.popups.text : Color.muted
                font.family: "Monospace, monospace"
                font.bold: true
                font.pixelSize: Style.font.caption
                font.letterSpacing: 1
              }
            }

            MouseArea {
              id: browseMouseArea
              anchors.fill: parent
              enabled: root.hasUrl
              cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
              onClicked: root.openInBrowser()
            }

            PanelToolTip {
              visible: browseMouseArea.containsMouse
              text: "Open cleaned URL in default browser (B / Enter)"
            }
          }
        }
      }
    }
  }
}
