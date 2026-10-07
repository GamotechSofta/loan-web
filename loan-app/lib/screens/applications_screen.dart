import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../state/app_state.dart';
import '../utils/loan_calculator.dart';
import '../widgets/ui_kit.dart';

/// Profile tab: account summary plus every application on file.
class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    final state = context.read<AppState>();
    if (state.userToken.isEmpty) return;
    final result = await state.api.getProfile(state.userToken);
    if (!mounted) return;
    if (result.statusCode == 401 || result.statusCode == 403) {
      await state.clearUserSession();
      return;
    }
    if (result.ok) state.setUserProfile(result.data);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final profile = state.userProfile ?? const <String, dynamic>{};
    final raw = profile['applications'];
    final applications = raw is List
        ? raw.whereType<Map>().toList()
        : const <Map>[];

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          24 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Profile',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        color: AppColors.slate900,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Your account and loan history',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.slate500,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: state.clearUserSession,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.slate500,
                ),
                icon: const Icon(Icons.logout_rounded, size: 16),
                label: const Text('Logout', style: TextStyle(fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.brandSoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.person_outline_rounded,
                        color: AppColors.brand,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${profile['fullName'] ?? '—'}',
                            style: const TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.slate900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '+91 ${profile['mobile'] ?? '—'}',
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColors.slate500,
                            ),
                          ),
                          if ('${profile['email'] ?? ''}'.isNotEmpty)
                            Text(
                              '${profile['email']}',
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: AppColors.slate500,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 6),
                DetailRow(
                  label: 'KYC Status',
                  value:
                      '${profile['kycStatus'] ?? profile['applicationStatus'] ?? '—'}',
                ),
                DetailRow(
                  label: 'Loan Status',
                  value: '${profile['loanStatus'] ?? '—'}',
                ),
                if (profile['loanAmount'] != null)
                  DetailRow(
                    label: 'Loan Amount',
                    value: formatCurrency(profile['loanAmount'] as num),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (applications.isNotEmpty) ...[
            _FullApplicationForm(
              application: applications.first,
              canCheckCibil:
                  profile['canCheckCibil'] == true ||
                  (applications.first['canCheckCibil'] == true),
            ),
            const SizedBox(height: 20),
          ],
          const SectionHeading('Your Applications'),
          const SizedBox(height: 10),
          if (applications.isEmpty)
            AppCard(
              child: Column(
                children: [
                  const Icon(
                    Icons.inbox_outlined,
                    size: 30,
                    color: AppColors.slate300,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'No applications yet',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.slate700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Apply for a loan to see it listed here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12.5, color: AppColors.slate500),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: state.startApplication,
                      child: const Text('Apply for Loan'),
                    ),
                  ),
                ],
              ),
            )
          else
            for (final item in applications)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ApplicationTile(application: item),
              ),
        ],
      ),
    );
  }
}

