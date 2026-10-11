# Panel CLI integration

`Service.qml` invokes only the resolved `bin/mntg` path. Rich results are
parsed by strict `Model.js` adapters before becoming panel state.

| Panel need | CLI route | Parser |
|---|---|---|
| attention | `mntg status --json` | `parseStatus` |
| libraries | `mntg repository list --json` | `parseRepositoryList` |
| stable items | `mntg repository loadouts NAME --json` | `parseLoadoutCatalog` |
| explicit sync preview | `mntg repository sync NAME --json` | `parseSyncResult` |
| Share inventory | `mntg share catalog --repository NAME --loadout ID --json` | `parseShareCatalog` |
| tracked snapshots | `mntg loadout list --json --contents` | `parseLoadoutList` |
| live resource health | `mntg loadout check --json` | `parseLoadoutCheck` |
| Ress inspection | `mntg port ress inspect SOURCE --json` | `parseRessMigration` |

Malformed or wrong-version output is discarded. Inventory and health are merged
only when every stable applied id has a matching row.

Loadout health exits 0 (healthy) or 1 (valid unhealthy result). The service waits
for both collected output and completion before publishing; malformed output
and other exits remain unavailable in either event order. Ress decisions are
an object with `ressPlugin` and `montagePlugin` values, never an array.

Share passes resource ids and withdrawal fingerprints as an argument array;
it never assembles a shell string. Publication progress uses documented
porcelain records. Repository configuration, apply, synchronization actions,
lifecycle mutation, and Ress publication use `omarchy-launch-terminal` with an
argument array so review and consent remain visible.

The panel refresh timer requests local status while visible. It schedules no
product operation and performs no remote access; only the explicit sync or
source-resolution routes may use the network.
