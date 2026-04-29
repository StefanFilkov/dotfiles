import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: root

    color: "transparent"
    visible: shown   // surface only exists while shown; polling Timer/Process keep running regardless

    anchors { top: true; bottom: true; left: true; right: true }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "alt-tab-switcher"
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // ---- State -------------------------------------------------------------

    property bool shown: false
    property var clientsByWs: ({})
    property var orderedWsIds: []
    property var mru: []
    property string activeAddr: ""
    property string thumbDir: "/tmp/alt-tab-switcher/thumbs"
    property int thumbVersion: 0
    property string filter: ""
    property int selWs: 0
    property int selIdx: 0
    property int mruIndex: 1
    property int lastSeq: -1
    property int pendingDir: 1

    // ---- Theme (kitty 1984) ------------------------------------------------

    readonly property color bgColor:    "#0d0f31"
    readonly property color cardBg:     "#15183b"
    readonly property color rowBg:      "#1a1d4a"
    readonly property color thumbBg:    "#0a0c27"
    readonly property color fgColor:    "#feffff"
    readonly property color subFg:      "#a8acdf"
    readonly property color dimFg:      "#6a6e9d"
    readonly property color accent:     "#00d5eb"   // cyan / cursor
    readonly property color accent2:    "#f806fa"   // magenta
    readonly property color accent3:    "#ff16b0"   // hot pink
    readonly property string monoFont:  "JetBrainsMono Nerd Font"

    // ---- Press polling -----------------------------------------------------

    Timer {
        interval: 50
        running: true
        repeat: true
        onTriggered: pressPoller.running = true
    }

    Process {
        id: pressPoller
        command: ["bash", "-c", "cat /tmp/alt-tab-switcher/press 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const txt = this.text.trim()
                if (txt === "") return
                const parts = txt.split(/\s+/)
                const n = parseInt(parts[0])
                if (isNaN(n)) return
                const dir = (parts[1] === "prev") ? -1 : 1
                if (root.lastSeq < 0) { root.lastSeq = n; return }
                if (n === root.lastSeq) return
                root.lastSeq = n
                root.pendingDir = dir
                root.handlePress()
            }
        }
    }

    Process {
        id: stateLoader
        command: ["cat", "/tmp/alt-tab-switcher/state.json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const st = JSON.parse(this.text)
                    root.applyState(st)
                    root.openSwitcher()
                } catch (e) {
                    console.warn("alt-tab: state parse error", e)
                }
            }
        }
    }

    // ---- State application -------------------------------------------------

    function applyState(st) {
        const clients = (st.clients || []).filter(c =>
            c && c.workspace && c.workspace.id > 0
            && (c.title || c.class)
            && (c.title || "").indexOf("qs-master") !== 0
            && (c.title || "").indexOf("alt-tab-switcher") !== 0
        )
        const groups = {}
        for (const c of clients) {
            const wid = c.workspace.id
            if (!groups[wid]) groups[wid] = []
            groups[wid].push(c)
        }
        for (const wid in groups) {
            groups[wid].sort((a, b) => (a.at[0] || 0) - (b.at[0] || 0))
        }
        const ids = Object.keys(groups).map(Number).sort((a, b) => a - b)
        clientsByWs = groups
        orderedWsIds = ids
        mru = (st.mru || []).filter(a => a && a !== "")
        activeAddr = st.active || ""
        if (st.thumbDir) thumbDir = st.thumbDir
        thumbVersion = thumbVersion + 1
    }

    // Filter recomputed when filter / state changes.
    property var rows: {
        const _ = [filter, orderedWsIds, clientsByWs]
        const f = (filter || "").toLowerCase()
        const out = []
        for (const id of orderedWsIds) {
            const wins = (clientsByWs[id] || []).filter(w => {
                if (!f) return true
                return ((w.title || "").toLowerCase().indexOf(f) >= 0)
                    || ((w.class || "").toLowerCase().indexOf(f) >= 0)
            })
            if (wins.length > 0) out.push({ id: id, windows: wins })
        }
        return out
    }

    // ---- Press handling ----------------------------------------------------

    function handlePress() {
        if (shown) {
            cycleMRU(pendingDir)
        } else {
            stateLoader.running = true
        }
    }

    function openSwitcher() {
        filter = ""
        searchField.text = ""
        // Default selection: try MRU[1] (the previously-focused window).
        if (mru.length >= 2) { mruIndex = 1 }
        else if (mru.length === 1) { mruIndex = 0 }
        if (!selectByAddr(mru[mruIndex])) {
            selWs = 0
            selIdx = 0
        }
        shown = true
        searchField.forceActiveFocus()
    }

    function hideSwitcher() {
        shown = false
        filter = ""
        searchField.text = ""
    }

    function confirmSelection() {
        const r = rows
        if (r.length === 0) { hideSwitcher(); return }
        const ws = Math.min(selWs, r.length - 1)
        const wins = r[ws].windows
        if (wins.length === 0) { hideSwitcher(); return }
        const idx = Math.min(selIdx, wins.length - 1)
        const addr = wins[idx].address
        if (addr) {
            Quickshell.execDetached(["hyprctl", "dispatch", "focuswindow", "address:" + addr])
        }
        hideSwitcher()
    }

    function selectByAddr(addr) {
        if (!addr) return false
        const r = rows
        for (let i = 0; i < r.length; i++) {
            for (let j = 0; j < r[i].windows.length; j++) {
                if (r[i].windows[j].address === addr) {
                    selWs = i
                    selIdx = j
                    return true
                }
            }
        }
        return false
    }

    function cycleMRU(step) {
        if (mru.length === 0) return
        let attempts = 0
        do {
            mruIndex = (mruIndex + step + mru.length) % mru.length
            attempts++
            if (selectByAddr(mru[mruIndex])) return
        } while (attempts < mru.length)
        if (rows.length > 0) { selWs = 0; selIdx = 0 }
    }

    function moveSel(dx, dy) {
        const r = rows
        if (r.length === 0) return
        const ws = Math.max(0, Math.min(r.length - 1, selWs + dy))
        const wins = r[ws].windows
        const idx = Math.max(0, Math.min(wins.length - 1, selIdx + dx))
        selWs = ws
        selIdx = idx
        const sel = wins[idx]
        if (sel) {
            const mi = mru.indexOf(sel.address)
            if (mi >= 0) mruIndex = mi
        }
    }

    // ---- Visuals -----------------------------------------------------------

    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: shown ? 0.55 : 0
        Behavior on opacity { NumberAnimation { duration: 130 } }

        MouseArea {
            anchors.fill: parent
            enabled: root.shown
            onClicked: root.hideSwitcher()
        }
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: Math.min(1400, parent.width - 160)
        height: Math.min(900, parent.height - 100)
        radius: 16
        color: bgColor
        border.color: accent
        border.width: 2
        opacity: shown ? 1.0 : 0.0
        scale: shown ? 1.0 : 0.96
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

        Rectangle {
            anchors { left: parent.left; right: parent.right; top: parent.top }
            height: 3
            color: accent3
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 14

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Text {
                    text: "alt-tab"
                    color: accent2
                    font.family: monoFont
                    font.pixelSize: 13
                    font.bold: true
                }
                Text { text: "::"; color: dimFg; font.family: monoFont; font.pixelSize: 13 }
                Text {
                    text: rows.length + " workspace" + (rows.length === 1 ? "" : "s")
                    color: subFg
                    font.family: monoFont
                    font.pixelSize: 13
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: "↑↓←→ navigate · enter focus · esc cancel"
                    color: dimFg
                    font.family: monoFont
                    font.pixelSize: 11
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 46
                color: cardBg
                radius: 8
                border.color: searchField.activeFocus ? accent : "#2b2e63"
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    spacing: 10

                    Text {
                        text: ""
                        color: accent
                        font.family: monoFont
                        font.pixelSize: 16
                    }

                    TextField {
                        id: searchField
                        Layout.fillWidth: true
                        placeholderText: "type to filter..."
                        color: fgColor
                        placeholderTextColor: dimFg
                        font.family: monoFont
                        font.pixelSize: 14
                        background: Item {}
                        selectionColor: accent
                        selectedTextColor: bgColor

                        onTextChanged: {
                            root.filter = text
                            const r = root.rows
                            if (r.length === 0) return
                            if (root.selWs >= r.length) root.selWs = 0
                            const wins = r[root.selWs].windows
                            if (root.selIdx >= wins.length) root.selIdx = 0
                        }

                        Keys.onEscapePressed: (e) => { root.hideSwitcher(); e.accepted = true }
                        Keys.onReturnPressed: (e) => { root.confirmSelection(); e.accepted = true }
                        Keys.onEnterPressed:  (e) => { root.confirmSelection(); e.accepted = true }
                        Keys.onLeftPressed:   (e) => { root.moveSel(-1, 0);    e.accepted = true }
                        Keys.onRightPressed:  (e) => { root.moveSel(+1, 0);    e.accepted = true }
                        Keys.onUpPressed:     (e) => { root.moveSel(0, -1);    e.accepted = true }
                        Keys.onDownPressed:   (e) => { root.moveSel(0, +1);    e.accepted = true }
                        Keys.onTabPressed:    (e) => { root.cycleMRU(+1);      e.accepted = true }
                        Keys.onBacktabPressed:(e) => { root.cycleMRU(-1);      e.accepted = true }
                    }
                }
            }

            ListView {
                id: wsList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 12
                boundsBehavior: Flickable.StopAtBounds
                model: root.rows

                delegate: Rectangle {
                    id: wsDelegate
                    required property int index
                    required property var modelData

                    width: wsList.width
                    height: 168
                    color: index === root.selWs ? Qt.rgba(0.0, 0.84, 0.92, 0.06) : cardBg
                    radius: 10
                    border.color: index === root.selWs ? accent : "#262959"
                    border.width: index === root.selWs ? 2 : 1

                    Behavior on color { ColorAnimation { duration: 100 } }
                    Behavior on border.color { ColorAnimation { duration: 100 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 12

                        Rectangle {
                            Layout.preferredWidth: 56
                            Layout.fillHeight: true
                            color: wsDelegate.index === root.selWs ? accent : "#1f2253"
                            radius: 8

                            Text {
                                anchors.centerIn: parent
                                text: wsDelegate.modelData.id
                                color: wsDelegate.index === root.selWs ? bgColor : subFg
                                font.family: monoFont
                                font.pixelSize: 28
                                font.bold: true
                            }
                        }

                        Flickable {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            contentWidth: cardsRow.width
                            contentHeight: height
                            clip: true
                            interactive: true
                            boundsBehavior: Flickable.StopAtBounds

                            Row {
                                id: cardsRow
                                spacing: 10
                                height: parent.height

                                Repeater {
                                    model: wsDelegate.modelData.windows
                                    delegate: Rectangle {
                                        id: cardItem
                                        required property int index
                                        required property var modelData

                                        readonly property int wsRowIndex: wsDelegate.index
                                        readonly property bool isSelected:
                                            wsRowIndex === root.selWs && index === root.selIdx
                                        readonly property bool isActive:
                                            modelData.address === root.activeAddr

                                        width: 220
                                        height: 148
                                        radius: 8
                                        color: rowBg
                                        border.color: isSelected ? accent
                                                       : (isActive ? accent2 : "#2b2e63")
                                        border.width: isSelected ? 2 : (isActive ? 2 : 1)

                                        Behavior on border.color { ColorAnimation { duration: 100 } }

                                        ColumnLayout {
                                            anchors.fill: parent
                                            anchors.margins: 6
                                            spacing: 4

                                            Rectangle {
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: 100
                                                color: thumbBg
                                                radius: 5
                                                clip: true

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: (cardItem.modelData.class || "?").toLowerCase()
                                                    color: subFg
                                                    font.family: monoFont
                                                    font.pixelSize: 13
                                                    font.italic: true
                                                    visible: thumb.status !== Image.Ready
                                                }

                                                Image {
                                                    id: thumb
                                                    anchors.fill: parent
                                                    anchors.margins: 1
                                                    fillMode: Image.PreserveAspectCrop
                                                    asynchronous: true
                                                    cache: false
                                                    smooth: true
                                                    // thumbVersion forces re-evaluation when state reloads
                                                    source: cardItem.modelData.address && root.thumbVersion >= 0
                                                        ? "file://" + root.thumbDir + "/"
                                                          + cardItem.modelData.address + ".png"
                                                        : ""
                                                    visible: status === Image.Ready
                                                }
                                            }

                                            Text {
                                                Layout.fillWidth: true
                                                text: cardItem.modelData.title
                                                      || cardItem.modelData.class
                                                      || "(untitled)"
                                                color: cardItem.isSelected ? accent : fgColor
                                                font.family: monoFont
                                                font.pixelSize: 11
                                                elide: Text.ElideRight
                                                maximumLineCount: 1
                                            }
                                            Text {
                                                Layout.fillWidth: true
                                                text: cardItem.modelData.class || ""
                                                color: cardItem.isActive ? accent2 : dimFg
                                                font.family: monoFont
                                                font.pixelSize: 10
                                                elide: Text.ElideRight
                                                maximumLineCount: 1
                                            }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            hoverEnabled: true
                                            onEntered: {
                                                root.selWs = cardItem.wsRowIndex
                                                root.selIdx = cardItem.index
                                            }
                                            onClicked: {
                                                root.selWs = cardItem.wsRowIndex
                                                root.selIdx = cardItem.index
                                                root.confirmSelection()
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
