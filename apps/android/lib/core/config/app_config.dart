/// Cấu hình tĩnh của app. Đọc từ `--dart-define`, không hardcode.
///
/// Chạy dev với API local:
/// ```
/// flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000
/// ```
/// `10.0.2.2` là địa chỉ của máy host nhìn từ emulator Android. Trên máy thật
/// phải dùng IP LAN của máy tính, ví dụ `http://192.168.1.10:3000`.
class AppConfig {
  const AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000',
  );

  /// Supabase dùng cho đăng nhập. Để trống thì app chạy chế độ offline/demo.
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );

  /// Token tiêm thẳng khi chạy dev, **chỉ dùng ở debug build**:
  ///
  /// ```
  /// flutter run --dart-define=DEV_ACCESS_TOKEN=<jwt>
  /// ```
  /// Mục đích: xem dữ liệu thật trên emulator khi chưa có anon key Supabase.
  /// Release/profile không bao giờ dùng giá trị này (`kDebugMode` chặn).
  static const String devAccessToken = String.fromEnvironment(
    'DEV_ACCESS_TOKEN',
  );

  /// Mật khẩu dùng chung của endpoint `POST /v1/dev/login` (chỉ có ở server
  /// dev). Có giá trị này thì app đăng nhập qua API local thay vì Supabase —
  /// đủ để kiểm luồng đăng nhập thật bằng tài khoản có dữ liệu.
  ///
  /// Không bao giờ đặt giá trị này trong bản release: endpoint dev tự tắt khi
  /// server chạy `NODE_ENV=production`.
  static const String devLoginPassword = String.fromEnvironment(
    'DEV_LOGIN_PASSWORD',
  );

  /// Chưa cấu hình Supabase thì không thể đăng nhập thật.
  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Đăng nhập qua API dev thay vì Supabase.
  static bool get hasDevLogin => !hasSupabase && devLoginPassword.isNotEmpty;

  /// Có ít nhất một đường đăng nhập. Không có thì app không dùng được: không
  /// còn chế độ xem dữ liệu mẫu để rơi về.
  static bool get canSignIn => hasSupabase || hasDevLogin;

  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 20);
}