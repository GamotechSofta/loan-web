import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/animations.dart';
import '../config/theme.dart';
import '../state/app_state.dart';
import '../widgets/ui_kit.dart';
import 'sign_up_screen.dart';
import 'user_sign_in_sheet.dart';

/// Signed-out entry point: greeting, then apply or check application status.
class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  Future<void> _openSignUp(BuildContext context) {
    return Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SignUpScreen()));
  }

  Future<void> _openSignIn(BuildContext context) async {
    final state = context.read<AppState>();
    await UserSignInSheet.show(
      context,
      api: state.api,
      onSignedIn: state.onSignedIn,
      onCreateAccount: () => _openSignUp(context),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                children: [
                  FadeUp(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Hello! 👋',
                          style: TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.w800,
                            color: AppColors.slate900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'What would you like\nto do today?',
                          style: TextStyle(
                            fontSize: 25,
                            height: 1.25,
                            fontWeight: FontWeight.w800,
                            color: AppColors.slate900,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Simple steps to your financial freedom.',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.slate500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  FadeUp.delayed(
                    child: FeatureCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Apply for Loan',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                    SizedBox(height: 6),
                                    Text(
                                      'Get instant approval and\nquick disbursal',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        height: 1.4,
                                        color: Color(0xCCFFFFFF),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              const MoneyGlyph(size: 58),
                            ],
                          ),
                          const SizedBox(height: 18),
                          OnBrandButton(
                            label: 'Apply Now',
                            onPressed: state.startApplication,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  ActionCard(
                    title: 'Create an account',
                    description:
                        'Sign up with your mobile number\nto check CIBIL and apply',
                    icon: Icons.person_add_alt_1_outlined,
                    onTap: () => _openSignUp(context),
                  ),
                  const SizedBox(height: 14),
                  ActionCard(
                    title: 'Check Your Application Status',
                    description: 'Track your loan application\nin real-time',
                    icon: Icons.assignment_outlined,
                    onTap: () => _openSignIn(context),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 18),
              child: SecureNote(text: 'Your data is 100% secure with us'),
            ),
          ],
        ),
      ),
    );
  }
}
