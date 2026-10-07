import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../utils/id_validation.dart';
import '../widgets/loan_process_layout.dart';
import '../widgets/process_ui.dart';

class CompleteKycScreen extends StatefulWidget {
  const CompleteKycScreen({super.key});

  @override
  State<CompleteKycScreen> createState() => _CompleteKycScreenState();
}

class _CompleteKycScreenState extends State<CompleteKycScreen> {
  final _fullName = TextEditingController();
  final _parentName = TextEditingController();
  final _email = TextEditingController();
  final _residential = TextEditingController();
  final _permanent = TextEditingController();
  final _occupation = TextEditingController();
  final _employer = TextEditingController();
  final _income = TextEditingController();
  final _education = TextEditingController();
  final _nomineeName = TextEditingController();
  final _nomineeRelation = TextEditingController();
  final _nomineeMobile = TextEditingController();
  final _emergencyName = TextEditingController();
  final _emergencyRelation = TextEditingController();
  final _emergencyMobile = TextEditingController();
  final _ref1Name = TextEditingController();
  final _ref1Mobile = TextEditingController();
  final _ref2Name = TextEditingController();
  final _ref2Mobile = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _feedback = TextEditingController();
  final _aadhaar = TextEditingController();
  final _pan = TextEditingController();
  final _account = TextEditingController();
  final _ifsc = TextEditingController();
  late final TextEditingController _mobileDisplay;

