# Ress v1 semantic transformations.
#
# This adapter may interpret and construct Ress v1 artifacts. It does not
# select repositories, traverse Git history, ask for consent, stage native
# publication, create commits, or emit consumer output.

ress_v1_profile_apply_import_decision() {
  local source="$1" destination="$2" decision="$3"
  case "$decision" in
    include) cp -- "$source" "$destination" ;;
    omit)
      jq --arg id "$RESS_V1_SELF_PLUGIN" '.plugins |= map(select(.id != $id))' \
        "$source" >"$destination"
      ;;
    *) return 1 ;;
  esac
}

ress_v1_profile_apply_export_decisions() {
  local source="$1" destination="$2" ress_decision="$3" montage_decision="$4"
  jq --arg ress "$RESS_V1_SELF_PLUGIN" --arg montage "$RESS_V1_MONTAGE_PLUGIN" \
    --arg rd "$ress_decision" --arg md "$montage_decision" '
    .plugins |= (
      map(select((.id != $ress) or $rd != "omit")) |
      map(select((.id != $montage) or ($md != "omit" and $md != "map-ress"))) |
      if $md == "map-ress" and any(.[]; .id == $ress) then .
      elif $md == "map-ress" then . + [{id:$ress,url:"https://github.com/btsouth/omarchy-resurrect",commit:""}]
      else . end |
      sort_by(.id)
    )
  ' "$source" >"$destination"
}

ress_v1_translate_suffixes() {
  local root="$1" path target
  while IFS= read -r -d '' path; do
    case "$path" in
      *.ress-bak) target="${path%.ress-bak}.montage-bak" ;;
      *.resurrect-bak) target="${path%.resurrect-bak}.montage-bak" ;;
      *) continue ;;
    esac
    [[ ! -e $target && ! -L $target ]] || return 1
    mv -- "$path" "$target" || return 1
  done < <(find -P "$root" -depth -type f -print0)
}

ress_v1_reverse_suffixes() {
  local root="$1" path target
  while IFS= read -r -d '' path; do
    target="${path%.montage-bak}.ress-bak"
    [[ ! -e $target && ! -L $target ]] || return 1
    mv -- "$path" "$target" || return 1
  done < <(find -P "$root" -depth -type f -name '*.montage-bak' -print0)
}

ress_v1_filter_plugin_inventory() {
  local file="$1" ress_decision="$2" montage_decision="$3" next
  [[ -f $file && ! -L $file ]] || return 0
  next="$file.next"
  awk -F '\t' -v ress="$RESS_V1_SELF_PLUGIN" -v montage="$RESS_V1_MONTAGE_PLUGIN" \
    -v rd="$ress_decision" -v md="$montage_decision" '
      $1 == ress && rd == "omit" { next }
      $1 == montage && md == "omit" { next }
      { print }
    ' "$file" >"$next" || return 1
  mv -- "$next" "$file"
}

ress_v1_copy_payload() {
  local source="$1" stage="$2" category source_dir
  for category in packages home omarchy webapps plugins services secrets report; do
    source_dir="$source/$category"
    [[ ! -e $source_dir && ! -L $source_dir ]] || {
      [[ -d $source_dir && ! -L $source_dir ]] || return 1
      mkdir -p "$stage/$category" || return 1
      cp -a -- "$source_dir/." "$stage/$category/" || return 1
    }
  done
}

ress_v1_translate_vault_tree() {
  local source="$1" stage="$2" machine_id="$3" ress_decision="$4" montage_decision="$5"
  local manifest="$PORT_ADAPTER_CONTROL" operational
  ress_v1_copy_payload "$source" "$stage" || return 1
  # Product runtime and encryption identity are not backup payload, even if a
  # hand-edited Ress vault placed them below its captured home tree.
  for operational in \
      "$stage/home/.config/ress" "$stage/home/.local/state/ress" \
      "$stage/home/.local/share/ress" "$stage/config" "$stage/state" \
      "$stage/locks" "$stage/restore.progress" "$stage/loadouts.json" \
      "$stage/secrets.key"; do
    [[ ! -e $operational && ! -L $operational ]] || rm -rf -- "$operational"
  done
  ress_v1_translate_suffixes "$stage" || return 1
  ress_v1_filter_plugin_inventory "$stage/plugins/plugins.tsv" \
    "$ress_decision" "$montage_decision" || return 1
  jq -S --arg machineId "$machine_id" --arg montageVersion "$VERSION" '
    {schemaVersion:1,kind:"montage-backup",montageVersion:$montageVersion,
     createdAt:.createdAt,machineId:$machineId,
     machine:{hostname:.machine.hostname,user:.machine.user,
       omarchy:.machine.omarchyVersion,kernel:.machine.kernel},
     categories:.categories,counts:.counts}
  ' "$manifest" >"$stage/$VAULT_MANIFEST" || return 1
}

