# Task 6 — 1000-data scale test (positive path)

Date: 2026-08-17
Device: Oppo CPH1911 (ColorOS), connected demo phone — **not** the production/store phone
Build: `flutter test integration_test/scale_performance_test.dart -d MR9T5L9LJ7GIGYQ8` (debug)
Dataset: 200 produk, 21 kategori (6 root + 15 nested), 1000 mutasi across 6 months

Result: **all 13 on-device tests passed.** Correctness holds at scale; the
bottlenecks found are all in rendering and in per-row query loops — never
in Isar itself, whose every individual query measured ≤ 43 ms.

> **Read the numbers as upper bounds.** This is a **debug** build with
> assertions on and no AOT optimisation. Release-build figures will be
> materially lower — typically 2–4× on widget-build-bound work. Nothing
> below should be treated as a release-mode SLA.

---

## 1. What the code does today

### 1.1 Isar schema

Opened in `lib/data/isar_service.dart`, six collections. Foreign keys are
plain `int` fields, not `IsarLink`.

| Collection | Notable fields | Indexes |
|---|---|---|
| `Product` | `currentStock`, `minStockThreshold`, `sellPrice`, `averageCostPrice` (weighted HPP), `unitsPerPack`/`unitsPerDus`, `isArchived`, `criticalStockAlertState` | `name`, `code`, `categoryId` |
| `StockMutation` | `productId`, `type`, `quantity` (canonical pcs), `stockAfter`, `sellPriceSnapshot`, `costPriceSnapshot`, `snapshotBackfilled` | `createdAt` |
| `Category` | `name`, `parentId` (self-reference; `null` = root) | `name`, `parentId` |
| `AppSettings` | notification enable flags, up to 3 alert slots, restock tuning | — |
| `CostPriceAdjustment` | manual HPP corrections | — |
| `RestockList` | kulakan shopping lists | — |

`IsarService.open()` takes **no directory or name parameter** — it is
hardcoded to `getApplicationDocumentsDirectory()`. This is why the scale
test opens its own instance directly rather than going through
`IsarService` (see §2).

The `currentStock`-only-via-`recordMutation` convention holds: `recordMutation`
is the sole writer, and it maintains stock, weighted-average HPP, both price
snapshots and the critical-alert state machine inside one write transaction.

### 1.2 Notification scheduling — two different mechanisms

| | Critical-stock alert | Daily summary |
|---|---|---|
| Mechanism | `AndroidAlarmManager.oneShotAt` | WorkManager periodic |
| Precision | **Exact** — `exact: true`, `allowWhileIdle: true`, `wakeup: true`, `rescheduleOnReboot: true` → `AlarmManagerCompat.setExactAndAllowWhileIdle` | **Inexact by design** (24h period, OS-scheduled) |
| Recurrence | One-shot; the callback re-arms itself for tomorrow | OS-maintained |
| Timing compensation | none needed | ±30 min window check + 15-min one-off retry when the OS fires outside it |
| Slots | up to 3/day, each with its own alarm id (200+n) and notification id (100+n) | 1 |

Both callbacks run in their own background isolate and reopen Isar
themselves. `SCHEDULE_EXACT_ALARM`, `RECEIVE_BOOT_COMPLETED`, `WAKE_LOCK`
and `POST_NOTIFICATIONS` are all declared in the manifest, and
`PengaturanScreen` checks `canScheduleExactAlarms()` before arming.

### 1.3 Profit report, clipboard, PDF

`StockMutationRepository.buildProfitReport(period)` is the **good path**:
one indexed `createdAtBetween` query (or no where-clause at all for
`allTime`), one batched `products.getAll()`, then the pure synchronous
`ProfitReportBuilder.build`. Prices resolve through `MutationPricing`
(snapshot first, product as fallback); a row that can resolve neither
contributes nothing rather than being counted as zero.

- **Rekap Keuntungan screen** uses this path.
- **Copy-to-clipboard** is a pure `StringBuffer` walk over the
  already-built report — no further queries.
- **PDF export** is `loadRecapPdfFonts()` (bundled Plus Jakarta Sans TTF)
  + `buildRecapPdf()` (pure function of the report), written to a temp
  file, then handed to the OS share sheet.

