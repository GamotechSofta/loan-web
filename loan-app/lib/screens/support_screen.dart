import 'package:flutter/material.dart';

import '../config/company_content.dart';
import '../config/theme.dart';
import '../widgets/ui_kit.dart';

/// "Support" tab: how to reach the team, plus the most common questions.
class SupportView extends StatelessWidget {
  const SupportView({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        24 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        const Text(
          'Support',
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w800,
            color: AppColors.slate900,
          ),
        ),
        const SizedBox(height: 3),
        const Text(
          "We're here to help you",
          style: TextStyle(fontSize: 12.5, color: AppColors.slate500),
        ),
        const SizedBox(height: 18),
        const _ContactTile(
          icon: Icons.call_outlined,
          label: 'Call us',
          value: Company.phone,
        ),
        const SizedBox(height: 12),
        const _ContactTile(
          icon: Icons.mail_outline_rounded,
          label: 'Email us',
          value: Company.email,
        ),
        const SizedBox(height: 12),
        const _ContactTile(
          icon: Icons.schedule_rounded,
          label: 'Office hours',
          value: Company.hours,
        ),
        const SizedBox(height: 12),
        const _ContactTile(
          icon: Icons.location_on_outlined,
          label: 'Registered office',
          value: Company.address,
        ),
        const SizedBox(height: 22),
        const SectionHeading('Frequently asked'),
        const SizedBox(height: 10),
        for (final item in homeFaq.take(4))
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.question,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.slate900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.answer,
                    style: const TextStyle(
                      fontSize: 12.5,
                      height: 1.5,
                      color: AppColors.slate600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 4),
        const SecureNote(text: 'Your data is 100% secure with us'),
      ],
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.brandSoft,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 19, color: AppColors.brand),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.slate500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13.5,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                    color: AppColors.slate900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
