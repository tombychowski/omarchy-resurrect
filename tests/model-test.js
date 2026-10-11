// Unit tests for the strict, plain-JavaScript panel protocol adapters.
const fs = require("fs");
const path = require("path");
const source = fs.readFileSync(path.join(__dirname, "..", "Model.js"), "utf8")
  .replace(/^\s*\.pragma\s+library\s*$/m, "");
const names = ["ATTENTION_STATES", "SHARE_KINDS", "stripCredentials", "plural", "consent",
  "attentionLabel", "attentionTone", "parseStatus", "parseRecord", "parseRepositoryList",
  "parseLoadoutCatalog", "parseSyncResult", "parseLoadoutList", "parseLoadoutCheck",
  "mergeLoadoutViews", "loadoutState", "resourceHealth", "parseRessMigration",
  "parseShareCatalog", "shareSelection", "selectedShareIds", "toggleShareResource",
  "filterShareResources", "unacknowledgedShareResources", "addSharePreset"];
const Model = {};
new Function("exports", source + "\n" + names.map((name) =>
  `exports.${name} = typeof ${name} !== "undefined" ? ${name} : undefined;`).join("\n"))(Model);

let failures = 0;
function check(label, got, want) {
  if (JSON.stringify(got) !== JSON.stringify(want)) {
    console.log(`  FAIL ${label}\n       want ${JSON.stringify(want)}\n       got  ${JSON.stringify(got)}`);
    failures++;
  }
}

check("attention vocabulary", Model.ATTENTION_STATES, ["healthy", "update-available",
  "repair-needed", "drifted", "repository-attention", "unavailable-or-invalid",
  "operation-partial-or-failed", "operation-active"]);
check("healthy label", Model.attentionLabel("healthy"), "Loadouts healthy");
check("active tone", Model.attentionTone("operation-active"), "active");
check("invalid label", Model.attentionLabel("anything"), "Loadout status unavailable");
check("AUR ask", Model.consent("ask"), "ask before building · recommended");
check("plural", Model.plural(2, "library", "libraries"), "2 libraries");
check("strip credentials", Model.stripCredentials("https://u:p@example.test/repo"),
  "https://example.test/repo");

const status = { schemaVersion: 1, kind: "montage-status", attention: "healthy", causes: [],
  operation: { active: false, valid: true, ownerPid: null },
  loadouts: { available: true, evidenceValid: true, count: 0, attention: 0,
    repairNeeded: 0, drifted: 0, partialOrFailed: 0, updateAvailable: 0, items: [] },
  repositories: { available: true, count: 0, attention: 0, items: [], migration: null },
  settings: { aur: "ask" }, migration: null };
check("parse healthy status", Model.parseStatus(status), status);
check("parse valid empty status", Model.parseStatus(status).loadouts.items, []);
check("reject unknown attention", Model.parseStatus({ ...status, attention: "stale" }), null);
check("reject malformed optional source", Model.parseStatus({ ...status,
  loadouts: { ...status.loadouts, available: "yes" } }), null);
check("parse status record", Model.parseRecord("STATUS|1|healthy|0|0").attention, "healthy");
check("parse Ress record", Model.parseRecord("RESS|1|inspect|true|true|false|").operation, "inspect");
check("reject obsolete prose", Model.parseRecord("backup complete"), null);

const repositoryList = { schemaVersion: 1, kind: "montage-repository-list", revision: 2,
  repositories: [{ name: "personal", path: "/tmp/personal", type: "loadouts",
    id: "personal-library", remote: "https://example.test/loadouts", valid: true,
    status: "healthy" }] };
check("parse loadout-only libraries", Model.parseRepositoryList(repositoryList), repositoryList);
check("reject vault kind", Model.parseRepositoryList({ ...repositoryList,
  repositories: [{ ...repositoryList.repositories[0], type: "vault" }] }), null);
check("reject credentialed library", Model.parseRepositoryList({ ...repositoryList,
  repositories: [{ ...repositoryList.repositories[0], remote: "https://token@example.test/x" }] }), null);

const catalog = { schemaVersion: 1, kind: "montage-loadout-catalog",
  repositoryId: "personal-library", repositoryCommit: "a".repeat(40), path: "/tmp/personal",
  items: [{ id: "work", name: "Work", author: "A", repositoryId: "personal-library",
    digest: "b".repeat(64) }], invalid: [] };
check("parse library items", Model.parseLoadoutCatalog(catalog), catalog);
check("reject item identity mismatch", Model.parseLoadoutCatalog({ ...catalog,
  items: [{ ...catalog.items[0], repositoryId: "other" }] }), null);

const sync = { schemaVersion: 1, kind: "montage-repository-sync", repositoryId: "personal-library",
  repositoryType: "loadouts", status: "divergent", ahead: 1, behind: 1,
  remote: "https://example.test/loadouts", fetch: { ok: true, errorCode: null } };
