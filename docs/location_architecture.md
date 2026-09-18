# HeartPearl location-sharing architecture

Updated: 2026-09-18

## Scope and evidence quality

Zenly did not publish a complete client/server location algorithm. This design therefore separates:

- **Verified public behavior:** Zenly described continuous background location, battery-conscious operation, and OEM-specific troubleshooting. Public reporting also described gathering detection and a highly animated, custom map experience.
- **Platform requirements:** the implementation details required by current Apple, Android, Firebase, Flutter, and Mapbox documentation.
- **HeartPearl design decisions:** the adaptive sampling, security model, schema, caching, and UX chosen here. These are engineering inferences, not claims about Zenly's private implementation.

Reverse-engineered protocols and unofficial private APIs were deliberately excluded.

## Public research

### Zenly and comparable product behavior

- Zenly's archived help center says location sharing was designed to operate continuously while limiting battery usage, but it does not disclose the algorithm: [Does Zenly Consume A Lot of Battery?](https://zenlyapp.zendesk.com/hc/en-us/articles/5334111973137-Does-Zenly-Consume-A-Lot-of-Battery)
- Zenly documented that Xiaomi/OEM battery optimization, autostart, and background restrictions can stop timely updates: [Location Not Updating on Xiaomi Devices](https://zenlyapp.zendesk.com/hc/en-us/articles/360001708367-Location-Not-Updating-on-Xiaomi-Devices)
- Mapbox's former case study describes Zenly Footsteps as using real-time background tracking, vector maps, and data processing, without exposing the tracking algorithm: [Clear the fog with Zenly](https://medium.com/mapbox/clear-the-fog-with-zenly-fc7778b06c33)
- Contemporary reporting described gathering detection, group-aware battery optimization, and Zenly's custom animated map. These are secondary sources and are used only as UX inspiration: [TechCrunch 2017](https://techcrunch.com/2017/06/21/snap-copied-location-sharing-app-zenly-to-build-snap-map/), [TechCrunch 2022](https://techcrunch.com/2022/05/18/social-maps-app-zenly-rolls-out-its-own-maps/).
- Apple Find My and Google Location Sharing both use explicit, per-person sharing and make global stopping/hiding easy: [Apple Find My](https://support.apple.com/guide/iphone/share-your-location-iph01954dc44/27/ios/27), [Google Location Sharing](https://support.google.com/accounts/answer/9363497).

### Platform constraints that drive the architecture

- Apple recommends requesting authorization in context, preferring When In Use and requesting Always only when the feature truly needs it. Background delivery requires the Location Updates capability and explicit background updates: [authorization](https://developer.apple.com/documentation/corelocation/requesting-authorization-to-use-location-services), [background updates](https://developer.apple.com/documentation/corelocation/handling-location-updates-in-the-background), [`allowsBackgroundLocationUpdates`](https://developer.apple.com/documentation/corelocation/cllocationmanager/allowsbackgroundlocationupdates).
- Apple recommends reducing frequency, using `distanceFilter`, pausing when stationary, and using lower-energy monitoring where appropriate: [Accessing the device's location efficiently](https://developer.apple.com/documentation/xcode/accessing-the-device-s-location-efficiently).
- Android requires foreground permission before background permission. Persistent background location is a core-functionality use case and must have prominent disclosure. Android 14 location foreground services need the location service type and permission: [background location](https://developer.android.com/develop/sensors-and-location/location/background), [foreground-service types](https://developer.android.com/about/versions/14/changes/fgs-types-required).
- WorkManager is for deferrable persistent work, not continuous live tracking. Periodic execution has a 15-minute minimum and is inexact: [persistent work](https://developer.android.com/develop/background-work/background-tasks/persistent), [periodic work](https://developer.android.com/develop/background-work/background-tasks/persistent/getting-started/define-work).
- iOS background tasks are system-scheduled and must not be presented as exact timers: [`BGTaskScheduler`](https://developer.apple.com/documentation/backgroundtasks/bgtaskscheduler), [Flutter Workmanager iOS setup](https://docs.page/fluttercommunity/flutter_workmanager/quickstart).
- Firestore security rules are not filters. A query must be valid for every possible result, and rules have document-access call limits: [securely query data](https://firebase.google.com/docs/firestore/security/rules-query), [rules conditions and access-call limits](https://firebase.google.com/docs/firestore/security/rules-conditions).
- Mapbox Static Images API requests are billable requests and require attribution. Limits/pricing can change, so the implementation uses explicit caching rather than assuming a permanent free allowance: [Static Images API](https://docs.mapbox.com/api/maps/static-images/).

## Security and Firestore schema

Location is stored separately from public profiles so the existing broad `users` read rule cannot expose it:

```text
userLocations/{uid}
  ownerUid: string
  geo: GeoPoint
  updatedAt: server timestamp
  capturedAt: device timestamp
  accuracy: number (metres)
  speed: number (metres/second)
  batteryLevel: number (0..100, optional)
  isSharing: bool
  allowedViewers: list<string>
```

An empty `allowedViewers` list means all current friends may view the location. Otherwise the requester must be both a friend and a member of the list. Owners can always read and write their own document. Reads are denied if either account blocks the other. List queries are denied; clients subscribe directly to known friend document IDs. This avoids depending on rules as a result filter and keeps authorization per document.

The client never writes another user's location. Rules validate the owner ID, field types, bounds, immutable ownership, list size, and timestamps. Disabling sharing clears sensitive coordinates while retaining privacy settings.

## Runtime design

1. The user opens Location Privacy and receives a prominent explanation of continuous sharing and battery implications.
2. HeartPearl asks for foreground/When In Use permission first. Only after the user explicitly enables sharing does it request the background/Always upgrade supported by the platform.
3. `LocationService` owns permission handling, the Geolocator stream, filtering, throttled Firestore writes, and sharing settings. Widgets contain no Firestore business logic.
4. Accepted fixes must be newer than the previous fix, have valid coordinates and reasonable accuracy, and be at least 30 seconds after the last successful write. A 20 m distance filter reduces callbacks. Low battery or background state selects a less aggressive accuracy mode.
5. Android uses Geolocator's location foreground service with the persistent Vietnamese notification “Đang chia sẻ vị trí với bạn bè”. iOS allows the OS to pause updates automatically. iOS may suspend the process; timestamps and stale-state UI make that limitation explicit.
6. `friendLocationsProvider` obtains the existing filtered friend list and subscribes directly to each allowed `userLocations/{uid}` document. The map and foreground widget refresh use this provider/repository path. A headless WorkManager isolate cannot safely depend on a UI ProviderContainer, so it invokes the same `LocationService` repository methods.
7. The map interpolates received coordinate changes for approximately 1.2 seconds. It displays movement class, accuracy/staleness, and last update time; it never implies centimeter-level precision.
8. Widget refresh is best effort. It chooses the nearest visible friend, caches the last chosen coordinate and map image, and calls Mapbox only when at least 20 minutes have elapsed and the friend moved at least 75 m. The Mapbox token is supplied with `--dart-define=MAPBOX_ACCESS_TOKEN=...` and is not committed.

## Battery and reliability policy

- Foreground/normal battery: high accuracy, 20 m distance filter.
- Background or battery at/below 20%: medium accuracy, 50 m distance filter.
- Firestore write throttle: minimum 30 seconds, independent of distance callbacks.
- Stale UI thresholds: warning after 10 minutes; do not silently describe stale data as live.
- Accuracy worse than 200 m is ignored for publication.
- WorkManager/BGTask scheduling is opportunistic and never used for continuous tracking.
- OEM background restrictions can still prevent Android updates. The UI should expose a clear error/state instead of claiming the user is live.

## Privacy and abuse resistance

- Sharing defaults off and requires an explicit toggle.
- Ghost mode immediately writes `isSharing: false` and removes coordinate fields.
- Per-friend switches maintain `allowedViewers` without weakening friendship checks.
- Existing two-way block rules also deny location reads.
- The UI shows permission denied, service disabled, stale, and accuracy states.
- No location history collection is created; only the latest point is retained.
- Mapbox receives only the selected friend's map coordinate needed for the static image. The API token must be URL-restricted where Mapbox supports it and rotated if exposed.

## Operational configuration

- Native Google Maps SDK keys are supplied outside source control. Android reads `GOOGLE_MAPS_API_KEY` from `android/local.properties`; iOS reads `GOOGLE_MAPS_API_KEY` from an untracked Xcode configuration/user-defined setting.
- The Mapbox token is a build-time Dart define. A missing token disables only static-map downloading and leaves the existing photo widget intact.
- Firestore rules must be deployed before enabling location sharing in production.
- App Store/Play disclosures must accurately describe continuous background location. App Review notes should include a demo account and exact steps to enable sharing.

## Known limitations

- Public Zenly material is insufficient to reproduce its internal fusion or gathering algorithms.
- Geolocator's cross-platform stream does not expose every Core Location mode as a Dart API. This implementation relies on OS pausing/background delivery rather than claiming a native significant-change implementation that cannot be verified end-to-end.
- Background task timing is not guaranteed on either platform.
- The widget presents the nearest visible friend because HeartPearl currently has no pinned-friend data model.
