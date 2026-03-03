import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../screens/auth/sign_in_screen.dart';

class ProfileMenuButton extends StatefulWidget {
  final String? userEmail;

  const ProfileMenuButton({super.key, this.userEmail});

  @override
  State<ProfileMenuButton> createState() => _ProfileMenuButtonState();
}

class _ProfileMenuButtonState extends State<ProfileMenuButton> {
  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await AuthService.logout();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const SignInScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final initials = widget.userEmail != null && widget.userEmail!.isNotEmpty
        ? widget.userEmail!.substring(0, 1).toUpperCase()
        : 'U';

    return PopupMenuButton<String>(
      icon: CircleAvatar(
        backgroundColor: colorScheme.primaryContainer,
        child: Text(
          initials,
          style: TextStyle(
              color: colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w600),
        ),
      ),
      itemBuilder: (context) => <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.userEmail ?? 'User',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'signout',
          onTap: _signOut,
          child: const Row(
            children: [
              Icon(Icons.logout_outlined),
              SizedBox(width: 12),
              Text('Sign Out')
            ],
          ),
        ),
      ],
    );
  }
}
