import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';

class GameService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get myUid => _auth.currentUser!.uid;

  String generateGameCode() {
    return (100000 + Random().nextInt(900000)).toString();
  }

  Future<String> createGame(String playerName) async {
    String code = generateGameCode();
    await _db.collection('games').doc(code).set({
      'createdAt': FieldValue.serverTimestamp(),
      'active': true,
    });
    await joinGame(code, playerName);
    return code;
  }

  Future<void> joinGame(String code, String playerName) async {
    await _db
        .collection('games')
        .doc(code)
        .collection('players')
        .doc(myUid)
        .set({
          'name': playerName,
          'status': 'in_game',
          'lat': 0.0,
          'lng': 0.0,
          'updatedAt': FieldValue.serverTimestamp(),
        });
  }

  Future<void> updatePosition(String gameCode, double lat, double lng) async {
    await _db
        .collection('games')
        .doc(gameCode)
        .collection('players')
        .doc(myUid)
        .update({
          'lat': lat,
          'lng': lng,
          'updatedAt': FieldValue.serverTimestamp(),
        });
  }

  Future<void> updateStatus(String gameCode, String status) async {
    await _db
        .collection('games')
        .doc(gameCode)
        .collection('players')
        .doc(myUid)
        .update({'status': status});
  }

  Stream<QuerySnapshot> playersStream(String gameCode) {
    return _db
        .collection('games')
        .doc(gameCode)
        .collection('players')
        .snapshots();
  }

  Future<void> addPing(
    String gameCode,
    double lat,
    double lng,
    String playerName, {
    String comment = '',
  }) async {
    final pingId = DateTime.now().millisecondsSinceEpoch.toString();
    await _db
        .collection('games')
        .doc(gameCode)
        .collection('pings')
        .doc(pingId)
        .set({
          'lat': lat,
          'lng': lng,
          'playerName': playerName,
          'comment': comment,
          'createdAt': FieldValue.serverTimestamp(),
        });

    Future.delayed(const Duration(seconds: 30), () {
      _db
          .collection('games')
          .doc(gameCode)
          .collection('pings')
          .doc(pingId)
          .delete();
    });
  }

  Future<void> deletePing(String gameCode, String pingId) async {
    await _db
        .collection('games')
        .doc(gameCode)
        .collection('pings')
        .doc(pingId)
        .delete();
  }

  Stream<QuerySnapshot> pingsStream(String gameCode) {
    return _db
        .collection('games')
        .doc(gameCode)
        .collection('pings')
        .snapshots();
  }
}
