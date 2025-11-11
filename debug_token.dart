// 임시 디버깅 코드
// login_screen.dart의 86줄 다음에 추가

import 'dart:convert';

// idToken 디코딩 (서명 검증 없이 payload만 확인)
final parts = idToken.split('.');
if (parts.length == 3) {
  final payload = parts[1];
  // Base64 디코딩 (패딩 추가)
  final normalized = base64.normalize(payload);
  final decoded = utf8.decode(base64.decode(normalized));
  print('🔍 idToken payload: $decoded');
}
