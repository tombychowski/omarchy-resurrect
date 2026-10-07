.pragma library

// Formatting helpers shared by the panel and the bar icon. Kept out of QML so
// the bindings above read as layout, not arithmetic.

var CATEGORIES = [
  { key: "packages", label: "Packages",  detail: "Explicit pacman and AUR packages" },
  { key: "config",   label: "Dotfiles",  detail: "Shell, Hyprland, terminals, editors" },
  { key: "omarchy",  label: "Omarchy",   detail: "Bar layout, themes, hooks, extensions" },
  { key: "webapps",  label: "Web apps",  detail: "Launchers made with omarchy webapp" },
  { key: "plugins",  label: "Plugins",   detail: "Shell plugins, by git remote" },
  { key: "secrets",  label: "Secrets",   detail: "Encrypted with age. Off by default" }
]

function ago(epochSeconds, nowSeconds) {
  if (!epochSeconds) return "never"
  var d = Math.max(0, nowSeconds - epochSeconds)
  if (d < 60) return "just now"
  if (d < 3600) return Math.floor(d / 60) + "m ago"
  if (d < 86400) return Math.floor(d / 3600) + "h ago"
  if (d < 2592000) return Math.floor(d / 86400) + "d ago"
  return Math.floor(d / 2592000) + "mo ago"
}

// Three states, because that is how often you actually care: it is current,
// it is getting old, or there is nothing to restore from.
function freshness(epochSeconds, nowSeconds, staleHours) {
  if (!epochSeconds) return "none"
  var age = Math.max(0, nowSeconds - epochSeconds)
  return age > (staleHours || 48) * 3600 ? "stale" : "fresh"
}

// A remote may carry a token (https://TOKEN@host/…). The CLI strips it before
// writing it to a config file; the panel strips it before putting it on screen.
function stripCredentials(url) {
  return String(url || "").replace(/^([a-z][a-z0-9+.-]*:\/\/)[^\/@]*@/, "$1")
}

function isRessLocation(path) {
  var value = String(path || "").replace(/\/+$/, "")
  return /(^|\/)ress(\/|$)/.test(value) || /\/\.local\/share\/resurrect(\/|$)/.test(value) ||
    /\/\.config\/resurrect(\/|$)/.test(value) || /\/\.local\/state\/resurrect(\/|$)/.test(value)
}

function plural(n, one, many) {
  return n + " " + (n === 1 ? one : (many || one + "s"))
}

// A consent setting has three states, and none of them is well described by
// "on". Said in words here, so the panel and the CLI agree on what ask means.
function consent(value, whenYes, whenNo, whenAsk) {
  if (value === "yes") return whenYes
  if (value === "no") return whenNo
  return whenAsk
}

function summarize(counts) {
  if (!counts) return ""
  return [
    plural(counts.packages || 0, "package"),
    plural(counts.config || 0, "config path"),
    plural(counts.webapps || 0, "web app"),
    plural(counts.plugins || 0, "plugin")
  ].join(" · ")
}

// The CLI's --porcelain protocol. One record per line, pipe separated.
function parseRecord(line) {
  var parts = String(line || "").split("|")
  switch (parts[0]) {
    case "BEGIN":    return { type: "begin", action: parts[1], vault: parts[2] }
    case "STEP":     return { type: "step", category: parts[1], state: parts[2], message: parts.slice(3).join("|") }
    case "PROGRESS": return { type: "progress", category: parts[1], done: Number(parts[2]), total: Number(parts[3]) }
    case "LOG":      return { type: "log", message: parts.slice(1).join("|") }
    case "SYNC":
      if (parts[1] !== "1") return null
      return { type: "sync", schemaVersion: 1, status: parts[2], ahead: Number(parts[3]),
        behind: Number(parts[4]), fetchOk: parts[5] === "true", performed: parts[6],
        actionOk: parts[7] === "true", reason: parts.slice(8).join("|") }
    case "PORT":
      if (parts[1] !== "1") return null
      return { type: "port", schemaVersion: 1, operation: parts[2], artifactType: parts[3],
        compatible: parts[4] === "true", published: parts[5] === "true",
        reason: parts.slice(6).join("|") }
    case "PORT_IDENTITY": return { type: "portIdentity", values: parts.slice(1) }
    case "PORT_REVISION": return { type: "portRevision", values: parts.slice(1) }
    case "PORT_LOSS": return { type: "portLoss", values: parts.slice(1) }
    case "DONE":     return { type: "done", state: parts[1], message: parts.slice(2).join("|") }
  }
  return null
}

