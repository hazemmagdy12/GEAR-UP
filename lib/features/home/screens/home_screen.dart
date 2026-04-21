import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:showcaseview/showcaseview.dart';
import '../../../core/theme/colors.dart';
import '../../../core/localization/app_lang.dart';
import '../../../core/local_storage/cache_helper.dart';
import '../widgets/car_card.dart';
import '../widgets/part_card.dart';
import '../widgets/filters_bottom_sheet.dart';
import 'search_screen.dart';
import 'view_all_cars_screen.dart';
import 'saved_cars_screen.dart';
import 'saved_parts_screen.dart';
import '../../nearby/screens/nearby_locations_screen.dart';
import '../../marketplace/cubit/market_cubit.dart';
import '../../marketplace/cubit/market_state.dart';
import '../../profile/screens/start_selling_screen.dart';
import '../../marketplace/models/car_model.dart';
import '../../auth/screens/login_screen.dart';
import 'main_layout.dart';

// =================================================================
// HomeScreen
// =================================================================
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const HomeScreenContent();
  }
}

class HomeScreenContent extends StatefulWidget {
  const HomeScreenContent({super.key});

  @override
  State<HomeScreenContent> createState() => _HomeScreenContentState();
}

class _HomeScreenContentState extends State<HomeScreenContent> {
  final ScrollController _newCarsScrollController = ScrollController();
  final ScrollController _usedCarsScrollController = ScrollController();
  final ScrollController _newsScrollController = ScrollController();
  final ScrollController _mainScrollController = ScrollController();
  final ScrollController _promotedScrollController = ScrollController();
  final ScrollController _topRatedScrollController = ScrollController();
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey = GlobalKey<RefreshIndicatorState>();

  bool _showQuickMenuIcon = false;
  Offset _quickMenuPosition = const Offset(16, 600);
  bool _isDraggingQuickMenu = false;
  bool _isQuickMenuCollapsed = true;
  bool _isPositionInitialized = false;
  Timer? _quickMenuTimer;

  List<CarModel> _actualTopRatedCars = [];
  bool _isLoadingTopRated = true;

  List<CarModel> _homePromotedCars = [];
  List<CarModel> _homeNewCars = [];
  List<CarModel> _homeUsedCars = [];

  final Map<int, ScrollController> _dynamicScrollControllers = {};

