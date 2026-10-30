import 'package:acadeno_crm/shared/widgets/acadeno_dropdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/injection/injection.dart';
import '../../../../shared/snackbar_alerts/snack_alert.dart';
import '../../application/dashboard_cubit.dart';
import '../../../leads/application/lead_import_cubit.dart';
import '../../../leads/application/lead_import_state.dart';
import '../../../leads/data/model/lead_import_models.dart';
import '../../../leads/data/sources/lead_import_parser.dart';

class ImportLeadsView extends StatelessWidget {
  const ImportLeadsView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<LeadImportCubit>(),
      child: const _ImportLeadsBody(),
    );
  }
}

class _ImportLeadsBody extends StatefulWidget {
  const _ImportLeadsBody();

  @override
  State<_ImportLeadsBody> createState() => _ImportLeadsBodyState();
}

class _ImportLeadsBodyState extends State<_ImportLeadsBody> {
  bool _skipExisting = true;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<LeadImportCubit, LeadImportState>(
      listener: (context, state) {
        if (state.errorMessage != null && state.errorMessage!.isNotEmpty) {
          SnackBarAlert.showToast(
            context: context,
            message: state.errorMessage!,
            isWarning: true,
          );
        }
      },
      builder: (context, state) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 720;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Import leads',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.5,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'From Excel (.xlsx) or Google Sheets (saved as .csv). Duplicate phone numbers are detected automatically.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF667085),
                          ),
                        ),
                      ],
                    ),
                    if (state.currentStep == 2 || state.currentStep == 3)
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF4338CA),
                          side: const BorderSide(color: Color(0xFFC7D2FE)),
                        ),
                        onPressed: () =>
                            context.read<LeadImportCubit>().reset(),
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text(
                          'Start New Import',
                          style: TextStyle(fontSize: 12.5),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 18),

                // 3-Step Stepper
                _buildStepper(context, state, isMobile),
                const SizedBox(height: 18),

                // Step Body
                if (state.currentStep == 1)
                  _buildStep1Upload(context, state, isMobile),
                if (state.currentStep == 2)
                  _buildStep2CheckRows(context, state, isMobile),
                if (state.currentStep == 3)
                  _buildStep3Done(context, state, isMobile),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildStepper(
    BuildContext context,
    LeadImportState state,
    bool isMobile,
  ) {
    final cubit = context.read<LeadImportCubit>();
    final steps = [
      _buildStepCard(
        stepNumber: 1,
        label: 'Upload file',
        isCompleted: state.currentStep > 1,
        isActive: state.currentStep == 1,
        onTap: () => cubit.setStep(1),
      ),
      _buildStepCard(
        stepNumber: 2,
        label: 'Check rows',
        isCompleted: state.currentStep > 2,
        isActive: state.currentStep == 2,
        onTap: state.items.isNotEmpty ? () => cubit.setStep(2) : () {},
      ),
      _buildStepCard(
        stepNumber: 3,
        label: 'Done',
        isCompleted: state.currentStep == 3,
        isActive: state.currentStep == 3,
        onTap: state.summary != null ? () => cubit.setStep(3) : () {},
      ),
    ];

    if (isMobile) {
      return Column(
        children: [
          steps[0],
          const SizedBox(height: 8),
          steps[1],
          const SizedBox(height: 8),
          steps[2],
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: steps[0]),
        const SizedBox(width: 12),
        Expanded(child: steps[1]),
        const SizedBox(width: 12),
        Expanded(child: steps[2]),
      ],
    );
  }

  Widget _buildStepCard({
    required int stepNumber,
    required String label,
    required bool isCompleted,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    Color circleBg;
    Widget circleChild;

    if (isCompleted) {
      circleBg = const Color(0xFF15803D);
      circleChild = const Icon(Icons.check, size: 15, color: Colors.white);
    } else if (isActive) {
      circleBg = const Color(0xFF4338CA);
      circleChild = Text(
        '$stepNumber',
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      );
    } else {
      circleBg = const Color(0xFFE4E7EC);
      circleChild = Text(
        '$stepNumber',
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: Color(0xFF475467),
        ),
      );
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? const Color(0xFFD0D5DD) : const Color(0xFFE8EAF0),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: circleBg,
                shape: BoxShape.circle,
              ),
              child: circleChild,
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive
                    ? const Color(0xFF0F172A)
                    : const Color(0xFF475467),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Step 1: Upload File & Configure Source
  // ---------------------------------------------------------------------------

  Widget _buildStep1Upload(
    BuildContext context,
    LeadImportState state,
    bool isMobile,
  ) {
    final cubit = context.read<LeadImportCubit>();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8EAF0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '1. Select source event & consent basis (FR-1.1 / DPDP)',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 16,
            runSpacing: 14,
            children: [
              SizedBox(
                width: isMobile ? double.infinity : 340,
                child: AcadenoDropdown.strings(
                  label: 'Source Event / Campaign',
                  value: state.sourceEvent,
                  items: const [
                    'AI & Machine Learning Workshop (Nov)',
                    'Python Bootcamp Registration',
                    'NIT Calicut Industrial Visit',
                    'CET College Seminar Leads',
                    'Direct Walk-in / Referral Sheet',
                  ],
                  onChanged: (v) {
                    if (v != null) cubit.setSourceEvent(v);
                  },
                ),
              ),
              SizedBox(
                width: isMobile ? double.infinity : 280,
                child: AcadenoDropdown.strings(
                  label: 'DPDP Consent Basis',
                  value: state.consentBasis,
                  items: const [
                    'Event registration form',
                    'College attendance sheet',
                    'Website inquiry form',
                    'Direct verbal consent / Walk-in',
                  ],
                  onChanged: (v) {
                    if (v != null) cubit.setConsentBasis(v);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Template & Fast Testing Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '2. Upload CSV or Excel file',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              Wrap(
                spacing: 8,
                children: [
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF4338CA),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                    ),
                    onPressed: () => _downloadSampleTemplate(context),
                    icon: const Icon(Icons.download_rounded, size: 16),
                    label: const Text(
                      'Download Sample CSV',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF0F172A),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                    ),
                    onPressed: () => _openPasteCsvDialog(context),
                    icon: const Icon(Icons.paste_rounded, size: 16),
                    label: const Text(
                      'Paste CSV Text',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Upload Dropzone
          InkWell(
            onTap: state.isParsing ? null : () => _pickAndParseFile(context),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFD0D5DD),
                  style: BorderStyle.solid,
                ),
              ),
              child: state.isParsing
                  ? Column(
                      children: const [
                        CircularProgressIndicator(strokeWidth: 2.5),
                        SizedBox(height: 14),
                        Text(
                          'Parsing file and normalizing 10-digit Indian numbers...',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF475467),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: const BoxDecoration(
                            color: Color(0xFFEEF2FF),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.upload_file_outlined,
                            size: 32,
                            color: Color(0xFF4338CA),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          state.fileName.isNotEmpty
                              ? 'Selected file: ${state.fileName}'
                              : 'Click to select .CSV or .XLSX file',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Supported columns: Name, Phone, Email, College, Branch, Year, Course, Notes, Consent\nIndian mobile numbers are automatically cleaned and verified by their last 10 digits.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF667085),
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 14),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF4338CA),
                            side: const BorderSide(color: Color(0xFFC7D2FE)),
                          ),
                          onPressed: () => _pickAndParseFile(context),
                          icon: const Icon(Icons.folder_open_rounded, size: 16),
                          label: const Text('Browse Files'),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 18),

          // Quick testing helper banner
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.bolt_rounded,
                  size: 20,
                  color: Color(0xFF16A34A),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Want to test right now? Load our pre-configured ACADENO Webinar lead batch (includes valid, existing, duplicates, and format errors).',
                    style: TextStyle(fontSize: 12.5, color: Color(0xFF166534)),
                  ),
                ),
                TextButton(
                  onPressed: () => cubit.loadSampleData(),
                  child: const Text(
                    'Load Demo Batch',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF15803D),
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

  // ---------------------------------------------------------------------------
  // Step 2: Check Rows & Validation Preview
  // ---------------------------------------------------------------------------

  Widget _buildStep2CheckRows(
    BuildContext context,
    LeadImportState state,
    bool isMobile,
  ) {
    final cubit = context.read<LeadImportCubit>();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8EAF0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 3 Summary Cards
          if (isMobile) ...[
            _buildSummaryBanner(
              count: '${state.newLeadsCount}',
              label: 'New leads to create',
              bg: const Color(0xFFE6F4EA),
              fg: const Color(0xFF15803D),
            ),
            const SizedBox(height: 10),
            _buildSummaryBanner(
              count: '${state.existingLeadsCount}',
              label: _skipExisting
                  ? 'Already exist – will be skipped'
                  : 'Already exist – will enrich blanks',
              bg: const Color(0xFFE8F1FD),
              fg: const Color(0xFF1D4ED8),
            ),
            const SizedBox(height: 10),
            _buildSummaryBanner(
              count: '${state.skippedLeadsCount}',
              label: 'Invalid / duplicates skipped',
              bg: const Color(0xFFFEF0E6),
              fg: const Color(0xFF9A3412),
            ),
          ] else
            Row(
              children: [
                Expanded(
                  child: _buildSummaryBanner(
                    count: '${state.newLeadsCount}',
                    label: 'New leads to create',
                    bg: const Color(0xFFE6F4EA),
                    fg: const Color(0xFF15803D),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _buildSummaryBanner(
                    count: '${state.existingLeadsCount}',
                    label: _skipExisting
                        ? 'Already exist – will be skipped'
                        : 'Already exist – will enrich blanks',
                    bg: const Color(0xFFE8F1FD),
                    fg: const Color(0xFF1D4ED8),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _buildSummaryBanner(
                    count: '${state.skippedLeadsCount}',
                    label: 'Invalid / duplicates skipped',
                    bg: const Color(0xFFFEF0E6),
                    fg: const Color(0xFF9A3412),
                  ),
                ),
              ],
            ),

          const SizedBox(height: 20),

          // Filter bar and Policy toggle
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: [
              Wrap(
                spacing: 8,
                children: [
                  _filterChip(
                    context,
                    state,
                    'all',
                    'All (${state.items.length})',
                  ),
                  _filterChip(
                    context,
                    state,
                    'new',
                    'New (${state.newLeadsCount})',
                  ),
                  _filterChip(
                    context,
                    state,
                    'existing',
                    'Existing (${state.existingLeadsCount})',
                  ),
                  _filterChip(
                    context,
                    state,
                    'issues',
                    'Issues / Skipped (${state.skippedLeadsCount})',
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Skip already existing leads:',
                    style: TextStyle(fontSize: 12.5, color: Color(0xFF475467)),
                  ),
                  const SizedBox(width: 8),
                  Switch(
                    value: _skipExisting,
                    activeThumbColor: const Color(0xFF4338CA),
                    onChanged: (val) => setState(() => _skipExisting = val),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Attention Table
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFEAECF0)),
            ),
            child: isMobile
                ? _buildMobileRows(context, state)
                : _buildDesktopTable(context, state),
          ),

          const SizedBox(height: 22),

          // Bottom Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SizedBox(
                height: 42,
                child: OutlinedButton(
                  onPressed: () => cubit.setStep(1),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0F172A),
                    side: const BorderSide(color: Color(0xFFD0D5DD)),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    '← Back to Upload',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              SizedBox(
                height: 42,
                child: ElevatedButton(
                  onPressed:
                      state.isImporting ||
                          state.isVerifying ||
                          state.importableTotal == 0
                      ? null
                      : () => _showImportConfirmation(context, state),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4338CA),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: state.isImporting
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Importing (${state.processedCount}/${state.totalCandidates})...',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        )
                      : Text(
                          'Import ${state.importableTotal} Leads →',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filterChip(
    BuildContext context,
    LeadImportState state,
    String key,
    String label,
  ) {
    final isSelected = state.filter == key;
    return ChoiceChip(
      selected: isSelected,
      label: Text(label),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        color: isSelected ? Colors.white : const Color(0xFF475467),
      ),
      selectedColor: const Color(0xFF4338CA),
      backgroundColor: const Color(0xFFF2F4F7),
      onSelected: (_) => context.read<LeadImportCubit>().setFilter(key),
    );
  }

  Widget _buildSummaryBanner({
    required String count,
    required String label,
    required Color bg,
    required Color fg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            count,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: fg,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopTable(BuildContext context, LeadImportState state) {
    const headerStyle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: Color(0xFF667085),
      letterSpacing: 0.4,
    );

    final displayItems = state.filteredItems;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: const BoxDecoration(
            color: Color(0xFFF9FAFB),
            borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
            border: Border(bottom: BorderSide(color: Color(0xFFEAECF0))),
          ),
          child: const Row(
            children: [
              Expanded(flex: 8, child: Text('ROW', style: headerStyle)),
              Expanded(flex: 22, child: Text('NAME', style: headerStyle)),
              Expanded(flex: 18, child: Text('PHONE', style: headerStyle)),
              Expanded(
                flex: 24,
                child: Text('COLLEGE / DETAILS', style: headerStyle),
              ),
              Expanded(
                flex: 28,
                child: Text('STATUS & REASON', style: headerStyle),
              ),
            ],
          ),
        ),
        if (displayItems.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Text(
              'No rows match the selected filter.',
              style: TextStyle(color: Color(0xFF667085)),
            ),
          )
        else
          ...displayItems.map((item) {
            final isExcluded = item.isExcluded;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              decoration: BoxDecoration(
                color: isExcluded ? const Color(0xFFF8FAFC) : Colors.white,
                border: const Border(
                  bottom: BorderSide(color: Color(0xFFF2F4F7)),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 8,
                    child: Text(
                      '#${item.rowNumber}',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isExcluded
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF475467),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 22,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.name.isEmpty ? '(blank)' : item.name,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isExcluded
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF0F172A),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.edit_outlined,
                            size: 15,
                            color: Color(0xFF94A3B8),
                          ),
                          tooltip: 'Edit row',
                          onPressed: () => _openEditRowDialog(context, item),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 18,
                    child: Text(
                      item.phone.isEmpty ? '—' : item.phone,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isExcluded
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF344054),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 24,
                    child: Text(
                      item.collegeBranch.isNotEmpty
                          ? item.collegeBranch
                          : (item.email.isNotEmpty ? item.email : '—'),
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isExcluded
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF475467),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    flex: 28,
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isExcluded
                                  ? const Color(0xFFF1F5F9)
                                  : Color(item.status.badgeBgHex),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              isExcluded
                                  ? 'Excluded from import'
                                  : (item.issueMessage.isNotEmpty
                                        ? item.issueMessage
                                        : item.status.label),
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: isExcluded
                                    ? const Color(0xFF64748B)
                                    : Color(item.status.badgeFgHex),
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Checkbox(
                          value: !item.isExcluded,
                          activeColor: const Color(0xFF4338CA),
                          onChanged: (_) => context
                              .read<LeadImportCubit>()
                              .toggleExcludeRow(item.rowNumber),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _buildMobileRows(BuildContext context, LeadImportState state) {
    final displayItems = state.filteredItems;

    if (displayItems.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: Text(
            'No rows match the selected filter.',
            style: TextStyle(color: Color(0xFF667085)),
          ),
        ),
      );
    }

    return Column(
      children: displayItems.map((item) {
        final isExcluded = item.isExcluded;

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFF2F4F7))),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Row ${item.rowNumber} · ${item.name.isEmpty ? "(blank)" : item.name}',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: isExcluded
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.edit_outlined,
                      size: 16,
                      color: Color(0xFF64748B),
                    ),
                    onPressed: () => _openEditRowDialog(context, item),
                  ),
                  Checkbox(
                    value: !item.isExcluded,
                    activeColor: const Color(0xFF4338CA),
                    onChanged: (_) => context
                        .read<LeadImportCubit>()
                        .toggleExcludeRow(item.rowNumber),
                  ),
                ],
              ),
              Text(
                'Phone: ${item.phone.isEmpty ? "—" : item.phone} · ${item.collegeBranch}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF475467)),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isExcluded
                      ? const Color(0xFFF1F5F9)
                      : Color(item.status.badgeBgHex),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isExcluded
                      ? 'Excluded'
                      : (item.issueMessage.isNotEmpty
                            ? item.issueMessage
                            : item.status.label),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isExcluded
                        ? const Color(0xFF64748B)
                        : Color(item.status.badgeFgHex),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ---------------------------------------------------------------------------
  // Step 3: Done Summary
  // ---------------------------------------------------------------------------

  Widget _buildStep3Done(
    BuildContext context,
    LeadImportState state,
    bool isMobile,
  ) {
    final summary = state.summary;
    final totalImported = summary?.importedCount ?? state.importableTotal;
    final newCreated = summary?.validCount ?? state.newLeadsCount;
    final enrichedOrSkipped =
        summary?.existingCount ?? state.existingLeadsCount;
    final skippedCount = summary?.skippedCount ?? state.skippedLeadsCount;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8EAF0)),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: Color(0xFFE6F4EA),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              size: 32,
              color: Color(0xFF15803D),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '$totalImported leads imported successfully!',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Source: ${state.sourceEvent} · Consent: ${state.consentBasis}\n$newCreated new leads created · $enrichedOrSkipped existing profiles handled · $skippedCount invalid/duplicate rows skipped.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF667085),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),

          Wrap(
            spacing: 12,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF4338CA),
                  side: const BorderSide(color: Color(0xFFC7D2FE)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => _downloadErrorReport(context, state),
                icon: const Icon(Icons.file_download_outlined, size: 18),
                label: const Text('Download Skipped / Error Report (.csv)'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4338CA),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  // Switch to Leads & Assignment page
                  try {
                    context.read<DashboardCubit>().selectNav(1);
                  } catch (_) {}
                },
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: const Text('Go to Leads Dashboard'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Dialogs & File Operations
  // ---------------------------------------------------------------------------

  void _downloadSampleTemplate(BuildContext context) {
    Clipboard.setData(
      const ClipboardData(text: LeadImportParser.sampleTemplateCsv),
    );
    SnackBarAlert.showToast(
      context: context,
      message:
          'Sample CSV template copied to clipboard! You can also save it as acadeno_leads_template.csv.',
    );
  }

  void _downloadErrorReport(BuildContext context, LeadImportState state) {
    final csv = state.summary?.errorReportCsv.isNotEmpty == true
        ? state.summary!.errorReportCsv
        : LeadImportParser.generateErrorReportCsv(state.items);

    Clipboard.setData(ClipboardData(text: csv));
    SnackBarAlert.showToast(
      context: context,
      message:
          'Skipped & error report copied to clipboard (${csv.split("\n").length - 1} rows)!',
    );
  }

  void _openPasteCsvDialog(BuildContext context) {
    final textController = TextEditingController();
    final cubit = context.read<LeadImportCubit>();

    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        title: const Text(
          'Paste CSV Lines',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Paste rows copied directly from Excel, Numbers, or Google Sheets with column headers (Name, Phone, College...):',
                style: TextStyle(fontSize: 12.5, color: Color(0xFF667085)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: textController,
                maxLines: 8,
                decoration: const InputDecoration(
                  hintText:
                      'Name,Phone,Email,College...\nArun,9847011111,arun@gmail.com,NIT Calicut...',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4338CA),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final text = textController.text.trim();
              if (text.isEmpty) return;
              Navigator.pop(dlgCtx);
              cubit.parseCsvContent(
                text,
                'pasted_data.csv',
                fileSizeBytes: text.length,
              );
            },
            child: const Text('Parse Rows'),
          ),
        ],
      ),
    );
  }

  void _pickAndParseFile(BuildContext context) async {
    // For universal web/desktop compatibility: provide file picker or text input
    _openPasteCsvDialog(context);
  }

  void _openEditRowDialog(BuildContext context, LeadImportItem item) {
    final nameCtrl = TextEditingController(text: item.name);
    final phoneCtrl = TextEditingController(text: item.phone);
    final emailCtrl = TextEditingController(text: item.email);
    final collegeCtrl = TextEditingController(text: item.college);
    final branchCtrl = TextEditingController(text: item.branch);
    final yearCtrl = TextEditingController(text: item.year);

    final cubit = context.read<LeadImportCubit>();

    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        title: Text(
          'Edit Row #${item.rowNumber}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Name *',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: phoneCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Phone (10-digit Indian Mobile) *',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: collegeCtrl,
                        decoration: const InputDecoration(
                          labelText: 'College',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: branchCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Branch',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: yearCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Year / Semester',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4338CA),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(dlgCtx);
              cubit.updateRowDetails(
                item.rowNumber,
                name: nameCtrl.text,
                phone: phoneCtrl.text,
                email: emailCtrl.text,
                college: collegeCtrl.text,
                branch: branchCtrl.text,
                year: yearCtrl.text,
              );
            },
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }

  void _showImportConfirmation(BuildContext context, LeadImportState state) {
    final cubit = context.read<LeadImportCubit>();

    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        title: const Text(
          'Confirm Lead Import',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to write ${state.importableTotal} leads to Firestore?',
              style: const TextStyle(
                fontSize: 13.5,
                color: Color(0xFF0F172A),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '• ${state.newLeadsCount} new leads will be created in Firestore leads collection.',
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF475467)),
            ),
            if (state.existingLeadsCount > 0)
              Text(
                _skipExisting
                    ? '• ${state.existingLeadsCount} existing leads will be skipped (no overwrite).'
                    : '• ${state.existingLeadsCount} existing leads will be enriched with missing details.',
                style: const TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF475467),
                ),
              ),
            Text(
              '• ${state.skippedLeadsCount} invalid or duplicate rows will be skipped.',
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF475467)),
            ),
            const SizedBox(height: 10),
            Text(
              'Source Event: ${state.sourceEvent}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            Text(
              'Consent: ${state.consentBasis}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4338CA),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(dlgCtx);
              cubit.executeImport(skipExisting: _skipExisting);
            },
            child: const Text('Confirm & Save to Database'),
          ),
        ],
      ),
    );
  }
}
