source "$TESTS_DIR/lib/loadout.sh"

config_dir="$XDG_CONFIG_HOME/montage"
config_file="$config_dir/config"
mkdir -p "$config_dir"

mntg set AUR=ask
assert_ok "initial settings are written"
before=$(sha256sum "$config_file")

lock_ready="$SANDBOX/config-lock-ready"
lock_release="$SANDBOX/config-lock-release"
(
  exec 7>"$config_dir/.lock"
  flock 7
  : >"$lock_ready"
  while [[ ! -e $lock_release ]]; do sleep 0.02; done
) &
lock_pid=$!
for _ in {1..100}; do [[ -e $lock_ready ]] && break; sleep 0.02; done
assert_file "$lock_ready" "independent config-lock owner started"

mntg set AUR=yes
assert_fails "settings update fails when the config lock times out"
assert_output "configuration is busy; try again" "lock timeout has a clear retryable error"
after=$(sha256sum "$config_file")
assert_equals "$after" "$before" "timed-out writer leaves config byte-for-byte unchanged"

: >"$lock_release"
wait "$lock_pid"

# Both writers start while a short-lived holder owns the lock. Once released,
# each must acquire it and publish one complete retained-schema document.
queue_ready="$SANDBOX/config-queue-ready"
queue_release="$SANDBOX/config-queue-release"
(
  exec 7>"$config_dir/.lock"
  flock 7
  : >"$queue_ready"
  while [[ ! -e $queue_release ]]; do sleep 0.02; done
) &
queue_pid=$!
for _ in {1..100}; do [[ -e $queue_ready ]] && break; sleep 0.02; done

"$MNTG" set AUR=yes >"$SANDBOX/writer-one.out" 2>&1 &
writer_one=$!
"$MNTG" set AUR=no >"$SANDBOX/writer-two.out" 2>&1 &
writer_two=$!
sleep 0.1
: >"$queue_release"
wait "$queue_pid"
wait "$writer_one"; writer_one_status=$?
wait "$writer_two"; writer_two_status=$?

assert_equals "$writer_one_status" "0" "first queued settings writer succeeds"
assert_equals "$writer_two_status" "0" "second queued settings writer succeeds"
assert_equals "$(grep -c '^AUR=' "$config_file")" "1" \
  "serialized writers leave one complete retained setting"
case "$(sed -n 's/^AUR=//p' "$config_file")" in yes|no) STATUS=0 ;; *) STATUS=1 ;; esac
assert_ok "the final serialized value belongs to one complete writer"
