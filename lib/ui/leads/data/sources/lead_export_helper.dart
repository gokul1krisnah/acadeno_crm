import '../../../../core/utils/file_download_helper.dart';
import '../model/lead_models.dart';

/// Helper to generate and download CSV exports of lead records.
class LeadExportHelper {
  /// Converts [leads] to clean CSV format.
  static String generateCsv(List<LeadRecord> leads) {
    final buffer = StringBuffer();
    // CSV Header row
    buffer.writeln(
      'Lead ID,Name,Phone,Email,College & Branch,Course,Campaign / Source,Status,Assigned To,Assignment Slot,Last Contact,Notes,Created Date',
    );

    for (final l in leads) {
      final id = _escape(l.id);
      final name = _escape(l.name);
      final phone = _escape(l.phone);
      final email = _escape(l.email);
      final college = _escape(l.collegeBranch);
      final course = _escape(l.course);
      final source = _escape(l.source);
      final status = _escape(l.status);
      final assignedTo = _escape(l.assignedToName);
      final assignmentSlot = _escape(l.assignedDateLabel ?? '—');
      final lastContact = _escape(l.lastContact);
      final notes = _escape(l.notes);
      final createdAt = _escape(
        l.createdAt?.toIso8601String().split('T').first ?? '—',
      );

      buffer.writeln(
        '$id,$name,$phone,$email,$college,$course,$source,$status,$assignedTo,$assignmentSlot,$lastContact,$notes,$createdAt',
      );
    }

    return buffer.toString();
  }

  /// Triggers instant CSV file download for [leads].
  static Future<bool> exportLeads({
    required List<LeadRecord> leads,
    String? customFileName,
  }) async {
    final now = DateTime.now();
    final dateStr =
        '${now.year}_${now.month.toString().padLeft(2, '0')}_${now.day.toString().padLeft(2, '0')}';
    final fileName = customFileName ?? 'acadeno_leads_export_$dateStr.csv';
    final csvContent = generateCsv(leads);
    return FileDownloadHelper.downloadCsv(
      fileName: fileName,
      content: csvContent,
    );
  }

  static String _escape(String value) {
    var v = value.trim();
    if (v.contains(',') ||
        v.contains('"') ||
        v.contains('\n') ||
        v.contains('\r')) {
      v = '"${v.replaceAll('"', '""')}"';
    }
    return v;
  }
}
