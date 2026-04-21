import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/colors.dart';
import '../../../core/localization/app_lang.dart';
import '../cubit/market_cubit.dart';
import '../cubit/market_state.dart';

class FiltersBottomSheet extends StatelessWidget {
  const FiltersBottomSheet({super.key});

  final List<String> availableBrands = const ["Toyota", "Hyundai", "BMW", "Kia", "Mercedes", "Nissan", "Chevrolet"];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.75,
        padding: const EdgeInsets.only(left: 24, right: 24, top: 12, bottom: 24),
        decoration: BoxDecoration(
          color: isDark ? AppColors.backgroundDark.withOpacity(0.95) : Colors.white.withOpacity(0.95),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border(top: BorderSide(color: isDark ? Colors.white12 : Colors.black12)),
        ),
        child: BlocBuilder<MarketCubit, MarketState>(
          builder: (context, state) {
            final cubit = context.read<MarketCubit>();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.withOpacity(0.4), borderRadius: BorderRadius.circular(10)))),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // 🔥 حماية الـ Null Safety للترجمة 🔥
                    Text(AppLang.tr(context, 'filters') ?? "الفلاتر", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)),
                    GestureDetector(
                      onTap: () {
                        cubit.clearFilters();
                        Navigator.pop(context);
                      },
                      child: Text(AppLang.tr(context, 'clear_all') ?? "مسح الكل", style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primary)),
                    ),
                  ],
                ),
                const SizedBox(height: 30),

                // 🔥 حماية V2: Scroll View عشان مفيش شاشة تضرب Overflow أبداً 🔥
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // قسم الشركات (Brands)
                        Text(AppLang.tr(context, 'brands') ?? "الماركات", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textHint, letterSpacing: 1.2)),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 10, runSpacing: 12,
                          children: availableBrands.map((brand) {
                            final isSelected = cubit.selectedFilterBrands.contains(brand);
                            return GestureDetector(
                              onTap: () => cubit.toggleFilterBrand(brand),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isSelected ? AppColors.primary : Colors.transparent,
                                  border: Border.all(color: isSelected ? AppColors.primary : (isDark ? Colors.white24 : Colors.black12)),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(brand, style: TextStyle(color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87), fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 36),

                        // قسم السعر (Price)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(AppLang.tr(context, 'max_price') ?? "أقصى سعر", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textHint, letterSpacing: 1.2)),

                            // 🔥 تصليح لغم الـ Copy-Paste (all_brands -> any_price) وتصليح العملة 🔥
                            Text(
                                cubit.selectedMaxPrice == null
                                    ? (AppLang.tr(context, 'any_price') ?? "أي سعر")
                                    : "${AppLang.tr(context, 'up_to') ?? "حتى"} ${(cubit.selectedMaxPrice! / 1000000).toStringAsFixed(1)}${AppLang.tr(context, 'million_currency') ?? 'M'} ${AppLang.tr(context, 'currency_egp') ?? 'EGP'}",
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.primary)
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SliderTheme(
                          data: SliderThemeData(
                            activeTrackColor: AppColors.primary, inactiveTrackColor: isDark ? Colors.white12 : Colors.black12,
                            thumbColor: Colors.white, overlayColor: AppColors.primary.withOpacity(0.2),
                            trackHeight: 6, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12, elevation: 4),
                          ),
                          child: Slider(
                            value: cubit.selectedMaxPrice ?? 5000000,
                            min: 500000, max: 5000000, divisions: 9,
                            onChanged: (val) => cubit.setFilterPrice(val),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // زرار التطبيق
                SizedBox(
                  width: double.infinity, height: 56,
                  child: ElevatedButton(
                    onPressed: () {
                      cubit.applyFilters();
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
                    child: Text(AppLang.tr(context, 'apply_filters') ?? "تطبيق الفلاتر", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}