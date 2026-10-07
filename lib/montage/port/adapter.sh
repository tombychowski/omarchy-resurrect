# Explicit port-adapter selection and callback dispatch.
#
# User input and callback names select only literal cases. Shared engine
# modules never construct or evaluate adapter function names.

PORT_FORMAT=""
PORT_ADAPTER_ARTIFACT_TYPE=""
PORT_ADAPTER_SOURCE_ROOT=""
PORT_ADAPTER_CONTROL=""
PORT_ADAPTER_VERSION=""
PORT_ADAPTER_SUPPORTED_VERSION=""
PORT_ADAPTER_WARNINGS_JSON='[]'
PORT_ADAPTER_LOSSES_JSON='[]'
PORT_ADAPTER_REASON=""
PORT_ADAPTER_REPORT_FIELDS_JSON='{}'
PORT_ADAPTER_DECISIONS_JSON='{}'
PORT_ADAPTER_DECISION_FIELDS_JSON='{}'
PORT_ADAPTER_CLI_DECISIONS_JSON='{}'
PORT_ADAPTER_OPTION_CONSUMED=0

port_adapter_context_reset() {
  PORT_ADAPTER_ARTIFACT_TYPE="unknown"
  PORT_ADAPTER_SOURCE_ROOT=""
  PORT_ADAPTER_CONTROL=""
  PORT_ADAPTER_VERSION=""
  PORT_ADAPTER_WARNINGS_JSON='[]'
  PORT_ADAPTER_LOSSES_JSON='[]'
  PORT_ADAPTER_REASON=""
  PORT_ADAPTER_REPORT_FIELDS_JSON='{}'
  PORT_ADAPTER_DECISIONS_JSON='{}'
  PORT_ADAPTER_DECISION_FIELDS_JSON='{}'
}

port_adapter_select() {
  case "$1" in
    ress|ress-v1)
      PORT_FORMAT=ress-v1
      PORT_ADAPTER_SUPPORTED_VERSION="$RESS_V1_SCHEMA"
      ;;
    *) return 1 ;;
  esac
}

port_adapter_call() {
  local callback="$1"; shift
  case "$PORT_FORMAT:$callback" in
    ress-v1:inspect) ress_v1_adapter_inspect "$@" ;;
    ress-v1:validate-history-tree) ress_v1_adapter_validate_history_tree "$@" ;;
    ress-v1:revision-created-at) ress_v1_adapter_revision_created_at "$@" ;;
    ress-v1:validate-import) ress_v1_adapter_validate_import "$@" ;;
    ress-v1:prepare-import-decisions) ress_v1_adapter_prepare_import_decisions "$@" ;;
    ress-v1:prepare-export-decisions) ress_v1_adapter_prepare_export_decisions "$@" ;;
    ress-v1:export-loss-code) ress_v1_adapter_export_loss_code "$@" ;;
    ress-v1:translate-import) ress_v1_adapter_translate_import "$@" ;;
    ress-v1:translate-export) ress_v1_adapter_translate_export "$@" ;;
    ress-v1:validate-export) ress_v1_adapter_validate_export "$@" ;;
    ress-v1:command-option) ress_v1_adapter_command_option "$@" ;;
    ress-v1:command-decisions) ress_v1_adapter_command_decisions "$@" ;;
    *) return 1 ;;
  esac
}
