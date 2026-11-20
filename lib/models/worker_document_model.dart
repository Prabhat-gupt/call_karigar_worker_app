class Certification {
  final String url;
  final String fileType;
  final String title;
  final bool verified;

  Certification({
    required this.url,
    required this.fileType,
    required this.title,
    required this.verified,
  });

  factory Certification.fromJson(Map<String, dynamic> json) {
    return Certification(
      url: json['url'] ?? '',
      fileType: json['fileType'] ?? 'application/pdf',
      title: json['title'] ?? '',
      verified: json['verified'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'url': url,
        'fileType': fileType,
        'title': title,
        'verified': verified,
      };
}

class Document {
  final String url;
  final String fileType;

  Document({
    required this.url,
    required this.fileType,
  });

  factory Document.fromJson(Map<String, dynamic> json) {
    return Document(
      url: json['url'] ?? '',
      fileType: json['fileType'] ?? 'application/pdf',
    );
  }

  Map<String, dynamic> toJson() => {
        'url': url,
        'fileType': fileType,
      };
}

class WorkerDocument {
  final String id;
  final String workerId;
  final Document? aadhar;
  final Document? pan;
  final Document? policeVerification;
  final List<Certification> certifications;
  final bool isKYCComplete;
  final String status; // pending, verified, rejected
  final String? lastVerifiedBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  WorkerDocument({
    required this.id,
    required this.workerId,
    this.aadhar,
    this.pan,
    this.policeVerification,
    required this.certifications,
    required this.isKYCComplete,
    required this.status,
    this.lastVerifiedBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory WorkerDocument.fromJson(Map<String, dynamic> json) {
    return WorkerDocument(
      id: json['_id'] ?? json['id'] ?? '',
      workerId: json['workerId'] ?? '',
      aadhar: json['aadhar'] != null ? Document.fromJson(json['aadhar']) : null,
      pan: json['pan'] != null ? Document.fromJson(json['pan']) : null,
      policeVerification: json['policeVerification'] != null
          ? Document.fromJson(json['policeVerification'])
          : null,
      certifications: (json['certifications'] as List?)
              ?.map((c) => Certification.fromJson(c as Map<String, dynamic>))
              .toList() ??
          [],
      isKYCComplete: json['isKYCComplete'] ?? false,
      status: json['status'] ?? 'pending',
      lastVerifiedBy: json['lastVerifiedBy'],
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
        'workerId': workerId,
        'aadhar': aadhar?.toJson(),
        'pan': pan?.toJson(),
        'policeVerification': policeVerification?.toJson(),
        'certifications': certifications.map((c) => c.toJson()).toList(),
        'isKYCComplete': isKYCComplete,
        'status': status,
        'lastVerifiedBy': lastVerifiedBy,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };
}
