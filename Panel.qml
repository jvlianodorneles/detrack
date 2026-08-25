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
  readonly property color foreground: bar ? bar.barForeground : Color.foreground
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  // State
  property var settings: null
  property string originalUrl: ""
  property string cleanedUrl: ""
  property var trackersRemoved: []
  property int trackersCount: 0
  property int charsSaved: 0
  property string domain: ""
  property bool isShortener: false
  property bool showTrackerDetails: false
  property bool hasUrl: false
  property bool isCopied: false
  property var qrMatrix: []
  readonly property int qrSize: (qrMatrix && qrMatrix.length) ? qrMatrix.length : 0

  function getPreserveParams() {
    return (root.settings && Array.isArray(root.settings.preserveParams)) ? root.settings.preserveParams : []
  }

  readonly property string qrThemeStyle: (root.settings && root.settings.qrThemeStyle) ? root.settings.qrThemeStyle : "accent"

  readonly property color qrBoxBackgroundColor: {
    switch (root.qrThemeStyle) {
      case "dark_themed":
        return Color.surface || Util.alpha(Color.background, 0.95)
      case "classic":
      case "accent":
      default:
        return "#ffffff"
    }
  }

  readonly property color qrModuleColor: {
    switch (root.qrThemeStyle) {
      case "dark_themed":
      case "accent":
        return Color.accent
      case "classic":
      default:
        return "#000000"
    }
  }

  readonly property color qrBoxBorderColor: {
    switch (root.qrThemeStyle) {
      case "dark_themed":
      case "accent":
        return Util.alpha(Color.accent, 0.3)
      case "classic":
      default:
        return "transparent"
    }
  }

  // Bounded, no-follow regular-file reader for Omarchy clipboard history
  Process {
    id: historyReadProc
    running: false
    command: [
      "python3",
      "-c",
      "import os, stat, select, time, json, sys\n" +
      "path = os.path.expanduser('~/.local/state/omarchy/clipboard-history.json')\n" +
      "try:\n" +
      "    flags = os.O_RDONLY | getattr(os, 'O_NOFOLLOW', 0) | getattr(os, 'O_NONBLOCK', 0)\n" +
      "    fd = os.open(path, flags)\n" +
      "    try:\n" +
      "        st = os.fstat(fd)\n" +
      "        if stat.S_ISREG(st.st_mode):\n" +
      "            chunks, total, start_time = [], 0, time.monotonic()\n" +
      "            while total < 65536:\n" +
      "                rem = 1.0 - (time.monotonic() - start_time)\n" +
      "                if rem <= 0: break\n" +
      "                r, _, _ = select.select([fd], [], [], rem)\n" +
      "                if not r: break\n" +
      "                chunk = os.read(fd, min(4096, 65536 - total))\n" +
      "                if not chunk: break\n" +
      "                chunks.append(chunk)\n" +
      "                total += len(chunk)\n" +
      "            data = b''.join(chunks).decode('utf-8', errors='ignore')\n" +
      "            hist = json.loads(data)\n" +
      "            if isinstance(hist, list) and hist:\n" +
      "                for item in hist[:10]:\n" +
      "                    if isinstance(item, dict) and item.get('type') == 'text' and item.get('text'):\n" +
      "                        print(str(item['text'])[:8192], end='')\n" +
      "                        break\n" +
      "    finally:\n" +
      "        os.close(fd)\n" +
      "except Exception:\n" +
      "    pass\n"
    ]
    stdout: StdioCollector {
      id: historyStdout
      waitForEnd: true
      onStreamFinished: {
        var raw = String(text || "").trim()
        if (raw.length > 0) {
          root.processInput(raw.slice(0, 8192))
        }
      }
    }
  }

  // Watcher for Omarchy clipboard history updates
  property FileView historyFile: FileView {
    path: Quickshell.env("HOME") + "/.local/state/omarchy/clipboard-history.json"
    watchChanges: true
    printErrors: false
    onFileChanged: root.readHistoryFileBounded()
    onLoaded: root.readHistoryFileBounded()
  }

  // Direct Process for wl-paste
  Process {
    id: clipboardProc
    command: ["sh", "-c", "timeout 2 wl-paste --type text --no-newline 2>/dev/null | head -c 8192"]
    stdout: StdioCollector {
      id: clipboardStdout
      waitForEnd: true
      onStreamFinished: {
        var raw = String(text || "").trim()
        if (raw.length > 0) {
          root.processInput(raw.slice(0, 8192))
        }
      }
    }
  }

  // Async Unshortener Process
  Process {
    id: unshortenProc
    running: false
    command: []
    stdout: StdioCollector {
      id: unshortenStdout
      waitForEnd: true
      onStreamFinished: {
        var resolved = String(text || "").trim()
        if (resolved.length > 0 && resolved !== root.cleanedUrl) {
          root.processInput(resolved)
        }
      }
    }
  }

  function unshortenCurrentUrl() {
    if (!root.cleanedUrl) return
    var safeUrl = String(root.cleanedUrl).slice(0, 8192)
    if (!/^https?:\/\//i.test(safeUrl)) return
    unshortenProc.running = false
    unshortenProc.command = [
      "python3",
      "-c",
      "import sys, socket, ipaddress, ssl, http.client, urllib.parse\n" +
      "def is_safe_ip(ip):\n" +
      "    if isinstance(ip, ipaddress.IPv6Address) and ip.ipv4_mapped:\n" +
      "        ip = ip.ipv4_mapped\n" +
      "    return not (ip.is_private or ip.is_loopback or ip.is_link_local or ip.is_multicast or ip.is_reserved or ip.is_unspecified)\n" +
      "def unshorten(url, max_hops=5, timeout=4):\n" +
      "    curr = url\n" +
      "    visited = set()\n" +
      "    for _ in range(max_hops):\n" +
      "        if curr in visited:\n" +
      "            break\n" +
      "        visited.add(curr)\n" +
      "        try:\n" +
      "            parsed = urllib.parse.urlparse(curr)\n" +
      "            scheme = parsed.scheme.lower()\n" +
      "            if scheme not in ('http', 'https'):\n" +
      "                return None\n" +
      "            hostname = parsed.hostname\n" +
      "            if not hostname or hostname.lower() in ('localhost', 'ip6-localhost', 'ip6-loopback'):\n" +
      "                return None\n" +
      "            is_https = scheme == 'https'\n" +
      "            port = parsed.port or (443 if is_https else 80)\n" +
      "            addr_info = socket.getaddrinfo(hostname, port, socket.AF_UNSPEC, socket.SOCK_STREAM)\n" +
      "            if not addr_info:\n" +
      "                return None\n" +
      "            safe_entries = []\n" +
      "            for family, socktype, proto, _, sockaddr in addr_info:\n" +
      "                ip = ipaddress.ip_address(sockaddr[0].split('%')[0])\n" +
      "                if not is_safe_ip(ip):\n" +
      "                    return None\n" +
      "                safe_entries.append((family, socktype, proto, sockaddr))\n" +
      "            if not safe_entries:\n" +
      "                return None\n" +
      "        except Exception:\n" +
      "            return None\n" +
      "        family, socktype, proto, target_sockaddr = safe_entries[0]\n" +
      "        sock = None\n" +
      "        conn = None\n" +
      "        try:\n" +
      "            sock = socket.socket(family, socktype, proto)\n" +
      "            sock.settimeout(timeout)\n" +
      "            sock.connect(target_sockaddr)\n" +
      "            peer_ip = sock.getpeername()[0].split('%')[0]\n" +
      "            if peer_ip != target_sockaddr[0].split('%')[0]:\n" +
      "                sock.close()\n" +
      "                return None\n" +
      "            if not is_safe_ip(ipaddress.ip_address(peer_ip)):\n" +
      "                sock.close()\n" +
      "                return None\n" +
      "            if is_https:\n" +
      "                ctx = ssl.create_default_context()\n" +
      "                sock = ctx.wrap_socket(sock, server_hostname=hostname)\n" +
      "                conn = http.client.HTTPSConnection(hostname, port, timeout=timeout)\n" +
      "            else:\n" +
      "                conn = http.client.HTTPConnection(hostname, port, timeout=timeout)\n" +
      "            conn.sock = sock\n" +
      "            req_path = parsed.path or '/'\n" +
      "            if parsed.query:\n" +
      "                req_path += '?' + parsed.query\n" +
      "            host_hdr = f'[{hostname}]' if ':' in hostname else hostname\n" +
      "            if parsed.port and parsed.port != (443 if is_https else 80):\n" +
      "                host_hdr = f'{host_hdr}:{parsed.port}'\n" +
      "            headers = {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)', 'Accept': '*/*', 'Host': host_hdr, 'Connection': 'close'}\n" +
      "            conn.request('GET', req_path, headers=headers)\n" +
      "            resp = conn.getresponse()\n" +
      "            if resp.status in (301, 302, 303, 307, 308):\n" +
      "                loc = resp.getheader('Location')\n" +
      "                if not loc:\n" +
      "                    break\n" +
      "                next_url = urllib.parse.urljoin(curr, loc)\n" +
      "                if not next_url.lower().startswith(('http://', 'https://')):\n" +
      "                    break\n" +
      "                curr = next_url\n" +
      "            else:\n" +
      "                break\n" +
      "        except Exception:\n" +
      "            return None\n" +
      "        finally:\n" +
      "            if conn:\n" +
      "                try:\n" +
      "                    conn.close()\n" +
      "                except Exception:\n" +
      "                    pass\n" +
      "            elif sock:\n" +
      "                try:\n" +
      "                    sock.close()\n" +
      "                except Exception:\n" +
      "                    pass\n" +
      "    return curr\n" +
      "url = sys.argv[1] if len(sys.argv) > 1 else ''\n" +
      "if url:\n" +
      "    target = unshorten(url)\n" +
      "    if target and target != url:\n" +
      "        print(target)\n",
      safeUrl
    ]
    unshortenProc.running = true
  }

  function readHistoryFileBounded() {
    historyReadProc.running = false
    historyReadProc.running = true
  }

  function fetchFromClipboard() {
    root.readHistoryFileBounded()
    clipboardProc.running = false
    clipboardProc.running = true
  }

  // Step 1: Clean URL -> Step 2: Generate QR Code from Cleaned URL
  function processInput(rawText) {
    var bounded = (rawText && typeof rawText === "string") ? rawText.slice(0, 8192) : ""
    if (!bounded || bounded.length === 0) {
      root.hasUrl = false
      root.originalUrl = ""
      root.cleanedUrl = ""
      root.trackersRemoved = []
      root.trackersCount = 0
      root.charsSaved = 0
      root.domain = ""
      root.isShortener = false
      root.showTrackerDetails = false
      root.qrMatrix = []
      return
    }

    var res = Engine.cleanUrl(bounded, { preserveParams: root.getPreserveParams() })
    if (res.isValid && res.cleanedUrl && res.cleanedUrl.length > 0) {
      root.hasUrl = true
      root.originalUrl = res.originalUrl
      root.cleanedUrl = res.cleanedUrl
      root.trackersRemoved = res.trackersRemoved
      root.trackersCount = res.trackersCount
      root.charsSaved = res.charsSaved
      root.domain = res.domain
      root.isShortener = res.isShortener

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
      root.isShortener = false
      root.showTrackerDetails = false
      root.qrMatrix = []
    }
  }

  function copyCleanedUrl() {
    if (!root.hasUrl || !root.cleanedUrl) return
    Quickshell.execDetached(["wl-copy", root.cleanedUrl])
    root.isCopied = true
    copiedResetTimer.restart()
  }

  function openInBrowser() {
    if (!root.hasUrl || !root.cleanedUrl) return
    Quickshell.execDetached(["xdg-open", "--", root.cleanedUrl])
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

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function") {
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    }
    return false
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
    contentWidth: panel.fittedContentWidth(Style.space(280))
    contentHeight: panel.fittedContentHeight(panelColumn.implicitHeight)

    PanelKeyCatcher {
      anchors.fill: parent

      onCloseRequested: root.close()
      onActivateRequested: root.openInBrowser()
      onReturnRequested: root.openInBrowser()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) {
        if (t === "c") root.copyCleanedUrl()
        else if (t === "b") root.openInBrowser()
        else if (t === "r" || t === "p") root.fetchFromClipboard()
      }

      ColumnLayout {
        id: panelColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(10)

        // ------------------------------------------------ Header (PanelHero)
        PanelHero {
          Layout.fillWidth: true
          title: "detrack"
          meta: "URL TRACKER CLEANER"
          foreground: root.foreground
          fontFamily: root.fontFamily

          iconComponent: Component {
            Text {
              text: "󰒃" // nf-md-shield_check
              font.family: root.fontFamily
              font.pixelSize: Style.font.display
              color: Color.accent
            }
          }

          trailingControl: Component {
            Row {
              spacing: Style.space(6)

              Button {
                iconText: "󰅖" // close
                tooltipText: "Close (Esc)"
                fontSize: Style.font.body
                onClicked: root.close()
              }
            }
          }
        }

        PanelSeparator {
          Layout.fillWidth: true
          foreground: root.foreground
        }

        // ------------------------------------------------ QR Code Card
        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: Style.space(200)
          radius: Style.cornerRadius
          color: Util.alpha(Color.background, 0.5)

          Behavior on color { ColorAnimation { duration: 100 } }

          // Placeholder when no URL in clipboard
          Column {
            anchors.centerIn: parent
            spacing: Style.space(6)
            visible: !root.hasUrl || root.qrSize === 0

            Text {
              text: "󰅌"
              color: Color.muted
              opacity: 0.7
              font.family: root.fontFamily
              font.pixelSize: Style.font.displayLarge
              horizontalAlignment: Text.AlignHCenter
              anchors.horizontalCenter: parent.horizontalCenter
            }

            Text {
              text: "No URL in clipboard"
              color: Color.popups.text
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              horizontalAlignment: Text.AlignHCenter
              anchors.horizontalCenter: parent.horizontalCenter
            }

            Text {
              text: "Copy a link to clean & generate QR"
              color: Color.muted
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              horizontalAlignment: Text.AlignHCenter
              anchors.horizontalCenter: parent.horizontalCenter
            }
          }

          // Crisp native QR Code Box
          Rectangle {
            id: qrContainerBox
            visible: root.hasUrl && root.qrSize > 0
            anchors.centerIn: parent
            readonly property int moduleSize: root.qrSize > 0
              ? Math.max(2, Math.floor(Style.space(190) / root.qrSize))
              : 0
            width: (root.qrSize * moduleSize) + Style.space(16)
            height: width
            radius: Style.cornerRadius
            color: root.qrBoxBackgroundColor
            border.color: root.qrBoxBorderColor
            border.width: root.qrBoxBorderColor !== "transparent" ? 1 : 0

            Behavior on color { ColorAnimation { duration: 150 } }
            Behavior on border.color { ColorAnimation { duration: 150 } }

            Grid {
              anchors.centerIn: parent
              columns: root.qrSize
              rows: root.qrSize

              Repeater {
                model: root.qrSize * root.qrSize

                Rectangle {
                  required property int index
                  readonly property int matrixRow: Math.floor(index / root.qrSize)
                  readonly property int matrixColumn: index % root.qrSize

                  width: qrContainerBox.moduleSize
                  height: qrContainerBox.moduleSize
                  color: (root.qrMatrix && root.qrMatrix[matrixRow] && root.qrMatrix[matrixRow][matrixColumn]) ? root.qrModuleColor : "transparent"

                  Behavior on color { ColorAnimation { duration: 150 } }
                }
              }
            }

            MouseArea {
              id: qrMouseArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: root.hasUrl ? Qt.PointingHandCursor : Qt.ArrowCursor
              onClicked: root.copyCleanedUrl()
            }

            PanelToolTip {
              id: qrToolTip
              visible: qrMouseArea.containsMouse && root.hasUrl
              text: root.cleanedUrl ? ("Click to copy:\n" + root.cleanedUrl) : "Click to copy"
              contentItem: Text {
                text: qrToolTip.text
                textFormat: Text.PlainText
                color: qrToolTip.panelForeground
                font.family: qrToolTip.fontFamily
                font.pixelSize: qrToolTip.fontSize
                leftPadding: Border.left(qrToolTip.panelBorderSpec) + Style.spacing.controlPaddingX
                rightPadding: Border.right(qrToolTip.panelBorderSpec) + Style.spacing.controlPaddingX
                topPadding: Border.top(qrToolTip.panelBorderSpec) + Style.spacing.controlPaddingY
                bottomPadding: Border.bottom(qrToolTip.panelBorderSpec) + Style.spacing.controlPaddingY
              }
            }
          }
        }

        // ------------------------------------------------ Shortlink Expand Button (if shortener detected)
        Rectangle {
          visible: root.hasUrl && root.isShortener
          Layout.fillWidth: true
          Layout.preferredHeight: Style.space(22)
          radius: Style.cornerRadius
          color: unshortenMouseArea.pressed ? Util.alpha(Color.accent, 0.25) : (unshortenMouseArea.containsMouse ? Util.alpha(Color.accent, 0.15) : Util.alpha(Color.accent, 0.08))
          border.color: Util.alpha(Color.accent, 0.3)
          border.width: 1

          RowLayout {
            anchors.centerIn: parent
            spacing: Style.space(5)

            Text {
              text: unshortenProc.running ? "󰑮" : "󰌹"
              color: Color.accent
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }

            Text {
              text: unshortenProc.running ? "EXPANDING SHORTLINK..." : "EXPAND SHORTLINK"
              color: Color.accent
              font.family: "Monospace, monospace"
              font.bold: true
              font.pixelSize: Style.font.caption - 1
              font.letterSpacing: 1
            }
          }

          MouseArea {
            id: unshortenMouseArea
            anchors.fill: parent
            hoverEnabled: true
            enabled: !unshortenProc.running
            cursorShape: Qt.PointingHandCursor
            onClicked: root.unshortenCurrentUrl()
          }

          PanelToolTip {
            id: unshortenToolTip
            visible: unshortenMouseArea.containsMouse
            text: "Resolve destination URL and clean downstream trackers"
            contentItem: Text {
              text: unshortenToolTip.text
              textFormat: Text.PlainText
              color: unshortenToolTip.panelForeground
              font.family: unshortenToolTip.fontFamily
              font.pixelSize: unshortenToolTip.fontSize
              leftPadding: Border.left(unshortenToolTip.panelBorderSpec) + Style.spacing.controlPaddingX
              rightPadding: Border.right(unshortenToolTip.panelBorderSpec) + Style.spacing.controlPaddingX
              topPadding: Border.top(unshortenToolTip.panelBorderSpec) + Style.spacing.controlPaddingY
              bottomPadding: Border.bottom(unshortenToolTip.panelBorderSpec) + Style.spacing.controlPaddingY
            }
          }
        }

        // ------------------------------------------------ Tracker Info Counter & Detail Toggle
        Rectangle {
          visible: root.hasUrl
          Layout.fillWidth: true
          Layout.preferredHeight: Style.space(22)
          radius: Style.cornerRadius
          color: trackerMouseArea.pressed ? Util.alpha(Color.foreground, 0.1) : (trackerMouseArea.containsMouse ? Util.alpha(Color.foreground, 0.05) : "transparent")

          RowLayout {
            anchors.centerIn: parent
            spacing: Style.space(6)

            Text {
              text: root.trackersCount > 0
                ? (root.trackersCount + " TRACKER" + (root.trackersCount > 1 ? "S" : "") + " REMOVED" + (root.charsSaved > 0 ? " (-" + root.charsSaved + " chars)" : ""))
                : "󰄬 URL IS CLEAN"
              color: root.trackersCount > 0 ? Color.accent : Color.popups.text
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 1
              horizontalAlignment: Text.AlignHCenter
            }

            Text {
              visible: root.trackersCount > 0
              text: root.showTrackerDetails ? "󰅃" : "󰅀"
              color: Color.muted
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
          }

          MouseArea {
            id: trackerMouseArea
            anchors.fill: parent
            hoverEnabled: true
            enabled: root.trackersCount > 0
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: {
              if (root.trackersCount > 0) {
                root.showTrackerDetails = !root.showTrackerDetails
              }
            }
          }

          PanelToolTip {
            id: trackerCountToolTip
            visible: trackerMouseArea.containsMouse && root.trackersCount > 0
            text: root.showTrackerDetails ? "Click to collapse tracker list" : "Click to view removed tracker parameters"
            contentItem: Text {
              text: trackerCountToolTip.text
              textFormat: Text.PlainText
              color: trackerCountToolTip.panelForeground
              font.family: trackerCountToolTip.fontFamily
              font.pixelSize: trackerCountToolTip.fontSize
              leftPadding: Border.left(trackerCountToolTip.panelBorderSpec) + Style.spacing.controlPaddingX
              rightPadding: Border.right(trackerCountToolTip.panelBorderSpec) + Style.spacing.controlPaddingX
              topPadding: Border.top(trackerCountToolTip.panelBorderSpec) + Style.spacing.controlPaddingY
              bottomPadding: Border.bottom(trackerCountToolTip.panelBorderSpec) + Style.spacing.controlPaddingY
            }
          }
        }

        // ------------------------------------------------ Collapsible Tracker Tags Flow
        Flow {
          visible: root.hasUrl && root.showTrackerDetails && root.trackersCount > 0
          Layout.fillWidth: true
          spacing: Style.space(4)

          Repeater {
            model: root.trackersRemoved

            Rectangle {
              required property string modelData
              height: Style.space(18)
              width: tagLabel.implicitWidth + Style.space(12)
              radius: Style.space(9)
              color: Util.alpha(Color.accent, 0.12)
              border.color: Util.alpha(Color.accent, 0.3)
              border.width: 1

              Text {
                id: tagLabel
                anchors.centerIn: parent
                text: parent.modelData
                textFormat: Text.PlainText
                color: Color.accent
                font.family: "Monospace, monospace"
                font.pixelSize: Style.font.caption - 2
                font.bold: true
              }
            }
          }
        }

        PanelSeparator {
          Layout.fillWidth: true
          foreground: root.foreground
        }

        // ------------------------------------------------ Action Buttons Row (COPY / BROWSE)
        RowLayout {
          Layout.fillWidth: true
          Layout.preferredHeight: Style.spacing.controlHeight
          spacing: Style.spacing.controlGap

          // COPY BUTTON
          Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Style.spacing.controlHeight
            radius: Style.cornerRadius
            color: !root.hasUrl ? Util.alpha(Color.foreground, 0.05) : (copyMouseArea.pressed ? Qt.darker(Color.accent, 1.25) : Color.accent)
            opacity: root.hasUrl ? 1.0 : 0.4

            Behavior on color { ColorAnimation { duration: 100 } }
            Behavior on opacity { NumberAnimation { duration: 150 } }

            RowLayout {
              anchors.centerIn: parent
              spacing: Style.space(5)

              Text {
                text: root.isCopied ? "󰄬" : "󰅍"
                color: root.hasUrl ? "#ffffff" : Color.muted
                font.family: root.fontFamily
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
              hoverEnabled: true
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
            Layout.preferredHeight: Style.spacing.controlHeight
            radius: Style.cornerRadius
            color: !root.hasUrl ? Util.alpha(Color.foreground, 0.05) : (browseMouseArea.pressed ? Util.alpha(Color.foreground, 0.2) : (browseMouseArea.containsMouse ? Util.alpha(Color.foreground, 0.12) : Util.alpha(Color.foreground, 0.08)))
            border.color: Util.alpha(Color.foreground, 0.15)
            border.width: 1
            opacity: root.hasUrl ? 1.0 : 0.4

            Behavior on color { ColorAnimation { duration: 100 } }
            Behavior on opacity { NumberAnimation { duration: 150 } }

            RowLayout {
              anchors.centerIn: parent
              spacing: Style.space(5)

              Text {
                text: "󰖟"
                color: root.hasUrl ? Color.popups.text : Color.muted
                font.family: root.fontFamily
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
              hoverEnabled: true
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