const _formSections = <(String, List<(String, String)>)>[
  (
    'Personal Details',
    [
      ('fullName', 'Full Name'),
      ('parentName', "Parent's / Spouse Name"),
      ('dateOfBirth', 'Date of Birth'),
      ('gender', 'Gender'),
      ('mobile', 'Mobile Number'),
      ('email', 'Email Address'),
    ],
  ),
  (
    'Address',
    [
      ('residentialAddress', 'Residential Address'),
      ('permanentAddress', 'Permanent Address'),
      ('pinCode', 'PIN Code'),
    ],
  ),
  (
    'Occupation & Education',
    [
      ('occupation', 'Occupation'),
      ('employerDetails', 'Employer Details'),
      ('incomeDetails', 'Income Details'),
      ('educationalInfo', 'Educational Information'),
    ],
  ),
  (
    'Nominee & Emergency Contact',
    [
      ('nomineeName', 'Nominee Name'),
      ('nomineeRelation', 'Nominee Relation'),
      ('nomineeMobile', 'Nominee Mobile'),
      ('emergencyContactName', 'Emergency Contact Name'),
      ('emergencyContactRelation', 'Emergency Contact Relation'),
      ('emergencyContactMobile', 'Emergency Contact Mobile'),
    ],
  ),
  (
    'References',
    [
      ('reference1Name', 'Reference 1 Name'),
      ('reference1Mobile', 'Reference 1 Mobile'),
      ('reference2Name', 'Reference 2 Name'),
      ('reference2Mobile', 'Reference 2 Mobile'),
    ],
  ),
  (
    'Identity & Bank',
    [
      ('aadhaar', 'Aadhaar Number'),
      ('pan', 'PAN Number'),
      ('accountNumber', 'Account Number'),
      ('ifsc', 'IFSC Code'),
    ],
  ),
  (
    'Loan Details',
    [
      ('loanPurpose', 'Loan Purpose'),
      ('loanAmount', 'Loan Amount'),
      ('processingFee', 'Processing Fee'),
      ('emi', 'Monthly EMI'),
      ('totalPayable', 'Total Payable'),
      ('netCreditedAmount', 'Net Credited Amount'),
      ('offerValidUntil', 'Offer Valid Until'),
      ('eSignConsent', 'eSign Consent'),
    ],
  ),
  (
    'Account & Preferences',
    [
      ('username', 'Username'),
      ('communicationPreferences', 'Communication Preferences'),
      ('customerFeedback', 'Feedback'),
    ],
  ),
];

class _FullApplicationForm extends StatelessWidget {
  const _FullApplicationForm({
    required this.application,
    required this.canCheckCibil,
  });

  final Map application;
  final bool canCheckCibil;

