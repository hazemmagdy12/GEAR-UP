import 'package:flutter/material.dart';
import 'package:showcaseview/showcaseview.dart';
import '../../../core/theme/colors.dart';

// =================================================================
// 🔥 كل الـ Keys بتاعت الجولة في مكان واحد 🔥
// =================================================================
class AppTourKeys {
  static final searchKey      = GlobalKey();
  static final filterKey      = GlobalKey();
  static final savedItemsKey  = GlobalKey();
  static final savedPartsKey  = GlobalKey();
  static final nearbyKey      = GlobalKey();
  static final compareNavKey  = GlobalKey();
  static final partsNavKey    = GlobalKey();
  static final myCarNavKey    = GlobalKey();
  static final aiKey          = GlobalKey();
  static final quickMenuKey   = GlobalKey();
}

// =================================================================
// 🔥 LuxuriousShowcase - بيلف أي widget ويضيف له tooltip الجولة 🔥
// =================================================================
class LuxuriousShowcase extends StatelessWidget {
  final GlobalKey showcaseKey;
  final String? title;
  final String? description;
  final Widget child;

  const LuxuriousShowcase({
    super.key,
    required this.showcaseKey,
    required this.child,
    this.title,
    this.description,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Showcase(
      key: showcaseKey,
      title: title ?? '',
      description: description ?? '',
      tooltipBackgroundColor: isDark ? const Color(0xFF161E27) : Colors.white,
      textColor: isDark ? Colors.white : Colors.black87,
      titleTextStyle: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w900,
        color: AppColors.primary,
      ),
      descTextStyle: TextStyle(
        fontSize: 13,
        color: isDark ? Colors.white70 : Colors.black54,
        height: 1.5,
      ),
      child: child,
    );
  }
}