import QtQuick
import qs.Ui
import qs.Commons

// One compact plot in a synchronized history stack. The parent owns the
// shared hover time and vertical cursor; this component owns its scale, line,
// nearest sample marker, and optional bottom time axis.
Item {
  id: root

  required property var points
  required property string label
  property string value: ""
  property string unit: ""
  property color foreground: Color.popups.text
  property color accent: Color.accent
  property string fontFamily: Style.font.family
  property bool loading: false
  property bool includeZero: false
  property bool showTimeAxis: false
  property real plotStart: 0
  property real plotEnd: 0
  property real hoverTime: -1

  readonly property real plotLeft: Style.space(38)
  readonly property real plotRight: Style.space(4)
  readonly property var bounds: {
    var values = root.points || []
    if (!values.length) return ({ min: 0, max: 1 })
    var low = Number(values[0].v)
    var high = low
    for (var i = 1; i < values.length; i++) {
      low = Math.min(low, Number(values[i].v))
      high = Math.max(high, Number(values[i].v))
    }
    if (root.includeZero) low = Math.min(0, low)
    var span = high - low
    if (span <= 0) span = Math.max(1, Math.abs(high) * 0.1)
    var padding = span * 0.04
    return ({ min: root.includeZero && low === 0 ? 0 : low - padding,
              max: high + padding })
  }
  readonly property var hoveredPoint: root.nearestPoint(root.hoverTime)

  implicitHeight: Style.space(showTimeAxis ? 98 : 86)

  function nearestPoint(timestamp) {
    var values = root.points || []
    if (timestamp < 0 || !values.length) return null
    var low = 0
    var high = values.length - 1
    while (low < high) {
      var middle = Math.floor((low + high) / 2)
      if (Number(values[middle].t) < timestamp) low = middle + 1
      else high = middle
    }
    if (low > 0 && Math.abs(Number(values[low - 1].t) - timestamp)
        <= Math.abs(Number(values[low].t) - timestamp)) return values[low - 1]
    return values[low]
  }

  function shortNumber(value) {
    var numeric = Number(value)
    var magnitude = Math.abs(numeric)
    if (magnitude >= 1000) return (numeric / 1000).toFixed(1) + "k"
    if (magnitude >= 100) return String(Math.round(numeric))
    if (magnitude >= 10) return numeric.toFixed(1).replace(/\.0$/, "")
    return numeric.toFixed(2).replace(/0+$/, "").replace(/\.$/, "")
  }

  function hoveredValue() {
    if (!root.hoveredPoint) return root.value
    return root.shortNumber(root.hoveredPoint.v)
      + (root.unit ? " " + root.unit : "")
  }

  Text {
    id: title
    textFormat: Text.PlainText
    anchors.left: parent.left
    anchors.top: parent.top
    text: root.label
    color: Qt.darker(root.foreground, 1.28)
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    elide: Text.ElideRight
  }

  Text {
    textFormat: Text.PlainText
    anchors.right: parent.right
    anchors.top: parent.top
    text: root.hoveredValue()
    color: root.hoveredPoint ? root.accent : root.foreground
    font.family: root.fontFamily
    font.pixelSize: Style.font.bodySmall
    font.weight: Font.Medium
  }

  Item {
    id: plot
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: title.bottom
    anchors.topMargin: Style.spacing.xs
    anchors.bottom: root.showTimeAxis ? timeStart.top : parent.bottom
    anchors.bottomMargin: root.showTimeAxis ? Style.spacing.xs : 0

    Text {
      textFormat: Text.PlainText
      width: root.plotLeft - Style.spacing.xs
      anchors.left: parent.left
      anchors.top: parent.top
      text: root.shortNumber(root.bounds.max)
      color: Qt.darker(root.foreground, 1.55)
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      horizontalAlignment: Text.AlignRight
    }

    Text {
      textFormat: Text.PlainText
      width: root.plotLeft - Style.spacing.xs
      anchors.left: parent.left
      anchors.bottom: parent.bottom
      text: root.shortNumber(root.bounds.min)
      color: Qt.darker(root.foreground, 1.55)
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      horizontalAlignment: Text.AlignRight
    }

    Canvas {
      id: chart
      anchors.left: parent.left
      anchors.leftMargin: root.plotLeft
      anchors.right: parent.right
      anchors.rightMargin: root.plotRight
      anchors.top: parent.top
      anchors.bottom: parent.bottom

      onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        ctx.lineWidth = 1
        ctx.strokeStyle = Qt.rgba(root.foreground.r, root.foreground.g,
                                  root.foreground.b, 0.12)
        ctx.beginPath()
        ctx.moveTo(0, height - 0.5)
        ctx.lineTo(width, height - 0.5)
        ctx.stroke()

        var values = root.points || []
        if (values.length < 2) return
        var minTime = root.plotStart || Number(values[0].t)
        var maxTime = root.plotEnd || Number(values[values.length - 1].t)
        var timeSpan = Math.max(1, maxTime - minTime)
        var valueSpan = Math.max(0.000001, root.bounds.max - root.bounds.min)
        var pad = Style.space(2)
        ctx.lineWidth = Math.max(1.5, Style.space(1.5))
        ctx.lineJoin = "round"
        ctx.lineCap = "round"
        ctx.strokeStyle = root.accent
        ctx.beginPath()
        for (var point = 0; point < values.length; point++) {
          var x = (Number(values[point].t) - minTime) / timeSpan * width
          var y = pad + (root.bounds.max - Number(values[point].v)) / valueSpan
            * Math.max(1, height - pad * 2)
          if (point === 0) ctx.moveTo(x, y)
          else ctx.lineTo(x, y)
        }
        ctx.stroke()

        if (root.hoveredPoint) {
          var hoverX = (Number(root.hoveredPoint.t) - minTime) / timeSpan * width
          var hoverY = pad + (root.bounds.max - Number(root.hoveredPoint.v))
            / valueSpan * Math.max(1, height - pad * 2)
          ctx.fillStyle = root.accent
          ctx.beginPath()
          ctx.arc(hoverX, hoverY, Style.space(3), 0, Math.PI * 2)
          ctx.fill()
        }
      }

      Connections {
        target: root
        function onPointsChanged() { chart.requestPaint() }
        function onBoundsChanged() { chart.requestPaint() }
        function onWidthChanged() { chart.requestPaint() }
        function onHeightChanged() { chart.requestPaint() }
        function onAccentChanged() { chart.requestPaint() }
        function onForegroundChanged() { chart.requestPaint() }
        function onHoverTimeChanged() { chart.requestPaint() }
        function onPlotStartChanged() { chart.requestPaint() }
        function onPlotEndChanged() { chart.requestPaint() }
      }
    }
  }

  Text {
    id: timeStart
    textFormat: Text.PlainText
    visible: root.showTimeAxis
    anchors.left: parent.left
    anchors.leftMargin: root.plotLeft
    anchors.bottom: parent.bottom
    text: "24h ago"
    color: Qt.darker(root.foreground, 1.45)
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
  }

  Text {
    textFormat: Text.PlainText
    visible: root.showTimeAxis
    x: root.plotLeft + (root.width - root.plotLeft - root.plotRight) / 2
      - implicitWidth / 2
    anchors.bottom: parent.bottom
    text: "12h ago"
    color: Qt.darker(root.foreground, 1.55)
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
  }

  Text {
    textFormat: Text.PlainText
    visible: root.showTimeAxis
    anchors.right: parent.right
    anchors.rightMargin: root.plotRight
    anchors.bottom: parent.bottom
    text: root.loading ? "Loading…" : "Now"
    color: Qt.darker(root.foreground, 1.45)
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
  }
}
