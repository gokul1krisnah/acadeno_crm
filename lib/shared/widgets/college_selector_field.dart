import 'dart:async';
import 'package:acadeno_crm/core/services/firestore_stream_cache.dart';
import 'package:acadeno_crm/shared/theme/app_svgs.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'acadeno_dropdown.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

/// A dynamic college selection and editable input component.
/// Provides a toggle between College and Other categories (Plus Two, Business Development,
/// Career Switching, Skill Upgrading) + curved dropdown of known colleges + "+ Add New College".
/// Selecting a college auto-populates the editable [College · Branch · Year] text field.
/// Any newly entered college is automatically persisted to Firestore 'colleges' collection.
class CollegeSelectorField extends StatefulWidget {
  final TextEditingController controller;
  final List<String>? additionalColleges;
  final String label;
  final String? Function(String?)? validator;
  final bool useBentoLeadDetailsStyle;
  final ValueChanged<String>? onChanged;

  const CollegeSelectorField({
    super.key,
    required this.controller,
    this.additionalColleges,
    this.label = 'COLLEGE · BRANCH · YEAR',
    this.validator,
    this.useBentoLeadDetailsStyle = false,
    this.onChanged,
  });

  /// Persists a new college name into the Firestore 'colleges' collection so it
  /// automatically appears in the dropdown across the entire CRM system.
  static Future<void> saveCollegeIfNew(String rawText) async {
    final clean = rawText.split(RegExp(r'[·\-]')).first.trim();
    if (clean.isEmpty || clean.length < 2) return;
    // Don't save standard non-college categories to colleges collection
    for (final otherCat in _CollegeSelectorFieldState._otherCategories) {
      if (clean.toLowerCase() == otherCat.toLowerCase()) return;
    }
    try {
      await FirebaseFirestore.instance.collection('colleges').doc(clean).set({
        'name': clean,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // Non-fatal if offline
    }
  }

  @override
  State<CollegeSelectorField> createState() => _CollegeSelectorFieldState();
}

class _CollegeSelectorFieldState extends State<CollegeSelectorField> {
  static const _defaultColleges = [
    'NIT Calicut',
    'MES College',
    'Farook College',
    'GEC Kozhikode',
    'KMCT College of Engineering',
    'Government Polytechnic',
  ];

  static const _otherValue = '__OTHER_COLLEGE__';
  static const _otherCategoryValue = '__OTHER_CATEGORY__';

  static const _otherCategories = [
    'Plus Two',
    'Business Development',
    'Career Switching',
    'Skill Upgrading',
  ];

  final Set<String> _collegeList = {};
  String? _selectedCollege;
  bool _isOther = false;
  bool _isSavingCollege = false;
  bool _isOtherCategory = false;
  String? _selectedOtherCategory;
  final TextEditingController _customCollegeCtrl = TextEditingController();
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _collegeSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _leadsSub;

  @override
  void initState() {
    super.initState();
    _collegeList.addAll(_defaultColleges);
    if (widget.additionalColleges != null) {
      _collegeList.addAll(
        widget.additionalColleges!
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty && s != '—'),
      );
    }

    _determineSelectionFromText(widget.controller.text);

    // Stream real-time colleges from Firestore with graceful fallback handling
    _collegeSub = FirestoreStreamCache.instance
        .watchCollection('colleges')
        .listen(
          (snap) {
            if (!mounted) return;
            var changed = false;
            for (final doc in snap.docs) {
              final name = (doc.data()['name'] ?? doc.id).toString().trim();
              if (name.isNotEmpty && !_collegeList.contains(name)) {
                _collegeList.add(name);
                changed = true;
              }
            }
            if (changed) setState(() {});
          },
          onError: (error) {
            debugPrint('Colleges stream notice: $error');
          },
        );

    // Also include existing colleges from leads so any previously used college appears in dropdown
    _leadsSub = FirestoreStreamCache.instance
        .watchCollection('leads')
        .listen(
          (snap) {
            if (!mounted) return;
            var changed = false;
            for (final doc in snap.docs) {
              final raw = (doc.data()['collegeBranch'] ??
                      doc.data()['college'] ??
                      '')
                  .toString();
              final name = raw.split(RegExp(r'[·\-]')).first.trim();
              if (name.length >= 2 &&
                  name != '—' &&
                  !_otherCategories.any((cat) => cat.toLowerCase() == name.toLowerCase()) &&
                  !_collegeList.contains(name)) {
                _collegeList.add(name);
                changed = true;
              }
            }
            if (changed) setState(() {});
          },
          onError: (_) {},
        );
  }

  @override
  void dispose() {
    _collegeSub?.cancel();
    _leadsSub?.cancel();
    _customCollegeCtrl.dispose();
    super.dispose();
  }

  void _determineSelectionFromText(String text) {
    final clean = text.trim();
    if (clean.isEmpty) {
      _isOtherCategory = false;
      _selectedOtherCategory = null;
      _selectedCollege = null;
      _isOther = false;
      return;
    }

    // Check if it matches one of the other categories
    final matchedOther = _otherCategories.firstWhere(
      (cat) => clean.toLowerCase().startsWith(cat.toLowerCase()),
      orElse: () => '',
    );

    if (matchedOther.isNotEmpty) {
      _isOtherCategory = true;
      _selectedOtherCategory = matchedOther;
      _selectedCollege = null;
      _isOther = false;
      return;
    }

    _isOtherCategory = false;
    _selectedOtherCategory = null;

    final parts = text.split(RegExp(r'[·\-]'));
    final collegePart = parts.isNotEmpty ? parts.first.trim() : '';

    if (collegePart.isEmpty) {
      _selectedCollege = null;
      _isOther = false;
      return;
    }

    final matched = _collegeList.firstWhere(
      (c) => c.toLowerCase() == collegePart.toLowerCase(),
      orElse: () => '',
    );

    if (matched.isNotEmpty) {
      _selectedCollege = matched;
      _isOther = false;
    } else {
      _collegeList.add(collegePart);
      _selectedCollege = collegePart;
      _isOther = false;
    }
  }

  void _switchToOtherCategory([String? initialCategory]) {
    final cat = initialCategory ?? _selectedOtherCategory ?? _otherCategories.first;
    setState(() {
      _isOtherCategory = true;
      _selectedOtherCategory = cat;
      _isOther = false;
      widget.controller.text = cat;
    });
    widget.onChanged?.call(widget.controller.text);
  }

  void _switchToCollege([String? college]) {
    final col = college ??
        (_selectedCollege != null &&
                _selectedCollege != _otherCategoryValue &&
                _selectedCollege != _otherValue
            ? _selectedCollege
            : (_collegeList.isNotEmpty ? _collegeList.first : 'NIT Calicut'));
    setState(() {
      _isOtherCategory = false;
      _selectedCollege = col;
      _isOther = false;
      final defaultBranchYear = widget.useBentoLeadDetailsStyle
          ? ' · CSE · 3'
          : ' · CSE · 3rd yr';
      widget.controller.text = '$col$defaultBranchYear';
    });
    widget.onChanged?.call(widget.controller.text);
  }

  void _onOtherCategoryChanged(String val) {
    setState(() {
      _selectedOtherCategory = val;
      final parts = widget.controller.text.split('·');
      final detail = parts.length > 1 ? ' ·${parts.sublist(1).join('·')}' : '';
      widget.controller.text = '$val$detail';
    });
    widget.onChanged?.call(widget.controller.text);
  }

  void _onDropdownChanged(String? val) {
    if (val == null) return;
    if (val == _otherCategoryValue) {
      _switchToOtherCategory();
      return;
    }
    setState(() {
      _selectedCollege = val;
      if (val == _otherValue) {
        _isOther = true;
        final parts = widget.controller.text.split('·');
        final branchYear = parts.length > 1
            ? ' ·${parts.sublist(1).join('·')}'
            : (widget.useBentoLeadDetailsStyle
                  ? ' · CSE · 3'
                  : ' · CSE · 3rd yr');
        _customCollegeCtrl.text = '';
        widget.controller.text = branchYear.trim();
      } else {
        _isOther = false;
        final parts = widget.controller.text.split('·');
        final branchYear = parts.length > 1
            ? ' ·${parts.sublist(1).join('·')}'
            : (widget.useBentoLeadDetailsStyle
                  ? ' · CSE · 3'
                  : ' · CSE · 3rd yr');
        widget.controller.text = '$val$branchYear';
      }
    });
    widget.onChanged?.call(widget.controller.text);
  }

  void _onCustomCollegeChanged(String text) {
    final clean = text.trim();
    final parts = widget.controller.text.split('·');
    final branchYear = parts.length > 1
        ? ' ·${parts.sublist(1).join('·')}'
        : (widget.useBentoLeadDetailsStyle ? ' · CSE · 3' : ' · CSE · 3rd yr');
    widget.controller.text = clean.isNotEmpty
        ? '$clean$branchYear'
        : branchYear.trim();
    widget.onChanged?.call(widget.controller.text);
  }

  Future<void> _confirmAndAddCustomCollege() async {
    final clean = _customCollegeCtrl.text.trim();
    if (clean.length < 2) return;
    setState(() => _isSavingCollege = true);
    await CollegeSelectorField.saveCollegeIfNew(clean);
    if (!mounted) return;
    setState(() {
      _isSavingCollege = false;
      _collegeList.add(clean);
      _selectedCollege = clean;
      _isOther = false;
      final parts = widget.controller.text.split('·');
      final branchYear = parts.length > 1
          ? ' ·${parts.sublist(1).join('·')}'
          : (widget.useBentoLeadDetailsStyle
                ? ' · CSE · 3'
                : ' · CSE · 3rd yr');
      widget.controller.text = '$clean$branchYear';
    });
    widget.onChanged?.call(widget.controller.text);
  }

  Widget _getOtherCategoryIcon(String category) {
    switch (category) {
      case 'Plus Two':
        return const Icon(
          Icons.school_outlined,
          size: 16,
          color: Color(0xFF4F46E5),
        );
      case 'Business Development':
        return const Icon(
          Icons.trending_up_rounded,
          size: 16,
          color: Color(0xFF059669),
        );
      case 'Career Switching':
        return const Icon(
          Icons.swap_horiz_rounded,
          size: 16,
          color: Color(0xFFD97706),
        );
      case 'Skill Upgrading':
        return const Icon(
          Icons.upgrade_rounded,
          size: 16,
          color: Color(0xFF2563EB),
        );
      default:
        return const Icon(
          Icons.category_outlined,
          size: 16,
          color: Color(0xFF64748B),
        );
    }
  }

  Widget _buildModeSelector() {
    return Container(
      height: 38,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () {
                if (_isOtherCategory) {
                  _switchToCollege();
                }
              },
              borderRadius: BorderRadius.circular(8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: !_isOtherCategory ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: !_isOtherCategory
                      ? const [
                          BoxShadow(
                            color: Color(0x14000000),
                            blurRadius: 3,
                            offset: Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.account_balance_outlined,
                      size: 15,
                      color: !_isOtherCategory
                          ? const Color(0xFFD45107)
                          : const Color(0xFF64748B),
                    ),
                    const Gap(6),
                    Text(
                      'College',
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: !_isOtherCategory
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: !_isOtherCategory
                            ? const Color(0xFF0F172A)
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: () {
                if (!_isOtherCategory) {
                  _switchToOtherCategory();
                }
              },
              borderRadius: BorderRadius.circular(8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _isOtherCategory ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: _isOtherCategory
                      ? const [
                          BoxShadow(
                            color: Color(0x14000000),
                            blurRadius: 3,
                            offset: Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.category_outlined,
                      size: 15,
                      color: _isOtherCategory
                          ? const Color(0xFFD45107)
                          : const Color(0xFF64748B),
                    ),
                    const Gap(6),
                    Text(
                      'Other',
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: _isOtherCategory
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: _isOtherCategory
                            ? const Color(0xFF0F172A)
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sortedColleges = _collegeList.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    final dropdownItems = [
      ...sortedColleges.map(
        (c) => AcadenoDropdownItem<String>(
          value: c,
          label: c,
          icon: const Icon(
            Icons.school_outlined,
            size: 16,
            color: Color(0xFF64748B),
          ),
        ),
      ),
      const AcadenoDropdownItem<String>(
        value: _otherValue,
        label: '+ Add New College...',
        icon: Icon(
          Icons.add_circle_outline_rounded,
          size: 16,
          color: Color(0xFFD45107),
        ),
      ),
      const AcadenoDropdownItem<String>(
        value: _otherCategoryValue,
        label: 'Other (Plus Two, Career Switching...)',
        icon: Icon(
          Icons.more_horiz_rounded,
          size: 16,
          color: Color(0xFF4F46E5),
        ),
      ),
    ];

    if (widget.useBentoLeadDetailsStyle) {
      final currentVal =
          (_selectedCollege != null &&
              dropdownItems.any((i) => i.value == _selectedCollege))
          ? _selectedCollege
          : (sortedColleges.isNotEmpty ? sortedColleges.first : null);

      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildModeSelector(),
            const Gap(10),

            if (!_isOtherCategory) ...[
              // 1749:515 - College Selection
              Text(
                'College Selection',
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF334155),
                  height: 17.25 / 11.5,
                ),
              ),
              const Gap(4),
              Container(
                height: 47,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFE5E7EB),
                    width: 1,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0D764BA2),
                      blurRadius: 5,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: currentVal,
                    isExpanded: true,
                    isDense: true,
                    dropdownColor: const Color(0xFFE2E2E2),
                    borderRadius: BorderRadius.circular(12),
                    icon: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: Color(0xFF2E1D44),
                    ),
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF2E1D44),
                    ),
                    selectedItemBuilder: (context) => [
                      ...sortedColleges.map((c) => Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          c,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF2E1D44),
                          ),
                        ),
                      )),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '+ Add New College...',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFD35401),
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Other (Plus Two, Career Switching...)',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF4F46E5),
                          ),
                        ),
                      ),
                    ],
                    items: [
                      ...sortedColleges.map(
                        (c) => DropdownMenuItem<String>(
                          value: c,
                          child: AcadenoDropdown.buildMenuItemChild(
                            label: c,
                            isSelected: c == currentVal,
                          ),
                        ),
                      ),
                      DropdownMenuItem<String>(
                        value: _otherValue,
                        child: AcadenoDropdown.buildMenuItemChild(
                          label: '+ Add New College...',
                          isSelected: false,
                          textColor: const Color(0xFFD35401),
                        ),
                      ),
                      DropdownMenuItem<String>(
                        value: _otherCategoryValue,
                        child: AcadenoDropdown.buildMenuItemChild(
                          label: 'Other (Plus Two, Career Switching...)',
                          isSelected: false,
                          textColor: const Color(0xFF4F46E5),
                        ),
                      ),
                    ],
                    onChanged: _onDropdownChanged,
                  ),
                ),
              ),
              if (_isOther) ...[
                const Gap(8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFED7AA)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 36,
                          child: TextFormField(
                            controller: _customCollegeCtrl,
                            textAlignVertical: TextAlignVertical.center,
                            onChanged: _onCustomCollegeChanged,
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF0F172A),
                            ),
                            decoration: InputDecoration(
                              hintText: 'Type new college name...',
                              hintStyle: GoogleFonts.inter(
                                fontSize: 12,
                                color: const Color(0xFF94A3B8),
                              ),
                              isDense: true,
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: Color(0xFFFDBA74),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: Color(0xFFFDBA74),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE8612D),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const Gap(8),
                      SizedBox(
                        height: 36,
                        child: ElevatedButton(
                          onPressed: _isSavingCollege
                              ? null
                              : _confirmAndAddCustomCollege,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE8612D),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            'Add',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const Gap(9),
              // 1749:528 - College · Branch · Year
              Text(
                'College · Branch · Year',
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF334155),
                  height: 17.25 / 11.5,
                ),
              ),
            ] else ...[
              // Other Category Selection for Bento style
              Text(
                'Background / Category',
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF334155),
                  height: 17.25 / 11.5,
                ),
              ),
              const Gap(4),
              AcadenoDropdown<String>(
                hint: 'Select Category',
                value: _selectedOtherCategory,
                items: _otherCategories
                    .map(
                      (cat) => AcadenoDropdownItem<String>(
                        value: cat,
                        label: cat,
                        icon: _getOtherCategoryIcon(cat),
                      ),
                    )
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    _onOtherCategoryChanged(val);
                  }
                },
                fillColor: const Color(0xFFF5F5F5),
                borderColor: const Color(0xFFE5E7EB),
                borderRadius: 16.0,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 13,
                ),
              ),
              const Gap(9),
              Text(
                'Background Details (Editable)',
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF334155),
                  height: 17.25 / 11.5,
                ),
              ),
            ],

            const Gap(4),
            Stack(
              children: [
                TextFormField(
                  controller: widget.controller,
                  textAlignVertical: TextAlignVertical.center,
                  onChanged: (v) {
                    setState(() {
                      _determineSelectionFromText(v);
                    });
                    widget.onChanged?.call(v);
                  },
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF0F172A),
                  ),
                  decoration: InputDecoration(
                    hintText: _isOtherCategory
                        ? (_selectedOtherCategory ?? 'Career Switching · Working Professional')
                        : 'NIT Calicut · CSE · 3',
                    hintStyle: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF94A3B8),
                    ),
                    isDense: true,
                    filled: true,
                    fillColor: const Color(0x80F8FAFC),
                    constraints: const BoxConstraints(minHeight: 40),
                    contentPadding: const EdgeInsets.only(
                      left: 37,
                      right: 13,
                      top: 10,
                      bottom: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFFE2E8F0),
                        width: 1,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFFE2E8F0),
                        width: 1,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFFE8612D),
                        width: 1.2,
                      ),
                    ),
                  ),
                  validator:
                      widget.validator ??
                      (v) => (v == null || v.trim().isEmpty)
                          ? (_isOtherCategory ? 'Details required' : 'College details required')
                          : null,
                ),
                Positioned(
                  left: 14.55,
                  top: 13.2,
                  child: IgnorePointer(
                    child: SvgPicture.asset(
                      AppSvgs.leadDetailLayers,
                      width: 11.9,
                      height: 12.75,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Mode Selector: College vs Other
        _buildModeSelector(),
        const Gap(10),

        if (!_isOtherCategory) ...[
          // 1. Header with Quick "+ Add College" toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Existing College',
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF334155),
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: () {
                  if (_isOther) {
                    final fallback = sortedColleges.isNotEmpty
                        ? sortedColleges.first
                        : 'NIT Calicut';
                    _onDropdownChanged(fallback);
                  } else {
                    _onDropdownChanged(_otherValue);
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isOther
                            ? Icons.list_alt_rounded
                            : Icons.add_circle_outline_rounded,
                        size: 14,
                        color: const Color(0xFFD45107),
                      ),
                      const Gap(4),
                      Text(
                        _isOther ? 'Choose Existing' : '+ Add New College',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFD45107),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const Gap(6),

          // 2. Curved Dropdown of existing colleges
          AcadenoDropdown<String>(
            hint: 'Select existing college or add new',
            value:
                (_selectedCollege != null &&
                    dropdownItems.any((i) => i.value == _selectedCollege))
                ? _selectedCollege
                : null,
            items: dropdownItems,
            onChanged: _onDropdownChanged,
            fillColor: const Color(0xFFF8FAFC),
            borderColor: const Color(0xFFE2E8F0),
            borderRadius: 12.0,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
          ),

          // 3. Extra user-friendly card when "+ Add New College" is active
          if (_isOther) ...[
            const Gap(10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFED7AA)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.add_business_rounded,
                        size: 16,
                        color: Color(0xFFC2410C),
                      ),
                      const Gap(6),
                      Text(
                        'Add New College to List',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF9A3412),
                        ),
                      ),
                    ],
                  ),
                  const Gap(8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _customCollegeCtrl,
                          textAlignVertical: TextAlignVertical.center,
                          onChanged: _onCustomCollegeChanged,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF0F172A),
                          ),
                          decoration: InputDecoration(
                            hintText: 'Type college name (e.g. Govt Engg College)',
                            hintStyle: GoogleFonts.inter(
                              fontSize: 12.5,
                              color: const Color(0xFF94A3B8),
                            ),
                            isDense: true,
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: Color(0xFFFDBA74),
                                width: 1,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: Color(0xFFFDBA74),
                                width: 1,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: Color(0xFFD45107),
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const Gap(8),
                      SizedBox(
                        height: 40,
                        child: ElevatedButton.icon(
                          onPressed: _isSavingCollege
                              ? null
                              : _confirmAndAddCustomCollege,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD45107),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: _isSavingCollege
                              ? const SpinKitThreeBounce(
                                  color: Colors.white,
                                  size: 14,
                                )
                              : const Icon(Icons.check_rounded, size: 16),
                          label: Text(
                            'Add',
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ] else ...[
          // Other Background / Category Selection
          Text(
            'Select Background / Category',
            style: GoogleFonts.inter(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF334155),
            ),
          ),
          const Gap(6),
          AcadenoDropdown<String>(
            hint: 'Select Other Category',
            value: _selectedOtherCategory,
            items: _otherCategories
                .map(
                  (cat) => AcadenoDropdownItem<String>(
                    value: cat,
                    label: cat,
                    icon: _getOtherCategoryIcon(cat),
                  ),
                )
                .toList(),
            onChanged: (val) {
              if (val != null) {
                _onOtherCategoryChanged(val);
              }
            },
            fillColor: const Color(0xFFF8FAFC),
            borderColor: const Color(0xFFE2E8F0),
            borderRadius: 12.0,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
          ),
        ],

        const Gap(12),

        // 4. Fully editable text field for details
        Text(
          _isOtherCategory ? 'BACKGROUND / DETAILS (EDITABLE)' : widget.label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
            color: const Color(0xFF94A3B8),
          ),
        ),
        const Gap(6),
        TextFormField(
          controller: widget.controller,
          textAlignVertical: TextAlignVertical.center,
          onChanged: (v) {
            setState(() {
              _determineSelectionFromText(v);
            });
            widget.onChanged?.call(v);
          },
          style: GoogleFonts.inter(
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF0F172A),
          ),
          decoration: InputDecoration(
            hintText: _isOtherCategory
                ? (_selectedOtherCategory ?? 'Career Switching · Working Professional')
                : 'NIT Calicut · CSE · 3rd yr',
            hintStyle: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF94A3B8),
            ),
            isDense: true,
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFFE2E8F0),
                width: 1,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFFE2E8F0),
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFFD45107),
                width: 1.5,
              ),
            ),
          ),
          validator:
              widget.validator ??
              (v) => (v == null || v.trim().isEmpty)
                  ? (_isOtherCategory ? 'Details required' : 'College details required')
                  : null,
        ),
      ],
    );
  }
}
