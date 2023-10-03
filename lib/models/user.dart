import 'package:cloud_firestore/cloud_firestore.dart';

class User {
  final String email;

  final String displayName;

  final Timestamp timestamp;

  User(
      {required this.email,
      required this.displayName,
      required this.timestamp});

  factory User.fromDocument(DocumentSnapshot doc) {
    return User(
        email: doc['email'],
        displayName: doc['displayName'],
        timestamp: doc['timestamp']);
  }
}
