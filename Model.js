.pragma library

// Strict adapters for the CLI-owned Loadout protocol. A rejected value is
// represented as null; consumers never turn malformed output into empty or
// healthy state.

var ATTENTION_STATES = ["healthy", "update-available", "repair-needed", "drifted",
  "repository-attention", "unavailable-or-invalid", "operation-partial-or-failed",
  "operation-active"]
var LOADOUT_STATES = ["healthy", "pending", "drifted", "conflicting",
  "removal-pending", "unavailable"]
var RESOURCE_STATES = ["present", "missing", "modified", "conflicting", "protected",
  "pending", "failed", "uncertain", "unverifiable"]
var SYNC_STATES = ["equal", "local-ahead", "remote-ahead", "divergent", "invalid-remote",
  "invalid-repository", "no-local-history", "fetch-failed"]
var SHARE_KINDS = ["package", "plugin", "webapp", "theme"]

function versioned(value, kind) {
  return !!value && value.schemaVersion === 1 && value.kind === kind
}

function nonemptyString(value) {
  return typeof value === "string" && value.length > 0
}

function uniqueStrings(values) {
  if (!Array.isArray(values)) return false
  var seen = {}
  for (var i = 0; i < values.length; i++) {
    if (typeof values[i] !== "string" || seen[values[i]]) return false
    seen[values[i]] = true
  }
  return true
}

function stripCredentials(url) {
  return String(url || "").replace(/^([a-z][a-z0-9+.-]*:\/\/)[^\/@]*@/, "$1")
}

function plural(n, one, many) {
  return n + " " + (n === 1 ? one : (many || one + "s"))
}

function consent(value) {
  if (value === "yes") return "build without asking"
  if (value === "no") return "never build"
  return "ask before building · recommended"
}

function attentionLabel(value) {
  switch (value) {
    case "healthy": return "Loadouts healthy"
    case "update-available": return "Update available"
    case "repair-needed": return "Repair needed"
    case "drifted": return "Loadout drift detected"
    case "repository-attention": return "Library needs attention"
    case "operation-active": return "Loadout operation active"
    case "operation-partial-or-failed": return "Operation needs review"
    default: return "Loadout status unavailable"
  }
}

function attentionTone(value) {
  if (value === "healthy") return "healthy"
  if (value === "operation-active") return "active"
  if (value === "update-available") return "update"
  return "attention"
}

function parseStatus(value) {
  if (!versioned(value, "montage-status") || ATTENTION_STATES.indexOf(value.attention) < 0 ||
      !Array.isArray(value.causes) || !value.operation || typeof value.operation.active !== "boolean" ||
      typeof value.operation.valid !== "boolean" || !value.loadouts || !value.repositories ||
      typeof value.loadouts.available !== "boolean" ||
      typeof value.loadouts.evidenceValid !== "boolean" ||
      typeof value.repositories.available !== "boolean" ||
      !Array.isArray(value.loadouts.items) || !Array.isArray(value.repositories.items) ||
      !value.settings || ["ask", "yes", "no"].indexOf(value.settings.aur) < 0) return null
  if (value.loadouts.available && (typeof value.loadouts.count !== "number" ||
      typeof value.loadouts.attention !== "number" ||
      typeof value.loadouts.updateAvailable !== "number")) return null
  if (value.repositories.available && (typeof value.repositories.count !== "number" ||
      typeof value.repositories.attention !== "number")) return null
  return value
}

function parseRecord(line) {
  var parts = String(line || "").split("|")
  switch (parts[0]) {
    case "BEGIN": return { type: "begin", action: parts[1], values: parts.slice(2) }
    case "STEP": return { type: "step", category: parts[1], state: parts[2], message: parts.slice(3).join("|") }
    case "LOG": return { type: "log", message: parts.slice(1).join("|") }
    case "MIGRATION": return parts[1] === "1" ? { type: "migration", values: parts.slice(2) } : null
    case "STATUS": return parts[1] === "1" ? { type: "status", attention: parts[2] } : null
    case "SYNC": return parts[1] === "1" ? { type: "sync", status: parts[2] } : null
    case "RESS": return parts[1] === "1" ? { type: "ress", operation: parts[2] } : null
    case "RESS_LOSS": return { type: "ressLoss", code: parts[1], decision: parts[2] }
    case "DONE": return { type: "done", state: parts[1], message: parts.slice(2).join("|") }
  }
  return null
}