function versioned(value, kind) {
  return !!value && value.schemaVersion === 1 && value.kind === kind
}

function nonemptyString(value) {
  return typeof value === "string" && value.length > 0
}

function nullableCommit(value) {
  return value === null || (typeof value === "string" && (/^[0-9a-f]{40}$/).test(value))
}

var REPOSITORY_TYPES = ["loadouts", "vault"]
var SYNC_STATES = ["equal", "local-ahead", "remote-ahead", "divergent", "invalid-remote",
  "invalid-repository", "no-local-history", "fetch-failed"]

function parseRepositoryList(value) {
  if (!versioned(value, "montage-repository-list") || typeof value.revision !== "number" ||
      !Array.isArray(value.repositories)) return null
  var names = {}
  for (var i = 0; i < value.repositories.length; i++) {
    var item = value.repositories[i]
    if (!item || !nonemptyString(item.name) || names[item.name] ||
        REPOSITORY_TYPES.indexOf(item.type) < 0 || !nonemptyString(item.path) ||
        typeof item.id !== "string" || typeof item.remote !== "string" ||
        typeof item.valid !== "boolean" || !nonemptyString(item.status)) return null
    names[item.name] = true
  }
  return value
}

function parseLoadoutCatalog(value) {
  if (!versioned(value, "montage-loadout-catalog") || !nonemptyString(value.repositoryId) ||
      !nullableCommit(value.repositoryCommit) || !Array.isArray(value.items) ||
      !Array.isArray(value.invalid)) return null
  var ids = {}
  for (var i = 0; i < value.items.length; i++) {
    var item = value.items[i]
    if (!item || !nonemptyString(item.id) || ids[item.id] || !nonemptyString(item.name) ||
        !nonemptyString(item.repositoryId) || item.repositoryId !== value.repositoryId ||
        item.repositoryCommit !== value.repositoryCommit || !nonemptyString(item.digest)) return null
    ids[item.id] = true
  }
  for (var j = 0; j < value.invalid.length; j++) {
    var invalid = value.invalid[j]
    if (!invalid || !nonemptyString(invalid.id) || !nonemptyString(invalid.reason)) return null
  }
  return value
}

function parseBackupList(value) {
  if (!versioned(value, "montage-backup-list") || !nonemptyString(value.repositoryId) ||
      !Array.isArray(value.backups)) return null
  var commits = {}
  for (var i = 0; i < value.backups.length; i++) {
    var backup = value.backups[i]
    if (!backup || !(/^[0-9a-f]{40}$/).test(backup.commit || "") || commits[backup.commit] ||
        !nonemptyString(backup.createdAt) || !Array.isArray(backup.labels) ||
        !backup.counts || !backup.sourceMachine) return null
    commits[backup.commit] = true
  }
  return value
}

function parseRetentionResult(value) {
  if (!versioned(value, "montage-backup-retention") || !nonemptyString(value.repositoryId) ||
      typeof value.keep !== "number" || typeof value.changed !== "boolean" ||
      !Array.isArray(value.kept) || !Array.isArray(value.removed) ||
      !Array.isArray(value.protectedLabels) || typeof value.blocked !== "boolean" ||
      typeof value.remoteDivergence !== "boolean") return null
  return value
}

function parseSyncResult(value) {
  if (!versioned(value, "montage-repository-sync") || !nonemptyString(value.repositoryId) ||
      REPOSITORY_TYPES.indexOf(value.repositoryType) < 0 || SYNC_STATES.indexOf(value.status) < 0 ||
      typeof value.ahead !== "number" || typeof value.behind !== "number" ||
      !value.fetch || typeof value.fetch.ok !== "boolean") return null
  if (value.remote && stripCredentials(value.remote) !== value.remote) return null
  return value
}

