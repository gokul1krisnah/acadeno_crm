import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../model/lead_import_models.dart';
import '../model/lead_models.dart';

/// Pure Dart parser for CSV and Excel (.xlsx) lead data files.
class LeadImportParser {
  static const String sampleTemplateCsv =
      '''Name,Phone,Email,College,Branch,Year,Course,Source,Notes,Consent
Anand Kumar,9847011111,anand.k@example.com,NIT Calicut,CSE,3rd Year,AI & Python Bootcamp,AI & Machine Learning Workshop (Nov),Interested in weekend batch,Event registration form
Pooja Nair,9847022222,pooja.nair@gmail.com,CET Trivandrum,ECE,4th Year,Full Stack Flutter,College Seminar,Wants discount for group of 3,College attendance sheet
Mohammed R,9847033333,mohammed.r@outlook.com,GEC Thrissur,ME,2nd Year,Robotics & IoT,Direct visit,Follow up on Saturday,Website inquiry form
''';

  /// Standard column alias dictionary to auto-map user CSV / Excel headers.
  static const Map<String, List<String>> _headerAliases = {
    'name': [
      'name',
      'student_name',
      'studentname',
      'full_name',
      'fullname',
      'student',
      'candidate_name',
      'candidate',
      'lead_name',
      'leadname',
      'client_name',
      'clientname',
      'first_name',
      'firstname',
      'person_name',
      'personname',
      'applicant_name',
      'applicant',
      'customer_name',
      'customername',
      'contact_name',
      'contactname',
      'lead',
    ],
    'phone': [
      'phone',
      'mobile',
      'mobile_number',
      'mobilenumber',
      'contact',
      'phone_number',
      'phonenumber',
      'contact_number',
      'contactnumber',
      'tel',
      'telephone',
      'telephone_number',
      'telephonenumber',
      'cell',
      'cellphone',
      'cell_number',
      'cellnumber',
      'mobile_no',
      'mobileno',
      'phone_no',
      'phoneno',
      'contact_no',
      'contactno',
      'whatsapp',
      'whatsapp_number',
      'whatsappnumber',
      'whatsapp_no',
      'whatsappno',
      'ph',
    ],
    'email': [
      'email',
      'email_address',
      'emailaddress',
      'email_id',
      'emailid',
      'mail',
      'mail_id',
      'mailid',
    ],
    'college': [
      'college',
      'institution',
      'university',
      'college_name',
      'collegename',
      'institute',
      'campus',
      'school',
    ],
    'branch': [
      'branch',
      'department',
      'dept',
      'stream',
      'specialization',
      'discipline',
    ],
    'year': [
      'year',
      'semester',
      'sem',
      'batch',
      'current_year',
      'study_year',
      'graduation_year',
      'passout_year',
    ],
    'college_branch': [
      'college_branch',
      'collegebranch',
      'collegeinfo',
      'college_info',
      'college_and_branch',
      'collegeandbranch',
    ],
    'course': [
      'course',
      'workshop',
      'program',
      'topic',
      'interested_in',
      'course_name',
      'coursename',
      'program_name',
      'programname',
      'curriculum',
    ],
    'source': [
      'source',
      'campaign',
      'lead_source',
      'event',
      'source_event',
      'channel',
      'campaign_source',
      'campaignsource',
      'campaign_or_source',
      'campaignorsource',
      'leadsource',
      'source_name',
    ],
    'notes': [
      'notes',
      'remarks',
      'comment',
      'comments',
      'note',
      'message',
      'feedback',
    ],
    'consent': [
      'consent',
      'consent_basis',
      'consent_source',
      'consent_method',
      'dpdp_consent',
      'consent_type',
    ],
  };

  /// Parses CSV / TSV text into validated [LeadImportItem] records.
  static List<LeadImportItem> parseCsvString(
    String csvString, {
    String defaultSource = 'AI & Machine Learning Workshop (Nov)',
    String defaultConsent = 'Event registration form',
  }) {
    var cleanCsv = _stripBom(csvString);
    cleanCsv = _stripExcelSepDirective(cleanCsv);
    cleanCsv = _recoverByteEncodedCsv(cleanCsv);
    cleanCsv = _stripBom(cleanCsv);
    final delimiter = _detectDelimiter(cleanCsv);
    final rawRows = _splitCsvLines(cleanCsv, delimiter: delimiter);
    return _process2dRows(
      rawRows,
      defaultSource: defaultSource,
      defaultConsent: defaultConsent,
    );
  }

