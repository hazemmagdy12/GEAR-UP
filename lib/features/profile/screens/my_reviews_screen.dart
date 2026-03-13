import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/colors.dart';
import '../../../core/localization/app_lang.dart';
import '../../marketplace/cubit/market_cubit.dart';
import '../../marketplace/cubit/market_state.dart';
import '../../marketplace/models/car_model.dart';
import '../../home/screens/car_details_screen.dart';
import '../../home/screens/part_details_screen.dart';

class MyReviewsScreen extends StatefulWidget {
  const MyReviewsScreen({super.key});

  @override
  State<MyReviewsScreen> createState() => _MyReviewsScreenState();
}

class _MyReviewsScreenState extends State<MyReviewsScreen> {
  @override
  void initState() {
    super.initState();
    context.read<MarketCubit>().getMyReviews();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color screenBgColor = isDark ? const Color(0xFF0A0F14) : const Color(0xFFF4F7FA);

    return Scaffold(
      backgroundColor: screenBgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(AppLang.tr(context, 'my_reviews') ?? "تقييماتي", style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w900, fontSize: 20)),
        centerTitle: true,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(margin: const EdgeInsets.all(8), decoration: BoxDecoration(border: Border.all(color: isDark ? Colors.white10 : AppColors.primary.withOpacity(0.3)), borderRadius: BorderRadius.circular(12), color: isDark ? const Color(0xFF161E27).withOpacity(0.8) : Colors.white.withOpacity(0.7)), child: Icon(Icons.arrow_back, size: 24, color: isDark ? Colors.white : AppColors.primary)),
        ),
      ),
      body: BlocBuilder<MarketCubit, MarketState>(
          builder: (context, state) {
            final cubit = context.read<MarketCubit>();
            final reviews = cubit.myReviewsList;

            if (cubit.isLoadingMyReviews) return const Center(child: CircularProgressIndicator(color: AppColors.primary));

            if (reviews.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: isDark ? const Color(0xFF1E2834) : Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.05), blurRadius: 20, offset: const Offset(0, 10))]), child: Icon(Icons.star_outline_rounded, size: 80, color: isDark ? Colors.white24 : AppColors.textHint.withOpacity(0.5))),
                    const SizedBox(height: 24),
                    Text(AppLang.tr(context, 'no_reviews_title') ?? "لا توجد تقييمات", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)),
                    const SizedBox(height: 8),
                    Text(AppLang.tr(context, 'no_reviews_desc') ?? "لم تقم بإضافة أي تقييمات حتى الآن.", style: TextStyle(fontSize: 14, color: isDark ? Colors.white54 : AppColors.textSecondary)),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(24),
              physics: const BouncingScrollPhysics(),
              itemCount: reviews.length,
              itemBuilder: (context, index) {
                final review = reviews[index];
                double rating = (review['rating'] as num?)?.toDouble() ?? 0.0;
                String comment = review['comment'] ?? '';
                String itemId = review['carId'] ?? ''; // Could be car or part
                String reviewId = review['reviewId'] ?? '';
                bool isPart = review['isPart'] ?? false;

                DateTime date = DateTime.tryParse(review['createdAt'] ?? '') ?? DateTime.now();
                String formattedDate = "${date.day}-${date.month}-${date.year}";

                CarModel? reviewedItem;
                try {
                  if (isPart) {
                    reviewedItem = cubit.sparePartsList.firstWhere((p) => p.id == itemId);
                  } else {
                    reviewedItem = cubit.carsList.firstWhere((c) => c.id == itemId);
                  }
                } catch (e) {
                  try {
                    if (isPart) {
                      reviewedItem = cubit.promotedPartsList.firstWhere((p) => p.id == itemId);
                    } else {
                      reviewedItem = cubit.promotedCarsList.firstWhere((c) => c.id == itemId);
                    }
                  } catch (e) { reviewedItem = null; }
                }

                // حساب اللايكات هنا للعرض فقط
                List<dynamic> likes = review['likes'] ?? [];
                int likesCount = likes.length;

                return Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceDark : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.05), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (reviewedItem != null) ...[
                        GestureDetector(
                          onTap: () {
                            if (isPart) {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => PartDetailsScreen(partItem: reviewedItem!)));
                            } else {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => CarDetailsScreen(car: reviewedItem!)));
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: isDark ? const Color(0xFF1E2834) : const Color(0xFFF9FAFC), borderRadius: BorderRadius.circular(16), border: Border.all(color: isDark ? Colors.white10 : Colors.black12)),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: CachedNetworkImage(
                                    imageUrl: reviewedItem.images.isNotEmpty ? reviewedItem.images[0] : 'https://images.unsplash.com/photo-1552519507-da3b142c6e3d',
                                    width: 60, height: 60, fit: BoxFit.cover,
                                    placeholder: (context, url) => const SizedBox(width: 60, height: 60, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
                                    errorWidget: (context, url, error) => const Icon(Icons.directions_car, color: Colors.grey, size: 40),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text("${reviewedItem.make.toUpperCase()} ${reviewedItem.model}", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: isDark ? Colors.white : Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis),
                                      const SizedBox(height: 4),
                                      Text(isPart ? "قطعة غيار" : "سيارة", style: const TextStyle(color: AppColors.textHint, fontSize: 12)),
                                    ],
                                  ),
                                ),
                                Icon(Icons.arrow_forward_ios_rounded, color: isDark ? Colors.white54 : AppColors.textHint, size: 16),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ] else ...[
                        Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Row(children: [const Icon(Icons.info_outline, color: Colors.redAccent), const SizedBox(width: 12), Text(AppLang.tr(context, 'car_not_available') ?? "هذا الإعلان لم يعد متوفراً", style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))])), const SizedBox(height: 16),
                      ],

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(children: List.generate(5, (starIndex) { return Icon(starIndex < rating ? Icons.star_rounded : Icons.star_outline_rounded, color: Colors.amber, size: 20); })),
                          Text(formattedDate, style: const TextStyle(color: AppColors.textHint, fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 12),

                      Text(comment.isNotEmpty ? comment : (AppLang.tr(context, 'no_text_comment') ?? "تقييم بالنجوم فقط."), style: TextStyle(color: comment.isNotEmpty ? (isDark ? Colors.white.withOpacity(0.85) : Colors.black87) : AppColors.textHint, fontSize: 14, height: 1.6, fontStyle: comment.isEmpty ? FontStyle.italic : FontStyle.normal)),
                      const SizedBox(height: 16),

                      Divider(color: isDark ? Colors.white10 : Colors.black12, height: 1),
                      const SizedBox(height: 12),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.thumb_up_alt_rounded, color: AppColors.primary, size: 18),
                              const SizedBox(width: 6),
                              Text("$likesCount لايك", style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                          Row(
                            children: [
                              GestureDetector(onTap: () => _showEditDialog(context, cubit, itemId, reviewId, rating, comment, isDark, isPart), child: const Icon(Icons.edit_outlined, color: AppColors.primary, size: 20)),
                              const SizedBox(width: 20),
                              GestureDetector(onTap: () => _showDeleteDialog(context, cubit, itemId, reviewId, isDark, isPart), child: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20)),
                            ],
                          )
                        ],
                      )
                    ],
                  ),
                );
              },
            );
          }
      ),
    );
  }

  void _showEditDialog(BuildContext context, MarketCubit cubit, String itemId, String reviewId, double currentRating, String currentComment, bool isDark, bool isPart) {
    double tempRating = currentRating;
    TextEditingController commentController = TextEditingController(text: currentComment);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF161E27) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: isDark ? Colors.white10 : Colors.transparent)),
            title: Text(AppLang.tr(context, 'edit_review_title') ?? 'تعديل التقييم', style: TextStyle(fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(5, (index) { return GestureDetector(onTap: () { setState(() => tempRating = index + 1.0); }, child: Icon(index < tempRating ? Icons.star_rounded : Icons.star_outline_rounded, color: Colors.amber, size: 36)); })),
                const SizedBox(height: 16),
                TextField(controller: commentController, maxLines: 3, style: TextStyle(color: isDark ? Colors.white : Colors.black87), decoration: InputDecoration(hintText: AppLang.tr(context, 'write_comment_hint') ?? 'اكتب تعليقك...', hintStyle: const TextStyle(color: Colors.grey), filled: true, fillColor: isDark ? const Color(0xFF1E2834) : const Color(0xFFF5F6F8), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppLang.tr(context, 'cancel_btn') ?? 'إلغاء')),
              ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: () { Navigator.pop(ctx); cubit.updateReviewFromProfile(itemId, reviewId, tempRating, commentController.text.trim(), isPart: isPart); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLang.tr(context, 'review_updated_success') ?? 'تم تحديث التقييم بنجاح'), backgroundColor: Colors.green)); }, child: Text(AppLang.tr(context, 'update_btn') ?? 'تحديث', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
            ],
          );
        },
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, MarketCubit cubit, String itemId, String reviewId, bool isDark, bool isPart) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF161E27) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: isDark ? Colors.white10 : Colors.transparent)),
        title: Row(children: [Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.warning_amber_rounded, color: Colors.redAccent)), const SizedBox(width: 12), Text(AppLang.tr(context, 'confirm_delete_title') ?? 'تأكيد الحذف', style: TextStyle(fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87, fontSize: 18))]),
        content: Text(AppLang.tr(context, 'confirm_delete_review_msg') ?? 'هل أنت متأكد أنك تريد حذف هذا التقييم نهائياً؟', style: TextStyle(color: isDark ? Colors.white70 : AppColors.textSecondary, fontSize: 14, height: 1.5)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppLang.tr(context, 'undo_btn') ?? 'تراجع', style: TextStyle(color: isDark ? Colors.white54 : AppColors.textHint, fontWeight: FontWeight.bold))),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10)), onPressed: () { Navigator.pop(ctx); cubit.deleteMyReview(itemId, reviewId, isPart: isPart); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLang.tr(context, 'review_deleted_success') ?? 'تم حذف التقييم بنجاح'), backgroundColor: Colors.green)); }, child: Text(AppLang.tr(context, 'yes_delete_btn') ?? 'نعم، احذف', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }
}