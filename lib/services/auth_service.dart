import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';

/// Service managing user authentication (Email/Password & Anonymous Guest mode).
class AuthService {
  // ============================================================
  // SINGLETON
  // ============================================================

  static final AuthService _instance = AuthService._internal();

  factory AuthService() => _instance;

  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ============================================================
  // STREAMS & GETTERS
  // ============================================================

  /// Stream of authentication state changes.
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Currently signed in Firebase user, or null if unauthenticated.
  User? get currentUser => _auth.currentUser;

  /// Whether a user is currently logged in.
  bool get isAuthenticated => _auth.currentUser != null;

  /// Whether current user is logged in anonymously (Guest Volunteer mode).
  bool get isAnonymous => _auth.currentUser?.isAnonymous ?? false;

  /// Unique user ID for audit/provenance.
  String? get operatorId => _auth.currentUser?.uid;

  /// User email address, if registered.
  String? get operatorEmail => _auth.currentUser?.email;

  /// Human-readable operator display name.
  String get operatorDisplayName {
    final user = _auth.currentUser;
    if (user == null) return 'Petugas Lapangan';
    if (user.displayName != null && user.displayName!.trim().isNotEmpty) {
      return user.displayName!.trim();
    }
    if (user.isAnonymous) {
      return 'Relawan Tamu Lapangan';
    }
    return user.email ?? 'Petugas Lapangan';
  }

  // ============================================================
  // AUTH METHODS
  // ============================================================

  /// Sign in anonymously as a rapid field relief volunteer.
  ///
  /// Optionally sets a display callsign (e.g. "Posko 03 - Relawan Ahmad").
  Future<UserCredential> signInAnonymously({String? volunteerName}) async {
    final credential = await _auth.signInAnonymously();

    if (volunteerName != null && volunteerName.trim().isNotEmpty) {
      await credential.user?.updateDisplayName(volunteerName.trim());
      await credential.user?.reload();
    }

    return credential;
  }

  /// Sign in with an official registered email and password.
  Future<UserCredential> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Register a new official personnel account (PMI, BPBD, Lab analyst).
  Future<UserCredential> registerWithEmailPassword({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    if (displayName.trim().isNotEmpty) {
      await credential.user?.updateDisplayName(displayName.trim());
      await credential.user?.reload();
    }

    return credential;
  }

  /// Send password reset email.
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  /// Sign out current user.
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
