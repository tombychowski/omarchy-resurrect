# The shared port framework is format-neutral and adapters remain bounded.

fixture="$REPO_DIR/tests/fixtures/ress-v1/loadout"

mntg port ress-v1 inspect "$fixture" --json
assert_ok "the canonical Ress v1 format id dispatches explicitly"
assert_equals "$(jq -r '.kind' <<<"$OUT")" "montage-port-report" \
  "all adapters use the shared port report envelope"
assert_equals "$(jq -r '.format' <<<"$OUT")" "ress-v1" \
  "the report carries the stable adapter format id"

mntg port imaginary-v9 inspect "$fixture" --json
assert_fails "an unsupported format is refused at dispatch"
assert_output "unsupported port format: imaginary-v9" \
  "unsupported-format refusal identifies only the requested adapter"

assert_file "$REPO_DIR/lib/montage/port/common.sh" \
  "format-neutral lifecycle primitives have a dedicated module"
assert_file "$REPO_DIR/lib/montage/port/adapter.sh" \
  "literal adapter callbacks have a shared dispatch module"
assert_file "$REPO_DIR/lib/montage/port/inspect.sh" \
  "inspection and history planning are shared engine behavior"
assert_file "$REPO_DIR/lib/montage/port/import.sh" \
  "native import orchestration is shared engine behavior"
assert_file "$REPO_DIR/lib/montage/port/export.sh" \
  "native export orchestration is shared engine behavior"
assert_file "$REPO_DIR/lib/montage/port/adapters/ress_v1/format.sh" \
  "Ress format rules have a bounded adapter module"
assert_file "$REPO_DIR/lib/montage/port/adapters/ress_v1/translate.sh" \
  "Ress semantic translation is isolated"
assert_no_file "$REPO_DIR/lib/montage/port/adapters/ress_v1/inspect.sh" \
  "inspection lifecycle is no longer duplicated in the adapter"
assert_no_file "$REPO_DIR/lib/montage/port/adapters/ress_v1/import.sh" \
  "import lifecycle is no longer duplicated in the adapter"
assert_no_file "$REPO_DIR/lib/montage/port/adapters/ress_v1/export.sh" \
  "export lifecycle is no longer duplicated in the adapter"
assert_no_file "$REPO_DIR/lib/montage/port/adapters/ress_v1/commands.sh" \
  "common command parsing is no longer duplicated in the adapter"
assert_no_file "$REPO_DIR/lib/montage/port/ress_v1.sh" \
  "the former monolithic adapter is gone"

if rg -ni '\b(ress|resurrect)\b' \
    "$REPO_DIR/lib/montage/port/common.sh" \
    "$REPO_DIR/lib/montage/port/inspect.sh" \
    "$REPO_DIR/lib/montage/port/import.sh" \
    "$REPO_DIR/lib/montage/port/export.sh" \
    "$REPO_DIR/lib/montage/port/commands.sh" >/dev/null; then
  _fail "format-neutral port lifecycle code contains Ress-specific policy"
else
  _pass
fi

if rg -n 'confirm|git -C|rev-list|ls-tree|cat-file|checkout|archive|repository_(lock|stage|publish|commit|recover|worktree)|port_(publish_staged_directory|report_output)|montage_make_temp|loadout_repository_|vault_select_|resolve_vault' \
    "$REPO_DIR/lib/montage/port/adapters" >/dev/null; then
  _fail "a format adapter owns shared lifecycle, Git, transaction, staging, publication, or output behavior"
else
  _pass
fi

shared_lines=$(wc -l \
  "$REPO_DIR/lib/montage/port/common.sh" \
  "$REPO_DIR/lib/montage/port/adapter.sh" \
  "$REPO_DIR/lib/montage/port/inspect.sh" \
  "$REPO_DIR/lib/montage/port/import.sh" \
  "$REPO_DIR/lib/montage/port/export.sh" \
  "$REPO_DIR/lib/montage/port/commands.sh" | tail -1 | awk '{print $1}')
adapter_lines=$(wc -l \
  "$REPO_DIR/lib/montage/port/adapters/ress_v1/format.sh" \
  "$REPO_DIR/lib/montage/port/adapters/ress_v1/translate.sh" | tail -1 | awk '{print $1}')
if (( shared_lines > adapter_lines )); then _pass
else _fail "shared port engine is not materially larger than Ress adapter code"; fi

for primitive in port_destination_validate port_materialize_git_commit \
    port_loss_is_accepted port_publish_staged_directory port_report_json \
    port_report_output; do
  assert_file_contains "$REPO_DIR/lib/montage/port/common.sh" "$primitive()" \
    "shared framework defines $primitive"
done

assert_file_contains "$REPO_DIR/lib/montage/port/adapter.sh" '"$PORT_FORMAT:$callback"' \
  "one literal format-and-callback dispatcher replaces pass-through wrappers"
if (source "$REPO_DIR/lib/montage/port/adapter.sh"; PORT_FORMAT=ress-v1;
    port_adapter_call imaginary-callback) >/dev/null 2>&1; then
  _fail "an unsupported adapter callback escaped the literal matrix"
else
  _pass
fi
if rg -n '\beval\b|\$\{[^}]*callback[^}]*\}' "$REPO_DIR/lib/montage/port/adapter.sh" >/dev/null; then
  _fail "adapter dispatch dynamically evaluates a callback name"
else
  _pass
fi
