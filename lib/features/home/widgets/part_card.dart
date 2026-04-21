import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/colors.dart';
import '../../../core/localization/app_lang.dart';
import '../../../core/local_storage/cache_helper.dart'; // 🔥 تم استيراد الكاش لحماية الزائر
import '../screens/part_details_screen.dart';
import '../../marketplace/models/car_model.dart';
import '../../marketplace/cubit/market_cubit.dart';
import '../../marketplace/cubit/market_state.dart';

class PartCard extends StatelessWidget {
  final CarModel partItem;
  final bool isPromoted;

  const PartCard({
    super.key,
    required this.partItem,
    this.isPromoted = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cubit = context.read<MarketCubit>();

    // 🔥 الذكاء الاصطناعي للكارت: بيعرف لوحده إنه ممول 🔥
    final bool isActuallyPromoted = isPromoted || cubit.promotedPartsList.any((p) => p.id == partItem.id);

    final title = partItem.make;
    final compatibility = partItem.model;

    // 🔥 السحر هنا: كود بيقسم السعر ويحط فواصل الآلاف 🔥
    final formattedPrice = partItem.price.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');
    final price = "${AppLang.tr(context, 'currency_egp') ?? 'EGP'} $formattedPrice";

    final imageUrl = partItem.images.isNotEmpty ? partItem.images.first : null;
    const fallbackImage = 'https://images.unsplash.com/photo-1552519507-da3b142c6e3d?q=80&w=800&auto=format&fit=crop';

    // الألوان: لو ممول بياخد خلفية دهبي شيك
    Color cardBgColor = isActuallyPromoted
        ? (isDark ? const Color(0xFF3E3220) : const Color(0xFFFFFDF5))
        : (isDark ? const Color(0xFF161E27) : Colors.white);

    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => PartDetailsScreen(partItem: partItem, isPromoted: isActuallyPromoted)));
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardBgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isActuallyPromoted ? const Color(0xFFF39C12).withOpacity(0.5) : (isDark ? Colors.white10 : Colors.transparent),
              width: isActuallyPromoted ? 1.5 : 1.0
          ),
          boxShadow: [
            BoxShadow(
              color: isActuallyPromoted ? const Color(0xFFF39C12).withOpacity(0.15) : Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔥 قسم الصورة (مربع على الشمال/اليمين) 🔥
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: CachedNetworkImage(
                    imageUrl: imageUrl ?? fallbackImage,
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => const SizedBox(width: 100, height: 100, child: Center(child: CircularProgressIndicator(color: AppColors.primary))),
                    errorWidget: (context, url, error) => CachedNetworkImage(imageUrl: fallbackImage, width: 100, height: 100, fit: BoxFit.cover),
                  ),
                ),
                // 🔥 تم ضبط الـ PositionedDirectional عشان يقلب مع العربي واللغات تلقائي 🔥
                if (isActuallyPromoted)
                  PositionedDirectional(
                    top: 0,
                    start: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF39C12),
                        // ضبط الـ Radius عشان يمشي مع اتجاه الشارة
                        borderRadius: BorderRadiusDirectional.only(
                            bottomEnd: Radius.circular(12),
                            topStart: Radius.circular(16)
                        ),
                      ),
                      child: const Icon(Icons.local_fire_department, color: Colors.white, size: 14),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 16),

            // 🔥 قسم التفاصيل (جنب الصورة) 🔥
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: isDark ? Colors.white : Colors.black87),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // 🔥 زرار القلب بحماية الزوار (V2 Ready) 🔥
                      BlocBuilder<MarketCubit, MarketState>(
                        builder: (context, state) {
                          bool isSaved = cubit.isPartSaved(partItem.id);
                          return GestureDetector(
                            onTap: () {
                              if (CacheHelper.getData(key: 'uid') == null) {
                                // استدعي GuestChecker هنا لو عايز تطلع الـ Dialog
                                return;
                              }
                              cubit.toggleSavedPart(partItem);
                            },
                            child: Icon(
                              isSaved ? Icons.favorite : Icons.favorite_border,
                              color: isSaved ? Colors.redAccent : (isDark ? Colors.white54 : AppColors.textHint),
                              size: 22,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppLang.tr(context, 'compatibility') ?? "متوافق مع:",
                    style: TextStyle(color: isDark ? Colors.white54 : AppColors.textHint, fontSize: 11),
                  ),
                  Text(
                    compatibility.toUpperCase(),
                    style: TextStyle(color: isDark ? Colors.white70 : AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    price,
                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w900, fontSize: 18),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}