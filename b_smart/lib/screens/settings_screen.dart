import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:b_smart/core/lucide_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/design_tokens.dart';
import 'auth/login/login_screen.dart';

/// Settings: Preferences, Account, About sections + Log out.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _loggingOut = false;

  Future<void> _logout() async {
    setState(() => _loggingOut = true);
    try {
      await Supabase.instance.client.auth.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _loggingOut = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(LucideIcons.arrowLeft.localLucide),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionTitle('Preferences'),
          _settingTile(icon: LucideIcons.globe.localLucide, label: 'Language / Region', subLabel: 'Default: English', onTap: () {}),
          _settingTile(icon: LucideIcons.bell.localLucide, label: 'Notifications', subLabel: 'Manage notifications', onTap: () {}),
          const SizedBox(height: 24),
          _sectionTitle('Account'),
          _settingTile(icon: LucideIcons.shield.localLucide, label: 'Privacy', subLabel: 'Privacy settings', onTap: () {}),
          _settingTile(icon: LucideIcons.lock.localLucide, label: 'Security', subLabel: 'Password, 2FA', onTap: () {}),
          _settingTile(icon: LucideIcons.slidersHorizontal.localLucide, label: 'Content Settings', subLabel: 'Moderation & restrictions', onTap: () {}),
          const SizedBox(height: 24),
          _sectionTitle('About'),
          _settingTile(icon: LucideIcons.info.localLucide, label: 'About b Smart', subLabel: 'Version 1.0.0', onTap: () {}),
          _settingTile(icon: LucideIcons.info.localLucide, label: 'Help & Support', subLabel: 'Contact support', onTap: () {}),
          const SizedBox(height: 24),
          _sectionTitle('Actions'),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: _loggingOut ? null : _logout,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(color: Colors.red.shade50, shape: BoxShape.circle),
                      child: _loggingOut ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red.shade700)) : Icon(LucideIcons.logOut.localLucide, color: Colors.red.shade700, size: 20),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_loggingOut ? 'Logging out...' : 'Log Out', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.red.shade700)),
                          const SizedBox(height: 2),
                          Text('Sign out of your account', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(title.toUpperCase(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: DesignTokens.instaPink, letterSpacing: 0.5)),
    );
  }

  Widget _settingTile({required IconData icon, required String label, String? subLabel, VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: DesignTokens.instaPink.withOpacity(0.12), shape: BoxShape.circle),
                  child: Icon(icon, color: DesignTokens.instaPink, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
                      if (subLabel != null) ...[
                        const SizedBox(height: 2),
                        Text(subLabel, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      ],
                    ],
                  ),
                ),
                Icon(LucideIcons.chevronRight.localLucide, color: Colors.grey.shade400, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
