# Growth-curve scaling report

How five user-facing operations scale as the ledger grows. Companion to
`docs/task6-scale-test-report.md`, which measured one size (200 produk / 1000
mutasi) in depth; this one measures **four sizes in a single run** to get the
*shape* of each curve.

- Test: `integration_test/growth_curve_test.dart`
- Device: **CPH1911 / MR9T5L9LJ7GIGYQ8** (the demo phone — confirmed target;
  production data never touched, see §Safety)
- Build: **debug** (upper bounds, not release figures)
- Date: 2026-08-17
- Seeding: reuses `test_support/scale_seed.dart` (`buildScaleSeedPlan`) and the
  `assertSafeSeedDirectory` production-path guard. No new seeding logic.

## Dataset sizes

Mutation-to-product ratio held at **5:1** throughout, matching the earlier
200/1000 shape, so a size step changes how much data there is without changing
its shape.

| | 250 | 500 | 1000 | 2500 |
|---|---:|---:|---:|---:|
| Mutations | 250 | 500 | 1000 | 2500 |
| Products | 50 | 100 | 200 | 500 |
| **Sold products** (profit-report rows) | **44** | **93** | **190** | **466** |

The last row is the covariate that actually drives Rekap and the PDF, and it
tracks the mutation count closely (2.11× / 2.04× / 2.45×), so "linear in
mutations" and "linear in sold products" are not distinguishable here.

## Methodology

Three things were necessary to get numbers that mean anything on this device.
All were learned the hard way — each one produced garbage before it was fixed.

1. **All sizes in one run, back to back.** This phone throttles enough to move
   identical code by ~2× between runs (`task6` §3.4). A curve assembled from
   separate runs measures thermal state, not scaling. Sizes run in *ascending*
   order, so the largest size is the most thermally disadvantaged — that biases
   2500 towards looking worse than it is, which is the safe direction for a
   superlinearity hunt.
2. **A discarded warm-up pass** (20 produk / 100 mutasi) through every operation
   before the real sizes. This is a debug build, so the first pass also pays JIT
   compilation of the screens, the PDF layout engine and the JSON codec. Without
   it the smallest size absorbed all of that and measured *slower* than the next
   size up — Rekap 4008 ms @250 vs 2117 ms @500, PDF 1277 vs 683 — which
   inverted the first ratio and hid the real shape.
3. **Concrete-condition waiting, never `pumpAndSettle`.** Both Rekap and Beranda
   show a `CircularProgressIndicator` while loading, which schedules a frame
   forever, so `pumpAndSettle` degenerates into a busy-wait. Rekap waits for
   `'Salin'` (its bottom action bar, built only when the report is loaded and
   non-empty); Beranda waits for the `beranda_summary_total_keuntungan` tile.
   Both mean "the figures are on screen".

### A bug in the measurement, worth recording

The first version left both screens mounted while measuring backup import.
`BerandaScreen` subscribes to `watchLazy()` on products, mutations **and**
appSettings and calls `_load()` on every change, so the import's six
collection-wipes and rewrites triggered a storm of concurrent `_load()` calls —
each one a per-mutation product-lookup loop. That inflated the import timing
with unrelated screen work, left queries in flight past the end of the test, and
**reliably segfaulted IsarCore** (`SIGSEGV` in `[anon:dart-code]`) when the
instance was closed underneath them. The screens are now unmounted before any
non-widget measurement. Worth knowing independently of this task: a mounted
Beranda turns any bulk write into an N-way reload storm.

## Results — ms by dataset size

Single run, warm, ascending. Debug build on a throttling device: **the ratios
are the deliverable, the absolutes are upper bounds.**

| Operation | 250 | 500 | 1000 | 2500 |
|---|---:|---:|---:|---:|
| **1. Rekap Keuntungan → figures on screen** | 1047 | 1582 | 2575 | **5038** |
| **2. Beranda → summary figures on screen** | 1430 | 1729 | 2082 | **3997** |
| **3. PDF: generate document** | 591 | 611 | 768 | **2108** |
| &nbsp;&nbsp;3a. PDF: load bundled font | 5 | 6 | 6 | 6 |
| &nbsp;&nbsp;3b. PDF size (KB) | 13 | 20 | 35 | 79 |
| **4. Backup EXPORT (serialise + write file)** | 117 | 111 | 245 | **367** |
| &nbsp;&nbsp;4b. **Backup file size (KB)** | **86** | **170** | **338** | **844** |
| **5. Backup IMPORT (snapshot + wipe + restore)** | 240 | 365 | 694 | **1299** |
| &nbsp;&nbsp;5a. Backup: read file from disk | 6 | 3 | 6 | 17 |
| &nbsp;&nbsp;5b. Backup: validate + parse JSON | 23 | 24 | 38 | 122 |
| SEEDING (not user-facing) | 3345 | 5511 | 14212 | 31223 |

