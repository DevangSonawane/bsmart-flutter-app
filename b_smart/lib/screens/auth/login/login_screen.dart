import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../theme/instagram_theme.dart';
import '../../../widgets/clay_container.dart';
import '../../../services/auth/auth_service.dart';
import '../../../utils/validators.dart';
import '../../home_dashboard.dart';
import '../signup/signup_identifier_screen.dart';
import '../../../models/auth/signup_session_model.dart';

enum LoginMethod {
  username,
  email,
  phone,
  google,
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _otpController = TextEditingController();

  LoginMethod _selectedMethod = LoginMethod.email;
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  bool _isOTPSent = false;
  SignupSession? _phoneLoginSession;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _otpController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_selectedMethod == LoginMethod.phone && !_isOTPSent) {
        // Send OTP for phone login
        final session = await _authService.loginWithPhone(_phoneController.text.trim());
        setState(() {
          _isOTPSent = true;
          _phoneLoginSession = session;
        });
        return;
      }

      if (_selectedMethod == LoginMethod.phone && _isOTPSent && _phoneLoginSession != null) {
        // Complete phone login with OTP
        await _authService.completePhoneLogin(
          _phoneLoginSession!.sessionToken,
          _otpController.text.trim(),
        );
        _navigateToHome();
        return;
      }

      // Email, Username, or Google login
      if (_selectedMethod == LoginMethod.email) {
        await _authService.loginWithEmail(
          _emailController.text.trim(),
          _passwordController.text,
        );
      } else if (_selectedMethod == LoginMethod.username) {
        await _authService.loginWithUsername(
          _usernameController.text.trim(),
          _passwordController.text,
        );
      } else if (_selectedMethod == LoginMethod.google) {
        await _authService.loginWithGoogle();
      }

      _navigateToHome();
    } catch (e) {
      _showError(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleGoogleLogin() async {
    setState(() => _isLoading = true);
    print('hgfd');
    try {
      await _authService.loginWithGoogle();
      _navigateToHome();
    } catch (e) {
      print('error-> $e');
      _showError(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _navigateToHome() {
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const HomeDashboard(),
        ),
      );
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: InstagramTheme.errorRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;
    final maxWidth = isTablet ? 500.0 : size.width;
    final successMessage = ModalRoute.of(context)?.settings.arguments as String?;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: InstagramTheme.responsivePadding(context),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 40),
                      if (successMessage != null && successMessage.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.green.shade100),
                            ),
                            child: Row(
                              children: [
                                Icon(LucideIcons.circleCheck, color: Colors.green.shade700, size: 20),
                                const SizedBox(width: 8),
                                Expanded(child: Text(successMessage, style: TextStyle(color: Colors.green.shade800, fontSize: 13))),
                              ],
                            ),
                          ),
                        ),
                      // Logo
                      Center(
                        child: ClayContainer(
                          width: 100,
                          height: 100,
                          borderRadius: 50,
                          child: Center(
                            child: Icon(
                              LucideIcons.bot,
                              size: 48,
                              color: InstagramTheme.primaryPink,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        'b Smart',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.displayLarge,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Welcome back',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 64),

                      // Method Selection Tabs
                      if (!_isOTPSent || _selectedMethod != LoginMethod.phone)
                        Row(
                          children: [
                            Expanded(
                              child: _buildMethodTab('Username', LoginMethod.username),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildMethodTab('Email', LoginMethod.email),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildMethodTab('Phone', LoginMethod.phone),
                            ),
                          ],
                        ),
                      if (!_isOTPSent || _selectedMethod != LoginMethod.phone)
                        const SizedBox(height: 24),

                      // Username/Email/Phone Input
                      if (_selectedMethod == LoginMethod.username && (!_isOTPSent || _selectedMethod != LoginMethod.phone))
                        TextFormField(
                          controller: _usernameController,
                          style: const TextStyle(color: InstagramTheme.textBlack),
                          decoration: InputDecoration(
                            labelText: 'Username',
                            hintText: 'Enter your username',
                            prefixIcon: Icon(LucideIcons.mail),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your username';
                            }
                            return null;
                          },
                        )
                      else if (_selectedMethod == LoginMethod.email && (!_isOTPSent || _selectedMethod != LoginMethod.phone))
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: const TextStyle(color: InstagramTheme.textBlack),
                          decoration: InputDecoration(
                            labelText: 'Email',
                            hintText: 'Enter your email',
                            prefixIcon: Icon(LucideIcons.mail),
                          ),
                          validator: Validators.validateEmail,
                        )
                      else if (_selectedMethod == LoginMethod.phone)
                        if (!_isOTPSent)
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            style: const TextStyle(color: InstagramTheme.textBlack),
                            decoration: InputDecoration(
                              labelText: 'Phone Number',
                              hintText: '+1234567890',
                              prefixIcon: Icon(LucideIcons.phone),
                            ),
                            validator: Validators.validatePhone,
                          )
                        else
                          Column(
                            children: [
                              Text(
                                'OTP sent to ${_phoneController.text}',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 24),
                              TextFormField(
                                controller: _otpController,
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: InstagramTheme.textBlack,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 8,
                                ),
                                maxLength: 6,
                                decoration: InputDecoration(
                                  labelText: 'Enter OTP',
                                  hintText: '000000',
                                  counterText: '',
                                  prefixIcon: Icon(LucideIcons.lock),
                                ),
                                validator: Validators.validateOTP,
                              ),
                            ],
                          ),
                      if ((_selectedMethod == LoginMethod.email || _selectedMethod == LoginMethod.username) && (!_isOTPSent || _selectedMethod != LoginMethod.phone)) ...[
                        const SizedBox(height: 20),
                        // Password Field
                        TextFormField(
                          controller: _passwordController,
                          obscureText: !_isPasswordVisible,
                          style: const TextStyle(color: InstagramTheme.textBlack),
                          decoration: InputDecoration(
                            labelText: 'Password',
                            hintText: 'Enter your password',
                            prefixIcon: Icon(LucideIcons.lock),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _isPasswordVisible
                                    ? LucideIcons.eye                                    : LucideIcons.eyeOff,
                                color: InstagramTheme.textGrey,
                              ),
                              onPressed: () {
                                setState(() {
                                  _isPasswordVisible = !_isPasswordVisible;
                                });
                              },
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your password';
                            }
                            if (value.length < 6) {
                              return 'Password must be at least 6 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        // Forgot Password
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
                              Navigator.of(context).pushNamed('/forgot-password');
                            },
                            child: const Text('Forgot Password?'),
                          ),
                        ),
                      ],
                      const SizedBox(height: 40),

                      // Login Button
                      SizedBox(
                        height: 56,
                        child: ClayButton(
                          onPressed: _isLoading ? null : _handleLogin,
                          child: _isLoading
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        InstagramTheme.textWhite),
                                  ),
                                )
                              : Text(_isOTPSent && _selectedMethod == LoginMethod.phone
                                  ? 'VERIFY & LOGIN'
                                  : 'LOGIN'),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Divider
                      Row(
                        children: [
                          Expanded(
                            child: Divider(color: InstagramTheme.dividerGrey),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'OR',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontSize: 12,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Divider(color: InstagramTheme.dividerGrey),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),

                      // Google Sign In Button
                      SizedBox(
                        height: 56,
                        child: OutlinedButton.icon(
                          onPressed: _isLoading ? null : _handleGoogleLogin,
                          icon: const Icon(Icons.g_mobiledata, size: 28),
                          label: const Text('Continue with Google'),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: InstagramTheme.borderGrey),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Sign Up Link
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Don't have an account? ",
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => const SignupIdentifierScreen(),
                                ),
                              );
                            },
                            child: const Text('Sign Up'),
                          ),
                        ],
                      ),
                      SizedBox(height: isTablet ? 40 : 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMethodTab(String label, LoginMethod method) {
    final isSelected = _selectedMethod == method;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedMethod = method;
          _isOTPSent = false;
          _phoneLoginSession = null;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? InstagramTheme.primaryPink.withValues(alpha: 0.1)
              : InstagramTheme.surfaceWhite,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? InstagramTheme.primaryPink
                : InstagramTheme.borderGrey,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected
                ? InstagramTheme.primaryPink
                : InstagramTheme.textGrey,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
