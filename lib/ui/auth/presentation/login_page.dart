import 'package:acadeno_crm/core/router/app_router.dart';
import 'package:acadeno_crm/shared/extensions/build_context_extension.dart';
import 'package:acadeno_crm/shared/snackbar_alerts/snack_alert.dart';
import 'package:acadeno_crm/shared/theme/app_colors.dart';
import 'package:acadeno_crm/shared/theme/app_dim.dart';
import 'package:acadeno_crm/shared/theme/app_images.dart';
import 'package:acadeno_crm/shared/theme/app_typography.dart';
import 'package:acadeno_crm/ui/auth/application/login_cubit.dart';
import 'package:acadeno_crm/ui/auth/application/login_state.dart';
import 'package:acadeno_crm/ui/auth/data/model/login_model.dart';
import 'package:acadeno_crm/ui/auth/data/repository/firebase_auth_repo.dart';
import 'package:acadeno_crm/ui/auth/data/sources/firebase_auth_rds.dart';
import 'package:auto_route/auto_route.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

TextStyle _heading(double size) => AppTypography.heading(size);

TextStyle _body({
  double size = 15,
  FontWeight weight = FontWeight.w400,
  Color color = AppColors.text,
  double? height,
}) => AppTypography.body(
  size: size,
  weight: weight,
  color: color,
  height: height,
);

@RoutePage()
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authRds = FirebaseAuthRds(FirebaseAuth.instance);
    final repository = AuthRepository(authRds);

    return BlocProvider(
      create: (_) => LoginCubit(repository),
      child: const _LoginView(),
    );
  }
}

class _LoginView extends StatefulWidget {
  const _LoginView();

  @override
  State<_LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<_LoginView> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final request = LoginRequestModel(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    context.read<LoginCubit>().signIn(request);
  }

