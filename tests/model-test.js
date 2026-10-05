// Unit tests for Model.js, the formatting the panel and the bar icon share.
//
// Model.js is a QML `.pragma library`: plain JavaScript with no QML API in it,
// which is exactly why it can be tested here rather than by starting a shell.
// The pragma line is stripped before evaluating, since node does not know it.
//
// Run through tests/cases/16-qml.sh, or directly: node tests/model-test.js

const fs = require("fs");
const path = require("path");

const source = fs
  .readFileSync(path.join(__dirname, "..", "Model.js"), "utf8")
  .replace(/^\s*\.pragma\s+library\s*$/m, "");

const Model = {};
new Function("exports", source + "\n" + [
  "CATEGORIES", "ago", "freshness", "stripCredentials",
  "plural", "summarize", "parseRecord", "consent",
  "loadoutState", "resourceHealth", "parseLoadoutList", "parseLoadoutCheck", "mergeLoadoutViews",
  "summarizeLoadoutContent", "loadoutContentNames",
  "parseShareCatalog", "shareSelection", "selectedShareIds", "toggleShareResource",
  "shareCounts", "sharePresetWarnings", "addSharePreset", "filterShareResources", "unacknowledgedShareResources",
].map((name) => `exports.${name} = typeof ${name} !== "undefined" ? ${name} : undefined;`)
  .join("\n"))(Model);

let failures = 0;
function check(what, got, want) {
  const g = JSON.stringify(got);
  const w = JSON.stringify(want);
  if (g !== w) {
    console.log(`  FAIL ${what}\n       want ${w}\n       got  ${g}`);
    failures++;
  }
}

// ---- consent: a setting with three states, none of them "on" -------------
check("consent yes", Model.consent("yes", "always", "never", "asks"), "always");
check("consent no", Model.consent("no", "always", "never", "asks"), "never");
check("consent ask", Model.consent("ask", "always", "never", "asks"), "asks");
// Anything unrecognised has to read as "ask", the same way the CLI's
// units_decision_kind and aur_gate fall back, or the panel would tell you a
// machine is set to something it is not.
check("consent junk", Model.consent("wat", "always", "never", "asks"), "asks");
check("consent empty", Model.consent("", "always", "never", "asks"), "asks");
check("consent undefined", Model.consent(undefined, "always", "never", "asks"), "asks");

// ---- plural / summarize --------------------------------------------------
check("plural 1", Model.plural(1, "plugin"), "1 plugin");
check("plural 2", Model.plural(2, "plugin"), "2 plugins");
check("plural 0", Model.plural(0, "plugin"), "0 plugins");
check("plural irregular", Model.plural(2, "entry", "entries"), "2 entries");
check("summarize", Model.summarize({ packages: 1, config: 2, webapps: 0, plugins: 3 }),
  "1 package · 2 config paths · 0 web apps · 3 plugins");
check("summarize nothing", Model.summarize(null), "");

// ---- freshness / ago -----------------------------------------------------
const now = 1000000;
check("freshness none", Model.freshness(0, now, 48), "none");
check("freshness fresh", Model.freshness(now - 3600, now, 48), "fresh");
check("freshness stale", Model.freshness(now - 49 * 3600, now, 48), "stale");
check("freshness custom threshold", Model.freshness(now - 2 * 3600, now, 1), "stale");
check("ago never", Model.ago(0, now), "never");
check("ago just now", Model.ago(now - 5, now), "just now");
check("ago minutes", Model.ago(now - 300, now), "5m ago");
check("ago hours", Model.ago(now - 7200, now), "2h ago");
check("ago days", Model.ago(now - 3 * 86400, now), "3d ago");
// A clock that went backwards must not produce a negative age.
check("ago future", Model.ago(now + 5000, now), "just now");

// ---- stripCredentials ----------------------------------------------------
check("strip token", Model.stripCredentials("https://TOKEN@github.com/a/b"),
  "https://github.com/a/b");
check("strip user:pass", Model.stripCredentials("https://u:p@github.com/a/b"),
  "https://github.com/a/b");
check("strip nothing to strip", Model.stripCredentials("https://github.com/a/b"),
  "https://github.com/a/b");
check("strip empty", Model.stripCredentials(""), "");

// ---- parseRecord: the --porcelain protocol the panel reads ---------------
check("parse step", Model.parseRecord("STEP|packages|ok|done"),
  { type: "step", category: "packages", state: "ok", message: "done" });
check("parse begin", Model.parseRecord("BEGIN|restore|/v").action, "restore");
check("parse progress", Model.parseRecord("PROGRESS|config|3|10"),
  { type: "progress", category: "config", done: 3, total: 10 });