  DateTime? _dob;
  String _gender = '';
  bool _sameAsResidential = false;
  bool _eSignConsent = false;
  bool _submitting = false;
  String _error = '';
  final Map<String, bool> _touched = {};
  final Map<String, bool> _prefs = {
    'sms': true,
    'email': true,
    'phone': false,
    'whatsapp': false,
  };
  final Map<String, PickedUpload?> _files = {};

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    _pan.text = state.applicationData.pan;
    _mobileDisplay = TextEditingController(text: state.cleanedMobile);
  }

  @override
  void dispose() {
    for (final c in [
      _fullName,
      _parentName,
      _email,
      _residential,
      _permanent,
      _occupation,
      _employer,
      _income,
      _education,
      _nomineeName,
      _nomineeRelation,
      _nomineeMobile,
      _emergencyName,
      _emergencyRelation,
      _emergencyMobile,
      _ref1Name,
      _ref1Mobile,
      _ref2Name,
      _ref2Mobile,
      _username,
      _password,
      _confirmPassword,
      _feedback,
      _aadhaar,
      _pan,
      _account,
      _ifsc,
      _mobileDisplay,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  bool _isTouched(String key) => _touched[key] == true;

  void _markTouched(String key) {
    if (_touched[key] == true) return;
    setState(() => _touched[key] = true);
  }

  void _touchAll() {
    setState(() {
      for (final key in [
        'fullName',
        'parentName',
        'dob',
        'gender',
        'email',
        'residential',
        'permanent',
        'occupation',
        'income',
        'employer',
        'education',
        'nomineeName',
        'nomineeRelation',
        'nomineeMobile',
        'emergencyName',
        'emergencyRelation',
        'emergencyMobile',
        'ref1Name',
        'ref1Mobile',
        'ref2Name',
        'ref2Mobile',
        'aadhaar',
        'pan',
        'account',
        'ifsc',
        'photograph',
        'signature',
        'username',
        'password',
        'confirmPassword',
        'eSign',
      ]) {
        _touched[key] = true;
      }
    });
  }

  String _digits(TextEditingController c) =>
      c.text.replaceAll(RegExp(r'\D'), '');

  List<String> _collectValidationErrors() {
    final errors = <String>[];
    final state = context.read<AppState>();

    if (state.cleanedMobile.length != 10) {
      errors.add(
        'Valid 10-digit mobile number is required. Go back and complete OTP verification.',
      );
    }
    if (state.applicationData.loanAmount <= 0) {
      errors.add(
        'Loan amount is missing. Go back to the Approved Offer step and apply an amount.',
      );
    }

    void add(String message) {
      if (message.isNotEmpty) errors.add(message);
    }

    add(getRequiredError(_fullName.text, 'Full name'));
    add(getRequiredError(_parentName.text, "Parent's name"));
    add(getDobError(_dob));
    add(getGenderError(_gender));
    add(getEmailError(_email.text));
    add(getRequiredError(_residential.text, 'Residential address'));
    add(getRequiredError(_permanent.text, 'Permanent address'));
    add(getRequiredError(_occupation.text, 'Occupation'));
    add(getRequiredError(_employer.text, 'Employer details'));
    add(getRequiredError(_income.text, 'Income details'));
    add(getRequiredError(_education.text, 'Educational information'));
    add(getRequiredError(_nomineeName.text, 'Nominee name'));
    add(getRequiredError(_nomineeRelation.text, 'Nominee relation'));
    add(getMobileError(_nomineeMobile.text, label: 'Nominee mobile'));
    add(getRequiredError(_emergencyName.text, 'Emergency contact name'));
    add(
      getRequiredError(_emergencyRelation.text, 'Emergency contact relation'),
    );
    add(
      getMobileError(_emergencyMobile.text, label: 'Emergency contact mobile'),
    );
    add(getRequiredError(_ref1Name.text, 'Reference 1 name'));
    add(getMobileError(_ref1Mobile.text, label: 'Reference 1 mobile'));
    add(getRequiredError(_ref2Name.text, 'Reference 2 name'));
    add(getMobileError(_ref2Mobile.text, label: 'Reference 2 mobile'));
    add(getAadhaarError(_aadhaar.text));
    add(getPanError(_pan.text));
    add(getAccountError(_account.text));
    add(getIfscError(_ifsc.text));
    if (_files['photograph'] == null) {
      errors.add('Profile photograph is required.');
    }
    if (_files['signature'] == null) {
      errors.add('Signature upload is required.');
    }
    add(getUsernameError(_username.text));
    add(getPasswordError(_password.text));
    add(getConfirmPasswordError(_password.text, _confirmPassword.text));
    if (!_eSignConsent) {
      errors.add('Please accept the eSign consent to submit.');
    }
    return errors;
  }

  String? _fieldError(String key, String Function() validator) {
    final error = validator();
    if (error.isEmpty) return null;
    // Instant for non-empty invalid values; required empty after touch.
    final value = switch (key) {
      'dob' => _dob == null ? '' : 'x',
      'gender' => _gender,
      'photograph' => _files['photograph'] == null ? '' : 'x',
      'signature' => _files['signature'] == null ? '' : 'x',
      'eSign' => _eSignConsent ? 'x' : '',
      'confirmPassword' => _confirmPassword.text,
      'password' => _password.text,
      'pan' => _pan.text,
      'aadhaar' => _aadhaar.text,
      'email' => _email.text,
      'ifsc' => _ifsc.text,
      'account' => _account.text,
      'nomineeMobile' => _nomineeMobile.text,
      'emergencyMobile' => _emergencyMobile.text,
      'ref1Mobile' => _ref1Mobile.text,
      'ref2Mobile' => _ref2Mobile.text,
      'username' => _username.text,
      'fullName' => _fullName.text,
      'parentName' => _parentName.text,
      'residential' => _residential.text,
      'permanent' => _permanent.text,
      'occupation' => _occupation.text,
      'income' => _income.text,
      'employer' => _employer.text,
      'education' => _education.text,
      'nomineeName' => _nomineeName.text,
      'nomineeRelation' => _nomineeRelation.text,
      'emergencyName' => _emergencyName.text,
      'emergencyRelation' => _emergencyRelation.text,
      'ref1Name' => _ref1Name.text,
      'ref2Name' => _ref2Name.text,
      _ => '',
    };
    if (_isTouched(key) || value.trim().isNotEmpty) return error;
    return null;
  }

  Future<void> _pickFile(String field) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    setState(() {
      _files[field] = PickedUpload(
        path: file.path ?? '',
        name: file.name,
        bytes: file.bytes,
      );
      _touched[field] = true;
    });
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 25),
      firstDate: DateTime(1950),
      lastDate: DateTime(now.year - 18),
    );
    setState(() {
      _touched['dob'] = true;
      if (picked != null) _dob = picked;
    });
  }

  Future<void> _submit() async {
    _touchAll();
    setState(() => _error = '');

    final errors = _collectValidationErrors();
    if (errors.isNotEmpty) {
      setState(() => _error = errors.first);
      return;
    }

    final state = context.read<AppState>();
    final app = state.applicationData;
    final dob = _dob!;
    final dobStr =
        '${dob.year.toString().padLeft(4, '0')}-${dob.month.toString().padLeft(2, '0')}-${dob.day.toString().padLeft(2, '0')}';

    setState(() => _submitting = true);

    String clipMobile(TextEditingController c) {
      final d = _digits(c);
      return d.substring(0, d.length.clamp(0, 10));
    }

    final fields = <String, String>{
      'mobile': state.cleanedMobile,
      'fullName': _fullName.text.trim(),
      'parentName': _parentName.text.trim(),
      'dateOfBirth': dobStr,
      'gender': _gender,
      'email': _email.text.trim().toLowerCase(),
      'residentialAddress': _residential.text.trim(),
      'permanentAddress': _permanent.text.trim(),
      'address': _residential.text.trim(),
      'occupation': _occupation.text.trim(),
      'employerDetails': _employer.text.trim(),
      'employment': _occupation.text.trim(),
      'incomeDetails': _income.text.trim(),
      'income': _income.text.replaceAll(RegExp(r'\D'), '').isEmpty
          ? _income.text.trim()
          : _income.text.replaceAll(RegExp(r'\D'), ''),
      'educationalInfo': _education.text.trim(),
      'nomineeName': _nomineeName.text.trim(),
      'nomineeRelation': _nomineeRelation.text.trim(),
      'nomineeMobile': clipMobile(_nomineeMobile),
      'emergencyContactName': _emergencyName.text.trim(),
      'emergencyContactRelation': _emergencyRelation.text.trim(),
      'emergencyContactMobile': clipMobile(_emergencyMobile),
      'reference1Name': _ref1Name.text.trim(),
      'reference1Mobile': clipMobile(_ref1Mobile),
      'reference2Name': _ref2Name.text.trim(),
      'reference2Mobile': clipMobile(_ref2Mobile),
      'username': _username.text.trim(),
      'password': _password.text,
      'customerFeedback': _feedback.text.trim(),
      'communicationPreferences':
          '{"sms":${_prefs['sms']},"email":${_prefs['email']},"phone":${_prefs['phone']},"whatsapp":${_prefs['whatsapp']}}',
      'aadhaar': sanitizeAadhaar(_aadhaar.text),
      'pan': sanitizePan(_pan.text),
      'accountNumber': _account.text.trim(),
      'ifsc': _ifsc.text.trim().toUpperCase(),
      'pinCode': app.pinCode,
      'loanPurpose': app.loanPurpose,
      'loanAmount': '${app.loanAmount}',
      'processingFee': '${app.processingFee}',
      'emi': '${app.emi}',
      'totalPayable': '${app.totalPayable}',
      'netCreditedAmount': '${app.netCreditedAmount}',
      'offerValidUntil': app.offerValidUntil,
      'eSignConsent': '$_eSignConsent',
    };

    final result = await state.api.submitKyc(fields: fields, files: _files);
    if (!mounted) return;

    if (!result.ok || result.data == null) {
      setState(() {
        _submitting = false;
        _error = result.message ?? 'Failed to submit application.';
      });
      return;
    }

    final token = result.data!['token']?.toString() ?? '';
    final user = result.data!['user'];
    if (token.isNotEmpty) {
      await state.saveSession(
        token,
        user is Map<String, dynamic> ? user : null,
      );
    }
    setState(() => _submitting = false);
    state.setStep(4);
  }

  Widget _field(
    String key,
    String label,
    TextEditingController controller, {
    TextInputType? type,
    int? max,
    List<TextInputFormatter>? formatters,
    bool obscure = false,
    bool enabled = true,
    String Function(String value)? validator,
    VoidCallback? onChanged,
  }) {
    final validate = validator ?? (v) => getRequiredError(v, label);
    final error = _fieldError(key, () => validate(controller.text));

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: FloatingLabelField(
        label: label,
        errorText: error,
        child: TextField(
          controller: controller,
          keyboardType: type,
          maxLength: max,
          inputFormatters: formatters,
          obscureText: obscure,
          enabled: enabled,
          decoration: errorAwareDecoration(
            hintText: 'Enter $label',
            hasError: error != null,
          ),
          onChanged: (v) {
            onChanged?.call();
            setState(() {
              if (v.isNotEmpty) _touched[key] = true;
            });
          },
          onEditingComplete: () => _markTouched(key),
          onTapOutside: (_) => _markTouched(key),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final validationErrors = _collectValidationErrors();
    final dobError = _fieldError('dob', () => getDobError(_dob));
    final genderError = _fieldError('gender', () => getGenderError(_gender));
    final aadhaarError = _fieldError(
      'aadhaar',
      () => getAadhaarError(_aadhaar.text),
    );
    final panError = _fieldError('pan', () => getPanError(_pan.text));
    final photoError = _fieldError(
      'photograph',
      () =>
          _files['photograph'] == null ? 'Profile photograph is required.' : '',
    );
    final signatureError = _fieldError(
      'signature',
      () => _files['signature'] == null ? 'Signature upload is required.' : '',
    );
    final eSignError = _fieldError(
      'eSign',
      () => !_eSignConsent ? 'Please accept the eSign consent to submit.' : '',
    );

    return LoanProcessLayout(
      activeStep: 3,
      continueLabel: _submitting ? 'Submitting...' : 'Submit Application',
      continueDisabled: _submitting,
      continueLoading: _submitting,
      onBack: () => state.setStep(2),
      onContinue: _submit,
      background: AppColors.surfaceMuted,
      child: SectionCardStyle(
        boxed: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_error.isNotEmpty)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.red50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 18,
                      color: AppColors.red600,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error,
                        style: const TextStyle(
                          color: AppColors.red600,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else if (validationErrors.isNotEmpty)
              ValidationChecklist(errors: validationErrors),
            SectionCard(
              title: 'Personal Details',
              child: Column(
                children: [
                  _field('fullName', 'Full Name', _fullName),
                  _field('parentName', "Parent's / Spouse Name", _parentName),
                  FloatingLabelField(
                    label: 'Date of Birth',
                    errorText: dobError,
                    child: InkWell(
                      onTap: _pickDob,
                      child: InputDecorator(
                        decoration: errorAwareDecoration(
                          hasError: dobError != null,
                        ),
                        child: Text(
                          _dob == null
                              ? 'Select date'
                              : '${_dob!.day.toString().padLeft(2, '0')}/${_dob!.month.toString().padLeft(2, '0')}/${_dob!.year}',
                          style: TextStyle(
                            color: _dob == null
                                ? AppColors.slate400
                                : AppColors.slate700,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FloatingLabelField(
                    label: 'Gender',
                    errorText: genderError,
                    child: DropdownButtonFormField<String>(
                      initialValue: _gender.isEmpty ? null : _gender,
                      hint: const Text('Select gender'),
                      items: const [
                        DropdownMenuItem(value: 'male', child: Text('Male')),
                        DropdownMenuItem(
                          value: 'female',
                          child: Text('Female'),
                        ),
                        DropdownMenuItem(value: 'other', child: Text('Other')),
                        DropdownMenuItem(
                          value: 'prefer_not_to_say',
                          child: Text('Prefer not to say'),
                        ),
                      ],
                      onChanged: (v) => setState(() {
                        _gender = v ?? '';
                        _touched['gender'] = true;
                      }),
                      decoration: errorAwareDecoration(
                        hasError: genderError != null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FloatingLabelField(
                    label: 'Mobile',
                    child: TextField(
                      enabled: false,
                      controller: _mobileDisplay,
                      decoration: errorAwareDecoration(
                        fillColor: AppColors.slate100,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _field(
                    'email',
                    'Email',
                    _email,
                    type: TextInputType.emailAddress,
                    validator: getEmailError,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: 'Address',
              child: Column(
                children: [
                  _field(
                    'residential',
                    'Residential Address',
                    _residential,
                    onChanged: () {
                      if (_sameAsResidential) {
                        _permanent.text = _residential.text;
                      }
                    },
                  ),
                  Row(
                    children: [
                      Checkbox(
                        value: _sameAsResidential,
                        onChanged: (v) {
                          setState(() {
                            _sameAsResidential = v ?? false;
                            if (_sameAsResidential) {
                              _permanent.text = _residential.text;
                              _touched['permanent'] = true;
                            }
                          });
                        },
                      ),
                      const Expanded(
                        child: Text('Permanent address same as residential'),
                      ),
                    ],
                  ),
                  _field('permanent', 'Permanent Address', _permanent),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: 'Occupation',
              child: Column(
                children: [
                  _field('occupation', 'Occupation', _occupation),
                  _field('income', 'Income Details', _income),
                  _field('employer', 'Employer Details', _employer),
                  _field('education', 'Educational Info', _education),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: 'Nominee',
              child: Column(
                children: [
                  _field('nomineeName', 'Nominee Name', _nomineeName),
                  _field('nomineeRelation', 'Relation', _nomineeRelation),
                  _field(
                    'nomineeMobile',
                    'Nominee Mobile',
                    _nomineeMobile,
                    type: TextInputType.phone,
                    max: 10,
                    formatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) =>
                        getMobileError(v, label: 'Nominee mobile'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: 'Emergency Contact',
              child: Column(
                children: [
                  _field('emergencyName', 'Name', _emergencyName),
                  _field('emergencyRelation', 'Relation', _emergencyRelation),
                  _field(
                    'emergencyMobile',
                    'Mobile',
                    _emergencyMobile,
                    type: TextInputType.phone,
                    max: 10,
                    formatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) =>
                        getMobileError(v, label: 'Emergency contact mobile'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: 'References',
              child: Column(
                children: [
                  _field('ref1Name', 'Reference 1 Name', _ref1Name),
                  _field(
                    'ref1Mobile',
                    'Reference 1 Mobile',
                    _ref1Mobile,
                    type: TextInputType.phone,
                    max: 10,
                    formatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) =>
                        getMobileError(v, label: 'Reference 1 mobile'),
                  ),
                  _field('ref2Name', 'Reference 2 Name', _ref2Name),
                  _field(
                    'ref2Mobile',
                    'Reference 2 Mobile',
                    _ref2Mobile,
                    type: TextInputType.phone,
                    max: 10,
                    formatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) =>
                        getMobileError(v, label: 'Reference 2 mobile'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: 'Identity',
              child: Column(
                children: [
                  FloatingLabelField(
                    label: 'Aadhaar',
                    errorText: aadhaarError,
                    child: TextField(
                      controller: _aadhaar,
                      keyboardType: TextInputType.number,
                      maxLength: 12,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: errorAwareDecoration(
                        hintText: 'Enter Aadhaar',
                        hasError: aadhaarError != null,
                      ),
                      onChanged: (v) {
                        final cleaned = sanitizeAadhaar(v);
                        if (cleaned != v) {
                          _aadhaar.value = TextEditingValue(
                            text: cleaned,
                            selection: TextSelection.collapsed(
                              offset: cleaned.length,
                            ),
                          );
                        }
                        setState(() {
                          if (cleaned.isNotEmpty) _touched['aadhaar'] = true;
                        });
                      },
                      onEditingComplete: () => _markTouched('aadhaar'),
                      onTapOutside: (_) => _markTouched('aadhaar'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FloatingLabelField(
                    label: 'PAN',
                    errorText: panError,
                    child: TextField(
                      controller: _pan,
                      textCapitalization: TextCapitalization.characters,
                      maxLength: 10,
                      decoration: errorAwareDecoration(
                        hintText: 'Enter PAN',
                        hasError: panError != null,
                      ),
                      onChanged: (v) {
                        final cleaned = sanitizePan(v);
                        if (cleaned != v) {
                          _pan.value = TextEditingValue(
                            text: cleaned,
                            selection: TextSelection.collapsed(
                              offset: cleaned.length,
                            ),
                          );
                        }
                        setState(() {
                          if (cleaned.isNotEmpty) _touched['pan'] = true;
                        });
                      },
                      onEditingComplete: () => _markTouched('pan'),
                      onTapOutside: (_) => _markTouched('pan'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: 'Bank Details',
              child: Column(
                children: [
                  _field(
                    'account',
                    'Account Number',
                    _account,
                    type: TextInputType.number,
                    formatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: getAccountError,
                  ),
                  _field(
                    'ifsc',
                    'IFSC',
                    _ifsc,
                    validator: getIfscError,
                    onChanged: () {
                      final upper = _ifsc.text.toUpperCase();
                      if (upper != _ifsc.text) {
                        _ifsc.value = TextEditingValue(
                          text: upper,
                          selection: TextSelection.collapsed(
                            offset: upper.length,
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: 'Uploads',
              child: Column(
                children: [
                  UploadBox(
                    label: 'Photograph *',
                    fileName: _files['photograph']?.name,
                    errorText: photoError,
                    onTap: () => _pickFile('photograph'),
                  ),
                  const SizedBox(height: 12),
                  UploadBox(
                    label: 'Signature *',
                    fileName: _files['signature']?.name,
                    errorText: signatureError,
                    onTap: () => _pickFile('signature'),
                  ),
                  const SizedBox(height: 12),
                  UploadBox(
                    label: 'Selfie (optional)',
                    fileName: _files['selfie']?.name,
                    onTap: () => _pickFile('selfie'),
                  ),
                  const SizedBox(height: 12),
                  UploadBox(
                    label: 'Aadhaar Document (optional)',
                    fileName: _files['aadhaarDoc']?.name,
                    onTap: () => _pickFile('aadhaarDoc'),
                  ),
                  const SizedBox(height: 12),
                  UploadBox(
                    label: 'PAN Document (optional)',
                    fileName: _files['panDoc']?.name,
                    onTap: () => _pickFile('panDoc'),
                  ),
                  const SizedBox(height: 12),
                  UploadBox(
                    label: 'Salary Slips (optional)',
                    fileName: _files['salarySlips']?.name,
                    onTap: () => _pickFile('salarySlips'),
                  ),
                  const SizedBox(height: 12),
                  UploadBox(
                    label: 'Bank Statements (optional)',
                    fileName: _files['bankStatements']?.name,
                    onTap: () => _pickFile('bankStatements'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: 'Create Account',
              child: Column(
                children: [
                  _field(
                    'username',
                    'Username',
                    _username,
                    validator: getUsernameError,
                  ),
                  _field(
                    'password',
                    'Password',
                    _password,
                    obscure: true,
                    validator: getPasswordError,
                  ),
                  _field(
                    'confirmPassword',
                    'Confirm Password',
                    _confirmPassword,
                    obscure: true,
                    validator: (v) =>
                        getConfirmPasswordError(_password.text, v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: 'Feedback (optional)',
              child: TextField(
                controller: _feedback,
                maxLines: 3,
                decoration: errorAwareDecoration(
                  hintText: 'Any feedback for us',
                ),
              ),
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: 'Communication Preferences',
              child: Column(
                children: [
                  for (final key in _prefs.keys)
                    CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(key.toUpperCase()),
                      value: _prefs[key],
                      onChanged: (v) =>
                          setState(() => _prefs[key] = v ?? false),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: 'eSign Consent',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: _eSignConsent,
                        side: eSignError != null
                            ? const BorderSide(
                                color: AppColors.red600,
                                width: 1.5,
                              )
                            : null,
                        onChanged: (v) => setState(() {
                          _eSignConsent = v ?? false;
                          _touched['eSign'] = true;
                        }),
                      ),
                      Expanded(
                        child: Text(
                          'I consent to electronically sign and submit this application and confirm that the information provided is true and accurate.',
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            color: eSignError != null
                                ? AppColors.red600
                                : AppColors.slate700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (eSignError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6, left: 4),
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
                              eSignError,
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