There is also a **second, slower path**: `calculateProfitByDate` /
`calculateTotalProfit` call `profitForMutation` per row, and each of those
does its own `_isar.products.get()`. See §3.2.

---

## 2. Seed script — how to run it

**Files added:**

- `test_support/scale_seed.dart` — pure-Dart plan generator, expected-profit
  cross-check, and the production-path guard. No Flutter/Isar imports.
- `test/support/scale_seed_test.dart` — 27 unit tests for the above.
- `integration_test/scale_performance_test.dart` — the on-device seed +
  measurement + accuracy run.

**Command:**

```
flutter test integration_test/scale_performance_test.dart -d MR9T5L9LJ7GIGYQ8
```

No manual step. The timing table prints to the console at the end of the run.

To vary the dataset, change the `buildScaleSeedPlan(...)` call in
`setUpAll` (`productCount`, `mutationCount`, `monthsBack`, `randomSeed`).
The generator is deterministic per `randomSeed`, so a surprising number can
be reproduced rather than chased.

### 2.1 Why it cannot touch production data

Three independent layers:

1. It **never calls `IsarService.open()`.** It calls `Isar.open()` directly
   with its own `directory:` (a fresh timestamped subdirectory of the
   *cache* directory) and its own `name:`.
2. **A hard guard runs before anything is opened.**
   `assertSafeSeedDirectory` resolves the real production path via
   `getApplicationDocumentsDirectory()` — the same call `IsarService` makes,
   not a guessed string — and throws `UnsafeSeedDirectoryError` if the seed
   target is that directory or sits inside it. Prefix comparison is
   segment-terminated, so a sibling like `app_flutter_seed` is correctly
   allowed while a child like `app_flutter/seed` is refused. Five unit
   tests cover this.
3. **The instance is deleted from disk** in `tearDownAll`
   (`isar.close(deleteFromDisk: true)` plus a directory delete).

Notifications are equally contained: `NotificationService.sender` is
swapped for a recording fake, so nothing reaches the device tray and no
alarm is ever scheduled.

### 2.2 One thing worth knowing about the seed

`recordMutation` always stamps `createdAt = DateTime.now()` and offers no
override. To get timestamps spread across six months, the seeder records
every mutation through the real repository in ascending planned-time order
(so stock arithmetic, HPP and snapshots are exactly what the app would
produce), then rewrites `createdAt` in a single write transaction
afterwards. Rewriting timestamps in the order they were applied cannot
reorder the ledger relative to the arithmetic that produced it.

---

## 3. Performance

All figures wall-clock, debug build, on the CPH1911.

| Operation | ms | Flag |
|---|---:|---|
| **Queries** | | |
| Profit report query + aggregation (all time, 1000 mutasi) | 42 | |
| Profit report query + aggregation (last 30 days) | 22 | |
| Profitable date-range resolution (all-time label) | 41 | |
| Produk: `getAll()` (200 products) | 21 | |
| Produk: `searchByName()` | 24 | |
| Mutasi: `getAllMutations()` (1000 rows) | 18 | |
| Mutasi: `getHistoryForProduct()` | 4 | |
| Critical-stock alert: query + body build | 43 | |
| **Report paths** | | |
| `calculateProfitByDate` (per-mutation lookup) | 945 | ⚠ |
| `calculateTotalProfit` (per-mutation lookup) | 642 | ⚠ |
| A) `getStockOutHistoryForProduct` ×200, `filter()` (unindexed) | 640 | ⚠ |
| B) same loop, `where()` on a new `productId` index | 686 | ⚠ |
| C) same data, one query + group-by in Dart | **7** | |
| `PrioritasKulakanCalculator.calculateAll` (pure CPU) | 33 | |
| Daily summary task: full background run | 661 | |
| **Screens** | | |
| Rekap Keuntungan: open → figures on screen | **5881** | 🔴 |
| Beranda screen: open → figures | 1980 | 🔴 |
| Prioritas Kulakan: open → list | 1869 | 🔴 |
| Keuntungan Detail: open → figures | 1485 | 🔴 |
| Produk screen: open → list | 1295 | 🔴 |
| Mutasi screen: open → list | 1557 | 🔴 |
| **Snapshot backfill (post-upgrade first launch)** | | |
| Backfill: FIRST run on 1000 legacy (null-snapshot) rows | **72** | |
| Backfill: guarded no-op (every later launch) | 3 | |
| Backfill: unguarded re-run (idempotency) | 3 | |
| Profit report on backfilled legacy data | 17 | |
| **Actions** | | |
| Copy-to-clipboard (full report) | 1030 | see §3.4 |
| PDF: load bundled font | 6 | |
| PDF: generate document (190 product rows) | **1555** | 🔴 |
| PDF: write bytes to temp file | 47 | |
| **Seeding (not user-facing)** | | |
| Create 21 categories | 295 | |
| Create 200 products | 3625 | |
| Record 1000 mutations | 10304 | |
| Backdate 1000 timestamps (one txn) | 358 | |

