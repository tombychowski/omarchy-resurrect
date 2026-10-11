#!/bin/bash
# Focused public parsing for the one retained foreign boundary.

ress_migration_parse_options() {
  RESS_COMMAND_SOURCE=""
  RESS_COMMAND_REPOSITORY=""
  RESS_COMMAND_LOADOUT=""
  RESS_COMMAND_RESS_DECISION=""
  RESS_COMMAND_MONTAGE_DECISION=""
  RESS_COMMAND_JSON=0
  local allow_destination="$1" arg
  shift
  while (( $# > 0 )); do
    arg="$1"
    case "$arg" in
      --json) RESS_COMMAND_JSON=1 ;;
      --repository)
        [[ $allow_destination == 1 && $# -gt 1 ]] || return 1
        RESS_COMMAND_REPOSITORY="$2"; shift
        ;;
      --repository=*) [[ $allow_destination == 1 ]] || return 1; RESS_COMMAND_REPOSITORY="${arg#*=}" ;;
      --loadout)
        [[ $allow_destination == 1 && $# -gt 1 ]] || return 1
        RESS_COMMAND_LOADOUT="$2"; shift
        ;;
      --loadout=*) [[ $allow_destination == 1 ]] || return 1; RESS_COMMAND_LOADOUT="${arg#*=}" ;;
      --ress-plugin)
        (( $# > 1 )) || return 1
        RESS_COMMAND_RESS_DECISION="$2"; shift
        ;;
      --ress-plugin=*) RESS_COMMAND_RESS_DECISION="${arg#*=}" ;;
      --montage-plugin)
        (( $# > 1 )) || return 1
        RESS_COMMAND_MONTAGE_DECISION="$2"; shift
        ;;
      --montage-plugin=*) RESS_COMMAND_MONTAGE_DECISION="${arg#*=}" ;;
      -*) return 1 ;;
      *) [[ -z $RESS_COMMAND_SOURCE ]] || return 1; RESS_COMMAND_SOURCE="$arg" ;;
    esac
    shift
  done
  [[ -n $RESS_COMMAND_SOURCE ]] || return 1
  if [[ $allow_destination == 1 ]]; then
    [[ -n $RESS_COMMAND_REPOSITORY && -n $RESS_COMMAND_LOADOUT ]] || return 1
  else
    [[ -z $RESS_COMMAND_REPOSITORY && -z $RESS_COMMAND_LOADOUT ]] || return 1
  fi
}

cmd_port() {
  local format="${1:-}" action="${2:-}"
  [[ $format == ress ]] || die "unsupported port format: ${format:-missing}"
  shift 2 || true
  case "$action" in
    inspect)
      ress_migration_parse_options 0 "$@" ||
        die "usage: mntg port ress inspect SOURCE [--ress-plugin include|omit] [--montage-plugin include|omit] [--json]"
      ress_migration_inspect "$RESS_COMMAND_SOURCE" "$RESS_COMMAND_JSON" \
        "$RESS_COMMAND_RESS_DECISION" "$RESS_COMMAND_MONTAGE_DECISION"
      ;;
    import)
      [[ ${1:-} == loadout ]] || die "unknown Ress import type: ${1:-missing}"
      shift
      ress_migration_parse_options 1 "$@" ||
        die "usage: mntg port ress import loadout SOURCE --repository NAME --loadout ID [--ress-plugin include|omit] [--montage-plugin include|omit] [--json]"
      ress_migration_import "$RESS_COMMAND_SOURCE" "$RESS_COMMAND_REPOSITORY" \
        "$RESS_COMMAND_LOADOUT" "$RESS_COMMAND_JSON" "$RESS_COMMAND_RESS_DECISION" \
        "$RESS_COMMAND_MONTAGE_DECISION"
      ;;
    *) die "unknown Ress port command: ${action:-missing}" ;;
  esac
}
