# Baseline evidence

This matrix records the implementation and verification evidence reviewed before the baseline delta specs become main specifications. Function names are used instead of line numbers so the references remain useful as the script evolves.

Evidence classifications:

- **Automated** — exercised by the named repository test case.
- **Static** — checked against source structure or syntax, but not rendered end to end.
- **Real machine** — requires the scratch-machine procedure in `docs/testing/strategy.md`.
- **Fresh VM** — requires the clean-Omarchy procedure in `docs/testing/fresh-machine-validation.md`.

## Vault capture

| Scenario | Implementation | Verification |
|---|---|---|
| Enabled categories are captured | `cmd_backup`, `capture_packages`, `capture_config`, `capture_omarchy`, `capture_webapps`, `capture_plugins`, `write_manifest` in `bin/ress` | Automated: `tests/cases/01-backup.sh` |
| Disabled category is skipped and reported | `cat_enabled`, `cmd_backup`, `step_skip` in `bin/ress` | Automated: `tests/cases/15-secrets.sh`; protocol form in `tests/cases/12-porcelain.sh` |
| Unlisted configuration is reported | `capture_config` writes `report/not-captured.txt` | Automated: `tests/cases/01-backup.sh`; file and message behavior also reviewed in source |
| Unsafe symlink is not followed and is reported | `capture_config` uses `rsync --safe-links` and writes `report/symlinks-skipped.txt` | Automated: `tests/cases/14-hostile-vault.sh`; source review for the capture-side report |
| Local plugin or theme remote is reported | `capture_plugins`, Omarchy theme capture, `valid_git_remote` | Automated: `tests/cases/21-plugin-remotes.sh` |
| Unsupported web-app launcher is omitted and reported | `launcher_travels`, `capture_webapps` | Automated: `tests/cases/18-webapp-launchers.sh` |

## Resumable restore

| Scenario | Implementation | Verification |
|---|---|---|
| Live restore previews before mutation | `report_executable_content`, `report_restore_preview`, confirmation in `cmd_restore` | Automated: `tests/cases/03-units.sh`, `05-aur.sh`, `06-dry-run.sh` |
| `--only` restores selected categories | selection validation and category loop in `cmd_restore` | Automated: `tests/cases/11-empty.sh` |
| Unknown category is rejected before mutation | category validation in `cmd_restore` | Automated: `tests/cases/11-empty.sh` |
| Interrupted restore resumes | `RESTORE_STATE`, `step_done`, `mark_done`, `mark_partial` | Automated: `tests/cases/05-aur.sh`, `11-empty.sh` |
| Changed snapshot does not reuse progress | snapshot key stored with restore state | Automated: `tests/cases/11-empty.sh` |
| Dry run reports actions without mutation | `DRY_RUN`, `DRYRUN_VAULT`, preview functions | Automated: `tests/cases/06-dry-run.sh` |

## Non-destructive defaults

| Scenario | Implementation | Verification |
|---|---|---|
| Extra package remains installed | restore/apply calculate missing packages with `comm -23`; no package-removal path exists | Automated command-boundary evidence: `tests/cases/05-aur.sh`, `10-apply.sh`, `14-hostile-vault.sh`; Fresh VM for real package-manager behavior |
| Extra file remains present | restore uses additive `rsync` without `--delete` | Automated command-boundary evidence: `tests/cases/02-vault-format.sh`, `06-dry-run.sh`; Real machine for real rsync behavior |
| Existing file is backed up before replacement | `RSYNC_SAFE` and web-app icon restore use `--backup --suffix=.ress-bak` | Automated: `tests/cases/02-vault-format.sh`, `18-webapp-launchers.sh` |
| New file does not receive a fabricated prior backup | same rsync contract; backups are created only on replacement | Automated behavior exercised by new-file restores throughout `tests/cases/06-dry-run.sh` and `18-webapp-launchers.sh`; Real machine for real rsync behavior |
| Already-installed package is skipped | restore/apply compare desired packages with `pacman -Qq` before using `--needed` | Automated: `tests/cases/08-verify.sh`, `10-apply.sh`; Fresh VM for the real package manager |

