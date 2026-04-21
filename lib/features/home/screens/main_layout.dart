import 'package:flutter/material.dart';
import 'package:showcaseview/showcaseview.dart';
import '../../../core/local_storage/cache_helper.dart';
import '../../../core/theme/colors.dart';
import '../../../core/localization/app_lang.dart';
import 'home_screen.dart';
import '../widgets/ai_chat_bottom_sheet.dart';
import '../../compare/screens/compare_screen.dart';
import '../../parts/screens/parts_screen.dart';
import '../../my_car/screens/my_car_screen.dart';
import '../../profile/screens/profile_screen.dart';

class AppTourKeys {
  static final GlobalKey searchKey      = GlobalKey();
  static final GlobalKey filterKey      = GlobalKey();
  static final GlobalKey savedItemsKey  = GlobalKey();
  static final GlobalKey savedPartsKey  = GlobalKey();
  static final GlobalKey nearbyKey      = GlobalKey();
  static final GlobalKey cardSaveKey    = GlobalKey();
  static final GlobalKey cardCompareKey = GlobalKey();
  static final GlobalKey addAdKey       = GlobalKey();
  static final GlobalKey aiKey          = GlobalKey();
  static final GlobalKey compareNavKey  = GlobalKey();
  static final GlobalKey partsNavKey    = GlobalKey();
  static final GlobalKey myCarNavKey    = GlobalKey();
  static final GlobalKey profileNavKey  = GlobalKey();
}

class LuxuriousShowcase extends StatelessWidget {
  final GlobalKey showcaseKey;
  final String title;
  final String description;
  final Widget child;

  const LuxuriousShowcase({
    super.key,
    required this.showcaseKey,
    required this.title,
    required this.description,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Showcase(
      key: showcaseKey,
      title: title,
      description: description,
      tooltipBackgroundColor: isDark ? const Color(0xFF161E27) : const Color(0xFF0F1722),
      textColor: Colors.white,
      titleAlignment: Alignment.center,
      descTextStyle: const TextStyle(fontSize: 12, color: Colors.white70, height: 1.4),
      titleTextStyle: const TextStyle(fontSize: 15, color: Color(0xFF4DA8DA), fontWeight: FontWeight.bold),
      targetShapeBorder: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
      tooltipBorderRadius: BorderRadius.circular(12),
      tooltipPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      disableMovingAnimation: true,
      child: child,
    );
  }
}

class MainLayout extends StatelessWidget {
  const MainLayout({super.key});

  @override
  Widget build(BuildContext context) {
    return ShowCaseWidget(
      builder: (context) => const MainLayoutContent(),
      blurValue: 1.5,
      disableBarrierInteraction: false,
    );
  }
}

class MainLayoutContent extends StatefulWidget {
  const MainLayoutContent({super.key});

  @override
  State<MainLayoutContent> createState() => _MainLayoutContentState();
}

class _MainLayoutContentState extends State<MainLayoutContent> {
  int _currentIndex = 0;

  late PageController _pageController;

  bool _isTourBlocking = false;
  double? _aiButtonX;
  double? _aiButtonY;
  bool _isAiHidden = false;
  bool _isHiddenLeft = false;

  final List<GlobalKey> _screenKeys = [
    GlobalKey(),
    GlobalKey(),
    GlobalKey(),
    GlobalKey(),
    GlobalKey(),
  ];

  // 🔥 غلفنا الصفحات بـ KeepPageAlive عشان تحفظ مكان السكرول والداتا بتاعتها
  List<Widget> get _screens => [
    KeepPageAlive(key: ValueKey(_screenKeys[0]), child: HomeScreen(key: _screenKeys[0])),
    KeepPageAlive(key: ValueKey(_screenKeys[1]), child: CompareScreen(key: _screenKeys[1])),
    KeepPageAlive(key: ValueKey(_screenKeys[2]), child: PartsScreen(key: _screenKeys[2])),
    KeepPageAlive(key: ValueKey(_screenKeys[3]), child: MyCarScreen(key: _screenKeys[3])),
    KeepPageAlive(key: ValueKey(_screenKeys[4]), child: ProfileScreen(key: _screenKeys[4])),
  ];

