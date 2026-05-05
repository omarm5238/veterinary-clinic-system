import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  final db = FirebaseFirestore.instance;
  
  final res = await db.collection('reservations').get();
  print("--- RESERVATIONS ---");
  for (var r in res.docs) {
    final d = r.data();
    print("ID: ${r.id} | date: '${d['date']}' | time: '${d['time']}' | status: '${d['status']}' | slotId: '${d['slotId']}'");
  }

  final slots = await db.collection('available_slots').get();
  print("--- SLOTS ---");
  for (var s in slots.docs) {
    final d = s.data();
    print("ID: ${s.id} | date: '${d['date']}' | time: '${d['time']}' | isBooked: ${d['isBooked']}");
  }
}
