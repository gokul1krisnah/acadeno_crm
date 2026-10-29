import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../model/lead_import_models.dart';
import '../model/lead_models.dart';

/// Pure Dart parser for CSV and Excel (.xlsx) lead data files (FR-1.1 - FR-1.3).
class LeadImportParser {
  static const String sampleTemplateCsv = '''Name,Phone,Email,College,Branch,Year,Course,Source,Notes,Consent
Anand Kumar,9847011111,anand.k@example.com,NIT Calicut,CSE,3rd Year,AI & Python Bootcamp,AI & Machine Learning Workshop (Nov),Interested in weekend batch,Event registration form
Pooja Nair,9847022222,pooja.nair@gmail.com,CET Trivandrum,ECE,4th Year,Full Stack Flutter,College Seminar,Wants discount for group of 3,College attendance sheet
Mohammed R,9847033333,mohammed.r@outlook.com,GEC Thrissur,ME,2nd Year,Robotics & IoT,Direct visit,Follow up on Saturday,Website inquiry form
''';

  /// Standard column alias dictionary to auto-map user CSV / Excel headers.
  static const Map<String, List<String>> _headerAliases = {
    'name': ['name', 'student_name', 'studentname', 'full_name', 'fullname', 'student', 'candidate_name', 'candidate'],
    'phone': ['phone', 'mobile', 'mobile_number', 'mobilenumber', 'contact', 'phone_number', 'phonenumber', 'contact_number', 'tel'],
    'email': ['email', 'email_address', 'emailaddress', 'email_id', 'emailid', 'mail'],
    'college': ['college', 'institution', 'university', 'college_name', 'collegename', 'institute', 'campus'],
    'branch': ['branch', 'department', 'dept', 'stream', 'specialization'],
    'year': ['year', 'semester', 'sem', 'batch', 'current_year', 'study_year'],
    'college_branch': ['college_branch', 'collegebranch', 'collegeinfo', 'college_info'],
    'course': ['course', 'workshop', 'program', 'topic', 'interested_in', 'course_name'],
    'source': ['source', 'campaign', 'lead_source', 'event', 'source_event', 'channel'],
    'notes': ['notes', 'remarks', 'comment', 'comments', 'note', 'message'],
    'consent': ['consent', 'consent_basis', 'consent_source', 'consent_method', 'dpdp_consent'],
  };

  /// Parses CSV / TSV text into validated [LeadImportItem] records.
  static List<LeadImportItem> parseCsvString(
    String csvString, {
    String defaultSource = 'AI & Machine Learning Workshop (Nov)',
    String defaultConsent = 'Event registration form',
  }) {
    final cleanCsv = _stripBom(csvString);
    final rawRows = _splitCsvLines(cleanCsv);
    return _process2dRows(rawRows, defaultSource: defaultSource, defaultConsent: defaultConsent);
  }

  /// Parses raw CSV bytes (UTF-8).
  static List<LeadImportItem> parseCsvBytes(
    Uint8List bytes, {
    String defaultSource = 'AI & Machine Learning Workshop (Nov)',
    String defaultConsent = 'Event registration form',
  }) {
    final str = utf8.decode(bytes, allowMalformed: true);
    return parseCsvString(str, defaultSource: defaultSource, defaultConsent: defaultConsent);
  }

  /// Parses Excel (.xlsx) file bytes into validated [LeadImportItem] records.
  static List<LeadImportItem> parseXlsxBytes(
    Uint8List bytes, {
    String defaultSource = 'AI & Machine Learning Workshop (Nov)',
    String defaultConsent = 'Event registration form',
  }) {
    final zipEntries = _readZipEntries(bytes);
    if (zipEntries.isEmpty) {
      throw const FormatException('The uploaded file is not a valid zip / Excel file.');
    }

    // 1. Read shared strings
    final sharedStrings = <String>[];
    final sstEntry = zipEntries.firstWhere(
      (e) => e.name.toLowerCase().contains('sharedstrings.xml'),
      orElse: () => _SimpleZipEntry('', Uint8List(0)),
    );
    if (sstEntry.data.isNotEmpty) {
      final sstXml = utf8.decode(sstEntry.data, allowMalformed: true);
      sharedStrings.addAll(_parseSharedStringsXml(sstXml));
    }

    // 2. Read first sheet
    final sheetEntry = zipEntries.firstWhere(
      (e) => e.name.toLowerCase().contains('worksheets/sheet1.xml') || e.name.toLowerCase().contains('sheet1.xml'),
      orElse: () => _SimpleZipEntry('', Uint8List(0)),
    );
    if (sheetEntry.data.isEmpty) {
      throw const FormatException('Excel file does not contain a valid worksheet (sheet1.xml).');
    }

    final sheetXml = utf8.decode(sheetEntry.data, allowMalformed: true);
    final rawRows = _parseSheetXmlRows(sheetXml, sharedStrings);

    return _process2dRows(rawRows, defaultSource: defaultSource, defaultConsent: defaultConsent);
  }

