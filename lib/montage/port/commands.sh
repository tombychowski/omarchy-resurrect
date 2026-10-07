# Format-neutral port argument parsing and explicit adapter dispatch.

cmd_port_inspect() {
  local source="" as_json=0 arg rc=0
  for arg in "$@"; do
    case "$arg" in
      --json) as_json=1 ;;
      -*) die "usage: mntg port FORMAT inspect SOURCE [--json]" ;;
      *) [[ -z $source ]] || die "usage: mntg port FORMAT inspect SOURCE [--json]"; source="$arg" ;;
    esac
  done
  [[ -n $source ]] || die "usage: mntg port FORMAT inspect SOURCE [--json]"
  port_inspection_json "$PORT_FORMAT" "$source" || rc=$?
  port_report_output "$PORT_RESULT" "$as_json" "$rc"
  return "$rc"
}

cmd_port_plan() {
  local source="" destination="" as_json=0 history=0 arg rc=0
  while (( $# > 0 )); do
    arg="$1"
    case "$arg" in
      --json) as_json=1 ;;
      --history) history=1 ;;
      --destination) shift; destination="${1:-}" ;;
      --destination=*) destination="${arg#*=}" ;;
      -*) die "usage: mntg port FORMAT plan SOURCE --destination PATH [--history] [--json]" ;;
      *) [[ -z $source ]] || die "usage: mntg port FORMAT plan SOURCE --destination PATH [--history] [--json]"; source="$arg" ;;
    esac
    shift
  done
  [[ -n $source && -n $destination ]] ||
    die "usage: mntg port FORMAT plan SOURCE --destination PATH [--history] [--json]"
  port_plan_json "$PORT_FORMAT" "$source" "$destination" "$history" || rc=$?
  port_report_output "$PORT_RESULT" "$as_json" "$rc"
  return "$rc"
}

cmd_port_transfer() {
  local direction="$1" type="$2" primary="" repository="" loadout_id="" selector=""
  local destination="" accepted_loss="" as_json=0 history=0 compatible_only=0 arg consumed
  shift 2
  PORT_ADAPTER_CLI_DECISIONS_JSON='{}'
  while (( $# > 0 )); do
    arg="$1"; consumed=1
    case "$arg" in
      --json) as_json=1 ;;
      --history) history=1 ;;
      --compatible-only) compatible_only=1 ;;
      --repository|--loadout|--backup|--destination|--accept-loss)
        (( $# > 1 )) || die "missing value for $arg"
        case "$arg" in
          --repository) repository="$2" ;; --loadout) loadout_id="$2" ;;
          --backup) selector="$2" ;; --destination) destination="$2" ;;
          --accept-loss) accepted_loss="$2" ;;
        esac
        consumed=2
        ;;
      --repository=*) repository="${arg#*=}" ;; --loadout=*) loadout_id="${arg#*=}" ;;
      --backup=*) selector="${arg#*=}" ;; --destination=*) destination="${arg#*=}" ;;
      --accept-loss=*) accepted_loss="${arg#*=}" ;;
      -*)
        PORT_ADAPTER_OPTION_CONSUMED=0
        port_adapter_call command-option "$arg" "${2:-}" ||
          die "unsupported $PORT_FORMAT port option: $arg"
        consumed="$PORT_ADAPTER_OPTION_CONSUMED"
        ;;
      *) [[ -z $primary ]] || die "only one port source may be selected"; primary="$arg" ;;
    esac
    shift "$consumed"
  done
  port_adapter_call command-decisions "$direction" "$type" ||
    die "invalid $PORT_FORMAT decision option"
  case "$direction:$type" in
    import:loadout)
      [[ -n $primary && -n $repository && -n $loadout_id ]] ||
        die "usage: mntg port FORMAT import loadout SOURCE --repository NAME --loadout ID [OPTIONS]"
      port_import_loadout "$PORT_FORMAT" "$primary" "$repository" "$loadout_id" "$as_json" \
        "$PORT_ADAPTER_CLI_DECISIONS_JSON"
      ;;
    import:vault)
      [[ -n $primary && -n $destination ]] ||
        die "usage: mntg port FORMAT import vault SOURCE --destination PATH [OPTIONS]"
      (( compatible_only == 0 || history == 1 )) || die "--compatible-only requires --history"
      [[ -z $accepted_loss || $accepted_loss == unsupported-history-revisions ]] ||
        die "unsupported loss acceptance: $accepted_loss"
      port_import_vault "$PORT_FORMAT" "$primary" "$destination" "$as_json" \
        "$PORT_ADAPTER_CLI_DECISIONS_JSON" "$history" "$compatible_only" "$accepted_loss"
      ;;
    export:loadout)
      [[ -n $primary && -n $loadout_id && -n $destination ]] ||
        die "usage: mntg port FORMAT export loadout REPOSITORY --loadout ID --destination PATH --accept-loss CODE [OPTIONS]"
      port_export_loadout "$PORT_FORMAT" "$primary" "$loadout_id" "$destination" \
        "$as_json" "$accepted_loss" "$PORT_ADAPTER_CLI_DECISIONS_JSON"
      ;;
    export:backup)
      [[ -z $primary && -n $selector && -n $destination ]] ||
        die "usage: mntg port FORMAT export backup --backup COMMIT --destination PATH --accept-loss CODE [OPTIONS]"
      port_export_backup "$PORT_FORMAT" "$selector" "$destination" "$as_json" \
        "$accepted_loss" "$PORT_ADAPTER_CLI_DECISIONS_JSON"
      ;;
    *) die "unknown $PORT_FORMAT $direction type: ${type:-missing}" ;;
  esac
}

cmd_port() {
  local target="${1:-}" command="${2:-}"
  [[ -n $target ]] || die "usage: mntg port FORMAT COMMAND ..."
  port_adapter_select "$target" || die "unsupported port format: $target"
  shift 2 || true
  case "$command" in
    inspect) cmd_port_inspect "$@" ;;
    plan) cmd_port_plan "$@" ;;
    import|export) cmd_port_transfer "$command" "${1:-}" "${@:2}" ;;
    *) die "unknown port command: ${command:-missing}" ;;
  esac
}
