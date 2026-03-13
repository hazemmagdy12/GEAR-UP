class CarModel {
  final String id;
  final String sellerId;
  final String itemType;
  final String make;
  final String model;
  final String year;
  final double price;
  final String condition;
  final String description;
  List<String> images;
  final String createdAt;

  final String hp;
  final String cc;
  final String torque;
  final String transmission;
  final String luggageCapacity;
  final String mileage;

  final String sellerName;
  final String sellerPhone;
  final String sellerLocation;
  final String sellerEmail;

  final double rating;
  final int reviewsCount;

  // 🔥 التعديل الأهم: ضفنا عدد المشاهدات عشان يتقري من الفايربيز 🔥
  final int viewsCount;

  final double? tempRating;

  CarModel({
    required this.id,
    required this.sellerId,
    required this.itemType,
    required this.make,
    required this.model,
    required this.year,
    required this.price,
    required this.condition,
    required this.description,
    required this.images,
    required this.createdAt,
    required this.hp,
    required this.cc,
    required this.torque,
    required this.transmission,
    required this.luggageCapacity,
    required this.mileage,
    required this.sellerName,
    required this.sellerPhone,
    required this.sellerLocation,
    required this.sellerEmail,
    this.rating = 0.0,
    this.reviewsCount = 0,
    this.viewsCount = 0, // افتراضي 0
    this.tempRating,
  });

  CarModel copyWithRating(double rating) {
    return CarModel(
      id: id, sellerId: sellerId, itemType: itemType, make: make, model: model,
      year: year, price: price, condition: condition, description: description,
      images: images, createdAt: createdAt, hp: hp, cc: cc, torque: torque,
      transmission: transmission, luggageCapacity: luggageCapacity, mileage: mileage,
      sellerName: sellerName, sellerPhone: sellerPhone, sellerLocation: sellerLocation,
      sellerEmail: sellerEmail,
      rating: this.rating,
      reviewsCount: this.reviewsCount,
      viewsCount: this.viewsCount, // نسخه هنا كمان
      tempRating: rating,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id, 'sellerId': sellerId, 'itemType': itemType, 'make': make,
      'model': model, 'year': year, 'price': price, 'condition': condition,
      'description': description, 'images': images, 'createdAt': createdAt,
      'hp': hp, 'cc': cc, 'torque': torque, 'transmission': transmission,
      'luggageCapacity': luggageCapacity, 'mileage': mileage, 'sellerName': sellerName,
      'sellerPhone': sellerPhone, 'sellerLocation': sellerLocation, 'sellerEmail': sellerEmail,
      'rating': rating,
      'reviewsCount': reviewsCount,
      'viewsCount': viewsCount, // بيترفع للفايربيز
    };
  }

  factory CarModel.fromJson(Map<String, dynamic> json) {
    return CarModel(
      id: json['id'] ?? '', sellerId: json['sellerId'] ?? '', itemType: json['itemType'] ?? 'type_car',
      make: json['make'] ?? '', model: json['model'] ?? '', year: json['year'] ?? '',
      price: json['price']?.toDouble() ?? 0.0, condition: json['condition'] ?? '',
      description: json['description'] ?? '', images: List<String>.from(json['images'] ?? []),
      createdAt: json['createdAt'] ?? '', hp: json['hp'] ?? '', cc: json['cc'] ?? '',
      torque: json['torque'] ?? '', transmission: json['transmission'] ?? '',
      luggageCapacity: json['luggageCapacity'] ?? '', mileage: json['mileage'] ?? '',
      // دول بس اللي فيهم عربي، وهنسيبهم زي ما هما كـ Fallback عشان مفيش Context هنا
      sellerName: json['sellerName'] ?? 'غير معروف', sellerPhone: json['sellerPhone'] ?? 'غير متوفر',
      sellerLocation: json['sellerLocation'] ?? '', sellerEmail: json['sellerEmail'] ?? '',
      rating: json['rating']?.toDouble() ?? 0.0,
      reviewsCount: json['reviewsCount']?.toInt() ?? 0,
      viewsCount: json['viewsCount']?.toInt() ?? 0, // بيقرا من الفايربيز
    );
  }
}