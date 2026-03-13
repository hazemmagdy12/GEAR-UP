import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/colors.dart';
import '../../../core/localization/app_lang.dart';
import '../../../core/local_storage/cache_helper.dart';
import '../../marketplace/cubit/market_cubit.dart';
import '../../marketplace/cubit/market_state.dart';
import '../../marketplace/models/car_model.dart';
import '../../home/widgets/car_card.dart';
import '../../home/widgets/part_card.dart';
import 'start_selling_screen.dart';
import '../../home/widgets/ai_chat_bottom_sheet.dart';

class PublishedItemsScreen extends StatefulWidget {
  const PublishedItemsScreen({super.key});

  @override
  State<PublishedItemsScreen> createState() => _PublishedItemsScreenState();
}

class _PublishedItemsScreenState extends State<PublishedItemsScreen> {
  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    final cubit = context.read<MarketCubit>();
    if (cubit.carsList.isEmpty) cubit.getCars();
    if (cubit.sparePartsList.isEmpty) cubit.getSpareParts();
  }

  void _showDeleteConfirmation(BuildContext context, CarModel item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF161E27) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(AppLang.tr(context, 'delete_listing') ?? 'مسح الإعلان', style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
        content: Text(AppLang.tr(context, 'delete_confirm') ?? 'هل أنت متأكد من مسح هذا الإعلان نهائياً؟', style: TextStyle(color: isDark ? Colors.white70 : Colors.black54)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(AppLang.tr(context, 'cancel_btn') ?? 'إلغاء', style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                // 🔥 التعديل السحري: رمينا حمل المسح على الكيوبت الذكي اللي بيعرف نوع الكوليكشن 🔥
                await context.read<MarketCubit>().deleteUserItem(item);

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLang.tr(context, 'delete_success') ?? 'تم مسح الإعلان بنجاح'), backgroundColor: Colors.green));
                }
              } catch(e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLang.tr(context, 'delete_error') ?? 'حدث خطأ أثناء المسح'), backgroundColor: Colors.red));
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: Text(AppLang.tr(context, 'delete_btn') ?? 'مسح', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String? currentUserId = CacheHelper.getData(key: 'uid');

    final Color screenBgColor = isDark ? const Color(0xFF0A0F14) : const Color(0xFFF4F7FA);

    return BlocBuilder<MarketCubit, MarketState>(
      builder: (context, state) {
        final cubit = context.read<MarketCubit>();

        // 🔥 الخوارزمية المانعة للتكرار: بنجيب كل إعلاناتك من كل حتة ونفلترها بالـ ID 🔥
        List<CarModel> rawUserItems = [
          ...cubit.carsList.where((item) => item.sellerId == currentUserId),
          ...cubit.promotedCarsList.where((item) => item.sellerId == currentUserId),
          ...cubit.sparePartsList.where((item) => item.sellerId == currentUserId),
          ...cubit.promotedPartsList.where((item) => item.sellerId == currentUserId),
        ];

        // استخدام Map لضمان عدم وجود أي عنصر متكرر نهائياً
        final Map<String, CarModel> uniqueItemsMap = {};
        for (var item in rawUserItems) {
          uniqueItemsMap[item.id] = item;
        }

        final List<CarModel> myItems = uniqueItemsMap.values.toList();
        // الترتيب من الأحدث للأقدم
        myItems.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        final myCars = myItems.where((item) => item.itemType == 'type_car').toList();
        final myParts = myItems.where((item) => item.itemType == 'type_part').toList();
        final myAccessories = myItems.where((item) => item.itemType == 'type_accessory').toList();

        final isLoading = state is GetCarsLoading || state is SearchCarsLoading;

        final List<String> tabs = [
          "${AppLang.tr(context, 'tab_all') ?? 'الكل'} (${myItems.length})",
          "${AppLang.tr(context, 'tab_cars') ?? 'سيارات'} (${myCars.length})",
          "${AppLang.tr(context, 'tab_parts') ?? 'قطع غيار'} (${myParts.length})",
          "${AppLang.tr(context, 'tab_accessories') ?? 'إكسسوارات'} (${myAccessories.length})"
        ];

        List<CarModel> listToShow = [];
        if (_selectedTabIndex == 0) listToShow = myItems;
        else if (_selectedTabIndex == 1) listToShow = myCars;
        else if (_selectedTabIndex == 2) listToShow = myParts;
        else if (_selectedTabIndex == 3) listToShow = myAccessories;

        return Scaffold(
          backgroundColor: screenBgColor,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              if (myItems.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 12.0),
                  child: IconButton(
                    icon: const Icon(Icons.add_circle_outline, size: 28, color: AppColors.primary),
                    onPressed: () {
                      String initialType = 'type_car';
                      if (_selectedTabIndex == 2) initialType = 'type_part';
                      else if (_selectedTabIndex == 3) initialType = 'type_accessory';

                      Navigator.push(context, MaterialPageRoute(builder: (context) => StartSellingScreen(initialItemType: initialType)));
                    },
                  ),
                ),
            ],
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(AppLang.tr(context, 'published_items') ?? 'إعلاناتي', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)),
                    const SizedBox(height: 4),
                    Text(AppLang.tr(context, 'manage_listings') ?? 'أدر جميع إعلاناتك من هنا', style: TextStyle(color: isDark ? Colors.white70 : AppColors.textSecondary, fontSize: 14)),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              SizedBox(
                height: 40,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: tabs.length,
                  itemBuilder: (context, index) {
                    bool isSelected = _selectedTabIndex == index;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedTabIndex = index),
                      child: Container(
                        margin: const EdgeInsets.only(right: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary : (isDark ? const Color(0xFF1E2834) : Colors.white),
                          border: Border.all(color: isSelected ? AppColors.primary : (isDark ? Colors.white10 : const Color(0xFFEEEEEE))),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: isSelected ? [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))] : [],
                        ),
                        child: Center(
                          child: Text(
                            tabs[index],
                            style: TextStyle(color: isSelected ? Colors.white : (isDark ? Colors.white70 : AppColors.textSecondary), fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              Expanded(
                child: isLoading && myItems.isEmpty
                    ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                    : listToShow.isEmpty
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(color: isDark ? const Color(0xFF161E27) : Colors.white, shape: BoxShape.circle, border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFEEEEEE))),
                        child: const Icon(Icons.inventory_2_outlined, size: 48, color: AppColors.textHint),
                      ),
                      const SizedBox(height: 20),
                      Text(AppLang.tr(context, 'no_listings_yet') ?? 'لا توجد إعلانات بعد', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)),
                      const SizedBox(height: 8),
                      Text(AppLang.tr(context, 'haven_not_published') ?? 'لم تقم بنشر أي شيء في هذا القسم.', style: TextStyle(color: isDark ? Colors.white70 : AppColors.textSecondary)),
                      const SizedBox(height: 32),
                      GestureDetector(
                        onTap: () {
                          String initialType = 'type_car';
                          if (_selectedTabIndex == 2) initialType = 'type_part';
                          if (_selectedTabIndex == 3) initialType = 'type_accessory';
                          Navigator.push(context, MaterialPageRoute(builder: (context) => StartSellingScreen(initialItemType: initialType)));
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4))],
                          ),
                          child: Text(AppLang.tr(context, 'start_selling') ?? 'أضف إعلان جديد', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                        ),
                      ),
                    ],
                  ),
                )
                    : ListView.builder(
                  padding: const EdgeInsets.only(top: 24, left: 24, right: 24, bottom: 100),
                  itemCount: listToShow.length,
                  itemBuilder: (context, index) {
                    final item = listToShow[index];

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 28.0),
                      child: Column(
                        children: [
                          item.itemType == 'type_car' ? CarCard(car: item) : PartCard(partItem: item),

                          Transform.translate(
                            offset: const Offset(0, -10),
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 16),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E2834) : Colors.white,
                                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                                border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4))],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => Navigator.push(context, MaterialPageRoute(
                                          builder: (context) => StartSellingScreen(initialItemType: item.itemType, itemToEdit: item)
                                      )),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.edit_rounded, size: 18, color: isDark ? Colors.white70 : AppColors.primary),
                                          const SizedBox(width: 6),
                                          Text(AppLang.tr(context, 'edit_btn') ?? 'تعديل', style: TextStyle(color: isDark ? Colors.white70 : AppColors.primary, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Container(height: 20, width: 1, color: isDark ? Colors.white24 : Colors.black12),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => _showDeleteConfirmation(context, item),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                                          const SizedBox(width: 6),
                                          Text(AppLang.tr(context, 'delete_btn') ?? 'مسح', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () {
              showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (context) => const AiChatBottomSheet());
            },
            backgroundColor: AppColors.primary,
            elevation: 8,
            shape: const CircleBorder(),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 28),
          ),
        );
      },
    );
  }
}