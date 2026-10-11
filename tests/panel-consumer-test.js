// Execute the actual QML JavaScript handlers with actual CLI payloads.
// This proves protocol/handler semantics, not rendered focus or layout.
const fs = require("fs"), path = require("path"), assert = require("assert");
const [repo, fixtures] = process.argv.slice(2);
const service = fs.readFileSync(path.join(repo, "Service.qml"), "utf8");
const panel = fs.readFileSync(path.join(repo, "Panel.qml"), "utf8");
const modelSource = fs.readFileSync(path.join(repo, "Model.js"), "utf8").replace(/^\.pragma library\s*/m, "");
const Model = new Function(modelSource + "; return {parseRessMigration,parseLoadoutList,parseLoadoutCheck,mergeLoadoutViews};")();
function block(source, marker) {
  const start = source.indexOf(marker);
  assert(start >= 0, "missing handler: " + marker);
  const open = source.indexOf("{", start);
  let depth = 1, end = open + 1;
  for (; depth && end < source.length; end++) {
    if (source[end] === "{") depth++;
    if (source[end] === "}") depth--;
  }
  assert.strictEqual(depth, 0);
  return source.slice(open + 1, end - 1);
}
function processSection(id) {
  const start = service.indexOf("id: " + id);
  const end = service.indexOf("\n  Process {", start);
  return service.slice(start, end === -1 ? service.length : end);
}
function payload(name) { return fs.readFileSync(path.join(fixtures, name + ".json"), "utf8"); }
const inventorySection = processSection("loadoutProc");
const healthSection = processSection("loadoutCheckProc");
function invoke(root, source, marker, text, exitCode) {
  new Function("root", "Model", "text", "exitCode", block(source, marker))(root, Model, text, exitCode);
}
function rootState() {
  const root = {loadoutInventory:null,loadoutHealth:null,loadoutInventoryExit:-1,
    loadoutHealthExit:-1,loadouts:null,loadoutsAvailable:false,loadingLoadouts:true};
  for (const name of ["parseJson","publishLoadouts","rejectLoadouts"])
    root[name] = new Function("root","Model","return function(" +
      (name === "parseJson" ? "text,parser" : "") + ") {" +
      "with (root) {" + block(service, "function " + name + "(") + "}}") (root, Model);
  return root;
}
for (const name of ["healthy", "unhealthy"]) for (const exitFirst of [false,true]) {
  const root = rootState(), code = name === "healthy" ? 0 : 1;
  for (const [section, text, status] of [[inventorySection,payload("inventory"),0],
      [healthSection,payload(name),code]]) {
    if (exitFirst) invoke(root,section,"onExited:",null,status);
    invoke(root,section,"onStreamFinished:",text,null);
    if (!exitFirst) invoke(root,section,"onExited:",null,status);
  }
  assert(root.loadoutsAvailable, name + " remains available in either completion order");
  assert.strictEqual(root.loadouts[0].attentionCount > 0,name === "unhealthy");
}
for (const [text,code] of [["{malformed",1],[payload("unhealthy"),2]]) {
  const root = rootState();
  invoke(root,inventorySection,"onStreamFinished:",payload("inventory"),null);
  invoke(root,inventorySection,"onExited:",null,0);
  invoke(root,healthSection,"onStreamFinished:",text,null);
  invoke(root,healthSection,"onExited:",null,code);
  assert(!root.loadoutsAvailable,"malformed output or unexpected exit stays unavailable");
}
assert(Model.parseRessMigration(JSON.parse(payload("ress"))),"actual Ress producer parses");
const fields = {
  "library-name":"libraryNameField", "library-path":"libraryPathField",
  "library-remote":"libraryRemoteField", "ress-source":"ressSourceField",
  "ress-loadout":"ressLoadoutField", "share-name":"shareNameField",
  "share-description":"shareDescriptionField", "share-search":"shareSearchField"
};
for (const [id, target] of Object.entries(fields)) {
  let focused = "";
  const names = Object.values(fields), stubs = names.map(name =>
    ({forceActiveFocus() { focused = name; }}));
  new Function("id",...names,block(panel,"function trigger("))(id,...stubs);
  assert.strictEqual(focused,target,"Enter activates " + id);
}
for (const [id,expected] of [["share-start:work",["preset","work"]],["share-add:work",["work"]]]) {
  let args;
  new Function("id","beginShare","addPreset",block(panel,"function trigger("))(
    id,(...values)=>args=values,(...values)=>args=values);
  assert.deepStrictEqual(args,expected,"preset keyboard/pointer action is wired");
}
console.log("Actual CLI payloads, process completion orders, refusal handling, field focus and preset dispatch passed.");
