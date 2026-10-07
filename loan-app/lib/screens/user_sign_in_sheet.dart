import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/theme.dart';
import '../services/api_service.dart';
import '../widgets/process_ui.dart';

class UserSignInSheet extends StatefulWidget {
  const UserSignInSheet({
    super.key,
    required this.api,
    required this.onSignedIn,
    this.onCreateAccount,
  });

  final ApiService api;
  final Future<void> Function({
    required String token,
    required Map<String, dynamic> user,
  })
  onSignedIn;
  final VoidCallback? onCreateAccount;

  static Future<void> show(
    BuildContext context, {
    required ApiService api,
    required Future<void> Function({
      required String token,
      required Map<String, dynamic> user,
    })
    onSignedIn,
    VoidCallback? onCreateAccount,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => UserSignInSheet(
        api: api,
        onSignedIn: onSignedIn,
        onCreateAccount: onCreateAccount,
      ),
    );
  }

  @override
  State<UserSignInSheet> createState() => _UserSignInSheetState();
}

class _UserSignInSheetState extends State<UserSignInSheet> {
  static const _otpLength = 6;

  final _mobile = TextEditingController();
  final _password = TextEditingController();
  final _otpControllers = List.generate(
    _otpLength,
    (_) => TextEditingController(),
  );
  final _otpFocus = List.generate(_otpLength, (_) => FocusNode());

  /// `password` | `otp`
  String _mode = 'password';
  bool _otpSent = false;
  bool _loading = false;
  bool _obscurePassword = true;
  String _error = '';