check("parse sync decision", Model.parseSyncResult(sync), sync);
check("reject sync vault kind", Model.parseSyncResult({ ...sync, repositoryType: "vault" }), null);

const stored = { id: "work-a1", name: "Work", state: "healthy", resourceCount: 1,
  attentionCount: 0, profile: {} };
const live = { id: "work-a1", name: "Work", state: "drifted", attentionCount: 1,
  resources: [{ id: "package:fd", currentState: "missing", healthState: "missing" }] };
check("parse applied list", Model.parseLoadoutList({ schemaVersion: 1,
  kind: "montage-applied-loadout-list", loadouts: [stored] }), [stored]);
check("parse live health", Model.parseLoadoutCheck({ schemaVersion: 1,
  kind: "montage-loadout-check", healthy: false, loadouts: [live] }), [live]);
check("merge applied views", Model.mergeLoadoutViews([stored], [live]), [{ ...stored,
  state: "drifted", attentionCount: 1, resources: live.resources }]);
check("missing resource attention", Model.resourceHealth("missing"), "attention");

const ress = { schemaVersion: 1, kind: "montage-ress-loadout-migration", format: "ress-v1",
  compatible: true, ready: true, warnings: [], losses: [],
  decisions: {ressPlugin:"not-applicable",montagePlugin:"omit"},
  publication: { planned: false, published: false, commit: null } };
check("parse Ress migration", Model.parseRessMigration(ress), ress);
check("reject fictional Ress decision array", Model.parseRessMigration({...ress, decisions:[]}), null);
check("reject unknown Ress decision", Model.parseRessMigration({...ress,
  decisions:{ressPlugin:"accept-all",montagePlugin:"omit"}}), null);
check("reject general port envelope", Model.parseRessMigration({ ...ress,
  kind: "montage-port-report" }), null);

const fingerprint = "c".repeat(64);
const share = { schemaVersion: 1, kind: "montage-share-catalog", resources: [
  { id: "package:fd", kind: "package", name: "fd", shareable: true,
    reasonCode: "", reason: "", channels: ["native"], active: false },
  { id: "theme-install:night", kind: "theme", name: "night", shareable: true,
    reasonCode: "", reason: "", channels: [], active: true },
  { id: "webapp:Unsafe", kind: "webapp", name: "Unsafe", shareable: false,
    reasonCode: "unsupported-launcher", reason: "unsafe", channels: [], active: false }
], currentItem: { state: "valid", name: "Mine", description: "", resourceIds: ["package:fd"],
  unavailable: [{ id: "plugin:gone", name: "gone", reason: "missing", fingerprint }] },
  presets: { state: "valid", loadouts: [] }, counts: { package: 1, theme: 1, webapp: 1 },
  limits: { themes: 1 } };
check("parse Share catalog", Model.parseShareCatalog(share), share);
check("all selection excludes unsafe", Model.selectedShareIds(Model.shareSelection(share, "all")),
  ["package:fd", "theme-install:night"]);
check("unsafe toggle ignored", Model.selectedShareIds(Model.toggleShareResource(share, {}, "webapp:Unsafe")), []);
check("bounded search", Model.filterShareResources(share, "package", "f", 1).length, 1);
check("withdrawal acknowledgement required", Model.unacknowledgedShareResources(share, {}).length, 1);
check("withdrawal acknowledgement accepted", Model.unacknowledgedShareResources(share,
  { "plugin:gone": fingerprint }).length, 0);

const composed = {...share, resources: [...share.resources,
  {id:"theme-install:day",kind:"theme",name:"day",shareable:true,reasonCode:"",
    channels:[],active:false}], presets:{state:"valid",loadouts:[
    {id:"work",name:"Work",resourceIds:["package:fd","theme-install:day"],warnings:[]} ]}};
check("parse preset catalog", Model.parseShareCatalog(composed), composed);
check("preset initializes selection", Model.selectedShareIds(Model.shareSelection(composed,"preset","work")),
  ["package:fd","theme-install:day"]);
const union = Model.addSharePreset(composed,{"package:manual":true,"theme-install:night":true},"work");
check("preset union retains manual choice", Model.selectedShareIds(union.selection),
  ["package:fd","package:manual","theme-install:night"]);
check("preset reports theme conflict", union.themeConflict,"theme-install:day");
check("repeated union deduplicates", Model.selectedShareIds(Model.addSharePreset(composed,union.selection,"work").selection),
  Model.selectedShareIds(union.selection));
check("reject malformed preset warnings", Model.parseShareCatalog({...composed,
  presets:{state:"valid",loadouts:[{...composed.presets.loadouts[0],warnings:[{}]}]}}), null);

if (failures) {
  console.log(`${failures} Model.js assertions failed`);
  process.exit(1);
}
console.log("all Model.js assertions passed");
