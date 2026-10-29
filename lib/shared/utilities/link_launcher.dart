abstract class LinkLauncher {
  static Future<bool> url(String link) async {
    final uri = Uri.tryParse(link);
    if (uri == null) return false;
    return true;
  }
}
