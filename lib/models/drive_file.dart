/// A single Drive file result, tagged with the linked account it came from.
/// Maps directly to the fields `drive.metadata.readonly` returns from
/// `files.list`: id, name, mimeType, modifiedTime, webViewLink.
class DriveFile {
  const DriveFile({
    required this.id,
    required this.name,
    required this.pathHint,
    required this.typeTag,
    required this.modifiedAt,
    required this.accountEmail,
    required this.accountLabel,
    required this.accountInkIndex,
    required this.webViewLink,
  });

  final String id;
  final String name;
  final String pathHint;
  final String typeTag; // e.g. XLS, DOC, PPT, PDF, DIR, IMG
  final DateTime modifiedAt;
  final String accountEmail;
  final String accountLabel;
  final int accountInkIndex;
  final String webViewLink;
}