  /// Parses raw CSV bytes (supports UTF-8 with/without BOM, UTF-16 LE/BE, and ANSI).
  static List<LeadImportItem> parseCsvBytes(
    Uint8List bytes, {
    String defaultSource = 'AI & Machine Learning Workshop (Nov)',
    String defaultConsent = 'Event registration form',
  }) {
    if (bytes.isEmpty) {
      throw const FormatException('Uploaded file is empty (0 bytes).');
    }

    String str;
    if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
      // UTF-16 LE (common Windows Excel Unicode Text export)
      final charCodes = <int>[];
      for (int i = 2; i + 1 < bytes.length; i += 2) {
        charCodes.add(bytes[i] | (bytes[i + 1] << 8));
      }
      str = String.fromCharCodes(charCodes);
    } else if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
      // UTF-16 BE
      final charCodes = <int>[];
      for (int i = 2; i + 1 < bytes.length; i += 2) {
        charCodes.add((bytes[i] << 8) | bytes[i + 1]);
      }
      str = String.fromCharCodes(charCodes);
    } else if (bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF) {
      // UTF-8 with BOM
      str = utf8.decode(bytes.sublist(3), allowMalformed: true);
    } else {
      try {
        str = utf8.decode(bytes);
      } catch (_) {
        try {
          // Fallback to Latin-1 (Windows-1252 ANSI) for files saved by desktop Excel
          str = latin1.decode(bytes);
        } catch (_) {
          str = utf8.decode(bytes, allowMalformed: true);
        }
      }
    }

    str = _stripBom(str);
    str = _recoverByteEncodedCsv(str);
    return parseCsvString(
      str,
      defaultSource: defaultSource,
      defaultConsent: defaultConsent,
    );
  }

  /// Recovers CSV text if the uploaded file was saved as comma-separated byte numbers
  /// (e.g. "239,187,191,76,101,97,100,32,73,68...").
  static String _recoverByteEncodedCsv(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return input;

    final firstComma = trimmed.indexOf(',');
    if (firstComma != -1 && firstComma <= 5) {
      final firstToken = trimmed.substring(0, firstComma).trim();
      final firstNum = int.tryParse(firstToken);
      if (firstNum != null && firstNum >= 0 && firstNum <= 255) {
        final sampleTokens = trimmed
            .split(RegExp(r'[,\r\n\s]+'))
            .take(25)
            .toList();
        if (sampleTokens.length >= 8 &&
            sampleTokens.every((t) {
              final n = int.tryParse(t);
              return n != null && n >= 0 && n <= 255;
            })) {
          try {
            final allMatches = RegExp(r'\b\d+\b').allMatches(trimmed);
            final byteList = <int>[];
            for (final m in allMatches) {
              final v = int.tryParse(m.group(0)!);
              if (v != null && v >= 0 && v <= 255) {
                byteList.add(v);
              }
            }
            if (byteList.length >= 10) {
              final u8 = Uint8List.fromList(byteList);
              if (u8.length >= 3 &&
                  u8[0] == 0xEF &&
                  u8[1] == 0xBB &&
                  u8[2] == 0xBF) {
                return utf8.decode(u8.sublist(3), allowMalformed: true);
              }
              return utf8.decode(u8, allowMalformed: true);
            }
          } catch (_) {}
        }
      }
    }
    return input;
  }

  /// Parses Excel (.xlsx) file bytes into validated [LeadImportItem] records.
  static List<LeadImportItem> parseXlsxBytes(
    Uint8List bytes, {
    String defaultSource = 'AI & Machine Learning Workshop (Nov)',
    String defaultConsent = 'Event registration form',
  }) {
    final zipEntries = _readZipEntries(bytes);
    if (zipEntries.isEmpty) {
      throw const FormatException(
        'The uploaded file is not a valid zip / Excel file.',
      );
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
      (e) =>
          e.name.toLowerCase().contains('worksheets/sheet1.xml') ||
          e.name.toLowerCase().contains('sheet1.xml'),
      orElse: () => _SimpleZipEntry('', Uint8List(0)),
    );
    if (sheetEntry.data.isEmpty) {
      throw const FormatException(
        'Excel file does not contain a valid worksheet (sheet1.xml).',
      );
    }

    final sheetXml = utf8.decode(sheetEntry.data, allowMalformed: true);
    final rawRows = _parseSheetXmlRows(sheetXml, sharedStrings);

    return _process2dRows(
      rawRows,
      defaultSource: defaultSource,
      defaultConsent: defaultConsent,
    );
  }

  /// Generates a downloadable CSV containing all skipped, invalid, and failed rows.
  static String generateErrorReportCsv(List<LeadImportItem> items) {
    final buffer = StringBuffer();
    buffer.writeln('Row Number,Name,Phone,Email,Status,Reason');

    for (final item in items) {
      if (item.status == LeadImportStatus.valid ||
          item.status == LeadImportStatus.imported) {
        continue;
      }
      final cleanName = _escapeCsvField(item.name);
      final cleanPhone = _escapeCsvField(item.phone);
      final cleanEmail = _escapeCsvField(item.email);
      final cleanStatus = _escapeCsvField(item.status.label);
      final cleanReason = _escapeCsvField(
        item.issueMessage.isNotEmpty ? item.issueMessage : 'Skipped',
      );
      buffer.writeln(
        '${item.rowNumber},$cleanName,$cleanPhone,$cleanEmail,$cleanStatus,$cleanReason',
      );
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
      throw const FormatException(
        'The file is empty. Please upload a file with data rows.',
      );
    }

    int headerIndex = 0;
    Map<String, int> columnMap = {};
    int bestScore = -1;

    // Scan up to first 10 non-empty rows to find the most accurate header row
    final maxScan = rawRows.length < 10 ? rawRows.length : 10;
    for (int i = 0; i < maxScan; i++) {
      final row = rawRows[i];
      if (row.every((c) => c.trim().isEmpty)) continue;
      final candidateMap = _buildColumnMap(row);
      int score = candidateMap.length;
      if (candidateMap.containsKey('name')) score += 5;
      if (candidateMap.containsKey('phone')) score += 5;
      if (candidateMap.containsKey('email')) score += 2;
      if (candidateMap.containsKey('college') ||
          candidateMap.containsKey('college_branch')) {
        score += 2;
      }

      if (score > bestScore) {
        bestScore = score;
        headerIndex = i;
        columnMap = candidateMap;
        if (candidateMap.containsKey('name') &&
            candidateMap.containsKey('phone')) {
          break; // Perfect header row found
        }
      }
    }

    // Fallback: Infer unmapped columns (e.g. Phone, Name, Email) by inspecting data row patterns
    if (!columnMap.containsKey('name') || !columnMap.containsKey('phone')) {
      final inferred = _inferColumnsFromData(rawRows, headerIndex);
      if (!columnMap.containsKey('phone') && inferred.containsKey('phone')) {
        columnMap['phone'] = inferred['phone']!;
      }
      if (!columnMap.containsKey('name') && inferred.containsKey('name')) {
        columnMap['name'] = inferred['name']!;
      }
      if (!columnMap.containsKey('email') && inferred.containsKey('email')) {
        columnMap['email'] = inferred['email']!;
      }
    }

    // If phone is still missing, scan sample rows to locate any column containing valid phone numbers
    if (!columnMap.containsKey('phone')) {
      final sampleRows = rawRows.skip(headerIndex + 1).take(20).toList();
      final maxCols = sampleRows.fold<int>(
        0,
        (m, r) => r.length > m ? r.length : m,
      );
      for (int c = 0; c < maxCols; c++) {
        if (columnMap.values.contains(c)) continue;
        int matchCount = 0;
        for (final r in sampleRows) {
          if (c < r.length) {
            final norm = LeadPhoneValidator.normalize10Digits(r[c]);
            if (norm.length == 10 && RegExp(r'^[6-9]\d{9}$').hasMatch(norm)) {
              matchCount++;
            }
          }
        }
        if (matchCount > 0) {
          columnMap['phone'] = c;
          break;
        }
      }
    }

    // If still missing name, assign the first unmapped non-numeric column
    if (!columnMap.containsKey('name')) {
      final phoneCol = columnMap['phone'];
      final headerCols = rawRows[headerIndex].length;
      for (int c = 0; c < headerCols; c++) {
        if (c != phoneCol && !columnMap.values.contains(c)) {
          columnMap['name'] = c;
          break;
        }
      }
    }

    if (!columnMap.containsKey('phone') && !columnMap.containsKey('name')) {
      throw const FormatException(
        'Could not find required columns ("Name" and "Phone") in the header row. Please check the column headers.',
      );
    }
    if (!columnMap.containsKey('phone')) {
      throw const FormatException(
        'Could not find a valid "Phone" column in the uploaded file. Please ensure at least one column contains 10-digit phone numbers.',
      );
    }

    final results = <LeadImportItem>[];
    final seenPhoneToRowMap =
        <String, int>{}; // normalized 10-digit -> first row number

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

      var name = getCol('name');
      if (name.isEmpty) {
        name = 'Lead #$rowNumber';
      }
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
      final effectiveConsent = consentVal.isNotEmpty
          ? consentVal
          : defaultConsent;

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
      if (email.isNotEmpty &&
          !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
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
      final rawHeader = headers[col].toLowerCase().replaceAll(
        RegExp(r'[^a-z0-9_]'),
        '',
      );
      if (rawHeader.isEmpty) continue;

      for (final entry in _headerAliases.entries) {
        if (map.containsKey(entry.key)) continue;

        // Exact match against aliases
        if (entry.value.contains(rawHeader)) {
          map[entry.key] = col;
          break;
        }

        // Substring / suffix matches for compound names
        final matched = entry.value.any(
          (alias) =>
              rawHeader == alias ||
              rawHeader.startsWith('${alias}_') ||
              rawHeader.endsWith('_$alias') ||
              rawHeader == '${alias}no' ||
              rawHeader == '${alias}num' ||
              rawHeader == '${alias}number',
        );
        if (matched) {
          map[entry.key] = col;
          break;
        }
      }
    }
    return map;
  }

  /// Automatically infers column roles by scanning candidate data rows.
  static Map<String, int> _inferColumnsFromData(
    List<List<String>> rawRows,
    int headerIndex,
  ) {
    final inferred = <String, int>{};
    final sampleRows = rawRows.skip(headerIndex + 1).take(20).toList();
    if (sampleRows.isEmpty) return inferred;

    final numCols = sampleRows
        .map((r) => r.length)
        .fold<int>(0, (max, len) => len > max ? len : max);

    for (int col = 0; col < numCols; col++) {
      int phoneMatches = 0;
      int emailMatches = 0;
      int nameMatches = 0;
      int totalNonEmpty = 0;

      for (final row in sampleRows) {
        if (col >= row.length) continue;
        final cell = row[col].trim();
        if (cell.isEmpty) continue;
        totalNonEmpty++;

        final phone10 = LeadPhoneValidator.normalize10Digits(cell);
        if (phone10.length == 10 && RegExp(r'^[6-9]\d{9}$').hasMatch(phone10)) {
          phoneMatches++;
        } else if (cell.contains('@') && cell.contains('.')) {
          emailMatches++;
        } else if (RegExp(r'^[a-zA-Z\s\.À-ɏ]{2,50}$').hasMatch(cell) &&
            !cell.contains('http')) {
          nameMatches++;
        }
      }

      if (totalNonEmpty > 0) {
        if (phoneMatches / totalNonEmpty >= 0.4 &&
            !inferred.containsKey('phone')) {
          inferred['phone'] = col;
        } else if (emailMatches / totalNonEmpty >= 0.4 &&
            !inferred.containsKey('email')) {
          inferred['email'] = col;
        } else if (nameMatches / totalNonEmpty >= 0.4 &&
            !inferred.containsKey('name')) {
          inferred['name'] = col;
        }
      }
    }

    return inferred;
  }

  // ---------------------------------------------------------------------------
  // RFC-4180 CSV & TSV Text Parser
  // ---------------------------------------------------------------------------

  static String _stripBom(String s) {
    return s
        .replaceAll('\uFEFF', '')
        .replaceAll('\uFFFE', '')
        .replaceAll('\x00', '')
        .trimLeft();
  }

  static String _stripExcelSepDirective(String s) {
    if (s.toLowerCase().startsWith('sep=')) {
      final newlineIdx = s.indexOf(RegExp(r'\r\n|\r|\n'));
      if (newlineIdx != -1) {
        return s.substring(newlineIdx).trimLeft();
      }
    }
    return s;
  }

  static String _detectDelimiter(String text) {
    final lines = text
        .split(RegExp(r'\r\n|\r|\n'))
        .where((l) => l.trim().isNotEmpty)
        .take(5)
        .toList();
    if (lines.isEmpty) return ',';

    int commas = 0;
    int semicolons = 0;
    int tabs = 0;
    int pipes = 0;

    for (final line in lines) {
      commas += ','.allMatches(line).length;
      semicolons += ';'.allMatches(line).length;
      tabs += '\t'.allMatches(line).length;
      pipes += '|'.allMatches(line).length;
    }

    if (semicolons > commas && semicolons > tabs && semicolons > pipes) {
      return ';';
    }
    if (tabs > commas && tabs > semicolons && tabs > pipes) {
      return '\t';
    }
    if (pipes > commas && pipes > semicolons && pipes > tabs) {
      return '|';
    }
    return ',';
  }

  static List<List<String>> _splitCsvLines(
    String input, {
    String delimiter = ',',
  }) {
    final rows = <List<String>>[];
    final currentField = StringBuffer();
    final currentRow = <String>[];
    bool inQuotes = false;
    final length = input.length;

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
    if (field.contains(',') ||
        field.contains('"') ||
        field.contains('\n') ||
        field.contains('\r')) {
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
        final combined = tMatches
            .map((m) => _decodeXmlEntities(m.group(1) ?? ''))
            .join();
        strings.add(combined);
      } else {
        strings.add('');
      }
    }
    return strings;
  }

  static List<List<String>> _parseSheetXmlRows(
    String xml,
    List<String> sharedStrings,
  ) {
    final rows = <List<String>>[];
    final rowRegex = RegExp(
      r'<row\s+[^>]*?r="(\d+)"[^>]*?>(.*?)</row>',
      dotAll: true,
    );
    final cellRegex = RegExp(
      r'<c\s+r="([A-Z]+)(\d+)"(?:\s+[^>]*?t="([^"]*)")?[^>]*?>(?:<v>(.*?)</v>)?.*?</c>',
      dotAll: true,
    );

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
