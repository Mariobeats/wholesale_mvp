class ProfileModel {
  final String id;
  final String name;
  final String role; // 'admin' | 'salesman'
  final String? mobile;
  final DateTime? createdAt;

  ProfileModel({
    required this.id,
    required this.name,
    required this.role,
    this.mobile,
    this.createdAt,
  });

  bool get isAdmin => role.toLowerCase() == 'admin';
  bool get isSalesman => role.toLowerCase() == 'salesman';

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'User',
      role: json['role'] as String? ?? 'salesman',
      mobile: json['mobile'] as String?,
      createdAt: json['created_at'] != null 
          ? DateTime.tryParse(json['created_at'].toString()) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'role': role,
      'mobile': mobile,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }
}
