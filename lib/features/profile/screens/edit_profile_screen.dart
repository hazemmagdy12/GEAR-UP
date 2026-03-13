import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/colors.dart';
import '../../../core/localization/app_lang.dart';
import '../../../core/local_storage/cache_helper.dart';
import '../../home/widgets/ai_chat_bottom_sheet.dart';
import '../../auth/cubit/auth_cubit.dart';
import '../../auth/cubit/auth_state.dart';
import '../../marketplace/cubit/market_cubit.dart';
import '../../marketplace/cubit/market_state.dart';
import '../../marketplace/models/car_model.dart';
import 'change_password_screen.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthCubit>().currentUser;
    _nameController = TextEditingController(text: user?.name ?? "");
    _emailController = TextEditingController(text: user?.email ?? "");
    _phoneController = TextEditingController(text: user?.phone ?? "");
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _updateUserAdsInFirebaseAndLocal(String uid, String newName, String newPhone, String newEmail) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();

      final carsQuery = await firestore.collection('cars').where('sellerId', isEqualTo: uid).get();
      for (var doc in carsQuery.docs) {
        batch.update(doc.reference, {'sellerName': newName, 'sellerPhone': newPhone, 'sellerEmail': newEmail});
      }

      final promotedQuery = await firestore.collection('promoted_cars').where('sellerId', isEqualTo: uid).get();
      for (var doc in promotedQuery.docs) {
        batch.update(doc.reference, {'sellerName': newName, 'sellerPhone': newPhone, 'sellerEmail': newEmail});
      }

      final partsQuery = await firestore.collection('spare_parts').where('sellerId', isEqualTo: uid).get();
      for (var doc in partsQuery.docs) {
        batch.update(doc.reference, {'sellerName': newName, 'sellerPhone': newPhone, 'sellerEmail': newEmail});
      }

      await batch.commit();

      if (mounted) {
        final marketCubit = context.read<MarketCubit>();

        for (int i = 0; i < marketCubit.carsList.length; i++) {
          if (marketCubit.carsList[i].sellerId == uid) {
            CarModel old = marketCubit.carsList[i];
            marketCubit.carsList[i] = CarModel(
              id: old.id, sellerId: old.sellerId, itemType: old.itemType, make: old.make, model: old.model, year: old.year, price: old.price, condition: old.condition, description: old.description, hp: old.hp, cc: old.cc, torque: old.torque, transmission: old.transmission, luggageCapacity: old.luggageCapacity, mileage: old.mileage,
              sellerName: newName, sellerPhone: newPhone, sellerEmail: newEmail,
              sellerLocation: old.sellerLocation, images: old.images, createdAt: old.createdAt, rating: old.rating, reviewsCount: old.reviewsCount, viewsCount: old.viewsCount,
            );
          }
        }

        for (int i = 0; i < marketCubit.promotedCarsList.length; i++) {
          if (marketCubit.promotedCarsList[i].sellerId == uid) {
            CarModel old = marketCubit.promotedCarsList[i];
            marketCubit.promotedCarsList[i] = CarModel(
              id: old.id, sellerId: old.sellerId, itemType: old.itemType, make: old.make, model: old.model, year: old.year, price: old.price, condition: old.condition, description: old.description, hp: old.hp, cc: old.cc, torque: old.torque, transmission: old.transmission, luggageCapacity: old.luggageCapacity, mileage: old.mileage,
              sellerName: newName, sellerPhone: newPhone, sellerEmail: newEmail,
              sellerLocation: old.sellerLocation, images: old.images, createdAt: old.createdAt, rating: old.rating, reviewsCount: old.reviewsCount, viewsCount: old.viewsCount,
            );
          }
        }

        for (int i = 0; i < marketCubit.sparePartsList.length; i++) {
          if (marketCubit.sparePartsList[i].sellerId == uid) {
            CarModel old = marketCubit.sparePartsList[i];
            marketCubit.sparePartsList[i] = CarModel(
              id: old.id, sellerId: old.sellerId, itemType: old.itemType, make: old.make, model: old.model, year: old.year, price: old.price, condition: old.condition, description: old.description, hp: old.hp, cc: old.cc, torque: old.torque, transmission: old.transmission, luggageCapacity: old.luggageCapacity, mileage: old.mileage,
              sellerName: newName, sellerPhone: newPhone, sellerEmail: newEmail,
              sellerLocation: old.sellerLocation, images: old.images, createdAt: old.createdAt, rating: old.rating, reviewsCount: old.reviewsCount, viewsCount: old.viewsCount,
            );
          }
        }

        marketCubit.emit(CarDescriptionUpdatedState());
      }
    } catch (e) {
      print("Error updating user ads: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final user = context.read<AuthCubit>().currentUser;
    String name = user?.name ?? 'User';
    String profileImageUrl = user?.profileImage ?? '';

    String initials = "U";
    if (name.isNotEmpty) {
      List<String> nameParts = name.trim().split(' ');
      if (nameParts.length > 1 && nameParts[1].isNotEmpty) {
        initials = '${nameParts[0][0]}${nameParts[1][0]}'.toUpperCase();
      } else {
        initials = name[0].toUpperCase();
      }
    }

    final Color screenBgColor = isDark ? const Color(0xFF0A0F14) : const Color(0xFFF4F7FA);

    return Scaffold(
      backgroundColor: screenBgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: GestureDetector(
          onTap: () {
            context.read<AuthCubit>().clearProfileImage();
            Navigator.pop(context);
          },
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border.all(color: isDark ? Colors.white10 : AppColors.primary.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(12),
              color: isDark ? const Color(0xFF161E27).withOpacity(0.8) : Colors.white.withOpacity(0.7),
            ),
            child: Icon(Icons.arrow_back, size: 24, color: isDark ? Colors.white : AppColors.primary),
          ),
        ),
        title: Text(AppLang.tr(context, 'edit_profile') ?? 'Edit Profile', style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 18, fontWeight: FontWeight.w900)),
        centerTitle: true,
      ),
      body: BlocConsumer<AuthCubit, AuthState>(
        listener: (context, state) {
          if (state is UpdateUserSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('تم تحديث البيانات بنجاح'), backgroundColor: Colors.green),
            );
            Navigator.pop(context);
          } else if (state is UpdateUserError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.error), backgroundColor: Colors.red),
            );
          } else if (state is ProfileImagePickedError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.error), backgroundColor: Colors.orange),
            );
          }
        },
        builder: (context, state) {
          File? selectedImage = context.read<AuthCubit>().profileImage;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () {
                    context.read<AuthCubit>().pickProfileImage();
                  },
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: isDark ? const Color(0xFF161E27) : Colors.white, width: 4),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.1), blurRadius: 15, offset: const Offset(0, 5))],
                          image: selectedImage != null
                              ? DecorationImage(image: FileImage(selectedImage), fit: BoxFit.cover)
                              : (profileImageUrl.isNotEmpty
                              ? DecorationImage(image: CachedNetworkImageProvider(profileImageUrl), fit: BoxFit.cover)
                              : null),
                        ),
                        child: (selectedImage == null && profileImageUrl.isEmpty)
                            ? Center(child: Text(initials, style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)))
                            : null,
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: isDark ? const Color(0xFF161E27) : Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.camera_alt_outlined, color: Colors.white, size: 18),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 🔥 التعديل هنا: الكلمة بقت Clickable وبتفتح الاستوديو زي الصورة بالظبط 🔥
                GestureDetector(
                  onTap: () {
                    context.read<AuthCubit>().pickProfileImage();
                  },
                  child: Text(
                      AppLang.tr(context, 'change_profile_photo') ?? 'Change Profile Photo',
                      style: const TextStyle(color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.bold)
                  ),
                ),
                const SizedBox(height: 40),

                _buildLabelField(AppLang.tr(context, 'full_name') ?? 'Full Name', Icons.person_outline, _nameController, isDark),
                const SizedBox(height: 24),
                _buildLabelField(AppLang.tr(context, 'email_address') ?? 'Email Address', Icons.email_outlined, _emailController, isDark, isEmail: true),
                const SizedBox(height: 24),
                _buildLabelField(AppLang.tr(context, 'phone_number') ?? 'Phone Number', Icons.phone_outlined, _phoneController, isDark, isPhone: true),
                const SizedBox(height: 32),

                // 🔥 التعديل هنا: زرار تغيير الباسوورد بتصميم بريميوم فخم 🔥
                GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ChangePasswordScreen())),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF161E27) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? Colors.white10 : Colors.black12, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.3 : 0.04),
                          blurRadius: 15,
                          offset: const Offset(0, 6),
                        )
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.lock_outline, color: AppColors.primary, size: 22),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            AppLang.tr(context, 'change_password') ?? 'Change Password',
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios_rounded, color: isDark ? Colors.white54 : AppColors.textHint, size: 18),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 40),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: state is UpdateUserLoading ? null : () {
                          context.read<AuthCubit>().clearProfileImage();
                          Navigator.pop(context);
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          side: BorderSide(color: isDark ? Colors.white24 : AppColors.borderLight, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text(AppLang.tr(context, 'cancel') ?? 'Cancel', style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: state is UpdateUserLoading ? null : () {
                          String name = _nameController.text.trim();
                          String phone = _phoneController.text.trim();
                          String email = _emailController.text.trim();

                          if (name.isEmpty || phone.isEmpty || email.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('جميع الحقول مطلوبة'), backgroundColor: Colors.red),
                            );
                            return;
                          }

                          if (!email.toLowerCase().endsWith('@gmail.com')) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('البريد الإلكتروني يجب أن ينتهي بـ @gmail.com'), backgroundColor: Colors.red),
                            );
                            return;
                          }

                          if (phone.length != 11 || !RegExp(r'^[0-9]+$').hasMatch(phone)) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('يرجى إدخال رقم هاتف صحيح مكون من 11 رقماً بالصيغة الإنجليزية (مثال: 01xxxxxxxxx)'),
                                  backgroundColor: Colors.red
                              ),
                            );
                            return;
                          }

                          context.read<AuthCubit>().updateUserData(name: name, phone: phone, email: email);

                          String? uid = CacheHelper.getData(key: 'uid');
                          if (uid != null) {
                            _updateUserAdsInFirebaseAndLocal(uid, name, phone, email);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: state is UpdateUserLoading
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : Text(AppLang.tr(context, 'save_changes') ?? 'Save Changes', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
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

  Widget _buildLabelField(String label, IconData icon, TextEditingController controller, bool isDark, {bool isPhone = false, bool isEmail = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: isDark ? Colors.white70 : Colors.black87)),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: controller,
          keyboardType: isPhone ? TextInputType.phone : (isEmail ? TextInputType.emailAddress : TextInputType.text),
          style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 15),
          decoration: InputDecoration(
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