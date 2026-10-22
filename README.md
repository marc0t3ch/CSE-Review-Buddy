# CSE Review Buddy — Phase 5 Android beta integration candidate

This package **contains source code, not a compiled APK**. It merges the Phase 1–4 Flutter prototype, adds content validation, a Flutter smoke test, a GitHub Actions debug build workflow, and a release/testing checklist.

## Android-only setup (using your phone)
1. Create a GitHub repository and upload **the contents of this ZIP** to its root. Preserve the hidden `.github` directory. GitHub mobile web's multi-file upload may be awkward; use desktop-site mode or a GitHub-compatible Git client if needed.
2. Open repository **Actions**; enable workflows if prompted. Choose **Android Beta Debug APK** and **Run workflow**.
3. Open the run and check `Validate sample learning content`, `Static analysis`, `Unit and widget tests`, and `Build Android debug APK`.
4. **Only if all steps succeed:** download the APK artifact, extract it, and install `app-debug.apk` on your Android phone. Only install an APK produced by your own repository.
5. If a step fails, copy the error log into ChatGPT for a targeted code fix. Do not assume a successful APK before CI completes.

## Functional scope
- Onboarding with user name, exam level, manually selected exam date, daily study window.
- Offline bundled sample lessons and quizzes with answer explanations.
- Locally stored practice scores and attempt history.
- Daily reminder configuration and best-effort Android scheduled notifications.
- Timed **sample** mock exam, rule-based weak-subject recommendations, practice-day streak.
- No login, server database connection, or cross-device sync. Supabase SQL is a design scaffold only.

## Known limitations / release blockers
- Flutter is not installed in the packaging environment; **no Android compilation or device test was performed here**.
- Full official CSC reviewer coverage, independently checked explanations, actual examination date feed, and official-length mock exams are NOT provided. The 18 questions are demonstration content only.
- The reminder scheduler refreshes the next 30 days on app launch/settings change; it does not guarantee indefinite background rescheduling without reopening. Android power settings may delay delivery. Local notifications are not alarm-clock alarms.
- Notifications require user permission. A timezone-detection failure falls back to UTC, so test timezone behaviour on the actual phone.
- Study timer stores an end timestamp but does not yet track completed hours in analytics.
- Android signing, privacy policy, account deletion flows (if accounts added), accessibility audit, security review, Play Store compliance, and iOS work are outside this beta.

## Device acceptance test
1. Fresh install → enter name, choose Professional, set future date → dashboard countdown correct.
2. Review library → open lessons; practice quiz → select answers → score saved → analytics updated.
3. Mock exam → timer runs, navigation works, auto-submission on timeout, result saved.
4. Planner → choose start time 5–10 minutes ahead, grant notification permission, save; confirm notification arrival. Test break/resume/end; repeat with screen locked and app backgrounded.
5. Disable reminders → ensure pending notifications are cleared. Change date to today and ensure future reminders stop.
6. Force-stop and reboot tests: document device-specific differences; do not assume delivery after force-stop.
7. Restart onboarding → verify saved attempt history remains and new exam level changes visible topics.
8. Test offline mode, phone timezone changes, notification denial, small screen, and system font scaling.

## Distribution
The CI produces a **debug** APK for private testing, not a production-ready signed release. Do not publish or distribute broadly until quality, content, privacy and signing work is complete.
