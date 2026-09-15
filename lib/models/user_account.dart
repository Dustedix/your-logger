class UserAccount {
  final String username;
  final String displayName;
  final String totpSecret;
  final DateTime createdAt;
  final DateTime? lastLoginAt;

  const UserAccount({
    required this.username,
    required this.displayName,
    required this.totpSecret,
    required this.createdAt,
    this.lastLoginAt,
  });

  UserAccount copyWith({
    String? username,
    String? displayName,
    String? totpSecret,
    DateTime? createdAt,
    DateTime? lastLoginAt,
  }) {
    return UserAccount(
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      totpSecret: totpSecret ?? this.totpSecret,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'displayName': displayName,
      'totpSecret': totpSecret,
      'createdAt': createdAt.toIso8601String(),
      'lastLoginAt': lastLoginAt?.toIso8601String(),
    };
  }

  factory UserAccount.fromJson(Map<String, dynamic> json) {
    return UserAccount(
      username: json['username'] as String? ?? '',
      displayName: json['displayName'] as String? ?? json['username'] as String? ?? '',
      totpSecret: json['totpSecret'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      lastLoginAt: json['lastLoginAt'] != null
          ? DateTime.tryParse(json['lastLoginAt'] as String)
          : null,
    );
  }
}
