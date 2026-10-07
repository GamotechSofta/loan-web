import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../config/company_content.dart';
import '../config/theme.dart';
import '../state/app_state.dart';
import '../utils/id_validation.dart';
import '../widgets/loan_process_layout.dart';
import '../widgets/otp_verification_sheet.dart';
import '../widgets/process_ui.dart';

class ApplyStep0Screen extends StatefulWidget {
  const ApplyStep0Screen({super.key});

  @override
  State<ApplyStep0Screen> createState() => _ApplyStep0ScreenState();
}

class _ApplyStep0ScreenState extends State<ApplyStep0Screen> {
  late final TextEditingController _mobileController;
  bool _mobileTouched = false;
  bool _consentTouched = false;

  @override
  void initState() {
    super.initState();
    _mobileController = TextEditingController(
      text: context.read<AppState>().mobileNumber,
    );
  }

  @override
  void dispose() {
    _mobileController.dispose();
    super.dispose();
  }

  String? _mobileError(AppState state) {
    return liveError(
      touched: _mobileTouched,
      value: state.mobileNumber,
      validator: (v) => getMobileError(v),
    );
  }

  String? _consentError(AppState state) {
    if (!_consentTouched) return null;
    if (state.consentOne && state.consentTwo && state.consentThree) return null;
    return 'Please accept all consents to continue.';
  }

  Future<void> _onGetOtp(AppState state) async {
    setState(() {
      _mobileTouched = true;
      _consentTouched = true;
    });
    if (!state.isOtpEnabled) return;

    await state.sendOtp();
    if (!mounted) return;
    if (state.showOtpSheet) {
      await OtpVerificationSheet.show(
        context,
        mobile: state.mobileNumber,
        api: state.api,
        onVerified: state.onOtpVerified,
      );
      state.closeOtpSheet();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final mobileError = _mobileError(state);
    final consentError = _consentError(state);
    final hasMobileError = mobileError != null;

    return LoanProcessLayout(
      activeStep: 1,
      onBack: state.goHome,
      continueLabel: state.loading ? 'Sending...' : 'Get OTP',
      continueLoading: state.loading,
      onContinue: () => _onGetOtp(state),
      child: SectionCard(
        title: 'Mobile Verification',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'We will send a one time password to verify your mobile number.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.45,
                color: AppColors.slate500,
              ),
            ),
            const SizedBox(height: 18),
            if (state.status != null) ...[
              _StatusMessage(
                message: state.status!.message,
                success: state.status!.type == 'success',
              ),
              const SizedBox(height: 16),
            ],
            FloatingLabelField(
              label: 'Mobile Number',
              errorText: mobileError,
              child: Row(
                children: [
                  Container(
                    height: 50,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(AppRadius.field),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: const Text(
                      '+91',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.slate700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _mobileController,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      decoration: errorAwareDecoration(
                        hintText: 'Enter mobile number',
                        hasError: hasMobileError,
                      ),
                      onChanged: (v) {
                        state.setMobileNumber(v);
                        setState(() {
                          if (v.isNotEmpty) _mobileTouched = true;
                        });
                      },
                      onEditingComplete: () =>
                          setState(() => _mobileTouched = true),
                      onTapOutside: (_) =>
                          setState(() => _mobileTouched = true),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            _Consent(
              value: state.consentOne,
              hasError: consentError != null && !state.consentOne,
              onChanged: (v) {
                state.setConsent(one: v);
                setState(() => _consentTouched = true);
              },
              text:
                  'By proceeding, you agree to our Terms & Conditions, Privacy Policy, and consent to us accessing your credit information from credit bureaus for processing your application.',
            ),
            _Consent(
              value: state.consentTwo,
              hasError: consentError != null && !state.consentTwo,
              onChanged: (v) {
                state.setConsent(two: v);
                setState(() => _consentTouched = true);
              },
              text:
                  'I consent to receive loan-related updates, alerts, and communications via WhatsApp, SMS, RCS and any other communication channel on my registered mobile number.',
            ),
            _Consent(
              value: state.consentThree,
              hasError: consentError != null && !state.consentThree,
              onChanged: (v) {
                state.setConsent(three: v);
                setState(() => _consentTouched = true);
              },
              text:
                  'I hereby provide my consent to fetch and verify my KYC details from the CKYC registry for the purpose of processing my application.',
            ),
            if (consentError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 14,
                      color: AppColors.red600,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        consentError,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.red600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 14),
            Text(
              'The Name of the Company is ${Company.legalName.toUpperCase()}. '
              'The Registered Office of the Company will be situated in the '
              'STATE OF UTTAR PRADESH.',
              style: const TextStyle(
                fontSize: 11,
                height: 1.5,
                color: AppColors.slate400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusMessage extends StatelessWidget {
  const _StatusMessage({required this.message, required this.success});

  final String message;
  final bool success;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: success ? AppColors.green50 : AppColors.red50,
        borderRadius: BorderRadius.circular(AppRadius.field),
        border: Border.all(
          color: success ? AppColors.green200 : AppColors.red200,
        ),
      ),
      child: Text(
        message,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: success ? AppColors.green700 : AppColors.red600,
        ),
      ),
    );
  }
}

class _Consent extends StatelessWidget {
  const _Consent({
    required this.value,
    required this.onChanged,
    required this.text,
    this.hasError = false,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String text;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: Checkbox(
              value: value,
              side: hasError
                  ? const BorderSide(color: AppColors.red600, width: 1.5)
                  : null,
              onChanged: (v) => onChanged(v ?? false),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(!value),
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.5,
                  color: hasError ? AppColors.red600 : AppColors.slate600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