Reproducibility across the three warm runs of this session, for the two headline
figures: Rekap @2500 = 4952 / 4904 / 5038 ms; Beranda @2500 = 4101 / 4153 / 3997
ms. Within-run curve shape is stable; that is why the shapes below are
trustworthy even though any single absolute is not.

## Consecutive-size ratios

The data itself grows **2× / 2× / 2.5×** across the three steps. That is the bar
linear scaling has to clear. Anything growing more than 1.35× faster than the
data is flagged (a genuine quadratic would show ~4× against a 2× step, so this
threshold has room for device noise without hiding a real problem).

| Operation | 250→500 | 500→1000 | 1000→2500 | vs data growth | Verdict |
|---|---:|---:|---:|---|---|
| 1. Rekap Keuntungan | 1.51× | 1.63× | 1.96× | **all below** | linear / acceptable |
| 2. Beranda | 1.21× | 1.20× | 1.92× | **all below** | linear / acceptable |
| 3. PDF generate | 1.03× | 1.26× | 2.74× | 1.10× on last step | linear / acceptable (watch) |
| 4. Backup EXPORT | 0.95× | 2.21× | 1.50× | below overall | linear / acceptable |
| 5. Backup IMPORT | 1.52× | 1.90× | 1.87× | **all below** | linear / acceptable |
| — Backup file size | 1.98× | 1.99× | 2.50× | exactly proportional | as expected |
| — SEEDING | 1.65× | 2.58× | 2.20× | ~proportional | n/a (not user-facing) |

**Nothing is superlinear.** Every operation grew *slower* than the data over the
full 10× span (250 → 2500):

| Operation | 250 → 2500 growth | Data grew | Ratio |
|---|---:|---:|---:|
| Rekap Keuntungan | 4.8× | 10× | 0.48 |
| Beranda | 2.8× | 10× | 0.28 |
| PDF generate | 3.6× | 10× | 0.36 |
| Backup EXPORT | 3.1× | 10× | 0.31 |
| Backup IMPORT | 5.4× | 10× | 0.54 |

The sub-proportional growth is fixed overhead amortising, not a sublinear
algorithm: each curve is a real linear cost plus a constant (screen build,
isolate spawn, font load). Fitting a line to the last two points gives the
per-item slope used for the projections below.

## Verdict and projected pain points

Fits are `ms ≈ intercept + slope × sold_products`, from the 1000 and 2500 points.
Debug build, so real release figures will be lower — the *shape* is the finding.

### 1. Rekap Keuntungan — linear / acceptable shape, bad constant

`≈ 880 ms + 8.9 ms per sold product`

- **Shape: linear, and comfortably sub-proportional.** It is not going to
  explode. The earlier report's 5881 ms @1000 was measured with `pumpAndSettle`
  against a spinner and is not comparable to the 2575 ms measured here.
- **But the absolute is already the worst of the five**, and 99% of it is widget
  build, not query (`task6` §3.4 — the query itself is ~42 ms).
- Projected: **~5.3 s at 500 sold products, ~9.8 s at 1000 sold products** (debug).
- **Not a scaling emergency; it is a constant-factor problem** already on record.
  A shop reaching 500 sold products hits ~5 s. Fix is virtualising the product
  list, not changing the algorithm. Separate task.

### 2. Beranda — linear / acceptable, batching fix confirmed in shape

`≈ 760 ms + 6.9 ms per sold product`

- **Shape: the flattest curve of the five** (1.21× / 1.20× / 1.92× against 2× /
  2× / 2.5× data). The batched `getStockOutHistoryForProducts` path is doing its
  job — the old per-product N-query loop would have shown proportional growth.
