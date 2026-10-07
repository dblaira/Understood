# Home navigation and FAB Themes

Adam approved the placement mockup on 2026-10-06 for the editorial Understood app, bundle `app.understood.Understood`.

## Delivered behavior

- Home replaces the cowboy hat and returns to the unfiltered Stories screen.
- The main menu and navigation router no longer expose CowboyAI.
- Theme is the first dropdown after the destination control in all three FAB forms: Reminder, Action, and Event.
- The 31-theme catalog is copied verbatim from the current SAVY and Re_Call catalog. Theme questions remain editable, and answers remain intact while switching themes within an open form.
- Theme identity and complete question/answer text save to the local cache and the existing `recall.reminders` Supabase table. Four nullable columns preserve compatibility with older entries.

## Verification

- Built and installed the Debug iPhone app using the existing signing configuration.
- Inspected the actual iPhone 17 Pro Max Home, Reminder, Action, and Event screens. All three forms show Theme, then Decide, then Delegate.
- The final `./scripts/agent-ios-check.sh` run passed all six UI tests: Reminder and Action capture across relaunch; Themes in every FAB form; theme switching and answer persistence across save/relaunch; Home navigation and hidden menu access; and rejection of the legacy Cowboy route.
- Xcode stalled collecting Simulator diagnostics after the tests finished. Only the stalled `simctl diagnose` collectors were stopped; the unchanged test results then finalized as `TEST SUCCEEDED`, and the build gate exited 0.
- Eight model checks passed against the real `ReminderModels.swift` and `PostTheme.swift`, covering old-cache decoding, blank-form autosave behavior, draft preservation, full-text serialization, approved Mental Model wording, and unique theme IDs.
- Supabase migration readback confirmed the four nullable theme columns. A transaction inserted and read multiline Unicode theme text successfully, then rolled back. A follow-up query found zero verification rows remaining.
- Both reference `PostTheme.swift` files compare byte-for-byte equal to Understood's catalog.

## Device-testing boundary

Apple's physical-device XCTest runner failed to initialize with `com.apple.sharing.authentication error 12`. The actual phone screens were inspected using DEBUG launch controls and the iPhone Mirroring view. Automated interactions and save/relaunch tests ran in Simulator; the database transaction checked storage separately. No live signed-in iPhone save was claimed as automated proof.

The DEBUG-only `-uitestComposer reminder|action|event` launch control opens the real form without bypassing authentication or resetting the phone's cache. Simulator auth-bypass tests are explicitly prevented from syncing synthetic entries to Supabase.

Existing local-only styling in `MainTabView.swift`, `UnderstoodApp.swift`, and other previously excluded files is retained. The commit includes only this task's changes to those files.