function parsePortReport(value) {
  if (!versioned(value, "montage-port-report") || !nonemptyString(value.operation) ||
      !nonemptyString(value.artifactType) || !/^[a-z0-9][a-z0-9-]{0,31}$/.test(value.artifactType) ||
      !nonemptyString(value.format) || !/^[a-z0-9][a-z0-9-]{0,31}$/.test(value.format) ||
      typeof value.compatible !== "boolean" ||
      !Array.isArray(value.selectedRevisions) || !Array.isArray(value.warnings) ||
      !Array.isArray(value.losses) || !Array.isArray(value.mutations) ||
      !nonemptyString(value.source)) return null
  return value
}

// One vocabulary for the repository surfaces. Consumers pass only validated
// CLI results; null means invalid/unavailable rather than an empty catalog.
function repositoryPanelState(loading, repositories, selected, content, sync) {
  if (loading) return "loading"
  if (!repositories) return "invalid"
  if (repositories.repositories.length === 0) return "empty"
  if (!selected) return "attention"
  if (!selected.valid || !content) return "invalid"
  if (sync && sync.status === "divergent") return "divergent"
  if (sync && sync.status === "remote-ahead") return "stale"
  if (sync && ["fetch-failed", "invalid-remote", "invalid-repository", "no-local-history"].indexOf(sync.status) >= 0)
    return "attention"
  if (selected.type === "loadouts") {
    if (content.invalid.length > 0) return "attention"
    if (content.items.length === 0) return "empty"
  } else if (selected.type === "vault" && content.backups.length === 0) return "empty"
  return "healthy"
}

var LOADOUT_STATES = ["healthy", "pending", "drifted", "conflicting", "removal-pending", "unavailable"]
var RESOURCE_STATES = ["present", "missing", "modified", "conflicting", "protected", "pending", "failed", "uncertain", "unverifiable"]

function loadoutState(state) {
  switch (state) {
    case "healthy": return "Healthy"
    case "pending": return "Pending work"
    case "drifted": return "Needs repair"
    case "conflicting": return "Conflict"
    case "removal-pending": return "Removal pending"
    default: return "Unavailable"
  }
}

function resourceHealth(state) {
  if (state === "present" || state === "protected") return "healthy"
  if (state === "missing" || state === "pending") return "attention"
  if (state === "modified" || state === "conflicting" || state === "failed") return "warning"
  return "unknown"
}

// Consumer validation stays deliberately small and strict. A malformed CLI
// answer is unavailable state, never an invented empty/healthy dashboard.
function parseLoadoutList(value) {
  if (!versioned(value, "montage-applied-loadout-list") || !Array.isArray(value.loadouts)) return null
  var out = []
  for (var i = 0; i < value.loadouts.length; i++) {
    var item = value.loadouts[i]
    if (!item || typeof item.id !== "string" || typeof item.name !== "string" ||
        LOADOUT_STATES.indexOf(item.state) < 0 ||
        typeof item.resourceCount !== "number" || typeof item.attentionCount !== "number") return null
    out.push(item)
  }
  return out
}

function parseLoadoutCheck(value) {
  if (!versioned(value, "montage-loadout-check") ||
      typeof value.healthy !== "boolean" || !Array.isArray(value.loadouts)) return null
  var out = []
  for (var i = 0; i < value.loadouts.length; i++) {
    var item = value.loadouts[i]
    if (!item || typeof item.id !== "string" || typeof item.name !== "string" ||
        LOADOUT_STATES.indexOf(item.state) < 0 || typeof item.attentionCount !== "number" ||
        !Array.isArray(item.resources)) return null
    for (var j = 0; j < item.resources.length; j++) {
      var resource = item.resources[j]
      if (!resource || typeof resource.id !== "string" ||
          RESOURCE_STATES.indexOf(resource.currentState) < 0 ||
          RESOURCE_STATES.indexOf(resource.healthState) < 0) return null
    }
    out.push(item)
  }
  return out
}

