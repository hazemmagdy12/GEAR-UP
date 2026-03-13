import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/colors.dart';
import '../../../core/localization/app_lang.dart';
import '../../marketplace/cubit/market_cubit.dart';
import '../../marketplace/cubit/market_state.dart';

class RemindersScreen extends StatelessWidget {
  final String carId; // 🔥 بقينا بنستقبل carId هنا 🔥
  const RemindersScreen({super.key, required this.carId});

  Map<String, dynamic> _calculateReminderStatus(String targetDateStr, BuildContext context) {
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
      } else if (progress >= 0.90 || diff <= 3) {
        statusColor = Colors.redAccent; // قرب جداً (أحمر)
      } else if (progress >= 0.60) {
        statusColor = Colors.orangeAccent; // برتقالي
      } else {
        statusColor = AppColors.primary; // أزرق (لسه بدري)
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color screenBgColor = isDark ? const Color(0xFF0A0F14) : const Color(0xFFE3F2FD);

    return Scaffold(
      backgroundColor: screenBgColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        border: Border.all(color: isDark ? Colors.white10 : AppColors.primary.withOpacity(0.3)),
                        borderRadius: BorderRadius.circular(12),
                        color: isDark ? const Color(0xFF161E27).withOpacity(0.8) : Colors.white.withOpacity(0.7),
                      ),
                      child: Icon(Icons.arrow_back, size: 24, color: isDark ? Colors.white : AppColors.primary),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(AppLang.tr(context, 'reminders_center') ?? "مركز التذكيرات", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
                      Text(AppLang.tr(context, 'manage_reminders') ?? "إدارة جميع مواعيد الصيانة", style: const TextStyle(fontSize: 12, color: AppColors.textHint)),
                    ],
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showReminderDialog(context, isDark, isEdit: false, carId: carId),
                  icon: const Icon(Icons.add, color: Colors.white, size: 20),
                  label: Text(AppLang.tr(context, 'add_reminder') ?? "إضافة تذكير", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            Expanded(
              child: BlocBuilder<MarketCubit, MarketState>(
                builder: (context, state) {
                  final cubit = context.read<MarketCubit>();

                  // 🔥 بنفلتر التذكيرات بناءً على العربية المختارة بس 🔥
                  final allReminders = cubit.myReminders.where((r) => r['carId'] == carId).toList();

                  if (allReminders.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.notifications_off_outlined, size: 80, color: AppColors.textHint.withOpacity(0.3)),
                          const SizedBox(height: 16),
                          Text(AppLang.tr(context, 'no_reminders') ?? "لا توجد تذكيرات", style: const TextStyle(color: AppColors.textHint, fontWeight: FontWeight.bold, fontSize: 18)),
                        ],
                      ),
                    );
                  }

                  List<dynamic> upcoming = [];
                  List<dynamic> history = [];

                  DateTime now = DateTime.now();
                  DateTime today = DateTime(now.year, now.month, now.day);

                  for (var r in allReminders) {
                    try {
                      DateTime target = DateTime.parse(r['date'].split(' ')[0]);
                      if (target.isBefore(today)) {
                        history.add(r);
                      } else {
                        upcoming.add(r);
                      }
                    } catch (e) {
                      history.add(r);
                    }
                  }

                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (upcoming.isNotEmpty) ...[
                            Text(AppLang.tr(context, 'upcoming_reminders') ?? "مواعيد قادمة", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)),
                            const SizedBox(height: 12),
                            ...upcoming.map((reminder) {
                              final status = _calculateReminderStatus(reminder['date'], context);
                              return _buildReminderItem(context: context, isDark: isDark, id: reminder['id'], carId: reminder['carId'], title: reminder['task'], date: reminder['date'], frequency: reminder['notes'], statusText: status['text'], statusColor: status['color'], progress: status['progress']);
                            }),
                            const SizedBox(height: 20),
                          ],

