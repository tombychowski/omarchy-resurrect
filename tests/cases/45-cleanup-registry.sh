PLUGIN_DIR="$REPO_DIR"
source "$REPO_DIR/lib/ress/core.sh"

approved="$SANDBOX/approved"
mkdir -p "$approved"

ress_make_temp_file "$approved/.file.XXXXXX"; STATUS=$?
assert_ok "controlled temporary file creation succeeds"
temp_file="$RESS_TEMP_PATH"
assert_file "$temp_file" "created file exists"
[[ $temp_file == "$approved/"* ]] && _pass || _fail "temporary file remains under its template parent"

ress_make_temp_dir "$approved/.dir.XXXXXX"; STATUS=$?
assert_ok "controlled temporary directory creation succeeds"
temp_dir="$RESS_TEMP_PATH"
assert_dir "$temp_dir" "created directory exists"
[[ $temp_dir == "$approved/"* ]] && _pass || _fail "temporary directory remains under its template parent"

# Simulate a compromised creator returning a path outside the requested parent;
# the containment guard must refuse and remove only that just-created sandbox path.
outside="$SANDBOX/outside-created"
mktemp() {
  [[ ${1:-} == -d ]] || return 1
  mkdir -p "$outside"
  printf '%s\n' "$outside"
}
ress_make_temp_dir "$approved/.escape.XXXXXX"; STATUS=$?
assert_fails "temporary creator refuses a result outside its approved parent"
assert_no_file "$outside" "refused outside result is cleaned without registration"
unset -f mktemp

# Cleanup honors the registered type. A path replaced after registration is not
# handed to the wrong deletion primitive.
ress_make_temp_file "$approved/.swap-file.XXXXXX"
swap_file="$RESS_TEMP_PATH"
rm -f "$swap_file"; mkdir "$swap_file"
ress_make_temp_dir "$approved/.swap-dir.XXXXXX"
swap_dir="$RESS_TEMP_PATH"
rmdir "$swap_dir"; printf 'replacement\n' >"$swap_dir"

ress_cleanup
assert_no_file "$temp_file" "registered temporary file is removed"
assert_no_file "$temp_dir" "registered temporary directory is removed"
assert_dir "$swap_file" "file registration does not recursively remove a replacement directory"
assert_file "$swap_dir" "directory registration does not remove a replacement file"
