import 'package:flutter_test/flutter_test.dart';
import 'package:acadeno_crm/ui/leads/data/model/lead_models.dart';

void main() {
  group('QA Test Suite: Phone Privacy & Normalization', () {
    test('TC-PRIV-001: Masks standard 10-digit Indian phone numbers', () {
      const raw = '9847012345';
      final masked = LeadPhoneValidator.maskPhone(raw);
      expect(masked, equals('98470 •••45'));
    });

    test('TC-PRIV-002: Masks numbers with country code (+91)', () {
      const raw = '+91 94471 98765';
      final masked = LeadPhoneValidator.maskPhone(raw);
      expect(masked, equals('94471 •••65'));
    });

    test('TC-PRIV-003: Masks numbers with leading 0 or special characters', () {
      const raw = '09847-011223';
      final masked = LeadPhoneValidator.maskPhone(raw);
      expect(masked, equals('98470 •••23'));
    });

    test('TC-PRIV-004: Normalizes valid 10-digit phone', () {
      const raw = '+91-98470-12345';
      final norm = LeadPhoneValidator.normalize10Digits(raw);
      expect(norm, equals('9847012345'));
    });

    test('TC-PRIV-005: Validates phone numbers accurately', () {
      expect(LeadPhoneValidator.validate(null), isNotNull);
      expect(LeadPhoneValidator.validate(''), isNotNull);
      expect(LeadPhoneValidator.validate('12345'), isNotNull);
      expect(LeadPhoneValidator.validate('abcdefghij'), isNotNull);
      expect(LeadPhoneValidator.validate('9847012345'), isNull);
    });
  });
}
