class FeedItem {
  final int id;
  final String? content;
  final String? imageUrl;
  final User user;
  int commentsCount;
  int likesCount;
  final int retweetsCount;
  final String? industry;
  bool isLiked;
  bool isSaved;

  FeedItem({
    required this.id,
    this.content,
    this.imageUrl,
    required this.user,
    this.commentsCount = 0,
    this.likesCount = 0,
    this.retweetsCount = 0,
    this.industry,
    this.isLiked = false,
    this.isSaved = false,
  });

  factory FeedItem.fromJson(Map<String, dynamic> json) {
    // Map backend keys to model keys
    // Assuming backend returns something like:
    // { "id": 1, "description": "...", "image": "...", "user": { ... }, "industry": "..." }
    return FeedItem(
      id: json['id'] ?? 0,
      content: json['description'] ?? json['content'],
      imageUrl: json['image'] ?? json['imageUrl'],
      industry: json['indus_type'] ?? json['industry'],
      user: User.fromJson(json['user'] ?? {}),
      likesCount: json['likes_count'] ?? 0,
      commentsCount: json['comments_count'] ?? 0,
      retweetsCount: json['shares_count'] ?? 0,
      isLiked: json['is_liked'] ?? false,
      isSaved: json['is_saved'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'description': content,
      'image': imageUrl,
      'user': user.toJson(),
      'likes_count': likesCount,
      'comments_count': commentsCount,
      'shares_count': retweetsCount,
      'indus_type': industry,
      'is_liked': isLiked,
      'is_saved': isSaved,
    };
  }
}

class User {
  final int id;
  final String fullName;
  final String designation;
  final String imageUrl;
  final String userName;

  User({
    required this.id,
    required this.fullName,
    required this.designation,
    required this.imageUrl,
    required this.userName,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? 0,
      fullName: json['name'] ?? json['fullName'] ?? 'Unknown',
      designation: json['designation'] ?? json['desg'] ?? '',
      imageUrl: json['profile_pic'] ?? json['imageUrl'] ?? '',
      userName: json['username'] ?? json['userName'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': fullName,
      'designation': designation,
      'profile_pic': imageUrl,
      'username': userName,
    };
  }
}