ress_v1_translate_backup_export() {
  local source="$1" stage="$2" ress_decision="$3" montage_decision="$4"
  local manifest inventory_decision
  ress_v1_copy_payload "$source" "$stage" || return 1
  ress_v1_reverse_suffixes "$stage" || return 1
  inventory_decision="$montage_decision"
  [[ $montage_decision != map-ress ]] || inventory_decision=omit
  ress_v1_filter_plugin_inventory "$stage/plugins/plugins.tsv" \
    "$ress_decision" "$inventory_decision" || return 1
  if [[ $montage_decision == map-ress && -f $stage/plugins/plugins.tsv ]] &&
     ! rg -q "^${RESS_V1_SELF_PLUGIN}"$'\t' "$stage/plugins/plugins.tsv"; then
    printf '%s\t%s\tdisabled\t\n' "$RESS_V1_SELF_PLUGIN" \
      'https://github.com/btsouth/omarchy-resurrect' >>"$stage/plugins/plugins.tsv"
  fi
  manifest="$source/$VAULT_MANIFEST"
  jq -S --arg ressVersion "1.2.0" '
    {schemaVersion:1,ressVersion:$ressVersion,createdAt:.createdAt,
     machine:{hostname:.machine.hostname,user:.machine.user,
       omarchyVersion:.machine.omarchy,kernel:.machine.kernel},
     categories:.categories,counts:.counts}
  ' "$manifest" >"$stage/$RESS_V1_CANONICAL_MANIFEST" || return 1
}

ress_v1_adapter_translate_import() {
  local kind="$1" source="$2" stage="$3" native_id="$4" decisions="$5"
  local ress_decision montage_decision
  ress_decision=$(jq -r '.ressPlugin' <<<"$decisions") || return 1
  montage_decision=$(jq -r '.montagePlugin' <<<"$decisions") || return 1
  case "$kind" in
    loadout)
      ress_v1_profile_apply_import_decision "$source" "$stage/profile.json" "$ress_decision"
      ;;
    vault)
      ress_v1_translate_vault_tree "$source" "$stage" "$native_id" \
        "$ress_decision" "$montage_decision"
      ;;
    *) return 1 ;;
  esac
}

ress_v1_adapter_translate_export() {
  local kind="$1" source="$2" stage="$3" decisions="$4" ress_decision montage_decision
  ress_decision=$(jq -r '.ressPlugin' <<<"$decisions") || return 1
  montage_decision=$(jq -r '.montagePlugin' <<<"$decisions") || return 1
  case "$kind" in
    loadout)
      ress_v1_profile_apply_export_decisions "$source" "$stage/profile.json" \
        "$ress_decision" "$montage_decision" || return 1
      printf '# Ress v1 compatibility copy\n\nDisposable export from Montage.\n' >"$stage/README.md"
      ;;
    backup)
      ress_v1_translate_backup_export "$source" "$stage" \
        "$ress_decision" "$montage_decision" || return 1
      printf '# Ress v1 compatibility copy\n\nDisposable export from Montage.\n' >"$stage/README.md"
      ;;
    *) return 1 ;;
  esac
}

ress_v1_adapter_validate_export() {
  local kind="$1" stage="$2"
  case "$kind" in
    loadout) ress_v1_profile_validate_file "$stage/profile.json" ;;
    backup) ress_v1_vault_validate_root "$stage" ;;
    *) return 1 ;;
  esac
}
