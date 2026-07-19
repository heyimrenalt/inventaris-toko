import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../../domain/prioritas_kulakan_calculator.dart';

/// Horizontal bar chart of the top sales-velocity products for "Sering
/// Keluar" — a quick-glance ranking for a non-technical shopkeeper, not a
/// general-purpose chart widget. Built from plain widgets rather than a
/// chart package: fl_chart (the obvious pub.dev option) has no native
/// horizontal-bar orientation as of 1.2.0, and its RotatedBox workaround
/// fights label layout on the long Indonesian product names this app
/// deals with — the same squeeze [FrequentlySoldListItem] was fixed for.
///
/// Takes [results] already sorted by dailyVelocity descending (as
/// [FrequentlySoldScreen] computes via `sortFrequentlySold`) and shows at
/// most [maxBars] of them, so the chart and the list below it always
/// agree — there's no separate calculation here.
class FrequentlySoldChart extends StatelessWidget {
  const FrequentlySoldChart({super.key, required this.results, this.maxBars = 7});

  final List<PrioritasKulakanResult> results;
  final int maxBars;

  @override
  Widget build(BuildContext context) {
    final bars = results.take(maxBars).toList();
    if (bars.isEmpty) return const SizedBox.shrink();

    final maxVelocity = bars.first.dailyVelocity;

    return Padding(
      key: const Key('frequently_sold_chart'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Produk Paling Laris',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          for (final result in bars) _ChartBar(result: result, maxVelocity: maxVelocity),
        ],
      ),
    );
  }
}

class _ChartBar extends StatelessWidget {
  const _ChartBar({required this.result, required this.maxVelocity});

  final PrioritasKulakanResult result;

  /// The largest dailyVelocity among the bars currently shown — always
  /// > 0 here, since only products with dailyVelocity > 0 ever reach this
  /// chart (see `sortFrequentlySold`), and this is the max of that set.
  final double maxVelocity;

  @override
  Widget build(BuildContext context) {
    final product = result.product;
    final fraction = (result.dailyVelocity / maxVelocity).clamp(0.0, 1.0);

    return Padding(
      key: Key('frequently_sold_chart_bar_${product.id}'),
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            product.name,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Container(
                      height: 20,
                      decoration: BoxDecoration(
                        color: AppColors.greenSubtle,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: fraction,
                      child: Container(
                        height: 20,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: const BorderRadius.horizontal(right: Radius.circular(4)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '~${formatVelocity(result.dailyVelocity)}/hari',
                key: Key('frequently_sold_chart_value_${product.id}'),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
