import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:dio/dio.dart';
import 'market_state.dart';
import '../models/car_model.dart';
import '../models/news_model.dart';
import '../../../core/local_storage/cache_helper.dart';
import '../../../core/localization/app_lang.dart';
import '../../../core/utils/notification_helper.dart';

class MarketDefaultState extends MarketState {}

class MarketCubit extends Cubit<MarketState> {
  MarketCubit() : super(MarketInitial()) {
    Future.microtask(() => loadCompareCarsFromCache());
  }
  bool hasReachedMaxSearch = false; // 🔥 عشان نعرف السيرفر خلص ولا لأ
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final cloudinary = CloudinaryPublic('dfawviyf3', 'zclpevpk', cache: false);
  final Dio _dio = Dio();

// 🔥 رابط السيرفر الموحد الجديد بتاع Back4App (مفيش أي API Keys مكشوفة هنا خالص) 🔥
  final String _baseUrl = 'https://gear-up-backend.vercel.app';
  int _dynamicSequenceIndex = 0;
  List<CarModel> carsList = [];
  List<File> selectedCarImages = [];
  final ImagePicker _picker = ImagePicker();

  final int _currentYear = DateTime.now().year;

  final List<String> _premiumFallbacks = [
    'https://images.unsplash.com/photo-1492144534655-ae79c964c9d7',
    'https://images.unsplash.com/photo-1503376760367-175510e14a1c',
    'https://images.unsplash.com/photo-1552519507-da3b142c6e3d',
    'https://images.unsplash.com/photo-1583121274602-3e2820c69888',
  ];

  final Map<String, String> _localImageCache = {};

  List<CarModel> promotedCarsList = [];
  List<CarModel> promotedPartsList = [];
  List<CarModel> newCarsList = [];
  List<CarModel> usedCarsList = [];
  bool isFetchingExternal = false;
  List<String> _loadedHomeModels = [];
  Set<String> shownDynamicCarIds = {};
  Map<String, String> generatedCarDescriptions = {};
  CancelToken? descriptionCancelToken;

  Future<void> generateCarDescription(String carId, String make, String model, String year, bool isPromoted) async {
    bool isDummyDescription = generatedCarDescriptions[carId] != null && generatedCarDescriptions[carId]!.contains('بتصميم عصري');
    if (generatedCarDescriptions.containsKey(carId) && !isDummyDescription) { emit(CarDescriptionUpdatedState()); return; }
    descriptionCancelToken?.cancel("تم الخروج من الشاشة"); descriptionCancelToken = CancelToken();
    String finalDescription = "";
    try {
      // 🔥 تم التوجيه لسيرفر Node.js الخاص بك بدلاً من Groq مباشرة 🔥
      final aiResponse = await _dio.post('$_baseUrl/api/ai/chat', cancelToken: descriptionCancelToken, options: Options(receiveTimeout: const Duration(seconds: 15), sendTimeout: const Duration(seconds: 15)), data: {"messages": [{"role": "system", "content": "أنت خبير سيارات محترف في السوق المصري. اكتب وصفاً تسويقياً جذاباً ومختصراً باللغة العربية (في حدود سطرين) يبرز مميزات سيارة محددة. لا تستخدم أي علامات تنسيق مثل النجمة **."}, {"role": "user", "content": "اكتب وصفاً احترافياً لسيارة $make $model موديل $year."}], "temperature": 0.7});

      if (aiResponse.statusCode == 200 && aiResponse.data != null) {
        var choices = aiResponse.data['choices'];
        if (choices != null && choices.isNotEmpty) {
          var message = choices[0]['message'];
          if (message != null && message['content'] != null) { finalDescription = message['content'].toString().replaceAll('**', '').trim(); } else { throw Exception("Server sent null content"); }
        } else { throw Exception("Server sent empty choices"); }
      } else { throw Exception("Server API Error"); }
    } catch (e) {
      if (e is DioException && CancelToken.isCancel(e)) return;
      finalDescription = "سيارة $make $model بتصميم عصري وأداء قوي. لمعاينة السيارة ومعرفة تفاصيل أكثر، يرجى التواصل مع البائع مباشرة.";
    }
    generatedCarDescriptions[carId] = finalDescription;
    List<CarModel> targetList = isPromoted ? promotedCarsList : carsList;
    int index = targetList.indexWhere((c) => c.id == carId);
    if (index != -1) { CarModel oldCar = targetList[index]; targetList[index] = CarModel(id: oldCar.id, sellerId: oldCar.sellerId, itemType: oldCar.itemType, make: oldCar.make, model: oldCar.model, year: oldCar.year, price: oldCar.price, condition: oldCar.condition, description: finalDescription, images: oldCar.images, createdAt: oldCar.createdAt, hp: oldCar.hp, cc: oldCar.cc, torque: oldCar.torque, transmission: oldCar.transmission, luggageCapacity: oldCar.luggageCapacity, mileage: oldCar.mileage, sellerName: oldCar.sellerName, sellerPhone: oldCar.sellerPhone, sellerLocation: oldCar.sellerLocation, sellerEmail: oldCar.sellerEmail, rating: oldCar.rating, reviewsCount: oldCar.reviewsCount, viewsCount: oldCar.viewsCount); }
    emit(CarDescriptionUpdatedState());
    try { String collectionName = isPromoted ? 'promoted_cars' : 'cars'; await _firestore.collection(collectionName).doc(carId).update({'description': finalDescription}); } catch (e) {}
  }

  void cancelDescriptionFetch() { descriptionCancelToken?.cancel("المستخدم قفل الشاشة"); }

  List<CarModel> searchResults = [];
  bool isSearchingMore = false;
  int searchApiOffset = 0;
  List<String> _loadedSearchModels = [];
  int _currentSearchYear = DateTime.now().year;

  final Map<String, String> _carAliases = {
    'بي ام': 'bmw', 'بى ام': 'bmw', 'بي ام دبليو': 'bmw', 'bm': 'bmw', 'مرسيدس': 'mercedes', 'مارسيدس': 'mercedes', 'benz': 'mercedes', 'mercedes-benz': 'mercedes', 'شيفورليه': 'chevrolet', 'شيفروليه': 'chevrolet', 'شفروليه': 'chevrolet', 'chevy': 'chevrolet', 'دبابة': 'chevrolet', 'تويوتا': 'toyota', 'تايوتا': 'toyota', 'هيونداي': 'hyundai', 'هونداي': 'hyundai', 'هونداى': 'hyundai', 'كيا': 'kia', 'كيا موتورز': 'kia', 'نيسان': 'nissan', 'نيصان': 'nissan', 'متسوبيشي': 'mitsubishi', 'ميتسوبيشي': 'mitsubishi', 'ميتسوبيشى': 'mitsubishi', 'سكودا': 'skoda', 'اسكودا': 'skoda', 'فولكس': 'volkswagen', 'فولكس فاجن': 'volkswagen', 'vw': 'volkswagen', 'رينو': 'renault', 'رينوت': 'renault', 'بيجو': 'peugeot', 'بيجوت': 'peugeot', 'اودي': 'audi', 'أودي': 'audi', 'ام جي': 'mg', 'إم جي': 'mg', 'لادا': 'lada', 'فيات': 'fiat',
  };

  final Map<String, String> _partAliases = {
    'تيل': 'Brake Pads', 'تيل فرامل': 'Brake Pads', 'فرامل': 'Brake Pads', 'مساعدين': 'Shock Absorbers', 'مساعد': 'Shock Absorber', 'سير': 'Belt', 'سير كاتينة': 'Timing Belt', 'فلتر': 'Filter', 'فلتر زيت': 'Oil Filter', 'فلتر هوا': 'Air Filter', 'طرمبة': 'Pump', 'طرمبة بنزين': 'Fuel Pump', 'طلمبة': 'Pump', 'كوبلن': 'CV Joint', 'كبالن': 'CV Joints', 'مقصات': 'Control Arms', 'مقص': 'Control Arm', 'بوجيهات': 'Spark Plugs', 'بوجيه': 'Spark Plug',
  };

  String _convertArabicNumeralsToEnglish(String input) {
    const arabicNumbers = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    const englishNumbers = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    String result = input;
    for (int i = 0; i < arabicNumbers.length; i++) { result = result.replaceAll(arabicNumbers[i], englishNumbers[i]); }
    return result;
  }

  Map<String, dynamic> parseSearchQuery(String query, {bool isPart = false}) {
    String cleanQuery = _convertArabicNumeralsToEnglish(query).toLowerCase().trim();
    String? targetYear;
    final yearRegex = RegExp(r'\b(19[0-9]{2}|20[0-2][0-9]|2030)\b');
    final match = yearRegex.firstMatch(cleanQuery);
    if (match != null) { targetYear = match.group(0); cleanQuery = cleanQuery.replaceAll(targetYear!, '').trim(); }
    String paddedQuery = ' $cleanQuery ';
    final genericWords = ['عربيه', 'عربية', 'سياره', 'سيارة', 'عربيات', 'سيارات', 'موديل', 'سنه', 'سنة', 'car', 'cars', 'model', 'year'];
    for (var word in genericWords) { paddedQuery = paddedQuery.replaceAll(' $word ', ' '); }
    var sortedCarAliases = _carAliases.keys.toList()..sort((a, b) => b.length.compareTo(a.length));
    for (var alias in sortedCarAliases) { paddedQuery = paddedQuery.replaceAll(' $alias ', ' ${_carAliases[alias]} '); }
    if (isPart) {
      var sortedPartAliases = _partAliases.keys.toList()..sort((a, b) => b.length.compareTo(a.length));
      for (var alias in sortedPartAliases) { paddedQuery = paddedQuery.replaceAll(' $alias ', ' ${_partAliases[alias]} '); }
    }
    cleanQuery = paddedQuery.trim();
    List<String> queryWords = cleanQuery.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    return { 'words': queryWords, 'year': targetYear, 'cleanQueryForAi': cleanQuery.isNotEmpty ? cleanQuery : query };
  }

