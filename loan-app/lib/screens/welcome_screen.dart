import 'package:flutter/material.dart';

import '../config/animations.dart';
import '../config/company_content.dart';
import '../config/theme.dart';

/// Launch screen: brand mark centred on a soft field, trust line pinned to the
/// bottom. Timing is owned by the caller so it can double as a session gate.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceMuted,
      body: Stack(
        children: [
          Positioned(
            left: -80,
            top: 90,
            child: Container(
              width: 320,
              height: 320,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.brandSoft,
              ),
            ),
          ),
          Positioned(
            right: -110,
            bottom: 140,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.brandSoft.withValues(alpha: 0.7),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: FadeUp(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FloatSoft(
                            child: Image.asset(
                              'assets/images/logo.png',
                              width: 230,
                            ),
                          ),
                          const SizedBox(height: 22),
                          const Text(
                            Company.tagline,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13.5,
                              height: 1.4,
                              color: AppColors.slate500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const FadeUp.delayed(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 34),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.verified_user_outlined,
                              size: 16,
                              color: AppColors.slate700,
                            ),
                            SizedBox(width: 7),
                            Text(
                              'Trusted by Thousands',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.slate800,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Secure • Reliable • Fast',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: AppColors.slate400,
                          ),
                        ),
                      ],
                    ),
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
