import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '../../../core/localization/app_lang.dart';
import 'home_screen.dart';
import '../widgets/ai_chat_bottom_sheet.dart';
import '../../compare/screens/compare_screen.dart';
import '../../parts/screens/parts_screen.dart';
import '../../my_car/screens/my_car_screen.dart';
import '../../profile/screens/profile_screen.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;
  // 🔥 ضفنا الكنترولر المسؤول عن السويب 🔥
  late PageController _pageController;

  double? _aiButtonX;
  double? _aiButtonY;
  bool _isAiHidden = false;
  bool _isHiddenLeft = false;

  final List<Widget> _screens = [
    const HomeScreen(),
    const CompareScreen(),
    const PartsScreen(),
    const MyCarScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
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

    return Scaffold(
      backgroundColor: screenBgColor,
      body: Stack(
        children: [
          // 🔥 استبدلنا IndexedStack بـ PageView للسويب الناعم 🔥
          SafeArea(
            child: PageView(
              controller: _pageController,
              physics: const BouncingScrollPhysics(), // سويب ناعم ومريح
              onPageChanged: (index) {
                // لما اليوزر يسحب، البار اللي تحت بيتحدث
                setState(() {
                  _currentIndex = index;
                });
              },
              children: _screens,
            ),
          ),

          if (_isAiHidden)
            _buildHiddenAiArrow(isDark)
          else
            _buildDraggableAiButton(isDark),
        ],
      ),

      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: navBarColor,
          border: Border(
            top: BorderSide(color: isDark ? Colors.white10 : Colors.black12, width: 1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.4 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
            // 🔥 لما اليوزر يدوس على زرار تحت، الشاشة بتعمل أنيميشن لذيذ 🔥
            _pageController.animateToPage(
              index,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          },
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          backgroundColor: Colors.transparent,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: isDark ? Colors.white54 : AppColors.textHint,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
          items: [
            BottomNavigationBarItem(icon: const Icon(Icons.home_outlined), activeIcon: const Icon(Icons.home), label: AppLang.tr(context, 'home')),
            BottomNavigationBarItem(icon: const Icon(Icons.compare_arrows), label: AppLang.tr(context, 'compare')),
            BottomNavigationBarItem(icon: const Icon(Icons.build_outlined), activeIcon: const Icon(Icons.build), label: AppLang.tr(context, 'parts')),
            BottomNavigationBarItem(icon: const Icon(Icons.directions_car_outlined), activeIcon: const Icon(Icons.directions_car), label: AppLang.tr(context, 'my_car')),
            BottomNavigationBarItem(icon: const Icon(Icons.person_outline), activeIcon: const Icon(Icons.person), label: AppLang.tr(context, 'profile')),
          ],
        ),
      ),
    );
  }

  // --- دوال مساعدة لزرار الذكاء الاصطناعي ---
  Widget _buildDraggableAiButton(bool isDark) {
    return Positioned(
      left: _aiButtonX,
      top: _aiButtonY,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            final size = MediaQuery.of(context).size;
            _aiButtonX = _aiButtonX! + details.delta.dx;
            _aiButtonY = (_aiButtonY! + details.delta.dy).clamp(0.0, size.height - 160);

            if (_aiButtonX! >= size.width - 60) {
              _isAiHidden = true;
              _isHiddenLeft = false;
            }
            else if (_aiButtonX! <= 10) {
              _isAiHidden = true;
              _isHiddenLeft = true;
            }
          });
        },
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(isDark ? 0.4 : 0.3),
                blurRadius: 15,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: FloatingActionButton(
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => const AiChatBottomSheet(),
              );
            },
            backgroundColor: AppColors.primary,
            elevation: 0,
            shape: const CircleBorder(),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 28),
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
        onTap: () {
          setState(() {
            _isAiHidden = false;
            _aiButtonX = _isHiddenLeft ? 30.0 : MediaQuery.of(context).size.width - 90;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: _isHiddenLeft
                ? const BorderRadius.only(topRight: Radius.circular(16), bottomRight: Radius.circular(16))
                : const BorderRadius.only(topLeft: Radius.circular(16), bottomLeft: Radius.circular(16)),
            boxShadow: [
              BoxShadow(
                  color: AppColors.primary.withOpacity(isDark ? 0.4 : 0.3),
                  blurRadius: 8,
                  offset: Offset(_isHiddenLeft ? 2 : -2, 2)
              ),
            ],
          ),
          child: Icon(
              _isHiddenLeft ? Icons.arrow_forward_ios : Icons.arrow_back_ios_new,
              color: Colors.white,
              size: 16
          ),
        ),
      ),
    );
  }
}