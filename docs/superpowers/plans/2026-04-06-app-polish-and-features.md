# Detriment App Polish & Missing Features

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix bugs, add device trust/labeling, scan history, settings, share, widget deep link, onboarding permissions, and UI polish (pull-to-refresh, empty state).

**Architecture:** All changes are iOS-side. Device trust uses DeviceStorage (UserDefaults via app group). Scan history stores timestamped snapshots in the same storage. Settings is a new SwiftUI view. Share uses ShareLink. Widget deep links via URL scheme. No backend changes needed — backend is solid and matches client contract.

**Tech Stack:** SwiftUI, iOS 17+, WidgetKit, CoreLocation, NetworkExtension

---

## File Map

| File | Action | Responsibility |
|------|--------|---------------|
| `Detriment/Views/DeviceDetailView.swift` | Modify | Fix tips bug, add trust toggle |
| `Detriment/Views/MainView.swift` | Modify | Pull-to-refresh, empty state, filter trusted, share button, settings nav, history nav |
| `Detriment/Views/OnboardingView.swift` | Modify | Add permission request pages |
| `Detriment/Views/SettingsView.swift` | Create | Settings screen |
| `Detriment/Views/ScanHistoryView.swift` | Create | Past scan list |
| `Detriment/Views/ShareReportView.swift` | Create | Shareable scan summary renderer |
| `Detriment/Services/DeviceStorage.swift` | Modify | Trust API, scan history storage |
| `Detriment/Services/NetworkScanner.swift` | Modify | Save scan history after each scan |
| `Detriment/App/DetrimentApp.swift` | Modify | URL scheme handling for widget deep link |
| `DetrimentWidget/DetrimentWidget.swift` | Modify | Add widget URL for deep link |
| `Detriment/Info.plist` | Modify | Register URL scheme |

---

### Task 1: Fix tips bug in DeviceDetailView

**Files:**
- Modify: `Detriment/Views/DeviceDetailView.swift:17-29`

- [ ] **Step 1: Add tips section call**

In the `body` ScrollView VStack, after the vuln section and before the risk/all-clear sections, add the tips display:

```swift
if let intel = intel, !intel.tips.isEmpty {
    tipsSection(intel.tips)
}
```

- [ ] **Step 2: Verify build**

---

### Task 2: Pull-to-refresh + empty state on MainView

**Files:**
- Modify: `Detriment/Views/MainView.swift`

- [ ] **Step 1: Add .refreshable to device list**

On the `List` in `deviceList`, add:
```swift
.refreshable {
    scanner.startScan()
}
```

- [ ] **Step 2: Add empty state view after scan completes with 0 devices**

After the `if !scanner.devices.isEmpty` block, add an else-if for scan complete + no devices:
```swift
} else if !scanner.isScanning && scanner.detrimentScore != nil {
    // Scan finished but found nothing
    emptyStateView
}
```

Create the `emptyStateView` computed property — centered message with icon, "No devices found" text, and a rescan button.

- [ ] **Step 3: Verify build**

---

### Task 3: Device trust system in DeviceStorage

**Files:**
- Modify: `Detriment/Services/DeviceStorage.swift`

- [ ] **Step 1: Add trusted devices storage**

Add a `trustedDevicesKey` and methods:
- `var trustedDeviceMACs: Set<String>` 
- `func trustDevice(_ mac: String)`
- `func untrustDevice(_ mac: String)`
- `func isDeviceTrusted(mac: String) -> Bool`

Same pattern as `knownDevices` but separate key `"trustedDevices"`.

- [ ] **Step 2: Add device custom names storage**

Add methods:
- `func setDeviceName(_ mac: String, name: String)`
- `func getDeviceName(_ mac: String) -> String?`
- `func removeDeviceName(_ mac: String)`

Store as `[String: String]` dictionary in UserDefaults key `"deviceNames"`.

- [ ] **Step 3: Verify build**

---

### Task 4: Trust toggle + custom name in DeviceDetailView

**Files:**
- Modify: `Detriment/Views/DeviceDetailView.swift`

- [ ] **Step 1: Add trust toggle button and name editor**

Add a section at the top of the ScrollView (after deviceHeader) with:
- A "Trust this device" / "Trusted" toggle button that calls DeviceStorage trust/untrust
- A text field to set a custom name for the device
- Both read/write from DeviceStorage using the device's MAC address

- [ ] **Step 2: Verify build**

---

### Task 5: Scan history storage + view

**Files:**
- Modify: `Detriment/Services/DeviceStorage.swift`
- Modify: `Detriment/Services/NetworkScanner.swift`
- Create: `Detriment/Views/ScanHistoryView.swift`

- [ ] **Step 1: Add scan history to DeviceStorage**

