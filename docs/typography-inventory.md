# Inventaris tipografi

Dibuat untuk memutuskan skala teks sebelum penggantian call-site dikerjakan.
Ini dokumen keputusan, bukan rencana eksekusi — nomor 1–4 di bagian akhir
perlu dijawab dulu.

## Yang sudah konsisten

Hanya ada satu jenis huruf di seluruh aplikasi: **PlusJakartaSans**, dipasang
global lewat `ThemeData.fontFamily` (`lib/ui/theme/app_theme.dart:42`). Karena
`TextStyle` inline pada widget `Text` mewarisi family dari `DefaultTextStyle`,
tidak ada layar yang jatuh ke font sistem, termasuk yang memakai `TextStyle`
mentah. Tidak ada Roboto, tidak ada `google_fonts`.

Jadi masalahnya bukan font family — melainkan **skala ukuran dan berat**.

## Skala token saat ini

`lib/ui/theme/app_text_styles.dart`:

| Token | Ukuran | Berat |
|---|---|---|
| `caption` | 12 | w400 |
| `body` | 14 | w400 |
| `bodyMedium` | 14 | w600 |
| `subheading` | 16 | w700 |
| `stockNumber` | 17 | w800 |
| `heading` | 20 | w800 |
| `displayNumber` | 28 | w700 |
| `statNumber` | 32 | w800 |

## Ukuran yang dipakai di luar skala

Ukuran nyata di UI: 10, 10.5, 11, 12, 13, 14, 15, 16, 18, 28. Lima di antaranya
tidak punya token.

### 13px — 9 tempat, ini yang paling sering

Terbesar penyebab Pengaturan terasa beda dari Beranda, karena `settings_group`
dipakai di seluruh layar Pengaturan.

- `widgets/settings_group.dart:27` — judul grup (w500, hijau)
- `widgets/settings_group.dart:113` — deskripsi baris
- `widgets/settings_group.dart:118` — subtitle baris
- `widgets/section_header.dart:46`
- `widgets/report_period_filter.dart:155,166`
- `widgets/frequently_sold_chart.dart:106`
- `widgets/mutation_list_item.dart:116`
- `widgets/time_picker_sheet.dart:180`
- `widgets/date_range_filter.dart:421,430,450`
- `screens/mutasi/catat_stok_keluar_batch_screen.dart:336`

### 18px — 7 tempat, semuanya judul dialog

- `screens/pengaturan/pengaturan_screen.dart:1027,1128`
- `screens/produk/product_detail_screen.dart:206`
- `widgets/confirm_dialog.dart:17`
- `widgets/category_form_dialog.dart:100`
- `widgets/time_picker_sheet.dart:123`

### 11px — 4 tempat

- `widgets/status_badge.dart:36`
- `widgets/restock_qty_field.dart:357`
- `widgets/priority_product_card.dart:143` (`caption.copyWith(fontSize: 11)`)
- `widgets/frequently_sold_card.dart:93` (idem)

### 15px dan 10.5px — masing-masing 1, keduanya menyimpang sendirian

- `screens/pengaturan/faq_screen.dart:174` — pertanyaan FAQ, 15px
- `widgets/glass_bottom_nav.dart:214` — label nav bawah, 10.5px
- `widgets/product_list_item.dart:88` — `caption.copyWith(fontSize: 10)`

## Pola yang menandakan token hilang

Bukan penyimpangan acak — ada dua bentuk yang berulang cukup sering sehingga
lebih tepat jadi token baru daripada dibetulkan satu per satu:

**`caption` + w600/w700 — 12 tempat.** Muncul di seluruh layar keuntungan
(`rekap_keuntungan_screen.dart` 7×, `keuntungan_detail_screen.dart` 2×),
`stat_card.dart:52`, `frequently_sold_card.dart:83`,
`frequently_sold_list_item.dart:61`, `tentang_aplikasi_screen.dart:165`.
Ini praktis label 12px tebal yang belum punya nama.

**Teks dialog 16px + judul dialog 18px — 22 tempat, hampir semua di
`pengaturan_screen.dart`.** Tombol "Batal"/"Simpan"/"Tutup", isi dialog, dan
judul dialog, semuanya ditulis mentah. Satu file ini sendiri menyumbang 22 dari
total `TextStyle` mentah.

## Sebaran per area

| Area | `TextStyle` mentah | Pakai token |
|---|---|---|
| Pengaturan | 27 | 17 |
| Produk | 19 | 41 |
| Mutasi | 10 | 12 |
| Beranda | 5 | 18 |
| Widget bersama | ~45 | ~30 |

Pengaturan satu-satunya area yang lebih sering memakai style mentah daripada
token.

## Di luar cakupan

`lib/services/recap_pdf_builder.dart` (11 `TextStyle`, ukuran 9–18) memakai
`pw.TextStyle` dari paket `pdf`, bukan Flutter. Itu tipografi dokumen cetak
dengan batasan sendiri dan sebaiknya tidak diikutkan ke skala UI.

## Yang perlu diputuskan

1. **13px**: jadikan token resmi (mis. `label`, 13/w500) atau bulatkan ke 12
   (`caption`)? Ini keputusan paling berdampak — 9 tempat, dan menentukan
   apakah tampilan Pengaturan berubah atau tidak.
2. **18px dialog**: bikin token `dialogTitle` (18/w700) + `dialogBody` (16),
   atau pakai `subheading` (16) yang sudah ada untuk judul dialog?
3. **11px dan 10px**: jadikan satu token kecil (mis. `captionSmall`, 11) dan
   naikkan yang 10px, atau biarkan sebagai pengecualian badge/nav?
4. **`caption` tebal**: tambah token `captionMedium` (12/w600) untuk menutup
   12 pemakaian `copyWith`?

Dua penyimpangan tunggal — FAQ 15px dan nav bawah 10.5px — tidak perlu
keputusan; keduanya jelas menyimpang sendirian dan bisa langsung disamakan.
