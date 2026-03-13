import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/colors.dart';
import '../../../core/localization/app_lang.dart';
import '../../marketplace/models/car_model.dart';
import '../../marketplace/cubit/market_cubit.dart';
import '../../marketplace/cubit/market_state.dart';
import '../../../core/local_storage/cache_helper.dart';
import '../../auth/screens/login_screen.dart';
import '../../auth/cubit/auth_cubit.dart';
import '../../profile/screens/start_selling_screen.dart';

class PartDetailsScreen extends StatefulWidget {
  final CarModel partItem;
  final bool isPromoted;

  const PartDetailsScreen({super.key, required this.partItem, this.isPromoted = false});

  @override
  State<PartDetailsScreen> createState() => _PartDetailsScreenState();
}

class _PartDetailsScreenState extends State<PartDetailsScreen> {
  int _currentImageIndex = 0;
  int _currentViews = 0;
  bool _showValidationBanner = false;
  bool _isReporting = false;

  double _averageRating = 0.0;
  int _reviewsCount = 0;
  List<Map<String, dynamic>> _reviewsList = [];
  bool _isLoadingReviews = true;
  bool _isSubmittingReview = false;
  double _userRating = 0.0;
  final TextEditingController _reviewController = TextEditingController();
  String? _editingReviewId;

  @override
  void initState() {
    super.initState();
    _currentViews = widget.partItem.viewsCount;
    _loadPartData();
    if (widget.isPromoted) _incrementView();
    if (!widget.isPromoted) _checkValidationStatus();
  }

  Future<void> _loadPartData() async {
    final cubit = context.read<MarketCubit>();
    try {
      final ratingData = await cubit.getPartRatingData(widget.partItem.id).timeout(const Duration(seconds: 5));
      if (mounted) {
        setState(() {
          _averageRating = ratingData['average']; _reviewsCount = ratingData['count'];
          _reviewsList = List<Map<String, dynamic>>.from(ratingData['reviews'] ?? []);
          _reviewsList.sort((a, b) { DateTime dateA = DateTime.tryParse(a['createdAt'] ?? '') ?? DateTime.now(); DateTime dateB = DateTime.tryParse(b['createdAt'] ?? '') ?? DateTime.now(); return dateB.compareTo(dateA); });
        });
      }
    } catch (e) { print("Firebase Part Reviews Error: $e"); } finally { if (mounted) setState(() => _isLoadingReviews = false); }
  }

  Future<void> _submitReview() async {
    if (_userRating == 0 && _reviewController.text.trim().isEmpty) return;
    FocusScope.of(context).unfocus(); setState(() => _isSubmittingReview = true);
    try {
      final cubit = context.read<MarketCubit>();
      if (_editingReviewId != null) {
        await cubit.updateReviewFromProfile(widget.partItem.id, _editingReviewId!, _userRating > 0 ? _userRating : 5.0, _reviewController.text.trim(), isPart: true);
      } else {
        await cubit.addPartReview(partId: widget.partItem.id, sellerId: widget.partItem.sellerId, partMake: widget.partItem.make, partModel: widget.partItem.model, rating: _userRating > 0 ? _userRating : 5.0, comment: _reviewController.text.trim());
      }
      _reviewController.clear(); _userRating = 0.0; _editingReviewId = null; await _loadPartData();
    } catch (e) {} finally { if (mounted) setState(() => _isSubmittingReview = false); }
  }

  void _startEditingReview(Map<String, dynamic> review) {
    setState(() { _editingReviewId = review['id'] ?? review['reviewId']; _reviewController.text = review['comment'] ?? ''; _userRating = (review['rating'] as num).toDouble(); });
  }

