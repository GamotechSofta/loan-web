import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../utils/id_validation.dart';
import '../widgets/loan_process_layout.dart';
import '../widgets/process_ui.dart';

class BasicDetailsScreen extends StatefulWidget {
  const BasicDetailsScreen({super.key});

  @override
  State<BasicDetailsScreen> createState() => _BasicDetailsScreenState();
}

class _BasicDetailsScreenState extends State<BasicDetailsScreen> {
  late final TextEditingController _panController;
  late final TextEditingController _pinController;
  String _loanPurpose = '';
  bool _panTouched = false;
  bool _pinTouched = false;
  bool _purposeTouched = false;

  static const purposes = {
    'medical': 'Medical Emergency',
    'education': 'Education',
    'home': 'Home Expenses',
    'travel': 'Travel',
    'business': 'Business',
  };

  @override
  void initState() {
    super.initState();
    final data = context.read<AppState>().applicationData;
    _panController = TextEditingController(text: data.pan);
    _pinController = TextEditingController(text: data.pinCode);
    _loanPurpose = data.loanPurpose;
  }

  @override
  void dispose() {
    _panController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  bool get _canContinue =>
      isValidPanFormat(_panController.text) &&
      _pinController.text.length == 6 &&
      _loanPurpose.isNotEmpty;

  String? get _panError => liveError(
    touched: _panTouched,
    value: _panController.text,
    validator: getPanError,
  );

  String? get _pinError => liveError(
    touched: _pinTouched,
    value: _pinController.text,
    validator: getPinError,
  );

  String? get _purposeError =>
      _purposeTouched ? getLoanPurposeError(_loanPurpose).nullIfEmpty : null;

  void _touchAll() {
    setState(() {
      _panTouched = true;
      _pinTouched = true;
      _purposeTouched = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final panError = _panError;
    final pinError = _pinError;
    final purposeError = _purposeError;

    return LoanProcessLayout(
      activeStep: 1,
      continueDisabled: false,
      onBack: () => state.setStep(0),
      onContinue: () {
        _touchAll();
        if (!_canContinue) return;
        state.mergeApplication(
          state.applicationData.copyWith(
            pan: sanitizePan(_panController.text),
            pinCode: _pinController.text,
            loanPurpose: _loanPurpose,
          ),
        );
        state.setStep(2);
      },
      child: SectionCard(
        title: 'Personal Information',
        child: Column(
          children: [
            FloatingLabelField(
              label: 'PAN Number',
              errorText: panError,
              child: TextField(
                controller: _panController,
                textCapitalization: TextCapitalization.characters,
                maxLength: 10,
                decoration: errorAwareDecoration(
                  hintText: 'Enter PAN number',
                  hasError: panError != null,
                ),
                onChanged: (v) {
                  final cleaned = sanitizePan(v);
                  if (cleaned != v) {
                    _panController.value = TextEditingValue(
                      text: cleaned,
                      selection: TextSelection.collapsed(
                        offset: cleaned.length,
                      ),
                    );
                  }
                  setState(() {
                    // Show format warnings as soon as the user starts typing.
                    if (cleaned.isNotEmpty) _panTouched = true;
                  });
                },
                onEditingComplete: () => setState(() => _panTouched = true),
                onTapOutside: (_) => setState(() => _panTouched = true),
              ),
            ),
            const SizedBox(height: 18),
            FloatingLabelField(
              label: 'PIN Code',
              errorText: pinError,
              child: TextField(
                controller: _pinController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: errorAwareDecoration(
                  hintText: 'Enter PIN code',
                  hasError: pinError != null,
                ),
                onChanged: (v) {
                  setState(() {
                    if (v.isNotEmpty) _pinTouched = true;
                  });
                },
                onEditingComplete: () => setState(() => _pinTouched = true),
                onTapOutside: (_) => setState(() => _pinTouched = true),
              ),
            ),
            const SizedBox(height: 18),
            FloatingLabelField(
              label: 'Loan Purpose',
              errorText: purposeError,
              child: DropdownButtonFormField<String>(
                initialValue: _loanPurpose.isEmpty ? null : _loanPurpose,
                hint: const Text('Select loan purpose'),
                items: purposes.entries
                    .map(
                      (e) =>
                          DropdownMenuItem(value: e.key, child: Text(e.value)),
                    )
                    .toList(),
                onChanged: (v) => setState(() {
                  _loanPurpose = v ?? '';
                  _purposeTouched = true;
                }),
                decoration: errorAwareDecoration(
                  hasError: purposeError != null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension on String {
  String? get nullIfEmpty => isEmpty ? null : this;
}
