import 'package:flutter/foundation.dart';

class CreditsProvider extends ChangeNotifier {
  static const int creditsPerCorrect = 10;
  static const int creditsPerIncorrect = 0;

  int _totalCredits = 0;
  int get totalCredits => _totalCredits;

  void updateCredits(int credits) {
    _totalCredits = credits;
    notifyListeners();
  }

  String get creditLevel {
    if (_totalCredits >= 500) return '🏆 Gold Scholar';
    if (_totalCredits >= 200) return '🥈 Silver Scholar';
    if (_totalCredits >= 50) return '🥉 Bronze Scholar';
    return '🌱 Newcomer';
  }

  double get levelProgress {
    if (_totalCredits >= 500) return 1.0;
    if (_totalCredits >= 200) return (_totalCredits - 200) / 300;
    if (_totalCredits >= 50) return (_totalCredits - 50) / 150;
    return _totalCredits / 50;
  }
}