- **Caveat on "not the old ~2 s":** at 1000 mutations this measures **2082 ms**,
  essentially the same as the old 1980 ms. That is *not* evidence the fix did
  nothing — the old number came from `pumpAndSettle` on a spinner and is
  methodologically junk. What is now established is the shape, which is good.
  The remaining ~2 s at 1000 is dominated by first-frame widget build, same as
  Rekap.
- Projected: ~4.2 s at 500 sold products, ~7.7 s at 1000.
- **Verdict: linear / acceptable.** Shares Rekap's constant-factor problem.

### 3. PDF export — linear / acceptable, closest to the line

`≈ 845 ms + 4.9 ms per sold product`

- Last step (2.74× against 2.5× data, i.e. 1.10× of data growth) is the least
  comfortable margin of the five, but it is inside device noise and the first two
  steps are flat (1.03×, 1.26×). `dart_pdf` laying out one table row per sold
  product is inherently linear.
- Font load is free and constant (5–6 ms at every size). File size grows
  proportionally (13 → 79 KB).
- Projected: ~3.3 s at 500 sold products, ~5.7 s at 1000.
- **Verdict: linear / acceptable.** Worth re-measuring if the document ever gains
  per-row work; a user waiting on an explicit "Bagikan" tap tolerates seconds far
  better than a screen open does.

### 4. Backup EXPORT — linear / acceptable, cheap

`≈ 0.1 ms per mutation`

- **The cheapest operation measured**: 367 ms for 2500 mutations, and it grew only
  3.1× for 10× the data. The `compute()` isolate for JSON stringification is
  most of the fixed cost.
- **File size is exactly proportional** — 86 → 170 → 338 → 844 KB, i.e. ~0.34 KB
  per mutation. Projected: ~1.7 MB at 5000 mutations, ~3.4 MB at 10 000. No
  concern; note these datasets carry **no photos**, which in a real backup will
  dominate size (base64 of a few hundred KB per photo swamps 0.34 KB/row).
- **This is the first end-to-end exercise of backup at 1000 and 2500** — the
  integrity suite only ever ran it at 40/250. It works, at both sizes.
- **Verdict: linear / acceptable.** Nothing to do.

### 5. Backup IMPORT — linear / acceptable

`≈ 290 ms + 0.4 ms per mutation`

- 1299 ms at 2500 mutations, growing 5.4× for 10× the data. This includes the
  pre-import rollback snapshot, the wipe, and the full restore — three passes
  over everything — so a ~1.3 s worst case at 2500 is healthy.
- Read (17 ms) and parse (122 ms) are negligible.
- Projected: ~2.3 s at 5000 mutations.
- **Verdict: linear / acceptable.** Nothing to do.

### Seeding feasibility (not user-facing)

2500 mutations seeded in **31 s** with no OOM and no failure — the 2500 point was
measured, not dropped. Cost is one write transaction per `recordMutation`
(~12 ms each), which no user ever performs in a batch. This is the same path the
`Batch MutationSnapshotBackfill` backlog item concerns, and it is *not* evidence
against it: bulk writes there use `putAll`.

## Flagged for separate tasks

Measurement only — nothing was fixed in this task.

1. **Rekap Keuntungan / Beranda first-frame cost.** Linear in shape, but ~5 s and
   ~4 s respectively at 500 products (debug). Both are ~99% widget build. This is
   the pre-existing "screens are slow" finding from `task6` §5, now with a curve
   attached: it will grow proportionally, so it gets worse steadily rather than
   suddenly. Fix = list virtualisation.
2. **Nothing else.** No operation showed superlinear growth, and the whole backup
   path is comfortably cheap at 2500.

## Safety

Every size opened a throwaway Isar instance in a fresh subdirectory of the
**cache** directory under its own database name, cleared by
`assertSafeSeedDirectory` against the real documents directory before anything
was opened, and deleted from disk afterwards. `IsarService.open()` — the only
path to real shop data — was never called. Notification statics were pointed at
no-op fakes for the whole run, so the restore path's cancel/reschedule never
touched the device's tray or alarm manager. No screencap, no production install.

Note that `flutter test integration_test/...` uninstalls and reinstalls the app
package on the target device, which clears any app data on that phone. That is
why this only ever runs on the demo device.
