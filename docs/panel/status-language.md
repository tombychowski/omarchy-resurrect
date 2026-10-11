# Panel status language

The bar and hero use the `mntg status --json` attention value.

| Attention | Display | User meaning |
|---|---|---|
| `operation-active` | **Loadout operation active** | a live lock owner is mutating loadout or library state |
| `operation-partial-or-failed` | **Operation needs review** | authoritative operation evidence is incomplete or failed |
| `unavailable-or-invalid` | **Loadout status unavailable** | one required evidence source cannot be validated |
| `repository-attention` | **Library needs attention** | a configured library is unavailable, invalid, remote-ahead, or divergent |
| `drifted` | **Loadout drift detected** | current resource evidence is incompatible |
| `repair-needed` | **Repair needed** | tracked resources are missing or ordinarily repairable |
| `update-available` | **Update available** | an explicit update preview established changed content |
| `healthy` | **Loadouts healthy** | every available claim is satisfied and no decision remains |

The summary follows that precedence, while the detail view keeps every cause
and affected item. Valid zero-library and zero-applied state is healthy.
Malformed present state is unavailable; the panel never substitutes an empty
list.

Library language is action-specific: **Check synchronization** is an explicit
network preview; **Review divergence in terminal** keeps history decisions
visible. **Inspect Ress loadout** is read-only; **Import Ress loadout in
terminal** still requires confirmation. Applied rows show direct resource
health and open update, repair, or remove in a terminal.
