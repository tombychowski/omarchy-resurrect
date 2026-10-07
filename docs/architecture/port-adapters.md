# Port adapter architecture

Montage treats foreign artifacts as explicit interchange formats, not as
alternate native storage. `mntg port FORMAT ...` selects one allowlisted
adapter. The adapter may inspect and translate its format, but native loadout
and vault readers never gain foreign-schema branches.

The current public selector `ress` resolves to the stable format id `ress-v1`.
`ress-v1` is also accepted directly. Every machine-readable result records the
canonical id, never the shorthand.

## Dependency direction

```text
port/commands.sh --> port/adapter.sh --> adapter option/decision callbacks
                         |
                         +--> adapter format callbacks
                         +--> adapter translation callbacks

port/inspect.sh  --> report, destination, selection, history iteration
port/import.sh   --> native selection, locks, staging, validation, commits, publication
port/export.sh   --> exact native reads, staging, validation, publication
        |
        +--> port/common.sh
        +--> repository / loadout / vault native primitives
        +--> literal callbacks through port/adapter.sh
```

The dependency direction is policy, not just organization:

- `port/common.sh`, `port/inspect.sh`, `port/import.sh`, `port/export.sh`, and
  `port/commands.sh` contain no Ress, predecessor, filename, or foreign-schema
  knowledge.
- Adapter selection initializes immutable descriptor facts, including the
  canonical id and supported version. One literal `(format, callback)` matrix
  in `port/adapter.sh` dispatches every later call; user-controlled text is
  never interpolated into a function name.
- An adapter validates and translates foreign semantics. It does not call Git
  traversal, native repository selection or transaction, temporary staging,
  confirmation, publication, or consumer-output functions.
- Native readers do not call an adapter.
- Dispatch is a literal allowlist. User input never becomes a function name,
  source path, or sourced module name.
- Modules are still loaded by the literal list in `bin/mntg`; no directory glob
  discovers executable code.

## Shared lifecycle

The shared engine owns behavior that must not vary by format:

1. validate the bounded format id and build one `montage-port-report`;
2. prove source and destination are separate and the destination is absent or
   explicitly empty;
3. enumerate requested history and materialize each commit through the same
   contained, envelope-neutral Git-object reader used by native history,
   without archive extraction or checkout over the source;
4. match each waivable loss by its exact code and refuse non-waivable safety or
   authority loss;
5. select exact native loadouts or backups for export and initialize native
   repositories for import;
6. own locks, recovery, staging, validation order, commit creation,
   confirmation, and atomic publication; and
7. project the same decision as human, JSON, or porcelain output.

Recognizing a control file is not enough to authorize execution. Inspection
may classify a standalone manifest for diagnostics, but shared planning marks
it `incomplete-artifact`, supplies no mutations, and cannot import it. Missing
format decisions likewise remain one incompatible `montage-port-report` in
JSON mode rather than escaping into an unrelated prose error.

Native repository transactions remain authoritative when an import writes an
item inside an existing Montage repository. The shared directory publisher is
for a new standalone destination; it does not replace identity-scoped locks,
journals, or repository validation.

## Adapter responsibilities

Each adapter owns:

- one stable lowercase `format` id, including a version when versions are not
  safely interchangeable;
- accepted filenames, exact schema/version boundaries, field validation, and
  artifact detection;
- semantic inspection, format-specific warnings, loss codes, and self-product
  identity decisions;
- conversion callbacks between one validated foreign tree and one prepared
  native stage, or one exact native tree and one prepared foreign stage;
- validation of the staged foreign result;
- format-specific import/export option values and decision rules; and
- frozen fixtures plus current, future-version, hostile, lossy, history, and
  round-trip evidence.

An adapter does not own configuration roots, credentials, private keys, locks,
restore progress, cleanup authority, history enumeration/materialization,
native selection, repository setup, staging, commit creation, publication,
generic confirmation, or the port report envelope. It cannot declare those
losses waivable.

## Adding another format

For `other-v2`, add `lib/montage/port/adapters/other_v2/` with format and
translation modules. Implement only the applicable callbacks declared in the
literal matrix in `port/adapter.sh`: inspection facts, history-tree validation
and timestamp, pre-translation validation, decision preparation, loss codes,
translation, staged foreign validation, and format-only option handling.
Then:

1. add its literal modules to `MONTAGE_MODULES` and the reviewed dependency map;
2. add explicit `other-v2` descriptor selection and `(format, callback)` cases
   in `port/adapter.sh`;
3. define its version boundary and loss codes in an OpenSpec capability or
   delta without weakening the shared artifact-portability requirements;
4. add frozen fixtures and a framework-conformance case in addition to
   format-specific conversion tests;
5. document its commands and any manual-copy fallback; and
6. run the focused adapter cases, the full suite, and strict OpenSpec
   validation.

A new format does not implement inspection/report orchestration, destination
checks, dry-run, history iteration, Git materialization, compatible-subset
selection, mutation labels, common argument parsing, loss matching,
confirmation, native selection, locks, repository
setup, staging, native validation sequencing, commits, publication, or output.
If a new format appears to need one of those, extend the shared engine contract
through OpenSpec instead of hiding duplicated lifecycle policy in the adapter.