### 3.1 Isar itself is not the problem

Every raw query is **≤ 43 ms** at this data size, including the full
all-time profit report over 1000 mutations. `getAllMutations()` returning
1000 rows takes 18 ms. The `createdAt` index is doing its job — the bounded
30-day report (22 ms) is cheaper than the unbounded one (42 ms), as
designed.

**Conclusion: no database-layer bottleneck exists at 1000 mutations.**
Every flagged number below is rendering or per-row Dart work.

### 3.2 Confirmed N+1: `calculateProfitByDate` / `calculateTotalProfit`

945 ms and 642 ms respectively, against **42 ms** for `buildProfitReport`
over the same 1000 rows. That is a **~22× gap** for the same underlying
data.

Root cause, in `stock_mutation_repository.dart`: both methods loop over
mutations calling `profitForMutation`, and each call does its own
`_isar.products.get(mutation.productId)` — ~1000 sequential point reads
where `buildProfitReport` does exactly one batched `products.getAll()`.

This is the direct cause of the **Keuntungan Detail** screen's 1485 ms
(it calls `calculateProfitByDate` at `keuntungan_detail_screen.dart:83`),
and it also runs on the **Beranda** home screen
(`calculateTotalProfit`, `beranda_screen.dart:142`) — meaning the app's
landing screen pays ~640 ms of avoidable work at this data size.

Not fixed, per task scope. The fix is mechanical: batch the product lookup
the way `buildProfitReport` already does.

### 3.2b Confirmed N+1, worse ratio: the per-product history loop

**688 ms for 200 queries, against 11 ms for the same data in one query —
a 63× gap**, the largest found anywhere in this exercise.

The pattern (identical in `beranda_screen.dart:125` and
`NotificationService.executeDailySummaryTask`):

```dart
for (final product in products) {
  stockOutByProduct[product.id] =
      await _mutationRepository.getStockOutHistoryForProduct(product.id);
}
```

**Initial hypothesis — a missing index — was tested and proved wrong.**
See §3.2d: adding an index on `productId` changes nothing. The cost is
per-call overhead across 200 round-trips, not row scanning.

The test verifies the batched alternative produces a byte-identical
grouping (same mutation ids, same order, per product) before comparing
times, so this is a like-for-like number and not a faster path doing less
work.

There is an explicit comment above the loop asserting this is fine:

> *"A small store's product catalog is small enough that one query per
> product (rather than a single bulk query plus a manual group-by) stays
> cheap"*

At 200 products × 1000 mutations, **that assumption no longer holds.** It
was reasonable when written; the data has outgrown it. Worth updating the
comment alongside the fix, since it currently discourages exactly the
change that's needed.

Two consequences:

- **Beranda — the app's landing screen — takes 1980 ms to open.** Of that,
  688 ms is this loop and 616 ms is `calculateTotalProfit` (§3.2). **About
  1.3 of the 2 seconds is avoidable**, and both fixes are the same kind of
  change. Prioritas Kulakan (1869 ms) pays the same cost.
- **The daily summary background task takes 661 ms**, nearly all of it this
  loop. Less urgent — it runs in a background isolate where no user is
  waiting — but it is work done under Doze on a battery-constrained device,
  which is where OEM battery managers are most likely to notice and act
  (see §4.2c).

