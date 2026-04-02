import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math';

/// App lock service — supports biometric (fingerprint/face) and PIN.
class AppLockService {
  static final AppLockService _instance = AppLockService._internal();
  factory AppLockService() => _instance;
  AppLockService._internal();

  final LocalAuthentication _auth = LocalAuthentication();

  // ---------------------------------------------------------------------------
  // STATE
  // ---------------------------------------------------------------------------
  Future<bool> isLockEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('app_lock_enabled') ?? false;
  }

  Future<void> setLockEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('app_lock_enabled', enabled);
  }

  Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('app_lock_biometric') ?? true;
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('app_lock_biometric', enabled);
  }

  // ---------------------------------------------------------------------------
  // BIOMETRIC CHECK
  // ---------------------------------------------------------------------------
  Future<bool> isBiometricAvailable() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isDeviceSupported = await _auth.isDeviceSupported();
      return canCheck && isDeviceSupported;
    } catch (e) {
      debugPrint('Biometric check error: $e');
      return false;
    }
  }

  Future<bool> authenticateWithBiometric() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Authenticate to open Nirbhaya',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
    } catch (e) {
      debugPrint('Biometric auth error: $e');
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // PIN
  // ---------------------------------------------------------------------------
  Future<bool> hasPIN() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('app_lock_pin') != null;
  }

  Future<void> setPIN(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    // Simple hash using salt (not crypto-grade but sufficient for a demo lock)
    final hashed = _hashPin(pin);
    await prefs.setString('app_lock_pin', hashed);
  }

  Future<bool> verifyPIN(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('app_lock_pin');
    if (stored == null) return true; // no PIN set
    return stored == _hashPin(pin);
  }

  Future<void> clearPIN() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('app_lock_pin');
  }

  // ---------------------------------------------------------------------------
  // MAIN AUTHENTICATE — tries biometric, falls back to PIN
  // ---------------------------------------------------------------------------
  Future<bool> authenticate() async {
    final biometricEnabled = await isBiometricEnabled();
    final biometricAvailable = await isBiometricAvailable();

    if (biometricEnabled && biometricAvailable) {
      return await authenticateWithBiometric();
    }
    // PIN check is handled in the UI (dialog)
    return false;
  }

  String _hashPin(String pin) {
    // Simple deterministic hash (not for production crypto use)
    final bytes = utf8.encode(pin + 'nirbhaya_salt_2024');
    var h = 0;
    for (var b in bytes) {
      h = (h * 31 + b) & 0xFFFFFFFF;
    }
    return h.toRadixString(16);
  }
}
