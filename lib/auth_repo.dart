import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:developer' as developer;

enum Status { Uninitialized, LoggedIn, Logging, LoggedOut }

class AuthRepository with ChangeNotifier {
  FirebaseAuth _auth;
  User? _user;
  Status _status = Status.Uninitialized;

  AuthRepository.instance() : _auth = FirebaseAuth.instance {
    _auth.authStateChanges().listen(_onAuthStateChanged);
    _user = _auth.currentUser;
    _onAuthStateChanged(_user);
  }

  Status get status => _status;

  User? get user => _user;

  bool get isAuthenticated => status == Status.LoggedIn;

  Future<UserCredential?> signUp(String email, String password) async {
    try {
      _status = Status.Logging;
      notifyListeners();
      return await _auth.createUserWithEmailAndPassword(
          email: email, password: password);
    } catch (e) {
      developer.log('Sign up failed: ${e.toString()}', name: "Auth");
      _status = Status.LoggedOut;
      notifyListeners();
      return null;
    }
  }

  Future<bool> signIn(String email, String password) async {
    try {
      _status = Status.Logging;
      notifyListeners();
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      // Logged in
      return true;
    } catch (e) {
      developer.log('Log in failed: ${e.toString()}', name: "Auth");
      _status = Status.LoggedOut;
      notifyListeners();
      return false;
    }
  }

  Future signOut() async {
    _auth.signOut();
    _status = Status.LoggedOut; // immediately
    notifyListeners();
    return Future.delayed(Duration.zero);
  }

  Future<void> _onAuthStateChanged(User? firebaseUser) async {
    if (firebaseUser == null) {
      _user = null;
      _status = Status.LoggedOut;
      developer.log("Logged out!", name: "Auth");
    } else {
      _user = firebaseUser;
      _status = Status.LoggedIn;
      developer.log("Logged in: ${_user!.email}", name: "Auth");
    }

    notifyListeners();
  }
}