  void _snack(String message, {bool isError = false}) {
    SnackBarAlert.showToast(
      context: context,
      message: message,
      isWarning: isError,
    );
  }

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();

    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      _snack('Enter your work email first.', isError: true);
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      _snack('Password reset link sent to your email.');
    } on FirebaseAuthException catch (e) {
      _snack(e.message ?? 'Could not send reset email.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<LoginCubit, LoginState>(
      listener: (context, state) {
        state.whenOrNull(
          success: () {
            final cubit = context.read<LoginCubit>();
            if (cubit.isAdmin) {
              // Admin → admin dashboard
              context.router.replaceAll([const DashboardRoute()]);
            } else {
              // Normal Firebase user → home page
              context.router.replaceAll([const HomeRoute()]);
            }
          },
          failure: (message) => _snack(message, isError: true),
        );
      },
      builder: (context, state) {
        final isLoading = state.maybeWhen(
          loading: () => true,
          orElse: () => false,
        );

        return Scaffold(
          backgroundColor: AppColors.white,
          body: SafeArea(
            child: Column(
              children: [
                const _TopColorBar(),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        padding: EdgeInsets.symmetric(
                          horizontal: context.devicePadding,
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: 440,
                              minHeight: constraints.maxHeight,
                            ),
                            child: IntrinsicHeight(
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    const SizedBox(height: 44),

                                    // ---- LOGO (full logo on sign-in) ----
                                    Center(
                                      child: Image.asset(
                                        AppImages.logo,
                                        height: 80,
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                    const SizedBox(height: AppSpace.s32),

                                    Text('Lead Manager', style: _heading(26)),
                                    const SizedBox(height: AppSpace.s8),
                                    Text(
                                      'Acadeno Research & Innovation Centre',
                                      style: _body(
                                        size: 15,
                                        color: AppColors.secondary,
                                      ),
                                    ),
                                    const SizedBox(height: AppSpace.s24 + 4),

                                    const _Label('Work email'),
                                    const SizedBox(height: AppSpace.s8),
                                    TextFormField(
                                      controller: _emailController,
                                      keyboardType: TextInputType.emailAddress,
                                      textInputAction: TextInputAction.next,
                                      style: _body(size: 15),
                                      cursorColor: AppColors.indigo,
                                      decoration: _decoration(),
                                      validator: (value) {
                                        final email = value?.trim() ?? '';
                                        if (email.isEmpty ||
                                            !RegExp(
                                              r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                                            ).hasMatch(email)) {
                                          return 'Enter a valid email address.';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: AppSpace.s20),

                                    const _Label('Password'),
                                    const SizedBox(height: AppSpace.s8),
                                    TextFormField(
                                      controller: _passwordController,
                                      obscureText: _obscurePassword,
                                      textInputAction: TextInputAction.done,
                                      style: _body(size: 15),
                                      cursorColor: AppColors.indigo,
                                      onFieldSubmitted: (_) =>
                                          isLoading ? null : _submit(),
                                      decoration: _decoration().copyWith(
                                        suffixIcon: IconButton(
                                          onPressed: () => setState(() {
                                            _obscurePassword =
                                                !_obscurePassword;
                                          }),
                                          icon: Icon(
                                            _obscurePassword
                                                ? Icons.visibility_off_outlined
                                                : Icons.visibility_outlined,
                                            color: AppColors.secondary,
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                      validator: (value) =>
                                          (value == null || value.isEmpty)
                                          ? 'Password is required.'
                                          : null,
                                    ),
                                    const SizedBox(height: AppSpace.s12),

                                    // Forgot password (44px touch target)
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: InkWell(
                                        onTap: isLoading
                                            ? null
                                            : _forgotPassword,
                                        borderRadius: BorderRadius.circular(
                                          AppRadius.chip,
                                        ),
                                        child: ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            minHeight: 44,
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.only(
                                              left: AppSpace.s8,
                                            ),
                                            child: Align(
                                              widthFactor: 1,
                                              child: Text(
                                                'Forgot password?',
                                                style: _body(
                                                  size: 14,
                                                  weight: FontWeight.w500,
                                                  color: AppColors.indigo,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: AppSpace.s12),

                                    // Primary button
                                    SizedBox(
                                      height: 52,
                                      child: ElevatedButton(
                                        onPressed: isLoading ? null : _submit,
                                        style: ElevatedButton.styleFrom(
                                          elevation: 0,
                                          backgroundColor: AppColors.indigo,
                                          disabledBackgroundColor: AppColors
                                              .indigo
                                              .withValues(alpha: 0.6),
                                          foregroundColor: AppColors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              AppRadius.button,
                                            ),
                                          ),
                                        ),
                                        child: isLoading
                                            ? const CupertinoActivityIndicator(
                                                color: AppColors.white,
                                                radius: 11,
                                              )
                                            : Text(
                                                'Sign in',
                                                style: _body(
                                                  size: 16,
                                                  weight: FontWeight.w600,
                                                  color: AppColors.white,
                                                ),
                                              ),
                                      ),
                                    ),

                                    const Spacer(),
                                    const SizedBox(height: AppSpace.s24),

                                    // Info card
                                    Container(
                                      padding: EdgeInsets.all(
                                        context.devicePadding.clamp(14, 18),
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.ground,
                                        borderRadius: BorderRadius.circular(
                                          AppRadius.card,
                                        ),
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Padding(
                                            padding: EdgeInsets.only(top: 1),
                                            child: Icon(
                                              Icons.lock_outline,
                                              size: 18,
                                              color: AppColors.secondary,
                                            ),
                                          ),
                                          const SizedBox(width: AppSpace.s12),
                                          Expanded(
                                            child: Text(
                                              'Accounts are created by your admin. '
                                              "Ask your manager if you can't sign in.",
                                              style: _body(
                                                size: 13,
                                                color: AppColors.secondary,
                                                height: 1.4,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: AppSpace.s20),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  InputDecoration _decoration() {
    OutlineInputBorder outline(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: BorderSide(color: color, width: width),
        );

    return InputDecoration(
      filled: true,
      fillColor: AppColors.white,
      constraints: const BoxConstraints(minHeight: 52),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpace.s16,
        vertical: AppSpace.s16,
      ),
      errorStyle: _body(size: 12, color: AppColors.coral),
      border: outline(AppColors.border),
      enabledBorder: outline(AppColors.border),
      focusedBorder: outline(AppColors.indigo, 1.5),
      errorBorder: outline(AppColors.coral),
      focusedErrorBorder: outline(AppColors.coral, 1.5),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: _body(size: 14, weight: FontWeight.w600));
  }
}

/// Top brand color strip image (indigo, blue, orange, amber).
class _TopColorBar extends StatelessWidget {
  const _TopColorBar();

  @override
  Widget build(BuildContext context) {
    const colors = [
      AppColors.indigo,
      AppColors.blue,
      AppColors.orange,
      AppColors.amber,
    ];

    return SizedBox(
      height: 6,
      width: double.infinity,
      child: Image.asset(
        AppImages.topColorBar,
        fit: BoxFit.fill,
        errorBuilder: (_, _, _) => Row(
          children: [
            for (final c in colors) Expanded(child: ColoredBox(color: c)),
          ],
        ),
      ),
    );
  }
}
