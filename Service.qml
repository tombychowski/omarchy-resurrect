import QtQuick
import Quickshell
import Quickshell.Io
import "Model.js" as Model

// CLI-backed state and actions for the Loadout panel. This item has no file
// readers, Git calls, background jobs, or independent interpretation of Montage
// state. Every rich value is accepted only through a strict Model.js parser.
Item {
  id: root

  property bool panelOwned: true
  property bool uiActive: false
  readonly property string home: Quickshell.env("HOME")
  readonly property string cli: decodeURIComponent(Qt.resolvedUrl("bin/mntg").toString().replace(/^file:\/\//, ""))

  property var status: null
  property bool statusAvailable: false
  property bool loadingStatus: false
  readonly property string attention: statusAvailable ? status.attention : "unavailable-or-invalid"
  readonly property bool externallyBusy: statusAvailable && status.operation.active
  readonly property string aurMode: statusAvailable ? status.settings.aur : "ask"

  property var repositories: null
  property bool repositoriesAvailable: false
  property bool loadingRepositories: false
  property string selectedRepositoryName: ""
  property string selectedRepositoryId: ""
  property string selectedRepositoryPath: ""
  property string selectedRepositoryRemote: ""
  property var repositoryLoadouts: null
  property bool loadingRepositoryContent: false
  property string selectedRepositoryLoadoutId: ""

  property var loadouts: null
  property var loadoutInventory: null
  property var loadoutHealth: null
  property int loadoutInventoryExit: -1
  property int loadoutHealthExit: -1
  property bool loadoutsAvailable: false
  property bool loadingLoadouts: false

  property var shareCatalog: null
  property bool shareCatalogAvailable: false
  property bool loadingShareCatalog: false

  property var syncPreview: null
  property bool loadingSyncPreview: false
  property var ressPreview: null
  property bool loadingRessPreview: false

  property bool busy: false
  readonly property bool anyBusy: busy || externallyBusy
  property string busyAction: ""
  property string currentStep: ""
  property string lastResult: ""
  property string lastError: ""
  signal finished(string action, string state)

  function parseJson(text, parser) {
    try { return parser(JSON.parse(text || "{}")) }
    catch (e) { return null }
  }

  function refresh() {
    if (!statusProc.running) { loadingStatus = true; statusProc.running = true }
    refreshRepositories()
    refreshLoadouts()
  }

  function refreshRepositories() {
    if (repositoryListProc.running) return false
    loadingRepositories = true
    repositoryListProc.running = true
    return true
  }

  function refreshLoadouts() {
    if (loadoutProc.running || loadoutCheckProc.running) return false
    loadingLoadouts = true
    loadoutInventory = null
    loadoutHealth = null
    loadoutInventoryExit = -1
    loadoutHealthExit = -1
    loadoutProc.running = true
    loadoutCheckProc.running = true
    return true
  }

  function publishLoadouts() {
    if (loadoutInventoryExit !== 0 || (loadoutHealthExit !== 0 && loadoutHealthExit !== 1)) return
    if (loadoutInventory === null || loadoutHealth === null) return
    loadouts = Model.mergeLoadoutViews(loadoutInventory, loadoutHealth)
    loadoutsAvailable = loadouts !== null
    loadingLoadouts = false
  }

  function rejectLoadouts() {
    loadouts = null
    loadoutsAvailable = false
    loadingLoadouts = false
  }

  function selectRepository(name, path, id, remote) {
    selectedRepositoryName = String(name || "")
    selectedRepositoryPath = String(path || "")
    selectedRepositoryId = String(id || "")
    selectedRepositoryRemote = String(remote || "")
    selectedRepositoryLoadoutId = ""
    repositoryLoadouts = null
    shareCatalog = null
    shareCatalogAvailable = false
    syncPreview = null
    if (selectedRepositoryName === "" || repositoryLoadoutProc.running) return false
    loadingRepositoryContent = true
    repositoryLoadoutProc.command = [cli, "repository", "loadouts", selectedRepositoryName, "--json"]
    repositoryLoadoutProc.running = true
    return true
  }

  function selectRepositoryLoadout(id) {
    selectedRepositoryLoadoutId = String(id || "")
    shareCatalog = null
    shareCatalogAvailable = false
    return selectedRepositoryLoadoutId !== "" ? refreshShareCatalog() : false
  }

  function refreshShareCatalog(repositoryName, loadoutId) {
    var repo = String(repositoryName || selectedRepositoryName)
    var item = String(loadoutId || selectedRepositoryLoadoutId)
    if (shareCatalogProc.running || repo === "" || item === "") return false
    loadingShareCatalog = true
    shareCatalogProc.command = [cli, "share", "catalog", "--repository", repo,
                                "--loadout", item, "--json"]
    shareCatalogProc.running = true
    return true
  }

  function shareCustom(repositoryName, loadoutId, name, description, ids, acknowledgements) {
    var repo = String(repositoryName || selectedRepositoryName)
    var item = String(loadoutId || selectedRepositoryLoadoutId)
    if (repo === "" || item === "" || busy) return false
    var selected = (ids || []).slice().sort()
    var args = ["share", "--repository", repo, "--loadout", item, "--custom",
                "--name", String(name || ""), "--description", String(description || "")]
    for (var i = 0; i < selected.length; i++) args = args.concat(["--select", selected[i]])
    var acknowledged = []
    for (var id in (acknowledgements || {})) acknowledged.push(id)
    acknowledged.sort()
    for (var j = 0; j < acknowledged.length; j++)
      args = args.concat(["--acknowledge-unavailable", acknowledged[j], acknowledgements[acknowledged[j]]])
    return run(args, "share")
  }

  function previewSync(name) {
    var repository = String(name || selectedRepositoryName)
    if (repository === "" || syncPreviewProc.running) return false
    syncPreview = null
    loadingSyncPreview = true
    syncPreviewProc.command = [cli, "repository", "sync", repository, "--json"]
    syncPreviewProc.running = true
    return true
  }

  function previewRess(source, ressDecision, montageDecision) {
    if (String(source || "") === "" || ressPreviewProc.running) return false
    var args = [cli, "port", "ress", "inspect", String(source)]
    if (ressDecision === "include" || ressDecision === "omit")
      args = args.concat(["--ress-plugin", ressDecision])
    if (montageDecision === "include" || montageDecision === "omit")
      args = args.concat(["--montage-plugin", montageDecision])
    args.push("--json")
    ressPreview = null
    loadingRessPreview = true
    ressPreviewProc.command = args
    ressPreviewProc.running = true
    return true
  }

  function run(args, action) {
    if (busy) return false
    busy = true
    busyAction = action
    currentStep = ""
    lastResult = ""
    lastError = ""
    worker.command = [cli, "--porcelain"].concat(args)
    worker.running = true
    return true
  }

  function handleRecord(line) {
    var record = Model.parseRecord(line)
    if (!record) return
    if (record.type === "step") currentStep = record.message
    if (record.type === "done") lastResult = record.state
  }

  function openRepositoryConfigure(name, path, remote, replace) {
    var args = ["omarchy-launch-terminal", cli, "repository", "configure", name, path]
    var cleanRemote = Model.stripCredentials(remote)
    if (cleanRemote !== "") args = args.concat(["--remote", cleanRemote])
    if (replace) args.push("--replace")
    Quickshell.execDetached(args)
  }

  function openRepositoryApply(source, loadoutId, dryRun) {
    var args = ["omarchy-launch-terminal", cli]
    if (dryRun) args.push("--dry-run")
    args = args.concat(["apply", source, "--loadout", loadoutId])
    Quickshell.execDetached(args)
  }

  function openLoadoutAction(action, id) {
    Quickshell.execDetached(["omarchy-launch-terminal", cli, "loadout", action, id])
  }

  function openSync(name, action) {
    var args = ["omarchy-launch-terminal", cli, "repository", "sync", name]
    if (action === "pull" || action === "push") args.push("--" + action)
    Quickshell.execDetached(args)
  }

  function openRessImport(source, repositoryName, loadoutId, ressDecision, montageDecision) {
    var args = ["omarchy-launch-terminal", cli, "port", "ress", "import", "loadout",
                source, "--repository", repositoryName, "--loadout", loadoutId]
    if (ressDecision === "include" || ressDecision === "omit")
      args = args.concat(["--ress-plugin", ressDecision])
    if (montageDecision === "include" || montageDecision === "omit")
      args = args.concat(["--montage-plugin", montageDecision])
    Quickshell.execDetached(args)
  }

  function setAur(value) {
    if (["ask", "yes", "no"].indexOf(value) >= 0)
      Quickshell.execDetached([cli, "set", "AUR=" + value])
  }

  Process {
    id: worker
    command: []
    stdout: SplitParser { onRead: function(data) { root.handleRecord(data) } }
    stderr: SplitParser { onRead: function(data) { if (data) root.lastError = String(data) } }
    onExited: function(exitCode) {
      root.busy = false
      if (exitCode !== 0 && root.lastError === "") root.lastError = "exited with code " + exitCode
      root.finished(root.busyAction, root.lastResult || (exitCode === 0 ? "ok" : "fail"))
      root.refresh()
      if (root.busyAction === "share") root.refreshShareCatalog()
    }
  }

  Process {
    id: statusProc
    command: [root.cli, "status", "--json"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var parsed = root.parseJson(text, Model.parseStatus)
        root.status = parsed
        root.statusAvailable = parsed !== null
        root.loadingStatus = false
      }
    }
    onExited: function(exitCode) {
      root.loadingStatus = false
      if (exitCode !== 0) { root.status = null; root.statusAvailable = false }
    }
  }

  Process {
    id: repositoryListProc
    command: [root.cli, "repository", "list", "--json"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var parsed = root.parseJson(text, Model.parseRepositoryList)
        root.repositories = parsed
        root.repositoriesAvailable = parsed !== null
        root.loadingRepositories = false
      }
    }
    onExited: function(exitCode) {
      root.loadingRepositories = false
      if (exitCode !== 0) { root.repositories = null; root.repositoriesAvailable = false }
    }
  }

  Process {
    id: repositoryLoadoutProc
    command: []
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.repositoryLoadouts = root.parseJson(text, Model.parseLoadoutCatalog)
        root.loadingRepositoryContent = false
      }
    }
    onExited: function(exitCode) {
      root.loadingRepositoryContent = false
      if (exitCode !== 0) root.repositoryLoadouts = null
    }
  }

  Process {
    id: loadoutProc
    command: [root.cli, "loadout", "list", "--json", "--contents"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var parsed = root.parseJson(text, Model.parseLoadoutList)
        root.loadoutInventory = parsed
        if (parsed === null) root.rejectLoadouts()
        else root.publishLoadouts()
      }
    }
    onExited: function(exitCode) {
      root.loadoutInventoryExit = exitCode
      if (exitCode !== 0) root.rejectLoadouts()
      else root.publishLoadouts()
    }
  }

  Process {
    id: loadoutCheckProc
    command: [root.cli, "loadout", "check", "--json"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var parsed = root.parseJson(text, Model.parseLoadoutCheck)
        root.loadoutHealth = parsed
        if (parsed === null) root.rejectLoadouts()
        else root.publishLoadouts()
      }
    }
    onExited: function(exitCode) {
      root.loadoutHealthExit = exitCode
      if (exitCode !== 0 && exitCode !== 1) root.rejectLoadouts()
      else root.publishLoadouts()
    }
  }

  Process {
    id: shareCatalogProc
    command: []
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var parsed = root.parseJson(text, Model.parseShareCatalog)
        root.shareCatalog = parsed
        root.shareCatalogAvailable = parsed !== null
        root.loadingShareCatalog = false
      }
    }
    onExited: function(exitCode) {
      root.loadingShareCatalog = false
      if (exitCode !== 0) { root.shareCatalog = null; root.shareCatalogAvailable = false }
    }
  }

  Process {
    id: syncPreviewProc
    command: []
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.syncPreview = root.parseJson(text, Model.parseSyncResult)
        root.loadingSyncPreview = false
      }
    }
    onExited: function(exitCode) {
      root.loadingSyncPreview = false
      if (exitCode !== 0 && root.syncPreview === null) root.lastError = "Library sync preview is unavailable"
    }
  }

  Process {
    id: ressPreviewProc
    command: []
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.ressPreview = root.parseJson(text, Model.parseRessMigration)
        root.loadingRessPreview = false
      }
    }
    onExited: function(exitCode) {
      root.loadingRessPreview = false
      if (root.ressPreview === null && exitCode !== 0) root.lastError = "Ress migration preview is unavailable"
    }
  }

  Timer {
    interval: 30000
    repeat: true
    running: root.uiActive
    onTriggered: if (!root.loadingStatus) { root.loadingStatus = true; statusProc.running = true }
  }

  Component.onCompleted: refresh()
}