  /// Generates a downloadable CSV containing all skipped, invalid, and failed rows.
  static String generateErrorReportCsv(List<LeadImportItem> items) {
    final buffer = StringBuffer();
    buffer.writeln('Row Number,Name,Phone,Email,Status,Reason');

    for (final item in items) {
      if (item.status == LeadImportStatus.valid || item.status == LeadImportStatus.imported) {
        continue;
      }
      final cleanName = _escapeCsvField(item.name);
      final cleanPhone = _escapeCsvField(item.phone);
      final cleanEmail = _escapeCsvField(item.email);
      final cleanStatus = _escapeCsvField(item.status.label);
      final cleanReason = _escapeCsvField(item.issueMessage.isNotEmpty ? item.issueMessage : 'Skipped');
      buffer.writeln('${item.rowNumber},$cleanName,$cleanPhone,$cleanEmail,$cleanStatus,$cleanReason');
    }
    return buffer.toString();
  }

  // ---------------------------------------------------------------------------
  // Core Row Processing & Validation Engine
  // ---------------------------------------------------------------------------

  static List<LeadImportItem> _process2dRows(
    List<List<String>> rawRows, {
    required String defaultSource,
    required String defaultConsent,
  }) {
    if (rawRows.isEmpty) {
      throw const FormatException('The file is empty. Please upload a file with data rows.');
    }

    // Find header row (skip leading blank rows)
    int headerIndex = -1;
    for (int i = 0; i < rawRows.length; i++) {
      if (rawRows[i].any((cell) => cell.trim().isNotEmpty)) {
        headerIndex = i;
        break;
      }
    }

    if (headerIndex == -1) {
      throw const FormatException('File contains no headers or data.');
    }

    final headerRow = rawRows[headerIndex];
    final columnMap = _buildColumnMap(headerRow);

    if (!columnMap.containsKey('name') && !columnMap.containsKey('phone')) {
      throw const FormatException(
        'Could not find required columns ("Name" and "Phone") in the header row. Please check the column headers.',
      );
    }

    final results = <LeadImportItem>[];
    final seenPhoneToRowMap = <String, int>{}; // normalized 10-digit -> first row number

    for (int r = headerIndex + 1; r < rawRows.length; r++) {
      final row = rawRows[r];
      // Skip completely empty lines
      if (row.every((c) => c.trim().isEmpty)) continue;

      final rowNumber = r + 1; // 1-based row number matching Excel row number

      String getCol(String key) {
        final colIdx = columnMap[key];
        if (colIdx != null && colIdx < row.length) {
          return row[colIdx].trim();
        }
        return '';
      }

      final name = getCol('name');
      final rawPhone = getCol('phone');
      final email = getCol('email');
      var college = getCol('college');
      var branch = getCol('branch');
      var year = getCol('year');
      final collegeBranch = getCol('college_branch');

      if (collegeBranch.isNotEmpty && college.isEmpty && branch.isEmpty) {
        final parsed = LeadRecord.parseCollegeBranch(collegeBranch);
        college = parsed.college;
        branch = parsed.branch;
        year = parsed.year;
      }

      final course = getCol('course');
      final sourceVal = getCol('source');
      final effectiveSource = sourceVal.isNotEmpty ? sourceVal : defaultSource;

      final notes = getCol('notes');
      final consentVal = getCol('consent');
      final effectiveConsent = consentVal.isNotEmpty ? consentVal : defaultConsent;

      final item = LeadImportItem(
        rowNumber: rowNumber,
        name: name,
        phone: rawPhone,
        phoneNormalized: '',
        email: email,
        college: college,
        branch: branch,
        year: year,
        course: course,
        source: effectiveSource,
        notes: notes,
        consent: effectiveConsent,
      );

      // Validation 1: Required Name
      if (name.isEmpty) {
        item.status = LeadImportStatus.invalid;
        item.issueMessage = 'Name is missing – skipped';
        results.add(item);
        continue;
      }

      // Validation 2: Required Phone & 10-digit Indian mobile format
      if (rawPhone.isEmpty) {
        item.status = LeadImportStatus.invalid;
        item.issueMessage = 'Phone number is missing – skipped';
        results.add(item);
        continue;
      }

      final phone10 = LeadPhoneValidator.normalize10Digits(rawPhone);
      item.phoneNormalized = phone10;

      if (phone10.length != 10) {
        item.status = LeadImportStatus.invalid;
        item.issueMessage = 'Invalid phone digits – skipped';
        results.add(item);
        continue;
      }

      if (!RegExp(r'^[6-9]\d{9}$').hasMatch(phone10)) {
        item.status = LeadImportStatus.invalid;
        item.issueMessage = 'Invalid mobile (must start with 6–9) – skipped';
        results.add(item);
        continue;
      }

      // Validation 3: Email format (if provided)
      if (email.isNotEmpty && !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
        item.status = LeadImportStatus.invalid;
        item.issueMessage = 'Invalid email address format – skipped';
        results.add(item);
        continue;
      }

      // Validation 4: In-file duplicate detection
      if (seenPhoneToRowMap.containsKey(phone10)) {
        final firstRow = seenPhoneToRowMap[phone10]!;
        item.status = LeadImportStatus.duplicateInFile;
        item.issueMessage = 'Duplicate in file – merged with row $firstRow';
        results.add(item);
        continue;
      }

      // Record first appearance of this phone
      seenPhoneToRowMap[phone10] = rowNumber;
      item.status = LeadImportStatus.valid;
      item.issueMessage = 'Valid new lead';
      results.add(item);
    }

    return results;
  }

