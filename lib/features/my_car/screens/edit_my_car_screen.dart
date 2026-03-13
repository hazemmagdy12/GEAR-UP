import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/colors.dart';
import '../../../core/localization/app_lang.dart';
import '../../home/widgets/ai_chat_bottom_sheet.dart';
import '../../marketplace/cubit/market_cubit.dart';

class EditMyCarScreen extends StatefulWidget {
  final Map<String, dynamic>? carData; // لو null يبقى بيضيف عربية جديدة، لو فيه داتا يبقى بيعدل
  const EditMyCarScreen({super.key, this.carData});

  @override
  State<EditMyCarScreen> createState() => _EditMyCarScreenState();
}

class _EditMyCarScreenState extends State<EditMyCarScreen> {
  final TextEditingController _brandController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _yearController = TextEditingController();
  final TextEditingController _mileageController = TextEditingController();

  List<String> _existingImagesUrls = [];
  final List<File> _newSelectedImages = [];
  bool _isUploading = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    // لو اليوزر بيعدل عربية موجودة، هنملا البيانات
    if (widget.carData != null) {
      _brandController.text = widget.carData!['make'] ?? '';
      _modelController.text = widget.carData!['model'] ?? '';
      _yearController.text = widget.carData!['year'] ?? '';
      _mileageController.text = widget.carData!['mileage'] ?? '';

      if (widget.carData!['images'] != null) {
        _existingImagesUrls = List<String>.from(widget.carData!['images']);
      } else if (widget.carData!['imageUrl'] != null) {
        _existingImagesUrls = [widget.carData!['imageUrl']];
      }
    }
  }

  @override
  void dispose() {
    _brandController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _mileageController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile> pickedFiles = await _picker.pickMultiImage(imageQuality: 80);
      if (pickedFiles.isNotEmpty) {
        setState(() {
          _newSelectedImages.addAll(pickedFiles.map((e) => File(e.path)));
        });
      }
    } catch (e) {
      print("Error picking images: $e");
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
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
            widget.carData == null ? (AppLang.tr(context, 'add_new') ?? "إضافة سيارة جديدة") : (AppLang.tr(context, 'edit_my_vehicle') ?? "تعديل بيانات سيارتي"),
            style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 18, fontWeight: FontWeight.w900)
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppLang.tr(context, 'vehicle_details') ?? "تفاصيل السيارة", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 4),
            Text(AppLang.tr(context, 'update_car_info') ?? "تحديث معلومات سيارتك", style: TextStyle(color: isDark ? Colors.white70 : AppColors.textSecondary, fontSize: 14)),
            const SizedBox(height: 32),

            // 🔥 قسم عرض واختيار الصور مع إمكانية الحذف 🔥
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppLang.tr(context, 'car_photos') ?? "صور السيارة", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: isDark ? Colors.white : Colors.black87)),
                const SizedBox(height: 12),
                SizedBox(
                  height: 100,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    clipBehavior: Clip.none,
                    children: [
                      // زرار إضافة الصور
                      GestureDetector(
                        onTap: _pickImages,
                        child: Container(
                          width: 100,
                          height: 100,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF161E27) : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: isDark ? Colors.white10 : AppColors.primary.withOpacity(0.5), width: 2, style: BorderStyle.solid),
                          ),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_a_photo, color: AppColors.primary, size: 28),
                              SizedBox(height: 8),
                              Text("إضافة", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12)),
                            ],
                          ),
                        ),
                      ),

                      // 🔥 عرض الصور الجديدة المختارة مع زرار مسح 🔥
                      ..._newSelectedImages.asMap().entries.map((entry) {
                        int index = entry.key;
                        File file = entry.value;
                        return Stack(
                          children: [
                            Container(
                              width: 100,
                              height: 100,
                              margin: const EdgeInsets.only(right: 12),
                              decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: isDark ? Colors.white10 : Colors.black12)),
                              child: ClipRRect(borderRadius: BorderRadius.circular(18), child: Image.file(file, fit: BoxFit.cover)),
                            ),
                            Positioned(
                              top: 6,
                              right: 18,
                              child: GestureDetector(
                                onTap: () => setState(() => _newSelectedImages.removeAt(index)),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)]),
                                  child: const Icon(Icons.close, size: 14, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        );
                      }),

                      // 🔥 عرض الصور القديمة من الفايربيز مع زرار مسح 🔥
                      ..._existingImagesUrls.asMap().entries.map((entry) {
                        int index = entry.key;
                        String url = entry.value;
                        return Stack(
                          children: [
                            Container(
                              width: 100,
                              height: 100,
                              margin: const EdgeInsets.only(right: 12),
                              decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: isDark ? Colors.white10 : Colors.black12)),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(18),
                                child: CachedNetworkImage(imageUrl: url, fit: BoxFit.cover, placeholder: (context, url) => const Center(child: CircularProgressIndicator(strokeWidth: 2)), errorWidget: (context, url, error) => const Icon(Icons.error)),
                              ),
                            ),
                            Positioned(
                              top: 6,
                              right: 18,
                              child: GestureDetector(
                                onTap: () => setState(() => _existingImagesUrls.removeAt(index)),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)]),
                                  child: const Icon(Icons.close, size: 14, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),

            _buildLabelField(AppLang.tr(context, 'car_brand') ?? "ماركة السيارة", Icons.branding_watermark_outlined, _brandController, isDark),
            const SizedBox(height: 24),
            _buildLabelField(AppLang.tr(context, 'car_model') ?? "موديل السيارة", Icons.directions_car_outlined, _modelController, isDark),
            const SizedBox(height: 24),

            Row(
              children: [
                Expanded(child: _buildLabelField(AppLang.tr(context, 'manufacturing_year') ?? "سنة الصنع", Icons.calendar_today_outlined, _yearController, isDark, isNumber: true)),
                const SizedBox(width: 16),
                Expanded(child: _buildLabelField(AppLang.tr(context, 'mileage_km') ?? "المسافة (كم)", Icons.speed_outlined, _mileageController, isDark, isNumber: true)),
              ],
            ),
            const SizedBox(height: 50),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isUploading ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      side: BorderSide(color: isDark ? Colors.white24 : AppColors.borderLight, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text(AppLang.tr(context, 'cancel') ?? "إلغاء", style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isUploading ? null : () async {
                      if (_brandController.text.isEmpty || _modelController.text.isEmpty) return;

                      setState(() => _isUploading = true);

                      List<String> finalImagesUrls = List.from(_existingImagesUrls);

                      if (_newSelectedImages.isNotEmpty) {
                        try {
                          final cubit = context.read<MarketCubit>();
                          for (File img in _newSelectedImages) {
                            CloudinaryResponse response = await cubit.cloudinary.uploadFile(
                                CloudinaryFile.fromFile(img.path, folder: 'items_images')
                            );
                            finalImagesUrls.add(response.secureUrl);
                          }
                        } catch (e) {
                          print("Cloudinary Upload Error: $e");
                        }
                      }

                      // 🔥 بيسيف هنا حتى لو finalImagesUrls فاضية (بدون صور خالص) 🔥
                      if (mounted) {
                        await context.read<MarketCubit>().saveMyVehicleDetails(
                          vehicleId: widget.carData?['id'],
                          make: _brandController.text,
                          model: _modelController.text,
                          year: _yearController.text,
                          mileage: _mileageController.text,
                          imagesUrls: finalImagesUrls,
                        );

                        setState(() => _isUploading = false);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم الحفظ بنجاح"), backgroundColor: Colors.green));
                        Navigator.pop(context);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      shadowColor: AppColors.primary.withOpacity(0.5),
                    ),
                    child: _isUploading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(AppLang.tr(context, 'save_changes') ?? "حفظ", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => const AiChatBottomSheet(),
          );
        },
        backgroundColor: AppColors.primary,
        elevation: 8,
        shape: const CircleBorder(),
        child: const Icon(Icons.auto_awesome, color: Colors.white, size: 28),
      ),
    );
  }

  Widget _buildLabelField(String label, IconData icon, TextEditingController controller, bool isDark, {bool isNumber = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: isDark ? Colors.white : Colors.black87)),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161E27) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? Colors.white10 : AppColors.borderLight),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.02), blurRadius: 6, offset: const Offset(0, 3))],
          ),
          child: TextField(
            controller: controller,
            keyboardType: isNumber ? TextInputType.number : TextInputType.text,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? Colors.white : Colors.black87),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
        ),
      ],
    );
  }
}