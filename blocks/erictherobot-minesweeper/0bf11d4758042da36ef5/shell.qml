//@ pragma AppId user.local.139e727b6315
import QtQuick
import Quickshell
import Quickshell.Io
import Blannk.Design 1.0 as Design

ShellRoot {
    id: root
    property bool opened: false
    readonly property int rows: 9
    readonly property int columns: 10
    readonly property int mineCount: 12
    readonly property int tileSize: 36
    property var cells: []
    property int revealedCount: 0
    property int flagCount: 0
    property int elapsedSeconds: 0
    property bool started: false
    property bool gameOver: false
    property bool won: false
    property bool mouseDown: false
    property string gameStatus: "Click a square to begin."

    function recountMines(board) {
        for (var y = 0; y < rows; ++y) {
            for (var x = 0; x < columns; ++x) {
                var at = y * columns + x
                if (board[at].mine) continue
                var count = 0
                for (var dy = -1; dy <= 1; ++dy) {
                    for (var dx = -1; dx <= 1; ++dx) {
                        if (dx === 0 && dy === 0) continue
                        var nx = x + dx
                        var ny = y + dy
                        if (nx >= 0 && nx < columns && ny >= 0 && ny < rows && board[ny * columns + nx].mine)
                            count++
                    }
                }
                board[at].adjacent = count
            }
        }
    }

    function newGame() {
        var board = []
        for (var i = 0; i < rows * columns; ++i)
            board.push({ mine: false, adjacent: 0, revealed: false, flagged: false, exploded: false })
        var placed = 0
        while (placed < mineCount) {
            var pick = Math.floor(Math.random() * board.length)
            if (!board[pick].mine) {
                board[pick].mine = true
                placed++
            }
        }
        recountMines(board)
        cells = board
        revealedCount = 0
        flagCount = 0
        elapsedSeconds = 0
        started = false
        gameOver = false
        won = false
        mouseDown = false
        gameStatus = "Click a square to begin."
    }

    // Traditional beginner-style opening: the first square and its neighbors are safe.
    function makeFirstClickSafe(index) {
        var x = index % columns
        var y = Math.floor(index / columns)
        var board = cells.slice(0)
        var changed = false
        for (var dy = -1; dy <= 1; ++dy) {
            for (var dx = -1; dx <= 1; ++dx) {
                var nx = x + dx
                var ny = y + dy
                if (nx < 0 || nx >= columns || ny < 0 || ny >= rows) continue
                var protectedIndex = ny * columns + nx
                if (!board[protectedIndex].mine) continue
                var destination = -1
                for (var offset = 0; offset < board.length; ++offset) {
                    var candidate = (index + offset) % board.length
                    var cx = candidate % columns
                    var cy = Math.floor(candidate / columns)
                    if (!board[candidate].mine && (Math.abs(cx - x) > 1 || Math.abs(cy - y) > 1)) {
                        destination = candidate
                        break
                    }
                }
                if (destination >= 0) {
                    board[protectedIndex] = Object.assign({}, board[protectedIndex], { mine: false })
                    board[destination] = Object.assign({}, board[destination], { mine: true })
                    changed = true
                }
            }
        }
        if (changed) {
            recountMines(board)
            cells = board
        }
    }

    function toggleFlag(index) {
        if (gameOver || index < 0 || index >= cells.length || cells[index].revealed) return
        var next = cells.slice(0)
        next[index] = Object.assign({}, next[index], { flagged: !next[index].flagged })
        cells = next
        flagCount += next[index].flagged ? 1 : -1
        gameStatus = flagCount === mineCount ? "All mines flagged? Check every square." : "Right-click to flag or unflag a square."
    }

    function revealCell(index) {
        if (gameOver || index < 0 || index >= cells.length || cells[index].flagged) return
        if (cells[index].revealed) {
            chordCell(index)
            return
        }
        if (!started) {
            makeFirstClickSafe(index)
            started = true
        }
        if (cells[index].mine) {
            var lost = cells.slice(0)
            for (var m = 0; m < lost.length; ++m) {
                if (lost[m].mine)
                    lost[m] = Object.assign({}, lost[m], { revealed: true, exploded: m === index })
            }
            cells = lost
            gameOver = true
            gameStatus = "You hit a mine. Press the face to play again."
            return
        }

        // Iterative flood fill reveals connected empty cells and their numbered border.
        var next = cells.slice(0)
        var queue = [index]
        var cursor = 0
        var revealedNow = 0
        while (cursor < queue.length) {
            var current = queue[cursor++]
            if (next[current].revealed || next[current].flagged || next[current].mine) continue
            next[current] = Object.assign({}, next[current], { revealed: true })
            revealedNow++
            if (next[current].adjacent === 0) {
                var cx = current % columns
                var cy = Math.floor(current / columns)
                for (var dy = -1; dy <= 1; ++dy) {
                    for (var dx = -1; dx <= 1; ++dx) {
                        var nx = cx + dx
                        var ny = cy + dy
                        if (nx >= 0 && nx < columns && ny >= 0 && ny < rows) {
                            var neighbor = ny * columns + nx
                            if (!next[neighbor].revealed && !next[neighbor].flagged && !next[neighbor].mine)
                                queue.push(neighbor)
                        }
                    }
                }
            }
        }
        cells = next
        revealedCount += revealedNow
        if (revealedCount === rows * columns - mineCount) {
            won = true
            gameOver = true
            gameStatus = "You cleared the board! Press the face to play again."
        } else {
            gameStatus = "Use the numbers to find the mines."
        }
    }

    function chordCell(index) {
        if (gameOver || !cells[index].revealed || cells[index].adjacent === 0) return
        var x = index % columns
        var y = Math.floor(index / columns)
        var flaggedNeighbors = 0
        var neighbors = []
        for (var dy = -1; dy <= 1; ++dy) {
            for (var dx = -1; dx <= 1; ++dx) {
                if (dx === 0 && dy === 0) continue
                var nx = x + dx
                var ny = y + dy
                if (nx >= 0 && nx < columns && ny >= 0 && ny < rows) {
                    var neighbor = ny * columns + nx
                    if (cells[neighbor].flagged) flaggedNeighbors++
                    else if (!cells[neighbor].revealed) neighbors.push(neighbor)
                }
            }
        }
        if (flaggedNeighbors !== cells[index].adjacent) return
        for (var i = 0; i < neighbors.length && !gameOver; ++i)
            revealCell(neighbors[i])
    }

    function counterText(value) {
        if (value < 0) return "-" + ("0" + Math.abs(value)).slice(-2)
        return ("00" + value).slice(-3)
    }

    function numberColor(value) {
        if (value === 1) return "#0000ff"
        if (value === 2) return "#008000"
        if (value === 3) return "#ff0000"
        if (value === 4) return "#000080"
        if (value === 5) return "#800000"
        if (value === 6) return "#008080"
        if (value === 7) return "#000000"
        return "#808080"
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.started && !root.gameOver && root.elapsedSeconds < 999
        onTriggered: root.elapsedSeconds++
    }

    Component.onCompleted: newGame()

    IpcHandler {
        target: "block"
        function openPanel(): void { root.opened = true }
        function hide(): void { root.opened = false }
        function state(): string { return JSON.stringify({ open: root.opened, status: root.gameStatus }) }
    }

    FloatingWindow {
        visible: root.opened
        title: "BLANNK / MINESWEEPER"
        implicitWidth: 430
        implicitHeight: 470
        color: Design.Tokens.panel
        onVisibleChanged: if (!visible) root.opened = false

        Shortcut {
            sequence: "Escape"
            onActivated: root.opened = false
        }

        Column {
            anchors.centerIn: parent
            width: 376
            spacing: 10

            // Classic counter panel, using BLANNK's semantic panel color as its base.
            Rectangle {
                width: parent.width
                height: 58
                color: Design.Tokens.panel
                border.width: 2
                border.color: "#808080"
                Rectangle { anchors.left: parent.left; anchors.top: parent.top; width: parent.width; height: 2; color: "#ffffff" }
                Rectangle { anchors.left: parent.left; anchors.top: parent.top; width: 2; height: parent.height; color: "#ffffff" }

                Row {
                    anchors.fill: parent
                    anchors.margins: 5
                    spacing: 0

                    Rectangle {
                        width: 74; height: 44
                        anchors.verticalCenter: parent.verticalCenter
                        color: "#000000"
                        border.color: "#707070"; border.width: 1
                        Text {
                            anchors.centerIn: parent
                            text: root.counterText(root.mineCount - root.flagCount)
                            color: "#ff2020"; font.family: "Monospace"; font.pixelSize: 31; font.bold: true
                        }
                    }

                    Item { width: (parent.width - 74 * 2 - 44) / 2; height: 1 }

                    Rectangle {
                        width: 44; height: 44
                        anchors.verticalCenter: parent.verticalCenter
                        color: Design.Tokens.panel
                        border.width: root.mouseDown ? 2 : 3
                        border.color: root.mouseDown ? "#808080" : "#ffffff"
                        Rectangle { anchors.left: parent.left; anchors.top: parent.top; width: parent.width; height: 2; color: root.mouseDown ? "#808080" : "#ffffff" }
                        Rectangle { anchors.left: parent.left; anchors.top: parent.top; width: 2; height: parent.height; color: root.mouseDown ? "#808080" : "#ffffff" }
                        Text {
                            anchors.centerIn: parent
                            text: root.won ? "★" : (root.gameOver ? "☹" : (root.mouseDown ? "😮" : "☺"))
                            color: "#000000"
                            font.family: "Sans Serif"
                            font.pixelSize: root.mouseDown && !root.gameOver && !root.won ? 29 : 34
                            font.bold: true
                        }
                        MouseArea {
                            anchors.fill: parent
                            onPressed: root.mouseDown = true
                            onReleased: root.mouseDown = false
                            onCanceled: root.mouseDown = false
                            onClicked: root.newGame()
                        }
                    }

                    Item { width: (parent.width - 74 * 2 - 44) / 2; height: 1 }

                    Rectangle {
                        width: 74; height: 44
                        anchors.verticalCenter: parent.verticalCenter
                        color: "#000000"
                        border.color: "#707070"; border.width: 1
                        Text {
                            anchors.centerIn: parent
                            text: ("00" + root.elapsedSeconds).slice(-3)
                            color: "#ff2020"; font.family: "Monospace"; font.pixelSize: 31; font.bold: true
                        }
                    }
                }
            }

            // Raised outer frame and individually beveled 36-pixel square cells.
            Rectangle {
                width: parent.width
                height: root.rows * root.tileSize + 16
                color: Design.Tokens.panel
                border.color: "#808080"; border.width: 3
                Rectangle { anchors.left: parent.left; anchors.top: parent.top; width: parent.width; height: 3; color: "#ffffff" }
                Rectangle { anchors.left: parent.left; anchors.top: parent.top; width: 3; height: parent.height; color: "#ffffff" }

                Grid {
                    anchors.centerIn: parent
                    columns: root.columns
                    rows: root.rows
                    spacing: 0

                    Repeater {
                        model: root.cells.length
                        delegate: Rectangle {
                            id: tile
                            required property int index
                            readonly property var cell: root.cells[index] || ({})
                            width: root.tileSize
                            height: root.tileSize
                            color: cell.revealed ? Design.Tokens.panel : Design.Tokens.panel
                            border.width: cell.revealed ? 1 : 0
                            border.color: "#808080"

                            Rectangle { visible: !tile.cell.revealed; anchors.left: parent.left; anchors.top: parent.top; width: parent.width; height: 3; color: "#ffffff" }
                            Rectangle { visible: !tile.cell.revealed; anchors.left: parent.left; anchors.top: parent.top; width: 3; height: parent.height; color: "#ffffff" }
                            Rectangle { visible: !tile.cell.revealed; anchors.right: parent.right; anchors.bottom: parent.bottom; width: 3; height: parent.height; color: "#808080" }
                            Rectangle { visible: !tile.cell.revealed; anchors.right: parent.right; anchors.bottom: parent.bottom; width: parent.width; height: 3; color: "#808080" }

                            Text {
                                anchors.centerIn: parent
                                text: tile.cell.flagged && !tile.cell.revealed ? "⚑"
                                      : (tile.cell.revealed && tile.cell.mine ? "●"
                                      : (tile.cell.revealed && tile.cell.adjacent > 0 ? String(tile.cell.adjacent) : ""))
                                color: tile.cell.exploded ? "#ffffff"
                                       : (tile.cell.exploded ? "#ffffff"
                                       : (tile.cell.mine ? "#000000"
                                       : (tile.cell.flagged ? "#ff0000" : root.numberColor(tile.cell.adjacent))))
                                font.family: "Sans Serif"
                                font.pixelSize: tile.cell.mine ? 23 : 24
                                font.bold: true
                            }

                            MouseArea {
                                anchors.fill: parent
                                enabled: !root.gameOver
                                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                                onPressed: function(mouse) { if (mouse.button === Qt.LeftButton) root.mouseDown = true }
                                onReleased: root.mouseDown = false
                                onCanceled: root.mouseDown = false
                                onClicked: function(mouse) {
                                    root.mouseDown = false
                                    if (mouse.button === Qt.RightButton) root.toggleFlag(tile.index)
                                    else if (mouse.button === Qt.MiddleButton) root.chordCell(tile.index)
                                    else root.revealCell(tile.index)
                                }
                                onDoubleClicked: function(mouse) {
                                    if (mouse.button === Qt.LeftButton) root.chordCell(tile.index)
                                }
                            }
                        }
                    }
                }
            }

            Text {
                width: parent.width
                height: 18
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: root.gameStatus
                color: "#202020"
                font.family: "Sans Serif"
                font.pixelSize: 12
                elide: Text.ElideRight
            }
        }
    }
}
