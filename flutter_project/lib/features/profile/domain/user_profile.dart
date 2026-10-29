class UserProfileData {
  final String name;
  final String email;
  final String phone;
  const UserProfileData({
    required this.name,
    required this.email,
    required this.phone,
  });

  factory UserProfileData.fromMetadata(
    String? email,
    Map<String, dynamic>? metadata,
  ) {
    final data = metadata ?? {};
    final address = email ?? '';
    final storedName = (data['full_name'] ?? data['name'] ?? '')
        .toString()
        .trim();
    return UserProfileData(
      name: storedName.isNotEmpty ? storedName : address.split('@').first,
      email: address,
      phone: (data['phone'] ?? data['telefone'] ?? '').toString(),
    );
  }

  String get initials {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    return (parts.first.substring(0, 1) +
            (parts.length > 1 ? parts.last.substring(0, 1) : ''))
        .toUpperCase();
  }
}