Note the calculation itself is *not* the problem:
`PrioritasKulakanCalculator.calculateAll` over all 200 products is **33 ms**
of pure CPU. This is entirely query overhead.

### 3.2d Indexing `productId` does **not** fix it — negative result

An index on `StockMutation.productId` was the recommended first fix in the
previous version of this report, on the theory that each loop iteration was
a full scan. **That was wrong, and the measurement says so unambiguously.**

The index was added, the queries converted from `filter()` to `where()` (in
Isar only a where-clause consults an index; `filter()` always scans), and
all three variants measured **in a single test run** — necessary because
this phone throttles enough between runs to move every figure by ~2×,
which is far larger than the effect being measured:

| Variant | ms |
|---|---:|
| **A** — 200× loop, `filter()` on `productId` (unindexed scan) | 640 |
| **B** — 200× loop, `where()` on the new `productId` index | 686 |
| **C** — one query + group-by in Dart, no loop | **7** |

**B is not faster than A** — marginally slower, within noise. The test
asserts A and B return identical results (same mutation ids, same order,
per product) so this is a like-for-like comparison.

**Why the index is irrelevant here:** scanning is not the bottleneck. A
full fetch of all 1000 mutations takes 21 ms, so 200 scans cannot account
for 640 ms. The cost is the **fixed per-call overhead of 200 sequential
async queries** — roughly 3.2 ms each in query setup, FFI crossing and
future scheduling — and an index does nothing about that. Variant C proves
it: identical data, one call, **7 ms**.

**The fix is batching, not indexing — and it is worth ~90×.**

Recommendation: **revert the index and the `where()` conversion.** They buy
nothing measurable, and an index is not free — it adds write amplification
on every mutation insert (the app's hottest write path) plus database size,
in exchange for no demonstrated read benefit. If they are reverted, note
that the `where()` calls must be reverted too: `where().productIdEqualTo()`
only compiles while the index exists.

Left in place pending that decision, so the change is easy to inspect or
drop:
- `lib/data/models/stock_mutation.dart` — `@Index()` on `productId`
- `lib/data/repositories/stock_mutation_repository.dart` — 4 queries on `where()`
- `lib/data/repositories/product_repository.dart` — 1 count on `where()`

Not measured: the one-time cost of building this index on an existing
install's ledger when the new schema first opens. Isar builds it at open
time; a 1000-row bulk write is ~50 ms, so it is very likely negligible —
but it is inference, not measurement, and it is moot if the index is
reverted.

### 3.2c Snapshot backfill: measured, and genuinely cheap

The earlier version of this report cleared `MutationSnapshotBackfill` by
inference. That reasoning had a real gap: the shared dataset is seeded
through `recordMutation`, which always captures price snapshots, so the
backfill found **zero** candidate rows and the "clear" verdict rested on an
untested path.

Now measured properly against a purpose-built legacy fixture — 1000 rows
with `sellPriceSnapshot == null`, written directly rather than through the
current write path (which can no longer produce such rows):

| | ms |
|---|---:|
| First run, 1000 legacy rows — **awaited before the first frame** in `main.dart:123` | **72** |
| Guarded no-op — what every launch after the first pays | 3 |
| Unguarded re-run — writes 0 rows | 3 |

**Verdict unchanged, now on evidence: not a bottleneck.** 72 ms is
imperceptible against the 1500 ms minimum splash duration, so the
post-upgrade first launch will not feel slower at this data size. The
`sellPriceSnapshotIsNull()` filter is unindexed and therefore a full scan,
but one scan of 1000 rows is cheap — unlike §3.2b, this loop does not run
200 times.

Correctness verified alongside the timing: after the run every row carries
a snapshot, every backfilled row is marked `snapshotBackfilled = true` (so
the approximation stays traceable), the persisted flag is set, a re-run
writes 0 rows, and profit — uncomputable beforehand, since those rows
resolve no cost price — becomes computable afterwards.

### 3.3 The real headline: Rekap Keuntungan renders 190 rows eagerly

5881 ms to open, against a 42 ms query. **99.3% of that time is widget
build and layout, not data access.**

Cause (`rekap_keuntungan_screen.dart:498`): the per-product breakdown is a
`ListView.separated` with `shrinkWrap: true` and
`NeverScrollableScrollPhysics` nested inside a `SingleChildScrollView`.
That combination defeats lazy building entirely — every one of the 190
product rows (each a `Column` of five `Text` widgets plus a `Divider`) is
built and laid out before the first frame appears.

For contrast, **Produk screen uses `SliverList.builder`** and is lazy — its
1295 ms is query + category load + first frame, and it does not scale with
list length the way Rekap does. **Mutasi screen** uses a plain
`ListView(children: [...])` over day-grouped children, so it is eager too,
which is consistent with its 1557 ms.

### 3.4 Two numbers that are **not** bottlenecks — read carefully

- ~~**Copy-to-clipboard, 1030 ms** — mostly SnackBar animation.~~
  **Corrected.** Re-measured without settling through the SnackBar (two
  frames only): **894 ms**, against ~1030–1140 ms with the animation
  included. So the animation was only ~150–250 ms and **the copy itself is
  genuinely ~890 ms** — building ~190 products' worth of text plus the
  `Clipboard.setData` platform-channel round trip. My earlier attribution
  was wrong. It is borderline rather than alarming, and it is a discrete
  user-initiated action with immediate feedback, so I would still rank it
  below items 1–3 in §5 — but it is real work, not an artefact.
- **"Scroll 20 flings", 16.2 s (Produk) and 17.3 s (Mutasi).** These were
  measured with `pumpAndSettle` after each fling, so they are dominated by
  waiting for the fling's own deceleration animation to finish (~810 ms per
  fling) — they measure animation duration, **not frame jank**. They are
  reported here for completeness but are **not evidence of scroll
  performance problems**, and I would not act on them. Measuring real
  scroll performance needs frame-timing capture
  (`WidgetsBinding.instance.addTimingsCallback` or
  `binding.watchPerformance`), which is a separate exercise.

