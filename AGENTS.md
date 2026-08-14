# widtget development guide

## Product boundary

- `widtget` is a native macOS WidgetKit product with a deliberately small host app.
- Keep the widget as the primary product. The host app only manages shared widget preferences and credentials/data refresh when live GitHub data is added.
- The misspelling `widtget` is the intentional product and target name. Do not rename it to `widget` or `GitPulse`.
- Preserve the dark, number-first visual hierarchy and native Daily/Weekly App Intent configuration.

## Xcode project

- Project: `widtget.xcodeproj`
- Host app scheme: `widtget app`
- Widget extension scheme: `widtget`
- Deployment target: macOS 14+
- App bundle ID: `com.yjay18.widtget`
- Widget bundle ID: `com.yjay18.widtget.widget`
- Shared App Group: `group.com.yjay18.widtget`

The two targets must use the same signing team and App Group. Do not replace or remove the developer team configured by the user unless explicitly requested.

## Build and run

Use the repository entrypoint:

```sh
./script/build_and_run.sh build
```

This performs an unsigned Debug build, suitable for compile validation in an agent sandbox.

To build with the user's Xcode signing configuration and launch the host app:

```sh
./script/build_and_run.sh run
```

The signed run is required for macOS to register the embedded widget extension correctly. Build artifacts stay under `.build/DerivedData` and must not be committed.

## Architecture

- `widtgetApp/`: minimal SwiftUI host and shared appearance controls.
- `widtget/`: WidgetKit extension, App Intent configuration, timeline provider, models, and size-specific views.
- `Shared/WidgetPreferences.swift`: App Group preferences shared by both targets.
- `widtget/Provider/ActivityProvider.swift`: current fixture data and the integration seam for live GitHub activity.

When adding live GitHub data, store credentials in Keychain from the host app, fetch there, write only display-ready snapshots into the App Group container, and reload WidgetKit timelines. Never place a token in source, plist files, UserDefaults, or widget timeline entries.

## Validation

- Run the smallest relevant check first; at minimum, run `./script/build_and_run.sh build` after Swift or project changes.
- Use Xcode previews to inspect all supported widget families when layout changes.
- Preserve user-authored signing/project changes and unrelated worktree changes.
- Do not add commit co-author trailers.