  @override
  void initState() {
    super.initState();

    _pageController = PageController(initialPage: 0);

    bool isFirst = CacheHelper.getData(key: 'gearup_tour_v68') ?? true;
    if (isFirst) _isTourBlocking = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndStartTour();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _checkAndStartTour() {
    bool isFirstTime = CacheHelper.getData(key: 'gearup_tour_v68') ?? true;
    if (!isFirstTime) return;

    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;

      ShowCaseWidget.of(context).startShowCase([
        AppTourKeys.searchKey,
        AppTourKeys.filterKey,
        AppTourKeys.savedItemsKey,
        AppTourKeys.savedPartsKey,
        AppTourKeys.nearbyKey,
        AppTourKeys.cardSaveKey,
        AppTourKeys.cardCompareKey,
        AppTourKeys.addAdKey,
        AppTourKeys.compareNavKey,
        AppTourKeys.partsNavKey,
        AppTourKeys.myCarNavKey,
        AppTourKeys.profileNavKey,
        AppTourKeys.aiKey,
      ]);

      setState(() => _isTourBlocking = false);
      CacheHelper.saveData(key: 'gearup_tour_v68', value: false);
    });
  }

  void _onNavItemTap(int index) {
    if (_currentIndex == index) {
      // 🔥 حماية V2: تم إلغاء تدمير الشاشة (GlobalKey Reset) لمنع رمشة الـ UI وضياع السكرول 🔥
      return;
    } else {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color screenBgColor = isDark ? const Color(0xFF0A0F14) : const Color(0xFFF4F7FA);
    final Color navBarColor = isDark ? const Color(0xFF161E27) : Colors.white;

    if (_aiButtonX == null || _aiButtonY == null) {
      final size = MediaQuery.of(context).size;
      _aiButtonX = size.width - 80;
      _aiButtonY = size.height - 180;
    }

    return AbsorbPointer(
      absorbing: _isTourBlocking,
      child: Scaffold(
        backgroundColor: screenBgColor,
        body: Stack(
          children: [
            SafeArea(
              child: PageView(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                physics: const BouncingScrollPhysics(),
                children: _screens,
              ),
            ),
            if (_isAiHidden) _buildHiddenAiArrow(isDark) else _buildDraggableAiButton(isDark),
          ],
        ),
        bottomNavigationBar: Container(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
          decoration: BoxDecoration(
            color: navBarColor,
            border: Border(top: BorderSide(color: isDark ? Colors.white10 : Colors.black12, width: 1)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.4 : 0.05), blurRadius: 10, offset: const Offset(0, -4))],
          ),
          child: SizedBox(
            height: 65,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.home_outlined, Icons.home, AppLang.tr(context, 'nav_home') ?? 'الرئيسية', null, null, null),
                _buildNavItem(1, Icons.compare_arrows, Icons.compare_arrows, AppLang.tr(context, 'nav_compare') ?? 'مقارنة', AppTourKeys.compareNavKey, AppLang.tr(context, 'tour_compare_title') ?? 'صفحة المقارنة', AppLang.tr(context, 'tour_compare_desc') ?? 'قارن بين سيارتين لمعرفة الأفضل.'),
                _buildNavItem(2, Icons.build_outlined, Icons.build, AppLang.tr(context, 'nav_parts') ?? 'قطع غيار', AppTourKeys.partsNavKey, AppLang.tr(context, 'tour_parts_title') ?? 'قطع الغيار', AppLang.tr(context, 'tour_parts_desc') ?? 'ابحث عن قطع غيار لسيارتك.'),
                _buildNavItem(3, Icons.directions_car_outlined, Icons.directions_car, AppLang.tr(context, 'nav_my_car') ?? 'سيارتي', AppTourKeys.myCarNavKey, AppLang.tr(context, 'tour_my_car_title') ?? 'جراجك الرقمي', AppLang.tr(context, 'tour_my_car_desc') ?? 'تابع صيانات ومصاريف سيارتك.'),
                _buildNavItem(4, Icons.person_outline, Icons.person, AppLang.tr(context, 'nav_profile') ?? 'حسابي', AppTourKeys.profileNavKey, AppLang.tr(context, 'tour_profile_title') ?? 'حسابك الشخصي', AppLang.tr(context, 'tour_profile_desc') ?? 'كل إعداداتك وإعلاناتك هنا.'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, IconData activeIcon, String label, GlobalKey? showcaseKey, String? title, String? desc) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = _currentIndex == index;
    final color = isSelected ? AppColors.primary : (isDark ? Colors.white54 : AppColors.textHint);

    Widget item = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _onNavItemTap(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(isSelected ? activeIcon : icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: color, fontSize: isSelected ? 12 : 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500)),
        ],
      ),
    );

