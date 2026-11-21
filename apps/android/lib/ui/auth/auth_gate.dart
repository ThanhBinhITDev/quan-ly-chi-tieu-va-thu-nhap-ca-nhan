import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:android/app.dart';
import 'package:android/core/error/app_exception.dart';
import 'package:android/core/session/auth_controller.dart';
import 'package:android/ui/auth/animated_background.dart';
import 'package:android/ui/auth/app_logo.dart';
import 'package:android/ui/auth/register_screen.dart';
import 'package:android/ui/legal/consent_checkbox.dart';
import 'package:android/ui/strings.dart';
import 'package:android/ui/theme.dart';

/// Cửa ngõ của app: chưa đăng nhập thì hiện form, đã đăng nhập thì vào app.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Chưa đăng nhập thì chỉ có form: không còn đường vòng vào app bằng dữ
    // liệu mẫu. Dữ liệu luôn thuộc về tài khoản đang đăng nhập.
    final auth = ref.watch(authControllerProvider);
    return auth.when(
      loading: () => const _Splash(),
      error: (error, _) => _LoginScreen(
        initialError: error is AppException ? error.message : '$error',
      ),
      data: (session) => session == null
          ? const _LoginScreen()
          : const AppShell(),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );
  }
}

class _LoginScreen extends ConsumerStatefulWidget {
  const _LoginScreen({this.initialError});

  final String? initialError;

  @override
  ConsumerState<_LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<_LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _obscure = true;
  bool _consent = false;
  bool _consentError = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  /// Ghi nhận đồng ý điều khoản. Chỉ gọi **sau khi** đăng nhập thành công.
  Future<void> _recordConsent() async {
    if (!_consent) return;
    await recordConsent(ref);
  }

  @override
  void initState() {
    super.initState();
    _error = widget.initialError;
  }

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _info = null;
      _consentError = !_consent;
    });
    final formOk = _formKey.currentState?.validate() ?? false;
    if (!_consent) return;
    if (!formOk) return;

    final controller = ref.read(authControllerProvider.notifier);
    await controller.signIn(
      email: _email.text.trim(),
      password: _password.text,
    );
    if (!mounted) return;
    final state = ref.read(authControllerProvider);
    if (state.hasError) {
      final error = state.error;
      setState(() {
        _error = error is AppException ? error.message : '$error';
      });
      return;
    }
    await _recordConsent();
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authControllerProvider).isLoading;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: AnimatedAuthBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.xl,
                vertical: AppSpace.xxl,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 420),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) => Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, 18 * (1 - value)),
                      child: child,
                    ),
                  ),
                  child: _LoginCard(
                    formKey: _formKey,
                    email: _email,
                    password: _password,
                    obscure: _obscure,
                    isLoading: isLoading,
                    consent: _consent,
                    consentError: _consentError,
                    error: _error,
                    info: _info,
                    onToggleObscure: () => setState(() => _obscure = !_obscure),
                    onConsentChanged: (value) => setState(() {
                      _consent = value;
                      if (value) _consentError = false;
                    }),
                    onSubmit: _submit,
                    onOpenRegister: () => RegisterScreen.open(context),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Thẻ trắng chứa toàn bộ form đăng nhập.
class _LoginCard extends StatelessWidget {
  const _LoginCard({
    required this.formKey,
    required this.email,
    required this.password,
    required this.obscure,
    required this.isLoading,
    required this.consent,
    required this.consentError,
    required this.onToggleObscure,
    required this.onConsentChanged,
    required this.onSubmit,
    required this.onOpenRegister,
    this.error,
    this.info,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController email;
  final TextEditingController password;
  final bool obscure;
  final bool isLoading;
  final bool consent;
  final bool consentError;
  final VoidCallback onToggleObscure;
  final ValueChanged<bool> onConsentChanged;
  final VoidCallback onSubmit;
  final VoidCallback onOpenRegister;
  final String? error;
  final String? info;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.xl,
        AppSpace.xxl,
        AppSpace.xl,
        AppSpace.lg,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 28,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(child: AppLogo(size: 76)),
            const SizedBox(height: AppSpace.lg),
            Text(
              AppStrings.appTitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: AppSpace.sm),
            Text(
              AppStrings.loginSubtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),
            const SizedBox(height: AppSpace.xl),

            TextFormField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(
                labelText: AppStrings.emailLabel,
                prefixIcon: Icon(LucideIcons.mail),
              ),
              validator: (value) {
                final text = (value ?? '').trim();
                final ok =
                    RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text);
                return ok ? null : AppStrings.emailInvalid;
              },
            ),
            const SizedBox(height: AppSpace.lg),

            TextFormField(
              controller: password,
              obscureText: obscure,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              onFieldSubmitted: (_) => onSubmit(),
              decoration: InputDecoration(
                labelText: AppStrings.passwordLabel,
                prefixIcon: const Icon(LucideIcons.lock),
                suffixIcon: IconButton(
                  tooltip: obscure ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                  onPressed: onToggleObscure,
                  icon: Icon(obscure ? LucideIcons.eye : LucideIcons.eyeOff),
                ),
              ),
              validator: (value) => (value ?? '').length < 6
                  ? AppStrings.passwordTooShort
                  : null,
            ),

            if (error != null) ...[
              const SizedBox(height: AppSpace.lg),
              _NoticeBox(
                message: error!,
                color: AppColors.expense,
                background: AppColors.expenseSoft,
                icon: LucideIcons.circleAlert,
              ),
            ],
            if (info != null) ...[
              const SizedBox(height: AppSpace.lg),
              _NoticeBox(
                message: info!,
                color: AppColors.income,
                background: AppColors.incomeSoft,
                icon: LucideIcons.info,
              ),
            ],

            const SizedBox(height: AppSpace.lg),
            ConsentCheckbox(
              value: consent,
              onChanged: onConsentChanged,
              enabled: !isLoading,
              errorText: consentError ? AppStrings.consentRequired : null,
            ),
            const SizedBox(height: AppSpace.md),

            FilledButton(
              onPressed: isLoading ? null : onSubmit,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Text(AppStrings.signInAction),
            ),

            const SizedBox(height: AppSpace.sm),
            TextButton(
              onPressed: isLoading ? null : onOpenRegister,
              child: const Text(AppStrings.switchToSignUp),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoticeBox extends StatelessWidget {
  const _NoticeBox({
    required this.message,
    required this.color,
    required this.background,
    required this.icon,
  });

  final String message;
  final Color color;
  final Color background;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpace.md),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: AppSpace.sm),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: color, fontSize: 13, height: 1.35),
              ),
            ),
          ],
        ),
      ),
    );
  }
}