  Future<void> searchSpecificCar(String query, {bool isLoadMore = false}) async {
    if (query.trim().isEmpty) return;

    // 🛑 لو بيحمل أصلاً أو وصل لآخر نتايج السيرفر، متعملش ريكويست تاني
    if (isLoadMore && (isSearchingMore || hasReachedMaxSearch)) return;

    if (!isLoadMore) {
      // 🔥 بـدايـة الـتـعـديـل: حفظ كلمة البحث في الكاش بحد أقصى 10 كلمات بدون التأثير على أي شيء آخر 🔥
      List<String> searchHistory = CacheHelper.getStringList(key: 'search_history') ?? [];
      searchHistory.remove(query.trim()); // لو الكلمة موجودة بنمسحها عشان تتضاف كأحدث حاجة
      searchHistory.insert(0, query.trim()); // بنضيفها في الأول
      if (searchHistory.length > 10) {
        searchHistory = searchHistory.sublist(0, 10); // الليميت: لو زادوا عن 10 بنحتفظ بأحدث 10 بس
      }
      CacheHelper.saveData(key: 'search_history', value: searchHistory); // بنحفظ السجل النظيف
      // 🔥 نـهـايـة الـتـعـديـل 🔥

      emit(SearchCarsLoading());
      searchResults.clear();
      searchApiOffset = 0; // 🔥 تصفير عداد الـ API
      hasReachedMaxSearch = false;
      isSearchingMore = true;

      // ========================================================
      // 🔥 البحث الهجين (اللوكال أولاً) 🔥
      // ========================================================
      String lowerQuery = query.toLowerCase().trim();
      Set<String> addedIds = {};

      void searchInList(List<CarModel> list) {
        for (var item in list) {
          if (!addedIds.contains(item.id)) {
            if (item.make.toLowerCase().contains(lowerQuery) ||
                item.model.toLowerCase().contains(lowerQuery) ||
                item.description.toLowerCase().contains(lowerQuery) ||
                item.year.contains(lowerQuery)) {
              searchResults.add(item);
              addedIds.add(item.id);
            }
          }
        }
      }

      searchInList(promotedPartsList);
      searchInList(sparePartsList);
      searchInList(promotedCarsList);
      searchInList(carsList);
      // ========================================================

    } else {
      isSearchingMore = true;
      emit(SearchCarsLoadingMore());
    }

    try {
      // 🚀 بنكلم السيرفر ونبعتله العداد الخاص بيه عشان يجيب الجديد
      final response = await _dio.post(
        '$_baseUrl/api/search/smart',
        data: {
          "query": query.trim(),
          "offset": searchApiOffset, // 🔥 بنبعت الـ Offset للسيرفر
          "limit": 10,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final String category = data['category'] ?? 'cars';
        final List<dynamic> resultsList = data['results'] ?? [];

        List<CarModel> fetchedItems = [];

        if (category == 'cars') {
          for (var item in resultsList) {
            fetchedItems.add(CarModel(
              id: item['id']?.toString() ?? '', sellerId: item['sellerId']?.toString() ?? 'ai_server', itemType: item['itemType']?.toString() ?? 'type_car',
              make: item['make']?.toString() ?? 'Unknown', model: item['model']?.toString() ?? 'Unknown', year: item['year']?.toString() ?? '2024',
              price: double.tryParse(item['price'].toString()) ?? 1500000.0, condition: item['condition']?.toString() ?? 'used_condition',
              description: item['description']?.toString() ?? '',
              images: (item['images'] is List) ? List<String>.from(item['images']) : (item['images'] is String ? [item['images']] : []),
              createdAt: item['createdAt']?.toString() ?? DateTime.now().toIso8601String(),
              hp: item['hp']?.toString() ?? 'N/A', cc: item['cc']?.toString() ?? 'N/A', torque: item['torque']?.toString() ?? 'N/A',
              transmission: item['transmission']?.toString() ?? 'Automatic', luggageCapacity: 'N/A', mileage: item['mileage']?.toString() ?? '0',
              sellerName: item['sellerName']?.toString() ?? 'GEAR UP Global', sellerPhone: '16000', sellerLocation: 'مصر', sellerEmail: '',
              rating: 0.0, reviewsCount: 0, viewsCount: 0,
            ));
          }
        } else if (category == 'spare_parts') {
          for (var item in resultsList) {
            fetchedItems.add(CarModel(
              id: item['id']?.toString() ?? '', sellerId: item['sellerId']?.toString() ?? 'ai_server', itemType: item['itemType']?.toString() ?? 'type_spare_part',
              make: item['title']?.toString() ?? 'قطعة غيار', model: item['carCompatibility']?.toString() ?? 'متوافق مع جميع السيارات', year: '0',
              price: double.tryParse(item['price'].toString()) ?? 500.0, condition: 'new', description: item['description']?.toString() ?? '',
              images: (item['images'] is List) ? List<String>.from(item['images']) : (item['images'] is String ? [item['images']] : []),
              createdAt: item['createdAt']?.toString() ?? DateTime.now().toIso8601String(),
              hp: 'N/A', cc: 'N/A', torque: 'N/A', transmission: 'N/A', luggageCapacity: 'N/A', mileage: '0',
              sellerName: item['sellerName']?.toString() ?? 'GEAR UP Global', sellerPhone: '16000', sellerLocation: 'مصر', sellerEmail: '',
              rating: 0.0, reviewsCount: 0, viewsCount: 0,
            ));
          }
        }

        if (fetchedItems.isEmpty) {
          // السيرفر جاب آخره ورد بليستة فاضية
          hasReachedMaxSearch = true;
        } else {
          searchApiOffset += fetchedItems.length; // بنزود العداد

          int newlyAddedCount = 0; // 🔥 متغير عشان نعد الحاجات الجديدة بس

          for (var item in fetchedItems) {
            // لو القطعة دي مش موجودة عندنا في اللستة قبل كده، ضيفها
            if (!searchResults.any((existing) => existing.id == item.id)) {
              searchResults.add(item);
              newlyAddedCount++;
            }
          }

          // ========================================================
          // 🔥 تسجيل النتايج الجديدة في الفايربيز في مكانها الصح 🔥
          // ========================================================
          for (var item in fetchedItems) {
            if (item.id.isNotEmpty && item.sellerId == 'ai_server') {

              String targetCollection = item.itemType == 'type_spare_part' ? 'spare_parts' : 'cars';

              await FirebaseFirestore.instance
                  .collection(targetCollection)
                  .doc(item.id)
                  .set(item.toMap(), SetOptions(merge: true));
            }
          }
          // ========================================================

          // 🔥 التعديل السحري: مش هنقفل السكرول إلا لو السيرفر جاب داتا متكررة 100%
          // أو مفيش ولا حاجة جديدة اتضافت في الـ Load More
          if (isLoadMore && newlyAddedCount == 0) {
            hasReachedMaxSearch = true;
          }
        }

        emit(SearchCarsSuccess());
      }
    } catch (e) {
      print('❌ خطأ في البحث الذكي: $e');
      emit(SearchCarsSuccess());
    } finally {
      isSearchingMore = false;
    }
  }

  void clearSearch() {
    searchResults.clear();
    _loadedSearchModels.clear();
    searchApiOffset = 0;
    _currentSearchYear = _currentYear; // 🔥 ممسحتش اللستة هنا عشان دي متغيرة
    hasReachedMaxSearch = false; // 🔥 حطيناها جوه الدالة في مكانها الصح
    emit(MarketInitial());
  }
  bool isSearchingCategoryAPI = false;
  Future<void> searchCategoryCarsFromAI(String query, String categoryTitle) async {
    if (isSearchingCategoryAPI) return;
    isSearchingCategoryAPI = true; emit(SearchCarsLoadingMore());
    final parsedData = parseSearchQuery(query);
    final String cleanSearchString = parsedData['cleanQueryForAi'];
    final String? searchYear = parsedData['year'];
    String conditionPrompt = ""; String expectedCondition = "used_condition";
    if (categoryTitle.toLowerCase().contains("new") || categoryTitle == "السيارات الجديدة" || categoryTitle == "New Cars") {
      conditionPrompt = "CRITICAL: You MUST set condition to 'new_condition' and mileage to '0'. Do NOT generate used cars."; expectedCondition = "new_condition";
    } else if (categoryTitle.toLowerCase().contains("used") || categoryTitle == "السيارات المستعملة" || categoryTitle == "Used Cars") {
      conditionPrompt = "CRITICAL: You MUST set condition to 'used_condition'. Do NOT generate new cars."; expectedCondition = "used_condition";
    }
    String yearPrompt = searchYear != null ? "ALL 4 cars MUST be exactly from the year $searchYear." : "Mix the years between ${_currentYear - 4} and $_currentYear.";
    String avoidModels = _loadedHomeModels.isEmpty ? "None" : _loadedHomeModels.take(20).join(", ");
    try {
      final aiResponse = await _dio.post('$_baseUrl/api/ai/chat', data: {"messages": [{"role": "system", "content": "Generate a JSON array of 4 car objects available in Egypt. Format: [{\"make\":\"...\",\"model\":\"...\",\"year\":\"...\",\"price\":1000000,\"condition\":\"$expectedCondition\",\"hp\":\"...\",\"cc\":\"...\",\"torque\":\"...\",\"mileage\":\"...\"}]"}, {"role": "user", "content": "Generate 4 realistic distinct variants for the brand/model: '${cleanSearchString.isEmpty ? 'Cars in Egypt' : cleanSearchString}'. $conditionPrompt $yearPrompt DO NOT use these exact models: [$avoidModels]. Use realistic EGP prices for year $_currentYear."}], "temperature": 0.8});
      if (aiResponse.statusCode == 200) {
        String responseText = aiResponse.data['choices'][0]['message']['content']; int startIndex = responseText.indexOf('['); int endIndex = responseText.lastIndexOf(']');
        if (startIndex != -1 && endIndex != -1) {
          String jsonArray = responseText.substring(startIndex, endIndex + 1); List<dynamic> generatedCars = jsonDecode(jsonArray);
          List<Future<void>> futures = generatedCars.map<Future<void>>((aiCar) async {
            String make = aiCar['make'].toString().toUpperCase(); String model = aiCar['model'].toString().toUpperCase(); String year = aiCar['year'].toString(); String imageUrl = await _getSmartImage(make, model, year); String docId = _firestore.collection('cars').doc().id;
            String finalCondition = expectedCondition; _loadedHomeModels.add("$make $model");
            CarModel fetchedCar = CarModel(id: docId, sellerId: 'ai_search_category', itemType: 'type_car', make: make, model: model, year: year, price: double.tryParse(aiCar['price'].toString()) ?? 1500000.0, condition: finalCondition, description: '✨ تم جلب المواصفات عبر الذكاء الاصطناعي بناءً على بحثك.', images: [imageUrl], createdAt: DateTime.now().toIso8601String(), hp: aiCar['hp']?.toString() ?? 'N/A', cc: aiCar['cc']?.toString() ?? 'N/A', torque: aiCar['torque']?.toString() ?? 'N/A', transmission: 'Automatic', luggageCapacity: 'N/A', mileage: finalCondition == 'new_condition' ? '0' : (aiCar['mileage']?.toString() ?? '50000'), sellerName: 'GEAR UP Search', sellerPhone: '16000', sellerLocation: 'مصر', sellerEmail: '', rating: 0.0, reviewsCount: 0);
            await _firestore.collection('cars').doc(docId).set(fetchedCar.toMap()); carsList.add(fetchedCar);
            if (finalCondition == 'new_condition') { newCarsList.add(fetchedCar); } else { usedCarsList.add(fetchedCar); }
          }).toList(); await Future.wait(futures);
        }
      }
    } catch (e) { }
    isSearchingCategoryAPI = false; emit(SearchCarsSuccess());
  }

  List<CarModel> sparePartsList = [];
  List<CarModel> feedSparePartsList = [];
  List<CarModel> partsSearchResults = [];
  bool isFetchingParts = false;
  bool isFetchingMoreParts = false;
  List<String> _loadedPartsNames = [];

  void _blendSpareParts() {
    List<CarModel> blended = []; int normalIdx = 0; int vipIdx = 0;
    List<CarModel> rawNormal = List.from(sparePartsList); List<CarModel> vips = List.from(promotedPartsList);
    rawNormal.sort((a, b) => b.createdAt.compareTo(a.createdAt)); vips.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    while (normalIdx < rawNormal.length) {
      for (int i = 0; i < 15 && normalIdx < rawNormal.length; i++) { blended.add(rawNormal[normalIdx]); normalIdx++; }
      if (vips.isNotEmpty) { int vipsToInject = vips.length >= 2 ? 2 : 1; for (int i = 0; i < vipsToInject; i++) { blended.add(vips[vipIdx % vips.length]); vipIdx++; } }
    }
    if (rawNormal.isEmpty && vips.isNotEmpty) { blended.addAll(vips); }
    feedSparePartsList = blended;
  }

  Future<void> getSpareParts({bool isRefresh = false}) async {
    if (isRefresh) { sparePartsList.clear(); feedSparePartsList.clear(); promotedPartsList.clear(); _loadedPartsNames.clear(); }
    if (sparePartsList.isNotEmpty && !isRefresh) return;
    emit(SearchCarsLoading()); isFetchingParts = true;
    try {
      final results = await Future.wait([_firestore.collection('spare_parts').orderBy('createdAt', descending: true).limit(20).get(), _firestore.collection('promoted_parts').get()]);
      DateTime fiveMonthsAgo = DateTime.now().subtract(const Duration(days: 150));
      sparePartsList.clear(); promotedPartsList.clear();

      for (var doc in results[1].docs) {
        final partData = doc.data() as Map<String, dynamic>;
        DateTime createdAt = DateTime.tryParse(partData['createdAt']?.toString() ?? '') ?? DateTime.now();
        if (createdAt.isBefore(fiveMonthsAgo)) { await _firestore.collection('promoted_parts').doc(doc.id).delete(); continue; }
        promotedPartsList.add(CarModel(
          id: doc.id, sellerId: partData['sellerId']?.toString() ?? 'unknown', itemType: 'type_spare_part',
          // 🔥 الحماية من الـ Null هنا 🔥
          make: partData['title']?.toString() ?? partData['make']?.toString() ?? 'قطعة غيار',
          model: partData['carCompatibility']?.toString() ?? partData['model']?.toString() ?? 'متوافق مع جميع السيارات',
          year: partData['year']?.toString() ?? '0',
          price: double.tryParse(partData['price']?.toString() ?? '500') ?? 500.0,
          condition: partData['condition']?.toString() ?? 'new',
          description: partData['description']?.toString() ?? '',
          images: (partData['images'] is List) ? List<String>.from(partData['images']) : (partData['images'] is String ? [partData['images']] : []),
          createdAt: partData['createdAt']?.toString() ?? DateTime.now().toIso8601String(),
          hp: 'N/A', cc: 'N/A', torque: 'N/A', transmission: 'N/A', luggageCapacity: 'N/A', mileage: '0',
          sellerName: partData['sellerName']?.toString() ?? 'GEAR UP', sellerPhone: '16000', sellerLocation: 'مصر', sellerEmail: '', rating: 0.0, reviewsCount: 0, viewsCount: 0,
        ));
      }

      for (var doc in results[0].docs) {
        final partData = doc.data() as Map<String, dynamic>;
        sparePartsList.add(CarModel(
          id: doc.id, sellerId: partData['sellerId']?.toString() ?? 'ai_server', itemType: 'type_spare_part',
          // 🔥 الحماية من الـ Null هنا 🔥
          make: partData['title']?.toString() ?? partData['make']?.toString() ?? 'قطعة غيار',
          model: partData['carCompatibility']?.toString() ?? partData['model']?.toString() ?? 'متوافق مع جميع السيارات',
          year: partData['year']?.toString() ?? '0',
          price: double.tryParse(partData['price']?.toString() ?? '500') ?? 500.0,
          condition: partData['condition']?.toString() ?? 'new',
          description: partData['description']?.toString() ?? '',
          images: (partData['images'] is List) ? List<String>.from(partData['images']) : (partData['images'] is String ? [partData['images']] : []),
          createdAt: partData['createdAt']?.toString() ?? DateTime.now().toIso8601String(),
          hp: 'N/A', cc: 'N/A', torque: 'N/A', transmission: 'N/A', luggageCapacity: 'N/A', mileage: '0',
          sellerName: partData['sellerName']?.toString() ?? 'GEAR UP', sellerPhone: '16000', sellerLocation: 'مصر', sellerEmail: '', rating: 0.0, reviewsCount: 0, viewsCount: 0,
        ));
      }
      if (sparePartsList.isEmpty) { await searchSpecificCar("قطع غيار"); } else { emit(SearchCarsSuccess()); }
    } catch (e) { emit(SearchCarsSuccess()); } finally { isFetchingParts = false; }
  }

  Future<void> loadMoreSpareParts() async {
    if (isFetchingMoreParts) return;
    isFetchingMoreParts = true; emit(SearchCarsLoadingMore());
    try {
      final response = await _dio.post('$_baseUrl/api/search/smart', data: {"query": "قطع غيار متنوعة للسيارات في مصر", "offset": sparePartsList.length});
      if (response.statusCode == 200) {
        final List<dynamic> resultsList = response.data['results'] ?? [];
        for (var item in resultsList) {
          if (!sparePartsList.any((part) => part.id == item['id'])) {
            sparePartsList.add(CarModel(
              id: item['id'] ?? '', sellerId: item['sellerId'] ?? 'ai_server', itemType: 'type_spare_part',
              make: item['title'] ?? 'قطعة غيار', model: item['carCompatibility'] ?? 'متوافق مع جميع السيارات', year: '0',
              price: double.tryParse(item['price'].toString()) ?? 500.0, condition: 'new', description: item['description'] ?? '',
              images: (item['images'] is List) ? List<String>.from(item['images']) : (item['images'] is String ? [item['images']] : []),
              createdAt: item['createdAt'] ?? DateTime.now().toIso8601String(), hp: 'N/A', cc: 'N/A', torque: 'N/A', transmission: 'N/A', luggageCapacity: 'N/A', mileage: '0',
              sellerName: item['sellerName'] ?? 'GEAR UP Global', sellerPhone: '16000', sellerLocation: 'مصر', sellerEmail: '', rating: 0.0, reviewsCount: 0, viewsCount: 0,
            ));
          }
        }
      }
    } catch (e) {}
    isFetchingMoreParts = false; emit(SearchCarsSuccess());
  }

  Future<List<CarModel>> _fetchPersonalizedCarsFromAI(String usage, String budget) async {
    List<CarModel> generatedList = [];
    String avoidModels = _loadedHomeModels.isEmpty ? "None" : _loadedHomeModels.take(20).join(", ");
    try {
      final aiResponse = await _dio.post('$_baseUrl/api/ai/chat', data: {"messages": [{"role": "system", "content": "You are an expert in the Egyptian automotive market in $_currentYear. Generate a JSON array of 4 car objects available in Egypt. Format: [{\"make\":\"...\",\"model\":\"...\",\"year\":\"...\",\"price\":1000000,\"condition\":\"used_condition\",\"hp\":\"...\",\"cc\":\"...\",\"torque\":\"...\",\"mileage\":\"...\"}]"}, {"role": "user", "content": "Generate 4 realistic cars available in Egypt. The user wants a car for: '$usage'. Their budget range is: '$budget'. STRICTLY ensure the price matches this budget. DO NOT use these exact models: [$avoidModels]."}], "temperature": 0.8});
      if (aiResponse.statusCode == 200) {
        String responseText = aiResponse.data['choices'][0]['message']['content']; int startIndex = responseText.indexOf('['); int endIndex = responseText.lastIndexOf(']');
        if (startIndex != -1 && endIndex != -1) {
          List<dynamic> generatedCars = jsonDecode(responseText.substring(startIndex, endIndex + 1));
          List<Future<void>> futures = generatedCars.map<Future<void>>((aiCar) async {
            String make = aiCar['make'].toString().toUpperCase(); String model = aiCar['model'].toString().toUpperCase(); String year = aiCar['year'].toString(); String imageUrl = await _getSmartImage(make, model, year); String docId = _firestore.collection('cars').doc().id;
            CarModel fetchedCar = CarModel(id: docId, sellerId: 'ai_personalized', itemType: 'type_car', make: make, model: model, year: year, price: double.tryParse(aiCar['price'].toString()) ?? 1000000.0, condition: aiCar['condition'] ?? 'used_condition', description: '✨ سيارة تم اختيارها خصيصاً لك بناءً على تفضيلاتك.', images: [imageUrl], createdAt: DateTime.now().toIso8601String(), hp: aiCar['hp']?.toString() ?? 'N/A', cc: aiCar['cc']?.toString() ?? 'N/A', torque: aiCar['torque']?.toString() ?? 'N/A', transmission: 'Automatic', luggageCapacity: 'N/A', mileage: aiCar['mileage']?.toString() ?? '50000', sellerName: 'GEAR UP Assistant', sellerPhone: '16000', sellerLocation: 'مصر', sellerEmail: '', rating: 0.0, reviewsCount: 0);
            await _firestore.collection('cars').doc(docId).set(fetchedCar.toMap());
            carsList.add(fetchedCar); generatedList.add(fetchedCar); _loadedHomeModels.add("$make $model");
          }).toList();
          await Future.wait(futures);
        }
      }
    } catch (e) {}
    return generatedList;
  }

  List<Map<String, dynamic>> dynamicBottomSections = [];
  bool isGeneratingDynamicSection = false;
  Future<void> generateNextDynamicSection() async {
    if (isGeneratingDynamicSection || isFilterActive) return;
    isGeneratingDynamicSection = true; emit(MarketInitial());
    try {
      // 🔥 دي السلسلة الثابتة اللي هتتكرر بالترتيب (مستحيل صفين يجوا ورا بعض) 🔥
      List<String> sequence = ['promoted', 'top_rated', 'new_cars', 'used_cars', 'news'];
      bool hasSurvey = CacheHelper.getData(key: 'survey_completed') == true;
      if (hasSurvey && !sequence.contains('personalized')) {
        sequence.insert(0, 'personalized'); // بيضيف قسم "اخترناها لك" لو اليوزر مالي الاستبيان
      }

      // 🔥 اختيار القسم بالدور بناءً على العداد، وبعدين نزود العداد للمرة الجاية 🔥
      String selectedType = sequence[_dynamicSequenceIndex % sequence.length];
      _dynamicSequenceIndex++;

      List<dynamic> sourceList = []; String titleKey = ''; String subtitleKey = ''; bool isPremium = false;

      if (selectedType == 'personalized') {
        String usage = CacheHelper.getData(key: 'pref_carUsage') ?? ''; String budget = CacheHelper.getData(key: 'pref_budget') ?? '';
        titleKey = 'personalized_cars_title'; subtitleKey = usage; isPremium = true;
        sourceList = await _fetchPersonalizedCarsFromAI(usage, budget);
      } else if (selectedType == 'new_cars') {
        sourceList = newCarsList.where((car) => !shownDynamicCarIds.contains(car.id) && !promotedCarsList.any((p)=>p.id==car.id)).toList(); titleKey = 'new_cars'; subtitleKey = 'latest_models';
      } else if (selectedType == 'used_cars') {
        sourceList = usedCarsList.where((car) => !shownDynamicCarIds.contains(car.id) && !promotedCarsList.any((p)=>p.id==car.id)).toList(); titleKey = 'used_cars'; subtitleKey = 'quality_preowned';
      } else if (selectedType == 'news') {
        sourceList = List.from(newsList); titleKey = 'latest_cars_news'; subtitleKey = 'news_insights';
      } else if (selectedType == 'top_rated') {
        sourceList = carsList.where((car) => car.rating >= 4.0 && car.reviewsCount > 0 && !shownDynamicCarIds.contains(car.id) && !promotedCarsList.any((p)=>p.id==car.id)).toList();
        sourceList.sort((a, b) => b.rating.compareTo(a.rating)); titleKey = 'top_rated_cars'; subtitleKey = 'best_rated_$_currentYear'; isPremium = true;
      } else {
        sourceList = carsList.where((car) => !shownDynamicCarIds.contains(car.id) && !promotedCarsList.any((p)=>p.id==car.id)).toList(); titleKey = 'curated_for_you'; subtitleKey = 'randomly_selected_for_you'; isPremium = true;
      }

      // لو اللوكال نقص، نعوض
      if (selectedType != 'news' && selectedType != 'top_rated' && sourceList.length < 4) {
        await fetchExternalCarsData();
        if (selectedType == 'new_cars') sourceList = newCarsList.where((car) => !shownDynamicCarIds.contains(car.id) && !promotedCarsList.any((p)=>p.id==car.id)).toList();
        else if (selectedType == 'used_cars') sourceList = usedCarsList.where((car) => !shownDynamicCarIds.contains(car.id) && !promotedCarsList.any((p)=>p.id==car.id)).toList();
        else sourceList = carsList.where((car) => !shownDynamicCarIds.contains(car.id) && !promotedCarsList.any((p)=>p.id==car.id)).toList();
      }

      if (sourceList.length < 4 && selectedType != 'news' && selectedType != 'top_rated') {
        sourceList = carsList.where((car) => car.itemType == 'type_car' && !promotedCarsList.any((p)=>p.id==car.id)).toList()..shuffle();
      }

      if (selectedType == 'news' && sourceList.isEmpty) { await fetchMoreNews(); sourceList = List.from(newsList); }

      if (sourceList.isNotEmpty) {
        if (selectedType != 'top_rated' && selectedType != 'news') sourceList.shuffle();
        List<dynamic> selectedItems = sourceList.take(4).toList();
        if (selectedType != 'news' && selectedType != 'top_rated') { for (var item in selectedItems) { shownDynamicCarIds.add(item.id); } }
        dynamicBottomSections.add({'titleKey': titleKey, 'subtitleKey': subtitleKey, 'items': selectedItems, 'type': selectedType, 'isPremium': isPremium});
      }
    } catch (e) { }
    isGeneratingDynamicSection = false; emit(MarketInitial());
  }
  void _organizeNews() {
    final now = DateTime.now(); List<NewsModel> todayNews = []; List<NewsModel> month1News = []; List<NewsModel> month2News = []; List<NewsModel> month3News = [];
    for (var news in newsList) {
      DateTime dt = DateTime.tryParse(news.createdAt) ?? now; final difference = now.difference(dt).inDays;
      if (difference <= 2) { todayNews.add(news); } else if (difference <= 30) { month1News.add(news); } else if (difference <= 60) { month2News.add(news); } else { month3News.add(news); }
    }
    todayNews.sort((a, b) { DateTime dateA = DateTime.tryParse(a.createdAt) ?? now; DateTime dateB = DateTime.tryParse(b.createdAt) ?? now; return dateB.compareTo(dateA); });
    month1News.shuffle(); month2News.shuffle(); month3News.shuffle();
    newsList = [...todayNews, ...month1News, ...month2News, ...month3News];
  }

  List<NewsModel> newsList = []; bool isFetchingNews = false; bool isFetchingMoreNews = false; int _newsQueryIndex = 0; final List<String> _newsQueriesAr = ["أخبار السيارات مصر", "سوق السيارات المصري", "أسعار السيارات في مصر", "السيارات الكهربائية مصر"];

  Future<void> getNews() async {
    if (isFetchingNews) return; isFetchingNews = true; emit(MarketInitial());
    try {
      final snapshot = await _firestore.collection('automotive_news').get(); newsList.clear();
      DateTime threeMonthsAgo = DateTime.now().subtract(const Duration(days: 90));
      for (var doc in snapshot.docs) {
        NewsModel news = NewsModel.fromJson(doc.data()); DateTime createdAt = DateTime.tryParse(news.createdAt) ?? DateTime.now();
        if (createdAt.isBefore(threeMonthsAgo)) { await _firestore.collection('automotive_news').doc(news.id).delete(); continue; }
        newsList.add(news);
      }
      String? lastFetch = CacheHelper.getData(key: 'last_news_ai_fetch'); bool shouldFetchAi = lastFetch == null || DateTime.now().difference(DateTime.parse(lastFetch)).inHours >= 24;
      if (newsList.isEmpty || shouldFetchAi) { await fetchMoreNews(); await CacheHelper.saveData(key: 'last_news_ai_fetch', value: DateTime.now().toIso8601String()); } else { _organizeNews(); }
      isFetchingNews = false; emit(MarketInitial());
    } catch (e) { isFetchingNews = false; }
  }

  Future<void> fetchMoreNews() async {
    if (isFetchingMoreNews) return; isFetchingMoreNews = true; emit(MarketInitial());
    String currentQuery = _newsQueriesAr[_newsQueryIndex % _newsQueriesAr.length]; _newsQueryIndex++;
    try {
      final response = await _dio.post('$_baseUrl/api/search/news', data: {"query": currentQuery, "gl": "eg", "hl": "ar", "num": 5});
      if (response.statusCode == 200 && response.data != null && response.data['news'] != null) {
        List dynamicNews = response.data['news'];
        for (var item in dynamicNews) {
          String articleLink = item['link'] ?? '';
          // 🔥 حل مشكلة الـ URL المشفر (فك التشفير قبل الحفظ) 🔥
          try { articleLink = Uri.decodeFull(articleLink); } catch(e){}

          bool isDuplicate = newsList.any((news) => news.articleUrl == articleLink);
          if (!isDuplicate && articleLink.isNotEmpty) {
            String docId = _firestore.collection('automotive_news').doc().id;
            NewsModel newArticle = NewsModel(id: docId, title: item['title'] ?? 'خبر سيارات', snippet: item['snippet'] ?? 'اضغط للتفاصيل', date: item['date'] ?? 'الآن', imageUrl: item['imageUrl'] ?? _premiumFallbacks[0], articleUrl: articleLink, createdAt: DateTime.now().toIso8601String());
            await _firestore.collection('automotive_news').doc(docId).set(newArticle.toMap()); newsList.add(newArticle);
          }
        }
        _organizeNews();
      }
    } catch (e) {}
    isFetchingMoreNews = false; emit(MarketInitial());
  }

  Future<void> getCars() async {
    emit(GetCarsLoading());
    try {
      // 🚀 التعديل هنا فقط: ضفنا orderBy و limit لجلب أحدث 40 عربية فقط بدل كل الداتا 🚀
      final results = await Future.wait([
        _firestore.collection('cars').orderBy('createdAt', descending: true).limit(40).get(),
        _firestore.collection('promoted_cars').get()
      ]);

      final aiCarsSnapshot = results[0]; final promotedCarsSnapshot = results[1];
      carsList.clear(); promotedCarsList.clear(); newCarsList.clear(); usedCarsList.clear(); dynamicBottomSections.clear(); clearFilters(); shownDynamicCarIds.clear();
      DateTime fiveMonthsAgo = DateTime.now().subtract(const Duration(days: 150));
      for (var doc in promotedCarsSnapshot.docs) {
        CarModel car = CarModel.fromJson(doc.data() as Map<String, dynamic>); DateTime createdAt = DateTime.tryParse(car.createdAt) ?? DateTime.now();
        // 🔥 عزل تام للـ AI من البروموتيد 🔥
        if (createdAt.isBefore(fiveMonthsAgo) || car.sellerId.startsWith('ai_')) {
          if(createdAt.isBefore(fiveMonthsAgo)) await _firestore.collection('promoted_cars').doc(car.id).delete();
          continue;
        }
        carsList.add(car); promotedCarsList.add(car);
      }

      List<Future<void>> fixTasks = [];
      for (var doc in aiCarsSnapshot.docs) {
        CarModel car = CarModel.fromJson(doc.data() as Map<String, dynamic>); DateTime createdAt = DateTime.tryParse(car.createdAt) ?? DateTime.now();
        if (createdAt.isBefore(fiveMonthsAgo)) { await _firestore.collection('cars').doc(car.id).delete(); continue; }

        // لو الصورة ناقصة، نطلبها من السيرفر بتاعنا في الخلفية
        if (_needsImageFix(car.images)) { fixTasks.add(() async { String newUrl = await _getSmartImage(car.make, car.model, car.year); car.images = [newUrl]; await _firestore.collection('cars').doc(car.id).update({'images': [newUrl]}); }()); }
        carsList.add(car);
        if (car.condition == 'new_condition') { newCarsList.add(car); } else if (car.condition == 'used_condition') { usedCarsList.add(car); }
        _loadedHomeModels.add("${car.make.toUpperCase()} ${car.model.toUpperCase()}");
      }
      if (fixTasks.isNotEmpty) { await Future.wait(fixTasks); }

      String? lastFetch = CacheHelper.getData(key: 'last_cars_ai_fetch');
      bool shouldFetchAi = lastFetch == null || DateTime.now().difference(DateTime.parse(lastFetch)).inHours >= 24;
      if ((newCarsList.isEmpty && usedCarsList.isEmpty) || shouldFetchAi) {
        await fetchExternalCarsData();
        await CacheHelper.saveData(key: 'last_cars_ai_fetch', value: DateTime.now().toIso8601String());
      }
      carsList.sort((a, b) { bool aIsAi = a.sellerId.startsWith('ai_'); bool bIsAi = b.sellerId.startsWith('ai_'); if (aIsAi && !bIsAi) return 1; if (!aIsAi && bIsAi) return -1; return b.createdAt.compareTo(a.createdAt); });
      await getSavedCars(); await getSavedParts(); emit(GetCarsSuccess());
    } catch (e) { emit(GetCarsError(e.toString())); }
  }

  Future<void> fetchExternalCarsData() async {
    if (isFetchingExternal) return;
    isFetchingExternal = true;
    emit(FetchExternalCarsLoading());

    try {
      final response = await _dio.get('$_baseUrl/api/generate-cars', options: Options(receiveTimeout: const Duration(seconds: 20), sendTimeout: const Duration(seconds: 20)));
      if (response.statusCode == 200 && response.data['cars'] != null) {
        List<dynamic> fetchedCars = response.data['cars'];
        for (var carData in fetchedCars) {
          CarModel fetchedCar = CarModel.fromJson(carData);
          carsList.add(fetchedCar);
          if (fetchedCar.condition == 'used_condition' || (int.tryParse(fetchedCar.mileage.toString()) ?? 0) > 0) {
            usedCarsList.add(fetchedCar);
          } else {
            newCarsList.add(fetchedCar);
          }
          _loadedHomeModels.add("${fetchedCar.make.toUpperCase()} ${fetchedCar.model.toUpperCase()}");
        }
        isFetchingExternal = false;
        emit(FetchExternalCarsSuccess());
      } else { throw Exception("السيرفر لم يرسل بيانات صحيحة"); }
    } catch (e) { isFetchingExternal = false; emit(FetchExternalCarsSuccess()); }
  }

  Future<void> pickMultipleImages() async { try { final List<XFile> pickedFiles = await _picker.pickMultiImage(); if (pickedFiles.isNotEmpty) { for (var file in pickedFiles) { if (selectedCarImages.length < 10) selectedCarImages.add(File(file.path)); } emit(CarImagePickedSuccess()); } } catch (e) {} } void removeImage(File image) { selectedCarImages.remove(image); emit(MarketInitial()); } void clearSelectedImages() { selectedCarImages.clear(); emit(MarketInitial()); }

  Future<void> addCar({required String itemType, required String make, required String model, required String year, required double price, required String condition, required String description, required String hp, required String cc, required String torque, required String transmission, required String luggageCapacity, required String mileage, required String sellerName, required String sellerPhone, required String sellerLocation, required String sellerEmail,}) async {
    emit(AddCarLoading());
    try {
      String? sellerId = CacheHelper.getData(key: 'uid');
      if (sellerId == null) { emit(AddCarError('err_login_first')); return; }
      List<String> uploadedImagesUrls = [];
      if (selectedCarImages.isNotEmpty) { for (File image in selectedCarImages) { CloudinaryResponse response = await cloudinary.uploadFile(CloudinaryFile.fromFile(image.path, folder: 'items_images')); uploadedImagesUrls.add(response.secureUrl); } }
      String targetCollection = (itemType == 'type_car') ? 'promoted_cars' : 'promoted_parts';
      DocumentReference docRef = _firestore.collection(targetCollection).doc();
      CarModel newItem = CarModel(id: docRef.id, sellerId: sellerId, itemType: itemType, make: make, model: model, year: year, price: price, condition: condition, description: description, hp: hp, cc: cc, torque: torque, transmission: transmission, luggageCapacity: luggageCapacity, mileage: mileage, sellerName: sellerName, sellerPhone: sellerPhone, sellerLocation: sellerLocation, sellerEmail: sellerEmail, images: uploadedImagesUrls, createdAt: DateTime.now().toIso8601String(), rating: 0.0, reviewsCount: 0, viewsCount: 0);
      await docRef.set(newItem.toMap());
      if (itemType == 'type_car') { carsList.insert(0, newItem); promotedCarsList.insert(0, newItem); } else { promotedPartsList.insert(0, newItem); sparePartsList.insert(0, newItem); _blendSpareParts(); }

      dynamicBottomSections.clear(); shownDynamicCarIds.clear();

      clearSelectedImages(); emit(AddCarSuccess()); emit(MarketInitial());
    } catch (e) { emit(AddCarError(e.toString())); }
  }

  Future<void> incrementCarView(String carId, bool isPromoted, {bool isPart = false}) async {
    try {
      String userId = CacheHelper.getData(key: 'uid') ?? '';
      if (userId.isEmpty) { userId = CacheHelper.getData(key: 'guest_device_id') ?? ''; if (userId.isEmpty) { userId = 'guest_${DateTime.now().millisecondsSinceEpoch}'; await CacheHelper.saveData(key: 'guest_device_id', value: userId); } }
      String collectionName; if (isPart) { collectionName = isPromoted ? 'promoted_parts' : 'spare_parts'; } else { collectionName = isPromoted ? 'promoted_cars' : 'cars'; }
      DocumentReference carRef = _firestore.collection(collectionName).doc(carId); await carRef.update({'viewedBy': FieldValue.arrayUnion([userId])}); DocumentSnapshot snapshot = await carRef.get();
      if (snapshot.exists) {
        List<dynamic> viewedBy = (snapshot.data() as Map<String, dynamic>)['viewedBy'] ?? []; int actualViews = viewedBy.length; await carRef.update({'viewsCount': actualViews});
        if (isPart) {
          int index = sparePartsList.indexWhere((c) => c.id == carId);
          if (index != -1) { CarModel oldCar = sparePartsList[index]; sparePartsList[index] = CarModel(id: oldCar.id, sellerId: oldCar.sellerId, itemType: oldCar.itemType, make: oldCar.make, model: oldCar.model, year: oldCar.year, price: oldCar.price, condition: oldCar.condition, description: oldCar.description, images: oldCar.images, createdAt: oldCar.createdAt, hp: oldCar.hp, cc: oldCar.cc, torque: oldCar.torque, transmission: oldCar.transmission, luggageCapacity: oldCar.luggageCapacity, mileage: oldCar.mileage, sellerName: oldCar.sellerName, sellerPhone: oldCar.sellerPhone, sellerLocation: oldCar.sellerLocation, sellerEmail: oldCar.sellerEmail, rating: oldCar.rating, reviewsCount: oldCar.reviewsCount, viewsCount: actualViews); }
        } else {
          int index = carsList.indexWhere((c) => c.id == carId);
          if (index != -1) { CarModel oldCar = carsList[index]; carsList[index] = CarModel(id: oldCar.id, sellerId: oldCar.sellerId, itemType: oldCar.itemType, make: oldCar.make, model: oldCar.model, year: oldCar.year, price: oldCar.price, condition: oldCar.condition, description: oldCar.description, images: oldCar.images, createdAt: oldCar.createdAt, hp: oldCar.hp, cc: oldCar.cc, torque: oldCar.torque, transmission: oldCar.transmission, luggageCapacity: oldCar.luggageCapacity, mileage: oldCar.mileage, sellerName: oldCar.sellerName, sellerPhone: oldCar.sellerPhone, sellerLocation: oldCar.sellerLocation, sellerEmail: oldCar.sellerEmail, rating: oldCar.rating, reviewsCount: oldCar.reviewsCount, viewsCount: actualViews); }
        }
        emit(MarketInitial());
      }
    } catch (e) {}
  }

  void _checkAndTriggerRemindersAlarms() {
    String alarmedString = CacheHelper.getData(key: 'alarmed_reminders') ?? "";
    List<String> alarmedIds = alarmedString.isNotEmpty ? alarmedString.split(',') : [];
    DateTime now = DateTime.now(); DateTime today = DateTime(now.year, now.month, now.day); bool hasNewAlarm = false;

    for (var reminder in myReminders) {
      try {
        DateTime target = DateTime.parse(reminder['date'].split(' ')[0]);
        int diff = target.difference(today).inDays;
        double totalDays = 30.0; double passedDays = totalDays - diff; double progress = (passedDays / totalDays).clamp(0.05, 1.0);

        String warningId = "${reminder['id']}_warning"; String finishedId = "${reminder['id']}_finished";

        if (diff > 0 && (progress >= 0.90 || diff <= 3)) {
          if (!alarmedIds.contains(warningId)) { NotificationHelper.showSirenNotification('اقترب موعد الصيانة ⚠️', 'سيارتك تحتاج صيانة قريباً: ${reminder['task']}'); alarmedIds.add(warningId); hasNewAlarm = true; }
        }
        if (diff <= 0) {
          if (!alarmedIds.contains(finishedId)) { NotificationHelper.showSirenNotification('موعد الصيانة حان 🚨', 'اليوم هو موعد: ${reminder['task']}'); alarmedIds.add(finishedId); hasNewAlarm = true; }
        }
      } catch (e) { }
    }
    if (hasNewAlarm) { CacheHelper.saveData(key: 'alarmed_reminders', value: alarmedIds.join(',')); }
  }

  List<Map<String, dynamic>> myCars = []; List<Map<String, dynamic>> myReminders = []; List<Map<String, dynamic>> myMaintenanceHistory = []; bool isLoadingMyCar = false;
  Future<void> getMyCarData() async {
    String? uid = CacheHelper.getData(key: 'uid');
    if (uid == null || uid.isEmpty) return;

    isLoadingMyCar = true;
    emit(MarketInitial());

    try {
      // 🔥 ضفنا timeout (3 ثواني) عشان لو مفيش نت يفصل فوراً وينزل يسحب من الكاش 🔥
      final vehiclesSnapshot = await _firestore.collection('users').doc(uid).collection('my_cars').get().timeout(const Duration(seconds: 3));
      myCars = vehiclesSnapshot.docs.map((doc) { var data = doc.data(); data['id'] = doc.id; return data; }).toList();
      await CacheHelper.saveData(key: 'offline_my_cars_$uid', value: jsonEncode(myCars));

      final remindersSnapshot = await _firestore.collection('users').doc(uid).collection('reminders').orderBy('date').get().timeout(const Duration(seconds: 3));
      myReminders = remindersSnapshot.docs.map((doc) => doc.data()).toList();
      await CacheHelper.saveData(key: 'offline_reminders_$uid', value: jsonEncode(myReminders));

      final maintenanceSnapshot = await _firestore.collection('users').doc(uid).collection('maintenance').orderBy('date', descending: true).get().timeout(const Duration(seconds: 3));
      myMaintenanceHistory = maintenanceSnapshot.docs.map((doc) => doc.data()).toList();
      await CacheHelper.saveData(key: 'offline_maintenance_$uid', value: jsonEncode(myMaintenanceHistory));

      _checkAndTriggerRemindersAlarms();
    } catch (e) {
      // 🚀 جاري السحب من الكاش طلقة في حالة عدم وجود نت 🚀
      String? cC = CacheHelper.getData(key: 'offline_my_cars_$uid');
      if (cC != null) myCars = List<Map<String, dynamic>>.from(jsonDecode(cC));

      String? cR = CacheHelper.getData(key: 'offline_reminders_$uid');
      if (cR != null) myReminders = List<Map<String, dynamic>>.from(jsonDecode(cR));

      String? cM = CacheHelper.getData(key: 'offline_maintenance_$uid');
      if (cM != null) myMaintenanceHistory = List<Map<String, dynamic>>.from(jsonDecode(cM));
    } finally {
      isLoadingMyCar = false;
      emit(GetCarsSuccess()); // 🔥 خليناها Success عشان الشاشة تحدث وتجيب داتا الكاش
    }
  }  Future<void> saveMyVehicleDetails({String? vehicleId, required String make, required String model, required String year, required String mileage, required List<String> imagesUrls,}) async { String? uid = CacheHelper.getData(key: 'uid'); if (uid == null) return; try { String docId = vehicleId ?? _firestore.collection('users').doc(uid).collection('my_cars').doc().id; Map<String, dynamic> data = {'id': docId, 'make': make, 'model': model, 'year': year, 'mileage': mileage, 'images': imagesUrls,}; await _firestore.collection('users').doc(uid).collection('my_cars').doc(docId).set(data, SetOptions(merge: true)); int index = myCars.indexWhere((v) => v['id'] == docId); if (index != -1) { myCars[index] = data; } else { myCars.add(data); } await CacheHelper.saveData(key: 'offline_my_cars_$uid', value: jsonEncode(myCars)); emit(MarketInitial()); } catch (e) { } }
  Future<void> saveReminder({String? id, String? carId, required String task, required String date, required String notes}) async { String? uid = CacheHelper.getData(key: 'uid'); if (uid == null) return; try { String docId = id ?? _firestore.collection('users').doc(uid).collection('reminders').doc().id; Map<String, dynamic> reminderData = { 'id': docId, 'carId': carId, 'task': task, 'date': date, 'notes': notes }; await _firestore.collection('users').doc(uid).collection('reminders').doc(docId).set(reminderData); int index = myReminders.indexWhere((r) => r['id'] == docId); if (index != -1) { myReminders[index] = reminderData; } else { myReminders.add(reminderData); } myReminders.sort((a, b) => (a['date'] as String).compareTo(b['date'] as String)); await CacheHelper.saveData(key: 'offline_reminders_$uid', value: jsonEncode(myReminders)); _checkAndTriggerRemindersAlarms(); emit(MarketInitial()); } catch (e) { } }
  Future<void> deleteReminder(String id) async { String? uid = CacheHelper.getData(key: 'uid'); if (uid == null) return; try { await _firestore.collection('users').doc(uid).collection('reminders').doc(id).delete(); myReminders.removeWhere((r) => r['id'] == id); await CacheHelper.saveData(key: 'offline_reminders_$uid', value: jsonEncode(myReminders)); emit(MarketInitial()); } catch (e) { } }
  Future<void> saveMaintenanceRecord({String? id, String? carId, required String title, required String date, required String cost, required String desc}) async { String? uid = CacheHelper.getData(key: 'uid'); if (uid == null) return; try { String docId = id ?? _firestore.collection('users').doc(uid).collection('maintenance').doc().id; Map<String, dynamic> maintenanceData = { 'id': docId, 'carId': carId, 'title': title, 'date': date, 'cost': cost, 'desc': desc }; await _firestore.collection('users').doc(uid).collection('maintenance').doc(docId).set(maintenanceData); int index = myMaintenanceHistory.indexWhere((m) => m['id'] == docId); if (index != -1) { myMaintenanceHistory[index] = maintenanceData; } else { myMaintenanceHistory.add(maintenanceData); } myMaintenanceHistory.sort((a, b) => (b['date'] as String).compareTo(a['date'] as String)); await CacheHelper.saveData(key: 'offline_maintenance_$uid', value: jsonEncode(myMaintenanceHistory)); emit(MarketInitial()); } catch (e) { } }
  Future<void> deleteMaintenanceRecord(String id) async { String? uid = CacheHelper.getData(key: 'uid'); if (uid == null) return; try { await _firestore.collection('users').doc(uid).collection('maintenance').doc(id).delete(); myMaintenanceHistory.removeWhere((m) => m['id'] == id); await CacheHelper.saveData(key: 'offline_maintenance_$uid', value: jsonEncode(myMaintenanceHistory)); emit(MarketInitial()); } catch (e) { } }

  List<Map<String, dynamic>> userPaymentMethods = []; List<Map<String, dynamic>> userTransactions = []; bool isLoadingPayments = false;
  Future<void> getPaymentData() async { String? uid = CacheHelper.getData(key: 'uid'); if (uid == null || uid.isEmpty) return; isLoadingPayments = true; emit(MarketInitial()); try { final methodsSnap = await _firestore.collection('users').doc(uid).collection('payment_methods').get(); userPaymentMethods = methodsSnap.docs.map((doc) => doc.data()).toList(); final transSnap = await _firestore.collection('users').doc(uid).collection('transactions').orderBy('timestamp', descending: true).get(); userTransactions = transSnap.docs.map((doc) => doc.data()).toList(); } catch (e) { } finally { isLoadingPayments = false; emit(MarketInitial()); } }
  Future<void> addPaymentMethod({required String type, String? cardNumber, String? cardholderName, String? expiryDate, String? phoneNumber, String? name, String? walletName}) async { String? uid = CacheHelper.getData(key: 'uid'); if (uid == null || uid.isEmpty) return; try { String docId = _firestore.collection('users').doc(uid).collection('payment_methods').doc().id; Map<String, dynamic> methodData = { 'id': docId, 'type': type, 'isDefault': userPaymentMethods.isEmpty, 'createdAt': DateTime.now().toIso8601String() }; if (type == 'Card') { String maskedCard = (cardNumber != null && cardNumber.length >= 4) ? "•••• ${cardNumber.substring(cardNumber.length - 4)}" : "•••• 0000"; methodData.addAll({'title': maskedCard, 'subtitle': "$cardholderName\nExpires $expiryDate"}); } else { methodData.addAll({'title': walletName ?? 'Mobile Wallet', 'subtitle': "$name\n$phoneNumber"}); } userPaymentMethods.add(methodData); emit(SearchCarsLoading()); emit(MarketInitial()); await _firestore.collection('users').doc(uid).collection('payment_methods').doc(docId).set(methodData); } catch (e) {} }
  Future<void> deletePaymentMethod(String id) async { String? uid = CacheHelper.getData(key: 'uid'); if (uid == null) return; try { userPaymentMethods.removeWhere((method) => method['id'] == id); emit(SearchCarsLoading()); emit(MarketInitial()); await _firestore.collection('users').doc(uid).collection('payment_methods').doc(id).delete(); } catch (e) {} }
  Future<void> deleteTransactionRecord(String id) async { String? uid = CacheHelper.getData(key: 'uid'); if (uid == null) return; try { userTransactions.removeWhere((t) => t['id'] == id); emit(SearchCarsLoading()); emit(MarketInitial()); await _firestore.collection('users').doc(uid).collection('transactions').doc(id).delete(); } catch (e) {} }
  Future<void> addTransactionRecord({required String title, required String amount, required String status, required bool isPositive}) async { String? uid = CacheHelper.getData(key: 'uid'); if (uid == null || uid.isEmpty) return; try { String docId = _firestore.collection('users').doc(uid).collection('transactions').doc().id; DateTime now = DateTime.now(); List<String> months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']; String formattedDate = "${months[now.month - 1]} ${now.day}, ${now.year}"; Map<String, dynamic> transactionData = { 'id': docId, 'title': title, 'amount': amount, 'status': status, 'isPositive': isPositive, 'date': formattedDate, 'timestamp': now.toIso8601String() }; userTransactions.insert(0, transactionData); emit(SearchCarsLoading()); emit(MarketInitial()); await _firestore.collection('users').doc(uid).collection('transactions').doc(docId).set(transactionData); } catch (e) {} }

  // ========================================================
  // 🔥 دوال الريفيوهات وتحديث التوب ريتيد 🔥
  // ========================================================

  Future<Map<String, dynamic>> getCarRatingData(String carId) async {
    try {
      final snapshot = await _firestore.collection('cars').doc(carId).collection('reviews').get();
      if (snapshot.docs.isEmpty) return {'average': 0.0, 'count': 0, 'reviews': <Map<String, dynamic>>[]};
      double totalRating = 0; List<Map<String, dynamic>> reviewsList = [];
      for (var doc in snapshot.docs) { final data = doc.data(); data['id'] = doc.id; totalRating += (data['rating'] as num).toDouble(); reviewsList.add(data); }
      return {'average': totalRating / snapshot.docs.length, 'count': snapshot.docs.length, 'reviews': reviewsList};
    } catch (e) { return {'average': 0.0, 'count': 0, 'reviews': <Map<String, dynamic>>[]}; }
  }

  Future<Map<String, dynamic>> getPartRatingData(String partId) async {
    try {
      final snapshot = await _firestore.collection('spare_parts').doc(partId).collection('reviews').get();
      if (snapshot.docs.isEmpty) return {'average': 0.0, 'count': 0, 'reviews': <Map<String, dynamic>>[]};
      double totalRating = 0; List<Map<String, dynamic>> reviewsList = [];
      for (var doc in snapshot.docs) { final data = doc.data(); data['id'] = doc.id; totalRating += (data['rating'] as num).toDouble(); reviewsList.add(data); }
      return {'average': totalRating / snapshot.docs.length, 'count': snapshot.docs.length, 'reviews': reviewsList};
    } catch (e) { return {'average': 0.0, 'count': 0, 'reviews': <Map<String, dynamic>>[]}; }
  }

  Future<void> addReview({required String carId, required String sellerId, required String carMake, required String carModel, required double rating, required String comment}) async {
    String? uid = CacheHelper.getData(key: 'uid');
    String reviewerName = CacheHelper.getData(key: 'name') ?? 'مستخدم';
    try {
      if (reviewerName == 'مستخدم' && uid != null && !uid.startsWith('guest')) {
        var uDoc = await _firestore.collection('users').doc(uid).get();
        if (uDoc.exists) { reviewerName = uDoc.data()?['name'] ?? uDoc.data()?['userName'] ?? 'مستخدم'; CacheHelper.saveData(key: 'name', value: reviewerName); }
      }
      String reviewId = _firestore.collection('cars').doc(carId).collection('reviews').doc().id;
      Map<String, dynamic> reviewData = { 'id': reviewId, 'userId': uid ?? 'guest', 'userName': reviewerName, 'rating': rating, 'comment': comment, 'createdAt': DateTime.now().toIso8601String(), 'likes': [] };
      await _firestore.collection('cars').doc(carId).collection('reviews').doc(reviewId).set(reviewData);

      final snapshot = await _firestore.collection('cars').doc(carId).collection('reviews').get();
      double totalRating = 0; for (var doc in snapshot.docs) { totalRating += (doc.data()['rating'] as num).toDouble(); }
      double newAverage = snapshot.docs.isEmpty ? 0.0 : totalRating / snapshot.docs.length; int newCount = snapshot.docs.length;
      await _firestore.collection('cars').doc(carId).update({'rating': newAverage, 'reviewsCount': newCount});

      int index = carsList.indexWhere((c) => c.id == carId);
      if (index != -1) { CarModel oldCar = carsList[index]; carsList[index] = CarModel(id: oldCar.id, sellerId: oldCar.sellerId, itemType: oldCar.itemType, make: oldCar.make, model: oldCar.model, year: oldCar.year, price: oldCar.price, condition: oldCar.condition, description: oldCar.description, images: oldCar.images, createdAt: oldCar.createdAt, hp: oldCar.hp, cc: oldCar.cc, torque: oldCar.torque, transmission: oldCar.transmission, luggageCapacity: oldCar.luggageCapacity, mileage: oldCar.mileage, sellerName: oldCar.sellerName, sellerPhone: oldCar.sellerPhone, sellerLocation: oldCar.sellerLocation, sellerEmail: oldCar.sellerEmail, rating: newAverage, reviewsCount: newCount, viewsCount: oldCar.viewsCount); }
      if (uid != null) { await _firestore.collection('users').doc(uid).collection('my_reviews').doc(reviewId).set({'carId': carId, 'rating': rating, 'comment': comment, 'createdAt': DateTime.now().toIso8601String(), 'isPart': false}); }

      emit(GetCarsSuccess()); // عشان الهوم تعمل ريفريش للتوب ريتيد

      if (sellerId.isNotEmpty && !sellerId.startsWith('ai_')) {
        try { await _dio.post('$_baseUrl/api/notify-review', data: { 'sellerId': sellerId, 'carMake': carMake, 'carModel': carModel }); } catch (e) {}
      }
    } catch (e) {}
  }

  Future<void> addPartReview({required String partId, required String sellerId, required String partMake, required String partModel, required double rating, required String comment}) async {
    String? uid = CacheHelper.getData(key: 'uid');
    String reviewerName = CacheHelper.getData(key: 'name') ?? 'مستخدم';
    try {
      if (reviewerName == 'مستخدم' && uid != null && !uid.startsWith('guest')) {
        var uDoc = await _firestore.collection('users').doc(uid).get();
        if (uDoc.exists) { reviewerName = uDoc.data()?['name'] ?? uDoc.data()?['userName'] ?? 'مستخدم'; CacheHelper.saveData(key: 'name', value: reviewerName); }
      }
      String reviewId = _firestore.collection('spare_parts').doc(partId).collection('reviews').doc().id;
      Map<String, dynamic> reviewData = { 'id': reviewId, 'userId': uid ?? 'guest', 'userName': reviewerName, 'rating': rating, 'comment': comment, 'createdAt': DateTime.now().toIso8601String(), 'likes': [] };
      await _firestore.collection('spare_parts').doc(partId).collection('reviews').doc(reviewId).set(reviewData);

      final snapshot = await _firestore.collection('spare_parts').doc(partId).collection('reviews').get();
      double totalRating = 0; for (var doc in snapshot.docs) { totalRating += (doc.data()['rating'] as num).toDouble(); }
      double newAverage = snapshot.docs.isEmpty ? 0.0 : totalRating / snapshot.docs.length; int newCount = snapshot.docs.length;
      await _firestore.collection('spare_parts').doc(partId).update({'rating': newAverage, 'reviewsCount': newCount}).catchError((_){});

      int index = sparePartsList.indexWhere((p) => p.id == partId);
      if (index != -1) { CarModel oldPart = sparePartsList[index]; sparePartsList[index] = CarModel(id: oldPart.id, sellerId: oldPart.sellerId, itemType: oldPart.itemType, make: oldPart.make, model: oldPart.model, year: oldPart.year, price: oldPart.price, condition: oldPart.condition, description: oldPart.description, images: oldPart.images, createdAt: oldPart.createdAt, hp: oldPart.hp, cc: oldPart.cc, torque: oldPart.torque, transmission: oldPart.transmission, luggageCapacity: oldPart.luggageCapacity, mileage: oldPart.mileage, sellerName: oldPart.sellerName, sellerPhone: oldPart.sellerPhone, sellerLocation: oldPart.sellerLocation, sellerEmail: oldPart.sellerEmail, rating: newAverage, reviewsCount: newCount, viewsCount: oldPart.viewsCount); }
      _blendSpareParts();

      if (uid != null) { await _firestore.collection('users').doc(uid).collection('my_reviews').doc(reviewId).set({'carId': partId, 'rating': rating, 'comment': comment, 'createdAt': DateTime.now().toIso8601String(), 'isPart': true}); }

      emit(GetCarsSuccess());

      if (sellerId.isNotEmpty && !sellerId.startsWith('ai_')) {
        try { await _dio.post('$_baseUrl/api/notify-review', data: { 'sellerId': sellerId, 'carMake': partMake, 'carModel': partModel }); } catch (e) {}
      }
    } catch (e) {}
  }

  Future<void> toggleReviewLike({required String carId, required String reviewId, required bool isPart, required bool isLiking}) async {
    String uid = CacheHelper.getData(key: 'uid') ?? '';
    if (uid.isEmpty || uid.startsWith('guest_')) return;

    try {
      String collection = isPart ? 'parts' : 'cars';
      DocumentReference reviewRef = _firestore.collection(collection).doc(carId).collection('reviews').doc(reviewId);

      // 🔥 تحديث الفايربيز الحقيقي 🔥
      if (isLiking) {
        await reviewRef.update({
          'likes': FieldValue.arrayUnion([uid])
        });
      } else {
        await reviewRef.update({
          'likes': FieldValue.arrayRemove([uid])
        });
      }

      // 🔥 تحديث الليستة اللوكال عشان اللايك يسمع في شاشة تقييماتي فوراً من غير ريفريش 🔥
      int index = myReviewsList.indexWhere((r) => r['reviewId'] == reviewId);
      if (index != -1) {
        List currentLikes = List.from(myReviewsList[index]['likes'] ?? []);
        if (isLiking && !currentLikes.contains(uid)) {
          currentLikes.add(uid);
        } else if (!isLiking) {
          currentLikes.remove(uid);
        }
        myReviewsList[index]['likes'] = currentLikes;
        emit(GetCarsSuccess());
      }

    } catch (e) {
      print("Toggle Like Error: $e");
    }
  }

  Future<void> reportReview({required String carId, required String reviewId, required String comment, required bool isPart}) async {
    String? currentUserId = CacheHelper.getData(key: 'uid') ?? CacheHelper.getData(key: 'guest_device_id') ?? 'unknown';
    try { await _firestore.collection('reported_reviews').add({ 'itemId': carId, 'reviewId': reviewId, 'comment': comment, 'reportedBy': currentUserId, 'isPart': isPart, 'reportedAt': DateTime.now().toIso8601String(), 'status': 'pending' }); } catch (e) {}
  }

  List<Map<String, dynamic>> myReviewsList = []; bool isLoadingMyReviews = false;
  Future<void> getMyReviews() async {
    isLoadingMyReviews = true;
    emit(MarketInitial()); // إجبار الشاشة تظهر اللودينج

    String uid = CacheHelper.getData(key: 'uid') ?? '';
    myReviewsList = [];

    if (uid.isNotEmpty && !uid.startsWith('guest_')) {
      try {
        // 🔥 الاستعلام الصاروخي: ريكويست واحد يجيب كل تقييماتك في فيمتو ثانية 🔥
        var reviewsQuery = await _firestore.collectionGroup('reviews').where('userId', isEqualTo: uid).get();

        for (var reviewDoc in reviewsQuery.docs) {
          var data = reviewDoc.data();

          // بنستنتج الـ ID بتاع العربية واسم القسم (cars ولا parts) من مسار الداتا
          String parentId = reviewDoc.reference.parent.parent?.id ?? '';
          String collectionPath = reviewDoc.reference.parent.parent?.parent?.id ?? '';

          if (parentId.isNotEmpty) {
            data['carId'] = parentId;
            data['reviewId'] = reviewDoc.id;
            data['isPart'] = collectionPath == 'parts';
            data['likes'] = data['likes'] ?? []; // عشان اللايكات متضربش null
            myReviewsList.add(data);
          }
        }
      } catch (e) {
        print("Get My Reviews Error: $e");
      }
    }

    // الترتيب من الأحدث للأقدم
    myReviewsList.sort((a, b) => (b['createdAt'] ?? '').compareTo(a['createdAt'] ?? ''));

    isLoadingMyReviews = false;
    emit(GetCarsSuccess()); // تحديث الشاشة وتقفيل اللودينج
  }
  Future<void> deleteMyReview(String itemId, String reviewId, {String? originalUserId, bool isPart = false}) async {
    String? currentUid = CacheHelper.getData(key: 'uid');
    try {
      if (reviewId.isEmpty) return;
      String collection = isPart ? 'spare_parts' : 'cars';
      await _firestore.collection(collection).doc(itemId).collection('reviews').doc(reviewId).delete();
      String? targetUser = originalUserId ?? currentUid;
      if (targetUser != null && !targetUser.startsWith('guest_')) { await _firestore.collection('users').doc(targetUser).collection('my_reviews').doc(reviewId).delete(); }
      myReviewsList.removeWhere((r) => r['reviewId'] == reviewId);
      emit(MyReviewsLoadedState());

      final snapshot = await _firestore.collection(collection).doc(itemId).collection('reviews').get();
      double totalRating = 0; for (var doc in snapshot.docs) { totalRating += (doc.data()['rating'] as num).toDouble(); }
      double newAverage = snapshot.docs.isEmpty ? 0.0 : totalRating / snapshot.docs.length; int newCount = snapshot.docs.length;
      await _firestore.collection(collection).doc(itemId).update({'rating': newAverage, 'reviewsCount': newCount}).catchError((_){});

      if (isPart) {
        int index = sparePartsList.indexWhere((c) => c.id == itemId);
        if (index != -1) { CarModel oldPart = sparePartsList[index]; sparePartsList[index] = CarModel(id: oldPart.id, sellerId: oldPart.sellerId, itemType: oldPart.itemType, make: oldPart.make, model: oldPart.model, year: oldPart.year, price: oldPart.price, condition: oldPart.condition, description: oldPart.description, images: oldPart.images, createdAt: oldPart.createdAt, hp: oldPart.hp, cc: oldPart.cc, torque: oldPart.torque, transmission: oldPart.transmission, luggageCapacity: oldPart.luggageCapacity, mileage: oldPart.mileage, sellerName: oldPart.sellerName, sellerPhone: oldPart.sellerPhone, sellerLocation: oldPart.sellerLocation, sellerEmail: oldPart.sellerEmail, rating: newAverage, reviewsCount: newCount, viewsCount: oldPart.viewsCount); }
        _blendSpareParts();
      } else {
        int index = carsList.indexWhere((c) => c.id == itemId);
        if (index != -1) { CarModel oldCar = carsList[index]; carsList[index] = CarModel(id: oldCar.id, sellerId: oldCar.sellerId, itemType: oldCar.itemType, make: oldCar.make, model: oldCar.model, year: oldCar.year, price: oldCar.price, condition: oldCar.condition, description: oldCar.description, images: oldCar.images, createdAt: oldCar.createdAt, hp: oldCar.hp, cc: oldCar.cc, torque: oldCar.torque, transmission: oldCar.transmission, luggageCapacity: oldCar.luggageCapacity, mileage: oldCar.mileage, sellerName: oldCar.sellerName, sellerPhone: oldCar.sellerPhone, sellerLocation: oldCar.sellerLocation, sellerEmail: oldCar.sellerEmail, rating: newAverage, reviewsCount: newCount, viewsCount: oldCar.viewsCount); }
      }
    } catch (e) {}
  }

  Future<void> updateReviewFromProfile(String itemId, String reviewId, double newRating, String newComment, {bool isPart = false}) async {
    String? uid = CacheHelper.getData(key: 'uid');
    try {
      String collection = isPart ? 'spare_parts' : 'cars';
      await _firestore.collection(collection).doc(itemId).collection('reviews').doc(reviewId).set({'rating': newRating, 'comment': newComment}, SetOptions(merge: true));
      if (uid != null) { await _firestore.collection('users').doc(uid).collection('my_reviews').doc(reviewId).set({'carId': itemId, 'rating': newRating, 'comment': newComment, 'isPart': isPart}, SetOptions(merge: true)); }
      int revIndex = myReviewsList.indexWhere((r) => r['reviewId'] == reviewId);
      if (revIndex != -1) { myReviewsList[revIndex]['rating'] = newRating; myReviewsList[revIndex]['comment'] = newComment; }
      emit(MarketInitial());

      final snapshot = await _firestore.collection(collection).doc(itemId).collection('reviews').get();
      double totalRating = 0; for (var doc in snapshot.docs) { totalRating += (doc.data()['rating'] as num).toDouble(); }
      double newAverage = snapshot.docs.isEmpty ? 0.0 : totalRating / snapshot.docs.length; int newCount = snapshot.docs.length;
      await _firestore.collection(collection).doc(itemId).update({'rating': newAverage, 'reviewsCount': newCount}).catchError((_){});

      if (isPart) {
        int index = sparePartsList.indexWhere((c) => c.id == itemId);
        if (index != -1) { CarModel oldPart = sparePartsList[index]; sparePartsList[index] = CarModel(id: oldPart.id, sellerId: oldPart.sellerId, itemType: oldPart.itemType, make: oldPart.make, model: oldPart.model, year: oldPart.year, price: oldPart.price, condition: oldPart.condition, description: oldPart.description, images: oldPart.images, createdAt: oldPart.createdAt, hp: oldPart.hp, cc: oldPart.cc, torque: oldPart.torque, transmission: oldPart.transmission, luggageCapacity: oldPart.luggageCapacity, mileage: oldPart.mileage, sellerName: oldPart.sellerName, sellerPhone: oldPart.sellerPhone, sellerLocation: oldPart.sellerLocation, sellerEmail: oldPart.sellerEmail, rating: newAverage, reviewsCount: newCount, viewsCount: oldPart.viewsCount); }
        _blendSpareParts();
      } else {
        int index = carsList.indexWhere((c) => c.id == itemId);
        if (index != -1) { CarModel oldCar = carsList[index]; carsList[index] = CarModel(id: oldCar.id, sellerId: oldCar.sellerId, itemType: oldCar.itemType, make: oldCar.make, model: oldCar.model, year: oldCar.year, price: oldCar.price, condition: oldCar.condition, description: oldCar.description, images: oldCar.images, createdAt: oldCar.createdAt, hp: oldCar.hp, cc: oldCar.cc, torque: oldCar.torque, transmission: oldCar.transmission, luggageCapacity: oldCar.luggageCapacity, mileage: oldCar.mileage, sellerName: oldCar.sellerName, sellerPhone: oldCar.sellerPhone, sellerLocation: oldCar.sellerLocation, sellerEmail: oldCar.sellerEmail, rating: newAverage, reviewsCount: newCount, viewsCount: oldCar.viewsCount); }
      }
    } catch(e){}
  }

  Future<void> updateCar({required String carId, required String itemType, required String make, required String model, required String year, required double price, required String condition, required String description, required String hp, required String cc, required String torque, required String transmission, required String luggageCapacity, required String mileage, required String sellerName, required String sellerPhone, required String sellerLocation, required String sellerEmail, required bool isPromoted,}) async { emit(AddCarLoading()); try { Map<String, dynamic> updatedData = { 'itemType': itemType, 'make': make, 'model': model, 'year': year, 'price': price, 'condition': condition, 'description': description, 'hp': hp, 'cc': cc, 'torque': torque, 'transmission': transmission, 'luggageCapacity': luggageCapacity, 'mileage': mileage, 'sellerName': sellerName, 'sellerPhone': sellerPhone, 'sellerLocation': sellerLocation, 'sellerEmail': sellerEmail, }; String targetCollection; if (itemType == 'type_car') { targetCollection = isPromoted ? 'promoted_cars' : 'cars'; } else { targetCollection = isPromoted ? 'promoted_parts' : 'spare_parts'; } await _firestore.collection(targetCollection).doc(carId).set(updatedData, SetOptions(merge: true)); var reportsQuery = await _firestore.collection('reported_cars').where('carId', isEqualTo: carId).get(); for (var doc in reportsQuery.docs) { await doc.reference.delete(); } reportedCarsList.removeWhere((e) => e['carId'] == carId); if (itemType == 'type_car') { int index = carsList.indexWhere((c) => c.id == carId); if (index != -1) { CarModel oldCar = carsList[index]; carsList[index] = CarModel(id: oldCar.id, sellerId: oldCar.sellerId, itemType: itemType, make: make, model: model, year: year, price: price, condition: condition, description: description, hp: hp, cc: cc, torque: torque, transmission: transmission, luggageCapacity: luggageCapacity, mileage: mileage, sellerName: sellerName, sellerPhone: sellerPhone, sellerLocation: sellerLocation, sellerEmail: sellerEmail, images: oldCar.images, createdAt: oldCar.createdAt, rating: oldCar.rating, reviewsCount: oldCar.reviewsCount, viewsCount: oldCar.viewsCount); } int pIndex = promotedCarsList.indexWhere((c) => c.id == carId); if (pIndex != -1) { promotedCarsList[pIndex] = carsList[index]; } } else { int index = sparePartsList.indexWhere((p) => p.id == carId); if (index != -1) { CarModel oldCar = sparePartsList[index]; sparePartsList[index] = CarModel(id: oldCar.id, sellerId: oldCar.sellerId, itemType: itemType, make: make, model: model, year: year, price: price, condition: condition, description: description, hp: hp, cc: cc, torque: torque, transmission: transmission, luggageCapacity: luggageCapacity, mileage: mileage, sellerName: sellerName, sellerPhone: sellerPhone, sellerLocation: sellerLocation, sellerEmail: sellerEmail, images: oldCar.images, createdAt: oldCar.createdAt, rating: oldCar.rating, reviewsCount: oldCar.reviewsCount, viewsCount: oldCar.viewsCount); } } emit(AddCarSuccess()); } catch (e) { emit(AddCarError('err_update_ad_failed')); } }

  List<CarModel> compareCarsList = [];
  void loadCompareCarsFromCache() { String? jsonString = CacheHelper.getData(key: 'cached_compare_cars'); if (jsonString != null) { try { List<dynamic> decodedList = jsonDecode(jsonString); compareCarsList = decodedList.map((item) => CarModel.fromJson(item)).toList(); emit(MarketInitial()); } catch (e) {} } }
  Future<void> _saveCompareCarsToCache() async { await CacheHelper.saveData(key: 'cached_compare_cars', value: jsonEncode(compareCarsList.map((car) => car.toMap()).toList()),); }
  void toggleCompareCar(CarModel car, BuildContext context) { if (isCarInCompare(car.id)) { compareCarsList.removeWhere((c) => c.id == car.id); _saveCompareCarsToCache(); } else { if (compareCarsList.length >= 3) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLang.tr(context, 'err_max_compare') ?? "يمكنك مقارنة 3 سيارات كحد أقصى"), backgroundColor: Colors.red)); return; } compareCarsList.add(car); _saveCompareCarsToCache(); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLang.tr(context, 'success_add_compare') ?? "تم إضافة السيارة للمقارنة"), backgroundColor: Colors.green)); } emit(MarketInitial()); }
  bool isCarInCompare(String carId) { return compareCarsList.any((car) => car.id == carId); }

  bool isFilterActive = false; List<String> selectedFilterBrands = []; double? selectedMaxPrice; List<CarModel> filteredCarsView = []; bool isFetchingFilteredCars = false; bool isFetchingMoreFilteredCars = false;
  void toggleFilterBrand(String brand) { if (selectedFilterBrands.contains(brand)) { selectedFilterBrands.remove(brand); } else { selectedFilterBrands.add(brand); } emit(MarketInitial()); }
  void setFilterPrice(double price) { selectedMaxPrice = price; emit(MarketInitial()); }
  void clearFilters() { isFilterActive = false; selectedFilterBrands.clear(); selectedMaxPrice = null; filteredCarsView.clear(); emit(MarketInitial()); }

  bool _needsImageFix(List<String> images) { if (images.isEmpty || images[0].trim().isEmpty) return true; for (String fallback in _premiumFallbacks) { if (images[0].contains(fallback)) return true; } return false; }

  // 🔥 التعديل: ربط دالة الصورة بالسيرفر بتاعك بدل Serper مباشرة 🔥
  Future<String> _getSmartImage(String make, String model, String year) async {
    String cacheKey = "${year}_${make}_${model}".replaceAll(' ', '_').toLowerCase();
    if (_localImageCache.containsKey(cacheKey)) return _localImageCache[cacheKey]!;
    try {
      DocumentSnapshot cacheDoc = await _firestore.collection('global_image_cache').doc(cacheKey).get();
      if (cacheDoc.exists) { String cachedUrl = cacheDoc.get('imageUrl'); _localImageCache[cacheKey] = cachedUrl; return cachedUrl; }

      final response = await _dio.post('$_baseUrl/api/search/images', options: Options(receiveTimeout: const Duration(seconds: 20), sendTimeout: const Duration(seconds: 20)), data: jsonEncode({"query": "$year $make $model car exterior high quality", "num": 1}));

      if (response.data['images'] != null && (response.data['images'] as List).isNotEmpty) {
        String fetchedUrl = response.data['images'][0]['imageUrl'];
        await _firestore.collection('global_image_cache').doc(cacheKey).set({'imageUrl': fetchedUrl, 'createdAt': DateTime.now().toIso8601String(),});
        _localImageCache[cacheKey] = fetchedUrl;
        return fetchedUrl;
      }
      throw Exception("No image found");
    } catch (e) {
      List<String> fallbacks = List.from(_premiumFallbacks)..shuffle(); return fallbacks.first;
    }
  }

  List<CarModel> savedCarsList = [];
  Future<void> getSavedCars() async { String? userId = CacheHelper.getData(key: 'uid'); if (userId == null || userId.isEmpty) return; emit(SavedCarsLoading()); try { if (carsList.isEmpty || promotedCarsList.isEmpty) { await getCars(); } final snapshot = await _firestore.collection('users').doc(userId).collection('saved_cars').get(); savedCarsList.clear(); for (var doc in snapshot.docs) { int carIndex = carsList.indexWhere((c) => c.id == doc.id); if (carIndex != -1) { savedCarsList.add(carsList[carIndex]); } } emit(SavedCarsSuccess()); } catch (e) { emit(SavedCarsError(e.toString())); } }
  Future<void> toggleSavedCar(CarModel car) async { String? userId = CacheHelper.getData(key: 'uid'); if (userId == null || userId.isEmpty) return; bool isSaved = isCarSaved(car.id); if (isSaved) { savedCarsList.removeWhere((c) => c.id == car.id); } else { savedCarsList.add(car); } emit(SavedCarsSuccess()); try { final docRef = _firestore.collection('users').doc(userId).collection('saved_cars').doc(car.id); if (isSaved) { await docRef.delete(); } else { await docRef.set({'savedAt': DateTime.now().toIso8601String()}); } } catch (e) { await getSavedCars(); } }
  bool isCarSaved(String carId) { return savedCarsList.any((car) => car.id == carId); }

  List<CarModel> savedPartsList = [];
  Future<void> getSavedParts() async { String? userId = CacheHelper.getData(key: 'uid'); if (userId == null || userId.isEmpty) return; emit(SavedCarsLoading()); try { if (sparePartsList.isEmpty || promotedPartsList.isEmpty) { await getSpareParts(); } final snapshot = await _firestore.collection('users').doc(userId).collection('saved_parts').get(); savedPartsList.clear(); for (var doc in snapshot.docs) { String partId = doc.id; CarModel? foundPart; int normalIdx = sparePartsList.indexWhere((p) => p.id == partId); if (normalIdx != -1) foundPart = sparePartsList[normalIdx]; if (foundPart == null) { int vipIdx = promotedPartsList.indexWhere((p) => p.id == partId); if (vipIdx != -1) foundPart = promotedPartsList[vipIdx]; } if (foundPart == null) { var partDoc = await _firestore.collection('spare_parts').doc(partId).get(); if (partDoc.exists) { foundPart = CarModel.fromJson(partDoc.data() as Map<String, dynamic>); } else { partDoc = await _firestore.collection('promoted_parts').doc(partId).get(); if (partDoc.exists) { foundPart = CarModel.fromJson(partDoc.data() as Map<String, dynamic>); } } } if (foundPart != null) { savedPartsList.add(foundPart); } } emit(SavedCarsSuccess()); } catch (e) { emit(SavedCarsError(e.toString())); } }
  Future<void> toggleSavedPart(CarModel part) async { String? userId = CacheHelper.getData(key: 'uid'); if (userId == null || userId.isEmpty) return; bool isSaved = isPartSaved(part.id); if (isSaved) { savedPartsList.removeWhere((p) => p.id == part.id); } else { savedPartsList.add(part); } emit(SavedCarsSuccess()); try { final docRef = _firestore.collection('users').doc(userId).collection('saved_parts').doc(part.id); if (isSaved) { await docRef.delete(); } else { await docRef.set({'savedAt': DateTime.now().toIso8601String()}); } } catch (e) { await getSavedParts(); } }
  bool isPartSaved(String partId) { return savedPartsList.any((part) => part.id == partId); }

  List<Map<String, dynamic>> reportedCarsList = []; bool isLoadingReports = false;
  Future<void> getReportedCars() async { isLoadingReports = true; emit(MarketInitial()); try { final snapshot = await _firestore.collection('reported_cars').where('status', isEqualTo: 'pending').get(); reportedCarsList = snapshot.docs.map((doc) { var data = doc.data(); data['reportId'] = doc.id; return data; }).toList(); } catch (e) { } finally { isLoadingReports = false; emit(MarketInitial()); } }
  Future<void> deleteReportedCar(String reportId, String carId, bool isPart) async { emit(AddCarLoading()); try { String collection = isPart ? 'spare_parts' : 'cars'; await _firestore.collection(collection).doc(carId).delete(); String promotedCollection = isPart ? 'promoted_parts' : 'promoted_cars'; await _firestore.collection(promotedCollection).doc(carId).delete(); var reportsQuery = await _firestore.collection('reported_cars').where('carId', isEqualTo: carId).get(); for (var doc in reportsQuery.docs) { await doc.reference.delete(); } carsList.removeWhere((e) => e.id == carId); promotedCarsList.removeWhere((e) => e.id == carId); sparePartsList.removeWhere((e) => e.id == carId); promotedPartsList.removeWhere((e) => e.id == carId); reportedCarsList.removeWhere((e) => e['carId'] == carId); if (!isPart) { _blendSpareParts(); } emit(MarketInitial()); } catch (e) { emit(AddCarError('err_delete_ad_failed')); } }

  void _sortFilteredCars() { filteredCarsView.sort((a, b) { int yearA = int.tryParse(a.year.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0; int yearB = int.tryParse(b.year.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0; if (yearA != yearB) { return yearB.compareTo(yearA); } return b.createdAt.compareTo(a.createdAt); }); }


  // 🔥 1. دالة تطبيق الفلتر (بتبص في اللوكال/الفايربيز الأول) 🔥


  // 🔥 1. تطبيق الفلتر (اللوكال أولاً) 🔥
  Future<void> applyFilters() async {
    if (selectedFilterBrands.isEmpty && selectedMaxPrice == null) {
      clearFilters();
      return;
    }

    isFilterActive = true;
    filteredCarsView.clear(); // تفريغ القديم عشان الـ UI يعرض اللودينج
    emit(FilterCarsLoading());

    // ندور في اللوكال
    filteredCarsView = carsList.where((car) {
      bool matchesBrand = selectedFilterBrands.isEmpty || selectedFilterBrands.any((brand) => car.make.toLowerCase().contains(brand.toLowerCase()));
      bool matchesPrice = selectedMaxPrice == null || car.price <= selectedMaxPrice!;
      return matchesBrand && matchesPrice;
    }).toList();

    _sortFilteredCars();

    // لو اللوكال مفيهوش 4 عربيات، نكلم الـ API يولد ويسجل
    if (filteredCarsView.length < 4) {
      await fetchFilteredCarsFromAI(isLoadMore: false);
    } else {
      emit(GetCarsSuccess());
    }
  }

  // 🔥 2. جلب العربيات من الـ API وتسجيلها في الفايربيز 🔥
  Future<void> fetchFilteredCarsFromAI({bool isLoadMore = false}) async {
    if (isLoadMore) {
      if (isFetchingMoreFilteredCars) return;
      isFetchingMoreFilteredCars = true;
      emit(FilterCarsLoadingMore());
    } else {
      isFetchingFilteredCars = true;
      emit(FilterCarsLoading());
    }

    String brandCondition = selectedFilterBrands.isNotEmpty ? "The car make MUST be exactly one of these: [${selectedFilterBrands.join(', ')}]." : "";
    String priceCondition = selectedMaxPrice != null ? "The price MUST be strictly under ${selectedMaxPrice!.toInt()} EGP." : "";

    try {
      final aiResponse = await _dio.post(
          '$_baseUrl/api/ai/chat',
          options: Options(receiveTimeout: const Duration(seconds: 25), sendTimeout: const Duration(seconds: 25)),
          data: {
            "messages": [
              {"role": "system", "content": "You are a database of cars in Egypt in $_currentYear. Generate a JSON array of 4 car objects: [{\"make\":\"...\",\"model\":\"...\",\"year\":\"...\",\"price\":1000000,\"condition\":\"used_condition\",\"hp\":\"...\",\"cc\":\"...\",\"torque\":\"...\",\"mileage\":\"...\"}]"},
              {"role": "user", "content": "Generate 4 realistic cars available in Egypt. STRICT CONDITIONS: $brandCondition $priceCondition Mix the years between ${_currentYear - 4} and $_currentYear, but prioritize newer models."}
            ],
            "temperature": 0.8
          }
      );

      if (aiResponse.statusCode == 200 && aiResponse.data != null && aiResponse.data['choices'] != null) {
        String responseText = aiResponse.data['choices'][0]['message']['content'];
        int startIndex = responseText.indexOf('[');
        int endIndex = responseText.lastIndexOf(']');

        if (startIndex != -1 && endIndex != -1) {
          List<dynamic> generatedCars = jsonDecode(responseText.substring(startIndex, endIndex + 1));
          List<CarModel> tempFetchedCars = [];

          // 🔥 حماية فردية لكل عربية: لو واحدة فشلت التانيين يكملوا 🔥
          for (var aiCar in generatedCars) {
            try {
              String make = aiCar['make'].toString().toUpperCase();
              String model = aiCar['model'].toString().toUpperCase();
              String year = aiCar['year'].toString();
              String imageUrl = await _getSmartImage(make, model, year);
              String docId = _firestore.collection('cars').doc().id;

              CarModel fetchedCar = CarModel(
                  id: docId, sellerId: 'ai_filter', itemType: 'type_car', make: make, model: model, year: year,
                  price: double.tryParse(aiCar['price'].toString()) ?? 1000000.0, condition: aiCar['condition'] ?? 'used_condition',
                  description: '✨ سيارة متطابقة مع فلاتر البحث الخاصة بك.', images: [imageUrl], createdAt: DateTime.now().toIso8601String(),
                  hp: aiCar['hp']?.toString() ?? 'N/A', cc: aiCar['cc']?.toString() ?? 'N/A', torque: aiCar['torque']?.toString() ?? 'N/A',
                  transmission: 'Automatic', luggageCapacity: 'N/A', mileage: aiCar['mileage']?.toString() ?? '0',
                  sellerName: 'GEAR UP Search', sellerPhone: '16000', sellerLocation: 'مصر', sellerEmail: '', rating: 0.0, reviewsCount: 0
              );

              // التسجيل في الفايربيز
              await _firestore.collection('cars').doc(docId).set(fetchedCar.toMap());

              carsList.add(fetchedCar);
              tempFetchedCars.add(fetchedCar);
            } catch (e) {
              print("Skipped one car due to error: $e");
            }
          }

          filteredCarsView.addAll(tempFetchedCars);
        }
      }
    } catch (e) {
      print("Filter API Error: $e");
    }

    _sortFilteredCars();

    if (isLoadMore) {
      isFetchingMoreFilteredCars = false;
    } else {
      isFetchingFilteredCars = false;
    }

    emit(GetCarsSuccess()); // عرض العربيات على الشاشة
  }
  Future<List<CarModel>> getActualTopRatedCars() async { try { List<CarModel> topCars = carsList.where((car) => car.rating >= 4.0 && car.reviewsCount > 0).toList(); topCars.sort((a, b) => b.rating.compareTo(a.rating)); return topCars; } catch (e) { return []; } }

  // ========================================================
  // 🔥 دالة مسح الإعلان 🔥
  // ========================================================
  Future<void> deleteUserItem(CarModel item) async {
    emit(AddCarLoading());
    try {
      bool isCar = item.itemType == 'type_car';
      bool isPromoted = promotedCarsList.any((e) => e.id == item.id) || promotedPartsList.any((e) => e.id == item.id);
      String collection = '';
      if (isCar) { collection = isPromoted ? 'promoted_cars' : 'cars'; } else { collection = isPromoted ? 'promoted_parts' : 'spare_parts'; }

      var reviewsQuery = await _firestore.collection(collection).doc(item.id).collection('reviews').get();
      for (var doc in reviewsQuery.docs) {
        await doc.reference.delete();
      }

      await _firestore.collection(collection).doc(item.id).delete();
      carsList.removeWhere((e) => e.id == item.id);
      promotedCarsList.removeWhere((e) => e.id == item.id);
      sparePartsList.removeWhere((e) => e.id == item.id);
      promotedPartsList.removeWhere((e) => e.id == item.id);
      if (!isCar) { _blendSpareParts(); }
      emit(MarketInitial());
    } catch (e) { emit(AddCarError("err_delete_ad_failed")); }
  }

  // ========================================================
  // 🔥 دالة الإدارة: اتخاذ قرار في البلاغات 🔥
  // ========================================================
  Future<void> resolveReportedReview({
    required String reportId,
    required String itemId,
    required String reviewId,
    required bool isPart,
    required String action, // 'delete' أو 'dismiss'
  }) async {
    try {
      if (action == 'delete') {
        String collection = isPart ? 'spare_parts' : 'cars';
        DocumentSnapshot reviewDoc = await _firestore.collection(collection).doc(itemId).collection('reviews').doc(reviewId).get();

        if (reviewDoc.exists) {
          String originalUserId = reviewDoc.get('userId') ?? '';

          await reviewDoc.reference.delete();

          if (originalUserId.isNotEmpty && !originalUserId.startsWith('guest_')) {
            await _firestore.collection('users').doc(originalUserId).collection('my_reviews').doc(reviewId).delete();
          }

          final snapshot = await _firestore.collection(collection).doc(itemId).collection('reviews').get();
          double totalRating = 0;
          for (var doc in snapshot.docs) { totalRating += (doc.data()['rating'] as num).toDouble(); }
          double newAverage = snapshot.docs.isEmpty ? 0.0 : totalRating / snapshot.docs.length;
          int newCount = snapshot.docs.length;

          await _firestore.collection(collection).doc(itemId).update({
            'rating': newAverage, 'reviewsCount': newCount
          }).catchError((_){});

          if (isPart) {
            int index = sparePartsList.indexWhere((c) => c.id == itemId);
            if (index != -1) {
              CarModel oldItem = sparePartsList[index];
              sparePartsList[index] = CarModel(id: oldItem.id, sellerId: oldItem.sellerId, itemType: oldItem.itemType, make: oldItem.make, model: oldItem.model, year: oldItem.year, price: oldItem.price, condition: oldItem.condition, description: oldItem.description, images: oldItem.images, createdAt: oldItem.createdAt, hp: oldItem.hp, cc: oldItem.cc, torque: oldItem.torque, transmission: oldItem.transmission, luggageCapacity: oldItem.luggageCapacity, mileage: oldItem.mileage, sellerName: oldItem.sellerName, sellerPhone: oldItem.sellerPhone, sellerLocation: oldItem.sellerLocation, sellerEmail: oldItem.sellerEmail, rating: newAverage, reviewsCount: newCount, viewsCount: oldItem.viewsCount);
            }
            _blendSpareParts();
          } else {
            int index = carsList.indexWhere((c) => c.id == itemId);
            if (index != -1) {
              CarModel oldItem = carsList[index];
              carsList[index] = CarModel(id: oldItem.id, sellerId: oldItem.sellerId, itemType: oldItem.itemType, make: oldItem.make, model: oldItem.model, year: oldItem.year, price: oldItem.price, condition: oldItem.condition, description: oldItem.description, images: oldItem.images, createdAt: oldItem.createdAt, hp: oldItem.hp, cc: oldItem.cc, torque: oldItem.torque, transmission: oldItem.transmission, luggageCapacity: oldItem.luggageCapacity, mileage: oldItem.mileage, sellerName: oldItem.sellerName, sellerPhone: oldItem.sellerPhone, sellerLocation: oldItem.sellerLocation, sellerEmail: oldItem.sellerEmail, rating: newAverage, reviewsCount: newCount, viewsCount: oldItem.viewsCount);
            }
          }
        }
      }

      await _firestore.collection('reported_reviews').doc(reportId).delete();
      emit(MarketInitial());

    } catch (e) {
      print("Error resolving report: $e");
    }
  }
}