  @override
  void initState() {
    super.initState();

    final marketCubit = context.read<MarketCubit>();
    marketCubit.initializeHomeData();    // 1. تحميل السيارات الأساسية فوراً
    if (marketCubit.carsList.isEmpty) marketCubit.getCars();
    if (marketCubit.sparePartsList.isEmpty) marketCubit.getSpareParts();

    // 2. تأخير الطلبات الثانوية (الأخبار والـ API الخارجي) جزء من الثانية
    // عشان ندي فرصة للشاشة تترسم (Render) بنعومة بدون تقطيع
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        if (marketCubit.newCarsList.isEmpty && marketCubit.usedCarsList.isEmpty) {
          marketCubit.fetchExternalCarsData();
        }
        if (marketCubit.newsList.isEmpty) marketCubit.getNews();
      }
    });

    if (marketCubit.carsList.isNotEmpty) {
      _initializeHomeLists(marketCubit);
      Future.microtask(() => _loadTopRatedCars());
    }

    _startQuickMenuTimer();

    // ... (باقي أكواد الـ Listeners بتاعة الـ ScrollController زي ما هي بدون تغيير)
    _newCarsScrollController.addListener(() {
      if (_newCarsScrollController.position.pixels >= _newCarsScrollController.position.maxScrollExtent - 800) {
        bool added = _injectMoreCarsLocally(_homeNewCars, marketCubit.newCarsList, fallback: marketCubit.carsList);
        if (!added && !marketCubit.isSearchingCategoryAPI) marketCubit.searchCategoryCarsFromAI("", "السيارات الجديدة");
      }
    });

    _usedCarsScrollController.addListener(() {
      if (_usedCarsScrollController.position.pixels >= _usedCarsScrollController.position.maxScrollExtent - 800) {
        bool added = _injectMoreCarsLocally(_homeUsedCars, marketCubit.usedCarsList, fallback: marketCubit.carsList);
        if (!added && !marketCubit.isSearchingCategoryAPI) marketCubit.searchCategoryCarsFromAI("", "السيارات المستعملة");
      }
    });

    _promotedScrollController.addListener(() {
      if (_promotedScrollController.position.pixels >= _promotedScrollController.position.maxScrollExtent - 800) {
        _injectMoreCarsLocally(_homePromotedCars, marketCubit.promotedCarsList.where((c) => c.itemType == 'type_car'), isPromotedSection: true);
      }
    });

    _topRatedScrollController.addListener(() {
      if (_topRatedScrollController.position.pixels >= _topRatedScrollController.position.maxScrollExtent - 800) {
        _injectMoreCarsLocally(_actualTopRatedCars, marketCubit.carsList.where((c) => c.rating >= 4.0 && c.reviewsCount > 0));
      }
    });

    _newsScrollController.addListener(() {
      if (_newsScrollController.position.pixels >= _newsScrollController.position.maxScrollExtent - 800) {
        if (!marketCubit.isFetchingMoreNews) marketCubit.fetchMoreNews();
      }
    });

    _mainScrollController.addListener(() {
      // استخدمنا رقم كبير زي ما اتفقنا عشان يعمل Pre-fetching (تحميل مسبق) ويبقى طلقة
      if (_mainScrollController.position.pixels >= _mainScrollController.position.maxScrollExtent - 800) {
        if (!marketCubit.isFilterActive) {
          marketCubit.generateNextDynamicSection();
        } else {
          // 🔥 السطر السحري الجديد: لو الفلتر شغال واليوزر نزل لتحت، هاتله الدفعة اللي بعدها! 🔥
          if (!marketCubit.isFetchingFilteredCars) {
            marketCubit.applyFilters(isLoadMore: true);
          }
        }
      }

      // كود إظهار وإخفاء الزرار العائم (Quick Menu) زي ما هو
      if (_mainScrollController.offset > 200 && !_showQuickMenuIcon) {
        setState(() => _showQuickMenuIcon = true);
      } else if (_mainScrollController.offset <= 200 && _showQuickMenuIcon) {
        setState(() => _showQuickMenuIcon = false);
      }
    });
  }
  bool _injectMoreCarsLocally(List<CarModel> targetList, Iterable<CarModel> primarySource, {Iterable<CarModel>? fallback, int count = 4, bool isPromotedSection = false}) {
    final cubit = context.read<MarketCubit>();
    bool isAllowed(CarModel c) {
      if (targetList.any((t) => t.id == c.id)) return false;
      if (!isPromotedSection && cubit.promotedCarsList.any((p) => p.id == c.id)) return false;
      return true;
    }
    var newCars = primarySource.where(isAllowed).take(count).toList();
    if (newCars.isEmpty && fallback != null) newCars = fallback.where(isAllowed).take(count).toList();

    if (newCars.isNotEmpty) {
      setState(() => targetList.addAll(newCars));
      return true;
    }
    return false;
  }

  ScrollController _getDynamicController(int index, MarketCubit cubit, String type) {
    if (!_dynamicScrollControllers.containsKey(index)) {
      final controller = ScrollController();
      controller.addListener(() {
        if (controller.position.pixels >= controller.position.maxScrollExtent - 150) {
          if (type == 'news') {
            if (!cubit.isFetchingMoreNews) cubit.fetchMoreNews();
          } else {
            List<CarModel> currentItems = List<CarModel>.from(cubit.dynamicBottomSections[index]['items']);
            var newCars = cubit.carsList.where((c) {
              if (currentItems.any((t) => t.id == c.id)) return false;
              if (cubit.shownDynamicCarIds.contains(c.id)) return false;
              if (type == 'top_rated' && c.rating < 4.0) return false;
              if (type != 'promoted' && cubit.promotedCarsList.any((p) => p.id == c.id)) return false;
              return true;
            }).take(4).toList();

            if (newCars.isNotEmpty) {
              setState(() {
                currentItems.addAll(newCars);
                cubit.dynamicBottomSections[index]['items'] = currentItems;
                for (var car in newCars) { cubit.shownDynamicCarIds.add(car.id); }
              });
            } else {
              if (type != 'promoted' && type != 'top_rated' && !cubit.isFetchingExternal) {
                cubit.fetchExternalCarsData();
              }
            }
          }
        }
      });
      _dynamicScrollControllers[index] = controller;
    }
    return _dynamicScrollControllers[index]!;
  }

  void _initializeHomeLists(MarketCubit cubit) {
    setState(() {
      _homePromotedCars = _getMixedRecentList(cubit.promotedCarsList.where((car) => car.itemType == 'type_car').toList());
      _homeNewCars = _getMixedRecentList(cubit.newCarsList.where((car) => car.itemType == 'type_car' && !cubit.promotedCarsList.any((p) => p.id == car.id)).toList());
      _homeUsedCars = _getMixedRecentList(cubit.usedCarsList.where((car) => car.itemType == 'type_car' && !cubit.promotedCarsList.any((p) => p.id == car.id)).toList());
    });
  }

  List<CarModel> _getMixedRecentList(List<CarModel> source) {
    var sorted = source.toList()..sort((a,b) => (DateTime.tryParse(b.createdAt) ?? DateTime.now()).compareTo(DateTime.tryParse(a.createdAt) ?? DateTime.now()));
    if (sorted.length <= 15) { return sorted..shuffle(); }
    else { var top15 = sorted.take(15).toList()..shuffle(); var rest = sorted.skip(15).toList(); return [...top15, ...rest]; }
  }

  void _appendNewItemsToHomeLists(MarketCubit cubit) {
    setState(() {
      _injectMoreCarsLocally(_homePromotedCars, cubit.promotedCarsList.where((c) => c.itemType == 'type_car'), isPromotedSection: true);
      _injectMoreCarsLocally(_homeNewCars, cubit.newCarsList, fallback: cubit.carsList);
      _injectMoreCarsLocally(_homeUsedCars, cubit.usedCarsList, fallback: cubit.carsList);

      for (int i = 0; i < cubit.dynamicBottomSections.length; i++) {
        var section = cubit.dynamicBottomSections[i];
        String type = section['type'];
        if (type != 'news') {
          List<CarModel> currentItems = List<CarModel>.from(section['items']);
          var newCars = cubit.carsList.where((c) {
            if (currentItems.any((t) => t.id == c.id)) return false;
            if (cubit.shownDynamicCarIds.contains(c.id)) return false;
            if (type == 'top_rated' && c.rating < 4.0) return false;
            if (type != 'promoted' && cubit.promotedCarsList.any((p) => p.id == c.id)) return false;
            return true;
          }).take(4).toList();

          if (newCars.isNotEmpty) {
            currentItems.addAll(newCars);
            cubit.dynamicBottomSections[i]['items'] = currentItems;
            for (var car in newCars) { cubit.shownDynamicCarIds.add(car.id); }
          }
        }
      }
    });
  }

  void _loadTopRatedCars() async {
    if (!mounted) return;
    final cubit = context.read<MarketCubit>();
    setState(() => _isLoadingTopRated = true);

    try {
      final topCars = await cubit.getActualTopRatedCars();
      if (mounted) {
        setState(() {
          _actualTopRatedCars = List.from(topCars);
          // 🔥 التعديل السحري: لو السيرفر مرجعش حاجة، نفلتر من اللوكال فوراً 🔥
          if (_actualTopRatedCars.isEmpty && cubit.carsList.isNotEmpty) {
            _actualTopRatedCars = cubit.carsList.where((c) => c.rating >= 4.0 && c.reviewsCount > 0).toList();
          }
          _isLoadingTopRated = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          // 🔥 حماية قصوى: لو النت فصل، نعرض اللوكال وماتعلقش الشاشة 🔥
          if (cubit.carsList.isNotEmpty) {
            _actualTopRatedCars = cubit.carsList.where((c) => c.rating >= 4.0 && c.reviewsCount > 0).toList();
          }
          _isLoadingTopRated = false;
        });
      }
    }
  }

  Future<void> _handleRefresh() async {
    final cubit = context.read<MarketCubit>();
    cubit.shownDynamicCarIds.clear();
    cubit.dynamicBottomSections.clear();
    setState(() => _isLoadingTopRated = true);
    await cubit.getCars();

    // 🔥 حماية V2: التأكد من إن الشاشة لسه مفتوحة قبل تحديث הـ UI
    if (!mounted) return;

    _initializeHomeLists(cubit);
    _loadTopRatedCars();
  }

  void _startQuickMenuTimer() {
    _quickMenuTimer?.cancel();
    _quickMenuTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _isQuickMenuCollapsed = true);
    });
  }

  @override
  void dispose() {
    _newCarsScrollController.dispose();
    _usedCarsScrollController.dispose();
    _newsScrollController.dispose();
    _mainScrollController.dispose();
    _promotedScrollController.dispose();
    _topRatedScrollController.dispose();
    _quickMenuTimer?.cancel();
    for (var controller in _dynamicScrollControllers.values) { controller.dispose(); }
    super.dispose();
  }

  // 🚨 ملاحظة: إنت ممكن تمسح الدالة دي وتستخدم GuestChecker لو حابب كود أنضف، بس هسيبهالك شغالة زي ما هي أماناً ليك 🚨
  void _showGuestDialog(BuildContext context, String featureName) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
        context: context,
        builder: (ctx) => Dialog(
            backgroundColor: isDark ? const Color(0xFF161E27) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.lock_outline_rounded, size: 40, color: AppColors.primary)),
                      const SizedBox(height: 20),
                      Text(AppLang.tr(context, 'login_required') ?? "تسجيل الدخول مطلوب", style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w900, fontSize: 20)),
                      const SizedBox(height: 12),
                      Text(
                          "${AppLang.tr(context, 'sorry_cannot') ?? 'عفواً، لا يمكنك '} $featureName ${AppLang.tr(context, 'as_guest') ?? ' كزائر.'}",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: isDark ? Colors.white70 : AppColors.textSecondary, fontSize: 14)
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                              onPressed: () { Navigator.pop(ctx); Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginScreen())); },
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                              child: Text(AppLang.tr(context, 'login') ?? "تسجيل الدخول", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))
                          )
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                          width: double.infinity,
                          child: TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: Text(AppLang.tr(context, 'cancel') ?? "إلغاء", style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 15, fontWeight: FontWeight.bold))
                          )
                      )
                    ]
                )
            )
        )
    );
  }

  void _showPremiumQuickMenu(BuildContext context, bool isDark) {
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent, isScrollControlled: true, builder: (context) {
      return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
              padding: const EdgeInsets.only(left: 20, right: 20, top: 12, bottom: 40),
              decoration: BoxDecoration(color: isDark ? const Color(0xFF161E27).withOpacity(0.9) : Colors.white.withOpacity(0.9), borderRadius: const BorderRadius.vertical(top: Radius.circular(32))),
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withOpacity(0.5), borderRadius: BorderRadius.circular(10))),
                    const SizedBox(height: 32),
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildActionCard(isDark: isDark, title: AppLang.tr(context, 'saved_cars') ?? 'Saved Cars', icon: Icons.favorite, iconColor: Colors.red.shade400, onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => const SavedCarsScreen())); }),
                          _buildActionCard(isDark: isDark, title: AppLang.tr(context, 'saved_parts') ?? 'Saved Parts', icon: Icons.build_outlined, iconColor: AppColors.primary, onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => const SavedPartsScreen())); }),
                          _buildActionCard(isDark: isDark, title: AppLang.tr(context, 'find_nearby') ?? 'Find Nearby', icon: Icons.location_on_outlined, iconColor: const Color(0xFFE57373), onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => const NearbyLocationsScreen())); })
                        ]
                    )
                  ]
              )
          )
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    const double iconContainerSize = 56.0;

    final Color mainBgColor = isDark ? const Color(0xFF0A0F14) : Theme.of(context).scaffoldBackgroundColor;
    final Color sectionBgColor = isDark ? const Color(0xFF0A0F14) : const Color(0xFFE3F2FD);

    if (!_isPositionInitialized) { _quickMenuPosition = Offset(16, screenHeight - 300); _isPositionInitialized = true; }
    bool isLeft = _quickMenuPosition.dx < screenWidth / 2; double currentX = _quickMenuPosition.dx;
    if (!_showQuickMenuIcon) { currentX = isLeft ? -100.0 : screenWidth + 100.0; } else if (_isQuickMenuCollapsed && !_isDraggingQuickMenu) { currentX = isLeft ? -10.0 : screenWidth - 46.0; }

    return Scaffold(
      backgroundColor: mainBgColor,
      body: SafeArea(
        child: BlocConsumer<MarketCubit, MarketState>(
          listener: (context, state) {
            final cubit = context.read<MarketCubit>();

            // شلنا setState(() {}) الفاضية الكارثية واعتمدنا على التهيئة الصحيحة
            if (state is GetCarsSuccess) {
              _initializeHomeLists(cubit);
              _loadTopRatedCars();
            }
            else if (state is AddCarSuccess) {
              _initializeHomeLists(cubit);
              _loadTopRatedCars();
            }
            else if (state is SearchCarsSuccess || state is FetchExternalCarsSuccess) {
              _appendNewItemsToHomeLists(cubit);
            }
          },
          builder: (context, state) {
            // ... (باقي كود الـ builder زي ما هو)
            final cubit = context.read<MarketCubit>();
            final isFirebaseLoading = state is GetCarsLoading && cubit.carsList.isEmpty;
            final isApiLoading = state is FetchExternalCarsLoading || cubit.isSearchingCategoryAPI;

            Widget mainScrollableContent = SingleChildScrollView(
              controller: _mainScrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (cubit.isFilterActive) ...[
                    if (state is FilterCarsLoading && cubit.filteredCarsView.isEmpty) const Padding(padding: EdgeInsets.only(top: 50), child: Center(child: CircularProgressIndicator(color: AppColors.primary)))
                    else if (cubit.filteredCarsView.isEmpty) Padding(padding: const EdgeInsets.only(top: 50), child: Center(child: Column(children: [Icon(Icons.search_off, size: 64, color: AppColors.textHint.withOpacity(0.3)), const SizedBox(height: 16), Text(AppLang.tr(context, 'no_cars_to_show') ?? "لا توجد نتائج مطابقة", style: const TextStyle(color: AppColors.textHint, fontWeight: FontWeight.bold))])) )
                    else ...[
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: cubit.filteredCarsView.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 24),
                          itemBuilder: (context, index) {
                            final filteredItem = cubit.filteredCarsView[index];
                            if (filteredItem.itemType == 'type_spare_part') {
                              return PartCard(partItem: filteredItem, isPromoted: false);
                            }
                            return CarCard(car: filteredItem, isPromoted: false);
                          },
                        ),
                        if (state is FilterCarsLoadingMore) const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Center(child: CircularProgressIndicator(color: AppColors.primary)))
                      ]
                  ]
                  else ...[
                    _buildQuickActions(context, isDark),
                    const SizedBox(height: 36),

                    if (_homePromotedCars.isNotEmpty) _buildPromotedSection(context, isDark, _homePromotedCars, isFirebaseLoading),
                    if (_homePromotedCars.isNotEmpty) const SizedBox(height: 28),

                    // 🔥 تنظيف الترجمة 🔥
                    _buildSectionWrapper(
                        context: context, isDark: isDark, title: AppLang.tr(context, 'top_rated_cars') ?? 'Top Rated Cars', subtitle: AppLang.tr(context, 'best_rated_2025') ?? 'Best rated vehicles', actionText: AppLang.tr(context, 'view_more') ?? 'View More', bgColor: sectionBgColor, isPremium: true,
                        content: _isLoadingTopRated ? const SizedBox(height: 395, child: Center(child: CircularProgressIndicator(color: AppColors.primary))) : _actualTopRatedCars.isEmpty ? SizedBox(height: 200, child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.star_border_rounded, size: 64, color: AppColors.textHint.withOpacity(0.3)), const SizedBox(height: 16), Text(AppLang.tr(context, 'no_rated_cars_yet') ?? "لم يتم تقييم سيارات حتى الآن", style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textHint, fontSize: 16))])) ) : _buildCarList(_actualTopRatedCars, false, false, isTopRatedSection: true, controller: _topRatedScrollController), onViewMore: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ViewAllCarsScreen(title: AppLang.tr(context, 'top_rated_cars') ?? 'Top Rated Cars')))
                    ),
                    const SizedBox(height: 28),

                    _buildSectionWrapper(
                        context: context, isDark: isDark, title: AppLang.tr(context, 'new_cars') ?? "New Cars", subtitle: AppLang.tr(context, 'latest_models') ?? "Latest Models", actionText: AppLang.tr(context, 'view_more'), bgColor: sectionBgColor,
                        content: _buildCarList(_homeNewCars, isApiLoading && _homeNewCars.isEmpty, false, controller: _newCarsScrollController, isFetchingMore: isApiLoading), onViewMore: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ViewAllCarsScreen(title: AppLang.tr(context, 'new_cars') ?? "New Cars")))
                    ),
                    const SizedBox(height: 28),

                    _buildSectionWrapper(
                        context: context, isDark: isDark, title: AppLang.tr(context, 'latest_cars_news') ?? "News & Insights", subtitle: AppLang.tr(context, 'latest_automotive_updates') ?? "Latest automotive updates", actionText: AppLang.tr(context, 'view_more'), bgColor: sectionBgColor,
                        content: _buildNewsList(context, isDark, cubit, _newsScrollController), onViewMore: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ViewAllCarsScreen(title: AppLang.tr(context, 'latest_cars_news') ?? "News & Insights")))
                    ),
                    const SizedBox(height: 28),

                    _buildSectionWrapper(
                        context: context, isDark: isDark, title: AppLang.tr(context, 'used_cars') ?? "Used Cars", subtitle: AppLang.tr(context, 'quality_pre_owned') ?? "Quality pre-owned vehicles", actionText: AppLang.tr(context, 'view_more'), bgColor: sectionBgColor,
                        content: _buildCarList(_homeUsedCars, isApiLoading && _homeUsedCars.isEmpty, false, controller: _usedCarsScrollController, isFetchingMore: isApiLoading), onViewMore: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ViewAllCarsScreen(title: AppLang.tr(context, 'used_cars') ?? "Used Cars")))
                    ),
                    const SizedBox(height: 28),

                    ...cubit.dynamicBottomSections.asMap().entries.map((entry) {
                      int index = entry.key; var section = entry.value;
                      if (section['type'] == 'curated') return const SizedBox.shrink();

                      Widget sectionContent;
                      if (section['type'] == 'promoted') {
                        if (_homePromotedCars.isEmpty) return const SizedBox.shrink();
                        return Padding(padding: const EdgeInsets.only(bottom: 28.0), child: _buildPromotedSection(context, isDark, _homePromotedCars, false));
                      }

                      if (section['type'] == 'news') {
                        ScrollController sc = _getDynamicController(index, cubit, 'news');
                        sectionContent = SizedBox(height: 395, child: _buildNewsList(context, isDark, cubit, sc));
                      } else {
                        bool isTopRated = section['type'] == 'top_rated';
                        List<CarModel> dynamicCars = List<CarModel>.from(section['items']);
                        if (dynamicCars.isEmpty) return const SizedBox.shrink();
                        ScrollController sc = _getDynamicController(index, cubit, section['type']);
                        sectionContent = _buildCarList(dynamicCars, false, false, isTopRatedSection: isTopRated, controller: sc, isFetchingMore: isApiLoading);
                      }

                      Color dynamicBgColor = sectionBgColor;
                      if (section['type'] == 'personalized') { dynamicBgColor = isDark ? const Color(0xFF2A2035) : const Color(0xFFF4EBFF); }

                      return Padding(padding: const EdgeInsets.only(bottom: 28.0), child: _buildSectionWrapper(context: context, isDark: isDark, title: AppLang.tr(context, section['titleKey']) ?? section['titleKey'], subtitle: AppLang.tr(context, section['subtitleKey']) ?? section['subtitleKey'], actionText: AppLang.tr(context, 'view_more'), bgColor: dynamicBgColor, isPremium: section['isPremium'], content: sectionContent, onViewMore: () { Navigator.push(context, MaterialPageRoute(builder: (context) => ViewAllCarsScreen(title: AppLang.tr(context, section['titleKey']) ?? section['titleKey']))); }));
                    }).toList(),

                    if (cubit.isGeneratingDynamicSection) const Padding(padding: EdgeInsets.symmetric(vertical: 20.0), child: Center(child: CircularProgressIndicator(color: AppColors.primary))),
                  ],
                  const SizedBox(height: 80),
                ],
              ),
            );

            return Stack(
              children: [
                Column(
                  children: [
                    Padding(padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 8), child: _buildTopBar(context, isDark)),
                    if (cubit.isFilterActive)
                      Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), decoration: BoxDecoration(gradient: LinearGradient(colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(16)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Row(children: [const Icon(Icons.tune, color: Colors.white, size: 20), const SizedBox(width: 8), Text(AppLang.tr(context, 'filtered_results') ?? 'Filtered Results', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15))]), GestureDetector(onTap: () => cubit.clearFilters(), child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), border: Border.all(color: Colors.white.withOpacity(0.4)), borderRadius: BorderRadius.circular(12)), child: Row(children: [const Icon(Icons.close, color: Colors.white, size: 14), const SizedBox(width: 4), Text(AppLang.tr(context, 'clear_filter') ?? 'Clear', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))])) )]))),

                    Expanded(
                      child: cubit.isFilterActive
                          ? mainScrollableContent
                          : RefreshIndicator(
                          key: _refreshIndicatorKey,
                          color: AppColors.primary,
                          backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
                          strokeWidth: 3.0,
                          onRefresh: _handleRefresh,
                          child: mainScrollableContent
                      ),
                    ),
                  ],
                ),

                // 🔥 الـ Quick Menu Button مع الـ Showcase 🔥
                AnimatedPositioned(
                  duration: Duration(milliseconds: _isDraggingQuickMenu ? 0 : 300),
                  curve: Curves.easeOutCubic,
                  left: currentX,
                  top: _quickMenuPosition.dy,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 300),
                    opacity: _showQuickMenuIcon ? 1.0 : 0.0,
                    child: GestureDetector(
                      onPanStart: (details) { _quickMenuTimer?.cancel(); setState(() { _isDraggingQuickMenu = true; _isQuickMenuCollapsed = false; }); },
                      onPanUpdate: (details) { setState(() { double newX = _quickMenuPosition.dx + details.delta.dx; double newY = _quickMenuPosition.dy + details.delta.dy; newX = newX.clamp(0.0, screenWidth - iconContainerSize); newY = newY.clamp(120.0, screenHeight - 120.0); _quickMenuPosition = Offset(newX, newY); }); },
                      onPanEnd: (details) { setState(() { _isDraggingQuickMenu = false; double snapX = (_quickMenuPosition.dx > screenWidth / 2) ? screenWidth - iconContainerSize : 0.0; _quickMenuPosition = Offset(snapX, _quickMenuPosition.dy); _startQuickMenuTimer(); }); },
                      onTap: () { if (_isQuickMenuCollapsed) { setState(() { _isQuickMenuCollapsed = false; _startQuickMenuTimer(); }); } else { _showPremiumQuickMenu(context, isDark); _startQuickMenuTimer(); } },
                      child: ClipRRect(
                        borderRadius: BorderRadius.horizontal(left: Radius.circular(isLeft && _isQuickMenuCollapsed ? 0 : 16), right: Radius.circular(!isLeft && _isQuickMenuCollapsed ? 0 : 16)),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: _isQuickMenuCollapsed ? 56.0 : iconContainerSize,
                            height: iconContainerSize,
                            decoration: BoxDecoration(color: isDark ? const Color(0xFF161E27).withOpacity(0.85) : Colors.white.withOpacity(0.8), border: Border.all(color: isDark ? Colors.white10 : AppColors.primary.withOpacity(0.5), width: 1.5)),
                            child: Center(child: _isQuickMenuCollapsed ? Icon(isLeft ? Icons.arrow_forward_ios_rounded : Icons.arrow_back_ios_new_rounded, color: AppColors.primary, size: 20) : const Icon(Icons.widgets_rounded, color: AppColors.primary, size: 28)),
                          ),
                        ),
                      ),
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

  Widget _buildSectionWrapper({required BuildContext context, required bool isDark, required String title, required String subtitle, required Widget content, String? actionText, required Color bgColor, VoidCallback? onViewMore, bool isPremium = false}) {
    return Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(28)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.end, children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [if (isPremium) Row(children: [Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.15), shape: BoxShape.circle), child: const Icon(Icons.stars_rounded, color: AppColors.primary, size: 22)), const SizedBox(width: 10), Expanded(child: Text(title, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: isDark ? Colors.white : AppColors.secondary, letterSpacing: 0.5), maxLines: 1, overflow: TextOverflow.ellipsis))]) else Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: isDark ? Colors.white : AppColors.secondary), maxLines: 1, overflow: TextOverflow.ellipsis), const SizedBox(height: 6), Text(subtitle, style: TextStyle(fontSize: 14, color: isDark ? Colors.white70 : AppColors.textSecondary, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis)])), if (actionText != null) ...[const SizedBox(width: 8), GestureDetector(onTap: onViewMore, child: Container(padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8), color: Colors.transparent, child: Row(children: [Text(actionText, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? AppColors.primary : AppColors.secondary, fontSize: 13)), const SizedBox(width: 4), Icon(Icons.arrow_forward_ios, color: isDark ? AppColors.primary : AppColors.secondary, size: 12)])))]]), const SizedBox(height: 24), content]));
  }

  Widget _buildPromotedSection(BuildContext context, bool isDark, List cars, bool isLoading) {
    return Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: isDark ? const Color(0xFF2C2416) : const Color(0xFFFFF9E6), borderRadius: BorderRadius.circular(28)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Row(children: [Text(AppLang.tr(context, 'promoted') ?? 'Promoted', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: isDark ? const Color(0xFFFFB74D) : const Color(0xFFD35400))), const SizedBox(width: 12), Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: isDark ? const Color(0xFFFF9800) : const Color(0xFFF39C12), borderRadius: BorderRadius.circular(12)), child: Text(AppLang.tr(context, 'featured_listings') ?? 'Featured', style: TextStyle(color: isDark ? Colors.black87 : Colors.white, fontSize: 11, fontWeight: FontWeight.bold)))]), GestureDetector(onTap: () { Navigator.push(context, MaterialPageRoute(builder: (context) => ViewAllCarsScreen(title: AppLang.tr(context, 'promoted') ?? 'Promoted'))); }, child: Container(padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8), color: Colors.transparent, child: Row(children: [Text(AppLang.tr(context, 'view_more') ?? 'More', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppColors.secondary, fontSize: 13)), const SizedBox(width: 4), Icon(Icons.arrow_forward_ios, color: isDark ? Colors.white : AppColors.secondary, size: 12)])))]), const SizedBox(height: 4), Text(AppLang.tr(context, 'premium_listings') ?? 'Premium listings', style: TextStyle(fontSize: 14, color: isDark ? Colors.white70 : AppColors.textSecondary, fontWeight: FontWeight.w500)), const SizedBox(height: 24), _buildCarList(cars, isLoading, true, controller: _promotedScrollController, isFetchingMore: isLoading), const SizedBox(height: 20),
      LuxuriousShowcase(
        showcaseKey: AppTourKeys.addAdKey,
        title: AppLang.tr(context, 'tour_start_ad_title') ?? 'ابدأ إعلانك',
        description: AppLang.tr(context, 'tour_start_ad_desc') ?? 'اضغط هنا عشان تنشر إعلان سيارتك وتوصل لآلاف المشترين.',
        child: Container(width: double.infinity, decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppColors.premiumGoldStart, AppColors.premiumGoldEnd], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(16)), child: ElevatedButton.icon(onPressed: () { if (CacheHelper.getData(key: 'uid') == null) { _showGuestDialog(context, AppLang.tr(context, 'publish_ads_feature') ?? "نشر إعلانات"); return; } Navigator.push(context, MaterialPageRoute(builder: (context) => const StartSellingScreen(initialItemType: 'type_car'))); }, icon: const Icon(Icons.add_circle_outline, color: AppColors.secondary, size: 20), label: Text(AppLang.tr(context, 'start_ad_now') ?? 'Start Ad Now', style: const TextStyle(color: AppColors.secondary, fontWeight: FontWeight.bold, fontSize: 15)), style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, padding: const EdgeInsets.symmetric(vertical: 14)))),
      )
    ]));
  }

  Widget _buildNewsList(BuildContext context, bool isDark, MarketCubit cubit, [ScrollController? controller]) {
    if (cubit.isFetchingNews && cubit.newsList.isEmpty) return const SizedBox(height: 395, child: Center(child: CircularProgressIndicator(color: AppColors.primary)));
    if (cubit.newsList.isEmpty) return SizedBox(height: 200, child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.newspaper, size: 64, color: AppColors.textHint.withOpacity(0.3)), const SizedBox(height: 16), Text(AppLang.tr(context, 'no_news_available') ?? "لا توجد أخبار حالياً", style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textHint, fontSize: 16))])));
    return SizedBox(height: 395, child: ListView.builder(controller: controller, scrollDirection: Axis.horizontal, physics: const BouncingScrollPhysics(), clipBehavior: Clip.none, itemCount: cubit.newsList.length + (cubit.isFetchingMoreNews ? 1 : 0), itemBuilder: (context, index) { if (index == cubit.newsList.length) return const Padding(padding: EdgeInsets.symmetric(horizontal: 20.0), child: Center(child: CircularProgressIndicator(color: AppColors.primary))); final news = cubit.newsList[index]; String displayDate = news.date; if (displayDate == 'الآن' || displayDate.isEmpty || displayDate.contains('hours') || displayDate.contains('ساعات')) { DateTime dt = DateTime.tryParse(news.createdAt) ?? DateTime.now(); displayDate = "${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}"; } return _buildNewsCard(isDark: isDark, date: displayDate, title: news.title, desc: news.snippet, imageUrl: news.imageUrl, articleUrl: news.articleUrl); }));
  }

  Widget _buildNewsCard({required bool isDark, required String date, required String title, required String desc, required String imageUrl, required String articleUrl}) {
    return GestureDetector(onTap: () async { try { final Uri uri = Uri.parse(articleUrl); if (!await launchUrl(uri, mode: LaunchMode.inAppBrowserView)) await launchUrl(uri, mode: LaunchMode.externalApplication); } catch (e) { print("Error: $e"); } }, child: Container(width: 320, margin: const EdgeInsets.only(right: 20), decoration: BoxDecoration(color: isDark ? const Color(0xFF161E27) : Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: isDark ? Colors.white10 : Colors.transparent), boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.06), blurRadius: 15, offset: const Offset(0, 8))]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(height: 180, width: double.infinity, decoration: const BoxDecoration(borderRadius: BorderRadius.vertical(top: Radius.circular(24))), child: ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(24)), child: CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.cover, placeholder: (context, url) => const Center(child: CircularProgressIndicator(color: AppColors.primary)), errorWidget: (context, url, error) => Container(color: isDark ? const Color(0xFF1E2834) : AppColors.surfaceLight, child: const Center(child: Icon(Icons.newspaper_rounded, size: 70, color: AppColors.textHint)))))), Padding(padding: const EdgeInsets.all(20.0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: isDark ? const Color(0xFF1E2834) : AppColors.surfaceLight, borderRadius: BorderRadius.circular(8)), child: Text(date, style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold))), const SizedBox(height: 12), Text(title, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, height: 1.3, color: isDark ? Colors.white : Colors.black87), maxLines: 2, overflow: TextOverflow.ellipsis), const SizedBox(height: 8), Text(desc, style: TextStyle(color: isDark ? Colors.white70 : AppColors.textSecondary, fontSize: 13, height: 1.5), maxLines: 2, overflow: TextOverflow.ellipsis)]))])));
  }

  Widget _buildCarList(List cars, bool isLoading, bool isPromotedSection, {ScrollController? controller, bool isFetchingMore = false, bool isTopRatedSection = false}) {
    if (isLoading) return const SizedBox(height: 395, child: Center(child: CircularProgressIndicator(color: AppColors.primary)));
    if (cars.isEmpty) return SizedBox(height: 200, child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.directions_car_filled_outlined, size: 64, color: AppColors.textHint.withOpacity(0.3)), const SizedBox(height: 16), Text(AppLang.tr(context, 'no_cars_to_show') ?? "No cars to show", style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textHint, fontSize: 16))])));
    return SizedBox(height: 395, child: ListView.builder(controller: controller, scrollDirection: Axis.horizontal, physics: const BouncingScrollPhysics(), clipBehavior: Clip.none, itemCount: cars.length + (isFetchingMore && controller != null ? 1 : 0), itemBuilder: (context, index) {
      if (index == cars.length) return const Padding(padding: EdgeInsets.symmetric(horizontal: 20.0), child: Center(child: CircularProgressIndicator(color: AppColors.primary)));
      final bool isFirstPromotedCard = isPromotedSection && index == 0;
      return CarCard(
        car: cars[index],
        isPromoted: isPromotedSection,
        saveKey: isFirstPromotedCard ? AppTourKeys.cardSaveKey : null,
        compareKey: isFirstPromotedCard ? AppTourKeys.cardCompareKey : null,
      );
    }));
  }

  Widget _buildTopBar(BuildContext context, bool isDark) {
    return Row(children: [
      Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(border: Border.all(color: isDark ? Colors.white10 : AppColors.borderLight), borderRadius: BorderRadius.circular(14)), child: Image.asset('assets/images/logo.png', height: 26, width: 26)),
      const SizedBox(width: 12),
      Expanded(child: LuxuriousShowcase(
        showcaseKey: AppTourKeys.searchKey,
        title: AppLang.tr(context, 'tour_search_title') ?? 'بحث سريع',
        description: AppLang.tr(context, 'tour_search_desc') ?? 'ابحث عن أي سيارة أو قطعة غيار من هنا.',
        child: GestureDetector(
          onTap: () { Navigator.push(context, PageRouteBuilder(pageBuilder: (context, animation, secondaryAnimation) => const SearchScreen(), transitionDuration: Duration.zero, reverseTransitionDuration: Duration.zero)); },
          child: Container(padding: const EdgeInsets.symmetric(horizontal: 16), height: 52, decoration: BoxDecoration(color: isDark ? const Color(0xFF161E27) : Colors.white, border: Border.all(color: isDark ? Colors.white10 : AppColors.borderLight), borderRadius: BorderRadius.circular(24)), child: Row(children: [const Icon(Icons.search, color: AppColors.textHint, size: 22), const SizedBox(width: 8), Text(AppLang.tr(context, 'search_cars') ?? "Search", style: const TextStyle(color: AppColors.textHint, fontSize: 15))])),
        ),
      )),
      const SizedBox(width: 12),
      LuxuriousShowcase(
        showcaseKey: AppTourKeys.filterKey,
        title: AppLang.tr(context, 'tour_filter_title') ?? 'فلتر النتائج',
        description: AppLang.tr(context, 'tour_filter_desc') ?? 'فلتر النتائج براحتك عشان توصل للي بتدور عليه.',
        child: GestureDetector(
          onTap: () { showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (context) => const FiltersBottomSheet()); },
          child: Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.tune, color: Colors.white, size: 24)),
        ),
      ),
    ]);
  }

  Widget _buildQuickActions(BuildContext context, bool isDark) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      _buildActionCard(
        isDark: isDark,
        title: AppLang.tr(context, 'saved_cars') ?? "Saved Cars",
        icon: Icons.favorite,
        iconColor: Colors.red.shade400,
        showcaseKey: AppTourKeys.savedItemsKey,
        showcaseTitle: AppLang.tr(context, 'tour_saved_title') ?? 'السيارات المحفوظة',
        showcaseDesc: AppLang.tr(context, 'tour_saved_desc') ?? 'هتلاقي هنا كل السيارات اللي حفظتها عشان ترجع ليها بسهولة.',
        onTap: () { if (CacheHelper.getData(key: 'uid') == null) { _showGuestDialog(context, AppLang.tr(context, 'view_saved_cars') ?? "عرض المحفوظات"); return; } Navigator.push(context, MaterialPageRoute(builder: (context) => const SavedCarsScreen())); },
      ),
      _buildActionCard(
        isDark: isDark,
        title: AppLang.tr(context, 'saved_parts') ?? "Saved Parts",
        icon: Icons.build_outlined,
        iconColor: AppColors.primary,
        showcaseKey: AppTourKeys.savedPartsKey,
        showcaseTitle: AppLang.tr(context, 'tour_saved_parts_title') ?? 'قطع الغيار المحفوظة',
        showcaseDesc: AppLang.tr(context, 'tour_saved_parts_desc') ?? 'هنا بتلاقي قطع الغيار اللي احتفظت بيها.',
        onTap: () { if (CacheHelper.getData(key: 'uid') == null) { _showGuestDialog(context, AppLang.tr(context, 'view_saved_parts') ?? "عرض المحفوظات"); return; } Navigator.push(context, MaterialPageRoute(builder: (context) => const SavedPartsScreen())); },
      ),
      _buildActionCard(
        isDark: isDark,
        title: AppLang.tr(context, 'find_nearby') ?? "Nearby",
        icon: Icons.location_on_outlined,
        iconColor: const Color(0xFFE57373),
        showcaseKey: AppTourKeys.nearbyKey,
        showcaseTitle: AppLang.tr(context, 'tour_nearby_title') ?? 'الأماكن القريبة',
        showcaseDesc: AppLang.tr(context, 'tour_nearby_desc') ?? 'لاقي أقرب مراكز الصيانة والمعارض من مكانك.',
        onTap: () { Navigator.push(context, MaterialPageRoute(builder: (context) => const NearbyLocationsScreen())); },
      ),
    ]);
  }

  Widget _buildActionCard({required bool isDark, required String title, required IconData icon, required Color iconColor, required VoidCallback onTap, GlobalKey? showcaseKey, String? showcaseTitle, String? showcaseDesc}) {
    Widget card = GestureDetector(onTap: onTap, child: Container(margin: const EdgeInsets.symmetric(horizontal: 6), padding: const EdgeInsets.symmetric(vertical: 18), decoration: BoxDecoration(color: isDark ? const Color(0xFF161E27) : Colors.white, border: Border.all(color: isDark ? Colors.white10 : AppColors.borderLight), borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.02), blurRadius: 6, offset: const Offset(0, 3))]), child: Column(children: [Icon(icon, color: iconColor, size: 30), const SizedBox(height: 10), Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87), textAlign: TextAlign.center)])));

    if (showcaseKey != null) {
      return Expanded(child: LuxuriousShowcase(showcaseKey: showcaseKey, title: showcaseTitle ?? '', description: showcaseDesc ?? '', child: card));
    }
    return Expanded(child: card);
  }
}