check("parse log", Model.parseRecord("LOG|will run: 1 Omarchy hook").message,
  "will run: 1 Omarchy hook");
check("parse done", Model.parseRecord("DONE|fail|blocked by the secret scan").state, "fail");
// A message containing the separator must survive intact, since paths and
// commands in LOG records legitimately contain one.
check("parse embedded pipes", Model.parseRecord("LOG|a|b|c").message, "a|b|c");
// Anything that is not a record is not a record: the panel drops it rather
// than half-parsing it.
check("parse prose", Model.parseRecord("Possible credentials in the vault"), null);
check("parse empty", Model.parseRecord(""), null);
check("parse null", Model.parseRecord(null), null);

// ---- loadout lifecycle JSON ---------------------------------------------
const loadout = { id: "work-a1b2", name: "Work", state: "healthy",
  resourceCount: 3, attentionCount: 0 };
check("parse loadout list", Model.parseLoadoutList({ loadouts: [loadout] }), [loadout]);
check("parse empty loadout list", Model.parseLoadoutList({ loadouts: [] }), []);
check("reject malformed loadout result", Model.parseLoadoutList({ loadouts: [{ id: "x" }] }), null);
check("reject unknown loadout state", Model.parseLoadoutList({ loadouts: [{ ...loadout, state: "magic" }] }), null);
const checked = { id: "work-a1b2", name: "Work", state: "drifted", attentionCount: 1,
  resources: [{ id: "package:fd", currentState: "missing", healthState: "missing" }] };
check("parse live loadout health", Model.parseLoadoutCheck({ healthy: false, loadouts: [checked] }), [checked]);
check("reject malformed live resource", Model.parseLoadoutCheck({ healthy: false, loadouts: [
  { ...checked, resources: [{ id: "package:fd", currentState: "magic" }] }
] }), null);
check("merge stored content with live health", Model.mergeLoadoutViews([loadout], [checked]), [{
  ...loadout, state: "drifted", attentionCount: 1, resources: checked.resources
}]);
check("reject unmatched live health", Model.mergeLoadoutViews([loadout], []), null);
check("loadout healthy label", Model.loadoutState("healthy"), "Healthy");
check("loadout pending label", Model.loadoutState("pending"), "Pending work");
check("loadout unknown label", Model.loadoutState("newer-state"), "Unavailable");
check("missing resource needs attention", Model.resourceHealth("missing"), "attention");
check("unverifiable resource is unknown", Model.resourceHealth("unverifiable"), "unknown");
const profile = { packages: { native: ["fd"], aur: ["brave-bin"] },
  plugins: [{ id: "acme.widget" }], webapps: [{ name: "Draw" }], theme: { name: "night" } };
check("summarize loadout content", Model.summarizeLoadoutContent(profile),
  "2 packages · 1 plugin · 1 web app · theme night");
check("list loadout content names", Model.loadoutContentNames(profile),
  "fd · brave-bin · acme.widget · Draw · night");

// ---- share catalog and composer state -----------------------------------
const fingerprint = "a".repeat(64);
const shareCatalog = {
  schemaVersion: 1,
  resources: [
    { id: "package:fd", kind: "package", name: "fd", shareable: true,
      reasonCode: "", reason: "", channels: ["native"], active: false },
    { id: "plugin:acme.widget", kind: "plugin", name: "acme.widget", shareable: true,
      reasonCode: "", reason: "", channels: [], active: false },
    { id: "theme-install:night", kind: "theme", name: "night", shareable: true,
      reasonCode: "", reason: "", channels: [], active: true },
    { id: "theme-install:day", kind: "theme", name: "day", shareable: true,
      reasonCode: "", reason: "", channels: [], active: false },
    { id: "webapp:Flags", kind: "webapp", name: "Flags", shareable: false,
      reasonCode: "unsupported-launcher", reason: "flags", channels: [], active: false },
  ],
  currentExport: { state: "valid", name: "Mine", description: "desc",
    resourceIds: ["package:fd"], unavailable: [
      { id: "plugin:old", kind: "plugin", name: "old", reasonCode: "missing",
        reason: "gone", fingerprint }
    ] },
  presets: { state: "valid", loadouts: [
    { id: "work-1", name: "Work", resourceIds: ["plugin:acme.widget", "theme-install:day"],
      warnings: [{ id: "webapp:missing", state: "missing" }] }
  ] },
  counts: { package: 1, plugin: 1, theme: 2, webapp: 1 }, limits: { themes: 1 }
};
check("parse share catalog", Model.parseShareCatalog(shareCatalog), shareCatalog);
check("reject unknown share kind", Model.parseShareCatalog({ ...shareCatalog,
  resources: [{ ...shareCatalog.resources[0], kind: "file" }] }), null);
