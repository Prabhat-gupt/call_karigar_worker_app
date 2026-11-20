class Preferences {
  final String language; // 'en', 'hi'
  final bool notifications;
  final bool autoAccept;
  final int maxJobsPerDay;

  Preferences({
    required this.language,
    required this.notifications,
    required this.autoAccept,
    required this.maxJobsPerDay,
  });

  factory Preferences.fromJson(Map<String, dynamic> json) {
    return Preferences(
      language: json['language'] ?? 'en',
      notifications: json['notifications'] ?? true,
      autoAccept: json['availability']?['autoAccept'] ?? false,
      maxJobsPerDay: json['availability']?['maxJobsPerDay'] ?? 5,
    );
  }

  Map<String, dynamic> toJson() => {
        'language': language,
        'notifications': notifications,
        'availability': {
          'autoAccept': autoAccept,
          'maxJobsPerDay': maxJobsPerDay,
        }
      };
}

class Stats {
  final int totalJobs;
  final int completedJobs;
  final int cancelledJobs;
  final double totalEarnings;

  Stats({
    required this.totalJobs,
    required this.completedJobs,
    required this.cancelledJobs,
    required this.totalEarnings,
  });

  factory Stats.fromJson(Map<String, dynamic> json) {
    return Stats(
      totalJobs: json['totalJobs'] ?? 0,
      completedJobs: json['completedJobs'] ?? 0,
      cancelledJobs: json['cancelledJobs'] ?? 0,
      totalEarnings: (json['totalEarnings'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'totalJobs': totalJobs,
        'completedJobs': completedJobs,
        'cancelledJobs': cancelledJobs,
        'totalEarnings': totalEarnings,
      };
}

class WorkerProfileModel {
  final String id;
  final String phoneNumber;
  final String email;
  final String photo;
  final String bio;
  final List<String> skills;
  final String status; // pending, active, inactive, suspended
  final bool isVerified;
  final Preferences preferences;
  final Stats stats;
  final double ratingAverage;
  final int ratingCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  WorkerProfileModel({
    required this.id,
    required this.phoneNumber,
    required this.email,
    required this.photo,
    required this.bio,
    required this.skills,
    required this.status,
    required this.isVerified,
    required this.preferences,
    required this.stats,
    required this.ratingAverage,
    required this.ratingCount,
    required this.createdAt,
    required this.updatedAt,
  });

  factory WorkerProfileModel.fromJson(Map<String, dynamic> json) {
    // Extract ID - handle case where _id is a nested object
    String extractedId = '';
    final idValue = json['_id'];
    if (idValue is String) {
      extractedId = idValue;
    } else if (idValue is Map && idValue.containsKey('_id')) {
      extractedId = idValue['_id'] ?? '';
    }
    if (extractedId.isEmpty) {
      extractedId = json['id'] ?? '';
    }

    return WorkerProfileModel(
      id: extractedId,
      phoneNumber: json['phoneNumber'] ?? '',
      email: json['email'] ?? '',
      photo: json['photo'] ?? 'default-worker.jpg',
      bio: json['bio'] ?? 'Hello worker this side',
      skills: List<String>.from(json['skills'] ?? []),
      status: json['status'] ?? 'pending',
      isVerified: json['isVerified'] ?? false,
      preferences: Preferences.fromJson(json['preferences'] ?? {}),
      stats: Stats.fromJson(json['stats'] ?? {}),
      ratingAverage: (json['ratingAverage'] ?? 0).toDouble(),
      ratingCount: json['ratingCount'] ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        '_id': id,
        'phoneNumber': phoneNumber,
        'email': email,
        'photo': photo,
        'bio': bio,
        'skills': skills,
        'status': status,
        'isVerified': isVerified,
        'preferences': preferences.toJson(),
        'stats': stats.toJson(),
        'ratingAverage': ratingAverage,
        'ratingCount': ratingCount,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };
}