function mergeLoadoutViews(inventory, health) {
  if (!Array.isArray(inventory) || !Array.isArray(health)) return null
  var byId = {}
  for (var i = 0; i < health.length; i++) byId[health[i].id] = health[i]
  var out = []
  for (var j = 0; j < inventory.length; j++) {
    var stored = inventory[j]
    var live = byId[stored.id]
    if (!live) return null
    var merged = {}
    for (var key in stored) merged[key] = stored[key]
    merged.state = live.state
    merged.attentionCount = live.attentionCount
    merged.resources = live.resources
    out.push(merged)
  }
  return out
}

function summarizeLoadoutContent(profile) {
  if (!profile || !profile.packages) return "Content unavailable"
  var packages = (profile.packages.native || []).length + (profile.packages.aur || []).length
  var plugins = (profile.plugins || []).length
  var webapps = (profile.webapps || []).length
  var parts = [plural(packages, "package"), plural(plugins, "plugin"), plural(webapps, "web app")]
  if (profile.theme && profile.theme.name) parts.push("theme " + profile.theme.name)
  return parts.join(" · ")
}

function loadoutContentNames(profile) {
  if (!profile || !profile.packages) return ""
  var names = (profile.packages.native || []).concat(profile.packages.aur || [])
  var plugins = profile.plugins || []
  var webapps = profile.webapps || []
  for (var i = 0; i < plugins.length; i++) names.push(plugins[i].id)
  for (var j = 0; j < webapps.length; j++) names.push(webapps[j].name)
  if (profile.theme && profile.theme.name) names.push(profile.theme.name)
  return names.join(" · ")
}

var SHARE_KINDS = ["package", "plugin", "webapp", "theme"]
var SHARE_EXPORT_STATES = ["valid", "absent", "unavailable"]
var SHARE_PRESET_STATES = ["valid", "unavailable"]
var SHARE_REASON_CODES = ["", "missing-manifest", "unsafe-id", "missing-remote",
  "unsafe-remote", "unpinned", "unsupported-launcher", "unsafe-name",
  "unsafe-icon", "local-only", "missing-theme"]
var SHARE_CURRENT_REASON_CODES = ["missing", "definition-mismatch"].concat(SHARE_REASON_CODES)
var SHARE_WARNING_STATES = ["unavailable", "present", "missing", "modified",
  "conflicting", "protected", "pending", "deferred", "failed", "uncertain",
  "unverifiable", "removal-pending"].concat(SHARE_REASON_CODES)

function uniqueStrings(values) {
  if (!Array.isArray(values)) return false
  var seen = {}
  for (var i = 0; i < values.length; i++) {
    if (typeof values[i] !== "string" || seen[values[i]]) return false
    seen[values[i]] = true
  }
  return true
}

