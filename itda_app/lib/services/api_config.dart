class ApiConfig {
  // 실제 기기 테스트용 (ngrok 고정 도메인)
  //static const String baseUrl = 'https://bibless-ingrid-unmurmured.ngrok-free.dev/api/v1';

  // Android 에뮬레이터에서 localhost 접근
  static const String baseUrl = 'http://10.0.2.2:8000/api/v1';

  // iOS 시뮬레이터 (Mac에서)
  // static const String baseUrl = 'http://localhost:8000/api/v1';

  // 실제 기기 (같은 WiFi)
  // static const String baseUrl = 'http://192.168.x.x:8000/api/v1';

  static const Duration timeout = Duration(seconds: 30);
}