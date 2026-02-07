/// User model for authentication state
class User {
  final String id;
  final String email;
  final String? displayName;

  User({
    required this.id,
    required this.email,
    this.displayName,
  });

  String get initials {
    if (displayName != null && displayName!.isNotEmpty) {
      final parts = displayName!.split(' ');
      if (parts.length >= 2) {
        return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      }
      return displayName![0].toUpperCase();
    }
    return email[0].toUpperCase();
  }
}
