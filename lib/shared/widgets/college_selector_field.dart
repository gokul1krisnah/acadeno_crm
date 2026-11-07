import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'acadeno_dropdown.dart';

/// A dynamic college selection and editable input component.
/// Provides a curved dropdown of known colleges + "+ Add Other College".
/// Selecting a college auto-populates the editable [College · Branch · Year] text field.
/// Any newly entered college is automatically persisted to Firestore 'colleges' collection.
class CollegeSelectorField extends StatefulWidget {
  final TextEditingController controller;
  final List<String>? additionalColleges;
  final String label;
  final String? Function(String?)? validator;

  const CollegeSelectorField({
    super.key,
    required this.controller,
    this.additionalColleges,
    this.label = 'College · Branch · Year',
    this.validator,
  });

  /// Persists a new college name into the Firestore 'colleges' collection so it
  /// automatically appears in the dropdown across the entire CRM system.
  static Future<void> saveCollegeIfNew(String rawText) async {
    final clean = rawText.split(RegExp(r'[·\-]')).first.trim();
    if (clean.isEmpty || clean.length < 2) return;
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

  final Set<String> _collegeList = {};
  String? _selectedCollege;
  bool _isOther = false;
  final TextEditingController _customCollegeCtrl = TextEditingController();
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _collegeSub;

  @override
  void initState() {
    super.initState();
    _collegeList.addAll(_defaultColleges);
    if (widget.additionalColleges != null) {
      _collegeList.addAll(
        widget.additionalColleges!
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty),
      );
    }

    _determineSelectionFromText(widget.controller.text);

    // Stream real-time colleges from Firestore with graceful fallback handling
    _collegeSub = FirebaseFirestore.instance
        .collection('colleges')
        .snapshots()
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
            // Fall back gracefully to bundled college list if offline or permission denied
            debugPrint('Colleges stream notice: $error');
          },
        );
  }

  @override
  void dispose() {
    _collegeSub?.cancel();
    _customCollegeCtrl.dispose();
    super.dispose();
  }

  void _determineSelectionFromText(String text) {
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
      _selectedCollege = _otherValue;
      _isOther = true;
      _customCollegeCtrl.text = collegePart;
    }
  }

  void _onDropdownChanged(String? val) {
    if (val == null) return;
    setState(() {
      _selectedCollege = val;
      if (val == _otherValue) {
        _isOther = true;
        final parts = widget.controller.text.split('·');
        final branchYear = parts.length > 1
            ? ' ·${parts.sublist(1).join('·')}'
            : ' · Branch · Year';
        _customCollegeCtrl.text = '';
        widget.controller.text = branchYear.trim();
      } else {
        _isOther = false;
        final parts = widget.controller.text.split('·');
        final branchYear = parts.length > 1
            ? ' ·${parts.sublist(1).join('·')}'
            : ' · Branch · Year';
        widget.controller.text = '$val$branchYear';
      }
    });
  }

  void _onCustomCollegeChanged(String text) {
    final clean = text.trim();
    final parts = widget.controller.text.split('·');
    final branchYear = parts.length > 1
        ? ' ·${parts.sublist(1).join('·')}'
        : ' · Branch · Year';
    widget.controller.text = clean.isNotEmpty
        ? '$clean$branchYear'
        : branchYear.trim();
  }

  @override
  Widget build(BuildContext context) {
    final sortedColleges = _collegeList.toList()..sort();

    final dropdownItems = [
      ...sortedColleges.map(
        (c) => AcadenoDropdownItem<String>(value: c, label: c),
      ),
      const AcadenoDropdownItem<String>(
        value: _otherValue,
        label: '+ Other (Type new college...)',
        icon: Icon(
          Icons.add_circle_outline,
          size: 16,
          color: Color(0xFF4338CA),
        ),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Curved Dropdown
        AcadenoDropdown<String>(
          label: 'College Selection',
          hint: 'Select or choose Other',
          value:
              (_selectedCollege != null &&
                  dropdownItems.any((i) => i.value == _selectedCollege))
              ? _selectedCollege
              : null,
          items: dropdownItems,
          onChanged: _onDropdownChanged,
          borderRadius: 14.0,
        ),

        // 2. Extra field if Other is selected
        if (_isOther) ...[
          const SizedBox(height: 10),
          TextFormField(
            controller: _customCollegeCtrl,
            onChanged: _onCustomCollegeChanged,
            decoration: InputDecoration(
              labelText: 'New College Name *',
              hintText: 'e.g. Malabar College of Engineering',
              isDense: true,
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              prefixIcon: const Icon(
                Icons.school_outlined,
                size: 18,
                color: Color(0xFF4338CA),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: Color(0xFF4338CA),
                  width: 1.5,
                ),
              ),
            ),
          ),
        ],

        const SizedBox(height: 10),

        // 3. Fully editable text field for [College · Branch · Year]
        TextFormField(
          controller: widget.controller,
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: 'College · Branch · Year',
            isDense: true,
            filled: true,
            fillColor: Colors.white,
            prefixIcon: const Icon(
              Icons.edit_note_rounded,
              size: 20,
              color: Color(0xFF6B7280),
            ),
            helperText:
                'You can freely edit or fine-tune college, branch and year here.',
            helperStyle: const TextStyle(
              fontSize: 11,
              color: Color(0xFF94A3B8),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: Color(0xFF4338CA),
                width: 1.5,
              ),
            ),
          ),
          validator:
              widget.validator ??
              (v) => (v == null || v.trim().isEmpty)
                  ? 'College details required'
                  : null,
        ),
      ],
    );
  }
}