check("reject unavailable without reason", Model.parseShareCatalog({ ...shareCatalog,
  resources: [{ ...shareCatalog.resources[4], reasonCode: "" }] }), null);
check("reject unknown share reason", Model.parseShareCatalog({ ...shareCatalog,
  resources: [{ ...shareCatalog.resources[4], reasonCode: "anything" }] }), null);
check("reject package with unknown channel", Model.parseShareCatalog({ ...shareCatalog,
  resources: [{ ...shareCatalog.resources[0], channels: ["flatpak"] }] }), null);
check("reject partial catalog", Model.parseShareCatalog({ ...shareCatalog, limits: undefined }), null);
check("reject malformed unavailable fingerprint", Model.parseShareCatalog({ ...shareCatalog,
  currentExport: { ...shareCatalog.currentExport, unavailable: [
    { ...shareCatalog.currentExport.unavailable[0], fingerprint: "short" }
  ] } }), null);
check("all start selects shareable resources and only the active theme",
  Model.selectedShareIds(Model.shareSelection(shareCatalog, "all")),
  ["package:fd", "plugin:acme.widget", "theme-install:night"]);
check("current start", Model.selectedShareIds(Model.shareSelection(shareCatalog, "current")), ["package:fd"]);
check("empty start", Model.selectedShareIds(Model.shareSelection(shareCatalog, "empty")), []);
check("preset start", Model.selectedShareIds(Model.shareSelection(shareCatalog, "preset", "work-1")),
  ["plugin:acme.widget", "theme-install:day"]);
check("preset warnings are explicit", Model.sharePresetWarnings(shareCatalog.presets.loadouts[0]),
  "webapp:missing (missing)");
check("selected category counts", Model.shareCounts(shareCatalog,
  { "package:fd": true, "plugin:acme.widget": true }),
  { package: 1, plugin: 1, webapp: 0, theme: 0, total: 2 });
let selection = Model.toggleShareResource(shareCatalog, { "theme-install:night": true }, "theme-install:day");
check("theme toggle replaces prior theme", Model.selectedShareIds(selection), ["theme-install:day"]);
selection = Model.toggleShareResource(shareCatalog, selection, "webapp:Flags");
check("unavailable resource cannot be toggled", Model.selectedShareIds(selection), ["theme-install:day"]);
let added = Model.addSharePreset(shareCatalog, { "package:fd": true, "theme-install:night": true }, "work-1");
check("preset union retains manual resources", Model.selectedShareIds(added.selection),
  ["package:fd", "plugin:acme.widget", "theme-install:night"]);
check("preset union reports theme conflict", added.themeConflict, "theme-install:day");
check("share search filters and bounds", Model.filterShareResources(shareCatalog, "theme", "day", 1).map(x => x.id),
  ["theme-install:day"]);
check("unavailable resource needs acknowledgement", Model.unacknowledgedShareResources(shareCatalog, {}).map(x => x.id),
  ["plugin:old"]);
check("matching acknowledgement satisfies resource", Model.unacknowledgedShareResources(shareCatalog,
  { "plugin:old": fingerprint }), []);
const largeCatalog = { ...shareCatalog, resources: Array.from({ length: 1000 }, (_, i) => ({
  id: `package:pkg-${String(i).padStart(4, "0")}`, kind: "package",
  name: `pkg-${String(i).padStart(4, "0")}`, shareable: true,
  reasonCode: "", reason: "", channels: ["native"], active: false
})), counts: { package: 1000 }, currentExport: { state: "absent", name: "Mine",
  description: "", resourceIds: [], unavailable: [] },
  presets: { state: "unavailable", loadouts: [], reasonCode: "invalid-registry", reason: "bad" } };
check("large catalog validates", Model.parseShareCatalog(largeCatalog), largeCatalog);
check("large catalog detail is bounded", Model.filterShareResources(largeCatalog, "package", "", 200).length, 200);

// ---- the category table the panel renders --------------------------------
check("categories count", Model.CATEGORIES.length, 6);
check("category keys", Model.CATEGORIES.map((c) => c.key),
  ["packages", "config", "omarchy", "webapps", "plugins", "secrets"]);

if (failures > 0) {
  console.log(`${failures} Model.js assertions failed`);
  process.exit(1);
}
console.log("all Model.js assertions passed");
