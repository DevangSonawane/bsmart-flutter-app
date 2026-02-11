import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/auth/login/login_screen.dart';
import 'screens/home_dashboard.dart';
import 'theme/app_theme.dart';
import 'theme/theme_notifier.dart';
import 'theme/theme_scope.dart';
import 'state/store.dart';
import 'state/app_state.dart';
import 'config/api_config.dart';
import 'api/api.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'theme/design_tokens.dart';
import 'routes.dart';
import 'screens/post_detail_screen.dart';
import 'screens/profile_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment (if present)
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    // ignore - .env may be absent in some environments
  }

  // ── Initialize REST API config ──────────────────────────────────────────
  {
    String? apiBaseUrl;
    try {
      apiBaseUrl = dotenv.env['API_BASE_URL'];
    } catch (_) {}
    ApiConfig.init(baseUrl: apiBaseUrl);
  }

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  final store = createStore();
  final themeNotifier = await ThemeNotifier.create();
  runApp(StoreProvider<AppState>(
    store: store,
    child: ThemeScope(
      notifier: themeNotifier,
      child: const BSmartApp(),
    ),
  ));
}

class BSmartApp extends StatefulWidget {
  const BSmartApp({super.key});

  @override
  State<BSmartApp> createState() => _BSmartAppState();
}

class _BSmartAppState extends State<BSmartApp> {
  bool _isInitialized = false;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    final client = ApiClient();
    final hasToken = await client.hasToken;
    bool authed = false;
    if (hasToken) {
      try {
        await AuthApi().me();
        authed = true;
      } catch (_) {
        await client.clearToken();
        authed = false;
      }
    }
    if (mounted) {
      setState(() {
        _isAuthenticated = authed;
        _isInitialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: CircularProgressIndicator(
              color: DesignTokens.instaPink,
            ),
          ),
        ),
      );
    }

    // When using home:, routes must not contain '/' (Navigator.defaultRouteName)
    final routes = Map<String, WidgetBuilder>.from(appRoutes)..remove('/');
    final isDark = ThemeScope.of(context).isDark;
    return MaterialApp(
      title: 'b Smart',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      darkTheme: AppTheme.darkTheme,
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      home: _isAuthenticated ? const HomeDashboard() : const LoginScreen(),
      routes: routes,
      onGenerateRoute: (settings) {
        final name = settings.name ?? '';
        final uri = Uri.parse(name);
        final segments = uri.pathSegments;
        // /post/:postId
        if (segments.length == 2 && segments[0] == 'post') {
          final postId = segments[1];
          return MaterialPageRoute<void>(
            builder: (ctx) => PostDetailScreen(postId: postId),
            settings: settings,
          );
        }
        // /profile/:userId
        if (segments.length == 2 && segments[0] == 'profile') {
          final userId = segments[1];
          return MaterialPageRoute<void>(
            builder: (ctx) => ProfileScreen(userId: userId),
            settings: settings,
          );
        }
        return null;
      },
    );
  }
}
