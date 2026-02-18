# SmartSyncReminder

SmartSyncReminder is a small SwiftUI reminder app with iOS + watchOS targets that sync reminders using WatchConnectivity. The project includes local notifications and complication support on the Watch.

## Features
- Create, update and delete reminders on iPhone
- Automatic sync to paired Apple Watch using WatchConnectivity (applicationContext / sendMessage / transferUserInfo)
- Watch requests an on-demand sync when reachable
- Complication timeline reload and local notifications on the Watch

## Requirements
- Xcode 26 or newer
- macOS 15 or newer
- iOS / watchOS simulator runtimes installed matching your deployment targets

## Quick start
1. Open the workspace in Xcode:

   ```bash
   open SmartSyncReminder.xcodeproj
   ```

2. Select the iPhone scheme and a paired Watch scheme. If you use simulators you can pair them with simctl (example below).
3. Build & run the iOS app (Command-R) and then the Watch app.

## Pairing simulators (CLI)
List devices and find desired phone/watch UDIDs:

```bash
xcrun simctl list devices --json
```

Boot simulators and pair (replace <watch-udid> and <phone-udid>):

```bash
xcrun simctl boot <phone-udid>
xcrun simctl boot <watch-udid>
xcrun simctl pair <watch-udid> <phone-udid>
```

Confirm pairing:

```bash
xcrun simctl list pairs --json
```

Install and run the apps from Xcode to the paired simulators.

## Cleaning / rebuilding (CLI)
Remove DerivedData for this project and clean build products:

```bash
rm -rf ~/Library/Developer/Xcode/DerivedData/SmartSyncReminder-*
xcodebuild -project SmartSyncReminder.xcodeproj -scheme "SmartSyncReminder" clean
```

One-line clean + build (example destination, replace as needed):

```bash
rm -rf ~/Library/Developer/Xcode/DerivedData/SmartSyncReminder-* && xcodebuild -project SmartSyncReminder.xcodeproj -scheme "SmartSyncReminder" -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

## Testing sync
1. Run the iOS app and create a reminder.
2. Watch the console logs for iOS and Watch targets (`print` statements added for WCSession). Look for lines like `[WC][iOS] sync called` and `[WC][Watch] received`.
3. If data doesn’t appear on the Watch, reboot simulators and confirm both apps are installed.

## Commit & push to GitHub
Example commands (run from project root):

```bash
git status
git add -A
git commit -m "Add README and sync improvements"
# If you don't have a remote yet:
# git remote add origin git@github.com:<owner>/<repo>.git
# Push:
git push origin HEAD
```

Replace `<owner>/<repo>` and `origin`/branch names as appropriate.

## Notes
- Debug logging is present in development code. Remove or reduce logs before publishing.
- applicationContext is intended for small payloads; large payloads should use transferUserInfo or transferFile.

## License
Choose and add a license file if you plan to publish the repository.
