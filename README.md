# In.Level

In.Level is a universal SwiftUI level, slope and angle-matching tool for iPhone and iPad.

- Public app name: `In.Level`
- Bundle identifier: `au.h-v.in.level`
- Xcode project: `InLevel.xcodeproj`
- Shared scheme: `InLevel`
- Deployment target: iOS/iPadOS 17.0
- Revision: `In.Level v26.11.24.04`

The app uses Core Motion only. It has no external packages, network calls, analytics or advertising.


Codemagic note: this revision reuses the existing team Apple Developer Portal/App Store Connect integration named `In.Sync`. The app is routed to the In.Level App Store Connect record by the signed bundle identifier `au.h-v.in.level`.

## Measurement

Calibrate stores a Level zero for the current face or edge. Reset in Level restores the phone’s default Level position for all orientations. Reference in Match captures a gravity measurement, and Reset in Match clears it. Saved offsets and captures survive relaunch. The app recognises the previous release’s saved calibration and Match settings on upgrade.

For a flat transfer, point the same end of the phone in the same direction on both surfaces. The scope compares both tilt axes. Flat error is the angular separation of the two gravity vectors. On an edge, the signed error measures rotation about the captured edge axis. Match shows the saved target as a dashed ring and the live reading as a filled bubble. MATCHED uses the existing 0.05° tolerance and the number shows the measured residual to three decimals.

Slope is 100 times the tangent of the displayed angle. In Match this is the slope corresponding to the angular error. Tap the instrument or the area around it to enter full screen. Tap again to bring back the controls.

## Build

Extract the ZIP at the repository root. Open InLevel.xcodeproj and select the shared InLevel scheme. The Apple Developer App ID description is In Level. Codemagic assigns the build number and runs the measurement and persistence checks before signing.

GitHub Actions checks pushes and pull requests to `main` by running the regression tests and building the iOS app with Xcode. For a signed IPA, open this project in Codemagic, select **Start new build**, choose branch `main` and workflow **In.Level** (`in-level`), then start the build.

## App Store screenshots

The GitHub workflow captures Level and Match in portrait on the iPhone 17 Pro Max (1320 × 2868) and the 13-inch iPad Pro (2064 × 2752). Download `In.Level-App-Store-Screenshots` from the workflow run and upload the JPEGs to the corresponding iPhone and iPad sections in App Store Connect.
