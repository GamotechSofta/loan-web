import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../state/app_state.dart';
import '../widgets/process_ui.dart';
import '../widgets/ui_kit.dart';
import 'user_sign_in_sheet.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _fullName = TextEditingController();
  final _mobile = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();

  bool _loading = false;
  bool _obscurePassword = true;
  String _error = '';

  @override
  void dispose() {
    _fullName.dispose();
    _mobile.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  String get _cleanedMobile => _mobile.text.replaceAll(RegExp(r'\D'), '');

  bool get _canSubmit =>
      _fullName.text.trim().length >= 2 &&
      _cleanedMobile.length == 10 &&
      _email.text.contains('@') &&
      _password.text.length >= 6 &&
      _password.text == _confirmPassword.text;

  Future<void> _submit() async {
    final name = _fullName.text.trim();
    final email = _email.text.trim();
    if (name.length < 2) {
      setState(() => _error = 'Please enter your full name.');
      return;
    }
    if (_cleanedMobile.length != 10) {
      setState(() => _error = 'Enter a valid 10-digit mobile number.');
      return;
    }
    if (!email.contains('@') || !email.contains('.')) {
      setState(() => _error = 'Please enter a valid email address.');
      return;
    }
    if (_password.text.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return;
    }
    if (_password.text != _confirmPassword.text) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }

    setState(() {
      _loading = true;
      _error = '';
    });

    final state = context.read<AppState>();
    final result = await state.api.signUp(
      fullName: name,
      mobile: _cleanedMobile,
      email: email,
      password: _password.text,
    );
    if (!mounted) return;

    final token = result.data?['token']?.toString() ?? '';
    final user = result.data?['user'];
    if (!result.ok || token.isEmpty || user is! Map) {
      setState(() {
        _loading = false;
        _error = result.message ?? 'Could not create your account.';
      });
      return;
    }

    final navigator = Navigator.of(context);
    navigator.pop();
    await state.onSignedIn(token: token, user: Map<String, dynamic>.from(user));
  }

  void _goToSignIn() {
    final state = context.read<AppState>();
    final navigator = Navigator.of(context);
    navigator.pop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final host = navigator.context;
      if (!host.mounted) return;
      UserSignInSheet.show(
        host,
        api: state.api,
        onSignedIn: state.onSignedIn,
        onCreateAccount: () {
          navigator.push(
            MaterialPageRoute(builder: (_) => const SignUpScreen()),
          );
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            AppScreenHeader(
              title: 'Create account',
              subtitle: 'Sign up to check CIBIL and apply',
              onBack: () => Navigator.pop(context),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                children: [
                  TextField(
                    controller: _fullName,
                    textCapitalization: TextCapitalization.words,
                    autofillHints: const [AutofillHints.name],
                    decoration: const InputDecoration(
                      labelText: 'Full name',
                      hintText: 'Your full name',
                    ),
                    onChanged: (_) => setState(() => _error = ''),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _mobile,
                    keyboardType: TextInputType.phone,
                    autofillHints: const [AutofillHints.telephoneNumber],
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    decoration: const InputDecoration(
                      prefixText: '+91 ',
                      labelText: 'Mobile number',
                      hintText: '10-digit mobile number',
                    ),
                    onChanged: (_) => setState(() => _error = ''),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      hintText: 'you@email.com',
                    ),
                    onChanged: (_) => setState(() => _error = ''),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _password,
                    obscureText: _obscurePassword,
                    autofillHints: const [AutofillHints.newPassword],
                    decoration: InputDecoration(
                      labelText: 'Password',
                      hintText: 'At least 6 characters',
                      suffixIcon: IconButton(
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                    onChanged: (_) => setState(() => _error = ''),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _confirmPassword,
                    obscureText: _obscurePassword,
                    decoration: const InputDecoration(
                      labelText: 'Confirm password',
                      hintText: 'Re-enter your password',
                    ),
                    onChanged: (_) => setState(() => _error = ''),
                    onSubmitted: (_) {
                      if (_canSubmit && !_loading) _submit();
                    },
                  ),
                  if (_error.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error,
                      style: const TextStyle(color: Color(0xFFDC2626)),
                    ),
                  ],
                  const SizedBox(height: 20),
                  BrandPrimaryButton(
                    label: _loading ? 'Creating account...' : 'Create account',
                    loading: _loading,
                    onPressed: _canSubmit && !_loading ? _submit : null,
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: TextButton(
                      onPressed: _loading ? null : _goToSignIn,
                      child: const Text('Already have an account? Sign in'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