function parseRepositoryList(value) {
  if (!versioned(value, "montage-repository-list") || typeof value.revision !== "number" ||
      !Array.isArray(value.repositories)) return null
  var names = {}
  for (var i = 0; i < value.repositories.length; i++) {
    var item = value.repositories[i]
    if (!item || !nonemptyString(item.name) || names[item.name] || item.type !== "loadouts" ||
        !nonemptyString(item.path) || !nonemptyString(item.id) || typeof item.remote !== "string" ||
        stripCredentials(item.remote) !== item.remote || typeof item.valid !== "boolean" ||
        !nonemptyString(item.status)) return null
    names[item.name] = true
  }
  return value
}

function parseLoadoutCatalog(value) {
  if (!versioned(value, "montage-loadout-catalog") || !nonemptyString(value.repositoryId) ||
      !Array.isArray(value.items) || !Array.isArray(value.invalid)) return null
  var ids = {}
  for (var i = 0; i < value.items.length; i++) {
    var item = value.items[i]
    if (!item || !nonemptyString(item.id) || ids[item.id] || !nonemptyString(item.name) ||
        item.repositoryId !== value.repositoryId || !nonemptyString(item.digest)) return null
    ids[item.id] = true
  }
  for (var j = 0; j < value.invalid.length; j++)
    if (!value.invalid[j] || !nonemptyString(value.invalid[j].id) ||
        !nonemptyString(value.invalid[j].reason)) return null
  return value
}

function parseSyncResult(value) {
  if (!versioned(value, "montage-repository-sync") || !nonemptyString(value.repositoryId) ||
      value.repositoryType !== "loadouts" || SYNC_STATES.indexOf(value.status) < 0 ||
      typeof value.ahead !== "number" || typeof value.behind !== "number" ||
      !value.fetch || typeof value.fetch.ok !== "boolean" ||
      (value.remote && stripCredentials(value.remote) !== value.remote)) return null
  return value
}

function parseLoadoutList(value) {
  if (!versioned(value, "montage-applied-loadout-list") || !Array.isArray(value.loadouts)) return null
  for (var i = 0; i < value.loadouts.length; i++) {
    var item = value.loadouts[i]
    if (!item || !nonemptyString(item.id) || typeof item.name !== "string" ||
        LOADOUT_STATES.indexOf(item.state) < 0 || typeof item.resourceCount !== "number" ||
        typeof item.attentionCount !== "number") return null
  }
  return value.loadouts
}

function parseLoadoutCheck(value) {
  if (!versioned(value, "montage-loadout-check") || typeof value.healthy !== "boolean" ||
      !Array.isArray(value.loadouts)) return null
  for (var i = 0; i < value.loadouts.length; i++) {
    var item = value.loadouts[i]
    if (!item || !nonemptyString(item.id) || LOADOUT_STATES.indexOf(item.state) < 0 ||
        typeof item.attentionCount !== "number" || !Array.isArray(item.resources)) return null
    for (var j = 0; j < item.resources.length; j++) {
      var resource = item.resources[j]
      if (!resource || !nonemptyString(resource.id) ||
          RESOURCE_STATES.indexOf(resource.currentState) < 0 ||
          RESOURCE_STATES.indexOf(resource.healthState) < 0) return null
    }
  }
  return value.loadouts
}

