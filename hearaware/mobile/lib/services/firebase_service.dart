import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../models/detection.dart';
import '../models/user_profile.dart';

/// Firebase Auth + Firestore. If Firebase is not configured for this build, [available] is false and every
/// method is a safe no-op, so the app keeps working (local-only mode).
class FirebaseService {
  bool available = false;

  Future<void> init() async {
    try {
      await Firebase.initializeApp();
      available = true;
    } catch (_) {
      available = false;
    }
  }

  User? get user => available ? FirebaseAuth.instance.currentUser : null;
  Stream<User?> get authChanges => available ? FirebaseAuth.instance.authStateChanges() : const Stream.empty();

  /// Returns null on success, or a user-facing error message.
  Future<String?> signIn(String email, String password) async {
    if (!available) return 'Cloud account is not configured for this build.';
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(email: email.trim(), password: password);
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'Sign-in failed.';
    } catch (_) {
      return 'Sign-in failed. Check your connection.';
    }
  }

  Future<String?> register(String email, String password) async {
    if (!available) return 'Cloud account is not configured for this build.';
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email.trim(), password: password);
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'Registration failed.';
    } catch (_) {
      return 'Registration failed. Check your connection.';
    }
  }

  Future<void> signOut() async {
    if (available) await FirebaseAuth.instance.signOut();
  }

  DocumentReference<Map<String, dynamic>>? get _userDoc {
    final u = user;
    return u == null ? null : FirebaseFirestore.instance.collection('users').doc(u.uid);
  }

  Future<void> saveProfile(UserProfile p) async {
    try {
      await _userDoc?.set({'profile': p.name, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<UserProfile?> loadProfile() async {
    try {
      final d = await _userDoc?.get();
      return UserProfile.fromName(d?.data()?['profile'] as String?);
    } catch (_) {
      return null;
    }
  }

  /// Stores the delivered alert as text only.
  Future<void> saveEvent(Alert a) async {
    try {
      await _userDoc?.collection('events').doc(a.id).set(a.toJson());
    } catch (_) {}
  }
}
