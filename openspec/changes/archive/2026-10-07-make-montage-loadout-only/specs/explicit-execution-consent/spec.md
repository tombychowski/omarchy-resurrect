# Spec Delta

## REMOVED Requirements

### Requirement: AUR Builds Require Separate Consent

**Reason**: The requirement mixes restore and loadout behavior under a backup-era capability name.

**Migration**: The loadout apply and repair guarantee moves without weakening to `loadout-execution-consent`; restore behavior is removed.

### Requirement: Persistent Services Require Separate Consent

**Reason**: Captured systemd service replay exists only for machine restore, which is removed.

**Migration**: Montage loadouts have no service field and grant no persistent-service authority.

### Requirement: Declined Gated Work Remains Pending

**Reason**: Restore and service deferral are removed, while Loadout AUR deferral moves to the loadout-specific consent capability.

**Migration**: Pending AUR claims remain inspectable and repairable under `loadout-execution-consent`.

### Requirement: Autostart Capture Is Explicit

**Reason**: Autostart capture is a machine-backup category outside the constrained loadout format.

**Migration**: Montage does not capture or migrate autostart entries.
