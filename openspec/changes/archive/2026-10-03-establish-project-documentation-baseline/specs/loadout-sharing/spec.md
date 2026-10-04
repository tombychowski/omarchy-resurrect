# Spec Delta

## Purpose

Defines a constrained setup-sharing format that can install named software and integrations without carrying user files or executable payloads.

## ADDED Requirements

### Requirement: Loadout Contains Only Supported Setup Actions
The system SHALL limit a loadout to packages, pinned plugins, reconstructible web apps, and a theme selection.

#### Scenario: Share excludes home content
- **WHEN** a user exports a loadout from a vault
- **THEN** the loadout contains no dotfiles, secret bundle, arbitrary file content, or command field

#### Scenario: Unrepresentable launcher is omitted
- **WHEN** a captured web app requires launcher behavior the loadout format cannot represent
- **THEN** share omits it and reports the omission

### Requirement: Apply Is Previewed And Confirmed
The system SHALL show every action a loadout can take and obtain confirmation before a live apply.

#### Scenario: Apply preview is complete
- **WHEN** a valid loadout is selected
- **THEN** ress lists packages, plugins, web apps, and the theme it would apply
- **AND** states that dotfiles and arbitrary scripts are outside the operation

#### Scenario: Dry run does not install
- **WHEN** loadout apply is invoked with `--dry-run`
- **THEN** the same plan is displayed without installing or changing anything

### Requirement: Shared Code Is Pinned
The system SHALL install plugin or Git-theme code only at the commit recorded in the loadout unless the user explicitly permits unpinned entries.

#### Scenario: Pinned plugin is applied
- **WHEN** a loadout names a valid plugin remote and commit
- **THEN** ress fetches the repository and checks out that commit detached

#### Scenario: Unpinned entry is refused by default
- **WHEN** a loadout names a plugin or cloneable theme without a commit
- **THEN** ress skips it unless unpinned application was explicitly allowed

### Requirement: Short Links Are Resolved Locally
The system SHALL expand supported ress short links to their canonical repository URLs before making a network request.

#### Scenario: GitHub short link is applied
- **WHEN** the user provides a supported `ress.sh` GitHub link
- **THEN** ress derives the GitHub repository URL locally
- **AND** fetches the repository rather than requesting the shortener