// The composer accepts one complete, versioned CLI answer or no answer. It
// never fills holes by reading package, profile, or registry state itself.
function parseShareCatalog(value) {
  if (!versioned(value, "montage-share-catalog") || !Array.isArray(value.resources) ||
      !value.currentExport || !value.presets || !value.counts || !value.limits ||
      value.limits.themes !== 1)
    return null

  var ids = {}
  for (var i = 0; i < value.resources.length; i++) {
    var resource = value.resources[i]
    if (!resource || typeof resource.id !== "string" || resource.id === "" || ids[resource.id] ||
        SHARE_KINDS.indexOf(resource.kind) < 0 || typeof resource.name !== "string" ||
        typeof resource.shareable !== "boolean" || typeof resource.reasonCode !== "string" ||
        typeof resource.reason !== "string" || !uniqueStrings(resource.channels) ||
        SHARE_REASON_CODES.indexOf(resource.reasonCode) < 0 || typeof resource.active !== "boolean") return null
    for (var channel = 0; channel < resource.channels.length; channel++)
      if (resource.channels[channel] !== "native" && resource.channels[channel] !== "aur") return null
    if ((resource.kind === "package") !== (resource.channels.length > 0)) return null
    if (resource.kind !== "theme" && resource.active) return null
    var identityPrefix = resource.kind === "theme" ? "theme-install:" : resource.kind + ":"
    if (resource.id.indexOf(identityPrefix) !== 0 &&
        resource.id.indexOf("unavailable:" + resource.kind + ":") !== 0) return null
    if (!resource.shareable && resource.reasonCode === "") return null
    if (resource.shareable && resource.reasonCode !== "") return null
    ids[resource.id] = resource
  }

  for (var countKind in value.counts)
    if (SHARE_KINDS.indexOf(countKind) < 0 || typeof value.counts[countKind] !== "number" ||
        value.counts[countKind] < 0 || Math.floor(value.counts[countKind]) !== value.counts[countKind]) return null
  for (var expectedKind = 0; expectedKind < SHARE_KINDS.length; expectedKind++) {
    var kind = SHARE_KINDS[expectedKind], actualCount = 0
    for (var counted = 0; counted < value.resources.length; counted++)
      if (value.resources[counted].kind === kind) actualCount++
    if ((value.counts[kind] || 0) !== actualCount) return null
  }

  var current = value.currentExport
  if (SHARE_EXPORT_STATES.indexOf(current.state) < 0 || typeof current.name !== "string" ||
      typeof current.description !== "string" || !uniqueStrings(current.resourceIds) ||
      !Array.isArray(current.unavailable)) return null
  if (current.state === "unavailable" &&
      (current.reasonCode !== "invalid-profile" || typeof current.reason !== "string")) return null
  if (current.state !== "valid" && (current.resourceIds.length !== 0 || current.unavailable.length !== 0)) return null
  for (var c = 0; c < current.resourceIds.length; c++)
    if (!ids[current.resourceIds[c]] || !ids[current.resourceIds[c]].shareable) return null
  for (var u = 0; u < current.unavailable.length; u++) {
    var unavailable = current.unavailable[u]
    if (!unavailable || typeof unavailable.id !== "string" ||
        SHARE_KINDS.indexOf(unavailable.kind) < 0 || typeof unavailable.name !== "string" ||
        typeof unavailable.reasonCode !== "string" || unavailable.reasonCode === "" ||
        SHARE_CURRENT_REASON_CODES.indexOf(unavailable.reasonCode) < 0 ||
        typeof unavailable.reason !== "string" || typeof unavailable.fingerprint !== "string" ||
        !/^[0-9a-f]{64}$/.test(unavailable.fingerprint)) return null
  }

  var presets = value.presets
  if (SHARE_PRESET_STATES.indexOf(presets.state) < 0 || !Array.isArray(presets.loadouts)) return null
  if (presets.state === "unavailable" &&
      (presets.reasonCode !== "invalid-registry" || typeof presets.reason !== "string" ||
       presets.loadouts.length !== 0)) return null
  for (var p = 0; p < presets.loadouts.length; p++) {
    var preset = presets.loadouts[p]
    if (!preset || typeof preset.id !== "string" || typeof preset.name !== "string" ||
        !uniqueStrings(preset.resourceIds) || !Array.isArray(preset.warnings)) return null
    for (var r = 0; r < preset.resourceIds.length; r++)
      if (!ids[preset.resourceIds[r]] || !ids[preset.resourceIds[r]].shareable) return null
    for (var w = 0; w < preset.warnings.length; w++)
      if (!preset.warnings[w] || typeof preset.warnings[w].id !== "string" ||
          typeof preset.warnings[w].state !== "string" ||
          SHARE_WARNING_STATES.indexOf(preset.warnings[w].state) < 0) return null
  }
  return value
}

function shareResourceById(catalog, id) {
  if (!catalog || !Array.isArray(catalog.resources)) return null
  for (var i = 0; i < catalog.resources.length; i++)
    if (catalog.resources[i].id === id) return catalog.resources[i]
  return null
}

function sharePresetById(catalog, id) {
  if (!catalog || !catalog.presets || !Array.isArray(catalog.presets.loadouts)) return null
  for (var i = 0; i < catalog.presets.loadouts.length; i++)
    if (catalog.presets.loadouts[i].id === id) return catalog.presets.loadouts[i]
  return null
}

