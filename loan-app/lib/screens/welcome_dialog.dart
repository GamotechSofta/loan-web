import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../widgets/process_ui.dart';

class WelcomeProfileDialog extends StatelessWidget {
  const WelcomeProfileDialog({
    super.key,
    required this.profile,
    required this.onClose,
    required this.onViewProfile,
  });

  final Map<String, dynamic> profile;
  final VoidCallback onClose;
  final VoidCallback onViewProfile;

  static Future<void> show(
    BuildContext context, {
    required Map<String, dynamic> profile,
    required VoidCallback onClose,
    required VoidCallback onViewProfile,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => WelcomeProfileDialog(
        profile: profile,
        onClose: onClose,
        onViewProfile: onViewProfile,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name =
        profile['fullName']?.toString() ??
        profile['username']?.toString() ??
        'there';
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.brandSoft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.celebration_outlined,
                size: 26,
                color: AppColors.brand,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Welcome!',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                color: AppColors.slate900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Hi $name, your Sakaar account is ready.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.slate500),
            ),
            const SizedBox(height: 20),
            BrandPrimaryButton(
              label: 'View Profile',
              onPressed: () {
                Navigator.pop(context);
                onViewProfile();
              },
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                onClose();
              },
              child: const Text('Go to Home'),
            ),
          ],
        ),
      ),
    );
  }
}
