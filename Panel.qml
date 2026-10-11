import QtQuick
import QtQuick.Controls as QQC
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Three CLI-backed surfaces: Libraries, Compose/Share, and Applied Loadouts.
Panel {
  id: root
  moduleName: "tombychowski.montage"
  ipcTarget: "tombychowski.montage"
  manageIpc: false

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color accent: Color.accent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property color stateColor: Model.attentionTone(engine.attention) === "healthy" ? foreground
    : Model.attentionTone(engine.attention) === "active" ? accent : urgent

  property string tab: "libraries"
  property int cursor: 0
  property bool cursorActive: false
  property string notice: ""
  property string selectedAppliedId: ""

  property string libraryName: "personal"
  property string libraryPath: engine.home + "/.local/share/montage/loadouts"
  property string libraryRemote: ""
  property string ressSource: ""
  property string ressLoadoutId: "imported-ress"
  property string ressPluginDecision: "omit"
  property string montagePluginDecision: "omit"

  property string shareStage: "choose"
  property var shareSelection: ({})
  property var shareAcknowledgements: ({})
  property string shareName: "My Montage loadout"
  property string shareDescription: ""
  property string shareKind: "package"
  property string shareSearch: ""
  property string sharePresetNotice: ""
  readonly property var sharePresets: engine.shareCatalog ? engine.shareCatalog.presets.loadouts : []

  readonly property var tabs: ["libraries", "compose", "applied"]
  readonly property var rows: {
    var out = []
    if (tab === "libraries") {
      var repositories = engine.repositories ? engine.repositories.repositories : []
      for (var i = 0; i < repositories.length; i++)
        out.push({ id: "library:" + repositories[i].name, label: repositories[i].name })
      if (engine.selectedRepositoryName !== "") {
        out.push({ id: "sync-preview", label: "Check synchronization" })
        if (engine.syncPreview) out.push({ id: "sync-terminal", label: "Continue synchronization" })
        var items = engine.repositoryLoadouts ? engine.repositoryLoadouts.items : []
        for (var j = 0; j < items.length; j++)
          out.push({ id: "library-loadout:" + items[j].id, label: items[j].name })
        if (engine.selectedRepositoryLoadoutId !== "") {
          out.push({ id: "library-apply-preview", label: "Preview selected loadout" })
          out.push({ id: "library-apply", label: "Apply selected loadout" })
          out.push({ id: "library-compose", label: "Compose from selected loadout" })
        }
      }
      out.push({ id: "library-name", label: "Library name" })
      out.push({ id: "library-path", label: "Library path" })
      out.push({ id: "library-remote", label: "Library remote" })
      out.push({ id: "library-save", label: "Configure library" })
      out.push({ id: "ress-source", label: "Ress v1 source" })
      out.push({ id: "ress-loadout", label: "Imported loadout id" })
      out.push({ id: "ress-plugin", label: "Ress plugin decision" })
      out.push({ id: "montage-plugin", label: "Montage plugin decision" })
      out.push({ id: "ress-preview", label: "Inspect Ress loadout" })
      if (engine.ressPreview && engine.ressPreview.ready)
        out.push({ id: "ress-import", label: "Import Ress loadout" })
      return out
    }
    if (tab === "compose") {
      if (shareStage === "choose") {
        out.push({ id: "share-all", label: "All shareable resources" })
        out.push({ id: "share-current", label: "Current selection" })
        out.push({ id: "share-empty", label: "Empty selection" })
        for (var p = 0; p < sharePresets.length; p++)
          out.push({ id: "share-start:" + sharePresets[p].id, label: sharePresets[p].name })
      } else {
        out.push({ id: "share-name", label: "Loadout name" })
        out.push({ id: "share-description", label: "Description" })
        for (var q = 0; q < sharePresets.length; q++)
          out.push({ id: "share-add:" + sharePresets[q].id, label: sharePresets[q].name })
        for (var k = 0; k < Model.SHARE_KINDS.length; k++)
          out.push({ id: "share-kind:" + Model.SHARE_KINDS[k], label: Model.SHARE_KINDS[k] })
        out.push({ id: "share-search", label: "Search" })
        var resources = Model.filterShareResources(engine.shareCatalog, shareKind, shareSearch, 200)
        for (var r = 0; r < resources.length; r++)
          out.push({ id: "share-resource:" + resources[r].id, label: resources[r].name })
        var unavailable = engine.shareCatalog ? engine.shareCatalog.currentItem.unavailable : []
        for (var u = 0; u < unavailable.length; u++)
          out.push({ id: "share-ack:" + unavailable[u].id, label: unavailable[u].name })
        out.push({ id: "share-publish", label: "Publish loadout" })
        out.push({ id: "share-back", label: "Choose another start" })
      }
      return out
    }
    var applied = engine.loadouts || []
    for (var a = 0; a < applied.length; a++)
      out.push({ id: "applied:" + applied[a].id, label: applied[a].name })
    if (selectedAppliedId !== "") {
      out.push({ id: "applied-update", label: "Update" })
      out.push({ id: "applied-repair", label: "Repair" })
      out.push({ id: "applied-remove", label: "Remove" })
    }
    out.push({ id: "aur-policy", label: "AUR policy" })
    return out
  }

  readonly property string currentRowId: cursorActive && cursor >= 0 && cursor < rows.length
    ? rows[cursor].id : ""
  function hasCursor(id) { return currentRowId === id }

  function selectedRepository() {
    var values = engine.repositories ? engine.repositories.repositories : []
    for (var i = 0; i < values.length; i++)
      if (values[i].name === engine.selectedRepositoryName) return values[i]
    return null
  }

  function selectedLibraryLoadout() {
    var values = engine.repositoryLoadouts ? engine.repositoryLoadouts.items : []
    for (var i = 0; i < values.length; i++)
      if (values[i].id === engine.selectedRepositoryLoadoutId) return values[i]
    return null
  }

  function selectedApplied() {
    var values = engine.loadouts || []
    for (var i = 0; i < values.length; i++)
      if (values[i].id === selectedAppliedId) return values[i]
    return null
  }

  function setTab(name) {
    tab = name
    cursor = 0
    cursorActive = false
    if (name === "compose") engine.refreshShareCatalog()
  }

  function moveCursor(dx, dy) {
    cursorActive = true
    if (dx !== 0) {
      var index = tabs.indexOf(tab) + dx
      if (index < 0) index = tabs.length - 1
      if (index >= tabs.length) index = 0
      setTab(tabs[index])
      return
    }
    if (rows.length > 0) cursor = (cursor + dy + rows.length) % rows.length
  }

  function beginShare(source, presetId) {
    if (!engine.shareCatalogAvailable) { flash("Select a library loadout first"); return }
    if (source === "current" && engine.shareCatalog.currentItem.state !== "valid") {
      flash("The current library item is unavailable"); return
    }
    shareSelection = Model.shareSelection(engine.shareCatalog, source, presetId || "")
    sharePresetNotice = ""
    if (source === "preset") describePreset(presetId)
    shareAcknowledgements = ({})
    shareName = engine.shareCatalog.currentItem.name || "My Montage loadout"
    shareDescription = engine.shareCatalog.currentItem.description || ""
    shareStage = "compose"
    cursor = 0
  }

  function describePreset(id) {
    var preset = Model.sharePresetById(engine.shareCatalog, id)
    if (!preset) return
    var skipped = []
    for (var i = 0; i < preset.warnings.length; i++)
      skipped.push(preset.warnings[i].id + " (" + preset.warnings[i].state + ")")
    sharePresetNotice = skipped.length ? "Not selected: " + skipped.join(", ") : ""
  }

  function addPreset(id) {
    var result = Model.addSharePreset(engine.shareCatalog, shareSelection, id)
    shareSelection = result.selection
    describePreset(id)
    if (result.themeConflict !== "")
      sharePresetNotice += (sharePresetNotice ? "; " : "") +
        "Kept your selected theme; conflicting preset theme: " + result.themeConflict
  }

  function nextDecision(value) { return value === "omit" ? "include" : "omit" }
  function nextAur(value) { return value === "ask" ? "yes" : (value === "yes" ? "no" : "ask") }
  function flash(message) { notice = message; noticeTimer.restart() }

  function trigger(id) {
    if (id === "library-name") { libraryNameField.forceActiveFocus(); return }
    if (id === "library-path") { libraryPathField.forceActiveFocus(); return }
    if (id === "library-remote") { libraryRemoteField.forceActiveFocus(); return }
    if (id === "ress-source") { ressSourceField.forceActiveFocus(); return }
    if (id === "ress-loadout") { ressLoadoutField.forceActiveFocus(); return }
    if (id === "share-name") { shareNameField.forceActiveFocus(); return }
    if (id === "share-description") { shareDescriptionField.forceActiveFocus(); return }
    if (id === "share-search") { shareSearchField.forceActiveFocus(); return }
    if (id.indexOf("library:") === 0) {
      var name = id.substring(8), values = engine.repositories ? engine.repositories.repositories : []
      for (var i = 0; i < values.length; i++) if (values[i].name === name) {
        engine.selectRepository(values[i].name, values[i].path, values[i].id, values[i].remote)
        break
      }
    } else if (id.indexOf("library-loadout:") === 0) {
      engine.selectRepositoryLoadout(id.substring(16))
    } else if (id === "sync-preview") {
      engine.previewSync(engine.selectedRepositoryName)
    } else if (id === "sync-terminal") {
      var action = engine.syncPreview && engine.syncPreview.status === "remote-ahead" ? "pull"
        : (engine.syncPreview && engine.syncPreview.status === "local-ahead" ? "push" : "preview")
      engine.openSync(engine.selectedRepositoryName, action)
      close()
    } else if (id === "library-apply-preview" || id === "library-apply") {
      engine.openRepositoryApply(engine.selectedRepositoryName,
        engine.selectedRepositoryLoadoutId, id === "library-apply-preview")
      close()
    } else if (id === "library-compose") {
      setTab("compose")
      engine.refreshShareCatalog()
    } else if (id === "library-save") {
      engine.openRepositoryConfigure(libraryName, libraryPath, libraryRemote, false)
      close()
    } else if (id === "ress-plugin") {
      ressPluginDecision = nextDecision(ressPluginDecision)
    } else if (id === "montage-plugin") {
      montagePluginDecision = nextDecision(montagePluginDecision)
    } else if (id === "ress-preview") {
      engine.previewRess(ressSource, ressPluginDecision, montagePluginDecision)
    } else if (id === "ress-import") {
      engine.openRessImport(ressSource, engine.selectedRepositoryName, ressLoadoutId,
        ressPluginDecision, montagePluginDecision)
      close()
    } else if (id === "share-all") beginShare("all")
    else if (id === "share-current") beginShare("current")
    else if (id === "share-empty") beginShare("empty")
    else if (id.indexOf("share-start:") === 0) beginShare("preset", id.substring(12))
    else if (id.indexOf("share-add:") === 0) addPreset(id.substring(10))
    else if (id.indexOf("share-kind:") === 0) shareKind = id.substring(11)
    else if (id.indexOf("share-resource:") === 0)
      shareSelection = Model.toggleShareResource(engine.shareCatalog, shareSelection, id.substring(15))
    else if (id.indexOf("share-ack:") === 0) {
      var resourceId = id.substring(10), next = {}
      for (var key in shareAcknowledgements) next[key] = shareAcknowledgements[key]
      var unavailable = engine.shareCatalog.currentItem.unavailable
      for (var u = 0; u < unavailable.length; u++) if (unavailable[u].id === resourceId) {
        if (next[resourceId] === unavailable[u].fingerprint) delete next[resourceId]
        else next[resourceId] = unavailable[u].fingerprint
      }
      shareAcknowledgements = next
    } else if (id === "share-publish") {
      if (Model.selectedShareIds(shareSelection).length === 0) { flash("Choose at least one resource"); return }
      if (Model.unacknowledgedShareResources(engine.shareCatalog, shareAcknowledgements).length > 0) {
        flash("Acknowledge unavailable resources first"); return
      }
      engine.shareCustom(engine.selectedRepositoryName, engine.selectedRepositoryLoadoutId,
        shareName, shareDescription, Model.selectedShareIds(shareSelection), shareAcknowledgements)
    } else if (id === "share-back") {
      shareStage = "choose"
    } else if (id.indexOf("applied:") === 0) selectedAppliedId = id.substring(8)
    else if (id === "applied-update") { engine.openLoadoutAction("update", selectedAppliedId); close() }
    else if (id === "applied-repair") { engine.openLoadoutAction("repair", selectedAppliedId); close() }
    else if (id === "applied-remove") { engine.openLoadoutAction("remove", selectedAppliedId); close() }
    else if (id === "aur-policy") engine.setAur(nextAur(engine.aurMode))
  }

  function activate() { if (currentRowId !== "") trigger(currentRowId) }
  function switchPanel(direction) { moveCursor(direction, 0) }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight
  onOpenedChanged: if (opened) {
    cursor = 0
    cursorActive = false
    engine.refresh()
    if (tab === "compose") engine.refreshShareCatalog()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  Service {
    id: engine
    uiActive: root.opened
    onFinished: function(action, state) {
      root.flash(state === "ok" ? "Loadout publication complete" : action + " needs attention")
    }
  }
  Timer { id: noticeTimer; interval: 3200; onTriggered: root.notice = "" }

  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
    function openTab(name: string): string {
      if (root.tabs.indexOf(name) < 0) return "unknown tab: " + name
      root.setTab(name); root.open(); return "ok"
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    iconComponent: Component {
      Item {
        Text {
          anchors.centerIn: parent
          text: engine.attention === "operation-active" ? "󰔟" : "󰘬"
          color: root.stateColor
          font.family: root.fontFamily
          font.pixelSize: Style.bar.iconFont
          property real pulse: 1.0
          opacity: engine.attention === "operation-active" ? pulse : 1.0
          SequentialAnimation on pulse {
            running: engine.attention === "operation-active"
            loops: Animation.Infinite
            NumberAnimation { to: 0.35; duration: 700 }
            NumberAnimation { to: 1.0; duration: 700 }
          }
        }
      }
    }
    onPressed: function(buttonCode) { root.toggle() }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(420))
    contentHeight: panel.fittedContentHeight(content.implicitHeight, Style.space(650))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: libraryNameField.activeFocus || libraryPathField.activeFocus ||
        libraryRemoteField.activeFocus || ressSourceField.activeFocus ||
        ressLoadoutField.activeFocus || shareNameField.activeFocus ||
        shareDescriptionField.activeFocus || shareSearchField.activeFocus
      onMoveRequested: function(dx, dy) { root.moveCursor(dx, dy) }
      onActivateRequested: root.activate()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) {
        var key = String(t).toLowerCase()
        if (key === "l") root.setTab("libraries")
        else if (key === "c" || key === "s") root.setTab("compose")
        else if (key === "a") root.setTab("applied")
      }

      Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: content.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        QQC.ScrollBar.vertical: QQC.ScrollBar { policy: QQC.ScrollBar.AsNeeded }

        Column {
          id: content
          width: parent.width
          spacing: Style.space(12)

          PanelHero {
            width: parent.width
            title: "Montage"
            meta: Model.attentionLabel(engine.attention)
            foreground: root.foreground
            fontFamily: root.fontFamily
            iconComponent: Component {
              Text { text: "󰘬"; color: root.stateColor; font.family: root.fontFamily; font.pixelSize: Style.font.display }
            }
          }

          Text {
            visible: root.notice !== "" || engine.lastError !== ""
            width: parent.width
            text: engine.lastError !== "" ? engine.lastError : root.notice
            color: engine.lastError !== "" ? root.urgent : root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
          }

          Row {
            width: parent.width
            spacing: Style.space(6)
            Repeater { model: root.tabs; TabChip { required property var modelData; tabId: modelData } }
          }
          PanelSeparator { foreground: root.foreground }

          // ------------------------------------------------ Libraries
          Column {
            visible: root.tab === "libraries"
            width: parent.width
            spacing: Style.space(8)

            Text {
              width: parent.width
              text: "Libraries hold stable portable loadouts. Synchronization previews fetch explicitly; decisions continue in a terminal."
              color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall
              wrapMode: Text.WordWrap
            }
            Text {
              visible: !engine.repositoriesAvailable
              width: parent.width
              text: engine.loadingRepositories ? "Loading libraries…" : "Library information is unavailable; no state was inferred."
              color: engine.loadingRepositories ? root.dim : root.urgent
              font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall
            }
            Repeater {
              model: engine.repositories ? engine.repositories.repositories : []
              ActionRow {
                required property var modelData
                width: parent.width; rowId: "library:" + modelData.name; glyph: modelData.valid ? "󰘬" : ""
                title: modelData.name; subtitle: modelData.status + " · " + modelData.id
                primary: engine.selectedRepositoryName === modelData.name
              }
            }

            Column {
              visible: engine.selectedRepositoryName !== ""
              width: parent.width; spacing: Style.space(6)
              ActionRow {
                width: parent.width; rowId: "sync-preview"; glyph: ""
                title: engine.loadingSyncPreview ? "Checking synchronization…" : "Check synchronization"
                subtitle: engine.syncPreview ? engine.syncPreview.status + " · ahead " + engine.syncPreview.ahead +
                  " · behind " + engine.syncPreview.behind : "explicit network preview"
              }
              ActionRow {
                visible: engine.syncPreview !== null
                width: parent.width; rowId: "sync-terminal"; glyph: ""
                title: engine.syncPreview && engine.syncPreview.status === "divergent"
                  ? "Review divergence in terminal" : "Continue synchronization in terminal"
                subtitle: "Montage never forces history resolution"
              }
              PanelSectionHeader { text: "LIBRARY LOADOUTS"; foreground: root.foreground; fontFamily: root.fontFamily }
              Repeater {
                model: engine.repositoryLoadouts ? engine.repositoryLoadouts.items : []
                ActionRow {
                  required property var modelData
                  width: parent.width; rowId: "library-loadout:" + modelData.id
                  glyph: engine.selectedRepositoryLoadoutId === modelData.id ? "" : "○"
                  title: modelData.name; subtitle: modelData.id + " · " + modelData.author
                  primary: engine.selectedRepositoryLoadoutId === modelData.id
                }
              }
              ActionRow { visible: engine.selectedRepositoryLoadoutId !== ""; width: parent.width; rowId: "library-apply-preview"; glyph: ""; title: "Preview selected loadout"; subtitle: "review without changing this machine" }
              ActionRow { visible: engine.selectedRepositoryLoadoutId !== ""; width: parent.width; rowId: "library-apply"; glyph: ""; title: "Apply selected loadout"; subtitle: "confirmation and AUR consent stay visible" }
              ActionRow { visible: engine.selectedRepositoryLoadoutId !== ""; width: parent.width; rowId: "library-compose"; glyph: ""; title: "Compose from selected loadout"; subtitle: "open the Compose/Share surface" }
            }

            PanelSeparator { foreground: root.foreground }
            PanelSectionHeader { text: "CONFIGURE LIBRARY"; foreground: root.foreground; fontFamily: root.fontFamily }
            TextField { id: libraryNameField; width: parent.width; placeholderText: "Stable library name"; text: root.libraryName; foreground: root.foreground; font.family: root.fontFamily; hasCursor: root.hasCursor("library-name"); onTextChanged: root.libraryName = text; onAccepted: keyCatcher.forceActiveFocus(); Keys.onEscapePressed: keyCatcher.forceActiveFocus() }
            TextField { id: libraryPathField; width: parent.width; placeholderText: "Absolute local path"; text: root.libraryPath; foreground: root.foreground; font.family: root.fontFamily; hasCursor: root.hasCursor("library-path"); onTextChanged: root.libraryPath = text; onAccepted: keyCatcher.forceActiveFocus(); Keys.onEscapePressed: keyCatcher.forceActiveFocus() }
            TextField { id: libraryRemoteField; width: parent.width; placeholderText: "Credential-free remote (optional)"; text: root.libraryRemote; foreground: root.foreground; font.family: root.fontFamily; hasCursor: root.hasCursor("library-remote"); onTextChanged: root.libraryRemote = text; onAccepted: keyCatcher.forceActiveFocus(); Keys.onEscapePressed: keyCatcher.forceActiveFocus() }
            ActionRow { width: parent.width; rowId: "library-save"; glyph: ""; title: "Configure library"; subtitle: "opens the authoritative CLI in a terminal" }

            PanelSeparator { foreground: root.foreground }
            PanelSectionHeader { text: "RESS V1 LOADOUT MIGRATION"; foreground: root.foreground; fontFamily: root.fontFamily }
            Text {
              width: parent.width
              text: "Ress is a read-only source. Inspect one portable profile, review losses, then publish one new Montage library item in a terminal."
              color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap
            }
            TextField { id: ressSourceField; width: parent.width; placeholderText: "Ress v1 profile or directory"; text: root.ressSource; foreground: root.foreground; font.family: root.fontFamily; hasCursor: root.hasCursor("ress-source"); onTextChanged: root.ressSource = text; onAccepted: keyCatcher.forceActiveFocus(); Keys.onEscapePressed: keyCatcher.forceActiveFocus() }
            TextField { id: ressLoadoutField; width: parent.width; placeholderText: "New stable loadout id"; text: root.ressLoadoutId; foreground: root.foreground; font.family: root.fontFamily; hasCursor: root.hasCursor("ress-loadout"); onTextChanged: root.ressLoadoutId = text; onAccepted: keyCatcher.forceActiveFocus(); Keys.onEscapePressed: keyCatcher.forceActiveFocus() }
            ActionRow { width: parent.width; rowId: "ress-plugin"; glyph: "󰏗"; title: "Ress plugin entry"; subtitle: root.ressPluginDecision }
            ActionRow { width: parent.width; rowId: "montage-plugin"; glyph: "󰏗"; title: "Montage plugin entry"; subtitle: root.montagePluginDecision }
            ActionRow { width: parent.width; rowId: "ress-preview"; glyph: ""; title: engine.loadingRessPreview ? "Inspecting Ress loadout…" : "Inspect Ress loadout"; subtitle: "read-only compatibility and loss report" }
            Text {
              visible: engine.ressPreview !== null
              width: parent.width
              text: engine.ressPreview ? (engine.ressPreview.compatible
                ? (engine.ressPreview.losses.length + " migration decision(s) · " + (engine.ressPreview.ready ? "ready" : "needs decisions"))
                : "Migration refused: " + engine.ressPreview.reason) : ""
              color: engine.ressPreview && engine.ressPreview.ready ? root.foreground : root.urgent
              font.family: root.fontFamily; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap
            }
            ActionRow { visible: engine.ressPreview && engine.ressPreview.ready; width: parent.width; rowId: "ress-import"; glyph: ""; title: "Import Ress loadout in terminal"; subtitle: "publication still requires confirmation" }
          }

          // ---------------------------------------------- Compose / Share
          Column {
            visible: root.tab === "compose"
            width: parent.width
            spacing: Style.space(8)
            Text {
              width: parent.width
              text: engine.selectedRepositoryLoadoutId === ""
                ? "Select a library loadout first. Composition always publishes one explicit stable item."
                : "Compose " + engine.selectedRepositoryLoadoutId + " from current machine resources."
              color: engine.selectedRepositoryLoadoutId === "" ? root.urgent : root.dim
              font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall; wrapMode: Text.WordWrap
            }
            Text {
              visible: engine.loadingShareCatalog
              width: parent.width; text: "Reading shareable resources…"; color: root.dim
              font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall
            }
            Column {
              visible: engine.shareCatalogAvailable && root.shareStage === "choose"
              width: parent.width; spacing: Style.space(6)
              ActionRow { width: parent.width; rowId: "share-all"; glyph: ""; title: "All shareable resources"; subtitle: "start from this machine's complete safe catalog" }
              ActionRow { width: parent.width; rowId: "share-current"; glyph: ""; title: "Current library item"; actionable: engine.shareCatalog && engine.shareCatalog.currentItem.state === "valid"; subtitle: actionable ? "start from the item's current selection" : "current item is absent or unavailable" }
              ActionRow { width: parent.width; rowId: "share-empty"; glyph: "○"; title: "Empty selection"; subtitle: "choose every resource explicitly" }
              Repeater {
                model: root.sharePresets
                ActionRow {
                  required property var modelData
                  width: parent.width; rowId: "share-start:" + modelData.id
                  glyph: ""; title: "Start from " + modelData.name
                  subtitle: Model.plural(modelData.resourceIds.length, "eligible resource") +
                    " · " + Model.plural(modelData.warnings.length, "unavailable resource")
                }
              }
              Text {
                visible: engine.shareCatalog && (engine.shareCatalog.presets.state !== "valid" || root.sharePresets.length === 0)
                width: parent.width; text: "Applied loadout starting choices are absent or unavailable."
                color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption
                wrapMode: Text.WordWrap
              }
            }
            Column {
              visible: engine.shareCatalogAvailable && root.shareStage === "compose"
              width: parent.width; spacing: Style.space(7)
              TextField { id: shareNameField; width: parent.width; placeholderText: "Loadout name"; text: root.shareName; foreground: root.foreground; font.family: root.fontFamily; hasCursor: root.hasCursor("share-name"); onTextChanged: root.shareName = text; onAccepted: keyCatcher.forceActiveFocus(); Keys.onEscapePressed: keyCatcher.forceActiveFocus() }
              TextField { id: shareDescriptionField; width: parent.width; placeholderText: "Description (optional)"; text: root.shareDescription; foreground: root.foreground; font.family: root.fontFamily; hasCursor: root.hasCursor("share-description"); onTextChanged: root.shareDescription = text; onAccepted: keyCatcher.forceActiveFocus(); Keys.onEscapePressed: keyCatcher.forceActiveFocus() }
              Repeater {
                model: root.sharePresets
                ActionRow {
                  required property var modelData
                  width: parent.width; rowId: "share-add:" + modelData.id
                  glyph: "+"; title: "Add " + modelData.name
                  subtitle: "keep current selections and add eligible resources"
                }
              }
              Text {
                visible: root.sharePresetNotice !== ""
                width: parent.width; text: root.sharePresetNotice
                color: root.urgent; font.family: root.fontFamily; font.pixelSize: Style.font.caption
                wrapMode: Text.WordWrap
              }
              Row {
                width: parent.width; spacing: Style.space(5)
                Repeater {
                  model: Model.SHARE_KINDS
                  TabChip { required property var modelData; tabId: "share-kind:" + modelData; label: modelData; selectedOverride: root.shareKind === modelData }
                }
              }
              TextField { id: shareSearchField; width: parent.width; placeholderText: "Search " + root.shareKind + "s"; text: root.shareSearch; foreground: root.foreground; font.family: root.fontFamily; hasCursor: root.hasCursor("share-search"); onTextChanged: root.shareSearch = text; onAccepted: keyCatcher.forceActiveFocus(); Keys.onEscapePressed: keyCatcher.forceActiveFocus() }
              Repeater {
                model: Model.filterShareResources(engine.shareCatalog, root.shareKind, root.shareSearch, 200)
                ActionRow {
                  required property var modelData
                  width: parent.width; rowId: "share-resource:" + modelData.id
                  glyph: modelData.shareable ? (root.shareSelection[modelData.id] ? "" : "○") : ""
                  title: modelData.name
                  subtitle: modelData.shareable ? modelData.id : "not shareable · " + modelData.reason
                  actionable: modelData.shareable
                }
              }
              Text {
                visible: engine.shareCatalog && engine.shareCatalog.currentItem.unavailable.length > 0
                width: parent.width
                text: "Unavailable resources require an explicit withdrawal acknowledgement."
                color: root.urgent; font.family: root.fontFamily; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap
              }
              Repeater {
                model: engine.shareCatalog ? engine.shareCatalog.currentItem.unavailable : []
                ActionRow {
                  required property var modelData
                  width: parent.width; rowId: "share-ack:" + modelData.id; glyph: ""
                  title: modelData.name; subtitle: modelData.reason
                  primary: root.shareAcknowledgements[modelData.id] === modelData.fingerprint
                }
              }
              ActionRow { width: parent.width; rowId: "share-publish"; glyph: ""; title: engine.busy ? "Publishing…" : "Publish loadout"; subtitle: Model.plural(Model.selectedShareIds(root.shareSelection).length, "selected resource"); primary: true }
              ActionRow { width: parent.width; rowId: "share-back"; glyph: ""; title: "Choose another starting point"; subtitle: "discard this in-memory selection" }
            }
          }

          // ------------------------------------------------ Applied
          Column {
            visible: root.tab === "applied"
            width: parent.width
            spacing: Style.space(8)
            Text {
              width: parent.width
              text: !engine.loadoutsAvailable
                ? (engine.loadingLoadouts ? "Loading applied loadouts…" : "Applied loadout state is unavailable; no empty state was invented.")
                : Model.plural((engine.loadouts || []).length, "applied loadout")
              color: engine.loadoutsAvailable ? root.foreground : root.urgent
              font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall; wrapMode: Text.WordWrap
            }
            Repeater {
              model: engine.loadouts || []
              ActionRow {
                required property var modelData
                width: parent.width; rowId: "applied:" + modelData.id
                glyph: modelData.attentionCount > 0 ? "" : ""
                title: modelData.name
                subtitle: Model.loadoutState(modelData.state) + " · " + Model.plural(modelData.resourceCount, "resource")
                primary: root.selectedAppliedId === modelData.id
              }
            }
            Column {
              visible: root.selectedApplied() !== null
              width: parent.width; spacing: Style.space(5)
              Repeater {
                model: { var item = root.selectedApplied(); return item && item.resources ? item.resources : [] }
                Text {
                  required property var modelData
                  width: parent.width
                  text: modelData.healthState + " · " + modelData.id
                  color: Model.resourceHealth(modelData.healthState) === "healthy" ? root.dim : root.urgent
                  font.family: root.fontFamily; font.pixelSize: Style.font.caption; wrapMode: Text.WrapAnywhere
                }
              }
              ActionRow { width: parent.width; rowId: "applied-update"; glyph: ""; title: "Update"; subtitle: "resolve and review changed desired state" }
              ActionRow { width: parent.width; rowId: "applied-repair"; glyph: ""; title: "Repair"; subtitle: "review missing-resource work" }
              ActionRow { width: parent.width; rowId: "applied-remove"; glyph: ""; title: "Remove loadout"; subtitle: "only recorded cleanup authority applies" }
            }
            PanelSeparator { foreground: root.foreground }
            ActionRow { width: parent.width; rowId: "aur-policy"; glyph: ""; title: "AUR package policy"; subtitle: Model.consent(engine.aurMode) }
          }
        }
      }
    }
  }

  component TabChip: CursorSurface {
    id: tabButton
    property string tabId: ""
    property string label: tabId.charAt(0).toUpperCase() + tabId.slice(1)
    property bool selectedOverride: false
    readonly property bool selected: selectedOverride || root.tab === tabId
    current: selected
    foreground: root.foreground
    implicitWidth: tabLabel.implicitWidth + Style.space(18)
    implicitHeight: tabLabel.implicitHeight + Style.space(9)
    MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { if (tabButton.tabId.indexOf("share-kind:") === 0) root.trigger(tabButton.tabId); else root.setTab(tabButton.tabId) } }
    Text { id: tabLabel; anchors.centerIn: parent; text: tabButton.label; color: tabButton.selected ? root.foreground : root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall }
  }

  component ActionRow: CursorSurface {
    id: actionRow
    property string rowId: ""
    property string glyph: ""
    property string title: ""
    property string subtitle: ""
    property bool actionable: true
    property bool primary: false
    hasCursor: root.hasCursor(rowId)
    foreground: root.foreground
    implicitHeight: actionContent.implicitHeight + Style.spacing.rowPaddingX
    MouseArea {
      anchors.fill: parent; enabled: actionRow.actionable; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
      onEntered: { root.cursorActive = true; for (var i = 0; i < root.rows.length; i++) if (root.rows[i].id === actionRow.rowId) root.cursor = i }
      onClicked: root.trigger(actionRow.rowId)
    }
    RowLayout {
      anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(10); anchors.rightMargin: Style.space(10); spacing: Style.space(10)
      Text { text: actionRow.glyph; color: actionRow.primary ? root.accent : (actionRow.actionable ? root.foreground : root.dim); font.family: root.fontFamily; font.pixelSize: Style.font.icon }
      ColumnLayout {
        id: actionContent; Layout.fillWidth: true; spacing: Style.space(1)
        Text { Layout.fillWidth: true; text: actionRow.title; color: actionRow.primary ? root.accent : (actionRow.actionable ? root.foreground : root.dim); font.family: root.fontFamily; font.pixelSize: Style.font.body; elide: Text.ElideRight }
        Text { Layout.fillWidth: true; visible: actionRow.subtitle !== ""; text: actionRow.subtitle; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption; elide: Text.ElideMiddle }
      }
    }
  }
}