function sharePresetWarnings(preset) {
  if (!preset || !Array.isArray(preset.warnings)) return ""
  var parts = []
  for (var i = 0; i < preset.warnings.length; i++)
    parts.push(preset.warnings[i].id + " (" + preset.warnings[i].state + ")")
  return parts.join(" · ")
}

function shareSelection(catalog, source, presetId) {
  var result = {}
  if (!catalog) return result
  var values = []
  if (source === "all") {
    for (var i = 0; i < catalog.resources.length; i++)
      if (catalog.resources[i].shareable &&
          (catalog.resources[i].kind !== "theme" || catalog.resources[i].active))
        values.push(catalog.resources[i].id)
  } else if (source === "current" && catalog.currentExport.state === "valid") {
    values = catalog.currentExport.resourceIds
  } else if (source === "preset") {
    var preset = sharePresetById(catalog, presetId)
    if (preset) values = preset.resourceIds
  }
  for (var j = 0; j < values.length; j++) result[values[j]] = true
  return result
}

function selectedShareIds(selection) {
  var ids = []
  if (!selection) return ids
  for (var id in selection) if (selection[id]) ids.push(id)
  ids.sort()
  return ids
}

function shareCounts(catalog, selection) {
  var counts = { package: 0, plugin: 0, webapp: 0, theme: 0, total: 0 }
  if (!catalog) return counts
  var ids = selectedShareIds(selection)
  for (var i = 0; i < ids.length; i++) {
    var resource = shareResourceById(catalog, ids[i])
    if (!resource) continue
    counts[resource.kind] += 1
    counts.total += 1
  }
  return counts
}

function toggleShareResource(catalog, selection, id) {
  var next = {}, key
  for (key in (selection || {})) if (selection[key]) next[key] = true
  var resource = shareResourceById(catalog, id)
  if (!resource || !resource.shareable) return next
  if (next[id]) { delete next[id]; return next }
  if (resource.kind === "theme") {
    for (key in next) {
      var selected = shareResourceById(catalog, key)
      if (selected && selected.kind === "theme") delete next[key]
    }
  }
  next[id] = true
  return next
}

function addSharePreset(catalog, selection, presetId) {
  var next = {}, key, selectedTheme = "", conflict = ""
  for (key in (selection || {})) if (selection[key]) {
    next[key] = true
    var current = shareResourceById(catalog, key)
    if (current && current.kind === "theme") selectedTheme = key
  }
  var preset = sharePresetById(catalog, presetId)
  if (!preset) return { selection: next, themeConflict: "" }
  for (var i = 0; i < preset.resourceIds.length; i++) {
    var id = preset.resourceIds[i]
    var resource = shareResourceById(catalog, id)
    if (!resource) continue
    if (resource.kind === "theme" && selectedTheme !== "" && selectedTheme !== id) {
      conflict = id
      continue
    }
    next[id] = true
    if (resource.kind === "theme") selectedTheme = id
  }
  return { selection: next, themeConflict: conflict }
}

function filterShareResources(catalog, kind, query, limit) {
  if (!catalog) return []
  var out = [], needle = String(query || "").toLowerCase()
  var max = Math.max(1, Math.min(500, Number(limit) || 200))
  for (var i = 0; i < catalog.resources.length && out.length < max; i++) {
    var resource = catalog.resources[i]
    if (kind && resource.kind !== kind) continue
    if (needle && resource.name.toLowerCase().indexOf(needle) < 0 &&
        resource.id.toLowerCase().indexOf(needle) < 0) continue
    out.push(resource)
  }
  return out
}

function unacknowledgedShareResources(catalog, acknowledgements) {
  if (!catalog || catalog.currentExport.state !== "valid") return []
  var out = [], accepted = acknowledgements || {}
  for (var i = 0; i < catalog.currentExport.unavailable.length; i++) {
    var item = catalog.currentExport.unavailable[i]
    if (accepted[item.id] !== item.fingerprint) out.push(item)
  }
  return out
}
