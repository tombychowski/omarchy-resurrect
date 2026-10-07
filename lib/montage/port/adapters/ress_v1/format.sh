# Format-specific Ress v1 names, validation, detection, and loss discovery.

RESS_V1_SCHEMA=1
RESS_V1_CANONICAL_MANIFEST="ress.json"
RESS_V1_LEGACY_MANIFEST="resurrect.json"
RESS_V1_SELF_PLUGIN="tsouth89.resurrect"
RESS_V1_MONTAGE_PLUGIN="tombychowski.montage"
RESS_V1_CLI_RESS_DECISION=""
RESS_V1_CLI_MONTAGE_DECISION=""

ress_v1_adapter_command_option() {
  local option="$1" next="$2" value
  case "$option" in
    --ress-plugin|--montage-plugin)
      [[ -n $next ]] || return 1
      value="$next"; PORT_ADAPTER_OPTION_CONSUMED=2
      ;;
    --ress-plugin=*|--montage-plugin=*)
      value="${option#*=}"; PORT_ADAPTER_OPTION_CONSUMED=1
      ;;
    *) return 1 ;;
  esac
  case "$option" in
    --ress-plugin*) RESS_V1_CLI_RESS_DECISION="$value" ;;
    --montage-plugin*) RESS_V1_CLI_MONTAGE_DECISION="$value" ;;
  esac
}

ress_v1_adapter_command_decisions() {
  local direction="$1" type="$2"
  [[ -z $RESS_V1_CLI_RESS_DECISION || $RESS_V1_CLI_RESS_DECISION == include ||
     $RESS_V1_CLI_RESS_DECISION == omit ]] || return 1
  if [[ $direction == export ]]; then
    [[ -z $RESS_V1_CLI_MONTAGE_DECISION || $RESS_V1_CLI_MONTAGE_DECISION == include ||
       $RESS_V1_CLI_MONTAGE_DECISION == omit || $RESS_V1_CLI_MONTAGE_DECISION == map-ress ]] || return 1
  else
    [[ -z $RESS_V1_CLI_MONTAGE_DECISION || $RESS_V1_CLI_MONTAGE_DECISION == include ||
       $RESS_V1_CLI_MONTAGE_DECISION == omit ]] || return 1
    [[ $type != loadout || -z $RESS_V1_CLI_MONTAGE_DECISION ]] || return 1
  fi
  PORT_ADAPTER_CLI_DECISIONS_JSON=$(jq -nc --arg rd "$RESS_V1_CLI_RESS_DECISION" \
    --arg md "$RESS_V1_CLI_MONTAGE_DECISION" '{ressPlugin:$rd,montagePlugin:$md}')
  RESS_V1_CLI_RESS_DECISION=""; RESS_V1_CLI_MONTAGE_DECISION=""
}
ress_v1_profile_validate_file() {
  local file="$1" profile value id url commit icon
  [[ -f $file && ! -L $file ]] || return 1
  profile=$(<"$file")
  portable_profile_v1_shape_valid "$profile" || return 1
  jq -e '(.name|length) >= 1 and (.name|length) <= 120 and
    (.description|length) <= 1000' <<<"$profile" >/dev/null || return 1
  while IFS= read -r value; do valid_pkg "$value" || return 1; done \
    < <(jq -r '.packages.native[],.packages.aur[]' "$file")
  jq -e '(.packages.native|length)==(.packages.native|unique|length) and
    (.packages.aur|length)==(.packages.aur|unique|length)' "$file" >/dev/null || return 1
  while IFS=$'\t' read -r id url commit; do
    valid_id "$id" && valid_https "$url" && ! url_has_credentials "$url" &&
      { [[ -z $commit ]] || valid_sha "$commit"; } || return 1
  done < <(jq -r '.plugins[] | [.id,.url,.commit] | @tsv' "$file")
  while IFS=$'\t' read -r value url icon; do
    valid_label "$value" && valid_public_https "$url" &&
      { [[ -z $icon ]] || valid_icon "$icon"; } || return 1
  done < <(jq -r '.webapps[] | [.name,.url,.icon] | @tsv' "$file")
  value=$(jq -r '.theme.name' "$file")
  url=$(jq -r '.theme.url' "$file")
  commit=$(jq -r '.theme.commit' "$file")
  if [[ -n $value ]]; then
    valid_theme "$value" || return 1
    [[ -z $url ]] || { valid_https "$url" && ! url_has_credentials "$url"; } || return 1
    [[ -z $commit ]] || valid_sha "$commit" || return 1
  else
    [[ -z $url && -z $commit ]] || return 1
  fi
}

