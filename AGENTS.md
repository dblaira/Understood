# Understood Agent Instructions

Reference `WORKING_PATTERNS.md` when available. Start by deciding whether the request is Phase 1 ("help me judge this") or Phase 2 ("execute requirements").

## Native iOS Rule

Understood is a 100% native Apple-platform app.

The shipped iPhone app must be built in Xcode using Swift, SwiftUI/UIKit, and Apple native frameworks. Do not implement the iOS product as a web app, PWA, WebView shell, React Native app, Capacitor app, Expo app, TypeScript frontend, or browser-hosted experience.

Supabase and related backend services may remain backend, auth, storage, deployment, or admin infrastructure. They are not the iOS runtime.

The related web product (`understood-app-public`) is a separate codebase — do not conflate it with the native iOS app in this repo.

Device validation should prioritize real iPhone hardware. Avoid simulator-first thinking unless Adam explicitly requests it for a narrow diagnostic.

Acceptance criteria: if it is part of the shipped iPhone app experience, it should feel, behave, and integrate like a real App Store iOS app with direct access to Apple platform capabilities.

## Plan Overview Rule

Adam keeps `docs/understood-migration-map.html` on screen as the living status board. Suite-wide progress: `/Users/adamblair/Developer/GitHub/SAVY-iOS/docs/understood-suite-migration-map.html`.

When sharing multi-step plans or migration status: **overview first** — one sentence, horizontal progress track (all steps on one screen), "HERE" on current step, one-line next move. Details below or collapsed. Update the HTML when milestones change. See `.cursor/rules/plan-overview.mdc`.

## Execute, Don't Delegate

If the agent can run it (git, shell, `xcodebuild`, `gh`, `./scripts/agent-ios-check.sh`, deploys, file edits), **the agent runs it**. Do not return long manual steps or Xcode menu tutorials for work the agent can execute. Ask Adam only for human-only actions (unlock phone, passwords, design judgment) — one sentence, no checklist. See `.cursor/rules/execute-dont-delegate.mdc`.

## Product Rule

This app is being built for Adam first. Adam's taste, language, understanding, and natural reaction are the acceptance criteria. Do not optimize for a hypothetical average user before Adam has reacted.

If Adam does not understand the agent's explanation, naming, or proposed implementation, treat that as a product risk, not a communication footnote.

## Layout Rule

Mobile editorial layout follows `.cursor/rules/mobile-layout-philosophy.mdc`. Hero fills the viewport; measure against `docs/EDITORIAL_LAYOUT_STORIES.md` and `docs/scripts/measure_hero_cutoff.py` before calling a build matched.

## Build Gate

Before committing iOS changes, run `./scripts/agent-ios-check.sh`. See `docs/AGENT_IOS_BUILD.md` for simulator defaults, TestFlight scripts, and signing boundaries.

Do not change signing, certificates, provisioning, or App Store Connect settings from an agent run unless Adam explicitly asks.

## Technical Boundaries

- Swift and Apple frameworks are the app runtime.
- Xcode project: `Understood.xcodeproj`, scheme `Understood`.
- Supabase is allowed as backend/storage/auth.
- No WebKit/WebView in the app target unless Adam explicitly reverses this rule.
- No JavaScript or TypeScript application runtime in the iOS app.

## Current Lane

Update this line when the active milestone changes:

**Current lane:** TestFlight-valid capture shell (Reminders / Actions / Calendar); hero layout fidelity + low-friction capture — web stays composition authority, no mind maps or PDF on iOS. Do not App Store submit without Adam. Do not expand scope without Adam saying so.
