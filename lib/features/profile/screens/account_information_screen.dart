import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/colors.dart';
import '../../../core/localization/app_lang.dart';
import '../../auth/cubit/auth_cubit.dart';
import '../../auth/cubit/auth_state.dart';
import 'edit_profile_screen.dart';
import '../../home/widgets/ai_chat_bottom_sheet.dart';

class AccountInformationScreen extends StatelessWidget {
  const AccountInformationScreen({super.key});

  String _formatMemberSince(BuildContext context, String? isoDate) {
    if (isoDate == null || isoDate.isEmpty) return AppLang.tr(context, 'new_user') ?? 'New User';
    try {
      DateTime date = DateTime.parse(isoDate);
      String month = date.month.toString().padLeft(2, '0');
      return "$month / ${date.year}";
    } catch (e) {
      return AppLang.tr(context, 'new_user') ?? 'New User';
    }
  }

  // 🔥 دالة عرض الصورة بشكل كامل ومبهر بدون زراير 🔥
  void _showImageFullScreen(BuildContext context, String imageUrl, String initials) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.85),
      builder: (context) {
        return GestureDetector(
          onTap: () => Navigator.pop(context), // بمجرد الضغط في أي حتة يقفل
          child: Material(
            color: Colors.transparent,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5), // تأثير ضبابي للخلفية
              child: Center(
                child: Hero(
                  tag: 'profile_image',
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.85,
                    height: MediaQuery.of(context).size.width * 0.85,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: AppColors.primary.withOpacity(0.5), blurRadius: 30, spreadRadius: 5)
                      ],
                      image: imageUrl.isNotEmpty
                          ? DecorationImage(image: CachedNetworkImageProvider(imageUrl), fit: BoxFit.cover)
                          : null,
                    ),
                    child: imageUrl.isEmpty
                        ? Center(child: Text(initials, style: const TextStyle(color: Colors.white, fontSize: 80, fontWeight: FontWeight.bold, decoration: TextDecoration.none)))
                        : null,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 🔥 توحيد لون الخلفية الأساسية للدارك واللايت مود 🔥
    final Color screenBgColor = isDark ? const Color(0xFF0A0F14) : const Color(0xFFF4F7FA);

    return Scaffold(
      backgroundColor: screenBgColor,
      body: SafeArea(
        child: BlocBuilder<AuthCubit, AuthState>(
          builder: (context, state) {
            final user = context.read<AuthCubit>().currentUser;

            if (state is GetUserLoading && user == null) {
              return const Center(child: CircularProgressIndicator(color: AppColors.primary));
            }

            String name = user?.name ?? 'User';
            String email = user?.email ?? '';
            String phone = user?.phone ?? '';
            String profileImageUrl = user?.profileImage ?? '';

            String location = (user?.location != null && user!.location.isNotEmpty)
                ? user!.location
                : (AppLang.tr(context, 'fetching_location') ?? 'Fetching Location...');

            String memberSince = _formatMemberSince(context, user?.createdAt);

            String initials = "U";
            if (user != null && name.isNotEmpty) {
              List<String> nameParts = name.trim().split(' ');
              if (nameParts.length > 1 && nameParts[1].isNotEmpty) {
                initials = '${nameParts[0][0]}${nameParts[1][0]}'.toUpperCase();
              } else {
                initials = name[0].toUpperCase();
              }
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.only(left: 24.0, right: 24.0, bottom: 24.0, top: 16.0), // قللنا المسافة اللي فوق
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 🔥 الهيدر المدمج (زرار الرجوع + العناوين) رفعناه لفوق 🔥
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          margin: const EdgeInsets.only(top: 4, right: 16),
                          decoration: BoxDecoration(
                            border: Border.all(color: isDark ? Colors.white10 : AppColors.primary.withOpacity(0.3)),
                            borderRadius: BorderRadius.circular(12),
                            color: isDark ? const Color(0xFF161E27).withOpacity(0.8) : Colors.white.withOpacity(0.7),
                          ),
                          child: Icon(Icons.arrow_back, size: 24, color: isDark ? Colors.white : AppColors.primary),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(AppLang.tr(context, 'account_information') ?? 'Account Information', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)),
                            const SizedBox(height: 4),
                            Text(AppLang.tr(context, 'view_account_details') ?? 'View your account details', style: TextStyle(color: isDark ? Colors.white70 : AppColors.textSecondary, fontSize: 14)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32), // قللنا المسافة دي كمان

                  Center(
                    child: Column(
                      children: [
                        // 🔥 صورة البروفايل القابلة للضغط (Clickable) 🔥
                        GestureDetector(
                          onTap: () => _showImageFullScreen(context, profileImageUrl, initials),
                          child: Hero(
                            tag: 'profile_image',
                            child: Container(
                              width: 110, // كبرناها سنة تدي فخامة
                              height: 110,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                                border: Border.all(color: isDark ? const Color(0xFF161E27) : Colors.white, width: 4),
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 5))],
                                image: profileImageUrl.isNotEmpty
                                    ? DecorationImage(image: CachedNetworkImageProvider(profileImageUrl), fit: BoxFit.cover)
                                    : null,
                              ),
                              child: profileImageUrl.isEmpty
                                  ? Center(child: Text(initials, style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold, decoration: TextDecoration.none)))
                                  : null,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(name, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                        const SizedBox(height: 6),
                        Text("${AppLang.tr(context, 'member_since') ?? 'Member Since'} $memberSince", style: const TextStyle(color: AppColors.textHint, fontSize: 14)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),

                  _buildInfoCard(Icons.person_outline, AppLang.tr(context, 'full_name') ?? 'Full Name', name, isDark),
                  _buildInfoCard(Icons.email_outlined, AppLang.tr(context, 'email_address') ?? 'Email Address', email, isDark),
                  _buildInfoCard(Icons.phone_outlined, AppLang.tr(context, 'phone_number') ?? 'Phone Number', phone, isDark),
                  _buildInfoCard(Icons.location_on_outlined, AppLang.tr(context, 'location') ?? 'Location', location, isDark),
                  _buildInfoCard(Icons.calendar_today_outlined, AppLang.tr(context, 'member_since') ?? 'Member Since', memberSince, isDark),

                  const SizedBox(height: 40),

                  GestureDetector(
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const EditProfileScreen()));
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 6)),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.edit, color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Text(AppLang.tr(context, 'edit_information') ?? 'Edit Information', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.5)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            );
          },
        ),
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
  }

  Widget _buildInfoCard(IconData icon, String label, String value, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        // 🔥 توحيد لون كروت المعلومات للدارك واللايت مود 🔥
        color: isDark ? const Color(0xFF161E27) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFEEEEEE)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.02), blurRadius: 8, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: isDark ? const Color(0xFF1E2834) : AppColors.surfaceLight, shape: BoxShape.circle),
            child: Icon(icon, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: isDark ? Colors.white70 : AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
                const SizedBox(height: 6),
                Text(value, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}