ress_v1_vault_manifest_version() {
  local file="$1"
  [[ -f $file && ! -L $file ]] || return 1
  jq -er 'if (.schemaVersion|type)=="number" and (.schemaVersion|floor)==.schemaVersion
    then .schemaVersion else error("invalid") end' "$file" 2>/dev/null
}

ress_v1_vault_manifest_validate_file() {
  local file="$1"
  [[ $(ress_v1_vault_manifest_version "$file" 2>/dev/null || true) == "$RESS_V1_SCHEMA" ]] || return 1
  jq -e '
    type == "object" and
    keys == ["categories","counts","createdAt","machine","ressVersion","schemaVersion"] and
    (.ressVersion|type)=="string" and (.ressVersion|length)>=1 and (.ressVersion|length)<=64 and
    (.createdAt|type)=="string" and
    (.machine|type)=="object" and
      (.machine|keys)==["hostname","kernel","omarchyVersion","user"] and
      all(.machine.hostname,.machine.kernel,.machine.omarchyVersion,.machine.user;
        type=="string" and length>=1 and length<=255) and
    (.categories|type)=="array" and
      all(.categories[]; .=="packages" or .=="config" or .=="omarchy" or .=="webapps" or .=="plugins" or .=="secrets") and
      (.categories|length)==(.categories|unique|length) and
    (.counts|type)=="object" and
      (.counts|keys)==["config","packages","plugins","secrets","services","themes","uncaptured","webapps"] and
      all(.counts[]; type=="number" and floor==. and .>=0)
  ' "$file" >/dev/null 2>&1 || return 1
  repository_timestamp_valid "$(jq -r '.createdAt' "$file")"
}

ress_v1_source_contains_links() {
  local root="$1"
  find -P "$root" -path "$root/.git" -prune -o -type l -print -quit | grep -q .
}

