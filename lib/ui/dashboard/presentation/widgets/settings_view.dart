import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gap/gap.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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

  bool _obscureEmailPass = true;
  bool _obscureCurrentPass = true;
  bool _obscureNewPass = true;
  bool _obscureConfirmPass = true;

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
  // Tab 1: Account & Security
  // ---------------------------------------------------------------------------
  Widget _buildAccountAndSecurityTab() {
    final isMobile = MediaQuery.of(context).size.width < 640;
    return Padding(
      padding: const EdgeInsets.only(bottom: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Profile Name Card
          _buildCard(
            title: 'Admin Profile',
            subtitle:
                'Change your public display name shown across audit logs and lead assignments.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Display Name',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: _text,
                  ),
                ),
                const Gap(6),
                if (isMobile) ...[
                  SizedBox(
                    height: 48,
                    child: TextField(
                      controller: _nameController,
                      textAlignVertical: TextAlignVertical.center,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(
                          Icons.person_outline,
                          size: 18,
                          color: _muted,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: _border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: _border),
                        ),
                      ),
                    ),
                  ),
                  const Gap(12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isSavingName ? null : _updateDisplayName,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 48),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isSavingName
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Save Name',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ] else ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: TextField(
                            controller: _nameController,
                            textAlignVertical: TextAlignVertical.center,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(
                                Icons.person_outline,
                                size: 18,
                                color: _muted,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: _border),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: _border),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const Gap(12),
                      SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _isSavingName ? null : _updateDisplayName,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primary,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(0, 48),
                            padding: const EdgeInsets.symmetric(horizontal: 22),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: _isSavingName
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Save Name',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          const Gap(16),

          // 2. Email Address Card
          _buildCard(
            title: 'Login Email Address',
            subtitle: 'Requires re-authenticating with your current password.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'New Email Address',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: _text,
                  ),
                ),
                const Gap(6),
                TextField(
                  controller: _emailController,
                  textAlignVertical: TextAlignVertical.center,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(
                      Icons.email_outlined,
                      size: 18,
                      color: _muted,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: _border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: _border),
                    ),
                  ),
                ),
                const Gap(12),
                const Text(
                  'Current Password (for authorization)',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: _text,
                  ),
                ),
                const Gap(6),
                TextField(
                  controller: _emailPasswordController,
                  obscureText: _obscureEmailPass,
                  textAlignVertical: TextAlignVertical.center,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(
                      Icons.lock_outline,
                      size: 18,
                      color: _muted,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureEmailPass
                            ? Icons.visibility_off
                            : Icons.visibility,
                        size: 18,
                        color: _muted,
                      ),
                      onPressed: () => setState(
                        () => _obscureEmailPass = !_obscureEmailPass,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: _border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: _border),
                    ),
                  ),
                ),
                const Gap(16),
                SizedBox(
                  width: isMobile ? double.infinity : null,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isSavingEmail ? null : _updateEmail,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isSavingEmail
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Update Email',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),

          const Gap(16),

          // 3. Password Card
          _buildCard(
            title: 'Change Password',
            subtitle:
                'Ensure your account has a strong password of at least 6 characters.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Current Password',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: _text,
                  ),
                ),
                const Gap(6),
                TextField(
                  controller: _currentPasswordController,
                  obscureText: _obscureCurrentPass,
                  textAlignVertical: TextAlignVertical.center,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(
                      Icons.lock_outline,
                      size: 18,
                      color: _muted,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureCurrentPass
                            ? Icons.visibility_off
                            : Icons.visibility,
                        size: 18,
                        color: _muted,
                      ),
                      onPressed: () => setState(
                        () => _obscureCurrentPass = !_obscureCurrentPass,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: _border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: _border),
                    ),
                  ),
                ),
                const Gap(12),
                if (isMobile) ...[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'New Password',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: _text,
                        ),
                      ),
                      const Gap(6),
                      TextField(
                        controller: _newPasswordController,
                        obscureText: _obscureNewPass,
                        textAlignVertical: TextAlignVertical.center,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(
                            Icons.lock_outline,
                            size: 18,
                            color: _muted,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureNewPass
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              size: 18,
                              color: _muted,
                            ),
                            onPressed: () => setState(
                              () => _obscureNewPass = !_obscureNewPass,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: _border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: _border),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Gap(12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Confirm New Password',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: _text,
                        ),
                      ),
                      const Gap(6),
                      TextField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirmPass,
                        textAlignVertical: TextAlignVertical.center,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(
                            Icons.lock_outline,
                            size: 18,
                            color: _muted,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirmPass
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              size: 18,
                              color: _muted,
                            ),
                            onPressed: () => setState(
                              () => _obscureConfirmPass = !_obscureConfirmPass,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: _border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: _border),
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'New Password',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: _text,
                              ),
                            ),
                            const Gap(6),
                            TextField(
                              controller: _newPasswordController,
                              obscureText: _obscureNewPass,
                              textAlignVertical: TextAlignVertical.center,
                              decoration: InputDecoration(
                                prefixIcon: const Icon(
                                  Icons.lock_outline,
                                  size: 18,
                                  color: _muted,
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureNewPass
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    size: 18,
                                    color: _muted,
                                  ),
                                  onPressed: () => setState(
                                    () => _obscureNewPass = !_obscureNewPass,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: _border),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: _border),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Gap(12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Confirm New Password',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: _text,
                              ),
                            ),
                            const Gap(6),
                            TextField(
                              controller: _confirmPasswordController,
                              obscureText: _obscureConfirmPass,
                              textAlignVertical: TextAlignVertical.center,
                              decoration: InputDecoration(
                                prefixIcon: const Icon(
                                  Icons.lock_outline,
                                  size: 18,
                                  color: _muted,
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureConfirmPass
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    size: 18,
                                    color: _muted,
                                  ),
                                  onPressed: () => setState(
                                    () => _obscureConfirmPass =
                                        !_obscureConfirmPass,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: _border),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: _border),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
                const Gap(16),
                SizedBox(
                  width: isMobile ? double.infinity : null,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isSavingPassword ? null : _updatePassword,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isSavingPassword
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Update Password',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
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
