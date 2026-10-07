import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/theme.dart';
import '../services/api_service.dart';
import 'process_ui.dart';

class OtpVerificationSheet extends StatefulWidget {
  const OtpVerificationSheet({
    super.key,
    required this.mobile,
    required this.api,
    required this.onVerified,
    this.resend,
  });

  final String mobile;
  final ApiService api;
  final VoidCallback onVerified;
  final Future<ApiResult> Function()? resend;

  static Future<void> show(
    BuildContext context, {
    required String mobile,
    required ApiService api,
    required VoidCallback onVerified,
    Future<ApiResult> Function()? resend,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => OtpVerificationSheet(
        mobile: mobile,
        api: api,
        onVerified: onVerified,
        resend: resend,
      ),
    );
  }

  @override
  State<OtpVerificationSheet> createState() => _OtpVerificationSheetState();
}

class _OtpVerificationSheetState extends State<OtpVerificationSheet> {
  static const otpLength = 6;
  static const resendSeconds = 60;

  final _controllers = List.generate(otpLength, (_) => TextEditingController());
  final _focusNodes = List.generate(otpLength, (_) => FocusNode());
  int _timer = resendSeconds;
  bool _resending = false;
  bool _verifying = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _tick();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _focusNodes[0].requestFocus(),
    );
  }

  void _tick() {
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted || _timer <= 0) return;
      setState(() => _timer -= 1);
      _tick();
    });
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _otp => _controllers.map((c) => c.text).join();

  Future<void> _resend() async {
    if (_timer > 0 || _resending) return;
    setState(() {
      _resending = true;
      _error = '';
    });
    final result = widget.resend != null
        ? await widget.resend!()
        : await widget.api.sendOtp(widget.mobile);
    if (!mounted) return;
    if (!result.ok) {
      setState(() {
        _error = result.message ?? 'Failed to resend OTP. Please try again.';
        _resending = false;
      });
      return;
    }
    for (final c in _controllers) {
      c.clear();
    }
    setState(() {
      _timer = resendSeconds;
      _resending = false;
    });
    _tick();
    _focusNodes[0].requestFocus();
  }

  Future<void> _verify() async {
    final cleaned = _otp.replaceAll(RegExp(r'\D'), '');
    if (cleaned.length != otpLength) {
      setState(() => _error = 'Please enter the complete 6-digit OTP.');
      return;
    }
    setState(() {
      _verifying = true;
      _error = '';
    });
    final result = await widget.api.verifyOtp(widget.mobile, cleaned);
    if (!mounted) return;
    if (result.ok) {
      Navigator.of(context).pop();
      widget.onVerified();
    } else {
      for (final c in _controllers) {
        c.clear();
      }
      setState(() {
        _error = result.message ?? 'Invalid OTP. Please try again.';
        _verifying = false;
      });
      _focusNodes[0].requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom =
        MediaQuery.viewInsetsOf(context).bottom +
        MediaQuery.paddingOf(context).bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      // Scrolls so the keyboard can never clip the verify button.
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 20, 16, 24 + bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.slate200,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'OTP Verification',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.slate900,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: AppColors.slate500),
                ),
              ],
            ),
            Text(
              'Enter the 6-digit code sent to +91 ${widget.mobile}',
              style: const TextStyle(fontSize: 14, color: AppColors.slate600),
            ),
            const SizedBox(height: 20),
            AutofillGroup(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(otpLength, (index) {
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(left: index == 0 ? 0 : 6),
                      child: TextField(
                        controller: _controllers[index],
                        focusNode: _focusNodes[index],
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        maxLength: index == 0 ? otpLength : 1,
                        autofillHints: index == 0
                            ? const [AutofillHints.oneTimeCode]
                            : null,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          counterText: '',
                          contentPadding: EdgeInsets.symmetric(vertical: 14),
                        ),
                        onChanged: (value) {
                          setState(() => _error = '');
                          // SMS autofill may paste the full OTP into the first box.
                          if (index == 0 && value.length > 1) {
                            final digits = value.replaceAll(RegExp(r'\D'), '');
                            for (var i = 0; i < otpLength; i++) {
                              _controllers[i].text = i < digits.length
                                  ? digits[i]
                                  : '';
                            }
                            if (digits.length >= otpLength) {
                              _focusNodes[otpLength - 1].requestFocus();
                              _verify();
                            } else if (digits.isNotEmpty) {
                              _focusNodes[digits.length.clamp(0, otpLength - 1)]
                                  .requestFocus();
                            }
                            return;
                          }
                          if (value.isNotEmpty && index < otpLength - 1) {
                            _focusNodes[index + 1].requestFocus();
                          }
                          if (value.isEmpty && index > 0) {
                            _focusNodes[index - 1].requestFocus();
                          }
                          if (_controllers.every((c) => c.text.isNotEmpty)) {
                            _verify();
                          }
                        },
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 16),
            if (_timer > 0)
              Text(
                'Resend OTP in 00:${_timer.toString().padLeft(2, '0')}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF16A34A),
                ),
              )
            else
              TextButton(
                onPressed: _resending ? null : _resend,
                child: Text(_resending ? 'Resending...' : 'Resend OTP'),
              ),
            if (_error.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _error,
                  style: const TextStyle(
                    color: Color(0xFFDC2626),
                    fontSize: 14,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            BrandPrimaryButton(
              label: _verifying ? 'Verifying...' : 'Verify OTP',
              loading: _verifying,
              onPressed: _otp.length == otpLength ? _verify : null,
            ),
          ],
        ),
      ),
    );
  }
}
