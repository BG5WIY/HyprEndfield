import QtQuick

// bar 的图标集合（左侧小图标和右侧徽章共用），按 profile 画不同图形。
Item {
    id: glyph
    property string glyphKey: "cpu"
    property color color: "#141313"

    Canvas {
        anchors.fill: parent
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const scale = width / 32
            ctx.scale(scale, scale)
            ctx.fillStyle = glyph.color
            ctx.strokeStyle = glyph.color
            ctx.lineWidth = 2
            ctx.lineCap = "round"
            const c = 16
            switch (glyph.glyphKey) {
case "cpu":
    ctx.fillRect(10, 10, 12, 12)
    ctx.beginPath()
    for (let i = 0; i < 3; ++i) {
        const p = 11 + i * 5
        ctx.moveTo(p, 10); ctx.lineTo(p, 5)
        ctx.moveTo(p, 22); ctx.lineTo(p, 27)
        ctx.moveTo(10, p); ctx.lineTo(5, p)
        ctx.moveTo(22, p); ctx.lineTo(27, p)
    }
    ctx.stroke()
    break
case "memory":
    ctx.strokeRect(6, 11, 20, 10)
    ctx.fillRect(8, 13, 2, 6)
    ctx.fillRect(12, 13, 2, 6)
    ctx.fillRect(16, 13, 2, 6)
    ctx.fillRect(20, 13, 2, 6)
    break
case "battery":
    ctx.strokeRect(6, 10, 16, 12)
    ctx.fillRect(22, 14, 2, 4)
    ctx.fillRect(9, 13, 8, 6)
    break
case "network":
    ctx.beginPath()
    ctx.arc(c, 24, 9, Math.PI * 1.15, Math.PI * 1.85)
    ctx.stroke()
    ctx.beginPath()
    ctx.arc(c, 24, 14, Math.PI * 1.2, Math.PI * 1.8)
    ctx.stroke()
    ctx.beginPath()
    ctx.arc(c, 24, 19, Math.PI * 1.25, Math.PI * 1.75)
    ctx.stroke()
    ctx.fillRect(c - 1.5, 12, 3, 3)
    break
case "gpu":
    ctx.strokeRect(7, 10, 18, 12)
    ctx.fillRect(11, 14, 6, 4)
    ctx.fillRect(19, 14, 3, 4)
    ctx.beginPath()
    ctx.moveTo(10, 22); ctx.lineTo(10, 26)
    ctx.moveTo(16, 22); ctx.lineTo(16, 26)
    ctx.moveTo(22, 22); ctx.lineTo(22, 26)
    ctx.stroke()
    break
case "disk":
    ctx.strokeRect(6, 9, 20, 14)
    ctx.fillRect(9, 12, 14, 3)
    ctx.beginPath()
    ctx.arc(21, 20, 1.6, 0, Math.PI * 2)
    ctx.fill()
    break
case "download":
    ctx.beginPath()
    ctx.moveTo(16, 6); ctx.lineTo(16, 20)
    ctx.moveTo(10, 14); ctx.lineTo(16, 20); ctx.lineTo(22, 14)
    ctx.stroke()
    ctx.fillRect(9, 24, 14, 2)
    break
case "upload":
    ctx.beginPath()
    ctx.moveTo(16, 20); ctx.lineTo(16, 6)
    ctx.moveTo(10, 12); ctx.lineTo(16, 6); ctx.lineTo(22, 12)
    ctx.stroke()
    ctx.fillRect(9, 24, 14, 2)
    break
case "time":
    ctx.beginPath()
    ctx.arc(c, c, 11, 0, Math.PI * 2)
    ctx.stroke()
    ctx.beginPath()
    ctx.moveTo(c, c); ctx.lineTo(c, c - 6)
    ctx.moveTo(c, c); ctx.lineTo(c + 5, c + 2)
    ctx.stroke()
    break
default:
    ctx.beginPath()
    ctx.moveTo(19, 6); ctx.lineTo(10, 18); ctx.lineTo(15, 18)
    ctx.lineTo(12, 27); ctx.lineTo(23, 14); ctx.lineTo(17, 14)
    ctx.closePath(); ctx.fill()
}
        }
    }
    onGlyphKeyChanged: requestPaint()
    onColorChanged: requestPaint()
}
