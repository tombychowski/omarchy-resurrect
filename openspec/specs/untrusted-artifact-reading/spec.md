# untrusted-artifact-reading Specification

## Purpose

Defines how Montage reads control files from fetched Loadout libraries and profiles without allowing untrusted repository links to escape the selected artifact root.

## Requirements

### Requirement: Loadout Control Files Are Contained Regular Files

The system SHALL read a native loadout repository envelope, portable profile, configured registry document, applied registry document, or Ress loadout migration control only when the selected path is a regular non-symlink file contained beneath the validated repository, isolated fetched tree, migration source, or staging root expected for that artifact.

#### Scenario: Fetched profile is a symlink

- **WHEN** a cloned loadout repository provides the selected `profile.json` as a symbolic link
- **THEN** Montage refuses the profile before reading the link target
- **AND** performs no loadout mutation

#### Scenario: Repository envelope is a symlink

- **WHEN** a native library provides `montage.json` as a symbolic link
- **THEN** Montage refuses the repository before reading the link target

#### Scenario: Ress migration profile is a symlink

- **WHEN** a Ress loadout migration source provides its profile through a symbolic link
- **THEN** Montage refuses the source and leaves source and destination unchanged

#### Scenario: Registry is a symlink

- **WHEN** a configured or applied registry path is not the expected contained regular file
- **THEN** Montage refuses mutation rather than adopting the linked content as repository or cleanup authority

### Requirement: Loadout Directory Reading Does Not Escape The Artifact Root

The system SHALL inspect repository, fetched-source, and migration trees without following links that escape the validated root or using escaped content to select a mutation target.

#### Scenario: Repository item escapes its library

- **WHEN** a loadout item path or parent directory contains a link escaping the native repository
- **THEN** Montage refuses the item before share, apply, query, or update

#### Scenario: Fetched repository contains an escaping link

- **WHEN** an exact fetched commit contains a link escaping its isolated tree
- **THEN** Montage refuses the linked content before loadout planning or mutation

#### Scenario: Ress source contains an escaping link

- **WHEN** a Ress loadout migration source contains a directory link that escapes its artifact boundary
- **THEN** Montage refuses migration and does not publish the staged item
