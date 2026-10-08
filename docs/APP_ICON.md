# Opportunity313 app icon

The iPhone target uses `Opportunity313/AppIcon.icon`, copied from the supplied
`Opp313 Logo.icon` without altering its artwork or Icon Composer settings.
The target's existing `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon` picks up
this file from the synchronized app folder. No project-file edit was required.
The previous `Assets.xcassets/AppIcon.appiconset` contained no artwork and was
removed from the app; its original contents are backed up at
`/private/tmp/op313-empty-appicon-backup/Contents.json`.

Verification on October 7, 2026: unsigned generic-iPhone Release build passed.
The resulting app contains compiled AppIcon assets and declares `AppIcon` as
its primary icon in Info.plist. Its generated 120-pixel icon was visually
inspected. Signing, store submission and appearance on a physical phone remain
outside this build check. Android icon assets are unchanged.

The original supplied icon remains at its original Desktop location.
