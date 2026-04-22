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
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

class MarketDefaultState extends MarketState {}

class MarketCubit extends Cubit<MarketState> {
  MarketCubit() : super(MarketInitial()) {
    Future.microtask(() => loadCompareCarsFromCache());
  }
  String? lastGeneratedType; // متغير بيفتكر آخر سكشن اتعرض
// خريطة بتحفظ إحنا وقفنا فين في كل سكشن لوحده
  Map<String, DocumentSnapshot?> lastDocs = {
    'new_cars': null,
    'used_cars': null,
    'promoted': null,
  };  bool hasReachedMaxSearch = false;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final cloudinary = CloudinaryPublic('dfawviyf3', 'zclpevpk', cache: false);
  final Dio _dio = Dio();

  final String _baseUrl = 'https://gear-up-backend.vercel.app';
  int _dynamicSequenceIndex = 0;
  List<CarModel> carsList = [];

  List<Map<String, dynamic>> dynamicBottomSections = [];
  bool isGeneratingDynamicSection = false;
  Set<String> shownDynamicCarIds = {};

  DocumentSnapshot? lastCarDocument;
  bool hasMoreCarsInFirebase = true;
  bool isFetchingMoreFirebase = false;

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
  Map<String, String> generatedCarDescriptions = {};
  CancelToken? descriptionCancelToken;

