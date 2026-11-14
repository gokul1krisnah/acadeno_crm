import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gap/gap.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:acadeno_crm/shared/snackbar_alerts/snack_alert.dart';
import 'package:acadeno_crm/shared/widgets/acadeno_dropdown.dart';

const _primary = Color(0xFFEF8144);
const _border = Color(0xFFE5E7EB);
const _muted = Color(0xFF6B7280);
const _text = Color(0xFF111827);

class SettingsView extends StatefulWidget {
  final VoidCallback? onLogout;

  const SettingsView({super.key, this.onLogout});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Account editing controllers
  late TextEditingController _nameController;
  final _emailController = TextEditingController();
  final _emailPasswordController = TextEditingController();

  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isSavingName = false;
  bool _isSavingEmail = false;
  bool _isSavingPassword = false;

  bool _isResettingData = false;
  String _resetProgressStatus = '';

  // Organization settings
  String _defaultCallsTarget = '50';
  String _overdueEscalationHours = '24';
  bool _autoAssignWalkIns = true;
  bool _enableBiometricLock = true;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging && mounted) {
        setState(() {});
      }
    });

    final currentUser = _auth.currentUser;
    final initialName = (currentUser?.displayName ?? '').trim();
    _nameController = TextEditingController(
      text: initialName.isNotEmpty ? initialName : 'Admin',
    );
    _emailController.text = currentUser?.email ?? '';
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _emailPasswordController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _updateDisplayName() async {
    final newName = _nameController.text.trim();
    if (newName.isEmpty) {
      SnackBarAlert.showToast(
        context: context,
        message: 'Please enter a valid display name.',
        isWarning: true,
      );
      return;
    }

    setState(() => _isSavingName = true);
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await user.updateDisplayName(newName);
        await _firestore.collection('users').doc(user.uid).set({
          'name': newName,
          'role': 'admin',
          if (user.email != null) 'email': user.email,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        if (mounted) {
          SnackBarAlert.showToast(
            context: context,
            message: 'Admin name updated successfully.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        SnackBarAlert.showToast(
          context: context,
          message: 'Failed to update name: $e',
          isWarning: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingName = false);
    }
  }

  Future<void> _updateEmail() async {
    final newEmail = _emailController.text.trim();
    final password = _emailPasswordController.text.trim();

    if (newEmail.isEmpty || !newEmail.contains('@')) {
      SnackBarAlert.showToast(
        context: context,
        message: 'Please enter a valid email address.',
        isWarning: true,
      );
      return;
    }
    if (password.isEmpty) {
      SnackBarAlert.showToast(
        context: context,
        message: 'Enter your current password to confirm email change.',
        isWarning: true,
      );
      return;
    }

    setState(() => _isSavingEmail = true);
    try {
      final user = _auth.currentUser;
      if (user != null && user.email != null) {
        final cred = EmailAuthProvider.credential(
          email: user.email!,
          password: password,
        );
        await user.reauthenticateWithCredential(cred);
        await user.verifyBeforeUpdateEmail(newEmail);

        await _firestore.collection('users').doc(user.uid).set({
          'email': newEmail,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        _emailPasswordController.clear();
        if (mounted) {
          SnackBarAlert.showToast(
            context: context,
            message: 'Verification link sent to $newEmail. Click to complete.',
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        SnackBarAlert.showToast(
          context: context,
          message: e.message ?? 'Failed to update email.',
          isWarning: true,
        );
      }
    } catch (e) {
      if (mounted) {
        SnackBarAlert.showToast(
          context: context,
          message: 'Error updating email: $e',
          isWarning: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingEmail = false);
    }
  }

  Future<void> _updatePassword() async {
    final currentPass = _currentPasswordController.text.trim();
    final newPass = _newPasswordController.text.trim();
    final confirmPass = _confirmPasswordController.text.trim();

    if (currentPass.isEmpty) {
      SnackBarAlert.showToast(
        context: context,
        message: 'Please enter your current password.',
        isWarning: true,
      );
      return;
    }
    if (newPass.length < 6) {
      SnackBarAlert.showToast(
        context: context,
        message: 'New password must be at least 6 characters.',
        isWarning: true,
      );
      return;
    }
    if (newPass != confirmPass) {
      SnackBarAlert.showToast(
        context: context,
        message: 'New passwords do not match.',
        isWarning: true,
      );
      return;
    }

    setState(() => _isSavingPassword = true);
    try {
      final user = _auth.currentUser;
      if (user != null && user.email != null) {
        final cred = EmailAuthProvider.credential(
          email: user.email!,
          password: currentPass,
        );
        await user.reauthenticateWithCredential(cred);
        await user.updatePassword(newPass);

        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();

        if (mounted) {
          SnackBarAlert.showToast(
            context: context,
            message: 'Password changed successfully.',
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        SnackBarAlert.showToast(
          context: context,
          message: e.message ?? 'Password update failed.',
          isWarning: true,
        );
      }
    } catch (e) {
      if (mounted) {
        SnackBarAlert.showToast(
          context: context,
          message: 'Error changing password: $e',
          isWarning: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingPassword = false);
    }
  }

  Future<void> _confirmAndResetCrmData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: const [
              Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFFDC2626),
                size: 26,
              ),
              Gap(10),
              Expanded(
                child: Text(
                  'Reset CRM Database?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'This will permanently delete all operational data:',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF374151),
                ),
              ),
              Gap(8),
              Text(
                '• All Leads & student records\n• All Campaigns & source events\n• All Follow-ups & assignments\n• All Call logs & duration records\n• All College visits\n• Phone index & in-app alerts',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: Color(0xFF4B5563),
                ),
              ),
              Gap(14),
              Text(
                '🔒 All Admin & User accounts will remain 100% untouched.',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF059669),
                ),
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text(
                'Yes, Reset CRM Data',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _isResettingData = true;
      _resetProgressStatus = 'Initializing reset...';
    });

    try {
      final collectionsToClear = [
        {'name': 'leads', 'label': 'Leads'},
        {'name': 'campaigns', 'label': 'Campaigns'},
        {'name': 'lead_assignments', 'label': 'Follow-ups & Assignments'},
        {'name': 'assignments', 'label': 'Staff Assignments'},
        {'name': 'college_visits', 'label': 'College Visits'},
        {'name': 'call_logs', 'label': 'Call Logs'},
        {'name': 'lead_phones', 'label': 'Phone Index'},
        {'name': 'alerts', 'label': 'Alerts'},
        {'name': 'notification_queue', 'label': 'Notification Queue'},
        {'name': 'colleges', 'label': 'Colleges'},
      ];

      int totalDeleted = 0;

      for (final col in collectionsToClear) {
        final colName = col['name']!;
        final colLabel = col['label']!;
        if (!mounted) break;
        setState(() => _resetProgressStatus = 'Clearing $colLabel...');

        try {
          final snapshot = await _firestore.collection(colName).get();
          final docs = snapshot.docs;
          if (docs.isEmpty) continue;

          for (var i = 0; i < docs.length; i += 400) {
            final batch = _firestore.batch();
            final end = (i + 400 < docs.length) ? i + 400 : docs.length;
            final chunk = docs.sublist(i, end);
            for (final doc in chunk) {
              batch.delete(doc.reference);
            }
            await batch.commit();
            totalDeleted += chunk.length;
          }
        } catch (e) {
          debugPrint('Notice clearing $colName: $e');
        }
      }

      if (mounted) {
        SnackBarAlert.showToast(
          context: context,
          message: 'CRM Database successfully reset ($totalDeleted records removed). Fresh CRM ready!',
        );
      }
    } catch (e) {
      if (mounted) {
        SnackBarAlert.showToast(
          context: context,
          message: 'Error during CRM data reset: $e',
          isWarning: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isResettingData = false;
          _resetProgressStatus = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Page Header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Settings',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: _text,
                ),
              ),
              const Gap(4),
              const Text(
                'Manage administrator credentials, security policies, and organizational configurations.',
                style: TextStyle(fontSize: 13, color: _muted),
              ),
              const Gap(18),

              // Tab Selector
              Container(
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: _border)),
                ),
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  padding: EdgeInsets.zero,
                  labelPadding: const EdgeInsets.only(right: 28),
                  indicatorSize: TabBarIndicatorSize.label,
                  overlayColor: WidgetStateProperty.all(Colors.transparent),
                  splashFactory: NoSplash.splashFactory,
                  mouseCursor: SystemMouseCursors.click,
                  onTap: (_) => setState(() {}),
                  labelColor: _primary,
                  unselectedLabelColor: _muted,
                  indicatorColor: _primary,
                  indicatorWeight: 2.5,
                  labelStyle: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                  ),
                  tabs: const [
                    Tab(
                      icon: Icon(Icons.shield_outlined, size: 18),
                      text: 'Account & Security',
                    ),
                    Tab(
                      icon: Icon(Icons.business_outlined, size: 18),
                      text: 'Organization & CRM',
                    ),
                    Tab(
                      icon: Icon(Icons.info_outline_rounded, size: 18),
                      text: 'System & Notifications',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const Gap(16),

        // Active Tab Content
        Builder(
          builder: (context) {
            switch (_tabController.index) {
              case 0:
                return _buildAccountAndSecurityTab();
              case 1:
                return _buildOrganizationTab();
              case 2:
              default:
                return _buildSystemInfoTab();
            }
          },
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 1: Account & Security (Figma Node 1774:888 - MainContainer)
  // ---------------------------------------------------------------------------
  InputDecoration _figmaAccountInputDecoration() {
    return InputDecoration(
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF6B7280), width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF6B7280), width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFEB6625), width: 1.5),
      ),
    );
  }

  Widget _buildFigmaOrangeButton({
    required String label,
    required bool isLoading,
    required VoidCallback onPressed,
    required TextStyle textStyle,
    double? width,
    double? height,
  }) {
    final effectiveHeight = height ?? 43.0;
    final horizontalPad = (width != null && width < 160) ? 14.0 : 24.0;
    return Container(
      width: width,
      height: effectiveHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 1,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFEB6625),
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: Size(width ?? 0, effectiveHeight),
          padding: EdgeInsets.symmetric(horizontal: horizontalPad),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  softWrap: false,
                  textAlign: TextAlign.center,
                  style: textStyle.copyWith(height: 1.2),
                ),
              ),
      ),
    );
  }

  Widget _buildChangeEmailAndProfileCard({
    required bool isNarrowCard,
    required bool matchFixedHeight,
  }) {
    final padH = isNarrowCard ? 20.0 : 32.0;
    final padTop = isNarrowCard ? 24.0 : 31.0;
    final padBottom = isNarrowCard ? 24.0 : 33.0;

    return Container(
      constraints: matchFixedHeight
          ? const BoxConstraints(minHeight: 542)
          : null,
      padding: EdgeInsets.fromLTRB(padH, padTop, padH, padBottom),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1774:1150 - Heading 1: Admin Profile
          const Text(
            'Admin Profile',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Color(0xFF19233C),
              letterSpacing: -0.5,
              height: 27.5 / 20,
            ),
          ),
          const Gap(6.5),
          // 1774:890 - Subtitle
          const Text(
            'Change your public display name shown across audit logs and lead assignments',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Color(0xFF475569),
              height: 22.75 / 14,
            ),
          ),
          const Gap(15),
          // 1774:896 - Display Name + Save Name
          const Text(
            'Display Name',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Color(0xFF19233C),
              height: 21 / 14,
            ),
          ),
          const Gap(8),
          if (isNarrowCard) ...[
            SizedBox(
              height: 46,
              child: TextField(
                controller: _nameController,
                textAlignVertical: TextAlignVertical.center,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF19233C),
                ),
                decoration: _figmaAccountInputDecoration(),
              ),
            ),
            const Gap(10),
            _buildFigmaOrangeButton(
              label: 'Save Name',
              isLoading: _isSavingName,
              onPressed: _updateDisplayName,
              width: double.infinity,
              height: 43,
              textStyle: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                height: 22.5 / 15,
              ),
            ),
          ] else
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: TextField(
                      controller: _nameController,
                      textAlignVertical: TextAlignVertical.center,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF19233C),
                      ),
                      decoration: _figmaAccountInputDecoration(),
                    ),
                  ),
                ),
                const Gap(7),
                _buildFigmaOrangeButton(
                  label: 'Save Name',
                  isLoading: _isSavingName,
                  onPressed: _updateDisplayName,
                  width: 132,
                  height: 46,
                  textStyle: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          const Gap(27),

          // 1774:1149 - Change Email Title & Subtitle
          const Text(
            'Change Email ',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Color(0xFF19233C),
              letterSpacing: -0.5,
              height: 27.5 / 20,
            ),
          ),
          const Gap(8),
          const Text(
            'Requires re-authenticating with your current password',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Color(0xFF475569),
              height: 22.75 / 14,
            ),
          ),
          const Gap(15),

          // 1774:895 - Change Email Form
          const Text(
            'New email',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF19233C),
              height: 21 / 14,
            ),
          ),
          const Gap(8),
          SizedBox(
            height: 46,
            child: TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textAlignVertical: TextAlignVertical.center,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Color(0xFF19233C),
              ),
              decoration: _figmaAccountInputDecoration(),
            ),
          ),
          const Gap(20),

          // 1774:900 - Current Password(for authorization)
          const Text(
            'Current Password(for authorization)',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF19233C),
              height: 21 / 14,
            ),
          ),
          const Gap(8),
          SizedBox(
            height: 46,
            child: TextField(
              controller: _emailPasswordController,
              obscureText: true,
              textAlignVertical: TextAlignVertical.center,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Color(0xFF19233C),
              ),
              decoration: _figmaAccountInputDecoration(),
            ),
          ),
          const Gap(28),

          // 1774:904 - Submit Button (Update email)
          _buildFigmaOrangeButton(
            label: 'Update email',
            isLoading: _isSavingEmail,
            onPressed: _updateEmail,
            width: isNarrowCard ? double.infinity : null,
            height: 43,
            textStyle: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              height: 22.5 / 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChangePasswordCard({
    required bool isNarrowCard,
    required bool matchFixedHeight,
  }) {
    final padH = isNarrowCard ? 20.0 : 33.0;
    final padTop = isNarrowCard ? 24.0 : 32.0;
    final padBottom = isNarrowCard ? 24.0 : 33.0;

    return Container(
      constraints: matchFixedHeight
          ? const BoxConstraints(minHeight: 542)
          : null,
      padding: EdgeInsets.fromLTRB(padH, padTop, padH, padBottom),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1774:908 - Title & Subtitle
          const Text(
            'Change password',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 20,
              fontWeight: FontWeight.w400,
              color: Color(0xFF19233C),
              letterSpacing: -0.5,
              height: 27.5 / 20,
            ),
          ),
          const Gap(8),
          Text(
            'Use at least 8 characters.',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF475569),
              height: 22.75 / 14,
            ),
          ),
          const Gap(24),

          // 1774:914 - Current password
          Text(
            'Current password',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF19233C),
              height: 21 / 14,
            ),
          ),
          const Gap(8),
          SizedBox(
            height: 46,
            child: TextField(
              controller: _currentPasswordController,
              obscureText: true,
              textAlignVertical: TextAlignVertical.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: const Color(0xFF19233C),
              ),
              decoration: _figmaAccountInputDecoration(),
            ),
          ),
          const Gap(27),

          // 1774:918 - New password
          Text(
            'New password',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF19233C),
              height: 21 / 14,
            ),
          ),
          const Gap(8),
          SizedBox(
            height: 50,
            child: TextField(
              controller: _newPasswordController,
              obscureText: true,
              textAlignVertical: TextAlignVertical.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: const Color(0xFF19233C),
              ),
              decoration: _figmaAccountInputDecoration(),
            ),
          ),
          const Gap(27),

          // 1774:923 - Confirm new password
          Text(
            'Confirm new password',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF19233C),
              height: 21 / 14,
            ),
          ),
          const Gap(8),
          SizedBox(
            height: 46,
            child: TextField(
              controller: _confirmPasswordController,
              obscureText: true,
              textAlignVertical: TextAlignVertical.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: const Color(0xFF19233C),
              ),
              decoration: _figmaAccountInputDecoration(),
            ),
          ),
          const Gap(35),

          // 1774:931 - Submit Button (Update password)
          _buildFigmaOrangeButton(
            label: 'Update password',
            isLoading: _isSavingPassword,
            onPressed: _updatePassword,
            width: isNarrowCard ? double.infinity : null,
            height: 43,
            textStyle: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: Colors.white,
              height: 22.5 / 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountAndSecurityTab() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 40),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktopTwoCol = constraints.maxWidth >= 900;
          final isNarrowCard = constraints.maxWidth < 520;

          if (isDesktopTwoCol) {
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _buildChangeEmailAndProfileCard(
                      isNarrowCard: false,
                      matchFixedHeight: true,
                    ),
                  ),
                  const Gap(28),
                  Expanded(
                    child: _buildChangePasswordCard(
                      isNarrowCard: false,
                      matchFixedHeight: true,
                    ),
                  ),
                ],
              ),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildChangeEmailAndProfileCard(
                isNarrowCard: isNarrowCard,
                matchFixedHeight: false,
              ),
              const Gap(20),
              _buildChangePasswordCard(
                isNarrowCard: isNarrowCard,
                matchFixedHeight: false,
              ),
            ],
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 2: Organization & CRM
  // ---------------------------------------------------------------------------
  Widget _buildOrganizationTab() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCard(
            title: 'Organization Profile',
            subtitle:
                'Company details displayed on exported sheets and student communication.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow(
                  'Organization Name',
                  'Acadeno Research & Innovation Centre',
                ),
                const Divider(height: 24),
                _buildInfoRow('Branch / Center Code', 'ACADENO_KL_CENTRE'),
                const Divider(height: 24),
                _buildInfoRow(
                  'Operating Region',
                  'Kerala, India (IST UTC+05:30)',
                ),
                const Divider(height: 24),
                _buildInfoRow(
                  'Standard Working Hours',
                  '09:00 AM – 06:00 PM (Mon – Sat)',
                ),
              ],
            ),
          ),

          const Gap(16),

          _buildCard(
            title: 'Lead Management & Escalations',
            subtitle:
                'Configure daily workload capacities and automatic escalation triggers.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AcadenoDropdown.strings(
                  label: 'Daily Target Calls per Sales Executive',
                  value: _defaultCallsTarget,
                  items: const ['25', '40', '50', '75', '100'],
                  onChanged: (val) {
                    if (val != null) setState(() => _defaultCallsTarget = val);
                  },
                ),
                const Gap(16),
                AcadenoDropdown.strings(
                  label: 'Overdue Follow-up Escalation Threshold',
                  value: _overdueEscalationHours,
                  items: const ['12', '24', '48', '72'],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _overdueEscalationHours = val);
                    }
                  },
                ),
                const Gap(16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeTrackColor: const Color(0xFF4F46E5),
                  inactiveTrackColor: const Color(0xFFE2E8F0),
                  thumbColor: WidgetStateProperty.all(Colors.white),
                  trackOutlineColor: WidgetStateProperty.all(
                    Colors.transparent,
                  ),
                  title: const Text(
                    'Auto-assign Walk-in Leads to Creator',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: _text,
                    ),
                  ),
                  subtitle: const Text(
                    'When an executive logs a walk-in student, automatically assign them for immediate follow-up.',
                    style: TextStyle(fontSize: 12, color: _muted),
                  ),
                  value: _autoAssignWalkIns,
                  onChanged: (v) => setState(() => _autoAssignWalkIns = v),
                ),
                const Gap(8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeTrackColor: const Color(0xFF4F46E5),
                  inactiveTrackColor: const Color(0xFFE2E8F0),
                  thumbColor: WidgetStateProperty.all(Colors.white),
                  trackOutlineColor: WidgetStateProperty.all(
                    Colors.transparent,
                  ),
                  title: const Text(
                    'Biometric / PIN Screen Lock',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: _text,
                    ),
                  ),
                  subtitle: const Text(
                    'Require device authentication when app is backgrounded for more than 5 minutes.',
                    style: TextStyle(fontSize: 12, color: _muted),
                  ),
                  value: _enableBiometricLock,
                  onChanged: (v) => setState(() => _enableBiometricLock = v),
                ),
              ],
            ),
          ),

          const Gap(16),

          _buildDangerZoneCard(),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 3: System & Notifications
  // ---------------------------------------------------------------------------
  Widget _buildSystemInfoTab() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCard(
            title: 'Push Notifications & Web Workers',
            subtitle:
                'Live delivery channels for background and out-of-app notifications.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatusRow(
                  'Web Service Worker',
                  'firebase-messaging-sw.js active',
                  Icons.check_circle_outline,
                  const Color(0xFF16A34A),
                ),
                const Divider(height: 24),
                _buildStatusRow(
                  'FCM Push Integration',
                  'FCM V1 Cloud Engine Configured',
                  Icons.check_circle_outline,
                  const Color(0xFF16A34A),
                ),
                const Divider(height: 24),
                _buildStatusRow(
                  'Screen Privacy & Capture Protection',
                  'Screenshots Enabled',
                  Icons.verified_user_outlined,
                  _primary,
                ),
                const Divider(height: 24),
                _buildStatusRow(
                  'Offline Storage Engine',
                  'Hive Local Box & Queue',
                  Icons.storage_outlined,
                  _primary,
                ),
              ],
            ),
          ),

          const Gap(16),

          _buildCard(
            title: 'Application Version & Environment',
            subtitle:
                'Build provenance and connected Google Cloud deployment details.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow(
                  'Application Version',
                  '1.0.4+5 (Production Release)',
                ),
                const Divider(height: 24),
                _buildInfoRow('Firebase Project ID', 'acadenocrm-b727a'),
                const Divider(height: 24),
                _buildInfoRow(
                  'Database Engine',
                  'Google Cloud Firestore (Native Multi-region)',
                ),
                const Divider(height: 24),
                _buildInfoRow(
                  'Hosting Destination',
                  'Vercel Static Edge & SPA',
                ),
              ],
            ),
          ),

          const Gap(16),

          _buildDangerZoneCard(),
        ],
      ),
    );
  }

  Widget _buildDangerZoneCard() {
    return _buildCard(
      title: 'Danger Zone · Fresh CRM Reset',
      subtitle:
          'Permanently purge all operational records (leads, campaigns, follow-ups, visits, call logs). Users & Admins remain strictly preserved.',
      borderColor: const Color(0xFFFCA5A5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFECACA)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: Color(0xFFDC2626),
                  size: 20,
                ),
                Gap(10),
                Expanded(
                  child: Text(
                    'Executing this reset will wipe all leads, campaigns, assignments, visits, and phone records in Cloud Firestore. Use this to prepare a clean, fresh CRM. All user accounts and login access remain 100% untouched.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF991B1B),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Gap(16),
          _isResettingData
              ? Row(
                  children: [
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Color(0xFFDC2626),
                      ),
                    ),
                    const Gap(12),
                    Text(
                      _resetProgressStatus,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFDC2626),
                      ),
                    ),
                  ],
                )
              : ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  onPressed: _confirmAndResetCrmData,
                  icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                  label: const Text(
                    'Clear All CRM Data (Keep Users)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------
  Widget _buildCard({
    required String title,
    required String subtitle,
    required Widget child,
    Color? borderColor,
  }) {
    final isMobile = MediaQuery.of(context).size.width < 640;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(isMobile ? 14 : 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor ?? _border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: isMobile ? 15 : 16,
                fontWeight: FontWeight.w700,
                color: _text,
              ),
            ),
            const Gap(3),
            Text(subtitle, style: const TextStyle(fontSize: 12.5, color: _muted)),
            const Gap(16),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    final isMobile = MediaQuery.of(context).size.width < 640;
    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: _muted,
            ),
          ),
          const Gap(4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _text,
            ),
          ),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 220,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: _muted,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _text,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusRow(
    String label,
    String status,
    IconData icon,
    Color color,
  ) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const Gap(10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _text,
                ),
              ),
              Text(
                status,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
