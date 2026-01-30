import 'package:flutter/material.dart';
import '../../services/auth/auth_service.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({Key? key}) : super(key: key);

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _message;

  Future<void> _signup() async {
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      await AuthService().signupWithEmail(_emailController.text.trim(), _passwordController.text);
      setState(() {
        _message = 'Signup initiated. Please check email for verification (if configured).';
      });
    } catch (e) {
      setState(() {
        _message = 'Signup failed: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign up')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            if (_message != null) Text(_message!),
            ElevatedButton(
              onPressed: _loading ? null : _signup,
              child: _loading ? const CircularProgressIndicator() : const Text('Sign up'),
            ),
          ],
        ),
      ),
    );
  }
}

