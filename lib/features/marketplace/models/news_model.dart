class NewsModel {
  final String id;
  final String title;
  final String snippet;
  final String date;
  final String imageUrl;
  final String articleUrl;
  final String createdAt;

  NewsModel({
    required this.id,
    required this.title,
    required this.snippet,
    required this.date,
    required this.imageUrl,
    required this.articleUrl,
    required this.createdAt,
  });

  factory NewsModel.fromJson(Map<String, dynamic> json) {
    return NewsModel(
      // 🔥 حماية V2: استخدام toString() لتجنب كراش اختلاف نوع البيانات 🔥
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'خبر جديد',
      snippet: json['snippet']?.toString() ?? 'تفاصيل الخبر...',
      date: json['date']?.toString() ?? '',
      imageUrl: json['imageUrl']?.toString() ?? '',
      articleUrl: json['articleUrl']?.toString() ?? '',
      createdAt: json['createdAt']?.toString() ?? DateTime.now().toIso8601String(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'snippet': snippet,
      'date': date,
      'imageUrl': imageUrl,
      'articleUrl': articleUrl,
      'createdAt': createdAt,
    };
  }
}