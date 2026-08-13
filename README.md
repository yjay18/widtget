# widtget

`widtget` is a widget-first native macOS product for focused code-activity snapshots. Its small host app exists only to install the WidgetKit extension and manage shared appearance preferences—there is no dashboard, detailed statistics page, or app-style navigation.

## What is included

- Native `AppIntentConfiguration` with **Daily** and **Weekly** modes.
- Purpose-built small, medium, and large layouts.
- Large tabular addition/deletion totals, compact commit and repository metrics, proportional repository bars, and two-color activity visualizations.
- Loading, no-activity, API-error/retry, stale-data, and “+N more” visual states.
- A minimal macOS appearance window for showing or hiding repository breakdowns, activity visualization, and update status, plus repository density.
- Shared App Group preferences with immediate WidgetKit timeline reloads.
- Deterministic preview data for every layout, including the requested `+29,696` and `−43,332` daily headline values.
- Repository ranking by total lines changed, then commit count.

## Open and preview

1. Open `widtget.xcodeproj` in Xcode 15.4 or newer.
2. Select both the `widtget app` and `widtget` extension targets, then assign the same development team under Signing & Capabilities.
3. Confirm that `group.com.yjay18.widtget` is available to both targets as an App Group.
4. Run the `widtget app` target once so macOS registers the embedded widget.
5. Open `WidtgetPreviews.swift` to inspect all widget families and states in the canvas.
6. Add `widtget` from the macOS widget gallery. Edit an individual widget to select Daily or Weekly.

The app controls global appearance preferences. Daily/Weekly remains a native, per-widget setting so multiple instances can show different periods.

The project targets macOS 14 because it uses native App Intent widget configuration and interactive retry.

## Data boundary

`ActivityDataSource` in `Provider/ActivityProvider.swift` is the single integration seam for production data. It currently returns deterministic snapshots so the extension stays self-contained and never embeds a GitHub personal access token. Replace that implementation with an approved server-backed or shared-container data source when one is available.

GitHub does not provide unauthenticated aggregate line-addition/deletion totals, and embedding a token in a widget binary is unsafe. The widget therefore links to the public `yjay18` GitHub profile on tap but does not claim to be an official GitHub product.

## Packaging

The `widtget app` target embeds and signs `widtget.appex`. The host has no product dashboard: after the first launch, normal use happens entirely from the widget, and the app only needs to be reopened when changing appearance preferences.