  @override
  Widget build(BuildContext context) {
    final app = Map<String, dynamic>.from(application);
    final status = '${app['status'] ?? 'submitted'}';
    final verifications = app['verifications'] is Map
        ? Map<String, dynamic>.from(app['verifications'] as Map)
        : const <String, dynamic>{};
    final fields = verifications['fields'] is Map
        ? Map<String, dynamic>.from(verifications['fields'] as Map)
        : const <String, dynamic>{};
    final documents = app['documents'] is Map
        ? Map<String, dynamic>.from(app['documents'] as Map)
        : const <String, dynamic>{};
    final documentReviews = verifications['documents'] is Map
        ? Map<String, dynamic>.from(verifications['documents'] as Map)
        : const <String, dynamic>{};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeading('Latest Application'),
        const SizedBox(height: 10),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${app['id'] ?? 'Application'}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.slate900,
                      ),
                    ),
                  ),
                  _ReviewStatus(status: status, overall: true),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _statusMessage(status),
                style: const TextStyle(
                  fontSize: 12.5,
                  height: 1.4,
                  color: AppColors.slate600,
                ),
              ),
              if (app['submittedAt'] != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Submitted: ${_formatDate('${app['submittedAt']}')}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.slate400,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (canCheckCibil) ...[
          const SizedBox(height: 12),
          _CibilReportCard(
            initialReport: app['cibilReport'] is Map
                ? Map<String, dynamic>.from(app['cibilReport'] as Map)
                : const <String, dynamic>{},
          ),
        ],
        const SizedBox(height: 14),
        for (final section in _formSections) ...[
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  section.$1,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.slate900,
                  ),
                ),
                const SizedBox(height: 8),
                for (var index = 0; index < section.$2.length; index++) ...[
                  _ReviewedValue(
                    label: section.$2[index].$2,
                    value: _displayValue(app, section.$2[index].$1),
                    status: _itemStatus(fields[section.$2[index].$1]),
                  ),
                  if (index < section.$2.length - 1)
                    const Divider(height: 1, color: AppColors.line),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Uploaded Documents',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.slate900,
                ),
              ),
              const SizedBox(height: 8),
              if (documents.isEmpty)
                const Text(
                  'No documents uploaded.',
                  style: TextStyle(fontSize: 12.5, color: AppColors.slate500),
                )
              else
                for (final entry in documents.entries) ...[
                  _ReviewedValue(
                    label: _documentLabel(entry.key),
                    value: entry.value is Map
                        ? '${(entry.value as Map)['originalName'] ?? 'Uploaded'}'
                        : 'Uploaded',
                    status: _itemStatus(documentReviews[entry.key]),
                  ),
                  if (entry.key != documents.keys.last)
                    const Divider(height: 1, color: AppColors.line),
                ],
            ],
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Pull down on this page to refresh the latest admin review status.',
          style: TextStyle(fontSize: 11.5, color: AppColors.slate400),
        ),
      ],
    );
  }

  static String _statusMessage(String status) {
    return switch (status) {
      'verified' =>
        'Approved by admin. All submitted details have been verified.',
      'rejected' =>
        'Action is required. Review the rejected items shown below.',
      'in_review' =>
        'Admin review is in progress. Individual item decisions are shown below.',
      _ =>
        'Pending admin review. Your application is visible in the admin panel.',
    };
  }

  static String _itemStatus(dynamic value) {
    if (value is Map) return '${value['status'] ?? 'pending'}';
    return 'pending';
  }

  static String _displayValue(Map<String, dynamic> app, String key) {
    final value = app[key];
    if (key == 'loanAmount' ||
        key == 'processingFee' ||
        key == 'emi' ||
        key == 'totalPayable' ||
        key == 'netCreditedAmount') {
      return value is num ? formatCurrency(value) : '—';
    }
    if (key == 'eSignConsent') return value == true ? 'Yes' : 'No';
    if (key == 'communicationPreferences' && value is Map) {
      final enabled = value.entries
          .where((entry) => entry.value == true)
          .map((entry) => '${entry.key}'.toUpperCase())
          .toList();
      return enabled.isEmpty ? 'None' : enabled.join(', ');
    }
    if (key == 'gender' || key == 'loanPurpose') {
      final text = '${value ?? ''}'.replaceAll('_', ' ');
      if (text.isEmpty) return '—';
      return '${text[0].toUpperCase()}${text.substring(1)}';
    }
    final text = '${value ?? ''}'.trim();
    return text.isEmpty ? '—' : text;
  }

  static String _documentLabel(String key) {
    return switch (key) {
      'aadhaarDoc' => 'Aadhaar Document',
      'panDoc' => 'PAN Document',
      'salarySlips' => 'Salary Slips',
      'bankStatements' => 'Bank Statements',
      'photograph' => 'Profile Photograph',
      'signature' => 'Signature',
      'selfie' => 'Selfie',
      _ => key,
    };
  }

  static String _formatDate(String value) {
    final date = DateTime.tryParse(value)?.toLocal();
    if (date == null) return value;
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }
}

class _CibilReportCard extends StatefulWidget {
  const _CibilReportCard({required this.initialReport});

  final Map<String, dynamic> initialReport;

  @override
  State<_CibilReportCard> createState() => _CibilReportCardState();
}