ress_v1_vault_validate_root() {
  local root="$1" manifest="" relative
  [[ $root == /* && -d $root && ! -L $root ]] || return 1
  [[ $(realpath -e -- "$root" 2>/dev/null) == "$root" ]] || return 1
  [[ ! -e $root/montage.json && ! -L $root/montage.json ]] || return 1
  if [[ -e $root/$RESS_V1_CANONICAL_MANIFEST || -L $root/$RESS_V1_CANONICAL_MANIFEST ]]; then
    manifest=$(safe_control_file "$root" "$RESS_V1_CANONICAL_MANIFEST") || return 1
    [[ ! -e $root/$RESS_V1_LEGACY_MANIFEST && ! -L $root/$RESS_V1_LEGACY_MANIFEST ]] || return 1
  elif [[ -e $root/$RESS_V1_LEGACY_MANIFEST || -L $root/$RESS_V1_LEGACY_MANIFEST ]]; then
    manifest=$(safe_control_file "$root" "$RESS_V1_LEGACY_MANIFEST") || return 1
  else
    return 1
  fi
  ress_v1_vault_manifest_validate_file "$manifest" || return 1
  ress_v1_source_contains_links "$root" && return 1
  for relative in packages/native.txt packages/foreign.txt plugins/plugins.tsv \
      services/user-units.txt omarchy/themes.tsv omarchy/theme-repos.tsv \
      omarchy/current-theme secrets/secrets.tar.age; do
    [[ ! -e $root/$relative && ! -L $root/$relative ]] ||
      safe_control_file "$root" "$relative" >/dev/null || return 1
  done
  PORT_ADAPTER_CONTROL="$manifest"
}

ress_v1_detect_artifact() {
  local source="$1" canonical control=""
  PORT_ADAPTER_ARTIFACT_TYPE="unknown"; PORT_ADAPTER_SOURCE_ROOT=""; PORT_ADAPTER_CONTROL=""
  [[ $source == /* && -e $source && ! -L $source ]] || return 1
  canonical=$(realpath -e -- "$source") || return 1
  [[ $canonical == "$source" ]] || return 1
  if [[ -f $canonical ]]; then
    case "$(basename "$canonical")" in
      profile.json)
        ress_v1_profile_validate_file "$canonical" || return 1
        PORT_ADAPTER_ARTIFACT_TYPE=loadout; PORT_ADAPTER_SOURCE_ROOT=$(dirname "$canonical"); PORT_ADAPTER_CONTROL="$canonical"
        ;;
      "$RESS_V1_CANONICAL_MANIFEST"|"$RESS_V1_LEGACY_MANIFEST")
        ress_v1_vault_manifest_validate_file "$canonical" || return 1
        PORT_ADAPTER_ARTIFACT_TYPE=vault-manifest; PORT_ADAPTER_SOURCE_ROOT=$(dirname "$canonical"); PORT_ADAPTER_CONTROL="$canonical"
        ;;
      *) return 1 ;;
    esac
  elif [[ -d $canonical ]]; then
    if [[ -e $canonical/profile.json || -L $canonical/profile.json ]]; then
      control=$(safe_control_file "$canonical" profile.json) || return 1
      ress_v1_profile_validate_file "$control" || return 1
      PORT_ADAPTER_ARTIFACT_TYPE=loadout; PORT_ADAPTER_SOURCE_ROOT="$canonical"; PORT_ADAPTER_CONTROL="$control"
    else
      ress_v1_vault_validate_root "$canonical" || return 1
      PORT_ADAPTER_ARTIFACT_TYPE=vault; PORT_ADAPTER_SOURCE_ROOT="$canonical"
    fi
  else
    return 1
  fi
}

ress_v1_find_self_plugins() {
  local kind="$1" source="$2" inventory
  RESS_V1_HAS_RESS=0; RESS_V1_HAS_MONTAGE=0
  case "$kind" in
    loadout)
      jq -e --arg id "$RESS_V1_SELF_PLUGIN" 'any(.plugins[]; .id==$id)' "$source" >/dev/null && RESS_V1_HAS_RESS=1
      jq -e --arg id "$RESS_V1_MONTAGE_PLUGIN" 'any(.plugins[]; .id==$id)' "$source" >/dev/null && RESS_V1_HAS_MONTAGE=1
      ;;
    vault|backup)
      inventory="$source/plugins/plugins.tsv"
      [[ -f $inventory && ! -L $inventory ]] || return 0
      rg -q "^${RESS_V1_SELF_PLUGIN}"$'\t' "$inventory" && RESS_V1_HAS_RESS=1
      rg -q "^${RESS_V1_MONTAGE_PLUGIN}"$'\t' "$inventory" && RESS_V1_HAS_MONTAGE=1
      ;;
    *) return 1 ;;
  esac
  return 0
}

ress_v1_self_plugin_losses_json() {
  ress_v1_find_self_plugins "$1" "$2" || return 1
  jq -nc --argjson ress "$RESS_V1_HAS_RESS" --argjson montage "$RESS_V1_HAS_MONTAGE" '
    [if $ress==1 then {code:"ress-self-plugin",waivable:true,decision:"required"} else empty end,
     if $montage==1 then {code:"montage-self-plugin",waivable:true,decision:"required"} else empty end]'
}

ress_v1_adapter_inspect() {
  local source="$1" version="" manifest_name=""
  port_adapter_context_reset
  PORT_ADAPTER_SOURCE_ROOT="$source"
  if ! ress_v1_detect_artifact "$source"; then
    PORT_ADAPTER_REASON=malformed-or-unsafe
    if [[ -f $source && ! -L $source ]]; then
      version=$(ress_v1_vault_manifest_version "$source" 2>/dev/null || true)
      [[ -n $version && $version != "$RESS_V1_SCHEMA" ]] &&
        PORT_ADAPTER_REASON=unsupported-version
    elif [[ -d $source && ! -L $source ]]; then
      for manifest_name in "$RESS_V1_CANONICAL_MANIFEST" "$RESS_V1_LEGACY_MANIFEST"; do
        [[ -f $source/$manifest_name && ! -L $source/$manifest_name ]] || continue
        version=$(ress_v1_vault_manifest_version "$source/$manifest_name" 2>/dev/null || true)
        [[ -n $version && $version != "$RESS_V1_SCHEMA" ]] &&
          PORT_ADAPTER_REASON=unsupported-version
        break
      done
    fi
    PORT_ADAPTER_VERSION="$version"
    return 2
  fi
  PORT_ADAPTER_VERSION="$RESS_V1_SCHEMA"
  manifest_name=$(basename "$PORT_ADAPTER_CONTROL")
  case "$PORT_ADAPTER_ARTIFACT_TYPE" in
    vault)
      PORT_ADAPTER_LOSSES_JSON=$(ress_v1_self_plugin_losses_json vault "$PORT_ADAPTER_SOURCE_ROOT") || return 1
      [[ $manifest_name != "$RESS_V1_LEGACY_MANIFEST" ]] ||
        PORT_ADAPTER_WARNINGS_JSON='[{"code":"legacy-manifest-name"}]'
      ;;
    loadout)
      PORT_ADAPTER_LOSSES_JSON=$(ress_v1_self_plugin_losses_json loadout "$PORT_ADAPTER_CONTROL") || return 1
      ;;
  esac
  PORT_ADAPTER_REPORT_FIELDS_JSON=$(jq -nc --arg manifest "$manifest_name" \
    '{sourceManifestName:$manifest}')
}

ress_v1_adapter_validate_history_tree() {
  local root="$1"
  if ress_v1_vault_validate_root "$root"; then
    return 0
  fi
  PORT_ADAPTER_REASON=malformed-or-unsupported-revision
  local control
  for control in "$root/$RESS_V1_CANONICAL_MANIFEST" "$root/$RESS_V1_LEGACY_MANIFEST"; do
    [[ -f $control && ! -L $control ]] || continue
    if [[ $(ress_v1_vault_manifest_version "$control" 2>/dev/null || true) != "$RESS_V1_SCHEMA" ]]; then
      PORT_ADAPTER_REASON=unsupported-version
    fi
    break
  done
  return 1
}

ress_v1_adapter_revision_created_at() {
  jq -er '.createdAt' "$PORT_ADAPTER_CONTROL"
}

ress_v1_adapter_validate_import() {
  case "$1" in
    loadout) ress_v1_profile_validate_file "$2" ;;
    vault) ress_v1_vault_validate_root "$2" ;;
    *) return 1 ;;
  esac
}

ress_v1_prepare_decisions() {
  local supplied="$1" allow_map="$2" ress_reason="$3" ress_decision montage_decision
  ress_decision=$(jq -r '.ressPlugin // ""' <<<"$supplied") || return 1
  montage_decision=$(jq -r '.montagePlugin // ""' <<<"$supplied") || return 1
  if (( RESS_V1_HAS_RESS )); then
    [[ $ress_decision == include || $ress_decision == omit ]] || {
      PORT_ADAPTER_REASON="$ress_reason"; return 3;
    }
  else ress_decision=include; fi
  if (( RESS_V1_HAS_MONTAGE )); then
    [[ $montage_decision == include || $montage_decision == omit ||
       ( $allow_map == 1 && $montage_decision == map-ress ) ]] || {
      PORT_ADAPTER_REASON=montage-self-plugin-decision-required; return 3;
    }
  else montage_decision=include; fi
  PORT_ADAPTER_DECISIONS_JSON=$(jq -nc --arg rd "$ress_decision" --arg md "$montage_decision" \
    '{ressPlugin:$rd,montagePlugin:$md}')
  PORT_ADAPTER_DECISION_FIELDS_JSON=$(jq -nc --arg rd "$ress_decision" --arg md "$montage_decision" \
    '{ressPluginDecision:$rd,montagePluginDecision:$md}')
}

ress_v1_adapter_prepare_import_decisions() {
  local kind="$1" source="$2" _report="$3" supplied="$4" reason=ress-self-plugin-decision-required
  ress_v1_find_self_plugins "$kind" "$source" || return 1
  if [[ $kind == loadout ]]; then
    RESS_V1_HAS_MONTAGE=0; reason=self-plugin-decision-required
  fi
  ress_v1_prepare_decisions "$supplied" 0 "$reason" || return $?
  [[ $kind != loadout ]] || PORT_ADAPTER_DECISION_FIELDS_JSON=$(jq -nc \
    --arg decision "$(jq -r '.ressPlugin' <<<"$PORT_ADAPTER_DECISIONS_JSON")" \
    '{selfPluginDecision:$decision}')
}

ress_v1_adapter_prepare_export_decisions() {
  local kind="$1" source="$2" supplied="$3"
  ress_v1_find_self_plugins "$kind" "$source" || return 1
  ress_v1_prepare_decisions "$supplied" 1 ress-self-plugin-decision-required
}

ress_v1_adapter_export_loss_code() {
  case "$1" in
    loadout) printf montage-repository-metadata ;;
    backup) printf montage-vault-identity ;;
    *) return 1 ;;
  esac
}
