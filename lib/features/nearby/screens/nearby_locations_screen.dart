import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/colors.dart';
import '../../../core/localization/app_lang.dart';

class NearbyLocationsScreen extends StatefulWidget {
  const NearbyLocationsScreen({super.key});

  @override
  State<NearbyLocationsScreen> createState() => _NearbyLocationsScreenState();
}

class _NearbyLocationsScreenState extends State<NearbyLocationsScreen> {
  bool isServiceCenterActive = true;

  final Completer<GoogleMapController> _mapController = Completer<GoogleMapController>();
  final ScrollController _scrollController = ScrollController();

  LatLng? _userLocation;
  bool _isLoadingLocation = true;
  bool _isLoadingMore = false;
  String _locationError = '';
  Set<Marker> _markers = {};

  List<Map<String, dynamic>> _serviceCenters = [];
  List<Map<String, dynamic>> _showrooms = [];
  List<Map<String, dynamic>> _displayedPlaces = [];

  int _distanceMultiplier = 1;

  @override
  void initState() {
    super.initState();
    _getUserLocation();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 50) {
        if (!_isLoadingMore) {
          _loadMorePlaces();
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _getUserLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    try {
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showError('location_services_disabled');
        return;
      }

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showError('location_permission_denied');
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        _showError('location_permission_permanently_denied');
        return;
      }

      // 🔥 حماية V2: إضافة timeLimit عشان الأبلكيشن ميهنجش لو مفيش GPS 🔥
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      LatLng currentLocation = LatLng(position.latitude, position.longitude);

      if (mounted) {
        setState(() {
          _userLocation = currentLocation;
          _isLoadingLocation = false;
        });

        _generateSmartMockData(currentLocation, append: false);
        _updateDisplayedPlaces();
        _goToUserLocation();
      }
    } catch (e) {
      LatLng fallback = const LatLng(30.0444, 31.2357); // Cairo fallback
      if (mounted) {
        setState(() {
          _userLocation = fallback;
          _isLoadingLocation = false;
        });
        _generateSmartMockData(fallback, append: false);
        _updateDisplayedPlaces();
        _goToUserLocation();
      }
    }
  }

  void _showError(String errorKey) {
    setState(() {
      _locationError = errorKey;
      _isLoadingLocation = false;
    });
  }

  Future<void> _goToUserLocation() async {
    if (_userLocation == null) return;
    final GoogleMapController controller = await _mapController.future;
    controller.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(target: _userLocation!, zoom: 14.5),
    ));
  }

  Future<void> _loadMorePlaces() async {
    if (_userLocation == null) return;

    setState(() => _isLoadingMore = true);
    await Future.delayed(const Duration(seconds: 1));

    // 🔥 حماية V2: نتأكد إن الشاشة لسه موجودة قبل الـ setState 🔥
    if (!mounted) return;

    _distanceMultiplier++;
    _generateSmartMockData(_userLocation!, append: true);
    _updateDisplayedPlaces();

    setState(() => _isLoadingMore = false);
  }

  void _generateSmartMockData(LatLng center, {required bool append}) {
    final Random random = Random();

    bool isRtl = Directionality.of(context) == TextDirection.rtl;

    List<String> serviceNames = isRtl
        ? ["مركز صيانة الأمل", "المهندس أوتو سيرفيس", "برو كار كير", "مركز العبور المعتمد", "إليت أوتو لصيانة السيارات", "مركز النور", "صيانة الأبطال", "جير أب سيرفيس"]
        : ["Al-Amal Service Center", "El-Mohandes Auto Service", "Pro Car Care", "El-Obour Certified Center", "Elite Auto Service", "Al-Nour Center", "Heroes Maintenance", "Gear Up Service"];

    List<String> showroomNames = isRtl
        ? ["توكيل تويوتا المعتمد", "معرض جي أوتو", "أباظة للسيارات", "المصرية للسيارات", "معرض درايف زون", "أوتو ماك", "معرض النخبة", "أوتو سمارت"]
        : ["Toyota Authorized Dealer", "G-Auto Showroom", "Abaza Cars", "Egyptian Automotive", "Drive Zone", "Auto Mac", "Elite Showroom", "Auto Smart"];

    String kmLabel = AppLang.tr(context, 'km_label') ?? 'كم';
    String meterLabel = AppLang.tr(context, 'meter_label') ?? 'متر';

    if (!append) {
      _serviceCenters.clear();
      _showrooms.clear();
      _distanceMultiplier = 1;
    }

    int startIndex = _serviceCenters.length;

    for (int i = 0; i < 5; i++) {
      double latOffset = (random.nextDouble() - 0.5) * 0.05 * _distanceMultiplier;
      double lngOffset = (random.nextDouble() - 0.5) * 0.05 * _distanceMultiplier;

      LatLng pLoc = LatLng(center.latitude + latOffset, center.longitude + lngOffset);
      double dist = Geolocator.distanceBetween(center.latitude, center.longitude, pLoc.latitude, pLoc.longitude);

      _serviceCenters.add({
        'id': 's${startIndex + i}',
        'name': serviceNames[random.nextInt(serviceNames.length)],
        'phone': '010${random.nextInt(90000000) + 10000000}',
        'lat': pLoc.latitude, 'lng': pLoc.longitude, 'distanceMeters': dist,
        'distanceText': dist > 1000 ? '${(dist / 1000).toStringAsFixed(1)} $kmLabel' : '${dist.toStringAsFixed(0)} $meterLabel',
      });
    }

    for (int i = 0; i < 5; i++) {
      double latOffset = (random.nextDouble() - 0.5) * 0.05 * _distanceMultiplier;
      double lngOffset = (random.nextDouble() - 0.5) * 0.05 * _distanceMultiplier;

      LatLng pLoc = LatLng(center.latitude + latOffset, center.longitude + lngOffset);
      double dist = Geolocator.distanceBetween(center.latitude, center.longitude, pLoc.latitude, pLoc.longitude);

      _showrooms.add({
        'id': 'w${startIndex + i}',
        'name': showroomNames[random.nextInt(showroomNames.length)],
        'phone': '011${random.nextInt(90000000) + 10000000}',
        'lat': pLoc.latitude, 'lng': pLoc.longitude, 'distanceMeters': dist,
        'distanceText': dist > 1000 ? '${(dist / 1000).toStringAsFixed(1)} $kmLabel' : '${dist.toStringAsFixed(0)} $meterLabel',
      });
    }

    _serviceCenters.sort((a, b) => a['distanceMeters'].compareTo(b['distanceMeters']));
    _showrooms.sort((a, b) => a['distanceMeters'].compareTo(b['distanceMeters']));
  }

  void _updateDisplayedPlaces() {
    setState(() {
      _displayedPlaces = isServiceCenterActive ? _serviceCenters : _showrooms;
      _generateMarkers();
    });
  }

  void _generateMarkers() {
    if (_userLocation == null) return;
    _markers.clear();

    _markers.add(
      Marker(
        markerId: const MarkerId('user_loc'),
        position: _userLocation!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: InfoWindow(title: AppLang.tr(context, 'current_location') ?? 'موقعي الحالي'),
      ),
    );

    double hue = isServiceCenterActive ? BitmapDescriptor.hueOrange : BitmapDescriptor.hueRed;

    for (var place in _displayedPlaces) {
      _markers.add(
        Marker(
          markerId: MarkerId(place['id']),
          position: LatLng(place['lat'], place['lng']),
          icon: BitmapDescriptor.defaultMarkerWithHue(hue),
          infoWindow: InfoWindow(title: place['name'], snippet: place['distanceText']),
        ),
      );
    }
  }

  // 🔥 حماية V2: استخدام Universal Link عشان يفتح جوجل مابز على أي نظام تشغيل (iOS/Android) 🔥
  Future<void> _openGoogleMapsDirections(double destLat, double destLng) async {
    final String universalMapUrl = 'https://www.google.com/maps/dir/?api=1&destination=$destLat,$destLng&travelmode=driving';
    final Uri uri = Uri.parse(universalMapUrl);

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLang.tr(context, 'cannot_open_maps') ?? 'لا يمكن فتح الخرائط')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLang.tr(context, 'cannot_open_maps') ?? 'لا يمكن فتح الخرائط')));
      }
    }
  }

  void _openFullScreenMap(BuildContext context, bool isDark) {
    if (_userLocation == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          body: Stack(
            children: [
              GoogleMap(
                initialCameraPosition: CameraPosition(target: _userLocation!, zoom: 13.0),
                markers: _markers,
                myLocationEnabled: true,
                myLocationButtonEnabled: true,
                zoomControlsEnabled: false,
                onMapCreated: (GoogleMapController controller) {
                  if (isDark) {
                    controller.setMapStyle('[{"elementType":"geometry","stylers":[{"color":"#242f3e"}]},{"elementType":"labels.text.fill","stylers":[{"color":"#746855"}]},{"elementType":"labels.text.stroke","stylers":[{"color":"#242f3e"}]},{"featureType":"administrative.locality","elementType":"labels.text.fill","stylers":[{"color":"#d59563"}]},{"featureType":"poi","elementType":"labels.text.fill","stylers":[{"color":"#d59563"}]},{"featureType":"poi.park","elementType":"geometry","stylers":[{"color":"#263c3f"}]},{"featureType":"poi.park","elementType":"labels.text.fill","stylers":[{"color":"#6b9a76"}]},{"featureType":"road","elementType":"geometry","stylers":[{"color":"#38414e"}]},{"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#212a37"}]},{"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#9ca5b3"}]},{"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#746855"}]},{"featureType":"road.highway","elementType":"geometry.stroke","stylers":[{"color":"#1f2835"}]},{"featureType":"road.highway","elementType":"labels.text.fill","stylers":[{"color":"#f3d19c"}]},{"featureType":"water","elementType":"geometry","stylers":[{"color":"#17263c"}]},{"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#515c6d"}]},{"featureType":"water","elementType":"labels.text.stroke","stylers":[{"color":"#17263c"}]}]');
                  }
                },
              ),
              Positioned(
                top: 50,
                left: 20,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: isDark ? const Color(0xFF161E27) : Colors.white, shape: BoxShape.circle, boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)]),
                    child: Icon(Icons.close, color: isDark ? Colors.white : Colors.black),
                  ),
                ),
              ),
            ],
          ),
        ),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(20.0),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0A0F14) : Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.05), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: isDark ? const Color(0xFF161E27) : Colors.white, border: Border.all(color: isDark ? Colors.white10 : AppColors.borderLight), borderRadius: BorderRadius.circular(12)),
                      child: Icon(Icons.arrow_back, size: 22, color: isDark ? Colors.white : AppColors.secondary),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(AppLang.tr(context, 'nearby_locations') ?? 'أماكن قريبة', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: isDark ? Colors.white : AppColors.secondary, letterSpacing: 0.5)),
                      const SizedBox(height: 4),
                      Text(AppLang.tr(context, 'service_and_showrooms') ?? 'مراكز صيانة ومعارض', style: const TextStyle(fontSize: 13, color: AppColors.textHint, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: GestureDetector(
                onTap: () => _openFullScreenMap(context, isDark),
                child: Container(
                  height: 220,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 8))],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Stack(
                      children: [
                        _isLoadingLocation
                            ? Container(color: isDark ? const Color(0xFF161E27) : AppColors.surfaceLight, child: const Center(child: CircularProgressIndicator(color: AppColors.primary)))
                            : _locationError.isNotEmpty
                            ? Container(
                          color: isDark ? const Color(0xFF161E27) : AppColors.surfaceLight,
                          child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.location_off, size: 40, color: Colors.redAccent), const SizedBox(height: 10), Text(AppLang.tr(context, _locationError) ?? 'خطأ في الموقع', style: const TextStyle(color: AppColors.textHint, fontWeight: FontWeight.bold))])),
                        )
                            : AbsorbPointer(
                          child: GoogleMap(
                            initialCameraPosition: CameraPosition(target: _userLocation ?? const LatLng(30.0444, 31.2357), zoom: 14.5),
                            markers: _markers,
                            myLocationEnabled: true,
                            myLocationButtonEnabled: false,
                            zoomControlsEnabled: false,
                            onMapCreated: (GoogleMapController controller) {
                              if (!_mapController.isCompleted) {
                                _mapController.complete(controller);
                              }
                              if (isDark) {
                                controller.setMapStyle('[{"elementType":"geometry","stylers":[{"color":"#242f3e"}]},{"elementType":"labels.text.fill","stylers":[{"color":"#746855"}]},{"elementType":"labels.text.stroke","stylers":[{"color":"#242f3e"}]},{"featureType":"administrative.locality","elementType":"labels.text.fill","stylers":[{"color":"#d59563"}]},{"featureType":"poi","elementType":"labels.text.fill","stylers":[{"color":"#d59563"}]},{"featureType":"poi.park","elementType":"geometry","stylers":[{"color":"#263c3f"}]},{"featureType":"poi.park","elementType":"labels.text.fill","stylers":[{"color":"#6b9a76"}]},{"featureType":"road","elementType":"geometry","stylers":[{"color":"#38414e"}]},{"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#212a37"}]},{"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#9ca5b3"}]},{"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#746855"}]},{"featureType":"road.highway","elementType":"geometry.stroke","stylers":[{"color":"#1f2835"}]},{"featureType":"road.highway","elementType":"labels.text.fill","stylers":[{"color":"#f3d19c"}]},{"featureType":"water","elementType":"geometry","stylers":[{"color":"#17263c"}]},{"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#515c6d"}]},{"featureType":"water","elementType":"labels.text.stroke","stylers":[{"color":"#17263c"}]}]');
                              }
                            },
                          ),
                        ),
                        if (!_isLoadingLocation && _locationError.isEmpty)
                          Positioned(bottom: 12, right: 12, child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.fullscreen_rounded, color: Colors.white, size: 24))),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: isDark ? const Color(0xFF161E27) : Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: isDark ? Colors.white10 : Colors.black12)),
                child: Row(
                  children: [
                    Expanded(child: _buildTabButton(title: AppLang.tr(context, 'service_center') ?? 'مراكز خدمة', icon: Icons.build_outlined, isActive: isServiceCenterActive, isDark: isDark, activeColor: AppColors.primary, onTap: () { setState(() { isServiceCenterActive = true; _updateDisplayedPlaces(); }); })),
                    Expanded(child: _buildTabButton(title: AppLang.tr(context, 'showroom') ?? 'معارض', icon: Icons.directions_car_outlined, isActive: !isServiceCenterActive, isDark: isDark, activeColor: const Color(0xFFE57373), onTap: () { setState(() { isServiceCenterActive = false; _updateDisplayedPlaces(); }); })),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            Expanded(
              child: _displayedPlaces.isEmpty && !_isLoadingLocation
                  ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.not_listed_location_outlined, size: 60, color: AppColors.textHint.withOpacity(0.4)), const SizedBox(height: 12), Text(AppLang.tr(context, 'no_data_currently') ?? 'لا توجد بيانات حالياً', style: const TextStyle(color: AppColors.textHint, fontWeight: FontWeight.bold))]))
                  : ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                physics: const BouncingScrollPhysics(),
                itemCount: _displayedPlaces.length + (_isLoadingMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _displayedPlaces.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20.0),
                      child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                    );
                  }

                  final place = _displayedPlaces[index];
                  return _buildPremiumLocationCard(
                    name: place['name'],
                    phone: place['phone'],
                    distance: place['distanceText'],
                    icon: isServiceCenterActive ? Icons.build_rounded : Icons.directions_car_rounded,
                    gradientStart: isServiceCenterActive ? AppColors.primary : const Color(0xFFE57373),
                    gradientEnd: isServiceCenterActive ? const Color(0xFF1E3A8A) : const Color(0xFFC62828),
                    isDark: isDark,
                    onGetDirections: () => _openGoogleMapsDirections(place['lat'], place['lng']),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton({required String title, required IconData icon, required bool isActive, required bool isDark, required Color activeColor, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(color: isActive ? activeColor : Colors.transparent, borderRadius: BorderRadius.circular(20), boxShadow: isActive ? [BoxShadow(color: activeColor.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 4))] : []),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [Icon(icon, size: 18, color: isActive ? Colors.white : AppColors.textHint), const SizedBox(width: 8), Text(title, style: TextStyle(color: isActive ? Colors.white : AppColors.textHint, fontWeight: isActive ? FontWeight.bold : FontWeight.w600, fontSize: 14))],
        ),
      ),
    );
  }

  Widget _buildPremiumLocationCard({required String name, required String phone, required String distance, required IconData icon, required Color gradientStart, required Color gradientEnd, required bool isDark, required VoidCallback onGetDirections}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: isDark ? const Color(0xFF161E27) : Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFEEEEEE)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.4 : 0.05), blurRadius: 20, offset: const Offset(0, 10))]),
      child: Column(
        children: [
          Row(
            children: [
              Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(gradient: LinearGradient(colors: [gradientStart, gradientEnd], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: gradientStart.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 4))]), child: Icon(icon, color: Colors.white, size: 28)),
              const SizedBox(width: 20),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: isDark ? Colors.white : AppColors.secondary), maxLines: 2, overflow: TextOverflow.ellipsis), const SizedBox(height: 10), Row(children: [Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: AppColors.textHint.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.phone_enabled_rounded, size: 12, color: AppColors.textHint)), const SizedBox(width: 8), Text(phone, style: TextStyle(color: isDark ? Colors.white70 : AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.bold))]), const SizedBox(height: 6), Row(children: [Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: AppColors.textHint.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.location_on_rounded, size: 12, color: AppColors.textHint)), const SizedBox(width: 8), Text(distance, style: TextStyle(color: isDark ? Colors.white70 : AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.bold))])])),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: onGetDirections, icon: const Icon(Icons.navigation_rounded, color: Colors.white, size: 20), label: Text(AppLang.tr(context, 'get_directions') ?? 'احصل على الاتجاهات', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.5)), style: ElevatedButton.styleFrom(backgroundColor: gradientStart, padding: const EdgeInsets.symmetric(vertical: 16), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))))),
        ],
      ),
    );
  }
}