Add a `ScanSnapshot` struct (Codable): date, score, grade, deviceCount, newDeviceCount.
Add methods:
- `func saveScanSnapshot(_ snapshot: ScanSnapshot)` — appends to array, keeps last 30
- `func loadScanHistory() -> [ScanSnapshot]`
- `func clearHistory()`

Store as JSON data in UserDefaults key `"scanHistory"`.

- [ ] **Step 2: Save snapshot after each scan in NetworkScanner**

In `calculateDetrimentScore()`, after existing logic, call:
```swift
DeviceStorage.shared.saveScanSnapshot(ScanSnapshot(
    date: Date(),
    score: total,
    grade: detrimentScore!.grade,
    deviceCount: devices.count,
    newDeviceCount: newDeviceCount
))
```

- [ ] **Step 3: Create ScanHistoryView**

A list of past scans showing date, score gauge, device count, and new device count. Same dark theme + monospaced design. Each row shows: date/time, letter grade with color, "X devices, Y new".

- [ ] **Step 4: Verify build**

---

### Task 6: Settings screen

**Files:**
- Create: `Detriment/Views/SettingsView.swift`

- [ ] **Step 1: Create SettingsView**

Sections:
- **Devices**: "Reset known devices" button (clears DeviceStorage known list), "Reset trusted devices" button, "Clear custom names" button — each with confirmation alert
- **Notifications**: Toggle for new device alerts (reads/writes `@AppStorage("notificationsEnabled")`)
- **Data**: "Clear scan history" button with confirmation
- **About**: App version, "Detriment v1.0.0", link text for support

Same dark theme, monospaced design language.

- [ ] **Step 2: Verify build**

---

### Task 7: Share scan report

**Files:**
- Create: `Detriment/Views/ShareReportView.swift`
- Modify: `Detriment/Views/MainView.swift`

- [ ] **Step 1: Create ShareReportView**

A SwiftUI view that renders a shareable card: score, grade, device count, top risks. Use `ImageRenderer` to produce a `UIImage` from it.

- [ ] **Step 2: Add share function to MainView**

Create a `generateShareReport() -> String` method that produces a text summary:
```
DETRIMENT SCORE: B (35/100)
12 devices on WiFi
2 need attention
WiFi: MyNetwork (WPA2)
Scanned: Apr 6, 2026 7:30 PM
```

Add a share button (SF Symbol `square.and.arrow.up`) in the toolbar that presents a ShareLink with the text.

- [ ] **Step 3: Verify build**

---

### Task 8: Onboarding permission flow

**Files:**
- Modify: `Detriment/Views/OnboardingView.swift`

- [ ] **Step 1: Add permission request pages**

Add a 4th page before "Get Started" that requests:
- Location permission (for WiFi info) — explain why with friendly copy
- Notification permission — explain why

Each shows a button that triggers the actual permission request, with a "Maybe Later" skip option. The existing 3 content pages stay as-is.

- [ ] **Step 2: Remove permission requests from DetrimentApp.init and NetworkScanner**

Move notification request out of `DetrimentApp.init()`. Remove the location request from `NetworkScanner.loadWiFiInfo()` (it now happens during onboarding, but keep a fallback check in loadWiFiInfo in case they skipped).

- [ ] **Step 3: Verify build**

---

### Task 9: Widget deep link

**Files:**
- Modify: `Detriment/Info.plist`
- Modify: `Detriment/App/DetrimentApp.swift`
- Modify: `DetrimentWidget/DetrimentWidget.swift`

- [ ] **Step 1: Register URL scheme in Info.plist**

Add `CFBundleURLTypes` with scheme `detriment`.

- [ ] **Step 2: Add widgetURL to widget views**

Add `.widgetURL(URL(string: "detriment://scan"))` to both small and medium widget views.

- [ ] **Step 3: Handle URL in DetrimentApp**

Add `.onOpenURL { url in ... }` handler. If url is `detriment://scan`, trigger a scan. Pass scanner as environment object or use a shared trigger.

- [ ] **Step 4: Verify build**

---

### Task 10: Wire navigation in MainView (settings, history, share)

**Files:**
- Modify: `Detriment/Views/MainView.swift`

- [ ] **Step 1: Add toolbar buttons**

Add to the existing `.toolbar`:
- Leading: gear icon → NavigationLink to SettingsView
- Leading: clock icon → NavigationLink to ScanHistoryView  
- Trailing: share icon → share action (only when score exists)

- [ ] **Step 2: Show trusted badge on DeviceRow**

In DeviceRow, check `DeviceStorage.shared.isDeviceTrusted(mac:)` and show a small checkmark badge if trusted. Also use custom name from storage if set.

- [ ] **Step 3: Verify build**

---

### Task 11: Commit all changes

- [ ] **Step 1: Stage and commit**

```bash
git add -A
git commit -m "Add device trust, scan history, settings, share, widget deep link, onboarding permissions, and UI polish"
```