  void _deleteReview(String reviewId, String originalUserId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLang.tr(context, 'confirm_delete_title') ?? 'تأكيد الحذف', style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(AppLang.tr(context, 'confirm_delete_review_msg') ?? 'هل أنت متأكد من مسح هذا التقييم؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppLang.tr(context, 'cancel_btn') ?? 'إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async { Navigator.pop(ctx); setState(() => _isLoadingReviews = true); await context.read<MarketCubit>().deleteMyReview(widget.partItem.id, reviewId, originalUserId: originalUserId, isPart: true); await _loadPartData(); },
            child: Text(AppLang.tr(context, 'delete_btn') ?? 'مسح', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _reportReview(String reviewId, String commentText) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF161E27) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [const Icon(Icons.flag_rounded, color: Colors.orange), const SizedBox(width: 8), Text(AppLang.tr(context, 'report_review') ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))]),
        content: Text(AppLang.tr(context, 'confirm_report_review') ?? '', style: const TextStyle(height: 1.5)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppLang.tr(context, 'cancel_btn') ?? '', style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () async { Navigator.pop(ctx); await context.read<MarketCubit>().reportReview(carId: widget.partItem.id, reviewId: reviewId, comment: commentText, isPart: true); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLang.tr(context, 'review_reported_success') ?? ''), backgroundColor: Colors.green)); },
            child: Text(AppLang.tr(context, 'report_btn') ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _checkValidationStatus() async {
    List<String> validatedCars = CacheHelper.getStringList(key: 'validated_cars') ?? [];
    List<String> reportedCarsLocal = CacheHelper.getStringList(key: 'reported_cars_local') ?? [];
    if (!validatedCars.contains(widget.partItem.id) && !reportedCarsLocal.contains(widget.partItem.id)) { setState(() => _showValidationBanner = true); }
  }

  Future<void> _markAsValid() async {
    setState(() => _showValidationBanner = false);
    List<String> validatedCars = CacheHelper.getStringList(key: 'validated_cars') ?? [];
    validatedCars.add(widget.partItem.id); await CacheHelper.saveData(key: 'validated_cars', value: validatedCars);
  }

  Future<void> _reportToAdmin() async {
    setState(() => _isReporting = true);
    try {
      await FirebaseFirestore.instance.collection('reported_cars').add({'carId': widget.partItem.id, 'make': widget.partItem.make, 'model': widget.partItem.model, 'year': widget.partItem.year, 'sellerId': widget.partItem.sellerId, 'reportedAt': DateTime.now().toIso8601String(), 'status': 'pending', 'isPart': true});
      List<String> reportedCarsLocal = CacheHelper.getStringList(key: 'reported_cars_local') ?? [];
      reportedCarsLocal.add(widget.partItem.id); await CacheHelper.saveData(key: 'reported_cars_local', value: reportedCarsLocal);
      setState(() { _showValidationBanner = false; _isReporting = false; });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLang.tr(context, 'report_success_msg') ?? ''), backgroundColor: Colors.green));
    } catch (e) { setState(() => _isReporting = false); if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLang.tr(context, 'report_error_msg') ?? ''), backgroundColor: Colors.red)); }
  }

  void _incrementView() async {
    final cubit = context.read<MarketCubit>();
    await cubit.incrementCarView(widget.partItem.id, widget.isPromoted, isPart: true);
    if (mounted) setState(() { int index = cubit.sparePartsList.indexWhere((c) => c.id == widget.partItem.id); if (index != -1) _currentViews = cubit.sparePartsList[index].viewsCount; });
  }

  void _showGuestDialog(BuildContext context, String featureName) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: isDark ? const Color(0xFF161E27) : Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.lock_outline_rounded, size: 40, color: AppColors.primary)), const SizedBox(height: 20),
              Text(AppLang.tr(context, 'login_required') ?? "تسجيل الدخول مطلوب", style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w900, fontSize: 20)), const SizedBox(height: 12),
              Text("${AppLang.tr(context, 'guest_sorry_prefix') ?? ''} $featureName ${AppLang.tr(context, 'guest_sorry_suffix') ?? ''}", textAlign: TextAlign.center, style: TextStyle(color: isDark ? Colors.white70 : AppColors.textSecondary, fontSize: 14)), const SizedBox(height: 32),
              SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () { Navigator.pop(ctx); Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginScreen())); }, style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), child: Text(AppLang.tr(context, 'login') ?? "تسجيل الدخول", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)))),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _makePhoneCall(String phoneNumber) async { final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber); if (await canLaunchUrl(launchUri)) await launchUrl(launchUri); }
  Future<void> _sendEmail(String email) async { final Uri emailUri = Uri.parse("mailto:$email?subject=استفسار بخصوص قطعة الغيار"); try { await launchUrl(emailUri, mode: LaunchMode.externalApplication); } catch (e) {} }
  Future<void> _openMap(String location) async { final String googleMapsUrl = "https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(location)}"; if (await canLaunchUrl(Uri.parse(googleMapsUrl))) await launchUrl(Uri.parse(googleMapsUrl), mode: LaunchMode.externalApplication); }
  Future<void> _sharePart() async { final String shareContent = "${AppLang.tr(context, 'share_part_content') ?? ''}\n\n✨ ${widget.partItem.make}\n🔧 ${AppLang.tr(context, 'fits') ?? ''}: ${widget.partItem.model}\n💰 ${AppLang.tr(context, 'average_price')}: EGP ${widget.partItem.price.toStringAsFixed(0)}"; await Share.share(shareContent); }

  @override
  void dispose() { _reviewController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cubit = context.read<MarketCubit>();
    bool isAdmin = context.read<AuthCubit>().currentUser?.role == 'admin';

    final title = widget.partItem.make; final compatibility = widget.partItem.model; final price = "EGP ${widget.partItem.price.toStringAsFixed(0)}";
    final description = widget.partItem.description.isNotEmpty ? widget.partItem.description : "لا يوجد وصف متاح لهذه القطعة.";

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: BlocBuilder<MarketCubit, MarketState>(
        builder: (context, state) {
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderImageSlider(context, isDark, cubit),
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTitleSection(context, isDark, title, compatibility, price), const SizedBox(height: 40),
                      Text(AppLang.tr(context, 'specifications_title') ?? '', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)), const SizedBox(height: 20),
                      _buildSpecsGrid(context, isDark), const SizedBox(height: 40),

                      if (widget.partItem.sellerId.isNotEmpty && !widget.partItem.sellerId.startsWith('ai_')) ...[_buildSellerInfoCard(context, isDark), const SizedBox(height: 40)],

                      if (isAdmin) ...[
                        Container(
                          padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.redAccent.withOpacity(0.3))),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(AppLang.tr(context, 'admin_privileges') ?? '', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 16)), const SizedBox(height: 12),
                              Row(children: [Expanded(child: ElevatedButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => StartSellingScreen(initialItemType: widget.partItem.itemType, itemToEdit: widget.partItem))), icon: const Icon(Icons.edit, color: Colors.white, size: 18), label: Text(AppLang.tr(context, 'edit_btn') ?? '', style: const TextStyle(color: Colors.white)), style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))), const SizedBox(width: 12), Expanded(child: ElevatedButton.icon(onPressed: () async { await cubit.deleteUserItem(widget.partItem); Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLang.tr(context, 'admin_deleted_success') ?? ''), backgroundColor: Colors.green)); }, icon: const Icon(Icons.delete, color: Colors.white, size: 18), label: Text(AppLang.tr(context, 'delete_permanently_btn') ?? '', style: const TextStyle(color: Colors.white)), style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))))])
                            ],
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],

                      Text(AppLang.tr(context, 'description') ?? '', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)), const SizedBox(height: 16),
                      Text(description, style: TextStyle(color: isDark ? Colors.white70 : AppColors.textSecondary, height: 1.8, fontSize: 15)),

                      if (_showValidationBanner) ...[const SizedBox(height: 24), _buildValidationBanner(isDark)],

                      const SizedBox(height: 40),
                      if (widget.isPromoted) ...[_buildViewsCounter(context), const SizedBox(height: 40)],

                      Text(AppLang.tr(context, 'reviews') ?? '', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)), const SizedBox(height: 20),
                      _buildReviewSection(context, isDark),

                      if (_isLoadingReviews) const Padding(padding: EdgeInsets.only(top: 30.0), child: Center(child: CircularProgressIndicator(color: AppColors.primary)))
                      else if (_reviewsList.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 20.0), child: _buildReviewsList(isDark))
                      else Padding(padding: const EdgeInsets.symmetric(vertical: 40.0), child: Center(child: Column(children: [Icon(Icons.rate_review_outlined, size: 50, color: AppColors.textHint.withOpacity(0.4)), const SizedBox(height: 12), Text(AppLang.tr(context, 'no_reviews_yet') ?? "", style: const TextStyle(color: AppColors.textHint, fontWeight: FontWeight.bold, fontSize: 15))]))),
                      const SizedBox(height: 60),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildValidationBanner(bool isDark) {
    return AnimatedOpacity(duration: const Duration(milliseconds: 500), opacity: _showValidationBanner ? 1.0 : 0.0, child: Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: isDark ? const Color(0xFF1A237E).withOpacity(0.3) : AppColors.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.primary.withOpacity(0.3))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [const Icon(Icons.verified_user_outlined, color: AppColors.primary, size: 22), const SizedBox(width: 8), Expanded(child: Text(AppLang.tr(context, 'is_info_correct') ?? "", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? Colors.white : Colors.black87)))]), const SizedBox(height: 16), Row(children: [Expanded(child: OutlinedButton(onPressed: _isReporting ? null : _reportToAdmin, style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.redAccent), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: _isReporting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.redAccent, strokeWidth: 2)) : Text(AppLang.tr(context, 'no_error') ?? "", style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)))), const SizedBox(width: 12), Expanded(child: ElevatedButton(onPressed: _isReporting ? null : _markAsValid, style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text(AppLang.tr(context, 'yes_correct') ?? "", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))))])])));
  }

  Widget _buildViewsCounter(BuildContext context) { return Container(padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24), decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppColors.primary, Color(0xFF1E3A8A)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 8))]), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle), child: const Icon(Icons.visibility_outlined, color: Colors.white, size: 32)), const SizedBox(width: 24), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("$_currentViews", style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 2.0)), const SizedBox(height: 4), Text(AppLang.tr(context, 'total_views') ?? '', style: const TextStyle(color: Colors.white70, fontSize: 15, fontWeight: FontWeight.w500))])])); }

  Widget _buildSellerInfoCard(BuildContext context, bool isDark) { return Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: isDark ? AppColors.surfaceDark : Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: isDark ? AppColors.borderDark : const Color(0xFFEEEEEE)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.03), blurRadius: 15, offset: const Offset(0, 5))]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(AppLang.tr(context, 'seller_info') ?? '', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)), const SizedBox(height: 20), Row(children: [Container(width: 50, height: 50, decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.person, color: AppColors.primary, size: 24)), const SizedBox(width: 16), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(widget.partItem.sellerName, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)), const SizedBox(height: 4), Text(widget.partItem.sellerPhone, style: const TextStyle(color: AppColors.textHint, fontSize: 14)), if (widget.partItem.sellerEmail.isNotEmpty && widget.partItem.sellerEmail != "not_specified") ...[const SizedBox(height: 2), Text(widget.partItem.sellerEmail, style: const TextStyle(color: AppColors.textHint, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)]])), Row(mainAxisSize: MainAxisSize.min, children: [if (widget.partItem.sellerEmail.isNotEmpty && widget.partItem.sellerEmail != "not_specified") GestureDetector(onTap: () => _sendEmail(widget.partItem.sellerEmail), child: Container(margin: const EdgeInsets.only(right: 8), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.mail_outline, color: Colors.blueAccent, size: 20))), GestureDetector(onTap: () => _makePhoneCall(widget.partItem.sellerPhone), child: Container(padding: const EdgeInsets.all(12), decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle), child: const Icon(Icons.phone, color: Colors.white, size: 20)))])]), if (widget.partItem.sellerLocation.isNotEmpty && widget.partItem.sellerLocation != "not_specified") ...[const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)), GestureDetector(onTap: () => _openMap(widget.partItem.sellerLocation), child: Row(children: [Container(width: 50, height: 50, decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.location_on, color: Colors.redAccent, size: 24)), const SizedBox(width: 16), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(AppLang.tr(context, 'seller_location_title') ?? '', style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : AppColors.textSecondary)), const SizedBox(height: 4), Text(AppLang.tr(context, 'open_in_maps') ?? '', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87))])), const Icon(Icons.open_in_new, size: 18, color: AppColors.textHint)]))] ])); }

  Widget _buildHeaderImageSlider(BuildContext context, bool isDark, MarketCubit cubit) { final images = widget.partItem.images; return Stack(children: [Container(height: 380, width: double.infinity, decoration: BoxDecoration(color: isDark ? const Color(0xFF2A2A2A) : AppColors.surfaceLight), child: images.isNotEmpty ? PageView.builder(itemCount: images.length, onPageChanged: (index) => setState(() => _currentImageIndex = index), itemBuilder: (context, index) { return GestureDetector(onTap: () { Navigator.push(context,PageRouteBuilder(opaque: false, barrierColor: Colors.black.withOpacity(0.9), pageBuilder: (context, animation, secondaryAnimation) {return FullScreenImageViewer(images: images,initialIndex: index);},transitionsBuilder: (context, animation, secondaryAnimation, child) {return FadeTransition(opacity: animation, child: child);})); }, child: CachedNetworkImage(imageUrl: images[index], fit: BoxFit.cover, placeholder: (context, url) => const Center(child: CircularProgressIndicator(color: AppColors.primary)), errorWidget: (context, url, error) => const Center(child: Icon(Icons.broken_image, size: 80, color: AppColors.textHint)))); }) : const Center(child: Icon(Icons.settings, size: 160, color: AppColors.textHint))), if (images.length > 1) Positioned(bottom: 24, left: 0, right: 0, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(images.length, (index) { bool isActive = _currentImageIndex == index; return AnimatedContainer(duration: const Duration(milliseconds: 300), margin: const EdgeInsets.symmetric(horizontal: 4), width: isActive ? 24 : 8, height: 8, decoration: BoxDecoration(color: isActive ? AppColors.primary : Colors.white.withOpacity(0.5), borderRadius: BorderRadius.circular(4))); }))), Positioned(top: 50, left: 20, right: 20, child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [GestureDetector(onTap: () => Navigator.pop(context), child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: isDark ? AppColors.surfaceDark : Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.1), blurRadius: 10)]), child: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black, size: 24))), Row(children: [GestureDetector(onTap: _sharePart, child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: isDark ? AppColors.surfaceDark : Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.1), blurRadius: 10)]), child: Icon(Icons.share_outlined, color: isDark ? Colors.white : Colors.black, size: 24))), const SizedBox(width: 16), BlocBuilder<MarketCubit, MarketState>(builder: (context, state) { bool isSaved = cubit.isPartSaved(widget.partItem.id); return GestureDetector(onTap: () { if (CacheHelper.getData(key: 'uid') == null) { _showGuestDialog(context, AppLang.tr(context, 'save_ads') ?? ""); return; } cubit.toggleSavedPart(widget.partItem); }, child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: isDark ? AppColors.surfaceDark : Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.1), blurRadius: 10)]), child: Icon(isSaved ? Icons.favorite : Icons.favorite_border, color: isSaved ? Colors.redAccent : (isDark ? Colors.white : Colors.black), size: 24))); })])]))]); }

  Widget _buildTitleSection(BuildContext context, bool isDark, String title, String compatibility, String price) { return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 26, height: 1.2, color: isDark ? Colors.white : Colors.black87)), const SizedBox(height: 12), Row(children: [const Icon(Icons.check_circle, color: AppColors.primary, size: 18), const SizedBox(width: 6), Expanded(child: Text("${AppLang.tr(context, 'fits') ?? ''} $compatibility", style: const TextStyle(color: AppColors.textHint, fontSize: 15, fontWeight: FontWeight.w500)))]), const SizedBox(height: 12), Row(children: [const Icon(Icons.star, color: Colors.amber, size: 20), const SizedBox(width: 6), Text(_averageRating.toStringAsFixed(1), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87)), Text("  •  $_reviewsCount ${AppLang.tr(context, 'reviews') ?? ''}", style: const TextStyle(color: AppColors.textHint, fontSize: 14, fontWeight: FontWeight.w500))])])), const SizedBox(width: 16), Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(price, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w900, fontSize: 24))])]); }
  Widget _buildSpecsGrid(BuildContext context, bool isDark) { String conditionText = widget.partItem.condition.isNotEmpty ? AppLang.tr(context, widget.partItem.condition.toLowerCase()) ?? widget.partItem.condition : "-"; return GridView.count(crossAxisCount: 2, shrinkWrap: true, padding: EdgeInsets.zero, physics: const NeverScrollableScrollPhysics(), childAspectRatio: 2.0, mainAxisSpacing: 16, crossAxisSpacing: 16, children: [_buildSpecCard(AppLang.tr(context, 'condition') ?? '', conditionText, isDark), _buildSpecCard(AppLang.tr(context, 'type_part') ?? '', AppLang.tr(context, widget.partItem.itemType) ?? '', isDark)]); }
  Widget _buildSpecCard(String title, String value, bool isDark) { return Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: isDark ? const Color(0xFF1E262B) : const Color(0xFFF8F9FA), border: Border.all(color: isDark ? AppColors.borderDark : const Color(0xFFEEEEEE)), borderRadius: BorderRadius.circular(20)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Text(title, style: const TextStyle(color: AppColors.textHint, fontSize: 13, fontWeight: FontWeight.w500)), const SizedBox(height: 4), FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: isDark ? Colors.white : Colors.black87)))])); }

  Widget _buildReviewSection(BuildContext context, bool isDark) {
    bool canSubmit = (_userRating > 0 || _reviewController.text.trim().isNotEmpty) && !_isSubmittingReview;
    bool isEditing = _editingReviewId != null;

    return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: isDark ? AppColors.surfaceDark : Colors.white, border: Border.all(color: isDark ? AppColors.borderDark : const Color(0xFFEEEEEE)), borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.03), blurRadius: 15, offset: const Offset(0, 5))]),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(isEditing ? (AppLang.tr(context, 'edit_review_title') ?? "") : (AppLang.tr(context, 'write_review') ?? ''), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: isDark ? Colors.white : Colors.black87)), if (isEditing) TextButton(onPressed: () { setState(() { _editingReviewId = null; _reviewController.clear(); _userRating = 0.0; }); }, child: Text(AppLang.tr(context, 'cancel_btn') ?? "", style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)))]),
            const SizedBox(height: 16),
            Row(children: List.generate(5, (index) { return GestureDetector(onTap: () { setState(() { if (_userRating == index + 1.0) { _userRating = 0.0; } else { _userRating = index + 1.0; } }); }, child: Padding(padding: const EdgeInsets.only(right: 8.0), child: Icon(index < _userRating ? Icons.star_rounded : Icons.star_outline_rounded, color: Colors.amber, size: 34))); })),
            const SizedBox(height: 20),
            Container(decoration: BoxDecoration(color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F6F8), borderRadius: BorderRadius.circular(16), border: Border.all(color: isDark ? Colors.white24 : Colors.grey.shade300, width: 1)), child: TextField(controller: _reviewController, onChanged: (text) => setState(() {}), style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 15, height: 1.5), decoration: InputDecoration(hintText: AppLang.tr(context, 'share_experience_part') ?? '', hintStyle: TextStyle(color: AppColors.textHint.withOpacity(0.6), fontSize: 14), border: InputBorder.none, contentPadding: const EdgeInsets.all(16)), maxLines: 4)),
            const SizedBox(height: 20),
            Align(alignment: Alignment.centerRight, child: ElevatedButton(onPressed: _isSubmittingReview ? () {} : (canSubmit ? _submitReview : null), style: ElevatedButton.styleFrom(backgroundColor: isEditing ? Colors.green : AppColors.primary, disabledBackgroundColor: isDark ? const Color(0xFF333333) : Colors.grey.shade300, padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14), elevation: (canSubmit || _isSubmittingReview) ? 4 : 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))), child: Row(mainAxisSize: MainAxisSize.min, children: [Text(isEditing ? (AppLang.tr(context, 'update_btn') ?? "") : (AppLang.tr(context, 'submit') ?? ''), style: TextStyle(color: (canSubmit || _isSubmittingReview) ? Colors.white : AppColors.textHint, fontWeight: FontWeight.bold, fontSize: 16)), const SizedBox(width: 10), _isSubmittingReview ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)) : Icon(isEditing ? Icons.update_rounded : Icons.send_rounded, color: canSubmit ? Colors.white : AppColors.textHint, size: 18)])))
          ],
        )
    );
  }

  Widget _buildReviewsList(bool isDark) {
    String currentUserId = CacheHelper.getData(key: 'uid') ?? CacheHelper.getData(key: 'guest_device_id') ?? '';
    bool isAdmin = context.read<AuthCubit>().currentUser?.role == 'admin';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _reviewsList.map((review) {
        String reviewId = review['id'] ?? review['reviewId'] ?? '';
        String userName = review['userName'] ?? (AppLang.tr(context, 'gearup_user') ?? "");
        String userImage = review['userImage'] ?? "";
        bool hasComment = review['comment'] != null && review['comment'].toString().trim().isNotEmpty;
        bool isMyReview = review['userId'] == currentUserId;
        bool canManageReview = isMyReview || isAdmin;

        List<dynamic> likes = review['likes'] ?? [];
        bool isLiked = currentUserId.isNotEmpty && likes.contains(currentUserId);
        int likesCount = likes.length;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: isDark ? AppColors.surfaceDark : Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: isDark ? Colors.white10 : Colors.black12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.05), blurRadius: 10, offset: const Offset(0, 4))]),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(radius: 22, backgroundColor: AppColors.primary.withOpacity(0.2), backgroundImage: userImage.isNotEmpty ? NetworkImage(userImage) : null, child: userImage.isEmpty ? const Icon(Icons.person, size: 24, color: AppColors.primary) : null),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(userName, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: isDark ? Colors.white : Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Row(children: [Row(children: List.generate(5, (index) => Icon(index < (review['rating'] ?? 0) ? Icons.star_rounded : Icons.star_outline_rounded, color: Colors.amber, size: 16))), const SizedBox(width: 8), if (review['createdAt'] != null) Text(review['createdAt'].toString().substring(0, 10), style: const TextStyle(fontSize: 12, color: AppColors.textHint))])
                      ],
                    ),
                  ),
                  if (canManageReview)
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert, color: isDark ? Colors.white70 : Colors.black54),
                      color: isDark ? const Color(0xFF1E2834) : Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      onSelected: (value) { if (value == 'edit') _startEditingReview(review); if (value == 'delete') _deleteReview(reviewId, review['userId'] ?? ''); },
                      itemBuilder: (context) => [
                        if (isMyReview) PopupMenuItem(value: 'edit', child: Row(children: [const Icon(Icons.edit_outlined, color: AppColors.primary, size: 20), const SizedBox(width: 10), Text(AppLang.tr(context, 'edit_btn') ?? "")])),
                        PopupMenuItem(value: 'delete', child: Row(children: [const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20), const SizedBox(width: 10), Text(AppLang.tr(context, 'delete_review_btn') ?? "", style: const TextStyle(color: Colors.redAccent))])),
                      ],
                    )
                ],
              ),
              if (hasComment) ...[const SizedBox(height: 16), Text(review['comment'], style: TextStyle(color: isDark ? Colors.white.withOpacity(0.85) : Colors.black87, height: 1.6, fontSize: 15))],
              const SizedBox(height: 16),
              Divider(color: isDark ? Colors.white10 : Colors.black12, height: 1),
              const SizedBox(height: 8),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () async {
                      if (currentUserId.isEmpty || currentUserId.startsWith('guest_')) { _showGuestDialog(context, AppLang.tr(context, 'like_comments') ?? ""); return; }
                      bool newLikeState = !isLiked;
                      setState(() { if (newLikeState) { likes.add(currentUserId); } else { likes.remove(currentUserId); } });
                      await context.read<MarketCubit>().toggleReviewLike(carId: widget.partItem.id, reviewId: reviewId, isPart: true, isLiking: newLikeState);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(color: isLiked ? AppColors.primary.withOpacity(0.1) : Colors.transparent, borderRadius: BorderRadius.circular(20)),
                      child: Row(children: [AnimatedSwitcher(duration: const Duration(milliseconds: 300), child: Icon(isLiked ? Icons.thumb_up_alt_rounded : Icons.thumb_up_off_alt_rounded, key: ValueKey(isLiked), color: isLiked ? AppColors.primary : Colors.grey, size: 20)), const SizedBox(width: 8), Text(likesCount > 0 ? "$likesCount ${AppLang.tr(context, 'like')}" : (AppLang.tr(context, 'like') ?? ""), style: TextStyle(color: isLiked ? AppColors.primary : Colors.grey, fontWeight: FontWeight.bold, fontSize: 14))]),
                    ),
                  ),
                  if (!isMyReview)
                    GestureDetector(
                      onTap: () {
                        if (currentUserId.isEmpty || currentUserId.startsWith('guest_')) { _showGuestDialog(context, AppLang.tr(context, 'report_comments') ?? ""); return; }
                        _reportReview(reviewId, review['comment'] ?? AppLang.tr(context, 'no_text_comment'));
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(children: [const Icon(Icons.outlined_flag_rounded, color: Colors.orange, size: 20), const SizedBox(width: 6), Text(AppLang.tr(context, 'report') ?? "", style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 14))]),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class FullScreenImageViewer extends StatefulWidget {
  final List<String> images; final int initialIndex;
  const FullScreenImageViewer({super.key, required this.images, required this.initialIndex});
  @override State<FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}
class _FullScreenImageViewerState extends State<FullScreenImageViewer> {
  late int currentIndex; bool _showCounter = true; Timer? _hideTimer;
  @override void initState() { super.initState(); currentIndex = widget.initialIndex; _startHideTimer(); }
  void _startHideTimer() { _hideTimer?.cancel(); _hideTimer = Timer(const Duration(seconds: 3), () { if (mounted) { setState(() { _showCounter = false; }); } }); }
  void _onUserInteraction() { if (!_showCounter) { setState(() { _showCounter = true; }); } _startHideTimer(); }
  @override void dispose() { _hideTimer?.cancel(); super.dispose(); }
  @override Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _onUserInteraction(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Stack(children: [Container(color: Colors.transparent, width: double.infinity, height: double.infinity), PageView.builder(itemCount: widget.images.length, controller: PageController(initialPage: widget.initialIndex), onPageChanged: (index) { setState(() { currentIndex = index; }); _onUserInteraction(); }, itemBuilder: (context, index) { return Center(child: GestureDetector(onTap: () {}, child: InteractiveViewer(panEnabled: true, minScale: 0.5, maxScale: 4.0, child: CachedNetworkImage(imageUrl: widget.images[index], fit: BoxFit.contain, placeholder: (context, url) => const CircularProgressIndicator(color: AppColors.primary), errorWidget: (context, url, error) => const Icon(Icons.error, color: Colors.white, size: 60))))); }), if (widget.images.length > 1) Positioned(top: 60, left: 0, right: 0, child: AnimatedOpacity(opacity: _showCounter ? 1.0 : 0.0, duration: const Duration(milliseconds: 300), child: Center(child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), borderRadius: BorderRadius.circular(16)), child: Directionality(textDirection: TextDirection.ltr, child: Text("${currentIndex + 1} / ${widget.images.length}", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.5)))))))]),
        ),
      ),
    );
  }
}