  static Map<String, int> _buildColumnMap(List<String> headers) {
    final map = <String, int>{};
    for (int col = 0; col < headers.length; col++) {
      final rawHeader = headers[col].toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '');
      if (rawHeader.isEmpty) continue;

      for (final entry in _headerAliases.entries) {
        if (!map.containsKey(entry.key) && entry.value.contains(rawHeader)) {
          map[entry.key] = col;
          break;
        }
      }
    }
    return map;
  }

  // ---------------------------------------------------------------------------
  // RFC-4180 CSV & TSV Text Parser
  // ---------------------------------------------------------------------------

  static String _stripBom(String s) {
    if (s.startsWith('\uFEFF')) return s.substring(1);
    return s;
  }

  static List<List<String>> _splitCsvLines(String input) {
    final rows = <List<String>>[];
    final currentField = StringBuffer();
    final currentRow = <String>[];
    bool inQuotes = false;
    final length = input.length;

    // Detect delimiter (tab vs comma)
    String delimiter = ',';
    final firstLine = input.split('\n').first;
    if (firstLine.contains('\t') && !firstLine.contains(',')) {
      delimiter = '\t';
    }

    for (int i = 0; i < length; i++) {
      final char = input[i];

      if (char == '"') {
        if (inQuotes && i + 1 < length && input[i + 1] == '"') {
          currentField.write('"');
          i++; // skip escaped quote
        } else {
          inQuotes = !inQuotes;
        }
      } else if (!inQuotes && (char == delimiter)) {
        currentRow.add(currentField.toString());
        currentField.clear();
      } else if (!inQuotes && (char == '\r' || char == '\n')) {
        currentRow.add(currentField.toString());
        currentField.clear();
        if (currentRow.any((c) => c.trim().isNotEmpty)) {
          rows.add(List.from(currentRow));
        }
        currentRow.clear();
        if (char == '\r' && i + 1 < length && input[i + 1] == '\n') {
          i++; // skip \n in CRLF
        }
      } else {
        currentField.write(char);
      }
    }

    if (currentField.isNotEmpty || currentRow.isNotEmpty) {
      currentRow.add(currentField.toString());
      if (currentRow.any((c) => c.trim().isNotEmpty)) {
        rows.add(currentRow);
      }
    }

    return rows;
  }

  static String _escapeCsvField(String field) {
    if (field.contains(',') || field.contains('"') || field.contains('\n') || field.contains('\r')) {
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
  }

  // ---------------------------------------------------------------------------
  // OpenXML Excel (.xlsx) Parser & PKZIP Extractor
  // ---------------------------------------------------------------------------

  static List<_SimpleZipEntry> _readZipEntries(Uint8List bytes) {
    final entries = <_SimpleZipEntry>[];
    var offset = 0;
    if (bytes.length < 30) return entries;
    final byteData = ByteData.sublistView(bytes);

    while (offset + 30 <= bytes.length) {
      final sig = byteData.getUint32(offset, Endian.little);
      if (sig != 0x04034b50) {
        break; // Not local file header
      }

      final method = byteData.getUint16(offset + 8, Endian.little);
      final compSize = byteData.getUint32(offset + 18, Endian.little);
      final nameLen = byteData.getUint16(offset + 26, Endian.little);
      final extraLen = byteData.getUint16(offset + 28, Endian.little);

      final nameBytes = bytes.sublist(offset + 30, offset + 30 + nameLen);
      final fileName = utf8.decode(nameBytes, allowMalformed: true);

      final dataOffset = offset + 30 + nameLen + extraLen;
      if (dataOffset + compSize > bytes.length) break;

      final compData = bytes.sublist(dataOffset, dataOffset + compSize);
      Uint8List decompressed;

      if (method == 0) {
        decompressed = compData;
      } else if (method == 8) {
        try {
          final codec = ZLibCodec(raw: true);
          final rawDecoded = codec.decode(compData);
          decompressed = Uint8List.fromList(rawDecoded);
        } catch (_) {
          decompressed = Uint8List(0);
        }
      } else {
        decompressed = compData;
      }

      entries.add(_SimpleZipEntry(fileName, decompressed));
      offset = dataOffset + compSize;
    }
    return entries;
  }

  static List<String> _parseSharedStringsXml(String xml) {
    final strings = <String>[];
    final siRegex = RegExp(r'<si>(.*?)</si>', dotAll: true);
    final tRegex = RegExp(r'<t(?:\s+[^>]*?)?>(.*?)</t>', dotAll: true);

    for (final match in siRegex.allMatches(xml)) {
      final siContent = match.group(1) ?? '';
      final tMatches = tRegex.allMatches(siContent);
      if (tMatches.isNotEmpty) {
        final combined = tMatches.map((m) => _decodeXmlEntities(m.group(1) ?? '')).join();
        strings.add(combined);
      } else {
        strings.add('');
      }
    }
    return strings;
  }

  static List<List<String>> _parseSheetXmlRows(String xml, List<String> sharedStrings) {
    final rows = <List<String>>[];
    final rowRegex = RegExp(r'<row\s+[^>]*?r="(\d+)"[^>]*?>(.*?)</row>', dotAll: true);
    final cellRegex = RegExp(r'<c\s+r="([A-Z]+)(\d+)"(?:\s+[^>]*?t="([^"]*)")?[^>]*?>(?:<v>(.*?)</v>)?.*?</c>', dotAll: true);

    for (final rowMatch in rowRegex.allMatches(xml)) {
      final rowContent = rowMatch.group(2) ?? '';
      final cellMap = <int, String>{};
      int maxCol = 0;

      for (final cellMatch in cellRegex.allMatches(rowContent)) {
        final colLetters = cellMatch.group(1) ?? 'A';
        final colIndex = _excelColLetterToIndex(colLetters);
        if (colIndex > maxCol) maxCol = colIndex;

        final type = cellMatch.group(3) ?? '';
        final val = cellMatch.group(4) ?? '';

        String cellText = '';
        if (type == 's') {
          final sstIdx = int.tryParse(val) ?? -1;
          if (sstIdx >= 0 && sstIdx < sharedStrings.length) {
            cellText = sharedStrings[sstIdx];
          }
        } else {
          cellText = _decodeXmlEntities(val);
        }
        cellMap[colIndex] = cellText;
      }

      final rowCells = <String>[];
      for (int c = 0; c <= maxCol; c++) {
        rowCells.add(cellMap[c] ?? '');
      }
      rows.add(rowCells);
    }
    return rows;
  }

  static int _excelColLetterToIndex(String letters) {
    int index = 0;
    for (int i = 0; i < letters.length; i++) {
      index = index * 26 + (letters.codeUnitAt(i) - 64);
    }
    return index - 1; // 0-based
  }

  static String _decodeXmlEntities(String s) {
    return s
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&');
  }
}

class _SimpleZipEntry {
  final String name;
  final Uint8List data;

  const _SimpleZipEntry(this.name, this.data);
}

