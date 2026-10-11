# Panel principles

The panel is a small face on the authoritative CLI. It presents three surfaces:

- **Libraries** — configured loadout libraries, stable items, explicit synchronization, and Ress v1 migration;
- **Compose/Share** — a CLI-produced safe machine catalog and one explicit publication target;
- **Applied Loadouts** — tracked desired state, resource health, update/repair/remove actions, and AUR policy.

`Service.qml` requests versioned CLI results. `Model.js` accepts a complete
valid result or returns unavailable. QML never reads Git, profiles, registries,
launchers, package state, or operation files directly.

State-changing work that benefits from review or may need privilege continues
in an interactive terminal. The panel does not force a synchronization choice,
publish a migration without confirmation, or mutate source/destination content
itself.

The bar summarizes CLI attention, including active, partial, invalid, library,
drift, repair, update, and healthy states. It does not reinterpret time or
poll remotes to invent attention.
