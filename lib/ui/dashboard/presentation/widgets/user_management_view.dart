import 'package:flutter/cupertino.dart';
import 'package:gap/gap.dart';
import 'package:acadeno_crm/shared/widgets/acadeno_dropdown.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/snackbar_alerts/snack_alert.dart';
import '../../application/dashboard_cubit.dart';
import '../../data/model/dashboard_user_model.dart';

class UserManagementView extends StatefulWidget {
  final VoidCallback? onOpenSettings;

  const UserManagementView({super.key, this.onOpenSettings});

  @override
  State<UserManagementView> createState() => _UserManagementViewState();
}

class _UserManagementViewState extends State<UserManagementView> {
  void _navigateToSettings() {
    if (widget.onOpenSettings != null) {
      widget.onOpenSettings!();
    } else {
      try {
        context.read<DashboardCubit>().selectNav(8);
      } catch (_) {}
    }
  }

  String _searchQuery = '';
  String _roleFilter = 'all';
  String _statusFilter = 'all';
  Stream<QuerySnapshot<Map<String, dynamic>>>? _usersStream;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _usersStream ??= context.read<DashboardCubit>().watchAllUsers();
  }

  static const _primaryColor = Color(0xFFEF8144);
  static const _textDark = Color(0xFF0F172A);
  static const _textMuted = Color(0xFF64748B);
  static const _borderColor = Color(0xFFE2E8F0);
  static const _bgLight = Color(0xFFF8FAFC);

  void _confirmResetDevice(
    BuildContext context,
    DashboardCubit cubit,
    DashboardUserModel user,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.phonelink_erase_rounded, color: Color(0xFFD97706)),
            Gap(8),
            Text('Reset Phone Binding', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Text(
          'Reset registered phone for ${user.name}?\n\nThis will remotely sign out their existing phone session and permit them to register a new phone on their next sign-in.',
          style: const TextStyle(fontSize: 13.5, color: Color(0xFF334155)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD97706),
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              cubit.resetUserDevice(user.uid, user.name);
              SnackBarAlert.showToast(
                context: context,
                message:
                    'Phone binding reset for ${user.name}. They may now register a new phone.',
              );
            },
            child: const Text('Approve & Reset Phone'),
          ),
        ],
      ),
    );
  }

  void _confirmForceSignOut(
    BuildContext context,
    DashboardCubit cubit,
    DashboardUserModel user,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Force Sign Out ${user.name}?'),
        content: Text(
          'This will immediately revoke ${user.name}’s active login sessions across all devices.\n\nTheir app will terminate and return to the login screen.',
          style: const TextStyle(fontSize: 13.5, color: Color(0xFF334155)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              cubit.forceSignOutUser(user.uid, user.name);
              SnackBarAlert.showToast(
                context: context,
                message:
                    'Remote sign out sent for ${user.name}. Their session will terminate immediately.',
              );
            },
            icon: const Icon(Icons.logout_rounded, size: 16),
            label: const Text('Force Sign Out'),
          ),
        ],
      ),
    );
  }

  void _confirmResetPassword(
    BuildContext context,
    DashboardCubit cubit,
    DashboardUserModel user,
  ) {
    if (user.email.isEmpty || user.email == '—') {
      SnackBarAlert.showToast(
        context: context,
        message: 'Cannot reset password: user does not have a valid email.',
      );
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.lock_reset_rounded, color: Color(0xFF4F46E5)),
            Gap(8),
            Text(
              'Reset Password',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'Send a password reset link to ${user.email}?\n\n'
          'The user will receive an email allowing them to securely choose a new password.',
          style: const TextStyle(fontSize: 13.5, color: Color(0xFF334155)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              cubit.sendPasswordResetEmail(user.email, userName: user.name);
            },
            child: const Text('Send Reset Email'),
          ),
        ],
      ),
    );
  }

  void _openAddUserDialog({required bool byUid}) {
    final cubit = context.read<DashboardCubit>();
    final formKey = GlobalKey<FormState>();
    final uidCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    String selectedRole = 'hr';
    bool obscurePassword = true;
    bool isSubmitting = false;

    InputDecoration inputDeco(String label, IconData icon, {Widget? suffix}) {
      return InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 13, color: _textMuted),
        prefixIcon: Icon(icon, size: 18, color: _textMuted),
        suffixIcon: suffix,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _primaryColor, width: 1.5),
        ),
        filled: true,
        fillColor: _bgLight,
        isDense: true,
      );
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        final mq = MediaQuery.of(dialogCtx);
        final screenWidth = mq.size.width;
        final screenHeight = mq.size.height;
        final dialogWidth = (screenWidth - 48).clamp(280.0, 460.0);

        return StatefulBuilder(
          builder: (dialogCtx, setDState) => AlertDialog(
            scrollable: true,
            backgroundColor: const Color(0xFFFFFFFF),
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            insetPadding: EdgeInsets.symmetric(
              horizontal:
                  (screenWidth > 520 ? (screenWidth - dialogWidth) / 2 : 16)
                      .clamp(16.0, 500.0)
                      .toDouble(),
              vertical: (screenHeight * 0.04).clamp(12.0, 24.0).toDouble(),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF0FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    byUid ? Icons.key_rounded : Icons.person_add_rounded,
                    color: _primaryColor,
                    size: 20,
                  ),
                ),
                const Gap(12),
                Expanded(
                  child: Text(
                    byUid
                        ? 'Add Existing User by UID'
                        : 'Create New Team Account',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: _textDark,
                    ),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: dialogWidth,
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      byUid
                          ? 'Link a pre-existing Firebase Authentication UID to Firestore with user details and permissions.'
                          : 'Provision login credentials in Firebase Auth and assign role permissions in Firestore.',
                      style: const TextStyle(fontSize: 12.5, color: _textMuted),
                    ),
                    const Gap(16),
                    if (byUid) ...[
                      TextFormField(
                        controller: uidCtrl,
                        decoration: inputDeco(
                          'Firebase Auth UID *',
                          Icons.vpn_key_outlined,
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'UID is required'
                            : null,
                      ),
                      const Gap(12),
                    ],
                    TextFormField(
                      controller: nameCtrl,
                      decoration: inputDeco(
                        'Full Name *',
                        Icons.person_outline_rounded,
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Full name is required'
                          : null,
                    ),
                    const Gap(12),
                    TextFormField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: inputDeco(
                        'Work Email *',
                        Icons.email_outlined,
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Work email is required';
                        }
                        if (!RegExp(r'^\S+@\S+\.\S+$').hasMatch(v.trim())) {
                          return 'Enter a valid email address';
                        }
                        return null;
                      },
                    ),
                    if (!byUid) ...[
                      const Gap(12),
                      TextFormField(
                        controller: passCtrl,
                        obscureText: obscurePassword,
                        decoration: inputDeco(
                          'Temporary Password *',
                          Icons.lock_outline_rounded,
                          suffix: IconButton(
                            icon: Icon(
                              obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              size: 18,
                              color: _textMuted,
                            ),
                            onPressed: () => setDState(
                              () => obscurePassword = !obscurePassword,
                            ),
                          ),
                        ),
                        validator: (v) => (v == null || v.length < 6)
                            ? 'Password must be at least 6 characters'
                            : null,
                      ),
                    ],
                    const Gap(12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedRole,
                      isExpanded: true,
                      dropdownColor: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      decoration: inputDeco(
                        'Role & Access *',
                        Icons.badge_outlined,
                      ),
                      selectedItemBuilder: (context) => const [
                        Text(
                          'Admin',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        Text(
                          'HR & Operation Manager',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ],
                      items: const [
                        DropdownMenuItem(
                          value: 'admin',
                          child: Text(
                            'Admin (Assign Leads, Full Control)',
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'hr',
                          child: Text(
                            'HR & Operation Manager (Actual User)',
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                      onChanged: (v) =>
                          setDState(() => selectedRole = v ?? selectedRole),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(dialogCtx),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: _textMuted),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF8144),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                ),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setDState(() => isSubmitting = true);
                        final ok = await cubit.createUser(
                          CreateUserRequestModel(
                            uid: uidCtrl.text.trim(),
                            name: nameCtrl.text.trim(),
                            email: emailCtrl.text.trim(),
                            password: passCtrl.text,
                            role: selectedRole,
                            byUid: byUid,
                          ),
                        );
                        if (ok) {
                          if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                        } else {
                          setDState(() => isSubmitting = false);
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(byUid ? 'Save User to Database' : 'Create Account'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDeactivateAndReassignDialog(
    DashboardUserModel user,
    List<DashboardUserModel> allUsers,
  ) {
    final activeExecs = allUsers
        .where(
          (u) => u.uid != user.uid && u.isActive && u.name.trim().isNotEmpty,
        )
        .map((u) => u.name)
        .toList();
    final fallbackExecs = activeExecs.isNotEmpty
        ? activeExecs
        : ['Anjali R', 'Rahul M', 'Shilpa K', 'Ajmal P', 'Neethu S'];
    String reassignTarget = fallbackExecs.first;

    showDialog(
      context: context,
      builder: (ctx) {
        final mq = MediaQuery.of(ctx);
        final screenWidth = mq.size.width;
        final screenHeight = mq.size.height;
        final dialogWidth = (screenWidth - 48).clamp(280.0, 460.0);

        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            scrollable: true,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            insetPadding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: (screenHeight * 0.04).clamp(12.0, 24.0).toDouble(),
            ),
            title: Text(
              'Deactivate ${user.name} (RL-4)',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            content: SizedBox(
              width: dialogWidth,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Deactivating a team member revokes access within 1 minute and requires reassigning all open leads and follow-ups so no student inquiry is orphaned.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF475467),
                      height: 1.4,
                    ),
                  ),
                  const Gap(16),
                  const Text(
                    'Reassign open leads & follow-ups to:',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  const Gap(8),
                  DropdownButtonFormField<String>(
                    initialValue: reassignTarget,
                    isExpanded: true,
                    dropdownColor: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFF4338CA),
                          width: 1.5,
                        ),
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                    items: fallbackExecs
                        .map(
                          (e) => DropdownMenuItem(
                            value: e,
                            child: Text(e, overflow: TextOverflow.ellipsis),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setDialogState(() => reassignTarget = v);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFB42318),
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  context.read<DashboardCubit>().updateUserActive(
                    user.uid,
                    false,
                    userName: user.name,
                    reassignToExecutive: reassignTarget,
                  );
                  Navigator.pop(ctx);
                },
                child: const Text('Deactivate & Reassign Work'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    String uid,
    String name,
  ) async {
    final cubit = context.read<DashboardCubit>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) {
        final screenWidth = MediaQuery.of(c).size.width;
        final dialogWidth = (screenWidth - 48).clamp(280.0, 440.0);
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          title: const Text(
            'Remove User Account',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          content: SizedBox(
            width: dialogWidth,
            child: Text(
              'Are you sure you want to remove "$name" from the database? This cannot be undone.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel', style: TextStyle(color: _textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Remove User'),
            ),
          ],
        );
      },
    );
    if (ok == true) {
      await cubit.deleteUser(uid, name);
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    SnackBarAlert.showToast(
      context: context,
      message: 'Copied $label to clipboard',
    );
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<DashboardCubit>();
    final myUid = cubit.currentUserId;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _usersStream ??= cubit.watchAllUsers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(48),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError && !snapshot.hasData) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    size: 40,
                    color: Color(0xFFDC2626),
                  ),
                  const Gap(12),
                  const Text(
                    'Unable to load users',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const Gap(8),
                  Text(
                    '',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const Gap(16),
                  ElevatedButton(
                    onPressed: () => setState(() {
                      _usersStream = cubit.watchAllUsers();
                    }),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        final allUsers = cubit.mapAndSortUsers(snapshot.data);

        // Filter users
        final filteredUsers = allUsers.where((u) {
          final q = _searchQuery.toLowerCase().trim();
          final matchesSearch =
              q.isEmpty ||
              u.name.toLowerCase().contains(q) ||
              u.email.toLowerCase().contains(q) ||
              u.uid.toLowerCase().contains(q);

          final matchesRole =
              _roleFilter == 'all' ||
              DashboardUserModel.normalizeRole(u.role) == _roleFilter;

          final matchesStatus =
              _statusFilter == 'all' ||
              (_statusFilter == 'active' && u.isActive) ||
              (_statusFilter == 'inactive' && !u.isActive);

          return matchesSearch && matchesRole && matchesStatus;
        }).toList();

        final activeCount = allUsers.where((u) => u.isActive).length;
        final inactiveCount = allUsers.length - activeCount;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header & Action Buttons
            // Top Header & Action Buttons (Responsive Layout)
            LayoutBuilder(
              builder: (context, c) {
                final isMobile =
                    MediaQuery.of(context).size.width < 768 || c.maxWidth < 680;
                final titleCol = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'User Management',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: _textDark,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Gap(4),
                    Text(
                      'Add new team accounts, assign roles, and manage system access.',
                      style: TextStyle(fontSize: 13, color: _textMuted),
                    ),
                  ],
                );

                final addByUidBtn = OutlinedButton.icon(
                  onPressed: () => _openAddUserDialog(byUid: true),
                  icon: const Icon(
                    Icons.vpn_key_outlined,
                    size: 16,
                    color: Color(0xFF64748B),
                  ),
                  label: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Add by UID',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                );

                final addUserBtn = ElevatedButton.icon(
                  onPressed: () => _openAddUserDialog(byUid: false),
                  icon: const Icon(
                    Icons.person_add_alt_1_rounded,
                    size: 17,
                    color: Colors.white,
                  ),
                  label: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Add User',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF8144),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    side: BorderSide.none,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                );

                final actionBtns = isMobile
                    ? Row(
                        children: [
                          Expanded(child: addByUidBtn),
                          const Gap(10),
                          Expanded(child: addUserBtn),
                        ],
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          addByUidBtn,
                          const Gap(10),
                          addUserBtn,
                        ],
                      );

                if (isMobile) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      titleCol,
                      const Gap(12),
                      actionBtns,
                    ],
                  );
                }

                return SizedBox(
                  width: double.infinity,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(child: titleCol),
                      const Gap(16),
                      actionBtns,
                    ],
                  ),
                );
              },
            ),
            const Gap(20),

            // Search & Filter Toolbar
            LayoutBuilder(
              builder: (context, c) {
                final isNarrow = c.maxWidth < 720;
                final searchField = Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: TextField(
                    onChanged: (v) => setState(() => _searchQuery = v),
                    style: const TextStyle(fontSize: 13.5, color: _textDark),
                    decoration: InputDecoration(
                      hintText: 'Search by name, email, or UID...',
                      hintStyle: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF94A3B8),
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        size: 20,
                        color: Color(0xFF94A3B8),
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () =>
                                  setState(() => _searchQuery = ''),
                            )
                          : null,
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                  ),
                );

                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      searchField,
                      const Gap(10),
                      Row(
                        children: [
                          Expanded(child: _buildRoleFilterDropdown()),
                          const Gap(10),
                          Expanded(child: _buildStatusFilterDropdown()),
                        ],
                      ),
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(flex: 5, child: searchField),
                    const Gap(12),
                    Expanded(flex: 3, child: _buildRoleFilterDropdown()),
                    const Gap(12),
                    Expanded(flex: 2, child: _buildStatusFilterDropdown()),
                  ],
                );
              },
            ),
            const Gap(14),

            // Badges
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _badge(
                  'Total: ${allUsers.length}',
                  const Color(0xFFEEF0FF),
                  const Color(0xFF4F46E5),
                ),
                _badge(
                  'Active: $activeCount',
                  const Color(0xFFDCFCE7),
                  const Color(0xFF16A34A),
                ),
                _badge(
                  'Inactive: $inactiveCount',
                  const Color(0xFFFEE2E2),
                  const Color(0xFFEF4444),
                ),
                if (_searchQuery.isNotEmpty ||
                    _roleFilter != 'all' ||
                    _statusFilter != 'all')
                  _badge(
                    'Showing: ${filteredUsers.length}',
                    const Color(0xFFFEF3C7),
                    const Color(0xFFB45309),
                  ),
              ],
            ),
            const Gap(20),

            // User List / Table Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFF1F5F9)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Team Directory',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: _textDark,
                        ),
                      ),
                      Text(
                        '${filteredUsers.length} user${filteredUsers.length == 1 ? '' : 's'}',
                        style: const TextStyle(fontSize: 12, color: _textMuted),
                      ),
                    ],
                  ),
                  const Gap(16),
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (snapshot.hasError && !snapshot.hasData)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Error loading users: ${snapshot.error}',
                            style: const TextStyle(color: Colors.red),
                          ),
                          const Gap(8),
                          OutlinedButton.icon(
                            onPressed: () {
                              setState(() {
                                _usersStream = cubit.watchAllUsers();
                              });
                            },
                            icon: const Icon(CupertinoIcons.refresh, size: 16),
                            label: const Text('Retry Loading Users'),
                          ),
                        ],
                      ),
                    )
                  else if (filteredUsers.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(36),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.people_outline,
                              size: 48,
                              color: Color(0xFFCBD5E1),
                            ),
                            const Gap(12),
                            Text(
                              allUsers.isEmpty
                                  ? 'No team users in database yet.'
                                  : 'No users match your search/filter.',
                              style: const TextStyle(
                                color: _textMuted,
                                fontSize: 14,
                              ),
                            ),
                            const Gap(12),
                            if (allUsers.isEmpty)
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _primaryColor,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: () =>
                                    _openAddUserDialog(byUid: false),
                                icon: const Icon(Icons.person_add, size: 16),
                                label: const Text('Add First User'),
                              ),
                          ],
                        ),
                      ),
                    )
                  else
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isDesktop = constraints.maxWidth >= 780;
                        if (isDesktop) {
                          final tableWidth = constraints.maxWidth > 1050
                              ? constraints.maxWidth
                              : 1050.0;
                          return SizedBox(
                            width: double.infinity,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: SizedBox(
                                width: tableWidth,
                                child: _buildDesktopTable(
                                  cubit,
                                  filteredUsers,
                                  allUsers,
                                  myUid,
                                ),
                              ),
                            ),
                          );
                        } else {
                          return _buildMobileCardList(
                            cubit,
                            filteredUsers,
                            allUsers,
                            myUid,
                          );
                        }
                      },
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRoleFilterDropdown() {
    return AcadenoDropdown<String>(
      value: _roleFilter,
      borderRadius: 10,
      borderColor: const Color(0xFFE2E8F0),
      fillColor: Colors.white,
      prefixIcon: const Icon(
        Icons.work_outline_rounded,
        size: 18,
        color: Color(0xFF64748B),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      items: const [
        AcadenoDropdownItem(value: 'all', label: 'All Roles'),
        AcadenoDropdownItem(value: 'admin', label: 'Admin'),
        AcadenoDropdownItem(value: 'hr', label: 'HR & Operations'),
      ],
      onChanged: (v) => setState(() => _roleFilter = v ?? 'all'),
    );
  }

  Widget _buildStatusFilterDropdown() {
    return AcadenoDropdown<String>(
      value: _statusFilter,
      borderRadius: 10,
      borderColor: const Color(0xFFE2E8F0),
      fillColor: Colors.white,
      prefixIcon: const Icon(
        Icons.tune_rounded,
        size: 18,
        color: Color(0xFF64748B),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      items: const [
        AcadenoDropdownItem(value: 'all', label: 'All Statuses'),
        AcadenoDropdownItem(value: 'active', label: 'Active Only'),
        AcadenoDropdownItem(value: 'inactive', label: 'Inactive Only'),
      ],
      onChanged: (v) => setState(() => _statusFilter = v ?? 'all'),
    );
  }

  Widget _badge(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }

  static const _tblHdr = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: Color(0xFF94A3B8),
    letterSpacing: 0.5,
  );

  Widget _buildDesktopTable(
    DashboardCubit cubit,
    List<DashboardUserModel> users,
    List<DashboardUserModel> allUsers,
    String? myUid,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
          ),
          child: const Row(
            children: [
              Expanded(
                flex: 3,
                child: Padding(
                  padding: EdgeInsets.only(right: 14),
                  child: Text('USER', style: _tblHdr),
                ),
              ),
              Expanded(
                flex: 3,
                child: Padding(
                  padding: EdgeInsets.only(right: 14),
                  child: Text('EMAIL & UID', style: _tblHdr),
                ),
              ),
              Expanded(
                flex: 2,
                child: Padding(
                  padding: EdgeInsets.only(right: 14),
                  child: Text('ROLE', style: _tblHdr),
                ),
              ),
              Expanded(
                flex: 3,
                child: Padding(
                  padding: EdgeInsets.only(right: 14),
                  child: Text('DEVICE SECURITY', style: _tblHdr),
                ),
              ),
              SizedBox(
                width: 70,
                child: Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Text('ACTIVE', style: _tblHdr),
                ),
              ),
              SizedBox(
                width: 80,
                child: Center(child: Text('ACTIONS', style: _tblHdr)),
              ),
              SizedBox(
                width: 110,
                child: Center(child: Text('RESET PASSWORD', style: _tblHdr)),
              ),
            ],
          ),
        ),
        for (final user in users)
          Builder(
            builder: (_) {
              final isMe = user.uid == myUid;
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFF8FAFC))),
                ),
                child: Row(
                  children: [
                    // USER (Avatar + Name)
                    Expanded(
                      flex: 3,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 14),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: user.name.toLowerCase().contains('admin')
                                    ? const Color(0xFFFEF3C7)
                                    : (user.name.toLowerCase().contains('test')
                                          ? const Color(0xFFF3E8FF)
                                          : const Color(0xFFEEF2FF)),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                user.name.isNotEmpty && user.name != '—'
                                    ? user.name[0].toUpperCase()
                                    : (user.email.isNotEmpty &&
                                              user.email != '—'
                                          ? user.email[0].toUpperCase()
                                          : 'U'),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color:
                                      user.name.toLowerCase().contains('admin')
                                      ? const Color(0xFFD97706)
                                      : (user.name.toLowerCase().contains(
                                              'test',
                                            )
                                            ? const Color(0xFF9333EA)
                                            : const Color(0xFF4F46E5)),
                                ),
                              ),
                            ),
                            const Gap(10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          user.name.isNotEmpty
                                              ? user.name
                                              : (user.email.isNotEmpty &&
                                                        user.email != '—'
                                                    ? user.email
                                                          .split('@')
                                                          .first
                                                    : user.uid),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13.5,
                                            color: _textDark,
                                          ),
                                        ),
                                      ),
                                      if (isMe) ...[
                                        const Gap(6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 5,
                                            vertical: 1.5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFEEF0FF),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: const Text(
                                            'YOU',
                                            style: TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 0.4,
                                              color: Color(0xFF4F46E5),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // EMAIL & UID
                    Expanded(
                      flex: 3,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SelectableText(
                              user.email.isNotEmpty && user.email != '—'
                                  ? user.email
                                  : (user.name.contains('@') ? user.name : '—'),
                              maxLines: 1,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: _textDark,
                              ),
                            ),
                            const Gap(2),
                            InkWell(
                              onTap: () => _copyToClipboard(user.uid, 'UID'),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      user.uid,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 11,
                                        color: Color(0xFF94A3B8),
                                      ),
                                    ),
                                  ),
                                  const Gap(4),
                                  const Icon(
                                    Icons.copy_rounded,
                                    size: 12,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ROLE
                    Expanded(
                      flex: 2,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 14),
                        child: Container(
                          height: 34,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              dropdownColor: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              value: DashboardUserModel.normalizeRole(
                                user.role,
                              ),
                              isDense: true,
                              isExpanded: true,
                              icon: const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                size: 18,
                                color: Color(0xFF94A3B8),
                              ),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF334155),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'admin',
                                  child: Text(
                                    'Admin',
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'hr',
                                  child: Text(
                                    'HR & Operations',
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                              ],
                              onChanged: isMe
                                  ? null
                                  : (newRole) {
                                      if (newRole != null &&
                                          newRole != user.role) {
                                        cubit.updateUserRole(
                                          user.uid,
                                          newRole,
                                          userName: user.name,
                                        );
                                      }
                                    },
                            ),
                          ),
                        ),
                      ),
                    ),

                    // DEVICE SECURITY
                    Expanded(
                      flex: 3,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 14),
                        child: Row(
                          children: [
                            Icon(
                              user.deviceBound
                                  ? Icons.smartphone_rounded
                                  : Icons.sync_rounded,
                              size: 18,
                              color: user.deviceBound
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFFF59E0B),
                            ),
                            const Gap(8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    user.deviceBound
                                        ? (user.deviceName.isNotEmpty
                                              ? user.deviceName
                                              : 'Registered Phone')
                                        : 'Pending new phone',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: user.deviceBound
                                          ? _textDark
                                          : const Color(0xFFD97706),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const Gap(1),
                                  Text(
                                    user.deviceBound
                                        ? 'REGISTERED PHONE'
                                        : 'PENDING BINDING',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.3,
                                      color: user.deviceBound
                                          ? const Color(0xFF10B981)
                                          : const Color(0xFFD97706),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 26,
                                minHeight: 26,
                              ),
                              icon: const Icon(
                                Icons.cancel_rounded,
                                size: 16,
                                color: Color(0xFFCBD5E1),
                              ),
                              tooltip: 'Reset Phone Binding',
                              onPressed: () =>
                                  _confirmResetDevice(context, cubit, user),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ACTIVE
                    SizedBox(
                      width: 70,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Transform.scale(
                            scale: 0.8,
                            child: Switch(
                              value: user.isActive,
                              activeTrackColor: const Color(0xFF4F46E5),
                              inactiveTrackColor: const Color(0xFFE2E8F0),
                              thumbColor: WidgetStateProperty.all(Colors.white),
                              trackOutlineColor: WidgetStateProperty.all(
                                Colors.transparent,
                              ),
                              onChanged: isMe
                                  ? null
                                  : (val) {
                                      if (!val) {
                                        _showDeactivateAndReassignDialog(
                                          user,
                                          allUsers,
                                        );
                                      } else {
                                        cubit.updateUserActive(
                                          user.uid,
                                          true,
                                          userName: user.name,
                                        );
                                      }
                                    },
                            ),
                          ),
                        ),
                      ),
                    ),

                    // ACTIONS
                    SizedBox(
                      width: 80,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 30,
                              minHeight: 30,
                            ),
                            icon: const Icon(
                              Icons.logout_rounded,
                              size: 17,
                              color: Color(0xFF94A3B8),
                            ),
                            tooltip: 'Remote sign out session',
                            onPressed: () =>
                                _confirmForceSignOut(context, cubit, user),
                          ),
                          const Gap(4),
                          if (isMe)
                            IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 30,
                                minHeight: 30,
                              ),
                              icon: const Icon(
                                Icons.groups_outlined,
                                size: 19,
                                color: Color(0xFF6366F1),
                              ),
                              tooltip: 'Admin Settings',
                              onPressed: _navigateToSettings,
                            )
                          else
                            IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 30,
                                minHeight: 30,
                              ),
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                size: 18,
                                color: Color(0xFFF87171),
                              ),
                              tooltip: 'Remove user',
                              onPressed: () =>
                                  _confirmDelete(context, user.uid, user.name),
                            ),
                        ],
                      ),
                    ),

                    // RESET PASSWORD
                    SizedBox(
                      width: 110,
                      child: Center(
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                          icon: const Icon(
                            Icons.lock_reset_rounded,
                            size: 20,
                            color: Color(0xFF94A3B8),
                          ),
                          tooltip: 'Reset Password',
                          onPressed: () =>
                              _confirmResetPassword(context, cubit, user),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildMobileCardList(
    DashboardCubit cubit,
    List<DashboardUserModel> users,
    List<DashboardUserModel> allUsers,
    String? myUid,
  ) {
    return Column(
      children: [
        for (var i = 0; i < users.length; i++) ...[
          if (i > 0) const Gap(12),
          Builder(
            builder: (_) {
              final user = users[i];
              final isMe = user.uid == myUid;
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _bgLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: const Color(0xFFEEF0FF),
                          child: Text(
                            user.name.isNotEmpty && user.name != "—"
                                ? user.name[0].toUpperCase()
                                : (user.email.isNotEmpty && user.email != "—"
                                      ? user.email[0].toUpperCase()
                                      : "U"),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _primaryColor,
                            ),
                          ),
                        ),
                        const Gap(10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isMe
                                    ? '${user.name.isNotEmpty && user.name != "—" ? user.name : (user.email.isNotEmpty && user.email != "—" ? user.email.split("@").first : user.uid)} (YOU)'
                                    : (user.name.isNotEmpty && user.name != "—"
                                          ? user.name
                                          : (user.email.isNotEmpty &&
                                                    user.email != "—"
                                                ? user.email.split("@").first
                                                : user.uid)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                user.email.isNotEmpty && user.email != "—"
                                    ? user.email
                                    : (user.name.contains("@")
                                          ? user.name
                                          : "—"),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: _textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: user.isActive,
                          activeThumbColor: const Color(0xFF4F46E5),
                          onChanged: isMe
                              ? null
                              : (val) {
                                  if (!val) {
                                    _showDeactivateAndReassignDialog(
                                      user,
                                      allUsers,
                                    );
                                  } else {
                                    cubit.updateUserActive(
                                      user.uid,
                                      true,
                                      userName: user.name,
                                    );
                                  }
                                },
                        ),
                      ],
                    ),
                    const Gap(8),
                    InkWell(
                      onTap: () => _copyToClipboard(user.uid, 'UID'),
                      child: Row(
                        children: [
                          const Text(
                            'UID: ',
                            style: TextStyle(fontSize: 11, color: _textMuted),
                          ),
                          Flexible(
                            child: Text(
                              user.uid,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 11,
                                color: _textMuted,
                              ),
                            ),
                          ),
                          const Gap(4),
                          const Icon(
                            Icons.copy_rounded,
                            size: 12,
                            color: _textMuted,
                          ),
                        ],
                      ),
                    ),
                    const Gap(10),
                    Row(
                      children: [
                        const Text(
                          'Role:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _textMuted,
                          ),
                        ),
                        const Gap(8),
                        Expanded(
                          child: Container(
                            height: 32,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: _borderColor),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                dropdownColor: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                value: DashboardUserModel.normalizeRole(
                                  user.role,
                                ),
                                isDense: true,
                                isExpanded: true,
                                items: const [
                                  DropdownMenuItem(
                                    value: 'admin',
                                    child: Text(
                                      'Admin',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: 'hr',
                                    child: Text(
                                      'HR & Operation Manager',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ],
                                onChanged: isMe
                                    ? null
                                    : (newRole) {
                                        if (newRole != null &&
                                            newRole != user.role) {
                                          cubit.updateUserRole(
                                            user.uid,
                                            newRole,
                                            userName: user.name,
                                          );
                                        }
                                      },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Gap(8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            user.deviceBound
                                ? Icons.phone_android_rounded
                                : Icons.phonelink_setup_rounded,
                            size: 14,
                            color: user.deviceBound
                                ? const Color(0xFF16A34A)
                                : const Color(0xFFD97706),
                          ),
                          const Gap(6),
                          Expanded(
                            child: Text(
                              'Device: ${user.deviceName} (${user.deviceBound ? "Registered" : "Pending"})',
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: _textDark,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                            ),
                            onPressed: () =>
                                _confirmResetDevice(context, cubit, user),
                            icon: const Icon(
                              Icons.phonelink_erase_rounded,
                              size: 14,
                            ),
                            label: const Text(
                              'Reset',
                              style: TextStyle(fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Gap(8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.logout_rounded, size: 18),
                              tooltip: 'Remote sign out session',
                              onPressed: () =>
                                  _confirmForceSignOut(context, cubit, user),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.lock_reset_rounded,
                                size: 19,
                                color: Color(0xFF64748B),
                              ),
                              tooltip: 'Reset Password',
                              onPressed: () =>
                                  _confirmResetPassword(context, cubit, user),
                            ),
                            if (isMe)
                              IconButton(
                                icon: const Icon(
                                  Icons.manage_accounts_outlined,
                                  size: 20,
                                  color: _primaryColor,
                                ),
                                tooltip: 'Admin Settings',
                                onPressed: _navigateToSettings,
                              )
                            else
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 18,
                                  color: Color(0xFFDC2626),
                                ),
                                onPressed: () => _confirmDelete(
                                  context,
                                  user.uid,
                                  user.name,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}
