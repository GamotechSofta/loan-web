import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../state/app_state.dart';
import '../utils/id_validation.dart';
import '../utils/loan_calculator.dart';
import '../widgets/celebration_overlay.dart';
import '../widgets/loan_process_layout.dart';
import '../widgets/process_ui.dart';

/// Port of `frontend/src/components/ApprovedOfferPage.jsx`.
class ApprovedOfferScreen extends StatefulWidget {
  const ApprovedOfferScreen({super.key});

  @override
  State<ApprovedOfferScreen> createState() => _ApprovedOfferScreenState();
}

class _ApprovedOfferScreenState extends State<ApprovedOfferScreen> {
  /// `const CELEBRATION_MS = 2000`
  static const Duration _celebrationDuration = Duration(milliseconds: 2000);

  final TextEditingController _amountController = TextEditingController();
  final FocusNode _amountFocus = FocusNode();

  bool _amountApplied = false;
  bool _celebrating = false;
  String _applyError = '';
  Timer? _celebrationTimer;

  int get _rawLoanAmount {
    final digits = _amountController.text.replaceAll(RegExp(r'\D'), '');
    final value = int.tryParse(digits) ?? 0;
    return value > maxLoanAmount ? maxLoanAmount : value;
  }

  int get _loanAmount => normalizeLoanAmount(_rawLoanAmount);

  bool get _amountWasAdjusted =>
      _rawLoanAmount > 0 && _loanAmount != _rawLoanAmount;

  bool get _canApply => _loanAmount > 0 && !_celebrating;

  bool get _canAccept => _amountApplied && _loanAmount > 0 && !_celebrating;

