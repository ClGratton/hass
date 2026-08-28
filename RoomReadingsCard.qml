import QtQuick
import qs.Ui
import qs.Commons
import "BarData.js" as BarData

// Compact, generic environmental summary for one Home Assistant device.
// Classification lives in Model.js; this component only renders the projected
// values and uses the shell's active theme roles for every colour.
Item {
  id: card

  required property var hass
  required property string deviceId
  property QtObject bar: null
  property bool expanded: false
  property bool pinned: false
  property bool rowHovered: false
  property bool showIcon: true
  property bool showPanelPinOnHover: false

  signal expansionRequested()
  signal pinRequested()

  readonly property color fg: bar ? bar.foreground : Color.foreground
  readonly property string family: bar ? bar.fontFamily : Style.font.family
  readonly property color dim: Qt.darker(fg, 1.4)
  readonly property bool pinPreview: card.showPanelPinOnHover
    && card.showIcon && card.rowHovered
  readonly property int barConfigRevision: bar
    && bar.barConfigSerial !== undefined ? bar.barConfigSerial : 0
  readonly property var liveShellConfig: {
    card.barConfigRevision
    return bar && bar.shell ? bar.shell.shellConfig : null
  }
  readonly property var cardData: {
    hass.stateRevision
    hass.pendingToggleRevision
    return hass.roomReadingCard(deviceId)
  }

  function inBar(entry) {
    return BarData.contains(card.liveShellConfig, entry)
  }

  function toggleBar(entry) {
    if (!bar || !bar.shell || typeof bar.shell.mutateShellConfig !== "function") return
    var remove = inBar(entry)
    bar.shell.mutateShellConfig(function(config) {
      if (remove) BarData.remove(config, entry)
      else BarData.add(config, entry)
    })
  }

  width: parent ? parent.width : 0
  implicitHeight: header.implicitHeight
    + (expanded ? Style.spacing.lg + metrics.implicitHeight : 0)

  Item {
    id: header
    width: parent.width
    height: implicitHeight
    anchors.top: parent.top
    implicitHeight: Math.max(glyph.implicitHeight, headerLabels.height,
                             headerActions.implicitHeight)

    Text {
      textFormat: Text.PlainText
      id: glyph
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      visible: card.showIcon
      width: card.showIcon ? implicitWidth : 0
      text: card.cardData.icon
      color: card.fg
      opacity: card.pinPreview ? 0.0 : 1.0
      font.family: card.family
      font.pixelSize: Style.font.heading
    }

    BorderSurface {
      z: 1
      anchors.centerIn: glyph
      width: Math.max(glyph.implicitWidth, Style.space(18))
      height: Style.space(22)
      radius: Style.cornerRadius
      visible: card.pinPreview
      color: card.pinned
        ? Style.selectedFillFor(card.fg, Color.accent)
        : Style.hoverFillFor(card.fg, card.dim)
      borderSpec: card.pinned
        ? Border.controlSpec("selected", card.fg, Color.accent) : Border.none()
    }

    Text {
      textFormat: Text.PlainText
      id: pinGlyph
      z: 2
      anchors.centerIn: glyph
      visible: card.pinPreview
      text: ""                               // Font Awesome thumb tack
      color: card.pinned ? Color.accent : card.dim
      font.family: card.family
      font.pixelSize: Style.font.heading
    }

    MouseArea {
      id: glyphPinMouse
      z: 3
      anchors.centerIn: glyph
      width: Math.max(glyph.implicitWidth, Style.space(22))
      height: Style.space(22)
      enabled: card.showPanelPinOnHover && card.showIcon
      hoverEnabled: true
      cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
      onClicked: card.pinRequested()
    }

    PanelToolTip {
      visible: glyphPinMouse.containsMouse
      text: card.pinned ? "Unpin expanded readings" : "Pin expanded readings"
      fontFamily: card.family
    }

    Column {
      id: headerLabels
      anchors.left: glyph.right
      anchors.leftMargin: card.showIcon ? Style.spacing.xl : 0
      anchors.right: headerActions.left
      anchors.rightMargin: Style.spacing.lg
      anchors.verticalCenter: parent.verticalCenter
      height: name.implicitHeight
        + (areaName.visible ? spacing + areaName.implicitHeight : 0)
      spacing: Style.spacing.xxs

      Text {
        textFormat: Text.PlainText
        id: name
        width: parent.width
        text: card.cardData.name
        color: card.fg
        font.family: card.family
        font.pixelSize: Style.font.body
        elide: Text.ElideRight
      }

      Text {
        textFormat: Text.PlainText
        id: areaName
        width: parent.width
        visible: card.cardData.summary.length > 0
        text: card.cardData.summary
        color: card.dim
        font.family: card.family
        font.pixelSize: Style.font.caption
        elide: Text.ElideRight
      }
    }

    Item {
      id: headerActions
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      width: Style.space(64 + 22 + 32) + Style.spacing.md * 2
      height: Style.space(32)

      Item {
        id: roomPrimarySlot
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: Style.space(64)
        height: Style.space(32)

        ToggleSwitch {
          id: primaryControl
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          visible: card.cardData.controlEntityId.length > 0
          checked: card.cardData.controlOn
          busy: card.cardData.controlPending
          interactive: true
          cursorRing: false
          foreground: card.fg
          onToggled: if (card.cardData.controlEntityId) {
            card.hass.toggleEntity(card.cardData.controlEntityId)
          }
        }
      }

      Item {
        id: roomExpandSlot
        anchors.left: roomPrimarySlot.right
        anchors.leftMargin: Style.spacing.md
        anchors.verticalCenter: parent.verticalCenter
        width: Style.space(22)
        height: Style.space(32)

        PanelActionButton {
          anchors.centerIn: parent
          iconText: card.expanded ? "󰅃" : "󰅀"
          tooltipText: card.expanded ? "Collapse readings" : "Show readings"
          foreground: card.dim
          fontFamily: card.family
          onClicked: card.expansionRequested()
        }
      }

      Item {
        id: roomBarSlot
        readonly property var entry: BarData.roomEntry(card.deviceId)
        readonly property bool added: card.inBar(entry)
        anchors.left: roomExpandSlot.right
        anchors.leftMargin: Style.spacing.md
        anchors.verticalCenter: parent.verticalCenter
        width: Style.space(32)
        height: Style.space(32)

        PanelActionButton {
          anchors.fill: parent
          visible: card.cardData.readings.length >= 2
          opacity: roomBarSlot.added || cardHover.hovered ? 1.0 : 0.0
          size: parent.width
          iconText: roomBarSlot.added ? "󰍴" : "󰐕" // md-minus / md-plus
          tooltipText: roomBarSlot.added
            ? "Remove room readings from the bar" : "Add room readings to the bar"
          foreground: card.fg
          fontFamily: card.family
          onClicked: card.toggleBar(roomBarSlot.entry)
        }
      }
    }
  }

  Grid {
    id: metrics
    width: parent.width
    height: implicitHeight
    anchors.top: header.bottom
    anchors.topMargin: Style.spacing.lg
    visible: card.expanded
    columns: 2
    columnSpacing: Style.spacing.sm
    rowSpacing: Style.spacing.sm

    Repeater {
      model: card.cardData.readings

      delegate: Rectangle {
        id: metric
        required property var modelData
        readonly property var reading: modelData
        readonly property var entry: BarData.entityEntry(reading.entityId)
        readonly property bool added: card.inBar(entry)
        readonly property color qualityColor: {
          switch (reading.quality) {
          case "good": return Color.accent
          case "moderate": return card.fg
          case "poor": return Qt.lighter(Color.urgent, 1.28)
          case "critical": return Color.urgent
          default: return card.dim
          }
        }

        width: Math.floor((metrics.width - Style.spacing.sm) / 2)
        height: metricName.implicitHeight + Style.spacing.xxs
          + metricValue.implicitHeight + Style.spacing.md
        radius: Style.cornerRadius
        color: Style.normalFillFor(card.fg, qualityColor, Color.urgent)

        HoverHandler { id: metricHover }

        Column {
          id: metricLabels
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          anchors.leftMargin: Style.spacing.md
          anchors.rightMargin: Style.spacing.md
          height: metricName.implicitHeight + spacing + metricValue.implicitHeight
          spacing: Style.spacing.xxs

          Text {
            textFormat: Text.PlainText
            id: metricName
            width: parent.width
            text: reading.label
            color: card.dim
            font.family: card.family
            font.pixelSize: Style.font.caption
            elide: Text.ElideRight
          }

          Text {
            textFormat: Text.PlainText
            id: metricValue
            width: parent.width
            text: reading.value
            color: qualityColor
            font.family: card.family
            font.pixelSize: Style.font.body
            font.weight: Font.Medium
            elide: Text.ElideRight
          }
        }

        PanelActionButton {
          anchors.top: parent.top
          anchors.right: parent.right
          anchors.margins: Style.spacing.xxs
          visible: metricHover.hovered
          iconText: metric.added ? "󰍴" : "󰐕"  // md-minus / md-plus
          tooltipText: metric.added
            ? "Remove " + metric.reading.label + " from the bar"
            : "Add " + metric.reading.label + " to the bar"
          foreground: metric.qualityColor
          fontFamily: card.family
          size: Style.space(20)
          onClicked: card.toggleBar(metric.entry)
        }
      }
  }
}
}
