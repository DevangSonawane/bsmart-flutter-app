 import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/auth/login/login_screen.dart';
import 'screens/home_dashboard.dart';
import 'theme/app_theme.dart';
import 'state/store.dart';
import 'state/app_state.dart';
import 'config/supabase_config.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'theme/design_tokens.dart';
import 'routes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment (if present)
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    // ignore - .env may be absent in some environments
  }
  // Initialize SupabaseConfig from dotenv if available (safe access)
  {
    String? url;
    String? anonKey;
    String? googleWebClientId;
    String? googleAndroidClientId;
    String? googleIosClientId;
    try {
      url = dotenv.env['SUPABASE_URL'];
      anonKey = dotenv.env['SUPABASE_ANON_KEY'];
      googleWebClientId = dotenv.env['GOOGLE_WEB_CLIENT_ID'];
      googleAndroidClientId = dotenv.env['GOOGLE_ANDROID_CLIENT_ID'];
      googleIosClientId = dotenv.env['GOOGLE_IOS_CLIENT_ID'];
    } catch (_) {
      // dotenv not initialized or unavailable; leave values null to use defaults
    }
    SupabaseConfig.init(
      url: url,
      anonKey: anonKey,
      googleWebClientId: googleWebClientId,
      googleAndroidClientId: googleAndroidClientId,
      googleIosClientId: googleIosClientId,
    );
  }

  // Initialize Supabase
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  final store = createStore();
  runApp(StoreProvider<AppState>(
    store: store,
    child: const BSmartApp(),
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
    // Check current session from Supabase
    final session = Supabase.instance.client.auth.currentSession;
    setState(() {
      _isAuthenticated = session != null;
      _isInitialized = true;
    });

    // Listen for auth state changes
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (mounted) {
        setState(() {
          _isAuthenticated = data.session != null;
        });
      }
    });
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
    return MaterialApp(
      title: 'b Smart',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: _isAuthenticated ? const HomeDashboard() : const LoginScreen(),
      routes: routes,
    );
  }
}
