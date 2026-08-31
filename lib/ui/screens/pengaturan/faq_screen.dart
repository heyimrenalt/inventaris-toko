import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/app_header.dart';

/// One accordion entry on the FAQ screen: a [question] that expands to
/// reveal its [answer], optionally followed by a bulleted list of
/// [bullets] (only the "apa saja yang bisa aplikasi ini lakukan" item
/// uses those today).
class FaqItem {
  const FaqItem({required this.question, required this.answer, this.bullets = const []});

  final String question;
  final String answer;
  final List<String> bullets;
}

/// The FAQ copy, kept as data so future edits are a list change rather
/// than a widget change.
const List<FaqItem> faqItems = [
  FaqItem(
    question: 'Kenapa stok tidak bisa diubah langsung?',
    answer: 'Setiap perubahan stok harus lewat Mutasi (stok masuk/keluar) supaya ada catatan '
        'riwayatnya — kapan, berapa, dan kenapa stok berubah.',
  ),
  FaqItem(
    question: 'Saya salah catat mutasi, bagaimana membetulkannya?',
    answer: 'Buka riwayat mutasinya lalu tekan Urungkan. Mutasi tidak dihapus, tapi dicatat '
        'pembatalannya sebagai entri "Dibatalkan: …" supaya riwayat tetap jujur.',
  ),
  FaqItem(
    question: 'Apa itu HPP dan margin? Kenapa HPP berubah sendiri?',
    answer: 'HPP adalah harga modal rata-rata per barang, dan margin adalah selisihnya dengan '
        'harga jual. HPP dihitung ulang otomatis setiap ada stok masuk: 10 pcs @2.000 lalu '
        'masuk 10 pcs @3.000 → HPP jadi 2.500, bukan 3.000.',
  ),
  FaqItem(
    question: 'Apa itu Prioritas Kulakan?',
    answer: 'Perkiraan barang mana yang perlu segera dikulak, berdasarkan sisa stok dan '
        'kecepatan lakunya. Daftar Kulakan berbeda — itu catatan belanjamu sendiri, dan '
        'mencentangnya tidak menambah stok sampai dicatat sebagai stok masuk.',
  ),
  FaqItem(
    question: 'Produk yang sudah tidak dijual lagi, dihapus?',
    answer: 'Diarsipkan, bukan dihapus, supaya riwayat dan rekap keuntungan lama tetap utuh. '
        'Produk arsip bisa dibuka dan dikembalikan kapan saja.',
  ),
  FaqItem(
    question: 'Bagaimana cara backup data toko?',
    answer: 'Pengaturan → Cadangkan Data → kirim ke WhatsApp atau Google Drive. Lakukan rutin '
        'supaya data aman kalau HP hilang.',
  ),
  FaqItem(
    question: 'Apakah data hilang kalau HP rusak atau hilang?',
    answer: 'Ya, kalau belum pernah backup keluar HP. Aplikasi memang mencadangkan otomatis '
        'tiap hari, tapi file itu tersimpan di HP ini dan ikut hilang bersamanya — hanya '
        'backup yang kamu kirim keluar yang benar-benar aman.',
  ),
  FaqItem(
    question: 'Bagaimana cara memindahkan data ke HP lain?',
    answer: 'Cadangkan di HP lama → pasang aplikasi di HP baru → Pulihkan Data. Ingat, '
        'Pulihkan Data mengganti seluruh data yang ada di HP tujuan dan tidak bisa dibatalkan.',
  ),
  FaqItem(
    question: 'Kenapa notifikasi stok kritis tidak muncul?',
    answer: 'Biasanya izin notifikasi mati atau aplikasi dibatasi penghemat baterai. Buka '
        'Pengaturan → "Notifikasi tidak muncul?" untuk langkah perbaikannya.',
  ),
  FaqItem(
    question: 'Apakah aplikasi ini butuh internet?',
    answer: 'Tidak. Semua data tersimpan di HP dan aplikasi jalan penuh tanpa internet — '
        'koneksi hanya dipakai saat mengirim file backup keluar.',
  ),
  FaqItem(
    question: 'Apa saja yang bisa aplikasi ini lakukan?',
    answer: 'Yang bisa dilakukan aplikasi ini:',
    bullets: [
      'Catat stok masuk dan keluar — setiap perubahan stok tercatat lengkap dengan tanggal dan riwayatnya.',
      'Batalkan mutasi yang salah — pembatalan ikut tercatat, jadi riwayat tetap utuh dan bisa ditelusuri.',
      'Satuan pcs, pack, atau dus — atur isi per pack dan per dus, app yang menghitung konversinya.',
      'Kelola produk dan kategori bertingkat — kategori bisa punya sub-kategori sesuai kebutuhan toko.',
      'Foto produk — ambil dari kamera atau galeri supaya barang mudah dikenali.',
      'Arsipkan produk lama — berhenti dijual tanpa menghapus riwayat dan rekap keuntungannya.',
      'Harga modal (HPP) dihitung otomatis — rata-rata tertimbang yang diperbarui setiap ada stok masuk, lengkap dengan margin per barang.',
      'Prioritas Kulakan — perkiraan barang mana yang perlu segera dibeli lagi, dari sisa stok dan kecepatan lakunya.',
      'Rekap keuntungan & barang sering keluar — lihat per periode, dan simpan rekapnya sebagai PDF.',
      'Notifikasi ringkasan harian, stok kritis, dan pengingat backup — bisa diatur sendiri di Pengaturan.',
      'Cadangkan otomatis tiap hari, plus cadangkan manual — kirim ke WhatsApp atau Google Drive, dan pulihkan kapan saja.',
    ],
  ),
];

/// Accordion list of the app's frequently asked questions. Several items
/// can be open at once — answers are short enough that forcing one open at
/// a time would only make comparing two answers harder.
class FaqScreen extends StatefulWidget {
  const FaqScreen({super.key});

  @override
  State<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends State<FaqScreen> {
  final Set<int> _expanded = <int>{};

  void _toggle(int index) {
    setState(() {
      if (!_expanded.remove(index)) _expanded.add(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppHeader.withBack(title: 'FAQ'),
      body: SingleChildScrollView(
        // The extra bottom inset keeps the last item — item 11 expanded is
        // taller than the viewport — clear of the system navigation bar.
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.xxl + MediaQuery.viewPaddingOf(context).bottom,
        ),
        child: Material(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < faqItems.length; i++) ...[
                _FaqTile(
                  key: Key('faq_item_$i'),
                  item: faqItems[i],
                  expanded: _expanded.contains(i),
                  onTap: () => _toggle(i),
                ),
                if (i != faqItems.length - 1)
                  const Divider(height: 0.5, thickness: 0.5, color: Color(0xFFE5E5E5)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  const _FaqTile({super.key, required this.item, required this.expanded, required this.onTap});

  final FaqItem item;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    item.question,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.sm),
                  child: Icon(
                    expanded ? Icons.expand_more : Icons.chevron_right,
                    size: 20,
                    color: AppColors.gray700,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (expanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.answer,
                  style: const TextStyle(fontSize: 14, height: 1.45, color: AppColors.darkText),
                ),
                for (final bullet in item.bullets)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '•  ',
                          style: TextStyle(fontSize: 14, height: 1.45, color: AppColors.darkText),
                        ),
                        Expanded(
                          child: Text(
                            bullet,
                            style: const TextStyle(
                              fontSize: 14,
                              height: 1.45,
                              color: AppColors.darkText,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
