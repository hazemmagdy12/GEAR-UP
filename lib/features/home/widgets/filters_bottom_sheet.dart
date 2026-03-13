import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/colors.dart';
import '../../marketplace/cubit/market_cubit.dart';
import '../../marketplace/cubit/market_state.dart';

class FiltersBottomSheet extends StatelessWidget {
  const FiltersBottomSheet({super.key});

  // ضفنا كل الماركات الأساسية عشان الفلتر يكون شامل
  final List<String> companies = const [
    "Toyota", "Hyundai", "BMW", "Kia", "Mercedes-Benz", "Audi",
    "Nissan", "Chevrolet", "Volkswagen", "Fiat", "Peugeot",
    "Renault", "Jeep", "Ford", "Honda", "Skoda", "MG", "Chery"
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.88,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF161618) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20)],
        ),
        child: BlocBuilder<MarketCubit, MarketState>(
          builder: (context, state) {
            final cubit = context.read<MarketCubit>();

            return Column(
              children: [
                // ================= HEADER =================
                Padding(
                  padding: const EdgeInsets.only(left: 24, right: 24, top: 16, bottom: 16),
                  child: Column(
                    children: [
                      Center(child: Container(width: 48, height: 5, decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(10)))),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Filters", style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)),
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () => cubit.clearFilters(),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                                  child: const Text("Clear All", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                                ),
                              ),
                              const SizedBox(width: 16),
                              GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05), shape: BoxShape.circle),
                                  child: Icon(Icons.close, size: 20, color: isDark ? Colors.white70 : Colors.black54),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                Divider(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05), thickness: 1, height: 1),

                // ================= SCROLLABLE CONTENT =================
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("COMPANY", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1.5)),
                        const SizedBox(height: 20),

                        // عرض الماركات في شبكة (Grid) عشان تستوعب العدد الكبير بشياكة
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2, // عمودين
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 2.8, // نسبة العرض للطول عشان تبقى مستطيلة
                          ),
                          itemCount: companies.length,
                          itemBuilder: (context, index) {
                            final brand = companies[index];
                            final isSelected = cubit.selectedFilterBrands.contains(brand);
                            return GestureDetector(
                              onTap: () => cubit.toggleFilterBrand(brand),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: isSelected ? AppColors.primary.withOpacity(0.15) : (isDark ? const Color(0xFF222222) : const Color(0xFFF8F9FA)),
                                  border: Border.all(color: isSelected ? AppColors.primary : (isDark ? Colors.white10 : Colors.black12), width: 1.5),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(child: Text(brand, style: TextStyle(color: isSelected ? AppColors.primary : (isDark ? Colors.white70 : Colors.black87), fontWeight: isSelected ? FontWeight.bold : FontWeight.w600, fontSize: 14), overflow: TextOverflow.ellipsis)),
                                    if (isSelected) const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 36),

                        // ================= PRICE =================
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("MAX PRICE", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1.5)),
                            Text(cubit.selectedMaxPrice == null ? "Any Price" : "Up to ${(cubit.selectedMaxPrice! / 1000000).toStringAsFixed(1)}M EGP", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.primary)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SliderTheme(
                          data: SliderThemeData(
                            activeTrackColor: AppColors.primary, inactiveTrackColor: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
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

                // ================= BOTTOM STICKY BUTTON =================
                Container(
                  padding: const EdgeInsets.only(left: 24, right: 24, top: 16, bottom: 32),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF161618) : Colors.white,
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.4 : 0.05), blurRadius: 15, offset: const Offset(0, -5))],
                  ),
                  child: SizedBox(
                    width: double.infinity, height: 56,
                    child: ElevatedButton(
                      onPressed: () {
                        cubit.applyFilters();
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
                      child: const Text("Apply Filters", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                    ),
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