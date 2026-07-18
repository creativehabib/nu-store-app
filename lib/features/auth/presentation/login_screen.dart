import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../dashboard/presentation/dashboard_screen.dart';
import 'auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _loginController = TextEditingController();
  final _passwordController = TextEditingController();
  final _twoFactorController = TextEditingController();
  bool _isPasswordVisible = false;

  Future<void> _handleLogin() async {
    final login = _loginController.text.trim();
    final password = _passwordController.text.trim();
    final twoFactorCode = _twoFactorController.text.trim();

    if (login.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter email/PF No and password.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    await ref.read(authControllerProvider.notifier).login(
          login,
          password,
          twoFactorCode: twoFactorCode.isEmpty ? null : twoFactorCode,
        );

    final state = ref.read(authControllerProvider);
    if (!mounted) return;
    if (state.isAuthenticated) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DashboardScreen()));
    } else if (state.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.errorMessage!), backgroundColor: Colors.red));
    } else if (state.requiresTwoFactor) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter your 2FA code and submit again.')));
    } else if (!state.isApproved) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Your user approval is pending.'), backgroundColor: Colors.orange));
    }
  }

  @override
  void dispose() {
    _loginController.dispose();
    _passwordController.dispose();
    _twoFactorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.white, elevation: 0),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Welcome Back', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A))),
              const SizedBox(height: 8),
              const Text('Sign in with Laravel Sanctum/Passport API token validation.'),
              const SizedBox(height: 32),
              TextField(controller: _loginController, keyboardType: TextInputType.text, decoration: const InputDecoration(labelText: 'Email Address or PF No', hintText: 'example@nu.ac.bd or PF12345', prefixIcon: Icon(Icons.badge_outlined), border: OutlineInputBorder())),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: !_isPasswordVisible,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off), onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(controller: _twoFactorController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '2FA Code (if enabled)', prefixIcon: Icon(Icons.security), border: OutlineInputBorder())),
              Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () {}, child: const Text('Forgot Password?'))),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: auth.isLoading ? null : _handleLogin,
                  child: auth.isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Login'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
