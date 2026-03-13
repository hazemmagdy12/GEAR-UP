import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/colors.dart';
import '../../../core/localization/app_lang.dart'; // 🔥 تم استيراد ملف الترجمة
import '../../marketplace/cubit/market_cubit.dart';
import '../../marketplace/cubit/market_state.dart';
import '../../marketplace/models/car_model.dart';
import '../../home/screens/car_details_screen.dart';
import '../../home/screens/part_details_screen.dart';

class ReportedCarsScreen extends StatefulWidget {
  const ReportedCarsScreen({super.key});

  @override
  State<ReportedCarsScreen> createState() => _ReportedCarsScreenState();
}

class _ReportedCarsScreenState extends State<ReportedCarsScreen> {
  @override
  void initState() {
    super.initState();
    context.read<MarketCubit>().getReportedCars();
  }

  void _showDeleteConfirmation(BuildContext context, String reportId, String carId, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF161E27) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(AppLang.tr(context, 'delete_reported_ad_title') ?? "حذف الإعلان المخالف", style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
        content: Text(AppLang.tr(context, 'delete_ad_confirmation_msg') ?? "سيتم مسح الإعلان نهائياً من قاعدة البيانات وحذف جميع البلاغات المرتبطة به. هل أنت متأكد؟"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppLang.tr(context, 'cancel_btn') ?? "إلغاء", style: const TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              Navigator.pop(ctx);
              context.read<MarketCubit>().deleteReportedCar(reportId, carId, false);
            },
            child: Text(AppLang.tr(context, 'delete_btn') ?? "حذف", style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // 🔥 دالة ذكية تدور على العربية في اللستات وتفتحها للأدمن 🔥
  void _openReportedCar(BuildContext context, String carId) {
    final cubit = context.read<MarketCubit>();
    CarModel? foundCar;
    bool isPromoted = false;
    bool isPart = false;

    try { foundCar = cubit.carsList.firstWhere((c) => c.id == carId); } catch(e){}
    if (foundCar == null) {
      try { foundCar = cubit.promotedCarsList.firstWhere((c) => c.id == carId); isPromoted = true; } catch(e){}
    }
    if (foundCar == null) {
      try { foundCar = cubit.sparePartsList.firstWhere((c) => c.id == carId); isPart = true; } catch(e){}
    }
    if (foundCar == null) {
      try { foundCar = cubit.promotedPartsList.firstWhere((c) => c.id == carId); isPromoted = true; isPart = true; } catch(e){}
    }

    if (foundCar != null) {
      if (isPart) {
        Navigator.push(context, MaterialPageRoute(builder: (context) => PartDetailsScreen(partItem: foundCar!, isPromoted: isPromoted)));
      } else {
        Navigator.push(context, MaterialPageRoute(builder: (context) => CarDetailsScreen(car: foundCar!, isPromoted: isPromoted)));
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLang.tr(context, 'ad_not_found_msg') ?? "لم يتم العثور على الإعلان محلياً، ربما تم حذفه!"), backgroundColor: Colors.orange));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color screenBgColor = isDark ? const Color(0xFF0A0F14) : const Color(0xFFE3F2FD);

    return Scaffold(
      backgroundColor: screenBgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : AppColors.primary), onPressed: () => Navigator.pop(context)),
        title: Text(AppLang.tr(context, 'pending_reports_title') ?? "البلاغات المعلقة", style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w900, fontSize: 20)),
      ),
      body: BlocBuilder<MarketCubit, MarketState>(
        builder: (context, state) {
          final cubit = context.read<MarketCubit>();

          if (cubit.isLoadingReports) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }

          if (cubit.reportedCarsList.isEmpty) {
            return Center(child: Text(AppLang.tr(context, 'no_pending_reports') ?? "لا توجد بلاغات حالياً، الأمور مستقرة!", style: const TextStyle(fontSize: 16, color: AppColors.textHint, fontWeight: FontWeight.bold)));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: cubit.reportedCarsList.length,
            itemBuilder: (context, index) {
              final report = cubit.reportedCarsList[index];
              return GestureDetector(
                onTap: () => _openReportedCar(context, report['carId']),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF161E27) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(child: Text("${report['make']} ${report['model']}", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis)),
                          const SizedBox(width: 8),
                          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Text(AppLang.tr(context, 'status_pending') ?? "معلق", style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold))),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(AppLang.tr(context, 'click_to_view_ad') ?? "اضغط هنا لعرض تفاصيل الإعلان", style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text("${AppLang.tr(context, 'year_label') ?? 'السنة'}: ${report['year']} | ${AppLang.tr(context, 'seller_label') ?? 'البائع'} ID: ${report['sellerId']}", style: const TextStyle(color: AppColors.textHint, fontSize: 13)),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _showDeleteConfirmation(context, report['reportId'], report['carId'], isDark),
                              icon: const Icon(Icons.delete_forever, color: Colors.white, size: 18),
                              label: Text(AppLang.tr(context, 'delete_ad_btn') ?? "حذف الإعلان", style: const TextStyle(color: Colors.white)),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}