### 3.5 PDF generation, 1555 ms

Real and user-facing, for a 190-row document. Font loading is free (6 ms)
and the file write is trivial (47 ms) — it is all `dart_pdf` layout of the
product table. This is a `pubspec` in-process cost, not a query cost;
moving it to an isolate via `compute()` would be the obvious remedy if it
matters. The existing UI already covers it: the Bagikan button disables and
swaps its label to "Membuat PDF..." during generation.

---

## 4. Notifications at scale

### 4.1 Accuracy — clean, no issues found

Verified against a set of expected critical products computed from the seed
plan **independently of the database the code under test reads**, so this
is a real cross-check rather than a tautology.

| Check | Result |
|---|---|
| Right products identified | ✅ The set of products with `currentStock <= minStockThreshold` matched the plan-derived expected set exactly |
| No missed low-stock produk | ✅ Set equality, not subset |
| No wrongly-included produk | ✅ Every product named in the body was verified genuinely critical |
| No duplicate notifications | ✅ Exactly **one** batched notification for the whole slot, never one per product |
| No false notifications | ✅ Correct notification id (`100 + slot`) and channel (`channel_stock_critical`) |
| Truncated body still truthful | ✅ Body names 3 products but states the true total ("N barang stok kritis") |
| Multi-slot independence | ✅ Slot 1 re-alerted on the same live set under its own id, without being suppressed by slot 0 and without colliding with it |

Timing of the alert's own work: **43 ms** for the full 200-product query
plus body construction. Data volume contributes nothing meaningful to the
alarm callback.

Worth noting the design is sound here: `executeCriticalStockAlertSlot`
queries **live stock** at fire time rather than relying on the
`criticalStockAlertState` queue, so each slot independently reports
whatever is actually critical right now.

### 4.2 Timing — root cause analysis

**The 1000-record volume is not the cause of any timing drift.** Measured,
not assumed: the alarm callback's entire workload is 43 ms at 200 products.
Even a 100× slower device would not produce user-visible drift from this.

Reading the scheduling code directly, here is what actually governs timing:

**a) The critical-stock alert already uses the most precise API Android
offers.** `exact: true` + `allowWhileIdle: true` maps to
`AlarmManagerCompat.setExactAndAllowWhileIdle`. There is no more precise
option available to a non-alarm-clock app. **This is not an app bug.**