    if (showcaseKey != null && title != null && desc != null) {
      return Expanded(child: LuxuriousShowcase(showcaseKey: showcaseKey, title: title, description: desc, child: item));
    } else {
      return Expanded(child: item);
    }
  }

  Widget _buildDraggableAiButton(bool isDark) {
    return Positioned(
      left: _aiButtonX,
      top: _aiButtonY,
      child: LuxuriousShowcase(
        showcaseKey: AppTourKeys.aiKey,
        title: AppLang.tr(context, 'tour_ai_title') ?? 'المساعد الذكي',
        description: AppLang.tr(context, 'tour_ai_desc') ?? 'اسأل الذكاء الاصطناعي عن أي سيارة وسيجيبك فوراً.',
        child: GestureDetector(
          onPanUpdate: (details) {
            setState(() {
              final size = MediaQuery.of(context).size;
              _aiButtonX = _aiButtonX! + details.delta.dx;
              _aiButtonY = (_aiButtonY! + details.delta.dy).clamp(0.0, size.height - 160);
              if (_aiButtonX! >= size.width - 60) { _isAiHidden = true; _isHiddenLeft = false; }
              else if (_aiButtonX! <= 10) { _isAiHidden = true; _isHiddenLeft = true; }
            });
          },
          child: Container(
            decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(isDark ? 0.4 : 0.3), blurRadius: 15, offset: const Offset(0, 6))]),
            child: FloatingActionButton(
              onPressed: () { showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (context) => const AiChatBottomSheet()); },
              backgroundColor: AppColors.primary,
              elevation: 0,
              shape: const CircleBorder(),
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 28),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHiddenAiArrow(bool isDark) {
    return Positioned(
      left: _isHiddenLeft ? 0 : null,
      right: _isHiddenLeft ? null : 0,
      top: _aiButtonY,
      child: GestureDetector(
        onTap: () { setState(() { _isAiHidden = false; _aiButtonX = _isHiddenLeft ? 30.0 : MediaQuery.of(context).size.width - 90; }); },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: _isHiddenLeft ? const BorderRadius.only(topRight: Radius.circular(16), bottomRight: Radius.circular(16)) : const BorderRadius.only(topLeft: Radius.circular(16), bottomLeft: Radius.circular(16)),
            boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(isDark ? 0.4 : 0.3), blurRadius: 8, offset: Offset(_isHiddenLeft ? 2 : -2, 2))],
          ),
          child: Icon(_isHiddenLeft ? Icons.arrow_forward_ios : Icons.arrow_back_ios_new, color: Colors.white, size: 16),
        ),
      ),
    );
  }
}

// 🔥 الوديجت السحرية اللي بتحافظ على حالة الصفحة ومكان السكرول 🔥
class KeepPageAlive extends StatefulWidget {
  final Widget child;
  const KeepPageAlive({super.key, required this.child});

  @override
  State<KeepPageAlive> createState() => _KeepPageAliveState();
}

class _KeepPageAliveState extends State<KeepPageAlive> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true; // ده اللي بيمنع الفلاتر إنه يقتل الصفحة

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}