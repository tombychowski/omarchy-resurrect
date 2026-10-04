# Architectural decision records

Decision records preserve the reasoning behind choices that are difficult to reverse or easy to accidentally relitigate. This directory contains records only when the project has made such a decision; it is not a backlog or a substitute for OpenSpec changes.

## Write a record when

A decision record is useful when a change:

- establishes or changes a trust boundary;
- chooses an external format, protocol, or compatibility policy;
- changes which component owns authoritative state;
- introduces a dependency or operational mechanism with lasting cost;
- accepts a meaningful trade-off whose rejected alternative is likely to return; or
- deliberately constrains future implementation choices beyond one feature.

Examples include choosing a vault migration strategy, changing the CLI/panel authority boundary, or adopting a new CI/runtime dependency model.

## Do not write a record for

- routine implementation details visible from the code;
- temporary workarounds with an issue or task;
- user-visible behavior already captured by an OpenSpec requirement;
- exact format detail that belongs in a contract; or
- speculative choices not required by a current change.

## Relationship to OpenSpec

Use an OpenSpec change to propose observable behavior and implementation work. Add a decision record when that change also settles durable architectural reasoning worth preserving after the change is archived.

The decision record should link to the relevant OpenSpec change or archived change. The change should link back to the record from its design artifact. Archiving an OpenSpec change does not supersede a decision record; a later decision record does.

## Naming

Use a four-digit sequence and a short lowercase slug:

```text
0001-example-decision.md
```

Assign the next number when the decision is accepted. Do not reserve numbers with empty files.

## Minimum structure

```markdown
# NNNN: Decision title

- Status: proposed | accepted | superseded
- Date: YYYY-MM-DD
- OpenSpec change: <link>
- Supersedes: <link or none>

## Context

What forces a decision now? State constraints and evidence, not a chronology.

## Decision

What was chosen, including the boundary of the choice.

## Consequences

What becomes easier, harder, required, or intentionally unsupported.

## Alternatives considered

The credible alternatives and why they were not chosen.
```

Keep a record concise and factual. Update its status or add a superseding record instead of rewriting historical reasoning to match a later outcome.
