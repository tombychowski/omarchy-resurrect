#!/bin/bash
#
# Public loadout source fetching, normalization, digest/identity, and conversion
# from a normalized profile to resource definitions.
# Depends on core.sh and safety.sh. Owns profile schema and apply work paths;
# used by share, update, and apply. Definitions only at source time.

PROFILE_SCHEMA=1
PROFILE_DIR_DEFAULT="${XDG_DATA_HOME:-$HOME/.local/share}/montage/profile"
APPLY_WORK=""

profile_metadata_valid() {
  local name="$1" description="$2"
  (( ${#name} > 0 && ${#name} <= 120 && ${#description} <= 1000 )) || return 1
  [[ $(plain "$name") == "$name" && $(plain "$description") == "$description" ]]
}
# ------------------------------------------------------------------- apply

fetch_profile() {
  local source="$1" dest="$2" control="" display_source
  display_source=$(strip_credentials "$source")
  if [[ -e $source || -L $source ]]; then
    if [[ -d $source && ! -L $source ]]; then
      control=$(safe_control_file "$source" profile.json) ||
        die "profile.json must be a contained regular file"
    else
      control=$(safe_control_file "$(dirname "$source")" "$(basename "$source")") ||
        die "profile source must be a contained regular file"
    fi
    cp "$control" "$dest/profile.json"
  elif [[ $source == *.json ]]; then
    valid_https "$source" || die "profile URLs must be https"
    curl -fsSL --max-time 20 -o "$dest/profile.json" -- "$source" ||
      die "could not fetch $display_source"
  else
    valid_https "$source" || die "profile URLs must be https"
    git clone -q --depth 1 -- "$source" "$dest/repo" 2>/dev/null ||
      die "could not clone $display_source"
    git -C "$dest/repo" remote set-url origin "$display_source" 2>/dev/null || true
    control=$(safe_control_file "$dest/repo" profile.json) ||
      die "profile.json must be a contained regular file"
    cp "$control" "$dest/profile.json"
  fi
  jq -e . "$dest/profile.json" >/dev/null 2>&1 || die "profile.json is not valid JSON"
  local schema kind
  schema=$(jq -r '.schemaVersion // 0' "$dest/profile.json")
  kind=$(jq -r '.kind // ""' "$dest/profile.json")
  [[ $kind == "omarchy-loadout" ]] ||
    die "not an Omarchy loadout (kind: $(plain "${kind:-missing}"))"
  valid_int "$schema" ||
    die "this loadout does not declare a schema version as a number — refusing to read it"
  (( schema == PROFILE_SCHEMA )) ||
    die "loadout schema $(plain "$schema") is not readable by mntg $VERSION"
}

canonical_remote() {
  local value
  value=$(strip_credentials "$1")
  value="${value%.git}"
  value="${value%/}"
  printf '%s' "$value"
}

# Strict validation for a normalized portable leaf written into native
# repositories or persisted as applied desired state. Apply may accept unknown
# powerless input fields before normalization; stored leaves use this exact
# schema so their digest and interoperability remain deterministic.
profile_document_valid() {
  local profile="$1" value id url commit icon
  portable_profile_v1_shape_valid "$profile" || return 1

  profile_metadata_valid "$(jq -r '.name' <<<"$profile")" "$(jq -r '.description' <<<"$profile")" || return 1
  while IFS= read -r value; do valid_pkg "$value" || return 1; done \
    < <(jq -r '.packages.native[], .packages.aur[]' <<<"$profile")
  jq -e '(.packages.native | length == (unique | length)) and
    (.packages.aur | length == (unique | length))' <<<"$profile" >/dev/null || return 1
  while IFS=$'\t' read -r id url commit; do
    valid_id "$id" && valid_https "$url" && [[ $(canonical_remote "$url") == "$url" ]] &&
      { [[ -z $commit ]] || valid_sha "$commit"; } || return 1
  done < <(jq -r '.plugins[] | [.id,.url,.commit] | @tsv' <<<"$profile")
  jq -e '([.plugins[].id] | length) == ([.plugins[].id] | unique | length)' <<<"$profile" >/dev/null || return 1
  while IFS=$'\t' read -r value url icon; do
    valid_label "$value" && valid_public_https "$url" && { [[ -z $icon ]] || valid_icon "$icon"; } || return 1
  done < <(jq -r '.webapps[] | [.name,.url,.icon] | @tsv' <<<"$profile")
  jq -e '([.webapps[].name] | length) == ([.webapps[].name] | unique | length)' <<<"$profile" >/dev/null || return 1
  value=$(jq -r '.theme.name' <<<"$profile"); url=$(jq -r '.theme.url' <<<"$profile"); commit=$(jq -r '.theme.commit' <<<"$profile")
  if [[ -n $value ]]; then
    valid_theme "$value" || return 1
    { [[ -z $url ]] || { valid_https "$url" && [[ $(canonical_remote "$url") == "$url" ]]; }; } || return 1
    { [[ -z $commit ]] || valid_sha "$commit"; } || return 1
  else
    [[ -z $url && -z $commit ]] || return 1
  fi
}

# Unknown profile fields stay powerless and are not part of local identity.
# Invalid supported entries are omitted here and reported by apply planning.
normalize_profile() {
  local input="$1" output="$2" native=() aur=() plugins=() webapps=()
  local value id url sha label icon
  NORMALIZE_REFUSED_PACKAGES=0
  NORMALIZE_REFUSED_INTEGRATIONS=0
  while IFS= read -r url; do
    url_has_credentials "$url" &&
      die "loadout contains a credential-bearing web app URL"
  done < <(jq -r '.webapps[]?.url // empty' "$input")
  while IFS= read -r value; do
    if valid_pkg "$value"; then native+=("$value"); else NORMALIZE_REFUSED_PACKAGES=$((NORMALIZE_REFUSED_PACKAGES + 1)); fi
  done \
    < <(jq -r '.packages.native[]? // empty' "$input")
  while IFS= read -r value; do
    if valid_pkg "$value"; then aur+=("$value"); else NORMALIZE_REFUSED_PACKAGES=$((NORMALIZE_REFUSED_PACKAGES + 1)); fi
  done \
    < <(jq -r '.packages.aur[]? // empty' "$input")
  while IFS=$'\t' read -r id url sha; do
    [[ -n $id ]] || continue
    url=$(canonical_remote "$url")
    if ! valid_id "$id" || ! valid_https "$url" || { [[ -n $sha ]] && ! valid_sha "$sha"; }; then
      NORMALIZE_REFUSED_INTEGRATIONS=$((NORMALIZE_REFUSED_INTEGRATIONS + 1)); continue
    fi
    plugins+=("$(jq -nc --arg id "$id" --arg url "$url" --arg commit "$sha" '$ARGS.named')")
  done < <(jq -r '.plugins[]? | [.id, .url, (.commit // "")] | @tsv' "$input")
  while IFS=$'\t' read -r label url icon; do
    [[ -n $label ]] || continue
    if ! valid_label "$label" || ! valid_public_https "$url"; then
      NORMALIZE_REFUSED_INTEGRATIONS=$((NORMALIZE_REFUSED_INTEGRATIONS + 1)); continue
    fi
    valid_icon "$icon" || icon=""
    webapps+=("$(jq -nc --arg name "$label" --arg url "$url" --arg icon "$icon" '$ARGS.named')")
  done < <(jq -r '.webapps[]? | [.name, .url, (.icon // "")] | @tsv' "$input")

  local theme_name theme_url theme_commit
  theme_name=$(jq -r '.theme.name // ""' "$input")
  theme_url=$(canonical_remote "$(jq -r '.theme.url // ""' "$input")")
  theme_commit=$(jq -r '.theme.commit // ""' "$input")
  valid_theme "$theme_name" || theme_name=""
  valid_https "$theme_url" || theme_url=""
  valid_sha "$theme_commit" || theme_commit=""

  local native_json aur_json plugins_json webapps_json
  native_json=$(printf '%s\n' "${native[@]:-}" | sort -u | jq -Rsc 'split("\n") | map(select(length > 0))')
  aur_json=$(printf '%s\n' "${aur[@]:-}" | sort -u | jq -Rsc 'split("\n") | map(select(length > 0))')
  if (( ${#plugins[@]} )); then
    plugins_json=$(printf '%s\n' "${plugins[@]}" | jq -s 'sort_by(.id) | unique_by(.id)')
  else plugins_json='[]'; fi
  if (( ${#webapps[@]} )); then
    webapps_json=$(printf '%s\n' "${webapps[@]}" | jq -s 'sort_by(.name) | unique_by(.name)')
  else webapps_json='[]'; fi

  jq -S -n \
    --argjson schemaVersion "$PROFILE_SCHEMA" --arg kind omarchy-loadout \
    --arg name "$(plain "$(jq -r '.name // "Untitled"' "$input")")" \
    --arg author "$(plain "$(jq -r '.author // "unknown"' "$input")")" \
    --arg description "$(plain "$(jq -r '.description // ""' "$input")")" \
    --arg createdAt "$(plain "$(jq -r '.createdAt // "?"' "$input")")" \
    --arg omarchy "$(plain "$(jq -r '.omarchy // "unknown"' "$input")")" \
    --argjson native "$native_json" --argjson aur "$aur_json" \
    --argjson plugins "$plugins_json" --argjson webapps "$webapps_json" \
    --arg themeName "$theme_name" --arg themeUrl "$theme_url" --arg themeCommit "$theme_commit" \
    '{schemaVersion: $schemaVersion, kind: $kind, name: $name, author: $author,
      description: $description, createdAt: $createdAt, omarchy: $omarchy,
      packages: {native: $native, aur: $aur}, plugins: $plugins, webapps: $webapps,
      theme: {name: $themeName, url: $themeUrl, commit: $themeCommit}}' >"$output"
}

profile_digest() { jq -S -c . "$1" | sha256sum | awk '{print $1}'; }

loadout_local_id() {
  local name="$1" digest="$2" slug id n=12
  slug=$(printf '%s' "$name" | tr '[:upper:]' '[:lower:]' |
    sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//' | cut -c1-48)
  [[ -n $slug ]] || slug="loadout"
  while :; do
    id="$slug-${digest:0:n}"
    if ! jq -e --arg id "$id" '.loadouts[] | select(.id == $id)' <<<"$REGISTRY" >/dev/null; then
      printf '%s' "$id"; return 0
    fi
    n=$((n + 4)); (( n <= 64 )) || die "could not assign a unique local loadout id"
  done
}

profile_resources_json() {
  local profile="$1" loadout_id="$2"
  jq -c --arg loadout "$loadout_id" '
    ([.packages.native[]? | {id:("package:" + .), kind:"package", name:.,
       definition:{name:.}, requested:{channels:["native"]}}] +
     [.packages.aur[]? | {id:("package:" + .), kind:"package", name:.,
       definition:{name:.}, requested:{channels:["aur"]}}] +
     [.plugins[]? | {id:("plugin:" + .id), kind:"plugin", name:.id,
       definition:{id:.id,url:.url,commit:.commit}, requested:{}}] +
     [.webapps[]? | {id:("webapp:" + .name), kind:"webapp", name:.name,
       definition:{name:.name,url:.url,icon:.icon}, requested:{}}] +
     [select(.theme.name != "") | {id:("theme-install:" + .theme.name),
       kind:"theme-install", name:.theme.name,
       definition:{name:.theme.name,url:.theme.url,commit:.theme.commit}, requested:{}}] +
     [select(.theme.name != "") | {id:("theme-active:" + $loadout),
       kind:"theme-active", name:.theme.name,
       definition:{name:.theme.name}, requested:{}}]) |
    sort_by(.id) | group_by(.id) | map(
      if length == 1 then .[0]
      else .[0] * {requested:{channels:([.[].requested.channels[]?] | unique)}} end)
  ' "$profile"
}