  @override
  void dispose() {
    _celebrationTimer?.cancel();
    _amountController.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  void _handleAmountChange() {
    setState(() {
      _amountApplied = false;
      _applyError = '';
    });
  }

  void _handleApplyAmount() {
    if (_celebrating) return;

    if (_loanAmount <= 0) {
      setState(() => _applyError = 'Please enter a valid loan amount first.');
      _amountFocus.requestFocus();
      return;
    }

    if (_amountWasAdjusted) {
      _amountController.text = '$_loanAmount';
    }

    setState(() {
      _applyError = '';
      _amountApplied = false;
      _celebrating = true;
    });

    _celebrationTimer?.cancel();
    _celebrationTimer = Timer(_celebrationDuration, () {
      if (!mounted) return;
      setState(() {
        _celebrating = false;
        _amountApplied = true;
      });
      _celebrationTimer = null;
    });
  }

  void _handleNext(AppState state) {
    if (!_canAccept) return;
    final offer = calculateLoanOffer(_loanAmount);
    state.mergeApplication(
      state.applicationData.copyWith(
        loanAmount: offer.loanAmount,
        processingFee: offer.processingFee,
        emi: offer.emi,
        totalPayable: offer.totalPayable,
        netCreditedAmount: offer.netCreditedAmount,
        offerValidUntil: offer.validUntil,
      ),
    );
    state.setStep(3);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final details = buildDetailedRepaymentSchedule(_loanAmount);
    final summary = details.summary;

    return Stack(
      children: [
        LoanProcessLayout(
          activeStep: 2,
          background: AppColors.surfaceMuted,
          continueLabel: 'Next',
          continueDisabled: !_canAccept,
          continueWrapper: (child) =>
              AcceptOfferReady(ready: _amountApplied, child: child),
          onBack: () => state.setStep(1),
          onContinue: () => _handleNext(state),
          child: SectionCardStyle(
            boxed: true,
            child: Column(
              children: [
                _buildAmountCard(),
                if (summary != null) ...[
                  const SizedBox(height: 14),
                  _buildOfferSummary(summary),
                  const SizedBox(height: 14),
                  _buildScheduleCard(details, summary),
                ],
                const SizedBox(height: 14),
                const SectionCard(
                  title: 'Loan Terms & Conditions',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _TermBullet(
                        'Interest is charged on reducing balance basis.',
                      ),
                      SizedBox(height: 8),
                      _TermBullet(
                        'Processing fee is deducted at the time of disbursement.',
                      ),
                      SizedBox(height: 8),
                      _TermBullet(
                        'Early repayment is allowed without foreclosure penalty.',
                      ),
                      SizedBox(height: 8),
                      _TermBullet(
                        'Late payment charges apply as per agreement.',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const SupportSection(),
              ],
            ),
          ),
        ),
        CelebrationOverlay(
          show: _celebrating,
          message: 'Amount applied successfully!',
          amountLabel: _loanAmount > 0 ? formatCurrency(_loanAmount) : '',
        ),
      ],
    );
  }

  Widget _buildAmountCard() {
    return SectionCard(
      title: 'Enter Loan Amount',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Enter the amount you want to apply for, up to ${formatCurrency(maxLoanAmount)}. Amounts are rounded to the nearest ₹1,000 for your offer.',
            style: const TextStyle(
              fontSize: 14,
              height: 1.625,
              color: AppColors.slate600,
            ),
          ),
          const SizedBox(height: 18),
          FloatingLabelField(
            label: 'Loan Amount',
            child: TextField(
              controller: _amountController,
              focusNode: _amountFocus,
              enabled: !_celebrating,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter('$maxLoanAmount'.length),
              ],
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.slate900,
              ),
              decoration:
                  errorAwareDecoration(
                    hintText: 'Enter amount',
                    hasError: _applyError.isNotEmpty,
                    fillColor: _celebrating
                        ? AppColors.surfaceMuted
                        : AppColors.surface,
                  ).copyWith(
                    prefixText: '₹  ',
                    prefixStyle: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _applyError.isNotEmpty
                          ? AppColors.red600
                          : AppColors.slate500,
                    ),
                  ),
              onChanged: (v) {
                _handleAmountChange();
                // Live red warning if they clear the amount after applying.
                if (v.isEmpty && _amountApplied) {
                  setState(
                    () =>
                        _applyError = 'Please enter a valid loan amount first.',
                  );
                }
              },
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _canApply ? _handleApplyAmount : null,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: Text(_celebrating ? 'Applying...' : 'Apply amount'),
            ),
          ),
          if (_applyError.isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.red50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _applyError,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.red600,
                ),
              ),
            ),
          if (_loanAmount > 0)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: _amountApplied
                    ? AppColors.green50
                    : AppColors.brandSoft.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(
                  color: _amountApplied
                      ? AppColors.green200
                      : AppColors.brandSoftDeep,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'OFFER AMOUNT',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.3,
                      color: AppColors.slate500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatCurrency(_loanAmount),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.brand,
                    ),
                  ),
                  if (_amountWasAdjusted)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Adjusted from ${formatCurrency(_rawLoanAmount)} to the nearest ₹1,000.',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.slate500,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          if (_amountApplied && !_celebrating)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.green50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    margin: const EdgeInsets.only(top: 2),
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.green600,
                    ),
                    child: const Text(
                      '✓',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Great! Scroll down and tap Next to continue.',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.green700,
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

  Widget _buildOfferSummary(RepaymentSummary summary) {
    return SectionCard(
      title: 'Offer Summary',
      child: Column(
        children: [
          InfoRow(label: 'Loan Amount', value: summary.loanAmountLabel),
          InfoRow(label: 'Interest Rate', value: summary.interestRateLabel),
          InfoRow(
            label: 'Monthly Interest',
            value: summary.monthlyInterestRateLabel,
          ),
          InfoRow(label: 'Processing Fee', value: summary.processingFeeLabel),
          InfoRow(label: 'Loan Tenure', value: summary.loanTenureLabel),
          InfoRow(label: 'Monthly EMI', value: summary.emiLabel),
          InfoRow(label: 'Total Interest', value: summary.totalInterestLabel),
          InfoRow(label: 'Total Payable', value: summary.totalPayableLabel),
          InfoRow(
            label: 'Net Credited Amount',
            value: summary.netCreditedAmountLabel,
            highlight: true,
          ),
          InfoRow(label: 'Offer Validity', value: summary.offerValidityLabel),
        ],
      ),
    );
  }

  Widget _buildScheduleCard(
    DetailedRepayment details,
    RepaymentSummary summary,
  ) {
    const headerStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: AppColors.slate500,
    );

    return SectionCard(
      title: 'EMI Repayment Schedule',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Fixed monthly EMI of ${summary.emiLabel} for 11 months. The final EMI may differ slightly due to rounding on the reducing balance.',
            style: const TextStyle(fontSize: 14, color: AppColors.slate600),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: AppColors.slate200),
                    ),
                  ),
                  padding: const EdgeInsets.only(bottom: 8),
                  child: const Row(
                    children: [
                      _ScheduleCell('EMI #', width: 52, style: headerStyle),
                      _ScheduleCell('Due Date', width: 96, style: headerStyle),
                      _ScheduleCell('EMI', width: 84, style: headerStyle),
                      _ScheduleCell('Principal', width: 84, style: headerStyle),
                      _ScheduleCell('Interest', width: 76, style: headerStyle),
                      _ScheduleCell('Balance', width: 84, style: headerStyle),
                    ],
                  ),
                ),
                for (var i = 0; i < details.schedule.length; i++)
                  Container(
                    decoration: BoxDecoration(
                      border: i == details.schedule.length - 1
                          ? null
                          : const Border(
                              bottom: BorderSide(color: AppColors.slate100),
                            ),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        _ScheduleCell(
                          '${details.schedule[i].installment}',
                          width: 52,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.slate700,
                          ),
                        ),
                        _ScheduleCell(
                          details.schedule[i].date,
                          width: 96,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.slate600,
                          ),
                        ),
                        _ScheduleCell(
                          details.schedule[i].emiLabel,
                          width: 84,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.slate900,
                          ),
                        ),
                        _ScheduleCell(
                          details.schedule[i].principalLabel,
                          width: 84,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.slate700,
                          ),
                        ),
                        _ScheduleCell(
                          details.schedule[i].interestLabel,
                          width: 76,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.slate700,
                          ),
                        ),
                        _ScheduleCell(
                          details.schedule[i].balanceLabel,
                          width: 84,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.slate600,
                          ),
                        ),
                      ],
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

class _ScheduleCell extends StatelessWidget {
  const _ScheduleCell(this.text, {required this.width, required this.style});

  final String text;
  final double width;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Text(text, style: style),
    );
  }
}

/// `list-disc` list item inside the terms card.
class _TermBullet extends StatelessWidget {
  const _TermBullet(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 4,
          height: 4,
          margin: const EdgeInsets.only(left: 4, top: 9, right: 12),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.slate600,
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              height: 1.625,
              color: AppColors.slate600,
            ),
          ),
        ),
      ],
    );
  }
}
