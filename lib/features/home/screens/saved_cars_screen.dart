import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/colors.dart';
import '../../../core/localization/app_lang.dart';
import '../../../core/local_storage/cache_helper.dart';
import '../widgets/car_card.dart';
import '../../marketplace/cubit/market_cubit.dart';
import '../../marketplace/cubit/market_state.dart';
import '../../auth/screens/login_screen.dart';

class SavedCarsScreen extends StatefulWidget {
  const SavedCarsScreen({super.key});

  @override
  State<SavedCarsScreen> createState() => _SavedCarsScreenState();
}

class _SavedCarsScreenState extends State<SavedCarsScreen> {
  @override
  void initState() {
    super.initState();
    // 🔥 حماية V2: التأكد من إن الـ Widget اتبنى الأول، وحماية من "الزائر الشبح" 🔥
    Future.microtask(() {
      if (mounted) {
        String? uid = CacheHelper.getData(key: 'uid');
        bool isGuest = uid == null || uid.startsWith('guest_');

        if (!isGuest) {
          context.read<MarketCubit>().getSavedCars();
        }
      }
    });
  }

  // 🔥 الواجهة المخصصة للزوار (لو فتح الشاشة غصب) 🔥
  Widget _buildGuestView(BuildContext context, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_outline_rounded, size: 80, color: AppColors.textHint.withOpacity(0.3)),
          const SizedBox(height: 20),
          Text(
            AppLang.tr(context, 'login_required') ?? "تسجيل الدخول مطلوب",
            style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87, fontSize: 20),
          ),
          const SizedBox(height: 12),
          Text(
            AppLang.tr(context, 'login_to_view_saved_cars') ?? "قم بتسجيل الدخول لعرض سياراتك المحفوظة",
            style: TextStyle(color: isDark ? Colors.white54 : AppColors.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginScreen())),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            ),
            child: Text(
                AppLang.tr(context, 'login') ?? "تسجيل الدخول",
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color screenBgColor = isDark ? const Color(0xFF0A0F14) : const Color(0xFFE3F2FD);

    // 🔥 التحقق الذكي من حالة المستخدم 🔥
    String? uid = CacheHelper.getData(key: 'uid');
    bool isGuest = uid == null || uid.startsWith('guest_');

    return Scaffold(
      backgroundColor: screenBgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border.all(color: isDark ? Colors.white10 : AppColors.primary.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(12),
              color: isDark ? const Color(0xFF161E27) : Colors.white.withOpacity(0.7),
            ),
            child: Icon(Icons.arrow_back, size: 24, color: isDark ? Colors.white : AppColors.primary),
          ),
        ),
        title: Text(
          AppLang.tr(context, 'saved_cars') ?? 'السيارات المحفوظة',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w900,
            fontSize: 22,
          ),
        ),
      ),
      body: isGuest
          ? _buildGuestView(context, isDark)
          : BlocBuilder<MarketCubit, MarketState>(
        builder: (context, state) {
          final cubit = context.read<MarketCubit>();
          final savedCars = cubit.savedCarsList;

          if (state is SavedCarsLoading && savedCars.isEmpty) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }

          if (savedCars.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.favorite_border_rounded, size: 80, color: AppColors.textHint.withOpacity(0.3)),
                  const SizedBox(height: 20),
                  Text(
                    AppLang.tr(context, 'no_saved_cars') ?? "لم تقم بحفظ أي سيارات بعد",
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textHint, fontSize: 18),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    AppLang.tr(context, 'favorite_cars_appear_here') ?? "سياراتك المفضلة ستظهر هنا",
                    style: TextStyle(color: isDark ? Colors.white54 : AppColors.textSecondary, fontSize: 14),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async => await cubit.getSavedCars(),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: savedCars.length,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                return CarCard(car: savedCars[index], isPromoted: false);
              },
            ),
          );
        },
      ),
    );
  }
}