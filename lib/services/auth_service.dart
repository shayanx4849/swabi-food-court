import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/app_user.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  /// Registers a new user in Firebase Auth and saves their profile
  /// (including role: business/customer) under `users/{uid}` in
  /// Realtime Database.
  Future<AppUser> signUp({
    required String email,
    required String password,
    required String name,
    required String role,
    String? phone,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final appUser = AppUser(
      uid: credential.user!.uid,
      email: email,
      name: name,
      role: role,
      phone: phone,
    );

    await _db.child('users').child(appUser.uid).set(appUser.toMap());
    return appUser;
  }

  Future<AppUser?> signIn({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return getUserProfile(credential.user!.uid);
  }

  Future<AppUser?> getUserProfile(String uid) async {
    final snap = await _db.child('users').child(uid).get();
    if (!snap.exists || snap.value == null) return null;
    final map = Map<dynamic, dynamic>.from(snap.value as Map);
    return AppUser.fromMap(map);
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Sends a password-reset email via Firebase Auth. The person clicks the
  /// link in that email to set a new password themselves — this app never
  /// sees or handles the new password directly.
  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }
}
