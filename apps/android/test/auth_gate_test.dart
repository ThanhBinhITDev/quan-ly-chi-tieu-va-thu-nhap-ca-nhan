import 'package:android/core/session/auth_controller.dart';
import 'package:android/data/session/session_store.dart';
import 'package:android/ui/auth/auth_gate.dart';
import 'package:android/ui/strings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// Controller giả: luôn "chưa đăng nhập", không chạm secure storage.
class _SignedOutController extends AuthController {
  @override
  Future<AuthSession?> build() async => null;
}

Future<void> _pumpGate(WidgetTester tester) async {
  tester.view.physicalSize = const Size(360, 720);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(_SignedOutController.new),
      ],
      // Tắt hiệu ứng nền: `AnimationController.repeat()` khiến
      // `pumpAndSettle` chờ mãi. Người dùng bật "giảm chuyển động" trong cài
      // đặt hệ điều hành cũng đi đúng nhánh này.
      child: const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: MaterialApp(home: AuthGate()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('chưa đăng nhập thì hiện form đăng nhập', (tester) async {
    await _pumpGate(tester);

    expect(find.text(AppStrings.emailLabel), findsOneWidget);
    expect(find.text(AppStrings.passwordLabel), findsOneWidget);
    expect(find.text(AppStrings.signInAction), findsWidgets);
    expect(find.text(AppStrings.switchToSignUp), findsOneWidget);
  });

  testWidgets('email sai định dạng bị chặn ngay tại form', (tester) async {
    await _pumpGate(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, AppStrings.emailLabel),
      'khong-phai-email',
    );
    await tester.tap(find.text(AppStrings.signInAction).last);
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.emailInvalid), findsOneWidget);
  });

  testWidgets('mật khẩu ngắn bị chặn ngay tại form', (tester) async {
    await _pumpGate(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, AppStrings.emailLabel),
      'sinhvien@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, AppStrings.passwordLabel),
      '123',
    );
    await tester.tap(find.text(AppStrings.signInAction).last);
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.passwordTooShort), findsOneWidget);
  });

  testWidgets('chưa đồng ý điều khoản thì không đăng nhập được',
      (tester) async {
    await _pumpGate(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, AppStrings.emailLabel),
      'test@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, AppStrings.passwordLabel),
      'sftp-dev-login-2026',
    );
    await tester.tap(find.text(AppStrings.signInAction).last);
    await tester.pumpAndSettle();

    // Form hợp lệ nhưng thiếu đồng ý: phải chặn và nói rõ lý do.
    expect(find.text(AppStrings.consentRequired), findsOneWidget);
    expect(find.text(AppStrings.emailInvalid), findsNothing);
  });

  testWidgets('ô đồng ý mặc định không được tích sẵn', (tester) async {
    await _pumpGate(tester);

    final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
    expect(checkbox.value, isFalse);
    expect(find.textContaining(AppStrings.termsOfUse), findsWidgets);
    expect(find.textContaining(AppStrings.privacyPolicy), findsWidgets);
  });

  testWidgets('bật chế độ đăng ký thì hiện ô tên hiển thị', (tester) async {
    await _pumpGate(tester);

    await tester.tap(find.text(AppStrings.switchToSignUp));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.displayNameLabel), findsOneWidget);
    expect(find.text(AppStrings.switchToSignIn), findsOneWidget);
  });
}