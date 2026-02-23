import 'package:flutter/widgets.dart';
import 'screens/auth/login/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/auth/verify_otp_screen.dart';
import 'screens/home_dashboard.dart';
import 'screens/create_screen.dart';
import 'screens/create_upload_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/reels_screen.dart';
import 'screens/ads_screen.dart';
import 'screens/promote_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/wallet_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/auth_callback_screen.dart';
import 'screens/story_camera_screen.dart';
import 'screens/own_story_viewer_screen.dart';
import '../models/media_model.dart';
import 'screens/edit_video_screen.dart';

/// Centralized route definitions matching the React app structure.
final Map<String, WidgetBuilder> appRoutes = {
  '/login': (ctx) => const LoginScreen(),
  '/signup': (ctx) => const SignupScreen(),
  '/forgot-password': (ctx) => const ForgotPasswordScreen(),
  '/verify-otp': (ctx) {
    final email = ModalRoute.of(ctx)?.settings.arguments as String?;
    return VerifyOtpScreen(email: email);
  },
  '/home': (ctx) => const HomeDashboard(),
  // Do not add '/' here when MaterialApp uses home: - it would be redundant and trigger an assertion
  '/create_post': (ctx) => const CreateUploadScreen(
        initialMode: UploadMode.post,
      ),
  '/create': (ctx) => const CreateScreen(),
  '/profile': (ctx) => const ProfileScreen(),
  '/reels': (ctx) => const ReelsScreen(),
  '/ads': (ctx) => const AdsScreen(),
  '/promote': (ctx) => const PromoteScreen(),
  '/settings': (ctx) => const SettingsScreen(),
  '/wallet': (ctx) => const WalletScreen(),
  '/notifications': (ctx) => const NotificationsScreen(),
  '/auth/google/success': (ctx) => const AuthCallbackScreen(),
  '/edit-profile': (ctx) {
    return const EditProfileScreen(userId: '');
  },
  '/story-camera': (ctx) => const StoryCameraScreen(),
  '/own-story-viewer': (ctx) {
    return OwnStoryViewerScreen(stories: const [], userName: 'You');
  },
  '/edit_video': (ctx) {
    final args = ModalRoute.of(ctx)?.settings.arguments;
    final media = args is MediaItem ? args : null;
    return EditVideoScreen(media: media!);
  },
};