                          if (history.isNotEmpty) ...[
                            Text(AppLang.tr(context, 'history_reminders') ?? "سجل المواعيد (منتهية)", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.grey.shade600)),                            const SizedBox(height: 12),
                            ...history.map((reminder) {
                              final status = _calculateReminderStatus(reminder['date'], context);
                              return _buildReminderItem(context: context, isDark: isDark, id: reminder['id'], carId: reminder['carId'], title: reminder['task'], date: reminder['date'], frequency: reminder['notes'], statusText: status['text'], statusColor: status['color'], progress: status['progress'], isHistory: true);
                            }),
                          ],
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReminderItem({
    required BuildContext context,
    required bool isDark,
    required String id,
    required String carId, // 🔥 استقبلنا carId هنا
    required String title,
    required String date,
    required String frequency,
    required String statusText,
    required Color statusColor,
    required double progress,
    bool isHistory = false,
  }) {
    Color finalStatusColor = isHistory ? Colors.grey.shade500 : statusColor;
    String finalStatusText = isHistory ? (AppLang.tr(context, 'finished') ?? 'منتهي') : statusText;

    List<Color> progressGradient;
    if (isHistory) {
      progressGradient = [Colors.grey.shade400, Colors.grey.shade300];
    } else if (finalStatusColor == Colors.redAccent) {
      progressGradient = [const Color(0xFFE53935), const Color(0xFFFF8A80)];
    } else if (finalStatusColor == Colors.orangeAccent) {
      progressGradient = [const Color(0xFFF57C00), const Color(0xFFFFCC80)];
    } else {
      progressGradient = [AppColors.primary, const Color(0xFF4FC3F7)];
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161E27) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isHistory ? Colors.grey.withOpacity(0.3) : (isDark ? Colors.white10 : Colors.black12), width: 1),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.04), blurRadius: 12, offset: const Offset(0, 6)),
        ],
      ),
      child: Opacity(
        opacity: isHistory ? 0.5 : 1.0,
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [finalStatusColor.withOpacity(0.2), finalStatusColor.withOpacity(0.05)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    shape: BoxShape.circle,
                    border: Border.all(color: finalStatusColor.withOpacity(0.3)),
                  ),
                  child: Icon(isHistory ? Icons.history : Icons.notifications_active_rounded, color: finalStatusColor, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: isDark ? Colors.white : Colors.black87, decoration: isHistory ? TextDecoration.lineThrough : null)),
                      const SizedBox(height: 4),
                      Text("${AppLang.tr(context, 'due_date') ?? 'التاريخ:'} $date", style: TextStyle(color: isDark ? Colors.white60 : AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 4),
                      Text(frequency, style: const TextStyle(color: AppColors.textHint, fontSize: 12)),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(color: finalStatusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: finalStatusColor.withOpacity(0.2))),
                            child: Text(finalStatusText, style: TextStyle(color: finalStatusColor, fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                          Row(
                            children: [
                              if (!isHistory)
                                _buildActionButton(
                                  icon: Icons.edit_outlined,
                                  isDark: isDark,
                                  onTap: () => _showReminderDialog(
                                    context,
                                    isDark,
                                    isEdit: true,
                                    id: id,
                                    carId: carId, // 🔥 بنبعت الـ carId للتعديل
                                    initialTask: title,
                                    initialDate: date,
                                    initialNotes: frequency,
                                  ),
                                ),
                              if (!isHistory) const SizedBox(width: 8),
                              _buildActionButton(
                                icon: Icons.delete_outline,
                                isDark: isDark,
                                onTap: () => _showDeleteConfirmation(context, isDark, id),
                              ),
                            ],
                          )
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildProgressBar(progress, progressGradient, finalStatusColor, isDark),
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

  Widget _buildActionButton({required IconData icon, required bool isDark, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          border: Border.all(color: isDark ? Colors.white10 : AppColors.borderLight),
          shape: BoxShape.circle,
          color: isDark ? const Color(0xFF1E2834) : Colors.transparent,
        ),
        child: Icon(icon, size: 16, color: isDark ? Colors.white70 : AppColors.textSecondary),
      ),
    );
  }

  void _showReminderDialog(
      BuildContext context,
      bool isDark, {
        required bool isEdit,
        String? id,
        required String carId, // 🔥 خلينا الـ carId إجباري هنا عشان نسجله
        String initialTask = "",
        String initialDate = "",
        String initialNotes = "",
      }) {

    String displayDate = initialDate;
    String todayText = AppLang.tr(context, 'today') ?? "اليوم";

    if (displayDate.isNotEmpty) {
      try {
        DateTime parsedDate = DateTime.parse(displayDate.split(' ')[0]);
        DateTime now = DateTime.now();
        if (parsedDate.year == now.year && parsedDate.month == now.month && parsedDate.day == now.day) {
          if (!displayDate.contains(todayText)) {
            displayDate = "${displayDate.split(' ')[0]} ($todayText)";
          }
        }
      } catch (e) {}
    }

    TextEditingController taskCtrl = TextEditingController(text: initialTask);
    TextEditingController dateCtrl = TextEditingController(text: displayDate);
    TextEditingController notesCtrl = TextEditingController(text: initialNotes);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: isDark ? const Color(0xFF161E27) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          child: Padding(
            padding: const EdgeInsets.all(28.0),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(isEdit ? (AppLang.tr(context, 'edit_reminder') ?? 'تعديل تذكير') : (AppLang.tr(context, 'add_reminder') ?? 'إضافة تذكير'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.primary)),
                      GestureDetector(onTap: () => Navigator.pop(dialogContext), child: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.black12, shape: BoxShape.circle), child: const Icon(Icons.close, size: 18, color: AppColors.textHint))),
                    ],
                  ),
                  const SizedBox(height: 28),

                  _buildSingleTextField(
                      label: AppLang.tr(context, 'task') ?? 'المهمة',
                      hint: AppLang.tr(context, 'task_hint') ?? 'اسم المهمة',
                      isDark: isDark,
                      controller: taskCtrl
                  ),
                  const SizedBox(height: 16),

                  _buildDatePickerField(
                    context: context,
                    label: AppLang.tr(context, 'date') ?? 'التاريخ',
                    hint: 'YYYY-MM-DD',
                    isDark: isDark,
                    controller: dateCtrl,
                  ),
                  const SizedBox(height: 16),

                  _buildSingleTextField(
                      label: AppLang.tr(context, 'notes_optional') ?? 'ملاحظات (اختياري)',
                      hint: AppLang.tr(context, 'additional_details') ?? 'تفاصيل إضافية',
                      isDark: isDark,
                      controller: notesCtrl,
                      maxLines: 3
                  ),
                  const SizedBox(height: 32),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            side: BorderSide(color: isDark ? Colors.white24 : AppColors.borderLight),
                          ),
                          child: Text(AppLang.tr(context, 'cancel') ?? 'إلغاء', style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            if (taskCtrl.text.isNotEmpty && dateCtrl.text.isNotEmpty) {
                              String cleanDate = dateCtrl.text.split(' ')[0];

                              context.read<MarketCubit>().saveReminder(
                                id: id,
                                carId: carId, // 🔥 بنبعت الـ carId للـ Cubit
                                task: taskCtrl.text,
                                date: cleanDate,
                                notes: notesCtrl.text,
                              );
                              Navigator.pop(dialogContext);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                          child: Text(isEdit ? (AppLang.tr(context, 'save_changes') ?? 'حفظ') : (AppLang.tr(context, 'add_reminder') ?? 'إضافة'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showDeleteConfirmation(BuildContext context, bool isDark, String reminderId) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF161E27) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(AppLang.tr(context, 'delete_reminder') ?? 'حذف التذكير', style: TextStyle(fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)),
          content: Text(AppLang.tr(context, 'delete_confirm_msg') ?? 'هل أنت متأكد من حذف هذا التذكير؟', style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontWeight: FontWeight.w500)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(AppLang.tr(context, 'cancel') ?? 'إلغاء', style: const TextStyle(color: AppColors.textHint, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              onPressed: () {
                context.read<MarketCubit>().deleteReminder(reminderId);
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(AppLang.tr(context, 'reminder_deleted') ?? 'تم الحذف'),
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
              child: Text(AppLang.tr(context, 'delete') ?? 'حذف', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSingleTextField({required String label, required String hint, required bool isDark, required TextEditingController controller, int maxLines = 1}) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2834) : AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : AppColors.borderLight),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontWeight: FontWeight.bold),
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 14),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildDatePickerField({required BuildContext context, required String label, required String hint, required bool isDark, required TextEditingController controller}) {
    return GestureDetector(
      onTap: () async {
        DateTime? pickedDate = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2101),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: isDark
                    ? const ColorScheme.dark(
                  primary: AppColors.primary,
                  onPrimary: Colors.white,
                  surface: Color(0xFF161E27),
                  onSurface: Colors.white,
                )
                    : const ColorScheme.light(
                  primary: AppColors.primary,
                ),
              ),
              child: child!,
            );
          },
        );

        if (pickedDate != null) {
          String formattedDate = "${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}";

          DateTime now = DateTime.now();
          if (pickedDate.year == now.year && pickedDate.month == now.month && pickedDate.day == now.day) {
            String todayText = AppLang.tr(context, 'today') ?? "اليوم";
            formattedDate = "$formattedDate ($todayText)";
          }

          controller.text = formattedDate;
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E2834) : AppColors.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? Colors.white10 : AppColors.borderLight),
        ),
        child: TextField(
          controller: controller,
          enabled: false,
          style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontWeight: FontWeight.bold),
            hintText: hint,
            hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 14),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            suffixIcon: Icon(Icons.calendar_today_rounded, color: isDark ? Colors.white54 : Colors.black54, size: 20),
          ),
        ),
      ),
    );
  }
}