**b) Residual imprecision is inherent OS behaviour, and small:**
- `setExactAndAllowWhileIdle` is rate-limited by Android to roughly one
  firing per 9 minutes per app while in Doze. With at most 3 slots per day,
  this can never bind. **Non-issue.**
- On Android 12+ the user can revoke `SCHEDULE_EXACT_ALARM` ("Alarms &
  reminders") after granting it, at which point exact alarms silently
  degrade to inexact and become Doze-deferrable. The app already handles
  this correctly: `canScheduleExactAlarms()` is checked and
  `PengaturanScreen` warns before arming.

**c) The one genuine app-logic fragility — force-stop breaks the daily
recurrence chain.** `AndroidAlarmManager.oneShotAt` is a *one-shot*. The
daily repeat is maintained by `criticalStockAlarmCallback` re-arming the
slot after each fire. If the app is force-stopped — by the user, or by an
aggressive OEM battery manager — Android clears all pending alarms **and**
the callback that would re-arm them never runs. The alerts then stop
entirely until the app is next opened, at which point `main.dart`'s
fire-and-forget `_rescheduleNotifications` restores them.

`rescheduleOnReboot: true` covers device restart. It does **not** cover
force-stop.

This matters more than usual here: the demo device is an **Oppo running
ColorOS**, among the most aggressive OEM battery managers, and the target
audience's phones are likely similar budget Android hardware. If the shop
owner reports "the alert didn't come today", **this is the most probable
cause** — not data volume, and not the scheduling API.

**Is it fixable?** Partly, and only by mitigation, not by a true fix:
- Guide the user to exempt the app from battery optimisation
  (`REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`) / add it to ColorOS's protected
  apps list. Highest-impact, but it is a user action, not code.
- Add a boot-completed receiver that re-arms proactively (partially covered
  already by `rescheduleOnReboot`).
- Nothing in code can survive a force-stop, by Android's design. This is a
  known, unavoidable Android constraint.

**d) The daily summary is inexact by design and correctly compensated.**
WorkManager cannot target a wall-clock time; the code handles this with a
±30-minute acceptance window plus a 15-minute one-off retry when the OS
fires outside it. A daily summary arriving up to 30 minutes off the
configured time is **expected behaviour, not a bug** — worth knowing before
anyone files it as one.

---

## 5. Follow-ups

Ranked. Nothing here was fixed in this task, per scope.

1. **Rekap Keuntungan renders all product rows eagerly — 5.9 s to open.**
   `rekap_keuntungan_screen.dart:498`: `shrinkWrap: true` +
   `NeverScrollableScrollPhysics` inside a `SingleChildScrollView` defeats
   lazy building. Converting the screen to a `CustomScrollView` with a
   `SliverList.builder` (the pattern Produk already uses successfully)
   should recover most of it. **Highest user-visible impact.**

2. **Beranda (landing screen) pays ~1.3 s of avoidable query overhead.**
   Two independent N+1s land on the same screen:
   - `getStockOutHistoryForProduct` ×200 → **688 ms vs 11 ms batched (63×)**,
     because `StockMutation.productId` is **unindexed**, making each call a
     full ledger scan (§3.2b). Same loop in `executeDailySummaryTask`.
   - `calculateTotalProfit` → 616 ms vs 42 ms batched (§3.2).

   **Fix = batching. Indexing was tried and does not work** (§3.2d): one
   query + in-memory group-by is **7 ms vs 640–686 ms**, ~90×, and the test
   already proves the grouping is equivalent. Also update the stale "one
   query per product stays cheap" comment above the loop. **Prioritas
   Kulakan (2169 ms) gets the same benefit for free.**

3. **PDF generation blocks the UI isolate for ~1.6 s** at 190 rows. Move
   `buildRecapPdf` to `compute()` if it grows further. Related: the
   existing backlog item for `PrimaryButton`/`SecondaryButton` `isLoading`
   would give this a proper spinner instead of the current label swap.