## Explicit execution consent

| Scenario | Implementation | Verification |
|---|---|---|
| `--yes` does not authorize AUR | `AUR_CHOICE`, `aur_gate` | Automated: `tests/cases/05-aur.sh` |
| Review mode preserves package review | `aur_install` omits noninteractive flags in review mode | Automated: `tests/cases/05-aur.sh` |
| Denied AUR package is removed before consent | `aur_denied`, `aur_gate` | Automated: `tests/cases/05-aur.sh` |
| `--yes` does not enable services | `UNITS_CHOICE`, `units_decision_kind`, `restore_user_units` | Automated: `tests/cases/03-units.sh` |
| Service prompt shows executable commands | `pending_units`, `unit_exec`, `list_units` | Automated: `tests/cases/03-units.sh`, `06-dry-run.sh` |
| Declined AUR remains pending | `mark_partial`, `was_partial` | Automated: `tests/cases/05-aur.sh` |
| Deferred services can be enabled later | `cmd_enable_units` | Automated: `tests/cases/03-units.sh` |
| Autostart is excluded by default | `CAPTURE_AUTOSTART` branch in `capture_config` | Automated: `tests/cases/09-autostart.sh` |

## Credential protection

| Scenario | Implementation | Verification |
|---|---|---|
| Private key is excluded from plain capture | merged mandatory/user exclusion lists in `build_excludes` and `capture_config` | Automated: `tests/cases/07-secret-scan.sh`, `15-secrets.sh` |
| Warning scan identifies file/type without secret | `secret_scan`, `report_secret_findings` | Automated: `tests/cases/07-secret-scan.sh`, `12-porcelain.sh` |
| Blocking scan prevents commit | `cmd_backup` returns before `git add`/commit in block mode | Automated: `tests/cases/07-secret-scan.sh`, `12-porcelain.sh` |
| Default backup skips secrets | default config and `cat_enabled` | Automated: `tests/cases/15-secrets.sh` |
| Recipient mode supports unattended backup | `capture_secrets` recipient branch | Automated: `tests/cases/15-secrets.sh` |
| Passphrase mode requires a terminal | terminal check in `capture_secrets`/`restore_secrets` | Automated: `tests/cases/15-secrets.sh` |
| Restored secrets use private permissions | `private_dir`, secret archive extraction permission handling | Automated: `tests/cases/15-secrets.sh` |

## Loadout sharing

| Scenario | Implementation | Verification |
|---|---|---|
| Share excludes home content and commands | fixed `jq` object in `cmd_share` | Automated: `tests/cases/10-apply.sh`, `18-webapp-launchers.sh`; schema shape reviewed directly |
| Unrepresentable launcher is omitted | `collect_webapps_json`, `launchers_left_out_of_profile` | Automated: `tests/cases/18-webapp-launchers.sh` |
| Apply preview lists all supported actions and limits | preview section in `cmd_apply` | Automated: `tests/cases/10-apply.sh` |
| Apply dry run installs nothing | `DRY_RUN` return before action section | Automated: `tests/cases/10-apply.sh` |
| Pinned plugin is checked out detached at the recorded commit | `clone_pinned`, plugin loop in `cmd_apply` | Automated: `tests/cases/10-apply.sh` |
| Unpinned code is refused by default | plugin/theme filtering in `cmd_apply` | Automated: `tests/cases/10-apply.sh` |
| ress short link is expanded locally | `ress_link`, `normalize_source` | Automated: `tests/cases/10-apply.sh`; source review confirms expansion precedes `fetch_profile` |

## Machine verification

| Scenario | Implementation | Verification |
|---|---|---|
| Matching machine succeeds | `cmd_verify` | Automated: `tests/cases/08-verify.sh` |
| Mismatch names categories/items and exits non-zero | `cmd_verify` | Automated: `tests/cases/08-verify.sh` |
| Non-restorable entry is classified separately | refused collections in `cmd_verify` | Automated: `tests/cases/18-webapp-launchers.sh`, `21-plugin-remotes.sh` |
| Name containing spaces remains one JSON entry | unit-separator list encoding and JSON conversion in `cmd_verify` | Automated: `tests/cases/18-webapp-launchers.sh` |
| Malformed status inputs retain valid fallback output | `json_flag`, `json_number`, `manifest_json`, `cmd_status` | Automated: `tests/cases/19-status-config.sh` |

