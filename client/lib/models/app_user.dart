class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    this.online = false,
  });

  final String id;
  final String name;
  final String email;
  final bool online;

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as String,
        name: json['name'] as String,
        email: json['email'] as String,
        online: json['online'] as bool? ?? false,
      );

  AppUser copyWith({bool? online}) => AppUser(
        id: id,
        name: name,
        email: email,
        online: online ?? this.online,
      );

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final first = parts.first;
      return (first.length == 1 ? first : first.substring(0, 2)).toUpperCase();
    }
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}