4. **Notification recurrence does not survive force-stop** (§4.2c). Not
   code-fixable; consider an in-app guide for battery-optimisation
   exemption, especially for ColorOS/MIUI devices.

5. **Mutasi screen builds its day-grouped list eagerly** (plain `ListView`
   with a built children list). 1557 ms to open at 1000 mutations. Lower
   priority than Rekap since the list is date-grouped and filtered, but it
   will degrade as the real ledger grows past a year.

6. **Real scroll performance was not measured.** The fling numbers in §3.4
   measure animation duration, not jank. If scroll smoothness is a concern,
   it needs frame-timing capture as a separate exercise.

7. **`IsarService.open()` has no test seam.** It is hardcoded to the
   production documents directory with no `directory`/`name` parameter,
   which is why this test opens Isar directly. Fine as-is; worth knowing if
   another on-device test ever needs the app's own open path.

### Explicitly NOT a bottleneck

- **`MutationSnapshotBackfill`.** Investigated as a suspect and **cleared
  on direct measurement** against a purpose-built legacy fixture (§3.2c):
  **72 ms** for the first run over 1000 null-snapshot rows, 3 ms for the
  guarded no-op every later launch. Imperceptible against the 1500 ms
  minimum splash. Correctness verified too (full coverage, provenance flag
  set, idempotent). **No action needed** — this one is properly closed.
- **Isar query performance generally.** Every query measured ≤ 43 ms.
- **Copy-to-clipboard** (§3.4) — the 1030 ms is SnackBar animation.
- **Notification accuracy** — no defects found at 200 products / 1000 mutations.

---

## 6. Verification

| Gate | Result |
|---|---|
| `flutter analyze` | ✅ No issues found |
| `flutter test` | ✅ 804 passing (777 pre-existing + 27 new) |
| `flutter build apk --debug` | ✅ Built `app-debug.apk` |
| On-device scale test | ✅ 13/13 passing on CPH1911 |

**Run-to-run variance is large — do not compare figures across runs.**
Across four full runs this phone throttled enough to move nearly every
number by up to 2× (Rekap: 5881 / 6142 / 12319 / 6895 ms; PDF: 1555 / 1845
/ 3285 / 1762 ms) with no code change explaining it. This is why the
index question (§3.2d) was settled by an A/B/C **inside a single run**
rather than by comparing before/after runs — the confound was larger than
the effect. Every conclusion here rests on ratios measured within one run.

**A test-harness defect was found and fixed along the way.** The Rekap
screen test used `pumpAndSettle`, but that screen shows a
`CircularProgressIndicator` while loading, which schedules frames
indefinitely, so `pumpAndSettle` degenerated into a busy-wait. Identical
code measured 6 s, 12 s and **550 s** across three runs, and failed
intermittently. Replaced with `_pumpUntilFound`, which pumps to a concrete
condition — now stable and the number means "time until figures are on
screen". Other screens still use `pumpAndSettle` and have been stable, but
they carry the same latent risk.

One run was aborted by the environment rather than by a test failure: the
device's Play Store ANR'd and fully removed the app package mid-run. Re-ran
cleanly; noted only so the flake isn't mistaken for a real defect later.

The `flutter build apk --debug` KGP warning (5 plugins on the old Kotlin
Gradle Plugin) is pre-existing and already tracked in `docs/backlog.md`.

No screenshots were taken and no screen-capture command was run.

---

## Follow-up: growth curves across four sizes

This report measures one dataset size (200 produk / 1000 mutasi) in depth. The
*shape* of each cost curve — linear vs superlinear — is measured separately in
**`docs/growth-curve-report.md`**, which runs 250 / 500 / 1000 / 2500 mutations
back to back in a single run.

Headline: **no operation is superlinear**; every one grows more slowly than the
data does over a 10× span. Two figures here are superseded there:

- The Rekap **5881 ms** above was measured before `_pumpUntilFound` replaced
  `pumpAndSettle` on that screen; the comparable warm figure at 1000 mutations is
  **~2575 ms**.
- The Beranda **1980 ms** above came from `pumpAndSettle` against a spinner and
  is not a usable baseline for the batching fix. Beranda at 1000 mutations now
  measures ~2082 ms, and its *curve* is the flattest of the five.
