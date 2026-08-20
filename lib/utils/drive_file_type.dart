/// Maps a Drive mimeType to the short mono "call number" tag shown on the
/// file-type badge — deliberately generic glyphs, not Google's own colored
/// icons, to keep the catalog-card look consistent across every account.
String typeTagForMimeType(String mimeType, String fileName) {
  const known = {
    'application/vnd.google-apps.document': 'DOC',
    'application/vnd.google-apps.spreadsheet': 'XLS',
    'application/vnd.google-apps.presentation': 'PPT',
    'application/vnd.google-apps.form': 'FORM',
    'application/vnd.google-apps.folder': 'DIR',
    'application/vnd.google-apps.drawing': 'DRAW',
    'application/pdf': 'PDF',
    'application/zip': 'ZIP',
  };
  if (known.containsKey(mimeType)) return known[mimeType]!;
  if (mimeType.startsWith('image/')) return 'IMG';
  if (mimeType.startsWith('video/')) return 'VID';
  if (mimeType.startsWith('audio/')) return 'AUD';
  if (mimeType.startsWith('text/')) return 'TXT';

  final dot = fileName.lastIndexOf('.');
  if (dot != -1 && dot < fileName.length - 1) {
    final ext = fileName.substring(dot + 1).toUpperCase();
    if (ext.length <= 4) return ext;
  }
  return 'FILE';
}
