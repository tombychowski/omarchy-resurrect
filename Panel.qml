import QtQuick
import QtQuick.Controls as QQC
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

// One bar icon and one panel: how fresh the backup is, what it holds, and the
// two buttons that matter. Everything here is a thin face over
// bin/mntg — the panel never touches the filesystem itself.
Panel {
  id: root
  moduleName: "tombychowski.montage"
  ipcTarget: "tombychowski.montage"
  manageIpc: false

  // ------------------------------------------------------------------ theme
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color accent: Color.accent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  readonly property color stateColor: engine.busy ? accent
    : engine.freshness === "fresh" ? foreground
    : engine.freshness === "stale" ? Qt.darker(foreground, 1.35)
    : urgent

  // ------------------------------------------------------------------ state
  property string tab: "backup"
  property int cursor: 0
  property bool cursorActive: false
  property string selectedLoadoutId: ""
  property string selectedBackupCommit: ""
  property string repositorySettingName: "personal"
  property string repositorySettingPath: engine.home + "/.local/share/montage/loadouts"
  property string repositorySettingType: "loadouts"
  property string repositorySettingRemote: ""
  property string portSource: ""
  property string portDestination: engine.home + "/.local/share/montage/imported"
  property string portLoadoutId: "imported-ress"
  property string retentionKeep: "10"
  property string notice: ""
  property string shareStage: "choose"
  property var shareSelection: ({})
  property var shareAcknowledgements: ({})
  property string shareName: "My Montage loadout"
  property string shareDescription: ""
  property string shareCategory: "package"
  property string shareSearch: ""
  property string shareConflict: ""
  readonly property string shareViewState: engine.loadingShareCatalog ? "loading"
    : !engine.shareCatalogAvailable ? "unavailable"
    : engine.busy && engine.busyAction === "share" ? "exporting"
    : shareStage

  readonly property var tabs: ["backup", "repositories", "share", "loadouts"]
  readonly property var rows: {
    if (tab === "repositories") {
      var repositoryRows = []
      var configured = engine.repositories ? engine.repositories.repositories : []
      for (var c = 0; c < configured.length; c++)
        repositoryRows.push({ id: "repository:" + configured[c].name, label: configured[c].name })
      if (engine.selectedRepositoryName !== "") {
        repositoryRows.push({ id: "sync-preview", label: "Check synchronization" })
        if (engine.syncPreview)
          repositoryRows.push({ id: "sync-review", label: "Review synchronization in terminal" })
        if (engine.selectedRepositoryType === "loadouts") {
          var library = engine.repositoryLoadouts ? engine.repositoryLoadouts.items : []
          for (var ri = 0; ri < library.length; ri++)
            repositoryRows.push({ id: "repository-loadout:" + library[ri].id, label: library[ri].name })
          if (engine.selectedRepositoryLoadoutId !== "") {
            repositoryRows.push({ id: "repository-loadout-compose", label: "Compose selected loadout" })
            repositoryRows.push({ id: "repository-loadout-preview", label: "Preview selected loadout" })
            repositoryRows.push({ id: "repository-loadout-apply", label: "Apply selected loadout" })
          }
        } else if (engine.selectedRepositoryType === "vault") {
          var history = engine.backupHistory ? engine.backupHistory.backups : []
          for (var bi = 0; bi < history.length; bi++)
            repositoryRows.push({ id: "repository-backup:" + history[bi].commit, label: history[bi].createdAt })
          if (selectedBackupCommit !== "")
            repositoryRows.push({ id: "repository-backup-restore", label: "Restore selected backup" })
          repositoryRows.push({ id: "retention-keep", label: "Backups to keep" })
          repositoryRows.push({ id: "retention-preview", label: "Preview retention" })
          if (engine.retentionPreview && engine.retentionPreview.changed && !engine.retentionPreview.blocked)
            repositoryRows.push({ id: "retention-apply", label: "Run retention in terminal" })
        }
      }
      repositoryRows.push({ id: "repository-setting-name", label: "Repository name" })
      repositoryRows.push({ id: "repository-setting-path", label: "Repository location" })
      repositoryRows.push({ id: "repository-setting-type", label: "Repository type" })
      repositoryRows.push({ id: "repository-setting-remote", label: "Repository remote" })
      repositoryRows.push({ id: "repository-setting-save", label: "Save repository settings" })
      repositoryRows.push({ id: "port-source", label: "Ress port source" })
      repositoryRows.push({ id: "port-destination", label: "Montage port destination" })
      repositoryRows.push({ id: "port-loadout-id", label: "Imported loadout id" })
      repositoryRows.push({ id: "port-preview", label: "Preview Ress port" })
      if (engine.portPreview && engine.portPreview.compatible)
        repositoryRows.push({ id: "port-publish", label: "Publish Ress port in terminal" })
      return repositoryRows
    }
    if (tab === "share") {
      var shareRows = []
      if (shareStage === "choose") {
        shareRows.push({ id: "share-start-all", label: "All resources" })
        shareRows.push({ id: "share-start-current", label: "Current export" })
        shareRows.push({ id: "share-start-empty", label: "Empty selection" })
        var starts = engine.shareCatalog && engine.shareCatalog.presets
          ? engine.shareCatalog.presets.loadouts : []
        for (var s = 0; s < starts.length; s++)
          shareRows.push({ id: "share-start-preset:" + starts[s].id, label: starts[s].name })
      } else if (shareStage === "compose") {
        shareRows.push({ id: "share-name", label: "Name" })
        shareRows.push({ id: "share-description", label: "Description" })
        for (var k = 0; k < Model.SHARE_KINDS.length; k++)
          shareRows.push({ id: "share-category:" + Model.SHARE_KINDS[k], label: Model.SHARE_KINDS[k] })
        shareRows.push({ id: "share-search", label: "Search" })
        var visibleResources = Model.filterShareResources(engine.shareCatalog, shareCategory, shareSearch, 200)
        for (var r = 0; r < visibleResources.length; r++)
          shareRows.push({ id: "share-resource:" + visibleResources[r].id, label: visibleResources[r].name })
        var additions = engine.shareCatalog && engine.shareCatalog.presets
          ? engine.shareCatalog.presets.loadouts : []
        for (var p = 0; p < additions.length; p++)
          shareRows.push({ id: "share-add:" + additions[p].id, label: additions[p].name })
        var unavailable = engine.shareCatalog && engine.shareCatalog.currentExport
          ? engine.shareCatalog.currentExport.unavailable : []
        for (var u = 0; u < unavailable.length; u++)
          shareRows.push({ id: "share-ack:" + unavailable[u].id, label: unavailable[u].name })
        shareRows.push({ id: "share-export", label: "Export loadout" })
        shareRows.push({ id: "share-back", label: "Choose another start" })
      }
      shareRows.push({ id: "copy", label: "Copy the share command" })
      shareRows.push({ id: "folder", label: "Open the repository folder" })
      return shareRows
    }
    if (tab === "loadouts") {
      var loadoutRows = []
      var applied = engine.loadouts || []
      for (var l = 0; l < applied.length; l++)
        loadoutRows.push({ id: "loadout:" + applied[l].id, label: applied[l].name })
      if (selectedLoadoutId !== "") {
        loadoutRows.push({ id: "loadout-update", label: "Update selected loadout" })
        loadoutRows.push({ id: "loadout-repair", label: "Repair selected loadout" })
        loadoutRows.push({ id: "loadout-remove", label: "Remove selected loadout" })
      }
      return loadoutRows
    }
    var out = [{ id: "backup", label: "Back up now" }, { id: "restore", label: "Restore this machine" }]
    for (var i = 0; i < Model.CATEGORIES.length; i++)
      out.push({ id: "cat:" + Model.CATEGORIES[i].key, label: Model.CATEGORIES[i].label })
    out.push({ id: "auto", label: "Scheduled backups" })
    out.push({ id: "aur", label: "Building AUR packages" })
    out.push({ id: "units", label: "Enabling user services" })
    return out
  }

  readonly property string currentRowId: cursorActive && cursor >= 0 && cursor < rows.length
    ? rows[cursor].id : ""

  function hasCursor(id) { return currentRowId === id }

  function selectedLoadout() {
    var applied = engine.loadouts || []
    for (var i = 0; i < applied.length; i++)
      if (applied[i].id === selectedLoadoutId) return applied[i]
    return null
  }

  function selectedRepository() {
    var configured = engine.repositories ? engine.repositories.repositories : []
    for (var i = 0; i < configured.length; i++)
      if (configured[i].name === engine.selectedRepositoryName) return configured[i]
    return null
  }

  function selectedRepositoryLoadout() {
    var items = engine.repositoryLoadouts ? engine.repositoryLoadouts.items : []
    for (var i = 0; i < items.length; i++)
      if (items[i].id === engine.selectedRepositoryLoadoutId) return items[i]
    return null
  }

  function selectedBackup() {
    var backups = engine.backupHistory ? engine.backupHistory.backups : []
    for (var i = 0; i < backups.length; i++)
      if (backups[i].commit === selectedBackupCommit) return backups[i]
    return null
  }

  readonly property string repositoryViewState: Model.repositoryPanelState(
    engine.loadingRepositories || engine.loadingRepositoryContent,
    engine.repositories, selectedRepository(),
    engine.selectedRepositoryType === "loadouts" ? engine.repositoryLoadouts : engine.backupHistory,
    engine.syncPreview)

  function setTab(name) {
    tab = name
    cursor = 0
    cursorActive = false
    if (name === "share" && opened) engine.refreshShareCatalog()
  }

  function beginShare(source, presetId) {
    if (!engine.shareCatalogAvailable) { flash("Share catalog is unavailable"); return }
    var current = engine.shareCatalog.currentExport
    if (source === "current" && current.state !== "valid") {
      flash(current.state === "absent" ? "There is no current export" : "Current export is unavailable")
      return
    }
    shareSelection = Model.shareSelection(engine.shareCatalog, source, presetId || "")
    shareAcknowledgements = ({})
    shareConflict = ""
    // The catalog supplies the CLI's default name when no valid current export
    // exists, keeping panel and direct-CLI composition defaults identical.
    shareName = current.name
    shareDescription = current.state === "valid" ? current.description : ""
    shareStage = "compose"
    cursor = 0
  }

  function selectedShareCount() {
    return Model.selectedShareIds(shareSelection).length
  }

  function pendingWithdrawals() {
    return Model.unacknowledgedShareResources(engine.shareCatalog, shareAcknowledgements)
  }

  function canExportShare() {
    return engine.shareCatalogAvailable && selectedShareCount() > 0 &&
      shareName.replace(/^\s+|\s+$/g, "") !== "" && shareName.length <= 120 &&
      shareDescription.length <= 1000 && pendingWithdrawals().length === 0 && !engine.anyBusy
  }

  function reconcileShareCatalog(catalog) {
    if (!catalog || shareStage !== "compose") return
    var safe = {}, safeAcks = {}
    var ids = Model.selectedShareIds(shareSelection)
    for (var i = 0; i < ids.length; i++) {
      var resource = Model.shareResourceById(catalog, ids[i])
      if (resource && resource.shareable) safe[ids[i]] = true
    }
    var unavailable = catalog.currentExport.unavailable || []
    for (var u = 0; u < unavailable.length; u++) {
      var item = unavailable[u]
      if (shareAcknowledgements[item.id] === item.fingerprint)
        safeAcks[item.id] = item.fingerprint
    }
    shareSelection = safe
    shareAcknowledgements = safeAcks
  }

  // -------------------------------------------------------------- behaviour

  function moveCursor(dx, dy) {
    cursorActive = true
    if (dx !== 0) {
      var t = tabs.indexOf(tab) + dx
      if (t >= 0 && t < tabs.length) setTab(tabs[t])
      return
    }
    if (dy === 0) return
    cursor = Math.max(0, Math.min(rows.length - 1, cursor + dy))
  }

  function activate() {
    if (!cursorActive) { cursorActive = true; return }
    trigger(currentRowId)
  }

  function trigger(id) {
    if (id.indexOf("cat:") === 0) {
      var key = id.substring(4)
      engine.setCategory(key, !engine.categoryEnabled(key))
      return
    }
    if (id.indexOf("loadout:") === 0) {
      selectedLoadoutId = id.substring(8)
      return
    }
    if (id.indexOf("repository:") === 0) {
      var repositoryName = id.substring(11)
      var repositories = engine.repositories ? engine.repositories.repositories : []
      for (var rp = 0; rp < repositories.length; rp++) {
        if (repositories[rp].name === repositoryName) {
          selectedBackupCommit = ""
          engine.syncPreview = null
          engine.selectRepository(repositories[rp].name, repositories[rp].type,
                                  repositories[rp].path, repositories[rp].id)
          return
        }
      }
      return
    }
    if (id.indexOf("repository-loadout:") === 0) {
      engine.selectRepositoryLoadout(id.substring(19))
      return
    }
    if (id.indexOf("repository-backup:") === 0) {
      selectedBackupCommit = id.substring(18)
      return
    }
    if (id.indexOf("share-start-preset:") === 0) {
      beginShare("preset", id.substring(19))
      return
    }
    if (id.indexOf("share-category:") === 0) {
      shareCategory = id.substring(15)
      shareSearch = ""
      cursor = 0
      return
    }
    if (id.indexOf("share-resource:") === 0) {
      shareSelection = Model.toggleShareResource(engine.shareCatalog, shareSelection, id.substring(15))
      return
    }
    if (id.indexOf("share-add:") === 0) {
      var added = Model.addSharePreset(engine.shareCatalog, shareSelection, id.substring(10))
      shareSelection = added.selection
      shareConflict = added.themeConflict
      if (added.themeConflict !== "") flash("Theme kept; choose another theme explicitly")
      return
    }
    if (id.indexOf("share-ack:") === 0) {
      var ackId = id.substring(10)
      var pending = engine.shareCatalog.currentExport.unavailable || []
      var nextAck = {}, found = null
      for (var a in shareAcknowledgements) nextAck[a] = shareAcknowledgements[a]
      for (var q = 0; q < pending.length; q++) if (pending[q].id === ackId) found = pending[q]
      if (found) {
        if (nextAck[ackId] === found.fingerprint) delete nextAck[ackId]
        else nextAck[ackId] = found.fingerprint
      }
      shareAcknowledgements = nextAck
      return
    }
    switch (id) {
      case "backup":
        if (!engine.backupNow()) flash("Already running")
        break
      case "restore":
        root.setTab("repositories")
        flash("Select a vault and an exact backup first")
        break
      case "sync-preview":
        engine.previewSync(engine.selectedRepositoryName)
        break
      case "sync-review":
        var syncAction = engine.syncPreview && engine.syncPreview.status === "remote-ahead" ? "pull"
          : engine.syncPreview && engine.syncPreview.status === "local-ahead" ? "push" : "preview"
        engine.openSync(engine.selectedRepositoryName, syncAction)
        root.close()
        break
      case "repository-loadout-compose":
        root.setTab("share")
        engine.refreshShareCatalog()
        break
      case "repository-loadout-preview":
        engine.openRepositoryApply(engine.selectedRepositoryPath,
                                   engine.selectedRepositoryLoadoutId, true)
        break
      case "repository-loadout-apply":
        engine.openRepositoryApply(engine.selectedRepositoryPath,
                                   engine.selectedRepositoryLoadoutId, false)
        root.close()
        break
      case "repository-backup-restore":
        engine.openRestore(engine.selectedRepositoryPath, selectedBackupCommit)
        root.close()
        break
      case "retention-keep": retentionKeepField.forceActiveFocus(); break
      case "retention-preview":
        if (!engine.previewRetention(engine.selectedRepositoryPath, retentionKeep))
          flash("Enter a positive number of backups to keep")
        break
      case "retention-apply":
        engine.openRetention(engine.selectedRepositoryPath, retentionKeep)
        root.close()
        break
      case "repository-setting-name": repositoryNameField.forceActiveFocus(); break
      case "repository-setting-path": repositoryPathField.forceActiveFocus(); break
      case "repository-setting-type":
        repositorySettingType = repositorySettingType === "loadouts" ? "vault" : "loadouts"
        break
      case "repository-setting-remote": repositoryRemoteField.forceActiveFocus(); break
      case "repository-setting-save":
        if (repositorySettingName === "" || repositorySettingPath === "") {
          flash("Repository name and absolute path are required"); break
        }
        if (Model.isRessLocation(repositorySettingPath)) {
          flash("Ress directories are port sources, not live Montage repositories"); break
        }
        if (!engine.openRepositoryConfigure(repositorySettingName, repositorySettingPath,
                                            repositorySettingType, repositorySettingRemote, true)) {
          flash("Choose an independent Montage repository location"); break
        }
        root.close()
        break
      case "port-source": portSourceField.forceActiveFocus(); break
      case "port-destination": portDestinationField.forceActiveFocus(); break
      case "port-loadout-id": portLoadoutIdField.forceActiveFocus(); break
      case "port-preview":
        if (!engine.previewPort(portSource, portDestination, false))
          flash("Add separate source and destination paths")
        break
      case "port-publish":
        if (!engine.openPortImport(engine.portPreview, engine.selectedRepositoryName, portLoadoutId)) {
          flash("Select a loadout repository and provide a new stable id"); break
        }
        root.close()
        break
      case "auto":
        engine.setValue("AUTO_BACKUP", engine.autoBackup ? "off" : "on")
        break
      case "aur":
        engine.setValue("AUR", nextConsent(engine.aurMode))
        break
      case "units":
        engine.setValue("ENABLE_UNITS", nextConsent(engine.enableUnits))
        break
      case "share-start-all": beginShare("all", ""); break
      case "share-start-current": beginShare("current", ""); break
      case "share-start-empty": beginShare("empty", ""); break
      case "share-name": shareNameField.forceActiveFocus(); break
      case "share-description": shareDescriptionField.forceActiveFocus(); break
      case "share-search": shareSearchField.forceActiveFocus(); break
      case "share-export":
        if (selectedShareCount() === 0) { flash("Choose at least one resource"); break }
        if (shareName.replace(/^\s+|\s+$/g, "") === "") { flash("Add a loadout name"); break }
        if (shareName.length > 120 || shareDescription.length > 1000) { flash("Name or description is too long"); break }
        if (pendingWithdrawals().length > 0) { flash("Acknowledge unavailable resources first"); break }
        if (!engine.shareCustom(engine.selectedRepositoryName, engine.selectedRepositoryLoadoutId,
                                shareName, shareDescription,
                                Model.selectedShareIds(shareSelection), shareAcknowledgements))
          flash("Already running")
        break
      case "share-back":
        shareStage = "choose"
        cursor = 0
        break
      case "copy":
        copyProc.command = ["wl-copy", "--", shareCommand]
        copyProc.running = true
        break
      case "folder":
        if (engine.selectedRepositoryPath !== "")
          Quickshell.execDetached(["xdg-open", engine.selectedRepositoryPath])
        break
      case "loadout-update":
        engine.openLoadoutAction("update", selectedLoadoutId, "")
        root.close()
        break
      case "loadout-repair":
        engine.openLoadoutAction("repair", selectedLoadoutId, "")
        root.close()
        break
      case "loadout-remove":
        engine.openLoadoutAction("remove", selectedLoadoutId, "")
        root.close()
        break
    }
  }

  // ask -> yes -> no -> ask. Three states, so this cycles rather than toggles.
  function nextConsent(value) {
    return value === "ask" ? "yes" : (value === "yes" ? "no" : "ask")
  }

  function flash(message) { notice = message; noticeTimer.restart() }

  readonly property string shareCommand:
    engine.selectedRepositoryLoadoutId === "" ? "Select a repository loadout first"
      : ("mntg apply " + (selectedRepository() && selectedRepository().remote !== ""
          ? Model.stripCredentials(selectedRepository().remote) : engine.selectedRepositoryPath)
        + " --loadout " + engine.selectedRepositoryLoadoutId)

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onOpenedChanged: if (opened) {
    cursorActive = false
    cursor = 0
    notice = ""
    if (panelFlick) panelFlick.contentY = 0
    engine.refresh()
    if (tab === "share") engine.refreshShareCatalog()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  Service {
    id: engine
    panelOwned: true
    uiActive: root.opened
    staleHours: Math.max(1, Math.min(720, parseInt(root.setting("staleHours", 48), 10) || 48))
    onFinished: function(action, state) {
      root.flash(state === "ok"
        ? (action === "backup" ? "Backed up" : "Loadout exported")
        : (action + " finished with problems"))
    }
    onShareCatalogChanged: {
      root.reconcileShareCatalog(shareCatalog)
    }
  }

  Timer { id: noticeTimer; interval: 3200; onTriggered: root.notice = "" }
  Process {
    id: copyProc
    running: false
    command: []
    onExited: function(exitCode) {
      root.flash(exitCode === 0 ? "Copied to the clipboard"
                                : "Could not copy — wl-clipboard is not installed")
    }
  }

  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
    function backup(): string { return engine.backupNow() ? "started" : "busy" }

    // Open straight to a tab, so a keybind can go to Share without three keys.
    function openTab(name: string): string {
      if (root.tabs.indexOf(name) < 0) return "unknown tab: " + name
      root.setTab(name)
      root.open()
      return "ok"
    }
  }

  // ------------------------------------------------------------- bar button

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    iconComponent: Component {
      Item {
        Text {
          id: barGlyph
          anchors.centerIn: parent
          text: "󰁯"
          font.family: root.fontFamily
          font.pixelSize: Style.bar.iconFont
          color: engine.anyBusy ? root.barForeground
            : engine.freshness === "none" ? Qt.darker(root.barForeground, 1.6)
            : engine.freshness === "stale" ? Qt.darker(root.barForeground, 1.3)
            : root.barForeground

          // A backup running is the one thing worth animating: it is the only
          // state the icon can be in that you might want to wait for. The pulse
          // lives on its own property so opacity snaps back when it stops.
          property real pulse: 1.0
          opacity: engine.anyBusy ? pulse : 1.0

          SequentialAnimation on pulse {
            running: engine.anyBusy
            loops: Animation.Infinite
            NumberAnimation { to: 0.35; duration: 700; easing.type: Easing.InOutQuad }
            NumberAnimation { to: 1.0;  duration: 700; easing.type: Easing.InOutQuad }
          }
        }
      }
    }
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.MiddleButton) engine.backupNow()
      else root.toggle()
    }
  }

  // ------------------------------------------------------------------ panel

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(400))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(620))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: shareNameField.activeFocus || shareDescriptionField.activeFocus || shareSearchField.activeFocus ||
        repositoryNameField.activeFocus || repositoryPathField.activeFocus || repositoryRemoteField.activeFocus ||
        portSourceField.activeFocus || portDestinationField.activeFocus || portLoadoutIdField.activeFocus ||
        retentionKeepField.activeFocus
      onMoveRequested: function(dx, dy) { root.moveCursor(dx, dy) }
      onActivateRequested: root.activate()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) {
        var key = String(t).toLowerCase()
        if (key === "b") root.trigger("backup")
        else if (key === "r") root.trigger("restore")
        else if (key === "o") root.setTab("repositories")
        else if (key === "s") root.setTab("share")
        else if (key === "a" || key === "l") root.setTab("loadouts")
        else if (key === "?") root.setTab("backup")
      }

      Flickable {
        id: panelFlick
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        QQC.ScrollBar.vertical: QQC.ScrollBar { policy: QQC.ScrollBar.AsNeeded }

        Column {
          id: column
          width: panelFlick.width
          spacing: Style.space(12)

          // ------------------------------------------------------------ hero
          PanelHero {
            width: parent.width
            title: "Montage"
            meta: engine.anyBusy ? (engine.currentStep || "Working…")
              : engine.externallyBusy ? "Scheduled backup running…"
              : engine.lastBackup > 0 ? ("Backed up " + engine.agoText)
              : "Never backed up"
            foreground: root.foreground
            fontFamily: root.fontFamily
            iconComponent: Component {
              Text {
                text: "󰁯"
                color: root.stateColor
                font.family: root.fontFamily
                font.pixelSize: Style.font.display
              }
            }

          }

          // Progress only exists while something is running, and it reads the
          // real step names out of the CLI rather than guessing at a duration.
          Column {
            visible: engine.anyBusy
            width: parent.width
            spacing: Style.spacing.labelGap

            Rectangle {
              width: parent.width
              height: Math.max(2, Style.space(3))
              radius: height / 2
              color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12)

              Rectangle {
                id: progressFill
                height: parent.height
                radius: parent.radius
                color: root.accent
                width: engine.currentProgress >= 0
                  ? parent.width * engine.currentProgress
                  : parent.width * 0.35
                Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }

                SequentialAnimation on x {
                  id: sweep
                  running: engine.busy && engine.currentProgress < 0
                  loops: Animation.Infinite
                  // `target` is not set on a property value source, so reset
                  // the item itself rather than reading it off the animation.
                  onRunningChanged: if (!running) progressFill.x = 0
                  NumberAnimation { from: 0; to: panelFlick.width * 0.65; duration: 900; easing.type: Easing.InOutQuad }
                  NumberAnimation { from: panelFlick.width * 0.65; to: 0; duration: 900; easing.type: Easing.InOutQuad }
                }
              }
            }

            Text {
              width: parent.width
              text: engine.currentCategory
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
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

          // ------------------------------------------------------------ tabs
          Row {
            width: parent.width
            spacing: Style.space(6)

            Repeater {
              model: root.tabs
              TabChip {
                required property var modelData
                tabId: modelData
              }
            }
          }


          PanelSeparator { foreground: root.foreground }

          // ---------------------------------------------------- backup tab
          Column {
            visible: root.tab === "backup"
            width: parent.width
            spacing: Style.space(10)

            Row {
              width: parent.width
              spacing: Style.space(8)

              ActionRow {
                width: (parent.width - Style.space(8)) / 2
                rowId: "backup"
                glyph: ""
                title: engine.busy && engine.busyAction === "backup" ? "Backing up…" : "Back up now"
                subtitle: "b"
              }
              ActionRow {
                width: (parent.width - Style.space(8)) / 2
                rowId: "restore"
                glyph: "󰦛"
                title: "Browse backups"
                subtitle: "r · select an exact commit"
              }
            }

            Text {
              visible: !!(engine.status && engine.status.manifest)
              width: parent.width
              text: (engine.status && engine.status.manifest)
                ? Model.summarize(engine.status.manifest.counts) : ""
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }

            PanelSectionHeader {
              text: "WHAT TRAVELS"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Column {
              width: parent.width
              spacing: Style.space(4)

              Repeater {
                model: Model.CATEGORIES
                CategoryRow {
                  required property var modelData
                  width: parent.width
                  category: modelData
                }
              }
            }

            PanelSeparator { foreground: root.foreground }

            ActionRow {
              width: parent.width
              rowId: "auto"
              glyph: ""
              title: "Scheduled backups"
              subtitle: engine.autoBackup
                ? ("every " + engine.intervalHours + "h · next in " + Math.round(engine.nextDueIn / 3600) + "h")
                : "off"
              trailing: true
              trailingOn: engine.autoBackup
            }

            // The two decisions a restore never takes on its own. They are here
            // as well as in the config file because a setting you cannot see is
            // a setting you cannot have agreed to.
            ActionRow {
              width: parent.width
              rowId: "aur"
              glyph: ""
              title: "Building AUR packages"
              subtitle: Model.consent(engine.aurMode,
                "builds without asking", "never builds them", "asks first · recommended")
            }
            ActionRow {
              width: parent.width
              rowId: "units"
              glyph: ""
              title: "Enabling user services"
              subtitle: Model.consent(engine.enableUnits,
                "enables without asking", "never enables them", "asks first · recommended")
            }

            Text {
              width: parent.width
              text: engine.remote !== ""
                ? ("Pushes to " + Model.stripCredentials(engine.remote))
                : ("Vault: " + engine.vault)
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              elide: Text.ElideMiddle
            }
          }

          // ----------------------------------------------- repositories tab
          Column {
            visible: root.tab === "repositories"
            width: parent.width
            spacing: Style.space(10)

            Text {
              width: parent.width
              text: "Choose a Montage repository, then inspect its stable loadouts or immutable backup history. All validity and synchronization state comes from mntg."
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              wrapMode: Text.WordWrap
            }

            Text {
              visible: root.repositoryViewState === "loading"
              width: parent.width
              text: "Loading repositories…"
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
            }
            Text {
              visible: root.repositoryViewState === "invalid"
              width: parent.width
              text: "Repository information is invalid or unavailable. No state was inferred from repository files."
              color: root.urgent
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              wrapMode: Text.WordWrap
            }
            Text {
              visible: root.repositoryViewState === "empty"
              width: parent.width
              text: engine.selectedRepositoryName === ""
                ? "No Montage repositories are configured."
                : "This repository has no items yet."
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
            }

            PanelSectionHeader { text: "REPOSITORIES"; foreground: root.foreground; fontFamily: root.fontFamily }
            Repeater {
              model: engine.repositories ? engine.repositories.repositories : []
              ActionRow {
                required property var modelData
                width: parent.width
                rowId: "repository:" + modelData.name
                glyph: !modelData.valid ? "" : (modelData.type === "vault" ? "󰒃" : "󰘬")
                title: modelData.name
                subtitle: modelData.type + " · " + modelData.status + " · " + modelData.id
                primary: engine.selectedRepositoryName === modelData.name
              }
            }

            Column {
              visible: engine.selectedRepositoryName !== ""
              width: parent.width
              spacing: Style.space(6)

              Text {
                width: parent.width
                text: root.repositoryViewState === "divergent"
                  ? "Local and remote history diverge. Review synchronization in a terminal."
                  : root.repositoryViewState === "stale"
                    ? "The remote has newer history. Review before using this repository."
                    : root.repositoryViewState === "attention"
                      ? "This repository needs attention."
                      : root.repositoryViewState === "healthy" ? "Repository is healthy." : ""
                color: ["divergent", "stale", "attention"].indexOf(root.repositoryViewState) >= 0
                  ? root.urgent : root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
                wrapMode: Text.WordWrap
              }
              ActionRow {
                width: parent.width
                rowId: "sync-preview"
                glyph: ""
                title: engine.loadingSyncPreview ? "Checking synchronization…" : "Check synchronization"
                subtitle: engine.syncPreview
                  ? (engine.syncPreview.status + " · ahead " + engine.syncPreview.ahead + " · behind " + engine.syncPreview.behind)
                  : "read-only classification"
                actionable: !engine.loadingSyncPreview
              }
              ActionRow {
                visible: engine.syncPreview !== null
                width: parent.width; rowId: "sync-review"; glyph: ""
                title: engine.syncPreview && engine.syncPreview.status === "divergent"
                  ? "Review divergence in terminal" : "Continue synchronization in terminal"
                subtitle: "mntg keeps conflict and history decisions visible"
              }

              Column {
                visible: engine.selectedRepositoryType === "loadouts"
                width: parent.width
                spacing: Style.space(5)
                PanelSectionHeader { text: "LOADOUTS"; foreground: root.foreground; fontFamily: root.fontFamily }
                Repeater {
                  model: engine.repositoryLoadouts ? engine.repositoryLoadouts.items : []
                  ActionRow {
                    required property var modelData
                    width: parent.width
                    rowId: "repository-loadout:" + modelData.id
                    glyph: engine.selectedRepositoryLoadoutId === modelData.id ? "" : "○"
                    title: modelData.name
                    subtitle: modelData.id + " · " + modelData.author
                    primary: engine.selectedRepositoryLoadoutId === modelData.id
                  }
                }
                Text {
                  visible: !!(engine.repositoryLoadouts && engine.repositoryLoadouts.invalid.length)
                  width: parent.width
                  text: engine.repositoryLoadouts
                    ? Model.plural(engine.repositoryLoadouts.invalid.length, "invalid loadout") + " omitted by mntg"
                    : ""
                  color: root.urgent
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }
                ActionRow {
                  visible: engine.selectedRepositoryLoadoutId !== ""
                  width: parent.width; rowId: "repository-loadout-compose"; glyph: "󰏫"
                  title: "Compose selected loadout"; subtitle: "edit its validated resource selection"
                }
                ActionRow {
                  visible: engine.selectedRepositoryLoadoutId !== ""
                  width: parent.width; rowId: "repository-loadout-preview"; glyph: ""
                  title: "Preview apply"; subtitle: "dry run in a terminal"
                }
                ActionRow {
                  visible: engine.selectedRepositoryLoadoutId !== ""
                  width: parent.width; rowId: "repository-loadout-apply"; glyph: ""
                  title: "Apply selected loadout"; subtitle: "review and consent in a terminal"
                }
              }

              Column {
                visible: engine.selectedRepositoryType === "vault"
                width: parent.width
                spacing: Style.space(5)
                PanelSectionHeader { text: "BACKUP HISTORY"; foreground: root.foreground; fontFamily: root.fontFamily }
                Repeater {
                  model: engine.backupHistory ? engine.backupHistory.backups : []
                  ActionRow {
                    required property var modelData
                    width: parent.width
                    rowId: "repository-backup:" + modelData.commit
                    glyph: root.selectedBackupCommit === modelData.commit ? "" : "󰋚"
                    title: modelData.label || modelData.subject || modelData.createdAt
                    subtitle: modelData.createdAt + " · " + modelData.commit.substring(0, 12)
                    primary: root.selectedBackupCommit === modelData.commit
                  }
                }
                Text {
                  visible: root.selectedBackup() !== null
                  width: parent.width
                  text: {
                    var backup = root.selectedBackup()
                    return backup ? (backup.commit + "\n" + Model.summarize(backup.counts)) : ""
                  }
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  wrapMode: Text.WrapAnywhere
                }
                ActionRow {
                  visible: root.selectedBackupCommit !== ""
                  width: parent.width; rowId: "repository-backup-restore"; glyph: "󰦛"
                  title: "Restore this exact backup"; subtitle: "opens a terminal pinned to the full commit"
                }
                TextField {
                  id: retentionKeepField
                  width: parent.width; placeholderText: "Backups to keep"; text: root.retentionKeep
                  foreground: root.foreground; font.family: root.fontFamily
                  hasCursor: root.hasCursor("retention-keep")
                  onTextChanged: root.retentionKeep = text
                  onAccepted: keyCatcher.forceActiveFocus()
                  Keys.onEscapePressed: keyCatcher.forceActiveFocus()
                }
                ActionRow {
                  width: parent.width; rowId: "retention-preview"; glyph: ""
                  title: engine.loadingRetentionPreview ? "Planning retention…" : "Preview retention"
                  subtitle: "read-only list of exact commits that would be removed"
                  actionable: !engine.loadingRetentionPreview
                }
                Text {
                  visible: engine.retentionPreview !== null
                  width: parent.width
                  text: engine.retentionPreview
                    ? (Model.plural(engine.retentionPreview.removed.length, "backup") + " would be removed"
                      + (engine.retentionPreview.remoteDivergence ? " · remote history would diverge" : "")
                      + (engine.retentionPreview.blocked ? " · blocked by labels" : "")) : ""
                  color: engine.retentionPreview && (engine.retentionPreview.blocked || engine.retentionPreview.remoteDivergence)
                    ? root.urgent : root.foreground
                  font.family: root.fontFamily; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap
                }
                ActionRow {
                  visible: !!(engine.retentionPreview && engine.retentionPreview.changed && !engine.retentionPreview.blocked)
                  width: parent.width; rowId: "retention-apply"; glyph: ""
                  title: "Run retention in terminal"; subtitle: "previews again and asks before rewriting history"
                }
              }
            }

            PanelSeparator { foreground: root.foreground }
            PanelSectionHeader { text: "REPOSITORY SETTINGS"; foreground: root.foreground; fontFamily: root.fontFamily }
            Text {
              width: parent.width
              text: "Register an existing Montage repository at an independent absolute path. The CLI validates its identity and serializes the registry update. Credentials are removed from remotes before submission."
              color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }
            TextField {
              id: repositoryNameField
              width: parent.width; placeholderText: "Repository name"; text: root.repositorySettingName
              foreground: root.foreground; font.family: root.fontFamily
              hasCursor: root.hasCursor("repository-setting-name")
              onTextChanged: root.repositorySettingName = text
              onAccepted: keyCatcher.forceActiveFocus()
              Keys.onEscapePressed: keyCatcher.forceActiveFocus()
            }
            TextField {
              id: repositoryPathField
              width: parent.width; placeholderText: engine.home + "/.local/share/montage/loadouts"
              text: root.repositorySettingPath; foreground: root.foreground; font.family: root.fontFamily
              hasCursor: root.hasCursor("repository-setting-path")
              onTextChanged: root.repositorySettingPath = text
              onAccepted: keyCatcher.forceActiveFocus()
              Keys.onEscapePressed: keyCatcher.forceActiveFocus()
            }
            ActionRow {
              width: parent.width; rowId: "repository-setting-type"
              glyph: repositorySettingType === "vault" ? "󰒃" : "󰘬"
              title: "Repository type"; subtitle: repositorySettingType
            }
            TextField {
              id: repositoryRemoteField
              width: parent.width; placeholderText: "Credential-free Git remote (optional)"
              text: root.repositorySettingRemote; foreground: root.foreground; font.family: root.fontFamily
              hasCursor: root.hasCursor("repository-setting-remote")
              onTextChanged: root.repositorySettingRemote = Model.stripCredentials(text)
              onAccepted: keyCatcher.forceActiveFocus()
              Keys.onEscapePressed: keyCatcher.forceActiveFocus()
            }
            Text {
              visible: Model.isRessLocation(root.repositorySettingPath)
              width: parent.width
              text: "Ress directories cannot be registered as live Montage state. Use the one-time port preview below and a separate destination."
              color: root.urgent; font.family: root.fontFamily; font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }
            ActionRow {
              width: parent.width; rowId: "repository-setting-save"; glyph: ""
              title: "Save repository settings"
              subtitle: "opens mntg validation and the serialized configuration update"
              actionable: root.repositorySettingName !== "" && root.repositorySettingPath !== "" &&
                !Model.isRessLocation(root.repositorySettingPath)
            }

            PanelSectionHeader { text: "PORT FROM RESS"; foreground: root.foreground; fontFamily: root.fontFamily }
            Text {
              width: parent.width
              text: "A Ress directory is a read-only migration source, never a shared live location. Preview into a separate Montage destination before publishing."
              color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }
            TextField {
              id: portSourceField
              width: parent.width; placeholderText: "Ress artifact source"; text: root.portSource
              foreground: root.foreground; font.family: root.fontFamily; hasCursor: root.hasCursor("port-source")
              onTextChanged: root.portSource = text
              onAccepted: keyCatcher.forceActiveFocus()
              Keys.onEscapePressed: keyCatcher.forceActiveFocus()
            }
            TextField {
              id: portDestinationField
              width: parent.width; placeholderText: "Separate Montage destination"; text: root.portDestination
              foreground: root.foreground; font.family: root.fontFamily; hasCursor: root.hasCursor("port-destination")
              onTextChanged: root.portDestination = text
              onAccepted: keyCatcher.forceActiveFocus()
              Keys.onEscapePressed: keyCatcher.forceActiveFocus()
            }
            TextField {
              id: portLoadoutIdField
              visible: !!(engine.portPreview && engine.portPreview.artifactType === "loadout")
              width: parent.width; placeholderText: "New stable loadout id"; text: root.portLoadoutId
              foreground: root.foreground; font.family: root.fontFamily; hasCursor: root.hasCursor("port-loadout-id")
              onTextChanged: root.portLoadoutId = text
              onAccepted: keyCatcher.forceActiveFocus()
              Keys.onEscapePressed: keyCatcher.forceActiveFocus()
            }
            ActionRow {
              width: parent.width; rowId: "port-preview"; glyph: ""
              title: engine.loadingPortPreview ? "Inspecting Ress artifact…" : "Preview Ress port"
              subtitle: "read-only mntg conversion plan"
              actionable: !engine.loadingPortPreview && root.portSource !== "" && root.portDestination !== ""
            }
            Text {
              visible: engine.portPreview !== null
              width: parent.width
              text: engine.portPreview
                ? (engine.portPreview.artifactType + " · " + (engine.portPreview.compatible ? "compatible" : engine.portPreview.reason)
                  + " · " + Model.plural(engine.portPreview.losses.length, "reported loss", "reported losses")) : ""
              color: engine.portPreview && engine.portPreview.compatible ? root.foreground : root.urgent
              font.family: root.fontFamily; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap
            }
            ActionRow {
              visible: !!(engine.portPreview && engine.portPreview.compatible)
              width: parent.width; rowId: "port-publish"; glyph: ""
              title: "Publish port in terminal"
              subtitle: "review losses and self-plugin choices before mntg writes"
              actionable: engine.portPreview && (engine.portPreview.artifactType === "vault" ||
                (engine.selectedRepositoryType === "loadouts" && root.portLoadoutId !== ""))
            }
          }

          // ----------------------------------------------------- share tab
          Column {
            visible: root.tab === "share"
            width: parent.width
            spacing: Style.space(10)

            Text {
              width: parent.width
              text: engine.selectedRepositoryLoadoutId === ""
                ? "Select a loadout repository and stable loadout on the Repositories tab first."
                : "Build the selected repository loadout from resources on this machine. "
                + "The CLI checks every selection again before it changes the profile. "
                + "No dotfiles, keys, home files or applied-loadout ownership travel."
              color: engine.selectedRepositoryLoadoutId === "" ? root.urgent : root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              wrapMode: Text.WordWrap
            }

            Text {
              visible: root.shareViewState === "loading"
              width: parent.width
              text: "Inspecting shareable resources…"
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
            }

            Text {
              visible: root.shareViewState === "unavailable"
              width: parent.width
              text: "The Share catalog is unavailable. No machine state will be reconstructed in the panel."
              color: root.urgent
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              wrapMode: Text.WordWrap
            }

            Column {
              visible: !engine.loadingShareCatalog && engine.shareCatalogAvailable && root.shareStage === "choose"
              width: parent.width
              spacing: Style.space(6)

              PanelSectionHeader { text: "START WITH"; foreground: root.foreground; fontFamily: root.fontFamily }
              ActionRow {
                width: parent.width; rowId: "share-start-all"; glyph: "󰐕"
                title: "All shareable resources"; subtitle: "recommended · the quickest path"
                primary: true
              }
              ActionRow {
                width: parent.width; rowId: "share-start-current"; glyph: "󰋚"
                title: "Selected loadout"
                subtitle: engine.shareCatalog && engine.shareCatalog.currentExport.state === "valid"
                  ? "edit its metadata and current selections"
                  : (engine.shareCatalog && engine.shareCatalog.currentExport.state === "absent"
                      ? "not available · no profile has been exported" : "not available · profile could not be validated")
                actionable: !!(engine.shareCatalog && engine.shareCatalog.currentExport.state === "valid")
              }
              ActionRow {
                width: parent.width; rowId: "share-start-empty"; glyph: "󰝒"
                title: "Empty selection"; subtitle: "choose every resource yourself"
              }

              PanelSectionHeader { text: "OR AN APPLIED LOADOUT"; foreground: root.foreground; fontFamily: root.fontFamily }
              Text {
                visible: engine.shareCatalog && engine.shareCatalog.presets.state !== "valid"
                width: parent.width
                text: "Applied-loadout starting choices are unavailable; manual composition still works."
                color: root.urgent
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                wrapMode: Text.WordWrap
              }
              Repeater {
                model: engine.shareCatalog && engine.shareCatalog.presets.state === "valid"
                  ? engine.shareCatalog.presets.loadouts : []
                ActionRow {
                  required property var modelData
                  width: parent.width
                  rowId: "share-start-preset:" + modelData.id
                  glyph: modelData.warnings.length > 0 ? "" : "󰐕"
                  title: modelData.name
                  subtitle: Model.plural(modelData.resourceIds.length, "eligible resource")
                    + (modelData.warnings.length ? " · " + modelData.warnings.length + " not selected" : "")
                }
              }
              Repeater {
                model: engine.shareCatalog && engine.shareCatalog.presets.state === "valid"
                  ? engine.shareCatalog.presets.loadouts : []
                Text {
                  required property var modelData
                  visible: modelData.warnings.length > 0
                  width: parent.width
                  text: modelData.name + " excludes: " + Model.sharePresetWarnings(modelData)
                  color: root.urgent
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  wrapMode: Text.WrapAnywhere
                }
              }
            }

            Column {
              visible: !engine.loadingShareCatalog && engine.shareCatalogAvailable && root.shareStage === "compose"
              width: parent.width
              spacing: Style.space(8)

              TextField {
                id: shareNameField
                width: parent.width
                placeholderText: "Loadout name"
                text: root.shareName
                foreground: root.foreground
                font.family: root.fontFamily
                hasCursor: root.hasCursor("share-name")
                onTextChanged: root.shareName = text
                onAccepted: keyCatcher.forceActiveFocus()
                Keys.onEscapePressed: keyCatcher.forceActiveFocus()
              }
              TextField {
                id: shareDescriptionField
                width: parent.width
                placeholderText: "Description (optional)"
                text: root.shareDescription
                foreground: root.foreground
                font.family: root.fontFamily
                hasCursor: root.hasCursor("share-description")
                onTextChanged: root.shareDescription = text
                onAccepted: keyCatcher.forceActiveFocus()
                Keys.onEscapePressed: keyCatcher.forceActiveFocus()
              }

              PanelSectionHeader { text: "RESOURCES"; foreground: root.foreground; fontFamily: root.fontFamily }
              Repeater {
                model: Model.SHARE_KINDS
                ActionRow {
                  required property var modelData
                  width: parent.width
                  rowId: "share-category:" + modelData
                  glyph: modelData === "theme" ? "" : (modelData === "package" ? "" : "󰏗")
                  title: modelData === "webapp" ? "Web apps"
                    : modelData.charAt(0).toUpperCase() + modelData.slice(1) + "s"
                  subtitle: {
                    var counts = Model.shareCounts(engine.shareCatalog, root.shareSelection)
                    return Model.plural(counts[modelData], "selected") + " · open to search and choose"
                  }
                  primary: root.shareCategory === modelData
                }
              }

              TextField {
                id: shareSearchField
                width: parent.width
                placeholderText: "Search " + root.shareCategory + "s"
                text: root.shareSearch
                foreground: root.foreground
                font.family: root.fontFamily
                hasCursor: root.hasCursor("share-search")
                onTextChanged: root.shareSearch = text
                onAccepted: keyCatcher.forceActiveFocus()
                Keys.onEscapePressed: keyCatcher.forceActiveFocus()
              }
              Text {
                width: parent.width
                text: "Showing at most 200 matches. Themes are a single choice."
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }
              Repeater {
                model: Model.filterShareResources(engine.shareCatalog, root.shareCategory, root.shareSearch, 200)
                ActionRow {
                  required property var modelData
                  width: parent.width
                  rowId: "share-resource:" + modelData.id
                  glyph: modelData.shareable ? (modelData.active ? "" : "○") : ""
                  title: modelData.name
                  subtitle: modelData.shareable
                    ? (modelData.channels.length ? modelData.channels.join(" · ") : modelData.id)
                    : ("not shareable · " + modelData.reason)
                  actionable: modelData.shareable
                  trailing: modelData.shareable
                  trailingOn: !!root.shareSelection[modelData.id]
                }
              }

              PanelSectionHeader { text: "ADD FROM APPLIED LOADOUT"; foreground: root.foreground; fontFamily: root.fontFamily }
              Text {
                width: parent.width
                text: "Excluded resources are not added automatically. Selecting one that is shareable exports this machine's current definition, not the applied snapshot."
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                wrapMode: Text.WordWrap
              }
              Repeater {
                model: engine.shareCatalog && engine.shareCatalog.presets.state === "valid"
                  ? engine.shareCatalog.presets.loadouts : []
                ActionRow {
                  required property var modelData
                  width: parent.width
                  rowId: "share-add:" + modelData.id
                  glyph: ""
                  title: modelData.name
                  subtitle: Model.plural(modelData.resourceIds.length, "eligible resource")
                    + (modelData.warnings.length ? " · excludes " + modelData.warnings.length + " needing attention" : "")
                }
              }
              Repeater {
                model: engine.shareCatalog && engine.shareCatalog.presets.state === "valid"
                  ? engine.shareCatalog.presets.loadouts : []
                Text {
                  required property var modelData
                  visible: modelData.warnings.length > 0
                  width: parent.width
                  text: modelData.name + " excludes: " + Model.sharePresetWarnings(modelData)
                  color: root.urgent
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  wrapMode: Text.WrapAnywhere
                }
              }
              Text {
                visible: root.shareConflict !== ""
                width: parent.width
                text: "A preset requested another theme. Your existing theme was kept; choose explicitly above."
                color: root.urgent
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                wrapMode: Text.WordWrap
              }

              Column {
                visible: !!(engine.shareCatalog && engine.shareCatalog.currentExport.unavailable.length)
                width: parent.width
                spacing: Style.space(5)
                PanelSectionHeader { text: "NO LONGER AVAILABLE"; foreground: root.foreground; fontFamily: root.fontFamily }
                Text {
                  width: parent.width
                  text: "Acknowledge each item to remove its previous definition from the current export."
                  color: root.urgent
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  wrapMode: Text.WordWrap
                }
                Repeater {
                  model: engine.shareCatalog ? engine.shareCatalog.currentExport.unavailable : []
                  ActionRow {
                    required property var modelData
                    width: parent.width
                    rowId: "share-ack:" + modelData.id
                    glyph: ""
                    title: modelData.name
                    subtitle: modelData.reason
                    trailing: true
                    trailingOn: root.shareAcknowledgements[modelData.id] === modelData.fingerprint
                  }
                }
              }

              ActionRow {
                width: parent.width
                rowId: "share-export"
                glyph: ""
                title: engine.busy && engine.busyAction === "share" ? "Exporting…" : "Export current loadout"
                subtitle: root.selectedShareCount() === 0 ? "choose at least one resource"
                  : (root.pendingWithdrawals().length > 0
                      ? "acknowledge " + root.pendingWithdrawals().length + " unavailable resource(s)"
                      : Model.plural(root.selectedShareCount(), "selected resource") + " · checked again before writing")
                actionable: root.canExportShare()
                primary: root.canExportShare()
              }
              ActionRow {
                width: parent.width; rowId: "share-back"; glyph: ""
                title: "Choose another starting point"; subtitle: "discard this in-memory selection"
              }
            }

            ActionRow {
              width: parent.width
              rowId: "copy"
              glyph: ""
              title: "Copy the share command"
              subtitle: root.shareCommand
            }
            ActionRow {
              width: parent.width
              rowId: "folder"
              glyph: ""
              title: "Open the profile folder"
              subtitle: "open the selected Montage repository"
            }
          }

          // -------------------------------------------------- loadouts tab
          Column {
            visible: root.tab === "loadouts"
            width: parent.width
            spacing: Style.space(10)

            Text {
              width: parent.width
              text: "Applied loadouts are desired state already tracked on this machine. "
                + "Choose new repository loadouts from the Repositories tab. Mutation actions "
                + "open in a terminal so package, privilege, and cleanup decisions remain visible."
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              wrapMode: Text.WordWrap
            }

            Text {
              width: parent.width
              text: !engine.loadoutsAvailable
                ? (engine.loadingLoadouts ? "Loading applied loadouts…" : "Applied loadouts are unavailable")
                : Model.plural((engine.loadouts || []).length, "applied loadout")
              color: engine.loadoutsAvailable ? root.foreground : root.urgent
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
            }

            Repeater {
              model: engine.loadouts || []
              ActionRow {
                required property var modelData
                width: parent.width
                rowId: "loadout:" + modelData.id
                glyph: modelData.attentionCount > 0 ? "" : ""
                title: modelData.name
                subtitle: Model.loadoutState(modelData.state) + " · "
                  + Model.plural(modelData.resourceCount, "resource")
                  + (modelData.attentionCount > 0 ? " · " + modelData.attentionCount + " need attention" : "")
              }
            }

            Column {
              visible: root.selectedLoadout() !== null
              width: parent.width
              spacing: Style.space(6)

              Text {
                width: parent.width
                text: {
                  var item = root.selectedLoadout()
                  return item ? (item.name + " by " + item.author + "\n" + item.id + "\n" + item.source) : ""
                }
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                wrapMode: Text.WrapAnywhere
              }
              Text {
                width: parent.width
                text: {
                  var item = root.selectedLoadout()
                  return item ? Model.summarizeLoadoutContent(item.profile) : ""
                }
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
                wrapMode: Text.WordWrap
              }
              Text {
                width: parent.width
                text: {
                  var item = root.selectedLoadout()
                  return item ? Model.loadoutContentNames(item.profile) : ""
                }
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                wrapMode: Text.WordWrap
              }
              Repeater {
                model: {
                  var item = root.selectedLoadout()
                  return item && item.resources ? item.resources : []
                }
                Text {
                  required property var modelData
                  width: parent.width
                  text: Model.resourceHealth(modelData.healthState) !== "healthy"
                    ? "⚠ " + modelData.healthState + " · " + modelData.id
                    : modelData.healthState + " · " + modelData.id
                  color: Model.resourceHealth(modelData.healthState) === "healthy" ? root.dim : root.urgent
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  wrapMode: Text.WrapAnywhere
                }
              }
              ActionRow { width: parent.width; rowId: "loadout-update"; glyph: ""; title: "Update"; subtitle: "fetch and review changed content in a terminal" }
              ActionRow { width: parent.width; rowId: "loadout-repair"; glyph: ""; title: "Repair"; subtitle: "reinstall missing resources after review" }
              ActionRow { width: parent.width; rowId: "loadout-remove"; glyph: ""; title: "Remove loadout"; subtitle: "review cleanup and retention in a terminal" }
            }
          }
        }
      }
    }
  }

  // ------------------------------------------------------------- components

  component TabChip: CursorSurface {
    id: tabButton
    property string tabId: ""
    readonly property bool selected: root.tab === tabId

    current: tabButton.selected
    foreground: root.foreground
    implicitWidth: tabLabel.implicitWidth + Style.space(20)
    implicitHeight: tabLabel.implicitHeight + Style.space(10)

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: root.setTab(tabButton.tabId)
    }

    Text {
      id: tabLabel
      anchors.centerIn: parent
      text: tabButton.tabId.charAt(0).toUpperCase() + tabButton.tabId.slice(1)
      color: tabButton.selected ? root.foreground : root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
    }
  }

  component ActionRow: CursorSurface {
    id: actionRow
    property string rowId: ""
    property string glyph: ""
    property string title: ""
    property string subtitle: ""
    property bool trailing: false
    property bool trailingOn: false
    property bool actionable: true
    property bool primary: false

    hasCursor: root.hasCursor(actionRow.rowId)
    foreground: root.foreground
    implicitHeight: actionContent.implicitHeight + Style.spacing.rowPaddingX

    MouseArea {
      anchors.fill: parent
      enabled: actionRow.actionable
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onEntered: {
        root.cursorActive = true
        for (var i = 0; i < root.rows.length; i++)
          if (root.rows[i].id === actionRow.rowId) root.cursor = i
      }
      onClicked: root.trigger(actionRow.rowId)
    }

    RowLayout {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(10)
      anchors.rightMargin: Style.space(10)
      spacing: Style.space(10)

      Text {
        text: actionRow.glyph
        color: actionRow.actionable ? (actionRow.primary ? root.accent : root.foreground) : root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.icon
        Layout.alignment: Qt.AlignVCenter
      }

      ColumnLayout {
        id: actionContent
        Layout.fillWidth: true
        spacing: Style.space(1)

        Text {
          Layout.fillWidth: true
          text: actionRow.title
          color: actionRow.actionable ? (actionRow.primary ? root.accent : root.foreground) : root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          elide: Text.ElideRight
        }
        Text {
          Layout.fillWidth: true
          visible: actionRow.subtitle !== ""
          text: actionRow.subtitle
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideMiddle
        }
      }

      ToggleSwitch {
        visible: actionRow.trailing
        enabled: actionRow.actionable
        checked: actionRow.trailingOn
        hasCursor: actionRow.hasCursor
        foreground: root.foreground
        Layout.alignment: Qt.AlignVCenter
        onToggled: root.trigger(actionRow.rowId)
      }
    }
  }

  component CategoryRow: CursorSurface {
    id: categoryRow
    property var category: null
    readonly property string key: category ? category.key : ""
    readonly property bool on: engine.categoryEnabled(key)

    hasCursor: root.hasCursor("cat:" + key)
    foreground: root.foreground
    implicitHeight: categoryContent.implicitHeight + Style.spacing.rowPaddingX

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onEntered: {
        root.cursorActive = true
        for (var i = 0; i < root.rows.length; i++)
          if (root.rows[i].id === "cat:" + categoryRow.key) root.cursor = i
      }
      onClicked: root.trigger("cat:" + categoryRow.key)
    }

    RowLayout {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(10)
      anchors.rightMargin: Style.space(10)
      spacing: Style.space(10)

      ColumnLayout {
        id: categoryContent
        Layout.fillWidth: true
        spacing: Style.space(1)

        RowLayout {
          Layout.fillWidth: true
          spacing: Style.space(6)
          Text {
            text: categoryRow.category ? categoryRow.category.label : ""
            color: categoryRow.on ? root.foreground : root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
          }
          Text {
            visible: categoryRow.key === "secrets"
            text: "\uf023"
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }
          Item { Layout.fillWidth: true }
        }
        Text {
          Layout.fillWidth: true
          text: categoryRow.category ? categoryRow.category.detail : ""
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }
      }

      ToggleSwitch {
        checked: categoryRow.on
        hasCursor: categoryRow.hasCursor
        foreground: root.foreground
        Layout.alignment: Qt.AlignVCenter
        onToggled: root.trigger("cat:" + categoryRow.key)
      }
    }
  }
}