  @override
  void dispose() {
    _mobile.dispose();
    _password.dispose();
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final f in _otpFocus) {
      f.dispose();
    }
    super.dispose();
  }

  String get _otp => _otpControllers.map((c) => c.text).join();

  String get _cleanedMobile => _mobile.text.replaceAll(RegExp(r'\D'), '');

  void _switchMode(String mode) {
    setState(() {
      _mode = mode;
      _error = '';
      _otpSent = false;
      for (final c in _otpControllers) {
        c.clear();
      }
    });
  }

  Future<void> _finishLogin(ApiResult result) async {
    if (!result.ok || result.data == null) {
      setState(() {
        _loading = false;
        _error = result.message ?? 'Sign in failed.';
      });
      return;
    }
    final token = result.data!['token']?.toString() ?? '';
    final user = result.data!['user'];
    if (token.isEmpty || user is! Map<String, dynamic>) {
      setState(() {
        _loading = false;
        _error = 'Unexpected login response.';
      });
      return;
    }
    Navigator.pop(context);
    await widget.onSignedIn(token: token, user: user);
  }

  Future<void> _loginWithPassword() async {
    if (_cleanedMobile.length != 10) {
      setState(() => _error = 'Enter a valid 10-digit mobile number.');
      return;
    }
    if (_password.text.length < 6) {
      setState(() => _error = 'Enter your password (at least 6 characters).');
      return;
    }
    setState(() {
      _loading = true;
      _error = '';
    });
    final result = await widget.api.loginWithPassword(
      _cleanedMobile,
      _password.text,
    );
    if (!mounted) return;
    await _finishLogin(result);
  }

  Future<void> _sendOtp() async {
    if (_cleanedMobile.length != 10) {
      setState(() => _error = 'Enter a valid 10-digit mobile number.');
      return;
    }
    setState(() {
      _loading = true;
      _error = '';
    });
    final result = await widget.api.sendLoginOtp(_cleanedMobile);
    if (!mounted) return;
    if (!result.ok) {
      setState(() {
        _loading = false;
        _error = result.message ?? 'Failed to send OTP.';
      });
      return;
    }
    setState(() {
      _loading = false;
      _otpSent = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _otpFocus[0].requestFocus();
    });
  }

  Future<void> _verifyOtp() async {
    final cleaned = _otp.replaceAll(RegExp(r'\D'), '');
    if (cleaned.length != _otpLength || _loading) return;
    setState(() {
      _loading = true;
      _error = '';
    });
    final result = await widget.api.verifyLoginOtp(_cleanedMobile, cleaned);
    if (!mounted) return;
    if (!result.ok) {
      for (final c in _otpControllers) {
        c.clear();
      }
      setState(() {
        _loading = false;
        _error = result.message ?? 'Invalid OTP. Please try again.';
      });
      _otpFocus[0].requestFocus();
      return;
    }
    await _finishLogin(result);
  }

  void _onOtpChanged(int index, String value) {
    setState(() => _error = '');
    if (index == 0 && value.length > 1) {
      final digits = value.replaceAll(RegExp(r'\D'), '');
      for (var i = 0; i < _otpLength; i++) {
        _otpControllers[i].text = i < digits.length ? digits[i] : '';
      }
      if (digits.length >= _otpLength) {
        _otpFocus[_otpLength - 1].requestFocus();
        _verifyOtp();
      } else if (digits.isNotEmpty) {
        _otpFocus[digits.length.clamp(0, _otpLength - 1)].requestFocus();
      }
      return;
    }
    if (value.isNotEmpty && index < _otpLength - 1) {
      _otpFocus[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      _otpFocus[index - 1].requestFocus();
    }
    if (_otp.length == _otpLength) {
      _verifyOtp();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom =
        MediaQuery.viewInsetsOf(context).bottom +
        MediaQuery.paddingOf(context).bottom;
    final subtitle = _mode == 'password'
        ? 'Sign in with your registered mobile number and password.'
        : _otpSent
        ? 'Enter the 6-digit OTP sent to +91 $_cleanedMobile'
        : 'Sign in with the mobile number linked to your loan account.';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
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
                    'Sign In',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Text(subtitle, style: const TextStyle(color: AppColors.slate600)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.slate100,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _ModeChip(
                      label: 'Phone & Password',
                      selected: _mode == 'password',
                      onTap: () => _switchMode('password'),
                    ),
                  ),
                  Expanded(
                    child: _ModeChip(
                      label: 'OTP',
                      selected: _mode == 'otp',
                      onTap: () => _switchMode('otp'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _mobile,
              enabled: !(_mode == 'otp' && _otpSent),
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              decoration: const InputDecoration(
                prefixText: '+91 ',
                hintText: '10-digit mobile number',
                labelText: 'Mobile number',
              ),
            ),
            if (_mode == 'password') ...[
              const SizedBox(height: 12),
              TextField(
                controller: _password,
                obscureText: _obscurePassword,
                autofillHints: const [AutofillHints.password],
                decoration: InputDecoration(
                  labelText: 'Password',
                  hintText: 'Enter your password',
                  suffixIcon: IconButton(
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
                onSubmitted: (_) => _loginWithPassword(),
              ),
            ],
            if (_mode == 'otp' && _otpSent) ...[
              const SizedBox(height: 16),
              AutofillGroup(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(_otpLength, (i) {
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(left: i == 0 ? 0 : 6),
                        child: TextField(
                          controller: _otpControllers[i],
                          focusNode: _otpFocus[i],
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          maxLength: i == 0 ? _otpLength : 1,
                          autofillHints: i == 0
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
                          onChanged: (value) => _onOtpChanged(i, value),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
            if (_error.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(_error, style: const TextStyle(color: Color(0xFFDC2626))),
            ],
            const SizedBox(height: 16),
            BrandPrimaryButton(
              label: _loading
                  ? 'Please wait...'
                  : _mode == 'password'
                  ? 'Sign In'
                  : _otpSent
                  ? 'Verify & Sign In'
                  : 'Send OTP',
              loading: _loading,
              onPressed: _mode == 'password'
                  ? _loginWithPassword
                  : _otpSent
                  ? _verifyOtp
                  : _sendOtp,
            ),
            if (widget.onCreateAccount != null) ...[
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onCreateAccount!();
                  },
                  child: const Text('New here? Create an account'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Colors.white : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      elevation: selected ? 1 : 0,
      shadowColor: Colors.black26,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? AppColors.slate900 : AppColors.slate500,
            ),
          ),
        ),
      ),
    );
  }
}
