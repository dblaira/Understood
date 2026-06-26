# Agent iOS Build Gate

Use this command before committing iOS changes:

```sh
./scripts/agent-ios-check.sh
```

What it proves:

1. `Understood` builds for the iOS Simulator.
2. The command exits non-zero if the build fails.
3. The project currently exposes no test target, so simulator build is the local gate.

Default simulator:

```text
platform=iOS Simulator,name=iPhone 17
```

Override when needed:

```sh
IOS_DESTINATION="platform=iOS Simulator,name=iPhone 17 Pro" ./scripts/agent-ios-check.sh
```

Do not change signing, certificates, provisioning, or App Store submission settings from an agent run unless Adam explicitly asks.

## Xcode Cloud

This repo includes `ci_scripts/ci_post_clone.sh` for Xcode Cloud. It verifies that `Understood.xcodeproj` and the shared `Understood` scheme are present before Xcode Cloud starts its build.

Apple-side workflow configuration still lives in Xcode/App Store Connect.

## TestFlight Readiness

Run:

```sh
./scripts/agent-testflight-readiness.sh
```

This checks the shared scheme, bundle id, signing team, and whether App Store Connect API environment variables are present for CLI upload/status work.

Current known boundary:

```text
DEVELOPMENT_TEAM = 7FKUS5M5QS
```

That appears to be the same Personal Team used by the suite's local iOS builds. Personal Team builds are useful for local/device development, but TestFlight requires the app to be under an Apple Developer Program/App Store Connect team.
