import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/colors.dart';
import '../../../core/localization/app_lang.dart';
import '../../../core/local_storage/cache_helper.dart';
import '../../marketplace/cubit/market_cubit.dart';
import '../../marketplace/cubit/market_state.dart';
import 'reminders_screen.dart';
import '../../nearby/screens/nearby_locations_screen.dart';
import 'edit_my_car_screen.dart';
import '../../auth/screens/login_screen.dart';

class MyCarScreen extends StatefulWidget {
  const MyCarScreen({super.key});

  @override
  State<MyCarScreen> createState() => _MyCarScreenState();
}

class _MyCarScreenState extends State<MyCarScreen> {
  bool get isLoggedIn => CacheHelper.getData(key: 'uid') != null && !CacheHelper.getData(key: 'uid').toString().startsWith('guest_');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (isLoggedIn) {
        context.read<MarketCubit>().getMyCarData();
      }
    });
  }

  Map<String, dynamic> _calculateReminderStatus(String targetDateStr) {
    try {
      String cleanDate = targetDateStr.split(' ')[0];
      DateTime target = DateTime.parse(cleanDate);
      DateTime now = DateTime.now();
      DateTime today = DateTime(now.year, now.month, now.day);

      int diff = target.difference(today).inDays;

      double totalDays = 30.0;
      double passedDays = totalDays - diff;
      double progress = (passedDays / totalDays).clamp(0.05, 1.0);

      Color statusColor;

      if (diff < 0) {
        return {'text': '${diff.abs()} ${AppLang.tr(context, 'days_overdue') ?? 'أيام متأخرة'}', 'color': Colors.redAccent, 'progress': 1.0};
      } else if (diff == 0) {
        return {'text': AppLang.tr(context, 'today') ?? 'اليوم', 'color': Colors.redAccent, 'progress': 1.0};
      } else if (progress >= 0.90) {
        statusColor = Colors.redAccent;
      } else if (progress >= 0.60) {
        statusColor = Colors.orangeAccent;
      } else {
        statusColor = AppColors.primary;
      }

      return {
        'text': '$diff ${AppLang.tr(context, 'days_left') ?? 'أيام متبقية'}',
        'color': statusColor,
        'progress': progress,
      };
    } catch (e) {
      return {'text': 'Date error', 'color': Colors.grey, 'progress': 0.0};
    }
  }

  void _showGuestDialog(BuildContext context, String featureName) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF161E27) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            const Icon(Icons.lock_outline_rounded, size: 50, color: AppColors.primary),
            const SizedBox(height: 12),
            Text(AppLang.tr(context, 'login_required') ?? "تسجيل الدخول مطلوب", style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Text(
          "${AppLang.tr(context, 'guest_sorry_prefix') ?? 'عفواً، لا يمكنك'} $featureName ${AppLang.tr(context, 'guest_sorry_suffix') ?? 'كزائر. قم بتسجيل الدخول لتستمتع بجميع مميزات GEAR UP! 🚗✨'}",
          textAlign: TextAlign.center,
          style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 14, height: 1.5),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLang.tr(context, 'cancel_btn') ?? "إلغاء", style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(AppLang.tr(context, 'login') ?? "تسجيل الدخول", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color screenBgColor = isDark ? const Color(0xFF0A0F14) : const Color(0xFFF4F7FA);

    return Scaffold(
      backgroundColor: screenBgColor,
      body: SafeArea(
        child: isLoggedIn ? _buildLoggedInState(isDark) : _buildUnloggedState(isDark),
      ),
    );
  }

  Widget _buildUnloggedState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161E27) : Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.05), blurRadius: 15, offset: const Offset(0, 8)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [AppColors.primary.withOpacity(0.2), AppColors.primary.withOpacity(0.05)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_outline, size: 48, color: AppColors.primary),
              ),
              const SizedBox(height: 24),
              Text(AppLang.tr(context, 'my_car') ?? 'جراجي', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87, letterSpacing: 0.5)),
              const SizedBox(height: 12),
              Text(AppLang.tr(context, 'login_signup_msg') ?? 'قم بتسجيل الدخول لإدارة سيارتك ومواعيد الصيانة', textAlign: TextAlign.center, style: TextStyle(color: isDark ? Colors.white54 : AppColors.textSecondary, height: 1.6, fontSize: 14)),
              const SizedBox(height: 36),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
                  },
                  icon: const Icon(Icons.login, color: Colors.white, size: 20),
                  label: Text(AppLang.tr(context, 'login') ?? 'تسجيل الدخول', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoggedInState(bool isDark) {
    return BlocBuilder<MarketCubit, MarketState>(
      builder: (context, state) {
        final cubit = context.read<MarketCubit>();

        if (cubit.isLoadingMyCar) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        }

        List<Map<String, dynamic>> myCarsList = cubit.myCars;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 20.0, left: 20.0, right: 20.0, bottom: 10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppLang.tr(context, 'my_car') ?? 'سيارتي', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87, letterSpacing: 0.5)),
                  const SizedBox(height: 6),
                  Text(AppLang.tr(context, 'manage_vehicles') ?? 'إدارة سياراتك ومواعيد الصيانة بدقة وسهولة', style: TextStyle(color: isDark ? Colors.white60 : AppColors.textSecondary, fontSize: 14)),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: _buildPremiumSectionHeader(
                title: AppLang.tr(context, 'my_car') ?? 'سيارتي',
                isDark: isDark,
                actionLabel: AppLang.tr(context, 'add_your_cars') ?? 'إضافة',
                actionIcon: Icons.add_circle_outline,
                onActionTap: () {
                  if (!isLoggedIn) {
                    _showGuestDialog(context, AppLang.tr(context, 'add_car_to_garage') ?? "إضافة سيارة للجراج");
                    return;
                  }
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const EditMyCarScreen(carData: null)));
                },
              ),
            ),
            const SizedBox(height: 16),

            if (myCarsList.isEmpty)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: _buildEmptyState(isDark, AppLang.tr(context, 'no_cars_added_yet') ?? "لم تقم بإضافة سيارات بعد"),
                ),
              )
            else
              Expanded(
                child: PageView.builder(
                  physics: const BouncingScrollPhysics(),
                  itemCount: myCarsList.length,
                  itemBuilder: (context, index) {
                    final car = myCarsList[index];
                    final String carId = car['id'] ?? '';

                    String make = car['make'] ?? "Not Set";
                    String model = car['model'] ?? "Not Set";
                    String year = car['year'] ?? "N/A";
                    String mileage = car['mileage'] ?? "0";
                    if (mileage != "0" && !mileage.contains("km")) mileage += " km";
                    List<dynamic> images = car['images'] ?? (car['imageUrl'] != null ? [car['imageUrl']] : []);

                    // 🔥 تحسين الأداء: الفلترة بتتعمل هنا مرة واحدة بسرعة 🔥
                    final allCarReminders = cubit.myReminders.where((r) => r['carId'] == carId).toList();
                    final carMaintenance = cubit.myMaintenanceHistory.where((m) => m['carId'] == carId).toList();

                    final upcomingReminders = allCarReminders.where((r) {
                      try {
                        DateTime target = DateTime.parse(r['date'].split(' ')[0]);
                        DateTime now = DateTime.now();
                        DateTime today = DateTime(now.year, now.month, now.day);
                        return target.isAfter(today);
                      } catch(e) { return false; }
                    }).toList();

                    return SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20.0),
                            child: _buildMyVehicleCard(isDark, make, model, year, mileage, images, carId),
                          ),

                          _buildPageIndicator(index, myCarsList.length, isDark),

                          const SizedBox(height: 16),

                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20.0),
                            child: _buildPremiumSectionHeader(
                                title: AppLang.tr(context, 'upcoming_reminders') ?? 'التذكيرات القادمة',
                                actionLabel: AppLang.tr(context, 'view_all') ?? 'عرض الكل',
                                actionIcon: Icons.list_alt_rounded,
                                isDark: isDark,
                                onActionTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => RemindersScreen(carId: carId)))
                            ),
                          ),
                          const SizedBox(height: 16),

                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20.0),
                            child: upcomingReminders.isEmpty
                                ? _buildEmptyState(isDark, AppLang.tr(context, 'no_upcoming_reminders') ?? "لا توجد تذكيرات قادمة حالياً")
                                : Column(
                              children: upcomingReminders.map((reminder) {
                                final status = _calculateReminderStatus(reminder['date']);
                                List<Color> progressGradient;
                                if (status['color'] == Colors.redAccent) {
                                  progressGradient = [const Color(0xFFE53935), const Color(0xFFFF8A80)];
                                } else if (status['color'] == Colors.orangeAccent) {
                                  progressGradient = [const Color(0xFFF57C00), const Color(0xFFFFCC80)];
                                } else {
                                  progressGradient = [AppColors.primary, const Color(0xFF4FC3F7)];
                                }

                                return _buildReminderCard(
                                  title: reminder['task'],
                                  date: reminder['date'],
                                  daysLeft: status['text'],
                                  progress: status['progress'],
                                  progressGradient: progressGradient,
                                  glowColor: status['color'],
                                  isDark: isDark,
                                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => RemindersScreen(carId: carId))),
                                );
                              }).toList(),
                            ),
                          ),

                          const SizedBox(height: 36),

                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20.0),
                            child: _buildPremiumSectionHeader(
                                title: AppLang.tr(context, 'maintenance_history') ?? 'سجل الصيانة',
                                actionLabel: AppLang.tr(context, 'add_record') ?? 'إضافة سجل',
                                actionIcon: Icons.add_chart_rounded,
                                isDark: isDark,
                                onActionTap: () => _showMaintenanceDialog(isEdit: false, isDark: isDark, carId: carId)),
                          ),
                          const SizedBox(height: 16),

                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20.0),
                            child: carMaintenance.isEmpty
                                ? _buildEmptyState(isDark, AppLang.tr(context, 'no_maintenance_records') ?? "لا توجد سجلات صيانة لهذه السيارة")
                                : ListView.builder(
                              // 🔥 تحسين الأداء 2: حل مشكلة الـ Scroll والـ Constraints 🔥
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: carMaintenance.length,
                              itemBuilder: (context, idx) {
                                final record = carMaintenance[idx];
                                return _buildMaintenanceCard(
                                    context: context,
                                    id: record['id'],
                                    title: record['title'],
                                    desc: record['desc'],
                                    date: record['date'],
                                    price: "EGP ${record['cost']}",
                                    isDark: isDark,
                                    onEditTap: () => _showMaintenanceDialog(
                                        isEdit: true,
                                        id: record['id'],
                                        carId: carId,
                                        isDark: isDark,
                                        initialTitle: record['title'],
                                        initialDesc: record['desc'],
                                        initialDate: record['date'],
                                        initialPrice: record['cost']
                                    )
                                );
                              },
                            ),
                          ),

                          const SizedBox(height: 36),

                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20.0),
                            child: _buildServiceButton(context),
                          ),

                          const SizedBox(height: 100),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildPageIndicator(int currentIndex, int total, bool isDark) {
    if (total <= 1) return const SizedBox(height: 20);
    return Padding(
      padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(total, (index) {
          bool isActive = index == currentIndex;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            height: 8,
            width: isActive ? 24 : 8,
            decoration: BoxDecoration(
              color: isActive ? AppColors.primary : (isDark ? Colors.white24 : Colors.black12),
              borderRadius: BorderRadius.circular(4),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark, String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161E27) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12, width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 40, color: AppColors.textHint.withOpacity(0.5)),
          const SizedBox(height: 12),
          Text(message, style: const TextStyle(color: AppColors.textHint, fontWeight: FontWeight.bold, fontSize: 15)),
        ],
      ),
    );
  }

  Widget _buildServiceButton(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const NearbyLocationsScreen())),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [AppColors.primary, Color(0xFF3949AB)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 8))],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle), child: const Icon(Icons.location_on_outlined, color: Colors.white, size: 22)),
            const SizedBox(width: 12),
            Text(AppLang.tr(context, 'service_centers') ?? 'مراكز الصيانة', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.0)),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumSectionHeader({required String title, required bool isDark, required String actionLabel, required IconData actionIcon, required VoidCallback onActionTap}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87, letterSpacing: 0.3)),
        GestureDetector(
          onTap: onActionTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3)
                  )
                ]
            ),
            child: Row(
              children: [
                Icon(actionIcon, size: 16, color: Colors.white),
                const SizedBox(width: 6),
                Text(actionLabel, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMyVehicleCard(bool isDark, String make, String model, String year, String mileage, List<dynamic> images, String? carId) {
    String coverImage = images.isNotEmpty ? images.first.toString() : "";

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => EditMyCarScreen(
          carData: {'id': carId, 'make': make, 'model': model, 'year': year, 'mileage': mileage, 'images': images}
      ))),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF161E27) : Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: isDark ? Colors.white10 : Colors.black12, width: 1),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.4 : 0.05), blurRadius: 20, offset: const Offset(0, 10))],
        ),
        child: Stack(
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () {
                    // 🔥 تصليح لغم عرض الصور بشكل صحيح 🔥
                    if (images.isNotEmpty) {
                      _showCarImageFullScreen(isDark, images);
                    }
                  },
                  child: Container(
                    width: 110,
                    height: 100,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E2834) : AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.05), blurRadius: 8, offset: const Offset(0, 4))],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: coverImage.isNotEmpty
                          ? CachedNetworkImage(imageUrl: coverImage, fit: BoxFit.cover, placeholder: (context, url) => const Center(child: CircularProgressIndicator(strokeWidth: 2)), errorWidget: (context, url, error) => const Icon(Icons.directions_car, size: 50, color: AppColors.textHint))
                          : const Icon(Icons.directions_car, size: 50, color: AppColors.textHint),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(make.toUpperCase(), style: const TextStyle(color: AppColors.textHint, fontSize: 11, letterSpacing: 2.0, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(model, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: isDark ? Colors.white : Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildSpecMini(AppLang.tr(context, 'year') ?? 'Year', year, isDark),
                          _buildSpecMini(AppLang.tr(context, 'mileage') ?? 'Mileage', mileage, isDark),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.05) : AppColors.primary.withOpacity(0.05), shape: BoxShape.circle),
                child: Icon(Icons.edit_rounded, size: 14, color: isDark ? Colors.white70 : AppColors.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpecMini(String label, String value, bool isDark) {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textHint, fontSize: 10, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: isDark ? Colors.white : Colors.black87))
        ]
    );
  }

  Widget _buildReminderCard({
    required String title,
    required String date,
    required String daysLeft,
    required double progress,
    required List<Color> progressGradient,
    required Color glowColor,
    required bool isDark,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF161E27) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: isDark ? Colors.white10 : Colors.black12, width: 1),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.04), blurRadius: 12, offset: const Offset(0, 6))],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [glowColor.withOpacity(0.2), glowColor.withOpacity(0.05)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                      shape: BoxShape.circle,
                      border: Border.all(color: glowColor.withOpacity(0.3)),
                    ),
                    child: Icon(Icons.notifications_active_rounded, color: glowColor, size: 20)
                ),
                const SizedBox(width: 16),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
                          const SizedBox(height: 4),
                          Text("${AppLang.tr(context, 'due_date') ?? 'Due:'} $date", style: TextStyle(color: isDark ? Colors.white60 : AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500))
                        ]
                    )
                ),
                Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(color: glowColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: glowColor.withOpacity(0.2))),
                    child: Text(daysLeft, style: TextStyle(color: glowColor, fontWeight: FontWeight.w900, fontSize: 11))
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildProgressBar(progress, progressGradient, glowColor, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar(double progress, List<Color> gradient, Color glow, bool isDark) {
    return LayoutBuilder(builder: (context, constraints) {
      return Container(
          height: 8,
          width: constraints.maxWidth,
          decoration: BoxDecoration(color: isDark ? const Color(0xFF1E2834) : AppColors.surfaceLight, borderRadius: BorderRadius.circular(10)),
          child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                  width: constraints.maxWidth * progress,
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      gradient: LinearGradient(colors: gradient),
                      boxShadow: [BoxShadow(color: glow.withOpacity(0.5), blurRadius: 10, offset: const Offset(0, 2))]
                  )
              )
          )
      );
    });
  }

  Widget _buildMaintenanceCard({
    required BuildContext context,
    required String id,
    required String title,
    required String desc,
    required String date,
    required String price,
    required bool isDark,
    required VoidCallback onEditTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161E27) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12, width: 1),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.04), blurRadius: 12, offset: const Offset(0, 6))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.05) : AppColors.surfaceLight, shape: BoxShape.circle),
              child: const Icon(Icons.build_circle_outlined, color: AppColors.textHint, size: 22)
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(title, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
                        Text(price, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w900, fontSize: 15))
                      ]
                  ),
                  const SizedBox(height: 8),
                  Text(desc, style: TextStyle(color: isDark ? Colors.white60 : AppColors.textSecondary, fontSize: 13, height: 1.5, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.textHint),
                            const SizedBox(width: 6),
                            Text(date, style: const TextStyle(color: AppColors.textHint, fontSize: 12, fontWeight: FontWeight.bold))
                          ]
                      ),
                      Row(
                        children: [
                          _buildSmallActionButton(icon: Icons.edit_outlined, isDark: isDark, onTap: onEditTap),
                          const SizedBox(width: 8),
                          _buildSmallActionButton(icon: Icons.delete_outline, isDark: isDark, isDestructive: true, onTap: () => _showDeleteMaintenanceConfirmation(context, isDark, id)),
                        ],
                      )
                    ],
                  ),
                ]
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallActionButton({required IconData icon, required bool isDark, required VoidCallback onTap, bool isDestructive = false}) {
    Color iconColor = isDestructive ? Colors.redAccent : (isDark ? Colors.white70 : AppColors.textSecondary);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          border: Border.all(color: isDark ? Colors.white10 : AppColors.borderLight),
          shape: BoxShape.circle,
          color: isDark ? const Color(0xFF1E2834) : Colors.transparent,
        ),
        child: Icon(icon, size: 16, color: iconColor),
      ),
    );
  }

  void _showDeleteMaintenanceConfirmation(BuildContext context, bool isDark, String recordId) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF161E27) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(AppLang.tr(context, 'delete_record') ?? 'حذف السجل', style: TextStyle(fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)),
          content: Text(AppLang.tr(context, 'delete_confirm_msg') ?? 'هل أنت متأكد من حذف هذا السجل؟', style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontWeight: FontWeight.w500)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(AppLang.tr(context, 'cancel_btn') ?? 'إلغاء', style: const TextStyle(color: AppColors.textHint, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              onPressed: () {
                context.read<MarketCubit>().deleteMaintenanceRecord(recordId);
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(AppLang.tr(context, 'record_deleted') ?? 'تم الحذف'),
                    backgroundColor: Colors.redAccent,
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: Text(AppLang.tr(context, 'delete_btn') ?? 'حذف', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  // 🔥 تحسين العرض: استخدام InteractiveViewer عشان الصورة تبقى قابلة للتكبير وبدون Overflow 🔥
  void _showCarImageFullScreen(bool isDark, List<dynamic> images) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.95),
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: EdgeInsets.zero,
          child: Stack(
            children: [
              PageView.builder(
                physics: const BouncingScrollPhysics(),
                itemCount: images.length,
                itemBuilder: (context, index) {
                  return InteractiveViewer(
                    panEnabled: true,
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: CachedNetworkImage(
                      imageUrl: images[index].toString(),
                      fit: BoxFit.contain,
                      placeholder: (context, url) => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                    ),
                  );
                },
              ),
              Positioned(
                top: 40,
                right: 20,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showMaintenanceDialog({required bool isEdit, required bool isDark, String? id, required String carId, String initialTitle = "", String initialDesc = "", String initialDate = "", String initialPrice = ""}) {
    TextEditingController titleCtrl = TextEditingController(text: initialTitle);
    TextEditingController priceCtrl = TextEditingController(text: initialPrice);
    TextEditingController descCtrl = TextEditingController(text: initialDesc);
    ValueNotifier<String> dateNotifier = ValueNotifier(initialDate.isEmpty ? DateTime.now().toString().split(' ')[0] : initialDate);

    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: isDark ? const Color(0xFF161E27) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(isEdit ? (AppLang.tr(context, 'edit_record') ?? 'تعديل') : (AppLang.tr(context, 'add_record') ?? 'إضافة سجل'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.primary)), GestureDetector(onTap: () => Navigator.pop(dialogContext), child: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.black12, shape: BoxShape.circle), child: const Icon(Icons.close, size: 18, color: AppColors.textHint)))]),
                const SizedBox(height: 28),
                _buildModernTextField(titleCtrl, AppLang.tr(context, 'service_name') ?? 'Service Name', "e.g., Oil Change", isDark),
                const SizedBox(height: 16),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text((AppLang.tr(context, 'due_date') ?? 'Due').replaceAll(":", ""), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white70 : Colors.black87)),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () async {
                        DateTime? picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2030));
                        if (picked != null) dateNotifier.value = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E2834) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: isDark ? Colors.white10 : Colors.black12, width: 1),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            ValueListenableBuilder(valueListenable: dateNotifier, builder: (_, date, __) => Text(date, style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w500, fontSize: 15))),
                            Icon(Icons.calendar_today_rounded, color: AppColors.primary, size: 20),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                _buildModernTextField(priceCtrl, AppLang.tr(context, 'cost_egp') ?? 'Cost (EGP)', "e.g., 450", isDark),
                const SizedBox(height: 16),
                _buildModernTextField(descCtrl, AppLang.tr(context, 'description_details') ?? 'Description / Details', AppLang.tr(context, 'add_notes_here') ?? 'أضف ملاحظاتك هنا', isDark, maxLines: 3),
                const SizedBox(height: 32),

                Row(children: [
                  Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(dialogContext), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), side: BorderSide(color: isDark ? Colors.white24 : AppColors.borderLight)), child: Text(AppLang.tr(context, 'cancel_btn') ?? 'Cancel', style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold)))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: ElevatedButton(
                          onPressed: () {
                            if (titleCtrl.text.isNotEmpty && dateNotifier.value.isNotEmpty) {
                              context.read<MarketCubit>().saveMaintenanceRecord(id: id, carId: carId, title: titleCtrl.text, date: dateNotifier.value, cost: priceCtrl.text, desc: descCtrl.text);
                              Navigator.pop(dialogContext);
                            }
                          },
                          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
                          child: Text(isEdit ? (AppLang.tr(context, 'save_changes') ?? 'Save') : (AppLang.tr(context, 'add_record') ?? 'Add Record'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))),
                ])
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernTextField(TextEditingController controller, String label, String hint, bool isDark, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white70 : Colors.black87)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 14),
            filled: true,
            fillColor: isDark ? const Color(0xFF1E2834) : Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.black12, width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.black12, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}