  Future<void> generateCarDescription(String carId, String make, String model, String year, bool isPromoted) async {
    bool isDummyDescription = generatedCarDescriptions[carId] != null && generatedCarDescriptions[carId]!.contains('بتصميم عصري');
    if (generatedCarDescriptions.containsKey(carId) && !isDummyDescription) { emit(CarDescriptionUpdatedState()); return; }
    descriptionCancelToken?.cancel("تم الخروج من الشاشة"); descriptionCancelToken = CancelToken();
    String finalDescription = "";
    try {
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
  bool isSearchingMorePartsSearch = false;
  int partSearchApiOffset = 0;
  bool hasReachedMaxPartSearch = false;
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

  Future<void> searchSpecificCar(String query, {bool isLoadMore = false, bool isPart = false}) async {
    if (query.trim().isEmpty) return;

    // منع تكرار الطلبات لو وصلنا لآخر البحث أو بنحمل حالياً
    if (isLoadMore && (isPart ? (isSearchingMorePartsSearch || hasReachedMaxPartSearch) : (isSearchingMore || hasReachedMaxSearch))) return;

    final parsedData = parseSearchQuery(query, isPart: isPart);
    final List<String> searchWords = parsedData['words'];
    final String possibleMake = searchWords.isNotEmpty ? searchWords.first : '';

    if (!isLoadMore) {
      // حفظ تاريخ البحث (Search History)
      List<String> searchHistory = CacheHelper.getStringList(key: 'search_history') ?? [];
      searchHistory.remove(query.trim());
      searchHistory.insert(0, query.trim());
      if (searchHistory.length > 10) { searchHistory = searchHistory.sublist(0, 10); }
      CacheHelper.saveData(key: 'search_history', value: searchHistory);

      emit(SearchCarsLoading());

      if (isPart) {
        partsSearchResults.clear();
        partSearchApiOffset = 0;
        hasReachedMaxPartSearch = false;
        isSearchingMorePartsSearch = true;
      } else {
        searchResults.clear();
        searchApiOffset = 0;
        hasReachedMaxSearch = false;
        isSearchingMore = true;
      }

      // 1. البحث المحلي
      String lowerQuery = query.toLowerCase().trim();
      Set<String> addedIds = {};

      void searchInList(List<CarModel> list, List<CarModel> targetList) {
        for (var item in list) {
          if (!addedIds.contains(item.id)) {
            if (item.make.toLowerCase().contains(lowerQuery) ||
                item.model.toLowerCase().contains(lowerQuery) ||
                item.description.toLowerCase().contains(lowerQuery) ||
                item.year.contains(lowerQuery)) {
              targetList.add(item);
              addedIds.add(item.id);
            }
          }
        }
      }

      if (isPart) {
        searchInList(promotedPartsList, partsSearchResults);
        searchInList(sparePartsList, partsSearchResults);
      } else {
        searchInList(promotedCarsList, searchResults);
        searchInList(carsList, searchResults);
      }
    } else {
      if (isPart) isSearchingMorePartsSearch = true; else isSearchingMore = true;
      emit(SearchCarsLoadingMore());
    }

    List<CarModel> targetList = isPart ? partsSearchResults : searchResults;

    // 2. البحث في الفايربيز
    if (targetList.length < 4 && possibleMake.isNotEmpty) {
      try {
        String collection = isPart ? 'spare_parts' : 'cars';
        final localDbSearch = await _firestore.collection(collection)
            .where('make', isGreaterThanOrEqualTo: possibleMake.toUpperCase())
            .where('make', isLessThan: '${possibleMake.toUpperCase()}z')
            .limit(10)
            .get();

        for (var doc in localDbSearch.docs) {
          CarModel car = CarModel.fromJson(doc.data() as Map<String, dynamic>);
          if (!targetList.any((c) => c.id == car.id)) {
            targetList.add(car);
            if (!carsList.any((c) => c.id == car.id)) carsList.add(car);
          }
        }
      } catch (e) {
        debugPrint("Firebase Search Error: $e");
      }
    }

    // 3. البحث بالذكاء الاصطناعي وبناء الداتا بيز
    if (isLoadMore || targetList.length < 4) {
      try {
        String finalQuery = query.trim();
        if (isLoadMore) finalQuery = "$finalQuery (مزيد من الخيارات المختلفة)";

        final response = await _dio.post(
          '$_baseUrl/api/search/smart',
          data: {
            "query": finalQuery,
            "offset": isPart ? partSearchApiOffset : searchApiOffset,
            "limit": 10,
          },
        );

        if (response.statusCode == 200 && response.data != null) {
          final data = response.data;
          final List<dynamic> resultsList = data['results'] ?? [];
          List<CarModel> fetchedItems = [];

          for (var item in resultsList) {
            String fetchedMake = item['make']?.toString().trim() ?? '';
            String fetchedModel = item['model']?.toString().trim() ?? '';

            // 🔥 توليد ID فريد لو السيرفر مبعتش عشان اللستة تزيد
            String fetchedId = item['id']?.toString() ?? '';
            if (fetchedId.isEmpty || fetchedId == 'null' || fetchedId.length < 5) {
              fetchedId = _firestore.collection('cars').doc().id;
            }

            List<String> realBrands = [
              'bmw', 'mercedes', 'chevrolet', 'toyota', 'hyundai', 'kia',
              'nissan', 'mitsubishi', 'skoda', 'volkswagen', 'renault',
              'peugeot', 'audi', 'mg', 'lada', 'fiat', 'jeep', 'chery',
              'suzuki', 'honda', 'opel', 'citroen', 'geely', 'byd', 'mazda',
              'subaru', 'ford', 'seat', 'proton', 'dodge', 'chrysler'
            ];

            bool isValidBrand = realBrands.any((brand) => fetchedMake.toLowerCase().contains(brand)) ||
                _carAliases.keys.any((alias) => fetchedMake.toLowerCase().contains(alias));

            if (!isValidBrand && !isPart) {
              continue;
            }

            fetchedItems.add(CarModel(
                id: fetchedId,
                sellerId: item['sellerId']?.toString() ?? 'ai_server',
                itemType: item['itemType']?.toString() ?? (isPart ? 'type_spare_part' : 'type_car'),
                make: fetchedMake.isNotEmpty ? fetchedMake : (isPart ? item['title']?.toString() ?? 'قطعة' : 'Unknown'),
                model: fetchedModel.isNotEmpty ? fetchedModel : (isPart ? item['carCompatibility']?.toString() ?? 'عام' : 'Unknown'),
                year: item['year']?.toString() ?? '2024',
                price: double.tryParse(item['price'].toString()) ?? 10000.0,
                condition: item['condition']?.toString() ?? 'used_condition',
                description: item['description']?.toString() ?? '',
                images: (item['images'] is List) ? List<String>.from(item['images']) : (item['images'] is String ? [item['images']] : []),
                createdAt: item['createdAt']?.toString() ?? DateTime.now().toIso8601String(),
                hp: item['hp']?.toString() ?? 'N/A',
                cc: item['cc']?.toString() ?? 'N/A',
                torque: item['torque']?.toString() ?? 'N/A',
                transmission: item['transmission']?.toString() ?? 'Automatic',
                luggageCapacity: 'N/A',
                mileage: item['mileage']?.toString() ?? '0',
                sellerName: item['sellerName']?.toString() ?? 'GEAR UP Global',
                sellerPhone: '16000',
                sellerLocation: 'مصر',
                sellerEmail: '',
                rating: 0.0,
                reviewsCount: 0,
                viewsCount: 0
            ));
          }

          if (resultsList.isEmpty) {
            if (isPart) hasReachedMaxPartSearch = true; else hasReachedMaxSearch = true;
          } else {
            if (isPart) partSearchApiOffset += resultsList.length; else searchApiOffset += resultsList.length;

            for (var item in fetchedItems) {
              if (!targetList.any((existing) => existing.id == item.id)) {
                targetList.add(item);
                // الحفظ في الفايربيز
                String targetCollection = item.itemType == 'type_spare_part' ? 'spare_parts' : 'cars';
                await _firestore.collection(targetCollection).doc(item.id).set(item.toMap(), SetOptions(merge: true));
              }
            }
          }
        }
      } catch (e) {
        debugPrint("API Search Error: $e");
      }
    }

    if (isPart) isSearchingMorePartsSearch = false; else isSearchingMore = false;
    emit(SearchCarsSuccess());
  } //searchSpecificCar
  void clearSearch({bool isPart = false}) {
    if (isPart) {
      partsSearchResults.clear();
      partSearchApiOffset = 0;
      hasReachedMaxPartSearch = false;
    } else {
      searchResults.clear();
      searchApiOffset = 0;
      hasReachedMaxSearch = false;
    }
    _loadedSearchModels.clear();
    _currentSearchYear = _currentYear;
    emit(MarketInitial());
  }

  bool isSearchingCategoryAPI = false;
  Future<void> searchCategoryCarsFromAI(String query, String categoryTitle) async {
    if (isSearchingCategoryAPI) return;
    isSearchingCategoryAPI = true;
    emit(SearchCarsLoadingMore());

    final parsedData = parseSearchQuery(query);
    final String cleanSearchString = parsedData['cleanQueryForAi'];
    final String? searchYear = parsedData['year'];
    String conditionPrompt = "";
    String expectedCondition = "used_condition";

    if (categoryTitle.toLowerCase().contains("new") || categoryTitle.contains("جديد")) {
      conditionPrompt = "CRITICAL: You MUST set condition to 'new_condition' and mileage to '0'. Do NOT generate used cars.";
      expectedCondition = "new_condition";
    } else if (categoryTitle.toLowerCase().contains("used") || categoryTitle.contains("مستعمل")) {
      conditionPrompt = "CRITICAL: You MUST set condition to 'used_condition'. Do NOT generate new cars.";
      expectedCondition = "used_condition";
    }

    try {
      // =================================================================
      // 1. خطوة الكاشينج (البحث في الفايربيز أولاً لتوفير استهلاك الـ API)
      // =================================================================
      Query queryRef = _firestore.collection('cars')
          .where('sellerId', isEqualTo: 'ai_search_category')
          .where('condition', isEqualTo: expectedCondition);

      if (searchYear != null) {
        queryRef = queryRef.where('year', isEqualTo: searchYear);
      }

      final localSnapshot = await queryRef.limit(15).get();
      List<CarModel> cachedCars = [];

      for (var doc in localSnapshot.docs) {
        CarModel car = CarModel.fromJson(doc.data() as Map<String, dynamic>);
        // نتأكد إن العربية مش معروضة في اللستة قبل كده عشان نتجنب التكرار
        if (!carsList.any((c) => c.id == car.id)) {
          cachedCars.add(car);
        }
      }

      // لو لقينا 4 عربيات على الأقل، نستخدمهم ونقفل الدالة
      if (cachedCars.length >= 4) {
        final selectedCars = cachedCars.take(4).toList();
        for (var car in selectedCars) {
          carsList.add(car);
          if (expectedCondition == 'new_condition') {
            newCarsList.add(car);
          } else {
            usedCarsList.add(car);
          }
          _loadedHomeModels.add("${car.make.toUpperCase()} ${car.model.toUpperCase()}");
        }
        isSearchingCategoryAPI = false;
        emit(SearchCarsSuccess());
        return; // خروج مبكر بدون استدعاء السيرفر
      }

      // =================================================================
      // 2. لو مفيش كاش، نكلم الـ API ونولد عربيات جديدة ونحفظها للمستقبل
      // =================================================================
      String yearPrompt = searchYear != null ? "ALL 4 cars MUST be exactly from the year $searchYear." : "Mix the years between ${_currentYear - 4} and $_currentYear.";
      String avoidModels = _loadedHomeModels.isEmpty ? "None" : _loadedHomeModels.take(20).join(", ");

      final aiResponse = await _dio.post('$_baseUrl/api/ai/chat', data: {"messages": [{"role": "system", "content": "Generate a JSON array of 4 car objects available in Egypt. Format: [{\"make\":\"...\",\"model\":\"...\",\"year\":\"...\",\"price\":1000000,\"condition\":\"$expectedCondition\",\"hp\":\"...\",\"cc\":\"...\",\"torque\":\"...\",\"mileage\":\"...\"}]"}, {"role": "user", "content": "Generate 4 realistic distinct variants for the brand/model: '${cleanSearchString.isEmpty ? 'Cars in Egypt' : cleanSearchString}'. $conditionPrompt $yearPrompt DO NOT use these exact models: [$avoidModels]. Use realistic EGP prices for year $_currentYear."}], "temperature": 0.8});

      if (aiResponse.statusCode == 200) {
        String responseText = aiResponse.data['choices'][0]['message']['content'];
        int startIndex = responseText.indexOf('[');
        int endIndex = responseText.lastIndexOf(']');
        if (startIndex != -1 && endIndex != -1) {
          try {
            String jsonArray = responseText.substring(startIndex, endIndex + 1);
            List<dynamic> generatedCars = jsonDecode(jsonArray);
            List<Future<void>> futures = generatedCars.map<Future<void>>((aiCar) async {
              String make = aiCar['make'].toString().toUpperCase();
              String model = aiCar['model'].toString().toUpperCase();
              String year = aiCar['year'].toString();
              String imageUrl = await _getSmartImage(make, model, year);
              String docId = _firestore.collection('cars').doc().id;
              String finalCondition = expectedCondition;
              _loadedHomeModels.add("$make $model");

              CarModel fetchedCar = CarModel(id: docId, sellerId: 'ai_search_category', itemType: 'type_car', make: make, model: model, year: year, price: double.tryParse(aiCar['price'].toString()) ?? 1500000.0, condition: finalCondition, description: '✨ تم جلب المواصفات عبر الذكاء الاصطناعي بناءً على بحثك.', images: [imageUrl], createdAt: DateTime.now().toIso8601String(), hp: aiCar['hp']?.toString() ?? 'N/A', cc: aiCar['cc']?.toString() ?? 'N/A', torque: aiCar['torque']?.toString() ?? 'N/A', transmission: 'Automatic', luggageCapacity: 'N/A', mileage: finalCondition == 'new_condition' ? '0' : (aiCar['mileage']?.toString() ?? '50000'), sellerName: 'GEAR UP Search', sellerPhone: '16000', sellerLocation: 'مصر', sellerEmail: '', rating: 0.0, reviewsCount: 0);

              // سطر الحفظ في الفايربيز مهم جداً هنا عشان الكاش يشتغل المرة الجاية
              await _firestore.collection('cars').doc(docId).set(fetchedCar.toMap());
              carsList.add(fetchedCar);
              if (finalCondition == 'new_condition') { newCarsList.add(fetchedCar); } else { usedCarsList.add(fetchedCar); }
            }).toList();
            await Future.wait(futures);
          } catch(jsonErr) {
            debugPrint("AI JSON Format Error: $jsonErr");
          }
        }
      }
    } catch (e) { }
    isSearchingCategoryAPI = false;
    emit(SearchCarsSuccess());
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

  DocumentSnapshot? lastPartDocument;
  bool hasMorePartsInFirebase = true;
  bool isFetchingMoreFirebaseParts = false;

  Future<void> getSpareParts({bool isRefresh = false}) async {
    if (isRefresh) {
      lastPartDocument = null;
      hasMorePartsInFirebase = true;
      sparePartsList.clear();
      feedSparePartsList.clear();
      promotedPartsList.clear();
      _loadedPartsNames.clear();
    }

    // لو اللستة مليانة ومش بنعمل ريفريش، مفيش داعي نسحب تاني
    if (sparePartsList.isNotEmpty && !isRefresh) return;

    emit(SearchCarsLoading());
    isFetchingParts = true;

    try {
      DateTime fiveMonthsAgo = DateTime.now().subtract(const Duration(days: 150));
      String cutoffDate = fiveMonthsAgo.toIso8601String();

      // سحب الداتا النظيفة بس بالـ Limit عشان الشاشة متهنجش
      final results = await Future.wait([
        _firestore.collection('spare_parts')
            .where('createdAt', isGreaterThanOrEqualTo: cutoffDate)
            .orderBy('createdAt', descending: true)
            .limit(20)
            .get(),
        _firestore.collection('promoted_parts')
            .where('createdAt', isGreaterThanOrEqualTo: cutoffDate)
            .orderBy('createdAt', descending: true)
            .limit(20) // <--- الـ Limit اللي كان ناقص
            .get()
      ]);

      sparePartsList.clear();
      promotedPartsList.clear();

      // معالجة قطع الغيار الممولة
      for (var doc in results[1].docs) {
        final partData = doc.data() as Map<String, dynamic>;

        promotedPartsList.add(CarModel(
          id: doc.id, sellerId: partData['sellerId']?.toString() ?? 'unknown', itemType: 'type_spare_part',
          make: partData['title']?.toString() ?? partData['make']?.toString() ?? 'قطعة غيار',
          model: partData['carCompatibility']?.toString() ?? partData['model']?.toString() ?? 'متوافق مع جميع السيارات',
          year: partData['year']?.toString() ?? '0', price: double.tryParse(partData['price']?.toString() ?? '500') ?? 500.0,
          condition: partData['condition']?.toString() ?? 'new', description: partData['description']?.toString() ?? '',
          images: (partData['images'] is List) ? List<String>.from(partData['images']) : (partData['images'] is String ? [partData['images']] : []),
          createdAt: partData['createdAt']?.toString() ?? DateTime.now().toIso8601String(),
          hp: 'N/A', cc: 'N/A', torque: 'N/A', transmission: 'N/A', luggageCapacity: 'N/A', mileage: '0',
          sellerName: partData['sellerName']?.toString() ?? 'GEAR UP', sellerPhone: '16000', sellerLocation: 'مصر', sellerEmail: '', rating: 0.0, reviewsCount: 0, viewsCount: 0,
        ));
      }

      // معالجة قطع الغيار العادية
      final QuerySnapshot normalPartsSnapshot = results[0];
      if (normalPartsSnapshot.docs.isNotEmpty) {
        lastPartDocument = normalPartsSnapshot.docs.last;

        for (var doc in normalPartsSnapshot.docs) {
          final partData = doc.data() as Map<String, dynamic>;
          sparePartsList.add(CarModel(
            id: doc.id, sellerId: partData['sellerId']?.toString() ?? 'ai_server', itemType: 'type_spare_part',
            make: partData['title']?.toString() ?? partData['make']?.toString() ?? 'قطعة غيار',
            model: partData['carCompatibility']?.toString() ?? partData['model']?.toString() ?? 'متوافق مع جميع السيارات',
            year: partData['year']?.toString() ?? '0', price: double.tryParse(partData['price']?.toString() ?? '500') ?? 500.0,
            condition: partData['condition']?.toString() ?? 'new', description: partData['description']?.toString() ?? '',
            images: (partData['images'] is List) ? List<String>.from(partData['images']) : (partData['images'] is String ? [partData['images']] : []),
            createdAt: partData['createdAt']?.toString() ?? DateTime.now().toIso8601String(),
            hp: 'N/A', cc: 'N/A', torque: 'N/A', transmission: 'N/A', luggageCapacity: 'N/A', mileage: '0',
            sellerName: partData['sellerName']?.toString() ?? 'GEAR UP', sellerPhone: '16000', sellerLocation: 'مصر', sellerEmail: '', rating: 0.0, reviewsCount: 0, viewsCount: 0,
          ));
        }
      } else {
        hasMorePartsInFirebase = false;
      }

      _blendSpareParts();

      if (sparePartsList.isEmpty) {
        await searchSpecificCar("قطع غيار", isPart: true);
      } else {
        emit(SearchCarsSuccess());
      }

      // التنظيف في الخلفية (Fire and Forget)
      _cleanUpExpiredPartsInBackground(cutoffDate);

    } catch (e) {
      emit(SearchCarsSuccess());
    } finally {
      isFetchingParts = false;
    }
  }

  // دالة التنظيف في الخلفية لقطع الغيار
  Future<void> _cleanUpExpiredPartsInBackground(String cutoffDate) async {
    try {
      final expiredParts = await _firestore
          .collection('spare_parts')
          .where('createdAt', isLessThan: cutoffDate)
          .limit(10)
          .get();

      for (var doc in expiredParts.docs) {
        await doc.reference.delete();
      }

      final expiredPromotedParts = await _firestore
          .collection('promoted_parts')
          .where('createdAt', isLessThan: cutoffDate)
          .limit(10)
          .get();

      for (var doc in expiredPromotedParts.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      debugPrint("Background Parts Cleanup Error: $e");
    }
  }

  Future<void> loadMoreSpareParts() async {
    if (isFetchingMoreFirebaseParts || isFetchingMoreParts) return;

    if (!hasMorePartsInFirebase || lastPartDocument == null) {
      await _fetchMorePartsFromAPI();
      return;
    }

    isFetchingMoreFirebaseParts = true;
    emit(SearchCarsLoadingMore());

    try {
      DateTime fiveMonthsAgo = DateTime.now().subtract(const Duration(days: 150));
      String cutoffDate = fiveMonthsAgo.toIso8601String();

      final QuerySnapshot snapshot = await _firestore
          .collection('spare_parts')
          .where('createdAt', isGreaterThanOrEqualTo: cutoffDate) // حماية إضافية عشان منسحبش المنتهي
          .orderBy('createdAt', descending: true)
          .startAfterDocument(lastPartDocument!)
          .limit(20)
          .get();

      if (snapshot.docs.isEmpty) {
        hasMorePartsInFirebase = false;
        await _fetchMorePartsFromAPI();
      } else {
        lastPartDocument = snapshot.docs.last;
        for (var doc in snapshot.docs) {
          final partData = doc.data() as Map<String, dynamic>;
          if (!sparePartsList.any((part) => part.id == doc.id)) {
            sparePartsList.add(CarModel(
              id: doc.id, sellerId: partData['sellerId']?.toString() ?? 'ai_server', itemType: 'type_spare_part',
              make: partData['title']?.toString() ?? partData['make']?.toString() ?? 'قطعة غيار',
              model: partData['carCompatibility']?.toString() ?? partData['model']?.toString() ?? 'متوافق مع جميع السيارات',
              year: partData['year']?.toString() ?? '0', price: double.tryParse(partData['price']?.toString() ?? '500') ?? 500.0,
              condition: partData['condition']?.toString() ?? 'new', description: partData['description']?.toString() ?? '',
              images: (partData['images'] is List) ? List<String>.from(partData['images']) : (partData['images'] is String ? [partData['images']] : []),
              createdAt: partData['createdAt']?.toString() ?? DateTime.now().toIso8601String(),
              hp: 'N/A', cc: 'N/A', torque: 'N/A', transmission: 'N/A', luggageCapacity: 'N/A', mileage: '0',
              sellerName: partData['sellerName']?.toString() ?? 'GEAR UP', sellerPhone: '16000', sellerLocation: 'مصر', sellerEmail: '', rating: 0.0, reviewsCount: 0, viewsCount: 0,
            ));
          }
        }
        _blendSpareParts();
        isFetchingMoreFirebaseParts = false;
        emit(SearchCarsSuccess());
      }
    } catch (e) {
      isFetchingMoreFirebaseParts = false;
      emit(SearchCarsSuccess());
    }
  }
  Future<void> _fetchMorePartsFromAPI() async {
    isFetchingMoreParts = true;
    emit(SearchCarsLoadingMore());
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
        _blendSpareParts();
      }
    } catch (e) {}
    isFetchingMoreParts = false;
    emit(SearchCarsSuccess());
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

  Future<void> getCars({bool isRefresh = false}) async {
    if (isRefresh) {
      lastCarDocument = null;
      hasMoreCarsInFirebase = true;
      carsList.clear();
      newCarsList.clear();
      usedCarsList.clear();
      promotedCarsList.clear();
      shownDynamicCarIds.clear();
    }

    if (carsList.isNotEmpty && !isRefresh) return;

    emit(GetCarsLoading());
    try {
      // 1. ========================================================
      // الكود الأصلي بتاعك (جلب الداتا والفلترة والمسح)
      // ===========================================================
      final QuerySnapshot aiCarsSnapshot = await _firestore
          .collection('cars')
          .orderBy('createdAt', descending: true)
          .limit(20)
          .get();

      final promotedCarsSnapshot = await _firestore.collection('promoted_cars').get();

      DateTime fiveMonthsAgo = DateTime.now().subtract(const Duration(days: 150));

      for (var doc in promotedCarsSnapshot.docs) {
        CarModel car = CarModel.fromJson(doc.data() as Map<String, dynamic>);
        DateTime createdAt = DateTime.tryParse(car.createdAt) ?? DateTime.now();
        if (createdAt.isBefore(fiveMonthsAgo) || car.sellerId.startsWith('ai_')) {
          if (createdAt.isBefore(fiveMonthsAgo)) await _firestore.collection('promoted_cars').doc(car.id).delete();
          continue;
        }
        if (!carsList.any((c) => c.id == car.id)) {
          carsList.add(car);
          promotedCarsList.add(car);
        }
      }

      if (aiCarsSnapshot.docs.isNotEmpty) {
        lastCarDocument = aiCarsSnapshot.docs.last;

        for (var doc in aiCarsSnapshot.docs) {
          CarModel car = CarModel.fromJson(doc.data() as Map<String, dynamic>);
          DateTime createdAt = DateTime.tryParse(car.createdAt) ?? DateTime.now();
          if (createdAt.isBefore(fiveMonthsAgo)) {
            await _firestore.collection('cars').doc(car.id).delete();
            continue;
          }
          if (!carsList.any((c) => c.id == car.id)) {
            carsList.add(car);
            if (car.condition == 'new_condition') newCarsList.add(car);
            else if (car.condition == 'used_condition') usedCarsList.add(car);
            _loadedHomeModels.add("${car.make.toUpperCase()} ${car.model.toUpperCase()}");
          }
        }
      } else {
        hasMoreCarsInFirebase = false;
      }

      // 2. ========================================================
      // 🔥 الحل الجذري: تأمين السكاشن الثابتة لو طلعت فاضية 🔥
      // ===========================================================
      if (newCarsList.isEmpty) {
        debugPrint("⚠️ [DEBUG] لستة الجديد طلعت فاضية! بنجيب 5 مخصوص...");
        try {
          final newSnapshot = await _firestore.collection('cars')
              .where('condition', isEqualTo: 'new_condition')
              .limit(5).get();
          for (var doc in newSnapshot.docs) {
            CarModel car = CarModel.fromJson(doc.data() as Map<String, dynamic>);
            if (!carsList.any((c) => c.id == car.id)) {
              carsList.add(car);
              newCarsList.add(car);
            }
          }
        } catch (e) {
          debugPrint("❌ [ERROR] إيرور في جلب الجديد: $e");
        }
      }

      if (usedCarsList.isEmpty) {
        debugPrint("⚠️ [DEBUG] لستة المستعمل طلعت فاضية! بنجيب 5 مخصوص...");
        try {
          final usedSnapshot = await _firestore.collection('cars')
              .where('condition', isEqualTo: 'used_condition')
              .limit(5).get();
          for (var doc in usedSnapshot.docs) {
            CarModel car = CarModel.fromJson(doc.data() as Map<String, dynamic>);
            if (!carsList.any((c) => c.id == car.id)) {
              carsList.add(car);
              usedCarsList.add(car);
            }
          }
        } catch (e) {
          debugPrint("❌ [ERROR] إيرور في جلب المستعمل: $e");
        }
      }

      // 3. ========================================================
      // تكملة الكود الأصلي بتاعك
      // ===========================================================
      await getSavedCars();
      await getSavedParts();

      // 4. ========================================================
      // 🔥 صدمة الشاشة (إجبار إعادة الرسم) 🔥
      // ===========================================================
      emit(GetCarsLoading());
      await Future.delayed(const Duration(milliseconds: 100));

      emit(GetCarsSuccess());

    } catch (e) {
      emit(GetCarsError(e.toString()));
    }
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
  Future<void> generateNextDynamicSection() async {
    if (isGeneratingDynamicSection || isFilterActive) return;

    isGeneratingDynamicSection = true;
    emit(MarketInitial());

    try {
      // =========================================================
      // 1. الدالة المساعدة للذكاء الاصطناعي
      // =========================================================
      Future<List<CarModel>> fetchPersonalizedCarsFromAI(String usage, String budget) async {
        List<CarModel> generatedList = [];
        try {
          final localSnapshot = await _firestore.collection('cars').where('sellerId', isEqualTo: 'ai_personalized').limit(15).get();
          for (var doc in localSnapshot.docs) {
            CarModel car = CarModel.fromJson(doc.data() as Map<String, dynamic>);
            if (!carsList.any((c) => c.id == car.id) && !shownDynamicCarIds.contains(car.id)) generatedList.add(car);
          }
          if (generatedList.length >= 4) {
            generatedList = generatedList.take(4).toList();
            carsList.addAll(generatedList);
            for (var car in generatedList) _loadedHomeModels.add("${car.make.toUpperCase()} ${car.model.toUpperCase()}");
            return generatedList;
          }
        } catch (e) { debugPrint("Cache fetch error: $e"); }

        generatedList.clear();
        String avoidModels = _loadedHomeModels.isEmpty ? "None" : _loadedHomeModels.take(20).join(", ");
        try {
          final aiResponse = await _dio.post('$_baseUrl/api/ai/chat', data: {"messages": [{"role": "system", "content": "You are an expert... Generate a JSON array of 4 car objects..."}, {"role": "user", "content": "Generate 4 realistic cars... usage: '$usage'. budget: '$budget'. DO NOT use models: [$avoidModels]."}], "temperature": 0.8});
          if (aiResponse.statusCode == 200) {
            String responseText = aiResponse.data['choices'][0]['message']['content'];
            int startIndex = responseText.indexOf('['); int endIndex = responseText.lastIndexOf(']');
            if (startIndex != -1 && endIndex != -1) {
              try {
                List<dynamic> generatedCars = jsonDecode(responseText.substring(startIndex, endIndex + 1));
                List<Future<void>> futures = generatedCars.map<Future<void>>((aiCar) async {
                  String make = aiCar['make'].toString().toUpperCase(); String model = aiCar['model'].toString().toUpperCase(); String year = aiCar['year'].toString();
                  String imageUrl = await _getSmartImage(make, model, year); String docId = _firestore.collection('cars').doc().id;
                  CarModel fetchedCar = CarModel(id: docId, sellerId: 'ai_personalized', itemType: 'type_car', make: make, model: model, year: year, price: double.tryParse(aiCar['price'].toString()) ?? 1000000.0, condition: aiCar['condition'] ?? 'used_condition', description: '✨ سيارة تم اختيارها خصيصاً لك.', images: [imageUrl], createdAt: DateTime.now().toIso8601String(), hp: aiCar['hp']?.toString() ?? 'N/A', cc: aiCar['cc']?.toString() ?? 'N/A', torque: aiCar['torque']?.toString() ?? 'N/A', transmission: 'Automatic', luggageCapacity: 'N/A', mileage: aiCar['mileage']?.toString() ?? '50000', sellerName: 'GEAR UP Assistant', sellerPhone: '16000', sellerLocation: 'مصر', sellerEmail: '', rating: 0.0, reviewsCount: 0);
                  await _firestore.collection('cars').doc(docId).set(fetchedCar.toMap());
                  carsList.add(fetchedCar); generatedList.add(fetchedCar); _loadedHomeModels.add("$make $model");
                }).toList();
                await Future.wait(futures);
              } catch (jsonErr) { debugPrint("AI JSON Error: $jsonErr"); }
            }
          }
        } catch (e) {}
        return generatedList;
      }

      // =========================================================
      // 🔥 2. حلقة الاختيار ومنع الفراغ 🔥
      // =========================================================
      List<dynamic> finalSourceList = [];
      String finalTitleKey = '';
      String finalSubtitleKey = '';
      bool finalIsPremium = false;
      String finalSelectedType = '';

      int sectionRetry = 0;
      bool sectionFound = false;

      while (!sectionFound && sectionRetry < 3) {
        List<String> availableTypes = ['promoted', 'top_rated', 'new_cars', 'used_cars', 'news'];
        if (CacheHelper.getData(key: 'survey_completed') == true) availableTypes.add('personalized');
        if (lastGeneratedType != null && availableTypes.length > 1) availableTypes.remove(lastGeneratedType);

        availableTypes.shuffle();
        String currentType = availableTypes.first;

        List<dynamic> currentSourceList = [];
        String currentTitleKey = '';
        String currentSubtitleKey = '';
        bool currentIsPremium = false;

        // --- جلب الداتا ---
        if (currentType == 'news') {
          currentTitleKey = 'latest_cars_news'; currentSubtitleKey = 'news_insights';
          currentSourceList = List.from(newsList);
          if (currentSourceList.isEmpty) {
            await fetchMoreNews();
            currentSourceList = List.from(newsList);
          }
        }
        else if (currentType == 'top_rated') {
          // 🔥 هنا شيلنا شرط الفلترة عشان التوب ريتيد يظهر براحته 🔥
          currentSourceList = await getActualTopRatedCars();
          currentTitleKey = 'top_rated_cars'; currentSubtitleKey = 'best_rated_2025'; currentIsPremium = true;
        }
        else if (currentType == 'personalized') {
          String usage = CacheHelper.getData(key: 'pref_carUsage') ?? ''; String budget = CacheHelper.getData(key: 'pref_budget') ?? '';
          currentTitleKey = 'personalized_cars_title'; currentSubtitleKey = usage; currentIsPremium = true;
          currentSourceList = await fetchPersonalizedCarsFromAI(usage, budget);
        }
        else {
          void filterLocalData() {
            if (currentType == 'new_cars') {
              currentSourceList = newCarsList.where((car) => !shownDynamicCarIds.contains(car.id) && !promotedCarsList.any((p)=>p.id==car.id)).toList(); currentTitleKey = 'new_cars'; currentSubtitleKey = 'latest_models';
            } else if (currentType == 'used_cars') {
              currentSourceList = usedCarsList.where((car) => !shownDynamicCarIds.contains(car.id) && !promotedCarsList.any((p)=>p.id==car.id)).toList(); currentTitleKey = 'used_cars'; currentSubtitleKey = 'quality_preowned';
            } else if (currentType == 'promoted') {
              currentSourceList = promotedCarsList.where((car) => car.itemType == 'type_car').toList(); currentTitleKey = 'promoted'; currentSubtitleKey = 'premium_listings'; currentIsPremium = true;
            }
          }

          filterLocalData();

          if (currentSourceList.length < 4) {
            int fbRetry = 0; bool keepFetching = true;
            while (currentSourceList.length < 4 && keepFetching && fbRetry < 3) {
              try {
                String targetCollection = (currentType == 'promoted') ? 'promoted_cars' : 'cars';
                Query query = _firestore.collection(targetCollection);
                if (currentType == 'new_cars') query = query.where('condition', isEqualTo: 'new_condition');
                else if (currentType == 'used_cars') query = query.where('condition', isEqualTo: 'used_condition');

                if (lastDocs[currentType] != null) query = query.startAfterDocument(lastDocs[currentType]!);

                final snapshot = await query.limit(20).get();
                if (snapshot.docs.isEmpty) { keepFetching = false; break; }

                lastDocs[currentType] = snapshot.docs.last;

                for (var doc in snapshot.docs) {
                  CarModel car = CarModel.fromJson(doc.data() as Map<String, dynamic>);
                  if (currentType == 'promoted' || !shownDynamicCarIds.contains(car.id)) {
                    if (currentType == 'promoted') {
                      if (!promotedCarsList.any((c) => c.id == car.id)) promotedCarsList.add(car);
                    } else {
                      if (!carsList.any((c) => c.id == car.id)) carsList.add(car);
                      if (car.condition == 'new_condition' && !newCarsList.any((c)=>c.id==car.id)) newCarsList.add(car);
                      else if (car.condition == 'used_condition' && !usedCarsList.any((c)=>c.id==car.id)) usedCarsList.add(car);
                    }
                  }
                }
                filterLocalData();
                if (currentSourceList.length < 4) fbRetry++;
              } catch (e) { keepFetching = false; }
            }
          }
        }

        if (currentSourceList.isNotEmpty) {
          finalSourceList = currentSourceList; finalTitleKey = currentTitleKey; finalSubtitleKey = currentSubtitleKey; finalIsPremium = currentIsPremium; finalSelectedType = currentType; sectionFound = true;
        } else {
          sectionRetry++; lastGeneratedType = currentType;
        }
      }

      // =========================================================
      // 🔥 3. إضافة السكشن للشاشة (مع استثناء التوب ريتيد والممول) 🔥
      // =========================================================
      if (sectionFound && finalSourceList.isNotEmpty) {
        if (finalSelectedType != 'top_rated' && finalSelectedType != 'news') finalSourceList.shuffle();

        List<dynamic> selectedItems = finalSelectedType == 'news' ? finalSourceList.take(5).toList() : finalSourceList.take(4).toList();

        // 🔥 الاستثناء هنا: لو السكشن توب ريتيد أو ممول أو أخبار، مش بنسجله في قائمة العربيات المحروقة 🔥
        if (finalSelectedType != 'news' && finalSelectedType != 'promoted' && finalSelectedType != 'top_rated') {
          for (var item in selectedItems) shownDynamicCarIds.add(item.id);
        }

        dynamicBottomSections.add({
          'titleKey': finalTitleKey, 'subtitleKey': finalSubtitleKey, 'items': selectedItems, 'type': finalSelectedType, 'isPremium': finalIsPremium
        });

        lastGeneratedType = finalSelectedType;
        debugPrint("✅ تم عرض سكشن: $finalSelectedType بنجاح!");
      }

    } catch (e) {
      debugPrint("❌ Error in generateNextDynamicSection: $e");
    } finally {
      isGeneratingDynamicSection = false;
      emit(MarketInitial());
    }
  }
  Future<void> pickMultipleImages() async { try { final List<XFile> pickedFiles = await _picker.pickMultiImage(); if (pickedFiles.isNotEmpty) { for (var file in pickedFiles) { if (selectedCarImages.length < 10) selectedCarImages.add(File(file.path)); } emit(CarImagePickedSuccess()); } } catch (e) {} } void removeImage(File image) { selectedCarImages.remove(image); emit(MarketInitial()); } void clearSelectedImages() { selectedCarImages.clear(); emit(MarketInitial()); }

  Future<void> addCar({
    required String itemType, required String make, required String model,
    required String year, required double price, required String condition,
    required String description, required String hp, required String cc,
    required String torque, required String transmission, required String luggageCapacity,
    required String mileage, required String sellerName, required String sellerPhone,
    required String sellerLocation, required String sellerEmail,
  }) async {
    emit(AddCarLoading());
    try {
      String? sellerId = CacheHelper.getData(key: 'uid');
      if (sellerId == null) { emit(AddCarError('err_login_first')); return; }

      FormData formData = FormData.fromMap({
        'sellerId': sellerId,
        'itemType': itemType,
        'make': make,
        'model': model,
        'year': year,
        'price': price.toString(),
        'condition': condition,
        'description': description,
        'hp': hp,
        'cc': cc,
        'torque': torque,
        'transmission': transmission,
        'luggageCapacity': luggageCapacity,
        'mileage': mileage,
        'sellerName': sellerName,
        'sellerPhone': sellerPhone,
        'sellerLocation': sellerLocation,
        'sellerEmail': sellerEmail,
        'isPromoted': 'true',
      });

      // =========================================================
      // 🔥 عملية ضغط الصور (Image Compression) 🔥
      // =========================================================
      if (selectedCarImages.isNotEmpty) {
        final tempDir = await getTemporaryDirectory();

        for (int i = 0; i < selectedCarImages.length; i++) {
          File originalImage = selectedCarImages[i];

          // تحديد مسار الصورة المضغوطة المؤقتة
          String targetPath = '${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';

          // عملية الضغط: بنقلل الجودة لـ 70% وبنصغر الأبعاد عشان حجم الصورة يقل من 5 ميجا لـ 200 كيلوبايت تقريباً
          XFile? compressedFile = await FlutterImageCompress.compressAndGetFile(
            originalImage.absolute.path,
            targetPath,
            quality: 70, // جودة 70% ممتازة للويب والموبايل
            minWidth: 1024, // أقصى عرض
            minHeight: 1024, // أقصى طول
            format: CompressFormat.jpeg,
          );

          if (compressedFile != null) {
            // بنرفع الصورة المضغوطة بدل الأصلية
            formData.files.add(MapEntry(
              'images',
              await MultipartFile.fromFile(compressedFile.path, filename: compressedFile.path.split('/').last),
            ));
          } else {
            // لو الضغط فشل لأي سبب (نادر)، ارفع الأصلية كحل بديل
            formData.files.add(MapEntry(
              'images',
              await MultipartFile.fromFile(originalImage.path, filename: originalImage.path.split('/').last),
            ));
          }
        }
      }
      // =========================================================

      final response = await _dio.post(
        '$_baseUrl/api/publish-ad',
        data: formData,
        options: Options(
          receiveTimeout: const Duration(seconds: 90), // زودنا الـ Timeout شوية عشان الرفع
          sendTimeout: const Duration(seconds: 90),
        ),
      );

      // باقي الكود كما هو
      if (response.statusCode == 200 && response.data['item'] != null && response.data['item']['id'] != null) {
        CarModel newItem = CarModel.fromJson(response.data['item'] as Map<String, dynamic>);

        if (itemType == 'type_car') {
          carsList.insert(0, newItem);
          promotedCarsList.insert(0, newItem);
        } else {
          promotedPartsList.insert(0, newItem);
          sparePartsList.insert(0, newItem);
          _blendSpareParts();
        }

        dynamicBottomSections.clear();
        shownDynamicCarIds.clear();
        clearSelectedImages();

        emit(AddCarSuccess());
        emit(MarketInitial());
      } else {
        emit(AddCarError("خطأ من السيرفر: لم يتم النشر بشكل صحيح"));
      }
    } catch (e) {
      debugPrint("Upload Error: $e");
      emit(AddCarError("فشل الاتصال بالسيرفر أثناء النشر. تأكد من جودة الإنترنت."));
    }
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
      // السحر هنا: بنجيب التلاتة في نفس الوقت بدل ما نستنى كل واحد يخلص
      final results = await Future.wait([
        _firestore.collection('users').doc(uid).collection('my_cars').get().timeout(const Duration(seconds: 4)),
        _firestore.collection('users').doc(uid).collection('reminders').orderBy('date').get().timeout(const Duration(seconds: 4)),
        _firestore.collection('users').doc(uid).collection('maintenance').orderBy('date', descending: true).get().timeout(const Duration(seconds: 4)),
      ]);

      myCars = results[0].docs.map((doc) { var data = doc.data(); data['id'] = doc.id; return data; }).toList();
      myReminders = results[1].docs.map((doc) => doc.data()).toList();
      myMaintenanceHistory = results[2].docs.map((doc) => doc.data()).toList();

      await CacheHelper.saveData(key: 'offline_my_cars_$uid', value: jsonEncode(myCars));
      await CacheHelper.saveData(key: 'offline_reminders_$uid', value: jsonEncode(myReminders));
      await CacheHelper.saveData(key: 'offline_maintenance_$uid', value: jsonEncode(myMaintenanceHistory));

      _checkAndTriggerRemindersAlarms();
    } catch (e) {
      // الـ Fallback بتاع الأوفلاين زي ما هو
      String? cC = CacheHelper.getData(key: 'offline_my_cars_$uid');
      if (cC != null) myCars = List<Map<String, dynamic>>.from(jsonDecode(cC));

      String? cR = CacheHelper.getData(key: 'offline_reminders_$uid');
      if (cR != null) myReminders = List<Map<String, dynamic>>.from(jsonDecode(cR));

      String? cM = CacheHelper.getData(key: 'offline_maintenance_$uid');
      if (cM != null) myMaintenanceHistory = List<Map<String, dynamic>>.from(jsonDecode(cM));
    } finally {
      isLoadingMyCar = false;
      emit(GetCarsSuccess());
    }
  }

  Future<void> saveMyVehicleDetails({String? vehicleId, required String make, required String model, required String year, required String mileage, required List<String> imagesUrls,}) async { String? uid = CacheHelper.getData(key: 'uid'); if (uid == null) return; try { String docId = vehicleId ?? _firestore.collection('users').doc(uid).collection('my_cars').doc().id; Map<String, dynamic> data = {'id': docId, 'make': make, 'model': model, 'year': year, 'mileage': mileage, 'images': imagesUrls,}; await _firestore.collection('users').doc(uid).collection('my_cars').doc(docId).set(data, SetOptions(merge: true)); int index = myCars.indexWhere((v) => v['id'] == docId); if (index != -1) { myCars[index] = data; } else { myCars.add(data); } await CacheHelper.saveData(key: 'offline_my_cars_$uid', value: jsonEncode(myCars)); emit(MarketInitial()); } catch (e) { } }

  Future<void> saveReminder({String? id, String? carId, required String task, required String date, required String notes}) async {
    String? uid = CacheHelper.getData(key: 'uid');
    if (uid == null) return;
    try {
      String docId = id ?? _firestore.collection('users').doc(uid).collection('reminders').doc().id;

      String? fcmToken = '';
      try { fcmToken = await FirebaseMessaging.instance.getToken(); } catch (e) {}
      String currentLang = CacheHelper.getData(key: 'lang') ?? 'ar';

      Map<String, dynamic> reminderData = {
        'id': docId, 'userId': uid, 'carId': carId, 'task': task, 'date': date, 'notes': notes,
        'fcmToken': fcmToken ?? '', 'lang': currentLang,
      };

      await _firestore.collection('users').doc(uid).collection('reminders').doc(docId).set(reminderData);

      int index = myReminders.indexWhere((r) => r['id'] == docId);
      if (index != -1) { myReminders[index] = reminderData; } else { myReminders.add(reminderData); }
      myReminders.sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));

      await CacheHelper.saveData(key: 'offline_reminders_$uid', value: jsonEncode(myReminders));

      _checkAndTriggerRemindersAlarms();
      emit(MarketInitial());
    } catch (e) {}
  }

  Future<void> deleteReminder(String id) async { String? uid = CacheHelper.getData(key: 'uid'); if (uid == null) return; try { await _firestore.collection('users').doc(uid).collection('reminders').doc(id).delete(); myReminders.removeWhere((r) => r['id'] == id); await CacheHelper.saveData(key: 'offline_reminders_$uid', value: jsonEncode(myReminders)); emit(MarketInitial()); } catch (e) { } }
  Future<void> saveMaintenanceRecord({String? id, String? carId, required String title, required String date, required String cost, required String desc}) async { String? uid = CacheHelper.getData(key: 'uid'); if (uid == null) return; try { String docId = id ?? _firestore.collection('users').doc(uid).collection('maintenance').doc().id; Map<String, dynamic> maintenanceData = { 'id': docId, 'carId': carId, 'title': title, 'date': date, 'cost': cost, 'desc': desc }; await _firestore.collection('users').doc(uid).collection('maintenance').doc(docId).set(maintenanceData); int index = myMaintenanceHistory.indexWhere((m) => m['id'] == docId); if (index != -1) { myMaintenanceHistory[index] = maintenanceData; } else { myMaintenanceHistory.add(maintenanceData); } myMaintenanceHistory.sort((a, b) => (b['date'] as String).compareTo(a['date'] as String)); await CacheHelper.saveData(key: 'offline_maintenance_$uid', value: jsonEncode(myMaintenanceHistory)); emit(MarketInitial()); } catch (e) { } }
  Future<void> deleteMaintenanceRecord(String id) async { String? uid = CacheHelper.getData(key: 'uid'); if (uid == null) return; try { await _firestore.collection('users').doc(uid).collection('maintenance').doc(id).delete(); myMaintenanceHistory.removeWhere((m) => m['id'] == id); await CacheHelper.saveData(key: 'offline_maintenance_$uid', value: jsonEncode(myMaintenanceHistory)); emit(MarketInitial()); } catch (e) { } }

  List<Map<String, dynamic>> userPaymentMethods = []; List<Map<String, dynamic>> userTransactions = []; bool isLoadingPayments = false;
  Future<void> getPaymentData() async { String? uid = CacheHelper.getData(key: 'uid'); if (uid == null || uid.isEmpty) return; isLoadingPayments = true; emit(MarketInitial()); try { final methodsSnap = await _firestore.collection('users').doc(uid).collection('payment_methods').get(); userPaymentMethods = methodsSnap.docs.map((doc) => doc.data()).toList(); final transSnap = await _firestore.collection('users').doc(uid).collection('transactions').orderBy('timestamp', descending: true).get(); userTransactions = transSnap.docs.map((doc) => doc.data()).toList(); } catch (e) { } finally { isLoadingPayments = false; emit(MarketInitial()); } }
  Future<void> addPaymentMethod({required String type, String? cardNumber, String? cardholderName, String? expiryDate, String? phoneNumber, String? name, String? walletName}) async { String? uid = CacheHelper.getData(key: 'uid'); if (uid == null || uid.isEmpty) return; try { String docId = _firestore.collection('users').doc(uid).collection('payment_methods').doc().id; Map<String, dynamic> methodData = { 'id': docId, 'type': type, 'isDefault': userPaymentMethods.isEmpty, 'createdAt': DateTime.now().toIso8601String() }; if (type == 'Card') { String maskedCard = (cardNumber != null && cardNumber.length >= 4) ? "•••• ${cardNumber.substring(cardNumber.length - 4)}" : "•••• 0000"; methodData.addAll({'title': maskedCard, 'subtitle': "$cardholderName\nExpires $expiryDate"}); } else { methodData.addAll({'title': walletName ?? 'Mobile Wallet', 'subtitle': "$name\n$phoneNumber"}); } userPaymentMethods.add(methodData); emit(SearchCarsLoading()); emit(MarketInitial()); await _firestore.collection('users').doc(uid).collection('payment_methods').doc(docId).set(methodData); } catch (e) {} }
  Future<void> deletePaymentMethod(String id) async { String? uid = CacheHelper.getData(key: 'uid'); if (uid == null) return; try { userPaymentMethods.removeWhere((method) => method['id'] == id); emit(SearchCarsLoading()); emit(MarketInitial()); await _firestore.collection('users').doc(uid).collection('payment_methods').doc(id).delete(); } catch (e) {} }
  Future<void> deleteTransactionRecord(String id) async { String? uid = CacheHelper.getData(key: 'uid'); if (uid == null) return; try { userTransactions.removeWhere((t) => t['id'] == id); emit(SearchCarsLoading()); emit(MarketInitial()); await _firestore.collection('users').doc(uid).collection('transactions').doc(id).delete(); } catch (e) {} }
  Future<void> addTransactionRecord({required String title, required String amount, required String status, required bool isPositive}) async { String? uid = CacheHelper.getData(key: 'uid'); if (uid == null || uid.isEmpty) return; try { String docId = _firestore.collection('users').doc(uid).collection('transactions').doc().id; DateTime now = DateTime.now(); List<String> months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']; String formattedDate = "${months[now.month - 1]} ${now.day}, ${now.year}"; Map<String, dynamic> transactionData = { 'id': docId, 'title': title, 'amount': amount, 'status': status, 'isPositive': isPositive, 'date': formattedDate, 'timestamp': now.toIso8601String() }; userTransactions.insert(0, transactionData); emit(SearchCarsLoading()); emit(MarketInitial()); await _firestore.collection('users').doc(uid).collection('transactions').doc(docId).set(transactionData); } catch (e) {} }

  Future<Map<String, dynamic>> getCarRatingData(String carId) async {
    try {
      final snapshot = await _firestore.collection('cars').doc(carId).collection('reviews').get();
      if (snapshot.docs.isEmpty) return {'average': 0.0, 'count': 0, 'reviews': <Map<String, dynamic>>[]};
      double totalRating = 0; List<Map<String, dynamic>> reviewsList = [];
      for (var doc in snapshot.docs) { final data = doc.data(); data['id'] = doc.id; totalRating += (data['rating'] as num).toDouble(); reviewsList.add(data); }
      return {'average': totalRating / snapshot.docs.length, 'count': snapshot.docs.length, 'reviews': reviewsList};
    } catch (e) { return {'average': 0.0, 'count': 0, 'reviews': <Map<String, dynamic>>[]}; }
  }

  Future<Map<String, dynamic>> getPartRatingData(String partId, {bool isPromoted = false}) async {
    try {
      String collection = isPromoted ? 'promoted_parts' : 'spare_parts';
      final snapshot = await _firestore.collection(collection).doc(partId).collection('reviews').get();
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

      emit(GetCarsSuccess());

      if (sellerId.isNotEmpty && !sellerId.startsWith('ai_')) {
        String currentLang = CacheHelper.getData(key: 'lang') ?? 'ar';
        try { await _dio.post('$_baseUrl/api/notify-review', data: { 'sellerId': sellerId, 'carMake': carMake, 'carModel': carModel, 'isPart': false, 'lang': currentLang }); } catch (e) {}
      }
    } catch (e) {}
  }

  Future<void> addPartReview({required String partId, required String sellerId, required String partMake, required String partModel, required double rating, required String comment, bool isPromoted = false}) async {
    String? uid = CacheHelper.getData(key: 'uid');
    String reviewerName = CacheHelper.getData(key: 'name') ?? 'مستخدم';
    try {
      if (reviewerName == 'مستخدم' && uid != null && !uid.startsWith('guest')) {
        var uDoc = await _firestore.collection('users').doc(uid).get();
        if (uDoc.exists) { reviewerName = uDoc.data()?['name'] ?? uDoc.data()?['userName'] ?? 'مستخدم'; CacheHelper.saveData(key: 'name', value: reviewerName); }
      }

      String collection = isPromoted ? 'promoted_parts' : 'spare_parts';
      String reviewId = _firestore.collection(collection).doc(partId).collection('reviews').doc().id;

      Map<String, dynamic> reviewData = { 'id': reviewId, 'userId': uid ?? 'guest', 'userName': reviewerName, 'rating': rating, 'comment': comment, 'createdAt': DateTime.now().toIso8601String(), 'likes': [] };
      await _firestore.collection(collection).doc(partId).collection('reviews').doc(reviewId).set(reviewData);

      final snapshot = await _firestore.collection(collection).doc(partId).collection('reviews').get();
      double totalRating = 0; for (var doc in snapshot.docs) { totalRating += (doc.data()['rating'] as num).toDouble(); }
      double newAverage = snapshot.docs.isEmpty ? 0.0 : totalRating / snapshot.docs.length; int newCount = snapshot.docs.length;
      await _firestore.collection(collection).doc(partId).update({'rating': newAverage, 'reviewsCount': newCount}).catchError((_){});

      int index = sparePartsList.indexWhere((p) => p.id == partId);
      if (index != -1) { CarModel oldPart = sparePartsList[index]; sparePartsList[index] = CarModel(id: oldPart.id, sellerId: oldPart.sellerId, itemType: oldPart.itemType, make: oldPart.make, model: oldPart.model, year: oldPart.year, price: oldPart.price, condition: oldPart.condition, description: oldPart.description, images: oldPart.images, createdAt: oldPart.createdAt, hp: oldPart.hp, cc: oldPart.cc, torque: oldPart.torque, transmission: oldPart.transmission, luggageCapacity: oldPart.luggageCapacity, mileage: oldPart.mileage, sellerName: oldPart.sellerName, sellerPhone: oldPart.sellerPhone, sellerLocation: oldPart.sellerLocation, sellerEmail: oldPart.sellerEmail, rating: newAverage, reviewsCount: newCount, viewsCount: oldPart.viewsCount); }
      _blendSpareParts();

      if (uid != null) { await _firestore.collection('users').doc(uid).collection('my_reviews').doc(reviewId).set({'carId': partId, 'rating': rating, 'comment': comment, 'createdAt': DateTime.now().toIso8601String(), 'isPart': true}); }

      emit(GetCarsSuccess());

      if (sellerId.isNotEmpty && !sellerId.startsWith('ai_')) {
        String currentLang = CacheHelper.getData(key: 'lang') ?? 'ar';
        try { await _dio.post('$_baseUrl/api/notify-review', data: { 'sellerId': sellerId, 'carMake': partMake, 'carModel': partModel, 'isPart': true, 'lang': currentLang }); } catch (e) {}
      }
    } catch (e) {}
  }

  Future<void> toggleReviewLike({required String carId, required String reviewId, required bool isPart, required bool isLiking}) async {
    String uid = CacheHelper.getData(key: 'uid') ?? '';
    if (uid.isEmpty || uid.startsWith('guest_')) return;

    try {
      String collection = isPart
          ? (promotedPartsList.any((p) => p.id == carId) ? 'promoted_parts' : 'spare_parts')
          : (promotedCarsList.any((c) => c.id == carId) ? 'promoted_cars' : 'cars');

      DocumentReference reviewRef = _firestore.collection(collection).doc(carId).collection('reviews').doc(reviewId);

      if (isLiking) {
        await reviewRef.update({'likes': FieldValue.arrayUnion([uid])});
      } else {
        await reviewRef.update({'likes': FieldValue.arrayRemove([uid])});
      }

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
    emit(MarketInitial());

    String uid = CacheHelper.getData(key: 'uid') ?? '';
    myReviewsList = [];

    if (uid.isNotEmpty && !uid.startsWith('guest_')) {
      try {
        var reviewsQuery = await _firestore.collectionGroup('reviews').where('userId', isEqualTo: uid).get();

        for (var reviewDoc in reviewsQuery.docs) {
          var data = reviewDoc.data();
          String parentId = reviewDoc.reference.parent.parent?.id ?? '';
          String collectionPath = reviewDoc.reference.parent.parent?.parent?.id ?? '';

          if (parentId.isNotEmpty) {
            data['carId'] = parentId;
            data['reviewId'] = reviewDoc.id;
            data['isPart'] = collectionPath == 'spare_parts' || collectionPath == 'promoted_parts';
            data['likes'] = data['likes'] ?? [];
            myReviewsList.add(data);
          }
        }
      } catch (e) {
        print("Get My Reviews Error: $e");
      }
    }

    myReviewsList.sort((a, b) => (b['createdAt'] ?? '').compareTo(a['createdAt'] ?? ''));
    isLoadingMyReviews = false;
    // =========================================================
    // 🔥 تأمين السكاشن الثابتة (مع كشف الأخطاء وإجبار الشاشة) 🔥
    // =========================================================
    debugPrint("🔍 [DEBUG] جاري فحص لستة الجديد قبل قفل getCars... العدد الحالي: ${newCarsList.length}");

    if (newCarsList.isEmpty) {
      debugPrint("⚠️ [DEBUG] اللستة فاضية! بنحاول نجيب 5 عربيات جديدة فوراً من الفايربيز...");
      try {
        final newSnapshot = await _firestore.collection('cars')
            .where('condition', isEqualTo: 'new_condition')
            .limit(5).get();

        debugPrint("✅ [DEBUG] الفايربيز رد بـ ${newSnapshot.docs.length} عربيات جديدة.");

        for (var doc in newSnapshot.docs) {
          CarModel car = CarModel.fromJson(doc.data() as Map<String, dynamic>);
          if (!carsList.any((c) => c.id == car.id)) {
            carsList.add(car);
            newCarsList.add(car);
          }
        }
      } catch (e) {
        debugPrint("❌ [ERROR] حصل إيرور وإحنا بنجيب الجديد المخصوص: $e");
      }
    }

    // ... (ممكن تحط نفس البلوك للـ usedCarsList هنا لو حابب) ...

    // =========================================================
    // 🔥 السحر هنا: إجبار الشاشة على الريفرش فوراً 🔥
    // =========================================================
    emit(MarketLoading()); // صدمة للشاشة عشان تمسح الكاش بتاعها
    await Future.delayed(const Duration(milliseconds: 100)); // انتظار جزء من الثانية
    emit(MarketInitial()); // ابعت حالة النجاح النهائية بتاعتك (أو GetCarsSuccess)
    emit(GetCarsSuccess());
  }

  Future<void> deleteMyReview(String itemId, String reviewId, {String? originalUserId, bool isPart = false}) async {
    String? currentUid = CacheHelper.getData(key: 'uid');
    try {
      if (reviewId.isEmpty) return;
      String collection = isPart
          ? (promotedPartsList.any((p) => p.id == itemId) ? 'promoted_parts' : 'spare_parts')
          : (promotedCarsList.any((c) => c.id == itemId) ? 'promoted_cars' : 'cars');

      await _firestore.collection(collection).doc(itemId).collection('reviews').doc(reviewId).delete();

      String? targetUser = originalUserId ?? currentUid;
      if (targetUser != null && !targetUser.startsWith('guest_')) {
        await _firestore.collection('users').doc(targetUser).collection('my_reviews').doc(reviewId).delete();
      }

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
      String collection = isPart
          ? (promotedPartsList.any((p) => p.id == itemId) ? 'promoted_parts' : 'spare_parts')
          : (promotedCarsList.any((c) => c.id == itemId) ? 'promoted_cars' : 'cars');

      await _firestore.collection(collection).doc(itemId).collection('reviews').doc(reviewId).set({'rating': newRating, 'comment': newComment}, SetOptions(merge: true));

      if (uid != null) {
        await _firestore.collection('users').doc(uid).collection('my_reviews').doc(reviewId).set({'carId': itemId, 'rating': newRating, 'comment': newComment, 'isPart': isPart}, SetOptions(merge: true));
      }

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

  // 🔥 حماية V2: تعديل مسار الحذف عشان يمسح الإعلان الصح 🔥
  Future<void> deleteReportedCar(String reportId, String carId, bool isPart) async {
    emit(AddCarLoading());
    try {
      // 1. تحديد الكوليكشن الصح في الفايربيز
      String targetCollection = '';
      if (isPart) {
        targetCollection = promotedPartsList.any((e) => e.id == carId) ? 'promoted_parts' : 'spare_parts';
      } else {
        targetCollection = promotedCarsList.any((e) => e.id == carId) ? 'promoted_cars' : 'cars';
      }

      // 2. مسح التقييمات التابعة للإعلان
      var reviewsQuery = await _firestore.collection(targetCollection).doc(carId).collection('reviews').get();
      for (var doc in reviewsQuery.docs) { await doc.reference.delete(); }

      // 3. مسح الإعلان نفسه من الكوليكشن الصح
      await _firestore.collection(targetCollection).doc(carId).delete();

      // 4. تنظيف اللوكال ريبورتس
      var reportsQuery = await _firestore.collection('reported_cars').where('carId', isEqualTo: carId).get();
      for (var doc in reportsQuery.docs) { await doc.reference.delete(); }

      // 5. تحديث اللستة اللوكال لليوزر
      carsList.removeWhere((e) => e.id == carId);
      promotedCarsList.removeWhere((e) => e.id == carId);
      sparePartsList.removeWhere((e) => e.id == carId);
      promotedPartsList.removeWhere((e) => e.id == carId);
      reportedCarsList.removeWhere((e) => e['carId'] == carId);

      if (!isPart) { _blendSpareParts(); }
      emit(MarketInitial());
    } catch (e) { emit(AddCarError('err_delete_ad_failed')); }
  }

  Future<void> resolveReportedReview({
    required String reportId,
    required String itemId,
    required String reviewId,
    required bool isPart,
    required String action,
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

  Future<void> loadMoreCarsFromFirebase(String categoryTitle) async {
    if (isFetchingMoreFirebase || isFetchingExternal) return;

    if (!hasMoreCarsInFirebase || lastCarDocument == null) {
      await searchCategoryCarsFromAI("", categoryTitle);
      return;
    }

    isFetchingMoreFirebase = true;
    emit(FetchExternalCarsLoading());

    try {
      final QuerySnapshot snapshot = await _firestore
          .collection('cars')
          .orderBy('createdAt', descending: true)
          .startAfterDocument(lastCarDocument!)
          .limit(20)
          .get();

      if (snapshot.docs.isEmpty) {
        hasMoreCarsInFirebase = false;
        await searchCategoryCarsFromAI("", categoryTitle);
      } else {
        lastCarDocument = snapshot.docs.last;

        for (var doc in snapshot.docs) {
          CarModel car = CarModel.fromJson(doc.data() as Map<String, dynamic>);
          if (!carsList.any((c) => c.id == car.id)) {
            carsList.add(car);
            if (car.condition == 'new_condition') newCarsList.add(car);
            else if (car.condition == 'used_condition') usedCarsList.add(car);
            _loadedHomeModels.add("${car.make.toUpperCase()} ${car.model.toUpperCase()}");
          }
        }
      }
      isFetchingMoreFirebase = false;
      emit(FetchExternalCarsSuccess());
    } catch (e) {
      isFetchingMoreFirebase = false;
      emit(GetCarsError(e.toString()));
    }
  }
  void _sortFilteredCars() {
    filteredCarsView.sort((a, b) {
      int yearA = int.tryParse(a.year.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      int yearB = int.tryParse(b.year.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      if (yearA != yearB) {
        return yearB.compareTo(yearA);
      }
      return b.createdAt.compareTo(a.createdAt);
    });
  }
  Future<List<CarModel>> getActualTopRatedCars() async {
    try {
      // 🔥 التعديل السحري: اطلب من الفايربيز العربيات العالية مباشرة بدلاً من الفلترة المحلية
      final snapshot = await _firestore.collection('cars')
          .where('rating', isGreaterThanOrEqualTo: 4.0)
          .orderBy('rating', descending: true)
          .limit(10) // هات أول 10 عربيات بس
          .get();

      if (snapshot.docs.isEmpty) return [];

      return snapshot.docs.map((doc) => CarModel.fromJson(doc.data())).toList();
    } catch (e) {
      // لو النت قطع أو حصل مشكلة، ارجع للفلترة المحلية كخطة بديلة (Fallback)
      return carsList.where((car) => car.rating >= 4.0 && car.reviewsCount > 0).toList();
    }
  }
  int filterApiOffset = 0; // 🔥 متغير جديد لتتبع الصفحات

  // ========================================================
  // 🔥 دالة الفلتر بعد التعديل لتدعم السكرول (V3) 🔥
  // ========================================================
  Future<void> applyFilters({String categoryTitle = "", bool isLoadMore = false}) async {
    if (selectedFilterBrands.isEmpty && selectedMaxPrice == null) {
      clearFilters();
      return;
    }

    if (!isLoadMore) {
      isFilterActive = true;
      filteredCarsView.clear();
      filterApiOffset = 0;
      emit(FilterCarsLoading());
    } else {
      emit(FilterCarsLoadingMore());
    }

    isFetchingFilteredCars = true;

    try {
      final response = await _dio.post(
        '$_baseUrl/api/cars/filter',
        data: {
          "brands": selectedFilterBrands,
          "maxPrice": selectedMaxPrice ?? 5000000,
          "limit": 10,
          "offset": filterApiOffset, // 🔥 بنبعت الأوفست للسيرفر
          "categoryTitle": categoryTitle
        },
        options: Options(receiveTimeout: const Duration(seconds: 30), sendTimeout: const Duration(seconds: 30)),
      );

      if (response.statusCode == 200 && response.data != null) {
        final List<dynamic> resultsList = response.data['results'] ?? [];
        List<CarModel> tempFetchedCars = [];

        for (var item in resultsList) {
          CarModel fetchedCar = CarModel(
            id: item['id']?.toString() ?? '',
            sellerId: item['sellerId']?.toString() ?? 'ai_filter',
            itemType: item['itemType']?.toString() ?? 'type_car',
            make: item['make']?.toString() ?? 'Unknown',
            model: item['model']?.toString() ?? 'Unknown',
            year: item['year']?.toString() ?? '2024',
            price: double.tryParse(item['price'].toString()) ?? 1000000.0,
            condition: item['condition']?.toString() ?? 'used_condition',
            description: item['description']?.toString() ?? '',
            images: (item['images'] is List) ? List<String>.from(item['images']) : (item['images'] is String ? [item['images']] : []),
            createdAt: item['createdAt']?.toString() ?? DateTime.now().toIso8601String(),
            hp: item['hp']?.toString() ?? 'N/A',
            cc: item['cc']?.toString() ?? 'N/A',
            torque: item['torque']?.toString() ?? 'N/A',
            transmission: item['transmission']?.toString() ?? 'Automatic',
            luggageCapacity: item['luggageCapacity']?.toString() ?? 'N/A',
            mileage: item['mileage']?.toString() ?? '0',
            sellerName: item['sellerName']?.toString() ?? 'GEAR UP Search',
            sellerPhone: item['sellerPhone']?.toString() ?? '16000',
            sellerLocation: item['sellerLocation']?.toString() ?? 'مصر',
            sellerEmail: item['sellerEmail']?.toString() ?? '',
            rating: double.tryParse(item['rating']?.toString() ?? '0') ?? 0.0,
            reviewsCount: int.tryParse(item['reviewsCount']?.toString() ?? '0') ?? 0,
            viewsCount: int.tryParse(item['viewsCount']?.toString() ?? '0') ?? 0,
          );

          tempFetchedCars.add(fetchedCar);

          if (!carsList.any((c) => c.id == fetchedCar.id)) {
            carsList.add(fetchedCar);
            // 🔥 حفظ العربيات اللي جاية من الفلتر في الفايربيز عشان الكل يستفيد 🔥
            await _firestore.collection('cars').doc(fetchedCar.id).set(fetchedCar.toMap(), SetOptions(merge: true));
          }
        }

        filterApiOffset += tempFetchedCars.length;

        if (isLoadMore) {
          filteredCarsView.addAll(tempFetchedCars);
        } else {
          filteredCarsView = tempFetchedCars;
        }

        _sortFilteredCars();
      }
    } catch (e) {
      debugPrint("❌ خطأ في الفلتر V3: $e");
    } finally {
      isFetchingFilteredCars = false;
      emit(GetCarsSuccess());
    }
  }
  Future<void> deleteUserItem(CarModel item) async {
    emit(AddCarLoading());
    try {
      bool isCar = item.itemType == 'type_car';
      // 🔥 تعديل اللوجيك عشان يمسح من الكوليكشن الصح في الفايربيز
      String targetCollection = '';
      if (isCar) {
        targetCollection = promotedCarsList.any((e) => e.id == item.id) ? 'promoted_cars' : 'cars';
      } else {
        targetCollection = promotedPartsList.any((e) => e.id == item.id) ? 'promoted_parts' : 'spare_parts';
      }

      var reviewsQuery = await _firestore.collection(targetCollection).doc(item.id).collection('reviews').get();
      for (var doc in reviewsQuery.docs) {
        await doc.reference.delete();
      }

      await _firestore.collection(targetCollection).doc(item.id).delete();
      carsList.removeWhere((e) => e.id == item.id);
      promotedCarsList.removeWhere((e) => e.id == item.id);
      sparePartsList.removeWhere((e) => e.id == item.id);
      promotedPartsList.removeWhere((e) => e.id == item.id);
      if (!isCar) { _blendSpareParts(); }
      emit(MarketInitial());
    } catch (e) { emit(AddCarError("err_delete_ad_failed")); }
  }
  Future<void> initializeHomeData() async {
    emit(MarketLoading());
    try {
      // 1. هنجيب الداتا الأساسية العادية
      await getCars();

      // =======================================================
      // 🔥 الحل السحري: إجبار الفايربيز يملى السكاشن الثابتة 🔥
      // =======================================================

      // لو بعد الـ getCars لسه لستة "الجديد" فاضية، هنجيب جديد بالعافية
      if (newCarsList.isEmpty) {
        debugPrint("⚠️ لستة الجديد فاضية في البداية.. بنجيب داتا مخصوص عشان السكشن الأول...");
        final newSnapshot = await _firestore.collection('cars')
            .where('condition', isEqualTo: 'new_condition')
            .limit(5).get();

        for (var doc in newSnapshot.docs) {
          CarModel car = CarModel.fromJson(doc.data() as Map<String, dynamic>);
          if (!carsList.any((c) => c.id == car.id)) {
            carsList.add(car);
            newCarsList.add(car);
          }
        }
      }

      // ولو لستة "المستعمل" فاضية، هنجيب مستعمل بالعافية (عشان السكشن الثابت بتاعها لو موجود)
      if (usedCarsList.isEmpty) {
        debugPrint("⚠️ لستة المستعمل فاضية في البداية.. بنجيب داتا مخصوص...");
        final usedSnapshot = await _firestore.collection('cars')
            .where('condition', isEqualTo: 'used_condition')
            .limit(5).get();

        for (var doc in usedSnapshot.docs) {
          CarModel car = CarModel.fromJson(doc.data() as Map<String, dynamic>);
          if (!carsList.any((c) => c.id == car.id)) {
            carsList.add(car);
            usedCarsList.add(car);
          }
        }
      }

      // 2. بعد ما اتأكدنا إن مفيش لستة فاضية، نبني الديناميكي
      await generateNextDynamicSection();

    } catch (e) {
      debugPrint("Error Initializing Home: $e");
    } finally {
      // 3. قفل اللودينج وعرض الشاشة
      emit(MarketInitial());
    }
  }
  // دالة حذف السيارة
  // دالة حذف السيارة من جراج المستخدم (My Cars)
  Future<void> deleteMyVehicle(String vehicleId) async {
    try {
      String? uid = CacheHelper.getData(key: 'uid');
      if (uid == null) return; // لازم يكون مسجل دخول

      // 1. الحذف من الفايربيز (المسار الصحيح زي الصورة اللي بعتها)
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('my_cars')
          .doc(vehicleId)
          .delete();

      // 2. الحذف من اللستة المحلية بتاعة "عربياتي" عشان الـ UI يتحدث فوراً
      myCars.removeWhere((car) => car['id'] == vehicleId);

      // 3. تحديث الكاش المحلي (عشان لو فتح أوفلاين متظهرش تاني)
      await CacheHelper.saveData(key: 'offline_my_cars_$uid', value: jsonEncode(myCars));

      // 4. تحديث الشاشة
      emit(MarketInitial());

      debugPrint("✅ تم مسح السيارة من جراج المستخدم بنجاح");

    } catch (e) {
      debugPrint("❌ Error deleting vehicle from my_cars: $e");
    }
  }
}
