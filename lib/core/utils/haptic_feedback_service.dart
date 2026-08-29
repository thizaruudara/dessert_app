import 'package:flutter/services.dart';

class HapticFeedbackService {
  static void light() {
    try {
      HapticFeedback.lightImpact();
    } catch (_) {}
  }

  static void medium() {
    try {
      HapticFeedback.mediumImpact();
    } catch (_) {}
  }

  static void selection() {
    try {
      HapticFeedback.selectionClick();
    } catch (_) {}
  }

  static void success() {
    try {
      HapticFeedback.heavyImpact();
      Future.delayed(const Duration(milliseconds: 120), () {
        HapticFeedback.lightImpact();
      });
    } catch (_) {}
  }
}
