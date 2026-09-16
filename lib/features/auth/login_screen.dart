import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/errors/app_exception.dart';
import '../../services/store/app_store.dart';
import '../../shared/widgets/forms.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _LoginBody();
  }
}

class _LoginBody extends StatefulWidget {
  const _LoginBody();

  @override
  State<_LoginBody> createState() => _LoginBodyState();
}

class _LoginBodyState extends State<_LoginBody> {
  final _form = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _displayName = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _obscure = true;
  bool _obscureConfirm = true;
  bool _isRegister = false;
  bool _busy = false;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _displayName.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final store = context.read<AppStore>();
      if (_isRegister) {
        await _register(store);
      } else {
        await store.login(_username.text.trim(), _password.text);
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _register(AppStore store) async {
    final username = _username.text.trim();
    final password = _password.text;
    final confirmPassword = _confirmPassword.text;
    final displayName = _displayName.text.trim();

    if (username.isEmpty) throw ValidationException('Username is required.');
    if (password.isEmpty) throw ValidationException('Password is required.');
    if (password != confirmPassword) throw ValidationException('Passwords do not match.');
    if (password.length < 4) throw ValidationException('Password must be at least 4 characters.');
    if (displayName.isEmpty) throw ValidationException('Display name is required.');

    await store.registerUser(
      username: username,
      password: password,
      displayName: displayName,
    );

    // Auto-login after registration
    await store.login(username, password);
  }

  void _toggleMode() {
    setState(() {
      _isRegister = !_isRegister;
      _form.currentState?.reset();
      _username.clear();
      _password.clear();
      _displayName.clear();
      _confirmPassword.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isWide = MediaQuery.of(context).size.width >= 840;

    final form = Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.eco, size: 52, color: scheme.primary),
          const SizedBox(height: 12),
          Text(
            AppConstants.appName,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            'Farm Work, Payment & Collection Management',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 28),
          TextFormField(
            controller: _username,
            decoration: const InputDecoration(labelText: 'Username', prefixIcon: Icon(Icons.person_outline)),
            validator: Validators.required,
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.none,
          ),
          const SizedBox(height: 12),
          if (_isRegister) ...[
            TextFormField(
              controller: _displayName,
              decoration: const InputDecoration(labelText: 'Display Name', prefixIcon: Icon(Icons.badge_outlined)),
              validator: Validators.required,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
          ],
          TextFormField(
            controller: _password,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            onFieldSubmitted: (_) => _submit(),
            validator: _isRegister
                ? (v) {
                    if (v == null || v.isEmpty) return 'Password is required.';
                    if (v.length < 4) return 'Password must be at least 4 characters.';
                    return null;
                  }
                : Validators.required,
            textInputAction: _isRegister ? TextInputAction.next : TextInputAction.done,
          ),
          if (_isRegister) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirmPassword,
              obscureText: _obscureConfirm,
              decoration: InputDecoration(
                labelText: 'Confirm Password',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),
              onFieldSubmitted: (_) => _submit(),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Please confirm your password.';
                if (v != _password.text) return 'Passwords do not match.';
                return null;
              },
              textInputAction: TextInputAction.done,
            ),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _busy ? null : _submit,
            icon: Icon(_isRegister ? Icons.person_add : Icons.login),
            label: Text(_busy
                ? (_isRegister ? 'Creating account…' : 'Signing in…')
                : (_isRegister ? 'Create Account' : 'Sign In')),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _isRegister ? 'Already have an account? ' : 'Need an account? ',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              TextButton(
                onPressed: _busy ? null : _toggleMode,
                child: Text(_isRegister ? 'Sign In' : 'Create Account'),
              ),
            ],
          ),
          if (!_isRegister) ...[
            const SizedBox(height: 8),
            Text(
              'Demo: username: boss  password: 1234',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );

    final card = Container(
      constraints: const BoxConstraints(maxWidth: 420),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: scheme.shadow.withValues(alpha: 0.08), blurRadius: 30, offset: const Offset(0, 10)),
        ],
      ),
      child: form,
    );

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              scheme.primary.withValues(alpha: 0.12),
              scheme.surface,
              scheme.tertiary.withValues(alpha: 0.08),
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: isWide ? card : card,
          ),
        ),
      ),
    );
  }
}