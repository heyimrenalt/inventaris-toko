# Backlog

Open follow-ups that are not blocking today's work.

## PrimaryButton / SecondaryButton — add `isLoading` prop
Priority: medium
Context: Task 4 (keuntungan migration) refactored the rekap action bar to use PrimaryButton/SecondaryButton. Neither widget supports a busy/loading state, so the previous Share button spinner was removed. In-progress cue is currently label swap ('Membuat PDF...') plus disabled style. This works for the current ~1-3s PDF generation, but any future long-running action button will need proper spinner support.

Suggested API: `isLoading: bool = false`. When true, disable the button, replace icon with CircularProgressIndicator (sized to match icon, same color as label), keep label visible.

## Kotlin Gradle Plugin — outdated in 5 plugins
Priority: medium (external deadline)
Context: `flutter build apk --debug` warns that 5 plugins still use the old KGP: android_alarm_manager_plus, file_picker, package_info_plus, share_plus, workmanager_android. Future Flutter versions will fail to build if these aren't upgraded. Not blocking today, but tied to Flutter version cadence — plan an upgrade sweep before the next Flutter major.

## Batch MutationSnapshotBackfill
Priority: medium
Context: Current backfill (mutationPriceSnapshotBackfillDone flag) loads entire legacy mutation collection into memory via findAll() then writes in a single putAll() — no batching. On post-upgrade first launch with a large ledger (year+ of daily mutations), this risks slow init and OOM. Splash screen's "Menyiapkan data..." message handles the UX symptom; batching handles the cause. Batch size ~500 rows per transaction. Related: Task 6 (1000-data perf test) will confirm whether this is currently hitting real limits.

## values-night/styles.xml uses Theme.Black.NoTitleBar
Priority: low
Context: App is light-only (AppTheme.light), but values-night still inherits Theme.Black.NoTitleBar. On devices in dark mode, this causes a brief black flash during native splash before Flutter takes over. Cosmetic only.

## Splash screen — minor visual polish
Priority: low
Context: User flagged unspecified small mismatches after Task 1/2 completion but deferred details. Ask user to enumerate before scheduling.
