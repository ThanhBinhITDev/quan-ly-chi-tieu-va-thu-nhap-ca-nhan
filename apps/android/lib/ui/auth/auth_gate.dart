import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:android/app.dart';
import 'package:android/core/config/app_config.dart';
import 'package:android/core/error/app_exception.dart';
import 'package:android/core/session/auth_controller.dart';
import 'package:android/providers.dart';
import 'package:android/ui/auth/animated_background.dart';
import 'package:android/ui/legal/consent_checkbox.dart';
import 'package:android/ui/strings.dart';
import 'package:android/ui/theme.dart';

/// Cửa ngõ của app: chưa đăng nhập thì hiện form, đã đăng nhập thì vào app.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Chưa cấu hình Supabase (hoặc người dùng chọn xem thử): vào thẳng app với
    // dữ liệu mẫu để giao diện vẫn dùng được.
    if (ref.watch(demoModeProvider)) return const AppShell();

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
  final _displayName = TextEditingController();

  bool _isSignUp = false;
  bool _obscure = true;
  bool _consent = false;
  bool _consentError = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _displayName.dispose();
    super.dispose();
  }

  /// Ghi nhận đồng ý điều khoản. Chỉ gọi **sau khi** đăng nhập/đăng ký thành
  /// công: người dùng đồng ý để dùng dịch vụ, không phải để thử bấm nút.
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
    // Chặn cả khi form đúng nhưng chưa đồng ý điều khoản: đây là điều kiện
    // pháp lý, không phải gợi ý.
    if (!_consent) return;
    if (!formOk) return;

    final controller = ref.read(authControllerProvider.notifier);
    if (_isSignUp) {
      final hasSession = await controller.signUp(
        email: _email.text.trim(),
        password: _password.text,
        displayName: _displayName.text.trim(),
      );
      if (!mounted) return;
      if (!hasSession) {
        setState(() => _info = AppStrings.signUpNeedsConfirm);
        setState(() => _isSignUp = false);
        return;
      }
      await _recordConsent();
      return;
    }

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
                  // Một lần trượt nhẹ khi mở màn hình: đủ để mắt bắt được
                  // chuyển cảnh, không đủ để phải chờ.
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
                    displayName: _displayName,
                    isSignUp: _isSignUp,
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
                    onToggleMode: () => setState(() {
                      _isSignUp = !_isSignUp;
                      _error = null;
                      _info = null;
                    }),
                    onDemo: () =>
                        ref.read(demoModeProvider.notifier).setDemo(true),
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

/// Thẻ trắng chứa toàn bộ form. Tách khỏi `_LoginScreen` để phần hiệu ứng
/// chuyển cảnh ở trên không phải dựng lại mỗi lần gõ phím.
class _LoginCard extends StatelessWidget {
  const _LoginCard({
    required this.formKey,
    required this.email,
    required this.password,
    required this.displayName,
    required this.isSignUp,
    required this.obscure,
    required this.isLoading,
    required this.consent,
    required this.consentError,
    required this.onToggleObscure,
    required this.onConsentChanged,
    required this.onSubmit,
    required this.onToggleMode,
    required this.onDemo,
    this.error,
    this.info,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController email;
  final TextEditingController password;
  final TextEditingController displayName;
  final bool isSignUp;
  final bool obscure;
  final bool isLoading;
  final bool consent;
  final bool consentError;
  final VoidCallback onToggleObscure;
  final ValueChanged<bool> onConsentChanged;
  final VoidCallback onSubmit;
  final VoidCallback onToggleMode;
  final VoidCallback onDemo;
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
              isSignUp ? AppStrings.signUpAction : AppStrings.appTitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: AppSpace.sm),
            Text(
              isSignUp
                  ? AppStrings.signUpSubtitle
                  : AppStrings.loginSubtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),
            const SizedBox(height: AppSpace.xl),

            if (isSignUp) ...[
              TextFormField(
                controller: displayName,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: AppStrings.displayNameLabel,
                  prefixIcon: Icon(LucideIcons.user),
                ),
                validator: (value) => (value ?? '').trim().isEmpty
                    ? AppStrings.nameRequired
                    : null,
              ),
              const SizedBox(height: AppSpace.lg),
            ],

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
                  : Text(
                      isSignUp
                          ? AppStrings.signUpAction
                          : AppStrings.signInAction,
                    ),
            ),

            // Dev login chỉ đăng nhập được tài khoản đã có, nên ẩn đăng ký.
            if (!AppConfig.hasDevLogin) ...[
              const SizedBox(height: AppSpace.sm),
              TextButton(
                onPressed: isLoading ? null : onToggleMode,
                child: Text(
                  isSignUp
                      ? AppStrings.switchToSignIn
                      : AppStrings.switchToSignUp,
                ),
              ),
            ],

            const SizedBox(height: AppSpace.sm),
            Row(
              children: [
                const Expanded(child: Divider(color: AppColors.divider)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
                  child: Text(
                    AppStrings.orDivider,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const Expanded(child: Divider(color: AppColors.divider)),
              ],
            ),
            const SizedBox(height: AppSpace.sm),
            TextButton(
              onPressed: isLoading ? null : onDemo,
              child: const Text(AppStrings.continueOffline),
            ),
          ],
        ),
      ),
    );
  }
}

/// Logo app. Ảnh là icon 1024×1024 trong `assets/brand/`; nếu asset hỏng thì
/// hiện biểu tượng ví để màn hình không bị trống.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 72});

  final double size;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.26),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.22),
            blurRadius: size * 0.28,
            offset: Offset(0, size * 0.09),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.26),
        child: Image.asset(
          'assets/brand/app-icon-round.png',
          width: size,
          height: size,
          filterQuality: FilterQuality.high,
          errorBuilder: (_, _, _) => Container(
            width: size,
            height: size,
            color: AppColors.primarySoft,
            child: Icon(
              LucideIcons.wallet,
              size: size * 0.5,
              color: AppColors.primaryDark,
            ),
          ),
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