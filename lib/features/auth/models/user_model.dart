class UserModel {
  final String uId;
  final String name;
  final String email;
  final String phone;
  final String profileImage;
  final String location;
  final String createdAt;
  final String role; // 🔥 الإضافة السحرية للأدمن

  UserModel({
    required this.uId,
    required this.name,
    required this.email,
    required this.phone,
    required this.profileImage,
    required this.location,
    required this.createdAt,
    this.role = 'user', // الديفولت أي حد بيسجل بيبقى يوزر عادي
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uId: json['uid'] ?? json['uId'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      profileImage: json['profileImage'] ?? json['profile_image'] ?? '',
      location: json['location'] ?? '',
      createdAt: json['createdAt'] ?? '',
      role: json['role'] ?? 'user', // لو مفيش رول بيعتبره يوزر
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uId,
      'name': name,
      'email': email,
      'phone': phone,
      'profileImage': profileImage,
      'location': location,
      'createdAt': createdAt,
      'role': role,
    };
  }
}