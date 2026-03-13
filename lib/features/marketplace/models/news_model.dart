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
      id: json['id'] ?? '',
      title: json['title'] ?? 'خبر جديد',
      snippet: json['snippet'] ?? 'تفاصيل الخبر...',
      date: json['date'] ?? '',
      imageUrl: json['imageUrl'] ?? '',
      articleUrl: json['articleUrl'] ?? '',
      createdAt: json['createdAt'] ?? DateTime.now().toIso8601String(),
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