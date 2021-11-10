import 'dart:developer';

import 'package:english_words/english_words.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StoreRepository {
  final CollectionReference collection =
      FirebaseFirestore.instance.collection('users');

  Stream<QuerySnapshot> getStream() {
    return collection.snapshots();
  }

  // Also creates user document if didn't exist
  Future<void> updateUser(MyUser user) {
    return collection.doc(user.email).set(user.toJson());
  }

  Future<List<WordPair>?> getUserList(String email) async {
    var doc = await collection.doc(email).get();
    if (!doc.exists) {
      return [];
    } else {
      MyUser user = MyUser.fromSnapshot(doc);
      return user.favorites;
    }
  }

  void deleteUser(String email) async {
    await collection.doc(email).delete();
  }
}

class MyUser {
  final String email;
  List<WordPair>? favorites;

  MyUser(this.email, this.favorites);

  factory MyUser.fromSnapshot(DocumentSnapshot snapshot) {
    final newUser = MyUser.fromJson(snapshot.data() as Map<String, dynamic>);
    return newUser;
  }

  factory MyUser.fromJson(Map<String, dynamic> json) {
    List<dynamic> newList = json['favorites'].map((val) {
      var z = Map<String, dynamic>.from(val);
      return WordPair(z['first'], z['second']);
    }).toList();

    List<WordPair> newList2 = List.castFrom(newList);

    log("converted list is ${newList.toString()}", name: 'Favorites');

    return MyUser(json['email'] as String, newList2);
  }

  Map<String, dynamic> toJson() {
    var newList = (favorites!.isEmpty)
        ? []
        : favorites!
            .map((pair) => {'first': pair.first, 'second': pair.second})
            .toList();
    return <String, dynamic>{'email': email, 'favorites': newList};
  }
}
