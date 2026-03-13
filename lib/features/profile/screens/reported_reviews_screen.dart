import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/colors.dart';
import '../../../core/localization/app_lang.dart';
import '../../marketplace/cubit/market_cubit.dart';

class ReportedReviewsScreen extends StatelessWidget {
  const ReportedReviewsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color screenBgColor = isDark ? const Color(0xFF0A0F14) : const Color(0xFFF4F7FA);

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
          AppLang.tr(context, 'reported_reviews_title') ?? "مراجعة التعليقات",
          style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w900, fontSize: 20),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('reported_reviews').where('status', isEqualTo: 'pending').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline_rounded, size: 80, color: Colors.green.withOpacity(0.5)),
                  const SizedBox(height: 16),
                  Text(
                    AppLang.tr(context, 'no_reported_reviews') ?? "لا توجد بلاغات معلقة!",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black87),
                  ),
                ],
              ),
            );
          }

          final reports = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: reports.length,
            physics: const BouncingScrollPhysics(),
            itemBuilder: (context, index) {
              var report = reports[index];
              String reportId = report.id;
              String comment = report['comment'] ?? 'بدون نص';
              String itemId = report['itemId'] ?? '';
              String reviewId = report['reviewId'] ?? '';
              bool isPart = report['isPart'] ?? false;

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF161E27) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.05), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                        const SizedBox(width: 8),
                        Text(
                          isPart ? "بلاغ في قطعة غيار" : "بلاغ في سيارة",
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1A242F) : const Color(0xFFF9FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.redAccent.withOpacity(0.2)),
                      ),
                      child: Text(
                        "\"$comment\"",
                        style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 15, height: 1.5, fontStyle: FontStyle.italic),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              context.read<MarketCubit>().resolveReportedReview(
                                reportId: reportId, itemId: itemId, reviewId: reviewId, isPart: isPart, action: 'dismiss',
                              );
                            },
                            icon: const Icon(Icons.visibility_off, color: Colors.grey, size: 18),
                            label: const Text("تجاهل", style: TextStyle(color: Colors.grey)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.grey),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              context.read<MarketCubit>().resolveReportedReview(
                                reportId: reportId, itemId: itemId, reviewId: reviewId, isPart: isPart, action: 'delete',
                              );
                            },
                            icon: const Icon(Icons.delete_forever, color: Colors.white, size: 18),
                            label: const Text("مسح التعليق", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}