function mergeLoadoutViews(inventory, health) {
  if (!Array.isArray(inventory) || !Array.isArray(health)) return null
  var byId = {}, out = []
  for (var i = 0; i < health.length; i++) byId[health[i].id] = health[i]
  for (var j = 0; j < inventory.length; j++) {
    var stored = inventory[j], live = byId[stored.id]
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

function parseRessMigration(value) {
  if (!versioned(value, "montage-ress-loadout-migration") || value.format !== "ress-v1" ||
      typeof value.compatible !== "boolean" || typeof value.ready !== "boolean" ||
      !Array.isArray(value.warnings) || !Array.isArray(value.losses) ||
      !value.decisions || Array.isArray(value.decisions) ||
      Object.keys(value.decisions).sort().join(",") !== "montagePlugin,ressPlugin" ||
      ["include", "omit", "required", "not-applicable"].indexOf(value.decisions.ressPlugin) < 0 ||
      ["include", "omit", "required", "not-applicable"].indexOf(value.decisions.montagePlugin) < 0 ||
      !value.publication ||
      typeof value.publication.planned !== "boolean" ||
      typeof value.publication.published !== "boolean") return null
  return value
}

var SHARE_REASON_CODES = ["", "missing-manifest", "unsafe-id", "missing-remote",
  "unsafe-remote", "unpinned", "unsupported-launcher", "unsafe-name", "unsafe-icon",
  "local-only", "missing-theme", "credential-url"]

function parseShareCatalog(value) {
  if (!versioned(value, "montage-share-catalog") || !Array.isArray(value.resources) ||
      !value.currentItem || !value.presets || !value.counts || !value.limits ||
      value.limits.themes !== 1 || !Array.isArray(value.presets.loadouts) ||
      !Array.isArray(value.currentItem.resourceIds) ||
      !Array.isArray(value.currentItem.unavailable)) return null
  if (["valid", "absent", "unavailable"].indexOf(value.currentItem.state) < 0 ||
      ["valid", "unavailable"].indexOf(value.presets.state) < 0) return null
  var presetIds = {}
  for (var p = 0; p < value.presets.loadouts.length; p++) {
    var preset = value.presets.loadouts[p]
    if (!preset || !nonemptyString(preset.id) || presetIds[preset.id] ||
        typeof preset.name !== "string" || !uniqueStrings(preset.resourceIds) ||
        !Array.isArray(preset.warnings)) return null
    presetIds[preset.id] = true
    for (var w = 0; w < preset.warnings.length; w++)
      if (!nonemptyString(preset.warnings[w].id) || !nonemptyString(preset.warnings[w].state)) return null
  }
  var ids = {}
  for (var i = 0; i < value.resources.length; i++) {
    var resource = value.resources[i]
    if (!resource || !nonemptyString(resource.id) || ids[resource.id] ||
        SHARE_KINDS.indexOf(resource.kind) < 0 || typeof resource.name !== "string" ||
        typeof resource.shareable !== "boolean" ||
        SHARE_REASON_CODES.indexOf(resource.reasonCode) < 0 ||
        !uniqueStrings(resource.channels) || typeof resource.active !== "boolean") return null
    ids[resource.id] = resource
  }
  return value
}

function shareResourceById(catalog, id) {
  if (!catalog) return null
  for (var i = 0; i < catalog.resources.length; i++)
    if (catalog.resources[i].id === id) return catalog.resources[i]
  return null
}

function sharePresetById(catalog, id) {
  if (!catalog || !catalog.presets) return null
  for (var i = 0; i < catalog.presets.loadouts.length; i++)
    if (catalog.presets.loadouts[i].id === id) return catalog.presets.loadouts[i]
  return null
}

function shareSelection(catalog, source, presetId) {
  var result = {}, values = []
  if (!catalog) return result
  if (source === "all") {
    for (var i = 0; i < catalog.resources.length; i++)
      if (catalog.resources[i].shareable &&
          (catalog.resources[i].kind !== "theme" || catalog.resources[i].active))
        values.push(catalog.resources[i].id)
  } else if (source === "current" && catalog.currentItem.state === "valid") {
    values = catalog.currentItem.resourceIds
  } else if (source === "preset") {
    return addSharePreset(catalog, {}, presetId).selection
  }
  for (var j = 0; j < values.length; j++) result[values[j]] = true
  return result
}

function selectedShareIds(selection) {
  var ids = []
  for (var id in (selection || {})) if (selection[id]) ids.push(id)
  ids.sort()
  return ids
}

function toggleShareResource(catalog, selection, id) {
  var next = {}, key, resource = shareResourceById(catalog, id)
  for (key in (selection || {})) if (selection[key]) next[key] = true
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
    var id = preset.resourceIds[i], resource = shareResourceById(catalog, id)
    if (!resource || !resource.shareable) continue
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
  if (!catalog || catalog.currentItem.state !== "valid") return []
  var out = [], accepted = acknowledgements || {}
  for (var i = 0; i < catalog.currentItem.unavailable.length; i++) {
    var item = catalog.currentItem.unavailable[i]
    if (accepted[item.id] !== item.fingerprint) out.push(item)
  }
  return out
}