class _CibilReportCardState extends State<_CibilReportCard> {
  late Map<String, dynamic> _report;
  bool _loading = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _report = Map<String, dynamic>.from(widget.initialReport);
  }

  @override
  void didUpdateWidget(covariant _CibilReportCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialReport != widget.initialReport) {
      _report = Map<String, dynamic>.from(widget.initialReport);
    }
  }

  Future<void> _checkCibil() async {
    final state = context.read<AppState>();
    if (state.userToken.isEmpty) return;
    setState(() {
      _loading = true;
      _error = '';
    });
    final result = await state.api.requestCibil(state.userToken);
    if (!mounted) return;
    if (result.statusCode == 401 || result.statusCode == 403) {
      setState(() {
        _loading = false;
        _error =
            result.message ??
            'CIBIL is only available during an active loan application.';
      });
      return;
    }
    if (result.ok) {
      final data = result.data ?? const <String, dynamic>{};
      final next = data['cibilReport'];
      setState(() {
        _loading = false;
        _report = next is Map ? Map<String, dynamic>.from(next) : _report;
      });
      final profileResult = await state.api.getProfile(state.userToken);
      if (mounted && profileResult.ok) {
        state.setUserProfile(profileResult.data);
      }
    } else {
      setState(() {
        _loading = false;
        _error = result.message ?? 'Could not fetch CIBIL report.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = '${_report['status'] ?? 'idle'}';
    final summary = _report['summary'] is Map
        ? Map<String, dynamic>.from(_report['summary'] as Map)
        : const <String, dynamic>{};
    final score = _report['score'] ?? summary['score'];

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'CIBIL report',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.slate900,
                  ),
                ),
              ),
              TextButton(
                onPressed: _loading ? null : _checkCibil,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.slate900,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                child: Text(
                  _loading
                      ? 'Checking…'
                      : status == 'ready'
                      ? 'Refresh'
                      : 'Check CIBIL',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Available after login while your loan application is active.',
            style: TextStyle(fontSize: 12, color: AppColors.slate500),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _CibilStat(label: 'Status', value: status),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CibilStat(
                  label: 'Score',
                  value: score == null ? '—' : '$score',
                ),
              ),
            ],
          ),
          if (_error.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              _error,
              style: const TextStyle(fontSize: 12, color: Color(0xFFBE123C)),
            ),
          ],
          if ((_report['error'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '${_report['error']}',
              style: const TextStyle(fontSize: 12, color: Color(0xFFBE123C)),
            ),
          ],
          if (status == 'pending') ...[
            const SizedBox(height: 8),
            const Text(
              'Report requested. Pull to refresh if the score is still empty.',
              style: TextStyle(fontSize: 12, color: AppColors.slate500),
            ),
          ],
        ],
      ),
    );
  }
}

class _CibilStat extends StatelessWidget {
  const _CibilStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              letterSpacing: 0.4,
              color: AppColors.slate500,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: AppColors.slate900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewedValue extends StatelessWidget {
  const _ReviewedValue({
    required this.label,
    required this.value,
    required this.status,
  });

  final String label;
  final String value;
  final String status;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
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
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                    color: AppColors.slate900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _ReviewStatus(status: status),
        ],
      ),
    );
  }
}

class _ReviewStatus extends StatelessWidget {
  const _ReviewStatus({required this.status, this.overall = false});

  final String status;
  final bool overall;

  @override
  Widget build(BuildContext context) {
    final (background, foreground, label) = switch (status) {
      'verified' => (AppColors.green50, AppColors.green700, 'Approved'),
      'accepted' => (AppColors.green50, AppColors.green700, 'Accepted'),
      'rejected' => (AppColors.red50, AppColors.red600, 'Rejected'),
      'in_review' => (AppColors.brandSoft, AppColors.brandDeep, 'In Review'),
      'submitted' => (AppColors.amber50, AppColors.amber700, 'Pending'),
      _ => (AppColors.amber50, AppColors.amber700, 'Pending'),
    };
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: overall ? 10 : 8,
        vertical: overall ? 5 : 4,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: overall ? 11.5 : 10.5,
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
      ),
    );
  }
}

class _ApplicationTile extends StatelessWidget {
  const _ApplicationTile({required this.application});

  final Map application;

  @override
  Widget build(BuildContext context) {
    final status = '${application['status'] ?? 'pending'}';

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${application['id'] ?? 'Application'}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.slate900,
                  ),
                ),
              ),
              _ReviewStatus(status: status, overall: true),
            ],
          ),
          if (application['loanAmount'] != null) ...[
            const SizedBox(height: 6),
            DetailRow(
              label: 'Amount',
              value: formatCurrency(application['loanAmount'] as num),
            ),
          ],
        ],
      ),
    );
  }
}
