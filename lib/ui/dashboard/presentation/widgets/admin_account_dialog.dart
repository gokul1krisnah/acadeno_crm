import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gap/gap.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:acadeno_crm/shared/snackbar_alerts/snack_alert.dart';

/// Opens the Admin Account Management & Security Dialog.
void showAdminAccountDialog(
  BuildContext context,
  Map<String, dynamic> userDocData,
) {
  showDialog(
    context: context,
    builder: (ctx) => AdminAccountDialog(userDocData: userDocData),
  );
}

class AdminAccountDialog extends StatefulWidget {
  final Map<String, dynamic> userDocData;

  const AdminAccountDialog({super.key, required this.userDocData});

  @override
  State<AdminAccountDialog> createState() => _AdminAccountDialogState();
}

class _AdminAccountDialogState extends State<AdminAccountDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Edit Name
  late TextEditingController _nameController;

  // Change Email
  final _emailController = TextEditingController();
  final _emailPasswordController = TextEditingController();

  // Change Password
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

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    final currentUser = _auth.currentUser;
    final initialName =
        (widget.userDocData['name'] ?? currentUser?.displayName ?? '')
            .toString()
            .trim();
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

  // --- 1. SAVE DISPLAY NAME ---
  Future<void> _updateDisplayName() async {
    final newName = _nameController.text.trim();
    if (newName.isEmpty) {
      SnackBarAlert.showToast(
        context: context,
        message: 'Please enter a valid name',
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
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        if (mounted) {
          SnackBarAlert.showToast(
            context: context,
            message: 'Admin name updated successfully',
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

  // --- 2. UPDATE EMAIL / GMAIL ---
  Future<void> _updateEmail() async {
    final newEmail = _emailController.text.trim();
    final password = _emailPasswordController.text;

    if (newEmail.isEmpty || !newEmail.contains('@')) {
      SnackBarAlert.showToast(
        context: context,
        message: 'Please enter a valid email address',
        isWarning: true,
      );
      return;
    }
    if (password.isEmpty) {
      SnackBarAlert.showToast(
        context: context,
        message: 'Current password required to verify identity',
        isWarning: true,
      );
      return;
    }

    setState(() => _isSavingEmail = true);
    try {
      final user = _auth.currentUser;
      if (user == null || user.email == null) {
        throw Exception('User session not active');
      }

      // Re-authenticate
      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      await user.reauthenticateWithCredential(cred);

      // Securely update email in Firebase Auth (sends verification email to new address)
      await user.verifyBeforeUpdateEmail(newEmail);

      // Sync Firestore profile
      await _firestore.collection('users').doc(user.uid).set({
        'email': newEmail,
        'role': 'admin',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _emailPasswordController.clear();
      if (mounted) {
        SnackBarAlert.showToast(
          context: context,
          message:
              'Verification link sent to $newEmail. Please verify to complete.',
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        String msg = e.message ?? 'Failed to update email';
        if (e.code == 'wrong-password') {
          msg = 'Incorrect current password';
        }
        if (e.code == 'email-already-in-use') {
          msg = 'This email is already in use by another account';
        }
        SnackBarAlert.showToast(
          context: context,
          message: msg,
          isWarning: true,
        );
      }
    } catch (e) {
      if (mounted) {
        SnackBarAlert.showToast(
          context: context,
          message: 'Error: $e',
          isWarning: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingEmail = false);
    }
  }

  // --- 3. CHANGE PASSWORD ---
  Future<void> _updatePassword() async {
    final currentPass = _currentPasswordController.text;
    final newPass = _newPasswordController.text;
    final confirmPass = _confirmPasswordController.text;

    if (currentPass.isEmpty) {
      SnackBarAlert.showToast(
        context: context,
        message: 'Please enter current password',
        isWarning: true,
      );
      return;
    }
    if (newPass.length < 6) {
      SnackBarAlert.showToast(
        context: context,
        message: 'New password must be at least 6 characters',
        isWarning: true,
      );
      return;
    }
    if (newPass != confirmPass) {
      SnackBarAlert.showToast(
        context: context,
        message: 'New passwords do not match',
        isWarning: true,
      );
      return;
    }

    setState(() => _isSavingPassword = true);
    try {
      final user = _auth.currentUser;
      if (user == null || user.email == null) {
        throw Exception('User session not active');
      }

      // Re-authenticate
      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPass,
      );
      await user.reauthenticateWithCredential(cred);

      // Update password
      await user.updatePassword(newPass);

      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();

      if (mounted) {
        SnackBarAlert.showToast(
          context: context,
          message: 'Admin password updated successfully',
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        String msg = e.message ?? 'Failed to update password';
        if (e.code == 'wrong-password') msg = 'Current password is incorrect';
        SnackBarAlert.showToast(
          context: context,
          message: msg,
          isWarning: true,
        );
      }
    } catch (e) {
      if (mounted) {
        SnackBarAlert.showToast(
          context: context,
          message: 'Error: $e',
          isWarning: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingPassword = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFFEF8144);
    const border = Color(0xFFE2E8F0);
    const textDark = Color(0xFF0F172A);
    const textMuted = Color(0xFF64748B);

    final currentUser = _auth.currentUser;
    final currentEmail = currentUser?.email ?? 'admin@acadeno.com';
    final currentName = _nameController.text;

    return Dialog(
      backgroundColor: const Color(0xFFFFFFFF),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.admin_panel_settings_rounded,
                      color: primary,
                      size: 24,
                    ),
                  ),
                  const Gap(12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Admin Account & Security',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: textDark,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          'Manage your Admin profile, login Gmail & password',
                          style: TextStyle(fontSize: 12, color: textMuted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: textMuted),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Gap(20),

              // Active Admin Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: border),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: primary,
                      child: Text(
                        currentName.isNotEmpty
                            ? currentName[0].toUpperCase()
                            : 'A',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const Gap(12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                currentName,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: textDark,
                                ),
                              ),
                              const Gap(8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'Admin',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF16A34A),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Gap(2),
                          Text(
                            currentEmail,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Gap(20),

              // Tab Bar
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0F000000),
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  labelColor: primary,
                  unselectedLabelColor: textMuted,
                  labelStyle: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                  tabs: const [
                    Tab(text: 'Change Gmail'),
                    Tab(text: 'Change Password'),
                    Tab(text: 'Edit Profile'),
                  ],
                ),
              ),
              const Gap(16),

              // Tab Bar Content
              SizedBox(
                height: 260,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // TAB 1: Change Gmail
                    _buildChangeEmailTab(border, primary, textMuted),

                    // TAB 2: Change Password
                    _buildChangePasswordTab(border, primary, textMuted),

                    // TAB 3: Edit Profile
                    _buildEditProfileTab(border, primary, textMuted),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- WIDGET: CHANGE GMAIL TAB ---
  Widget _buildChangeEmailTab(Color border, Color primary, Color textMuted) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'New Admin Gmail / Email',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
          ),
          const Gap(6),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              hintText: 'e.g. admin@gmail.com',
              prefixIcon: const Icon(Icons.email_outlined, size: 18),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: border),
              ),
            ),
          ),
          const Gap(12),
          const Text(
            'Current Password (to verify changes)',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
          ),
          const Gap(6),
          TextField(
            controller: _emailPasswordController,
            obscureText: _obscureEmailPass,
            decoration: InputDecoration(
              hintText: 'Enter current password',
              prefixIcon: const Icon(Icons.lock_outline, size: 18),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureEmailPass ? Icons.visibility_off : Icons.visibility,
                  size: 18,
                ),
                onPressed: () =>
                    setState(() => _obscureEmailPass = !_obscureEmailPass),
              ),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: border),
              ),
            ),
          ),
          const Gap(18),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              onPressed: _isSavingEmail ? null : _updateEmail,
              child: _isSavingEmail
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Update Admin Email',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET: CHANGE PASSWORD TAB ---
  Widget _buildChangePasswordTab(Color border, Color primary, Color textMuted) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _currentPasswordController,
            obscureText: _obscureCurrentPass,
            decoration: InputDecoration(
              labelText: 'Current Password',
              prefixIcon: const Icon(Icons.lock_outline, size: 18),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureCurrentPass ? Icons.visibility_off : Icons.visibility,
                  size: 18,
                ),
                onPressed: () =>
                    setState(() => _obscureCurrentPass = !_obscureCurrentPass),
              ),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: border),
              ),
            ),
          ),
          const Gap(10),
          TextField(
            controller: _newPasswordController,
            obscureText: _obscureNewPass,
            decoration: InputDecoration(
              labelText: 'New Password (min 6 characters)',
              prefixIcon: const Icon(Icons.key_rounded, size: 18),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureNewPass ? Icons.visibility_off : Icons.visibility,
                  size: 18,
                ),
                onPressed: () =>
                    setState(() => _obscureNewPass = !_obscureNewPass),
              ),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: border),
              ),
            ),
          ),
          const Gap(10),
          TextField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirmPass,
            decoration: InputDecoration(
              labelText: 'Confirm New Password',
              prefixIcon: const Icon(Icons.key_rounded, size: 18),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmPass ? Icons.visibility_off : Icons.visibility,
                  size: 18,
                ),
                onPressed: () =>
                    setState(() => _obscureConfirmPass = !_obscureConfirmPass),
              ),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: border),
              ),
            ),
          ),
          const Gap(14),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              onPressed: _isSavingPassword ? null : _updatePassword,
              child: _isSavingPassword
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Update Password',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET: EDIT PROFILE TAB ---
  Widget _buildEditProfileTab(Color border, Color primary, Color textMuted) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Admin Full Name',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
          ),
          const Gap(6),
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              hintText: 'Enter Admin Name',
              prefixIcon: const Icon(Icons.person_outline, size: 18),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: border),
              ),
            ),
          ),
          const Gap(12),
          const Text(
            'Assigned Role',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
          ),
          const Gap(6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: border),
            ),
            child: const Row(
              children: [
                Icon(Icons.shield_outlined, size: 18, color: Color(0xFF16A34A)),
                Gap(8),
                Text(
                  'Admin (Super Administrator)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF16A34A),
                  ),
                ),
              ],
            ),
          ),
          const Gap(20),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              onPressed: _isSavingName ? null : _updateDisplayName,
              child: _isSavingName
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Save Admin Profile',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
