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
