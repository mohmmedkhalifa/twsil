import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:twsil_mobile/core/theme/app_theme.dart';

void main() {
  test('theme primary color', () {
    expect(AppTheme.primary, const Color(0xFF00875A));
  });
}