import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:b_smart/core/lucide_local.dart';
import '../../theme/design_tokens.dart';
import '../../services/supabase_service.dart';

/// 3-step flow: find account by email → verify OTP (recovery) → new password.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final SupabaseService _supabase = SupabaseService();
  final _client = Supabase.instance.client;

  int _step = 1;
  bool _loading = false;
  String _error = '';

  // Step 1
  final _emailController = TextEditingController();
  Map<String, dynamic>? _foundUser;

  // Step 2
  final _otpController = TextEditingController();

  // Step 3
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _findAccount() async {
    setState(() {
      _error = '';
      _loading = true;
    });
    try {
      final email = _emailController.text.trim();
      final user = await _supabase.getUserByEmail(email);
      if (user == null) {
        throw Exception('No account found with this email address');
      }
      setState(() => _foundUser = user);

      await _client.auth.resetPasswordForEmail(email);
      if (mounted) setState(() {
        _step = 2;
        _loading = false;
      });
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      if (msg.contains('rate limit') || msg.contains('429') || msg.contains('over_email_send_rate_limit')) {
        setState(() {
          _error = 'Email rate limit reached. Please use the code you received previously.';
          _step = 2;
        });
      } else {
        setState(() {
          _error = msg;
        });
      }
      setState(() => _loading = false);
    }
  }

  Future<void> _verifyOtp() async {
    setState(() {
      _error = '';
      _loading = true;
    });
    try {
      final res = await _client.auth.verifyOTP(
        type: OtpType.recovery,
        token: _otpController.text.trim(),
        email: _foundUser!['email'] as String,
      );
      if (res.session != null && mounted) {
        setState(() {
          _step = 3;
          _loading = false;
        });
      } else {
        throw Exception('Verification failed. Please try again.');
      }
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '').replaceFirst('AuthException: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _resetPassword() async {
    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;
    if (password != confirm) {
      setState(() => _error = 'Passwords do not match');
      return;
    }
    setState(() {
      _error = '';
      _loading = true;
    });
    try {
      await _client.auth.updateUser(UserAttributes(password: password));
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login', arguments: 'Password updated successfully! Please log in.');
      }
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '').replaceFirst('AuthException: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignTokens.instaPink.withOpacity(0.04),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              children: [
                TextButton.icon(
                  onPressed: () => Navigator.of(context).pushReplacementNamed('/login'),
                  icon: Icon(LucideIcons.arrowLeft.localLucide, size: 20),
                  label: const Text('Back to Login'),
                  style: TextButton.styleFrom(foregroundColor: Colors.grey.shade700),
                ),
                const SizedBox(height: 24),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 4)),
                    ],
                  ),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Progress bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: _step / 3,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: const AlwaysStoppedAnimation<Color>(DesignTokens.instaPink),
                          minHeight: 6,
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (_error.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.red.shade100),
                            ),
                            child: Row(
                              children: [
                                Icon(LucideIcons.circleAlert.localLucide, color: Colors.red.shade700, size: 20),
                                const SizedBox(width: 8),
                                Expanded(child: Text(_error, style: TextStyle(color: Colors.red.shade700, fontSize: 13))),
                              ],
                            ),
                          ),
                        ),
                      if (_step == 1) _buildStep1(),
                      if (_step == 2) _buildStep2(),
                      if (_step == 3) _buildStep3(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Find Your Account', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('Enter your email address to search for your account.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
        const SizedBox(height: 24),
        Text('Email Address', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.grey.shade700)),
        const SizedBox(height: 6),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            hintText: 'Enter your email',
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _loading ? null : _findAccount,
          style: FilledButton.styleFrom(
            backgroundColor: DesignTokens.instaPink,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _loading ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Find Account'),
        ),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(LucideIcons.shieldCheck.localLucide, size: 48, color: DesignTokens.instaPink),
        const SizedBox(height: 16),
        const Text("Verify it's you", textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('We sent a code to ${_emailController.text.trim()}', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
        if (_foundUser != null) ...[
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade100)),
            child: Row(
              children: [
                CircleAvatar(radius: 24, backgroundImage: _foundUser!['avatar_url'] != null ? NetworkImage(_foundUser!['avatar_url'] as String) : null, child: _foundUser!['avatar_url'] == null ? Text('${(_foundUser!['username'] ?? 'U').toString().substring(0, 1).toUpperCase()}') : null),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${_foundUser!['full_name'] ?? _foundUser!['username']}', style: const TextStyle(fontWeight: FontWeight.bold)), Text('${_foundUser!['email']}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600))])),
                Icon(LucideIcons.circleCheck.localLucide, color: Colors.green, size: 22),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        Text('Verification Code', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.grey.shade700)),
        const SizedBox(height: 6),
        TextField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 22, letterSpacing: 8, fontFamily: 'monospace'),
          decoration: InputDecoration(
            hintText: '000000',
            counterText: '',
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _loading ? null : _verifyOtp,
          style: FilledButton.styleFrom(
            backgroundColor: DesignTokens.instaPink,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _loading ? const Text('Verifying...') : const Text('Verify Code'),
        ),
      ],
    );
  }

  Widget _buildStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(LucideIcons.circleCheck.localLucide, size: 48, color: Colors.green),
        const SizedBox(height: 16),
        const Text('Reset Password', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('Create a new strong password for your account.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
        const SizedBox(height: 24),
        Text('New Password', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.grey.shade700)),
        const SizedBox(height: 6),
        TextField(
          controller: _passwordController,
          obscureText: true,
          decoration: InputDecoration(
            hintText: 'New password',
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
        const SizedBox(height: 16),
        Text('Confirm Password', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.grey.shade700)),
        const SizedBox(height: 6),
        TextField(
          controller: _confirmPasswordController,
          obscureText: true,
          decoration: InputDecoration(
            hintText: 'Confirm new password',
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _loading ? null : _resetPassword,
          style: FilledButton.styleFrom(
            backgroundColor: DesignTokens.instaPink,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _loading ? const Text('Updating...') : const Text('Update Password'),
        ),
      ],
    );
  }
}
