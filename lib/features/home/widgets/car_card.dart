import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/colors.dart';
import '../../../core/localization/app_lang.dart';
import '../screens/car_details_screen.dart';
import '../../marketplace/models/car_model.dart';
import '../../marketplace/cubit/market_cubit.dart';
import '../../marketplace/cubit/market_state.dart';

class CarCard extends StatelessWidget {
  final CarModel car;
  final bool isPromoted;

  const CarCard({
    super.key,
    required this.car,
    this.isPromoted = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cubit = context.read<MarketCubit>();
    final bool isActuallyPromoted = isPromoted || cubit.promotedCarsList.any((promotedCar) => promotedCar.id == car.id);

    final brand = car.make;
    final model = car.model;
    final year = car.year;

    final price = "${AppLang.tr(context, 'currency_egp') ?? 'EGP'} ${car.price.toStringAsFixed(0)}";
    final rating = car.rating > 0 ? car.rating.toStringAsFixed(1) : "0.0";
    final isTopRated = car.rating >= 4.5 && car.reviewsCount > 0;

    final imageUrl = car.images.isNotEmpty ? car.images.first : null;
    const fallbackImage = 'https://images.unsplash.com/photo-1552519507-da3b142c6e3d?q=80&w=800&auto=format&fit=crop';

    Color cardBgColor;
    if (isActuallyPromoted) {
      cardBgColor = isDark ? const Color(0xFF3E3220) : const Color(0xFFFFF9E6);
    } else {
      cardBgColor = isDark ? const Color(0xFF242C32) : Colors.white;
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CarDetailsScreen(
              car: car,
              isPromoted: isActuallyPromoted,
            ),
          ),
        );
      },
      child: Container(
        width: 280,
        margin: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: cardBgColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: isDark ? Colors.white10 : Colors.transparent),
          boxShadow: [
            BoxShadow(
              color: isActuallyPromoted
                  ? const Color(0xFFF39C12).withOpacity(isDark ? 0.3 : 0.15)
                  : Colors.black.withOpacity(isDark ? 0.3 : 0.05),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    child: imageUrl != null && imageUrl.isNotEmpty
                        ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                      errorWidget: (context, url, error) => CachedNetworkImage(imageUrl: fallbackImage, fit: BoxFit.cover),
                    )
                        : CachedNetworkImage(imageUrl: fallbackImage, fit: BoxFit.cover),
                  ),
                ),

                if (isActuallyPromoted)
                  Positioned(
                    top: 16,
                    left: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF39C12),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: const Color(0xFFF39C12).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.local_fire_department, color: Colors.white, size: 14),
                          const SizedBox(width: 4),
                          Text(AppLang.tr(context, 'promoted') ?? 'ممول', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  )
                else if (isTopRated)
                  Positioned(
                    top: 16,
                    left: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.star, color: Colors.white, size: 14),
                          const SizedBox(width: 4),
                          Text(AppLang.tr(context, 'top_rated') ?? 'أعلى تقييم', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),

                Positioned(
                  top: 16,
                  right: 16,
                  child: BlocBuilder<MarketCubit, MarketState>(
                    builder: (context, state) {
                      bool isSaved = cubit.isCarSaved(car.id);
                      bool isCompared = cubit.isCarInCompare(car.id);

                      return Column(
                        children: [
                          _buildIconButton(
                            icon: isSaved ? Icons.favorite : Icons.favorite_border,
                            iconColor: isSaved ? Colors.redAccent : (isDark ? Colors.white : AppColors.secondary),
                            isDark: isDark,
                            onTap: () => cubit.toggleSavedCar(car),
                          ),
                          const SizedBox(height: 12),
                          _buildIconButton(
                            icon: Icons.compare_arrows,
                            iconColor: isCompared ? Colors.white : (isDark ? Colors.white : AppColors.secondary),
                            isDark: isDark,
                            backgroundColor: isCompared ? AppColors.primary : null,
                            onTap: () => cubit.toggleCompareCar(car, context),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(brand.toUpperCase(), style: const TextStyle(color: AppColors.textHint, fontSize: 13, letterSpacing: 1.2, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text(model, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: isDark ? Colors.white : Colors.black87), overflow: TextOverflow.ellipsis)),
                      const Icon(Icons.chevron_right, color: AppColors.textHint, size: 24),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(year, style: TextStyle(color: isDark ? Colors.white70 : AppColors.textSecondary, fontSize: 15, fontWeight: FontWeight.w500)),
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.orange, size: 18),
                          const SizedBox(width: 4),
                          Text(rating, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? Colors.white : Colors.black87)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 🔥 التعديل السحري لمنع الـ Overflow نهائياً 🔥
                  SizedBox(
                    width: double.infinity,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          flex: 3,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: AlignmentDirectional.centerStart,
                            child: Text(
                              price,
                              style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w900, fontSize: 20),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          flex: 2,
                          child: Text(
                            AppLang.tr(context, 'average_price') ?? 'متوسط السعر',
                            style: TextStyle(color: isDark ? Colors.white54 : AppColors.textHint, fontSize: 11, fontWeight: FontWeight.w500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconButton({required IconData icon, required Color iconColor, required bool isDark, required VoidCallback onTap, Color? backgroundColor}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
            color: backgroundColor ?? (isDark ? const Color(0xFF38404B) : Colors.white),
            shape: BoxShape.circle,
            border: backgroundColor != null ? Border.all(color: isDark ? Colors.white24 : Colors.blue[100]!, width: 2) : null,
            boxShadow: [
              BoxShadow(
                  color: backgroundColor != null ? AppColors.primary.withOpacity(isDark ? 0.3 : 0.1) : Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                  blurRadius: 5,
                  offset: const Offset(0, 2)
              )
            ]
        ),
        child: Icon(icon, size: 20, color: iconColor),
      ),
    );
  }
}