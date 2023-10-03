import 'package:cloud_firestore/cloud_firestore.dart';

class Prompt {
  final String email;

  final String question;

  final String response;

  final String id;

  final Timestamp timestamp;

  Prompt(
      {required this.email,
      required this.question,
      required this.response,
      required this.id,
      required this.timestamp});

  factory Prompt.fromDocument(DocumentSnapshot doc) {
    return Prompt(
        email: doc['email'],
        question: doc['question'],
        response: doc['response'],
        id: doc['id'],
        timestamp: doc['timestamp']);
  }
}
