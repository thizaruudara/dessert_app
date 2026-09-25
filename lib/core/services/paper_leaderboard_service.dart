import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/upcoming_paper_model.dart';
import '../models/paper_leaderboard_model.dart';

class PaperLeaderboardService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> _ensureAuth() async {
    if (_auth.currentUser == null) {
      try {
        await _auth.signInAnonymously();
      } catch (_) {}
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // UPCOMING PAPERS
  // ══════════════════════════════════════════════════════════════════════════

  Stream<List<UpcomingPaper>> streamUpcomingPapers({String? examYear}) {
    return _firestore.collection('upcoming_papers').snapshots().map((snapshot) {
      final list = <UpcomingPaper>[];
      for (final doc in snapshot.docs) {
        try {
          list.add(UpcomingPaper.fromFirestore(doc));
        } catch (e, stack) {
          debugPrint('Error parsing upcoming paper ${doc.id}: $e\n$stack');
        }
      }
      // Sort by scheduledDate ascending (nearest upcoming first)
      list.sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));

      if (examYear != null && examYear.trim().isNotEmpty && examYear != 'All' && examYear != 'All Batches') {
        final cleanYear = examYear.replaceAll(' ', '').toUpperCase();
        return list.where((p) {
          final pYear = p.examYear.replaceAll(' ', '').toUpperCase();
          return pYear == cleanYear ||
              pYear == 'ALLBATCHES' ||
              pYear == 'ALL' ||
              p.examYear == examYear ||
              p.examYear == 'All Batches' ||
              p.examYear == 'All';
        }).toList();
      }
      return list;
    }).handleError((error, stack) {
      debugPrint('Firestore streamUpcomingPapers error: $error\n$stack');
      return <UpcomingPaper>[];
    });
  }

  Future<String> saveUpcomingPaper(UpcomingPaper paper) async {
    await _ensureAuth();
    final isNew = paper.id.isEmpty;
    final docRef = isNew
        ? _firestore.collection('upcoming_papers').doc()
        : _firestore.collection('upcoming_papers').doc(paper.id);

    await docRef.set(paper.toMap(), SetOptions(merge: true));
    return docRef.id;
  }

  Future<void> deleteUpcomingPaper(String id) async {
    await _ensureAuth();
    await _firestore.collection('upcoming_papers').doc(id).delete();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PAPER LEADERBOARDS
  // ══════════════════════════════════════════════════════════════════════════

  Stream<List<PaperLeaderboard>> streamPaperLeaderboards({String? examYear}) {
    return _firestore.collection('paper_leaderboards').snapshots().map((snapshot) {
      final list = <PaperLeaderboard>[];
      for (final doc in snapshot.docs) {
        try {
          list.add(PaperLeaderboard.fromFirestore(doc));
        } catch (e, stack) {
          debugPrint('Error parsing paper leaderboard ${doc.id}: $e\n$stack');
        }
      }
      // Sort by publishedAt descending (most recent leaderboard first)
      list.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));

      if (examYear != null && examYear.trim().isNotEmpty && examYear != 'All' && examYear != 'All Batches') {
        final cleanYear = examYear.replaceAll(' ', '').toUpperCase();
        final yearDigits = RegExp(r'\b(20\d\d)\b').firstMatch(examYear)?.group(1);
        return list.where((p) {
          final pYear = p.examYear.replaceAll(' ', '').toUpperCase();
          if (pYear == cleanYear ||
              pYear == 'ALLBATCHES' ||
              pYear == 'ALL' ||
              p.examYear == examYear ||
              p.examYear == 'All Batches' ||
              p.examYear == 'All') {
            return true;
          }
          if (yearDigits != null) {
            final pDigits = RegExp(r'\b(20\d\d)\b').firstMatch(p.examYear)?.group(1);
            if (pDigits != null && pDigits == yearDigits) return true;
          }
          return false;
        }).toList();
      }
      return list;
    }).handleError((error, stack) {
      debugPrint('Firestore streamPaperLeaderboards error: $error\n$stack');
      return <PaperLeaderboard>[];
    });
  }

  Future<String> savePaperLeaderboard(PaperLeaderboard leaderboard) async {
    await _ensureAuth();
    final isNew = leaderboard.id.isEmpty;
    final docRef = isNew
        ? _firestore.collection('paper_leaderboards').doc()
        : _firestore.collection('paper_leaderboards').doc(leaderboard.id);

    await docRef.set(leaderboard.toMap(), SetOptions(merge: true));
    return docRef.id;
  }

  Future<void> deletePaperLeaderboard(String id) async {
    await _ensureAuth();
    await _firestore.collection('paper_leaderboards').doc(id).delete();
  }
}
