import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart' as firebase_firestore;

class CloudRepository {
  final firebase_firestore.FirebaseStorage storage =
      firebase_firestore.FirebaseStorage.instance;

  Future<String> uploadNewImage(File file, String email) {
    return storage
        .ref('avatar')
        .child(email)
        .putFile(file)
        .then((snapshot) => snapshot.ref.getDownloadURL());
  }

  Future<String> getImageUrl(String email) {
    return storage.ref('avatar').child(email).getDownloadURL();
  }

  Future<String> getDefaultImageUrl() {
    return storage.ref('defaults').child('def_profile.jpg').getDownloadURL();
  }
}
