import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// ==========================
// QUICK SETUP
// Add to pubspec.yaml:
// dependencies:
//   google_sign_in: ^6.2.1
//   http: ^1.2.2
//   flutter_secure_storage: ^9.2.2
// Then: flutter pub get
// Android: register SHA-1/256 in Google Cloud Console (OAuth Client)
// iOS: URL Schemes for reversed client id
// ==========================

// Build-time API base url:  --dart-define=API_BASE_URL=https://api.example.com
const String kApiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'https://api.example.com');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Google Sign-In (Route A)',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.pink),
      home: const AuthGate(),
    );
  }
}

// ==========================
// SESSION STORAGE
// ==========================
class SessionStore {
  static const _kAccess = 'access_token';
  static const _kRefresh = 'refresh_token';
  final _storage = const FlutterSecureStorage();

  Future<void> save(String access, String? refresh) async {
    await _storage.write(key: _kAccess, value: access);
    if (refresh != null) {
      await _storage.write(key: _kRefresh, value: refresh);
    }
  }

  Future<String?> get access async => _storage.read(key: _kAccess);
  Future<String?> get refresh async => _storage.read(key: _kRefresh);

  Future<void> clear() async {
    await _storage.delete(key: _kAccess);
    await _storage.delete(key: _kRefresh);
  }
}

// ==========================
// API CLIENT with auto Authorization header & refresh
// ==========================
class ApiClient extends http.BaseClient {
  final String baseUrl;
  final SessionStore session;
  final http.Client _inner = http.Client();
  ApiClient(this.baseUrl, this.session);

  Future<http.StreamedResponse> _sendWithToken(http.BaseRequest request) async {
    final token = await session.access;
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    request.headers['Content-Type'] = request.headers['Content-Type'] ?? 'application/json';
    return _inner.send(request);
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    var res = await _sendWithToken(request);
    if (res.statusCode == 401) {
      final ok = await _tryRefresh();
      if (ok) {
        // Rebuild request (body may be already consumed)
        final retry = http.Request(request.method, request.url)
          ..headers.addAll(request.headers);
        if (request is http.Request) {
          retry.bodyBytes = request.bodyBytes;
        }
        return _sendWithToken(retry);
      }
    }
    return res;
  }

  Future<bool> _tryRefresh() async {
    final r = await session.refresh;
    if (r == null) return false;
    final resp = await _inner.post(
      Uri.parse('$baseUrl/auth/refresh'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refresh_token': r}),
    );
    if (resp.statusCode != 200) return false;
    final body = jsonDecode(resp.body);
    await session.save(body['access_token'] as String, body['refresh_token'] as String?);
    return true;
  }

  Future<http.Response> getJson(String path) async {
    final req = http.Request('GET', Uri.parse('$baseUrl$path'));
    final streamed = await send(req);
    return http.Response.fromStream(streamed);
  }

  Future<http.Response> postJson(String path, Map<String, dynamic> data) async {
    final req = http.Request('POST', Uri.parse('$baseUrl$path'))
      ..headers['Content-Type'] = 'application/json'
      ..body = jsonEncode(data);
    final streamed = await send(req);
    return http.Response.fromStream(streamed);
  }
}

// ==========================
// AUTH REPOSITORY (Route A)
// ==========================
class AuthRepo {
  final _google = GoogleSignIn(scopes: ['email', 'profile']);
  final SessionStore session;
  final String baseUrl;
  AuthRepo(this.session, this.baseUrl);

  Future<void> signInWithGoogle() async {
    final account = await _google.signIn();
    if (account == null) throw Exception('로그인이 취소되었습니다.');
    final auth = await account.authentication;

    final res = await http.post(
      Uri.parse('$baseUrl/auth/google'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'id_token': auth.idToken,
        'client_type': 'flutter-mobile',
      }),
    );
    if (res.statusCode != 200) {
      throw Exception('서버 인증 실패: ${res.statusCode} ${res.body}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    await session.save(body['access_token'] as String, body['refresh_token'] as String?);
  }

  Future<void> signOut(ApiClient api) async {
    try {
      await api.postJson('/auth/logout', {});
    } catch (_) {}
    await GoogleSignIn().signOut();
    await session.clear();
  }
}

// ==========================
// AUTH GATE
// ==========================
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final SessionStore _session;
  late final ApiClient _api;
  late final AuthRepo _auth;
  Future<bool>? _future;

  @override
  void initState() {
    super.initState();
    _session = SessionStore();
    _api = ApiClient(kApiBaseUrl, _session);
    _auth = AuthRepo(_session, kApiBaseUrl);
    _future = _check();
  }

  Future<bool> _check() async {
    final t = await _session.access;
    if (t == null) return false;
    final res = await _api.getJson('/me');
    return res.statusCode == 200;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _future,
      builder: (context, s) {
        if (!s.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return s.data! ? HomeScreen(api: _api, auth: _auth) : LoginScreen(auth: _auth, api: _api);
      },
    );
  }
}

// ==========================
// LOGIN SCREEN (Real Page Widget)
// ==========================
class LoginScreen extends StatefulWidget {
  final AuthRepo auth;
  final ApiClient api;
  const LoginScreen({super.key, required this.auth, required this.api});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _loading = false;

  Future<void> _handleGoogle() async {
    setState(() => _loading = true);
    try {
      await widget.auth.signInWithGoogle();
      if (!mounted) return;
      // 인증 성공 → /me 확인 후 홈으로 이동
      final ok = await widget.api.getJson('/me');
      if (ok.statusCode == 200 && mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => HomeScreen(api: widget.api, auth: widget.auth)),
        );
      } else {
        throw Exception('세션 확인 실패');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('로그인 실패: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const FlutterLogo(size: 84),
                  const SizedBox(height: 24),
                  Text('구글로 로그인', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  const Text('Google 계정으로 안전하게 로그인합니다.'),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _loading ? null : _handleGoogle,
                      icon: const Icon(Icons.login),
                      label: Text(_loading ? '로그인 중…' : 'Google로 계속하기'),
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================
// HOME SCREEN (with sign-out)
// ==========================
class HomeScreen extends StatelessWidget {
  final ApiClient api;
  final AuthRepo auth;
  const HomeScreen({super.key, required this.api, required this.auth});

  Future<Map<String, dynamic>> _loadMe() async {
    final r = await api.getJson('/me');
    if (r.statusCode != 200) throw Exception('유저 정보 로드 실패');
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('홈'),
        actions: [
          IconButton(
            tooltip: '로그아웃',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await auth.signOut(api);
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => LoginScreen(auth: auth, api: api)),
                  (_) => false,
                );
              }
            },
          )
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _loadMe(),
        builder: (context, s) {
          if (!s.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final me = s.data!;
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (me['picture'] != null)
                  CircleAvatar(radius: 32, backgroundImage: NetworkImage(me['picture'] as String)),
                const SizedBox(height: 12),
                Text(me['name']?.toString() ?? '이름 없음', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                Text(me['email']?.toString() ?? ''),
                const SizedBox(height: 8),
                Text('uid: ${me['uid'] ?? '-'}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          );
        },
      ),
    );
  }
}
