# Repository guidance

Start with [`docs/index.md`](docs/index.md). It defines which documentation layer owns vision, observable behavior, exact contracts, architecture, panel language, workflows, and testing evidence.

Before proposing behavior, read [`docs/vision/vision.md`](docs/vision/vision.md) and [`docs/vision/principles.md`](docs/vision/principles.md). Do not describe direction as shipped behavior or weaken safety, consent, preservation, credential, or compatibility guarantees to fit an implementation discrepancy.

Use OpenSpec for behavioral changes:

- inspect active changes and main specs under `openspec/`;
- express observable deltas in specs and implementation reasoning in design;
- reconcile affected contracts, workflows, panel semantics, and tests in the same change; and
- require implementation plus automated evidence for current-behavior claims, or record why validation is real-machine/fresh-VM only.

The CLI in `bin/ress` is authoritative for machine inspection, validation, mutation, persistent state, and consumer output. `Panel.qml`, `Service.qml`, and `Model.js` remain consumers and presentation; do not create a second vault or machine-state interpretation in QML.

Run focused cases while working:

```bash
./tests/run.sh <case-name-fragment>
```

Before completing a change, run:

```bash
./tests/run.sh
openspec validate --all --strict
```

Use [`docs/testing/strategy.md`](docs/testing/strategy.md) to identify evidence the sandbox cannot provide and [`docs/testing/fresh-machine-validation.md`](docs/testing/fresh-machine-validation.md) for the clean-Omarchy checks.
