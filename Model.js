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
    case "DONE":     return { type: "done", state: parts[1], message: parts.slice(2).join("|") }
  }
  return null
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
  if (!value || !Array.isArray(value.loadouts)) return null
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
  if (!value || typeof value.healthy !== "boolean" || !Array.isArray(value.loadouts)) return null
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
