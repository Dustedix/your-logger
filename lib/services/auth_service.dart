import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_account.dart';
import 'totp_service.dart';

class AuthService extends ChangeNotifier {
  static const String _keyAccounts = 'workout_auth_accounts_v1';
  static const String _keyActiveUser = 'workout_auth_active_user_v1';

  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  SharedPreferences? _prefs;
  List<UserAccount> _accounts = [];
  UserAccount? _currentUser;

  UserAccount? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  List<UserAccount> get savedAccounts => List.unmodifiable(_accounts);

  bool get _isFirebaseReady => Firebase.apps.isNotEmpty;
  FirebaseFirestore? get _firestore =>
      _isFirebaseReady ? FirebaseFirestore.instance : null;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _loadAccounts();

    final activeUsername = _prefs?.getString(_keyActiveUser);
    if (activeUsername != null && activeUsername.isNotEmpty) {
      final match = _accounts.where(
        (a) => a.username.toLowerCase() == activeUsername.toLowerCase(),
      );
      if (match.isNotEmpty) {
        _currentUser = match.first;
      }
    }
    notifyListeners();
  }

  Future<void> _loadAccounts() async {
    final raw = _prefs?.getString(_keyAccounts);
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = jsonDecode(raw) as List;
        _accounts = list
            .map((e) => UserAccount.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (e) {
        debugPrint('Error decoding saved accounts: $e');
        _accounts = [];
      }
    }
  }

  Future<void> _saveAccounts() async {
    final raw = jsonEncode(_accounts.map((a) => a.toJson()).toList());
    await _prefs?.setString(_keyAccounts, raw);
  }

  /// Finds an account by username locally or queries Cloud Firestore if available.
  Future<UserAccount?> findAccount(String username) async {
    final clean = username.trim().toLowerCase();
    if (clean.isEmpty) return null;

    // Check local list first
    final localMatch = _accounts.where((a) => a.username.toLowerCase() == clean);
    if (localMatch.isNotEmpty) {
      return localMatch.first;
    }

    // Try Cloud Firestore
    if (_isFirebaseReady && _firestore != null) {
      try {
        final doc = await _firestore!
            .collection('users')
            .doc(clean)
            .collection('auth')
            .doc('credentials')
            .get();

        if (doc.exists && doc.data() != null) {
          final account = UserAccount.fromJson(doc.data()!);
          _accounts.add(account);
          await _saveAccounts();
          return account;
        }
      } catch (e) {
        debugPrint('Notice querying user account from Firestore: $e');
      }
    }

    return null;
  }

  /// Registers a new user account with a pre-verified TOTP secret.
  Future<UserAccount> register({
    required String username,
    required String displayName,
    required String secret,
  }) async {
    final cleanUsername = username.trim().toLowerCase();
    final cleanDisplay = displayName.trim().isEmpty ? cleanUsername : displayName.trim();

    final account = UserAccount(
      username: cleanUsername,
      displayName: cleanDisplay,
      totpSecret: secret.trim().toUpperCase(),
      createdAt: DateTime.now(),
      lastLoginAt: DateTime.now(),
    );

    // Remove existing if any
    _accounts.removeWhere((a) => a.username.toLowerCase() == cleanUsername);
    _accounts.add(account);
    await _saveAccounts();

    // Persist to Firestore if available
    if (_isFirebaseReady && _firestore != null) {
      try {
        await _firestore!
            .collection('users')
            .doc(cleanUsername)
            .collection('auth')
            .doc('credentials')
            .set(account.toJson());
      } catch (e) {
        debugPrint('Notice saving user to Firestore: $e');
      }
    }

    _currentUser = account;
    await _prefs?.setString(_keyActiveUser, cleanUsername);
    notifyListeners();
    return account;
  }

  /// Verifies a 6-digit TOTP code against an existing account and logs in.
  Future<bool> loginWithTotp({
    required String username,
    required String code,
  }) async {
    final account = await findAccount(username);
    if (account == null) {
      return false;
    }

    final isValid = TotpService.verifyCode(
      secret: account.totpSecret,
      code: code,
      window: 1, // ±30s tolerance
    );

    if (isValid) {
      final updated = account.copyWith(lastLoginAt: DateTime.now());
      final index = _accounts.indexWhere(
        (a) => a.username.toLowerCase() == updated.username.toLowerCase(),
      );
      if (index >= 0) {
        _accounts[index] = updated;
      } else {
        _accounts.add(updated);
      }
      await _saveAccounts();

      if (_isFirebaseReady && _firestore != null) {
        _firestore!
            .collection('users')
            .doc(updated.username)
            .collection('auth')
            .doc('credentials')
            .set(updated.toJson(), SetOptions(merge: true))
            .catchError((e) {
          debugPrint('Notice updating login timestamp: $e');
        });
      }

      _currentUser = updated;
      await _prefs?.setString(_keyActiveUser, updated.username);
      notifyListeners();
      return true;
    }

    return false;
  }

  /// Logs out the current user and clears active session.
  Future<void> logout() async {
    _currentUser = null;
    await _prefs?.remove(_keyActiveUser);
    notifyListeners();
  }

  /// Removes an account from local device storage.
  Future<void> removeAccount(String username) async {
    final clean = username.trim().toLowerCase();
    _accounts.removeWhere((a) => a.username.toLowerCase() == clean);
    await _saveAccounts();
    if (_currentUser?.username.toLowerCase() == clean) {
      await logout();
    } else {
      notifyListeners();
    }
  }
}
