# Principles

## Users own libraries and state

Loadout libraries, configuration, and applied-state records are inspectable
local files. A remote is optional and credentials stay with Git transport.

## Use the least-powerful representation

Profiles name packages, pinned integrations, reconstructible web apps, and one
theme. They do not carry commands, arbitrary files, services, secrets, or
cleanup instructions. Unrepresentable resources are omitted and reported.

## Consent follows power

General confirmation does not authorize running AUR build instructions.
Declined work remains pending and machine-readable.

## Preserve before removing

Apply is additive. Removal follows validated native claims and current guards;
it never infers ownership from absence in a profile, removes shared resources,
or guesses at application data and dependency cleanup.

## Identity and provenance are exact

Library id, stable item id, source, exact commit, normalized profile digest,
and pinned plugin or theme commits remain distinct and queryable.

## Report the complete truth

Health reporting distinguishes valid empty state from unavailable evidence and
retains every simultaneous cause even when one summary has precedence. Status
does not contact a remote or mutate state.

## The CLI is authoritative

`bin/mntg` owns inspection, validation, mutation, persistent state, and
consumer output. QML presents versioned CLI results and never reinterprets Git,
profiles, registries, or the machine.

## Compatibility is narrow and explicit

Unsupported versions and hostile input are refused before mutation. Ress v1
loadout import reads a separate source, reports losses and self-plugin
decisions, and publishes through the native transaction boundary. A reverse or
broader conversion requires a new product decision.

## Stay intentionally narrow

Montage manages portable Omarchy setup choices. New authority must be
representable, previewable, consentful, verifiable, and owned without weakening
these constraints.
