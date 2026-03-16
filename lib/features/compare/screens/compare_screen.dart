import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/colors.dart';
import '../../../core/localization/app_lang.dart';
import '../../home/screens/car_details_screen.dart';
import '../../marketplace/cubit/market_cubit.dart';
import '../../marketplace/cubit/market_state.dart';
import '../../marketplace/models/car_model.dart';

class CompareScreen extends StatelessWidget {
  const CompareScreen({super.key});

  List<Color?> _getComparisonColors(List<String> values, String specType, bool isDark) {
    if (values.length < 2) return List.filled(values.length, null);

    List<double> parsedValues = values.map((val) {
      String clean = val.replaceAll(RegExp(r'[^0-9.]'), '');
      return double.tryParse(clean) ?? -1.0;
    }).toList();

    if (parsedValues.contains(-1.0)) return List.filled(values.length, null);

    double maxVal = parsedValues.reduce((curr, next) => curr > next ? curr : next);
    double minVal = parsedValues.reduce((curr, next) => curr < next ? curr : next);

    if (maxVal == minVal) return List.filled(values.length, null);

    bool lowerIsBetter = specType == 'price' || specType == 'mileage';

    return parsedValues.map((val) {
      if (lowerIsBetter) {
        if (val == minVal) return Colors.green;
        if (val == maxVal) return Colors.redAccent;
        return null;
      } else {
        if (val == maxVal) return Colors.green;
        if (val == minVal) return Colors.redAccent;
        return null;
      }
    }).toList();
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
        automaticallyImplyLeading: false,
        title: Text(
          AppLang.tr(context, 'compare_vehicles') ?? 'مقارنة السيارات',
          style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w900, fontSize: 22),
        ),
      ),
      body: BlocBuilder<MarketCubit, MarketState>(
        builder: (context, state) {
          final cubit = context.read<MarketCubit>();
          final List<CarModel> compareCars = cubit.compareCarsList;
          final int carCount = compareCars.length;

          if (compareCars.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.compare_arrows_rounded, size: 80, color: AppColors.textHint.withOpacity(0.3)),
                  const SizedBox(height: 20),
                  Text(
                    AppLang.tr(context, 'no_cars_to_compare') ?? "لا توجد سيارات للمقارنة",
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textHint, fontSize: 18),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    AppLang.tr(context, 'add_cars_from_home') ?? "قم بإضافة سيارات من الشاشة الرئيسية",
                    style: TextStyle(color: isDark ? Colors.white54 : AppColors.textSecondary, fontSize: 14),
                  ),
                ],
              ),
            );
          }

          return SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                    child: Text(
                      AppLang.tr(context, 'analyze_specs') ?? 'تحليل المواصفات جنباً إلى جنب',
                      style: TextStyle(color: isDark ? Colors.white70 : AppColors.textSecondary, fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: compareCars.map((car) {
                        List<String> allPrices = compareCars.map((c) => c.price.toString()).toList();
                        List<Color?> priceColors = _getComparisonColors(allPrices, 'price', isDark);
                        int carIndex = compareCars.indexOf(car);
                        Color? priceColor = priceColors[carIndex];

                        return Expanded(child: _buildCarHeader(context, car, isDark, cubit, priceColor, carCount));
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 24),
                  _buildModernComparisonTable(context, compareCars, isDark, carCount),
                  const SizedBox(height: 60),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCarHeader(BuildContext context, CarModel car, bool isDark, MarketCubit cubit, Color? priceColor, int carCount) {
    final imageUrl = car.images.isNotEmpty ? car.images.first : null;
    const fallbackImage = 'https://images.unsplash.com/photo-1552519507-da3b142c6e3d?q=80&w=800&auto=format&fit=crop';
    final price = "${AppLang.tr(context, 'currency_egp') ?? 'EGP'} ${car.price.toStringAsFixed(0)}";

    double imageHeight = carCount == 3 ? 105 : 150;
    double modelFontSize = carCount == 3 ? 13 : 16;
    double priceFontSize = carCount == 3 ? 13 : 16;
    double buttonFontSize = carCount == 3 ? 10 : 12;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => CarDetailsScreen(car: car, isPromoted: false)));
            },
            child: Column(
              children: [
                Container(
                  height: imageHeight,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF161E27) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isDark ? Colors.white10 : AppColors.borderLight),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.05), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: imageUrl != null
                        ? CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.cover, errorWidget: (c, u, e) => CachedNetworkImage(imageUrl: fallbackImage, fit: BoxFit.cover))
                        : CachedNetworkImage(imageUrl: fallbackImage, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(height: 12),
                Text(car.make.toUpperCase(), style: const TextStyle(color: AppColors.textHint, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0), textAlign: TextAlign.center),
                const SizedBox(height: 4),
                Text(car.model, style: TextStyle(fontWeight: FontWeight.w900, fontSize: modelFontSize, color: isDark ? Colors.white : Colors.black87), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(price, style: TextStyle(color: priceColor ?? AppColors.primary, fontWeight: FontWeight.w900, fontSize: priceFontSize)),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => cubit.toggleCompareCar(car, context),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: carCount == 3 ? 8 : 16, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.delete_outline_rounded, size: carCount == 3 ? 14 : 16, color: Colors.redAccent),
                  const SizedBox(width: 4),
                  Text(AppLang.tr(context, 'remove') ?? "إزالة", style: TextStyle(color: Colors.redAccent, fontSize: buttonFontSize, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernComparisonTable(BuildContext context, List<CarModel> cars, bool isDark, int carCount) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: Column(
        children: [
          _buildSpecRowCard(context, AppLang.tr(context, 'year') ?? "سنة الصنع", cars.map((c) => c.year).toList(), 'year', isDark, carCount),
          _buildSpecRowCard(context, AppLang.tr(context, 'cc') ?? "سعة المحرك", cars.map((c) => c.cc.isNotEmpty ? c.cc : "N/A").toList(), 'cc', isDark, carCount),
          _buildSpecRowCard(context, AppLang.tr(context, 'hp') ?? "قوة الحصان", cars.map((c) => c.hp.isNotEmpty ? c.hp : "N/A").toList(), 'hp', isDark, carCount),
          _buildSpecRowCard(context, AppLang.tr(context, 'torque') ?? "عزم الدوران", cars.map((c) => c.torque.isNotEmpty ? c.torque : "N/A").toList(), 'torque', isDark, carCount),
          _buildSpecRowCard(context, AppLang.tr(context, 'mileage') ?? "المسافة", cars.map((c) => c.mileage.isNotEmpty ? "${c.mileage} ${AppLang.tr(context, 'km') ?? 'km'}" : "0 ${AppLang.tr(context, 'km') ?? 'km'}").toList(), 'mileage', isDark, carCount),
          _buildSpecRowCard(context, AppLang.tr(context, 'luggage_capacity') ?? "الشنطة", cars.map((c) => c.luggageCapacity.isNotEmpty ? c.luggageCapacity : "N/A").toList(), 'luggage', isDark, carCount),
          _buildSpecRowCard(context, AppLang.tr(context, 'transmission') ?? "ناقل الحركة", cars.map((c) => c.transmission.isNotEmpty ? (AppLang.tr(context, c.transmission.toLowerCase()) ?? c.transmission) : "N/A").toList(), 'text', isDark, carCount),
          _buildSpecRowCard(context, AppLang.tr(context, 'condition') ?? "الحالة", cars.map((c) => AppLang.tr(context, c.condition.toLowerCase()) ?? c.condition).toList(), 'text', isDark, carCount),
        ],
      ),
    );
  }

  Widget _buildSpecRowCard(BuildContext context, String title, List<String> values, String specType, bool isDark, int carCount) {
    List<Color?> comparisonColors = _getComparisonColors(values, specType, isDark);
    double valFontSize = carCount == 3 ? 13 : 16;
    double titleFontSize = carCount == 3 ? 12 : 14;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161E27) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white10 : Colors.transparent),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
                color: isDark ? AppColors.primary.withOpacity(0.15) : AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12)
            ),
            child: Text(
              title,
              style: TextStyle(
                  color: isDark ? Colors.blue[200] : AppColors.primary,
                  fontSize: titleFontSize,
                  fontWeight: FontWeight.bold
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: values.asMap().entries.map((entry) {
              int idx = entry.key;
              String val = entry.value;
              Color? valColor = comparisonColors[idx];
              Color defaultColor = isDark ? Colors.white : Colors.black87;
              return Expanded(
                child: Text(
                  val,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: valColor != null ? FontWeight.w900 : FontWeight.bold,
                    color: valColor ?? defaultColor,
                    fontSize: valFontSize,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}