/// Login screen widget for Solid Pod authentication.
library;

import 'package:flutter/material.dart';
import 'package:solid_crdt_sync_core/solid_crdt_sync_core.dart';

/// A complete login screen for Solid Pod authentication.
/// 
/// This widget provides the UI for authenticating with a Solid Pod,
/// including provider selection and the authentication flow.
class SolidLoginScreen extends StatefulWidget {
  final SolidAuthProvider authProvider;
  final VoidCallback? onLoginSuccess;
  final Function(String)? onLoginError;

  const SolidLoginScreen({
    super.key,
    required this.authProvider,
    this.onLoginSuccess,
    this.onLoginError,
  });

  @override
  State<SolidLoginScreen> createState() => _SolidLoginScreenState();
}

class _SolidLoginScreenState extends State<SolidLoginScreen> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect to Solid Pod'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.cloud,
              size: 80,
              color: Colors.blue,
            ),
            const SizedBox(height: 32),
            const Text(
              'Connect to your Solid Pod',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'Sign in to access your personal data stored in your Solid Pod.',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isLoading ? null : _handleLogin,
              child: _isLoading 
                  ? const CircularProgressIndicator()
                  : const Text('Sign In'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleLogin() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // TODO: Implement actual login flow once solid-auth is integrated
      await Future.delayed(const Duration(seconds: 2)); // Simulate login
      
      if (mounted) {
        widget.onLoginSuccess?.call();
      }
    } catch (error) {
      if (mounted) {
        widget.onLoginError?.call(error.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}