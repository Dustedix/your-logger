import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../services/totp_service.dart';
import '../theme/app_theme.dart';
import '../models/user_account.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback? onLoginSuccess;

  const LoginScreen({super.key, this.onLoginSuccess});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _auth = AuthService();
  bool _isRegistering = false;

  // Login controllers
  final TextEditingController _loginUsernameController = TextEditingController();
  final TextEditingController _loginCodeController = TextEditingController();
  String? _loginError;
  bool _isVerifying = false;

  // Registration state
  final TextEditingController _regUsernameController = TextEditingController();
  final TextEditingController _regDisplayNameController = TextEditingController();
  final TextEditingController _regCodeController = TextEditingController();
  String? _generatedSecret;
  String? _otpAuthUri;
  String? _regError;
  bool _isRegisterVerifying = false;

  @override
  void initState() {
    super.initState();
    final accounts = _auth.savedAccounts;
    if (accounts.isNotEmpty) {
      _loginUsernameController.text = accounts.first.username;
    }
  }

  @override
  void dispose() {
    _loginUsernameController.dispose();
    _loginCodeController.dispose();
    _regUsernameController.dispose();
    _regDisplayNameController.dispose();
    _regCodeController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final username = _loginUsernameController.text.trim().toLowerCase();
    final code = _loginCodeController.text.trim();

    if (username.isEmpty) {
      setState(() => _loginError = 'Please enter or select a username.');
      return;
    }
    if (code.length != 6) {
      setState(() => _loginError = 'Please enter the 6-digit code from Google Authenticator.');
      return;
    }

    setState(() {
      _isVerifying = true;
      _loginError = null;
    });

    try {
      final success = await _auth.loginWithTotp(username: username, code: code);
      if (success) {
        await StorageService().switchUser(username);
        widget.onLoginSuccess?.call();
      } else {
        setState(() {
          _loginError = 'Invalid 6-digit code or user not found. Verify your phone clock and try again.';
        });
      }
    } catch (e) {
      setState(() => _loginError = 'Login error: $e');
    } finally {
      if (mounted) {
        setState(() => _isVerifying = false);
      }
    }
  }

  void _generatePairingKey() {
    final username = _regUsernameController.text.trim().toLowerCase();
    if (username.isEmpty) {
      setState(() => _regError = 'Please enter a username (e.g. alex, reyhan).');
      return;
    }
    if (!RegExp(r'^[a-z0-9_]{3,20}$').hasMatch(username)) {
      setState(() => _regError = 'Username must be 3-20 characters (lowercase letters, numbers, or _).');
      return;
    }

    final secret = TotpService.generateSecret(length: 16);
    final uri = TotpService.buildOtpAuthUri(
      username: username,
      secret: secret,
      issuer: 'YourLog',
    );

    setState(() {
      _generatedSecret = secret;
      _otpAuthUri = uri;
      _regError = null;
    });
  }

  Future<void> _handleConfirmRegistration() async {
    if (_generatedSecret == null) return;
    final username = _regUsernameController.text.trim().toLowerCase();
    final displayName = _regDisplayNameController.text.trim();
    final code = _regCodeController.text.trim();

    if (code.length != 6) {
      setState(() => _regError = 'Enter the 6-digit code shown in Google Authenticator.');
      return;
    }

    final isValid = TotpService.verifyCode(
      secret: _generatedSecret!,
      code: code,
      window: 1,
    );

    if (!isValid) {
      setState(() => _regError = 'Verification code did not match. Ensure your phone clock is synced.');
      return;
    }

    setState(() {
      _isRegisterVerifying = true;
      _regError = null;
    });

    try {
      await _auth.register(
        username: username,
        displayName: displayName.isEmpty ? username : displayName,
        secret: _generatedSecret!,
      );
      await StorageService().switchUser(username);
      widget.onLoginSuccess?.call();
    } catch (e) {
      setState(() => _regError = 'Registration error: $e');
    } finally {
      if (mounted) {
        setState(() => _isRegisterVerifying = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.surfaceHighlight),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 28,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: _isRegistering ? _buildRegisterView() : _buildLoginView(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginView() {
    final savedAccounts = _auth.savedAccounts;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // App Header
        Center(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.12),
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.primary.withOpacity(0.3), width: 2),
            ),
            child: const Icon(
              Icons.shield_outlined,
              size: 40,
              color: AppTheme.primary,
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Your Log',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Unlock with Google Authenticator',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[400],
          ),
        ),
        const SizedBox(height: 24),

        // Saved account pills if available
        if (savedAccounts.isNotEmpty) ...[
          Text(
            'SELECT ACCOUNT',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: savedAccounts.map((acc) {
              final isSelected =
                  _loginUsernameController.text.toLowerCase() == acc.username.toLowerCase();
              return InkWell(
                onTap: () {
                  setState(() {
                    _loginUsernameController.text = acc.username;
                    _loginError = null;
                  });
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primary.withOpacity(0.18)
                        : AppTheme.surfaceHighlight.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? AppTheme.primary : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 10,
                        backgroundColor: isSelected ? AppTheme.primary : Colors.grey[700],
                        child: Text(
                          acc.displayName.isNotEmpty
                              ? acc.displayName[0].toUpperCase()
                              : 'U',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        acc.displayName,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? Colors.white : Colors.grey[300],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
        ],

        // Username Field
        TextField(
          controller: _loginUsernameController,
          textInputAction: TextInputAction.next,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Username',
            prefixIcon: const Icon(Icons.person_outline, color: AppTheme.primary),
            filled: true,
            fillColor: AppTheme.background,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppTheme.surfaceHighlight),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppTheme.surfaceHighlight),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppTheme.primary, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 6-digit Code Field
        TextField(
          controller: _loginCodeController,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            letterSpacing: 8,
            fontWeight: FontWeight.bold,
          ),
          decoration: InputDecoration(
            labelText: 'Google Authenticator 6-Digit Code',
            counterText: '',
            hintText: '000000',
            hintStyle: TextStyle(
              color: Colors.grey[700],
              letterSpacing: 8,
              fontSize: 26,
            ),
            prefixIcon: const Icon(Icons.pin_outlined, color: AppTheme.primary),
            filled: true,
            fillColor: AppTheme.background,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppTheme.surfaceHighlight),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppTheme.surfaceHighlight),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppTheme.primary, width: 2),
            ),
          ),
          onSubmitted: (_) => _handleLogin(),
        ),

        if (_loginError != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.redAccent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, size: 18, color: Colors.redAccent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _loginError!,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _isVerifying ? null : _handleLogin,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 0,
          ),
          child: _isVerifying
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock_open, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Verify & Unlock',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
        ),

        const SizedBox(height: 16),
        const Divider(color: AppTheme.surfaceHighlight),
        const SizedBox(height: 10),

        // Register button
        TextButton(
          onPressed: () {
            setState(() {
              _isRegistering = true;
              _loginError = null;
              _regError = null;
              _generatedSecret = null;
              _otpAuthUri = null;
            });
          },
          child: const Text(
            'New here? Pair with Google Authenticator',
            style: TextStyle(
              color: AppTheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRegisterView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () {
                setState(() {
                  _isRegistering = false;
                  _regError = null;
                });
              },
            ),
            const Expanded(
              child: Text(
                'Pair Google Authenticator',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Connect your Google Authenticator app for secure, passwordless 6-digit login.',
          style: TextStyle(fontSize: 13, color: Colors.grey[400]),
        ),
        const SizedBox(height: 20),

        if (_generatedSecret == null) ...[
          // Step 1: Input username and display name
          TextField(
            controller: _regUsernameController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Username (unique identifier)',
              hintText: 'e.g. reyhan',
              prefixIcon: const Icon(Icons.alternate_email, color: AppTheme.primary),
              filled: true,
              fillColor: AppTheme.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _regDisplayNameController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Display Name (optional)',
              hintText: 'e.g. Reyhan',
              prefixIcon: const Icon(Icons.badge_outlined, color: AppTheme.primary),
              filled: true,
              fillColor: AppTheme.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _generatePairingKey,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.qr_code_2, size: 20),
                SizedBox(width: 8),
                Text(
                  'Generate QR Code',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ] else ...[
          // Step 2: Show QR code and confirmation code
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Center(
                  child: QrImageView(
                    data: _otpAuthUri!,
                    version: QrVersions.auto,
                    size: 190.0,
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.all(8),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Scan with Google Authenticator',
                  style: TextStyle(
                    color: Colors.grey[800],
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Secret key fallback box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.surfaceHighlight),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'MANUAL SETUP KEY',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[500],
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      SelectableText(
                        _generatedSecret!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 18, color: AppTheme.primary),
                  tooltip: 'Copy key',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _generatedSecret!));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Secret key copied to clipboard!'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Text(
            'Confirm pairing by entering the current 6-digit code shown in Google Authenticator:',
            style: TextStyle(fontSize: 12, color: Colors.grey[400]),
          ),
          const SizedBox(height: 10),

          // Code Confirmation
          TextField(
            controller: _regCodeController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              letterSpacing: 8,
              fontWeight: FontWeight.bold,
            ),
            decoration: InputDecoration(
              counterText: '',
              hintText: '000000',
              hintStyle: TextStyle(
                color: Colors.grey[700],
                letterSpacing: 8,
                fontSize: 26,
              ),
              filled: true,
              fillColor: AppTheme.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onSubmitted: (_) => _handleConfirmRegistration(),
          ),
          const SizedBox(height: 16),

          ElevatedButton(
            onPressed: _isRegisterVerifying ? null : _handleConfirmRegistration,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _isRegisterVerifying
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Verify & Complete Setup',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
          ),
        ],

        if (_regError != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.redAccent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, size: 18, color: Colors.redAccent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _regError!,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
