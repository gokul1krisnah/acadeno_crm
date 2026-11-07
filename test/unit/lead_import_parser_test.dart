import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:acadeno_crm/ui/leads/data/model/lead_import_models.dart';
import 'package:acadeno_crm/ui/leads/data/sources/lead_import_parser.dart';

void main() {
  group('QA Test Suite: LeadImportParser', () {
    test('TC-LIP-001: Parses standard UTF-8 CSV with name, phone, college', () {
      const csvData = '''Name,Phone,College,Branch,Status
Rahul Nair,9847012345,KMCT Engineering,CSE,New
Ananya Das,9447123456,Farook College,BCA,Interested
''';
      final bytes = Uint8List.fromList(utf8.encode(csvData));
      final items = LeadImportParser.parseCsvBytes(bytes);

      expect(items.length, equals(2));
      expect(items[0].name, equals('Rahul Nair'));
      expect(items[0].phoneNormalized, equals('9847012345'));
      expect(items[0].college, equals('KMCT Engineering'));
      expect(items[0].status, equals(LeadImportStatus.valid));
    });

    test(
      'TC-LIP-002: Recovers multi-byte Latin-1 / Windows-1252 encoded CSV',
      () {
        const csvData =
            'Candidate Name,Mobile Number,Institution\nRené Dupont,9876543210,GEC Kozhikode\n';
        final bytes = Uint8List.fromList(latin1.encode(csvData));
        final items = LeadImportParser.parseCsvBytes(bytes);

        expect(items.length, equals(1));
        expect(items[0].name, equals('René Dupont'));
        expect(items[0].phoneNormalized, equals('9876543210'));
        expect(items[0].status, equals(LeadImportStatus.valid));
      },
    );

    test('TC-LIP-003: Flags duplicate or invalid phone numbers', () {
      const csvData = '''Full Name,Contact,College
Arun Kumar,123,KMCT
Bibin George,9847012345,NIT Calicut
Cyril Jose,9847012345,NIT Calicut
''';
      final bytes = Uint8List.fromList(utf8.encode(csvData));
      final items = LeadImportParser.parseCsvBytes(bytes);

      expect(items.length, equals(3));
      // Row 1: invalid phone (too short)
      expect(items[0].status, equals(LeadImportStatus.invalid));
      expect(items[0].issueMessage, contains('Invalid phone'));

      // Row 2: valid phone
      expect(items[1].status, equals(LeadImportStatus.valid));

      // Row 3: duplicate in sheet
      expect(items[2].status, equals(LeadImportStatus.duplicateInFile));
      expect(items[2].issueMessage, contains('Duplicate'));
    });

    test(
      'TC-LIP-004: Throws FormatException for empty file so UI shows clear error',
      () {
        final emptyBytes = Uint8List.fromList([]);
        expect(
          () => LeadImportParser.parseCsvBytes(emptyBytes),
          throwsA(isA<FormatException>()),
        );
      },
    );
  });
}