## CLI consumer protocol

| Scenario | Implementation | Verification |
|---|---|---|
| Successful porcelain operation emits only records | `emit`, `step_*`, `progress`, `note`, terminal `DONE` records | Automated: `tests/cases/12-porcelain.sh` |
| Skipped/deferred work appears in porcelain | `step_skip`, `mark_partial`, final deferred log | Automated: `tests/cases/12-porcelain.sh` |
| `status --json` emits one object | `cmd_status` | Automated: `tests/cases/01-backup.sh`, `19-status-config.sh` |
| `verify --json` emits category summaries and arrays | `cmd_verify` | Automated: `tests/cases/08-verify.sh`, `18-webapp-launchers.sh` |
| Human warning remains readable outside protocol mode | non-porcelain branches of `step_*` and secret report | Automated: `tests/cases/07-secret-scan.sh`, `12-porcelain.sh` |

## Panel integration

| Scenario | Implementation | Verification |
|---|---|---|
| Panel refreshes from CLI status | `Service.qml` `statusProc` runs `ress status --json` | Static: `tests/cases/16-qml.sh`; Fresh VM for rendered state |
| Malformed status is not turned into fabricated values | `Service.qml` catches JSON parse failure and sets `status` to `null` | Static: `tests/cases/16-qml.sh`; Fresh VM for rendered fallback |
| Panel backup runs through CLI and renders records | `Service.qml` `run`, `backupNow`, `handleRecord`; `Model.parseRecord` | Automated parser/static integration: `tests/model-test.js`, `tests/cases/16-qml.sh`; Fresh VM for rendered progress |
| Restore opens an interactive terminal | `Panel.qml` restore trigger uses `omarchy-launch-terminal` | Static: `tests/cases/16-qml.sh`; Fresh VM for terminal interaction |
| Fresh, stale, missing, running, and failed conditions remain distinct | `Model.freshness`, `Service.qml` busy/error state, `Panel.qml` icon/hero/error bindings | Automated model/static integration: `tests/model-test.js`, `tests/cases/16-qml.sh`; Fresh VM for rendering |
| Keyboard-only navigation and actions | `PanelKeyCatcher`, `moveCursor`, `activate`, text shortcuts in `Panel.qml` | Static: `tests/cases/16-qml.sh`; Fresh VM for focus and rendered behavior |

## Schema compatibility

| Scenario | Implementation | Verification |
|---|---|---|
| Hostile schema expression is rejected before use | `valid_int` before arithmetic comparison in restore/apply | Automated: `tests/cases/14-hostile-vault.sh` |
| Future schema is rejected | schema equality check in `cmd_restore` | Automated: `tests/cases/14-hostile-vault.sh` |
| New backup writes `ress.json` | `VAULT_MANIFEST`, `write_manifest` | Automated: `tests/cases/02-vault-format.sh` |
| Legacy manifest can be restored | `manifest_path`, `has_manifest` | Automated: `tests/cases/02-vault-format.sh` |
| Subsequent backup migrates legacy manifest | `write_manifest` removes the legacy name | Automated: `tests/cases/02-vault-format.sh` |

## Coverage conclusion

All baseline scenarios have source evidence and either automated verification or an explicit real-machine/fresh-VM classification. No new runtime behavior is required by this baseline. The panel's malformed-status scenario is intentionally limited to refusing fabricated values; a distinct unavailable label is not current behavior. The six remaining fresh-machine gaps are package installation, a genuinely empty system, rendered panel behavior, services starting at login, visible theme application, and timing claims.

The affected panel/model coverage was rerun during reconciliation with `./tests/run.sh qml`: 1 case passed with 8 assertions. No new test was added because the unautomated panel claims are rendering, focus, and terminal-handoff behavior that the existing QML/static harness cannot prove without starting the real Omarchy shell; those remain explicitly classified as fresh-VM checks.
