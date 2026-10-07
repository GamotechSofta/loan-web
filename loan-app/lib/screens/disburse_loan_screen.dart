import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../state/app_state.dart';
import '../utils/loan_calculator.dart';
import '../widgets/loan_process_layout.dart';
import '../widgets/process_ui.dart';

class DisburseLoanScreen extends StatefulWidget {
  const DisburseLoanScreen({super.key});

  @override
  State<DisburseLoanScreen> createState() => _DisburseLoanScreenState();
}

class _DisburseLoanScreenState extends State<DisburseLoanScreen> {
  bool _loading = false;
  String _error = '';

  Future<void> _goToProfile() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = '';
    });

    final state = context.read<AppState>();
    try {
      if (state.userToken.isNotEmpty) {
        final result = await state.api.getProfile(state.userToken);
        if (result.ok) {
          state.finishDisbursal(result.data);
          return;
        }
      }
      state.finishDisbursal(state.userProfile);
    } catch (_) {
      setState(() => _error = 'Could not reach the server. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final user = state.userProfile;
    final loanAmount =
        (user?['loanAmount'] as num?)?.toInt() ??
        state.applicationData.loanAmount;
    final name = user?['fullName']?.toString();

    return LoanProcessLayout(
      activeStep: 4,
      title: 'Application Submitted',
      subtitle: 'Your application is ready for admin review',
      continueLabel: _loading ? 'Opening Profile...' : 'View Profile',
      continueDisabled: _loading,
      continueLoading: _loading,
      onBack: () => state.setStep(3),
      onContinue: _goToProfile,
      background: AppColors.surfaceMuted,
      child: SectionCardStyle(
        boxed: true,
        child: Column(
          children: [
            if (_error.isNotEmpty)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _error,
                  style: const TextStyle(color: Color(0xFFDC2626)),
                ),
              ),
            SectionCard(
              child: Column(
                children: [
                  const Text(
                    'Application Submitted Successfully!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.green700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Thank you${name != null ? ', $name' : ''}. Your loan application has been sent to the admin team for review.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.slate600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'You can track the latest status and every reviewed form item from your Profile.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: AppColors.slate500),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const SectionCard(
              title: 'Application Status',
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Status', style: TextStyle(color: Color(0xFF475569))),
                  StatusBadge(status: 'submitted'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: 'Application Summary',
              child: Column(
                children: [
                  InfoRow(
                    label: 'Requested Amount',
                    value: formatCurrency(loanAmount),
                  ),
                  const InfoRow(label: 'Review', value: 'Pending with admin'),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const SupportSection(),
          ],
        ),
      ),
    );
  }
}
