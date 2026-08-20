import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/drive_file.dart';
import '../models/linked_account.dart';
import '../utils/drive_file_type.dart';
import 'account_repository.dart';

/// One account's search outcome, as it arrives — searches run in parallel
/// per account and are genuinely independent, so the UI can show results
/// streaming in rather than waiting for the slowest account.
class AccountSearchResult {
  const AccountSearchResult({
    required this.account,
    required this.files,
    this.failed = false,
  });

  final LinkedAccount account;
  final List<DriveFile> files;
  final bool failed;
}

/// Queries Drive's `files.list` directly from the app — one HTTPS call per
/// linked account, no backend. Uses `drive.metadata.readonly`, so results
/// carry metadata only (name, type, modified time, link), not file content.
class DriveSearchService {
  const DriveSearchService();

  static const _endpoint = 'https://www.googleapis.com/drive/v3/files';

  /// Emits one [AccountSearchResult] per linked account as it completes.
  /// Accounts already known to be expired are skipped up front rather than
  /// spending a request on a call we know will fail.
  Stream<AccountSearchResult> search(String query) {
    final controller = StreamController<AccountSearchResult>();
    final accounts = AccountRepository.instance.accounts
        .where((a) => a.status != ConnectionStatus.expired)
        .toList();

    if (accounts.isEmpty) {
      scheduleMicrotask(controller.close);
      return controller.stream;
    }

    var remaining = accounts.length;
    for (final account in accounts) {
      _searchAccount(account, query).then((files) {
        if (!controller.isClosed) {
          controller.add(AccountSearchResult(account: account, files: files));
        }
      }).catchError((Object _) {
        // Expected for a mid-search invalid_grant or a dropped connection —
        // the account's own status pill already surfaces the problem, so
        // the search UI just quietly has nothing from that account.
        if (!controller.isClosed) {
          controller.add(
            AccountSearchResult(account: account, files: const [], failed: true),
          );
        }
      }).whenComplete(() {
        remaining--;
        if (remaining == 0 && !controller.isClosed) controller.close();
      });
    }
    return controller.stream;
  }

  Future<List<DriveFile>> _searchAccount(
    LinkedAccount account,
    String query,
  ) async {
    final token =
        await AccountRepository.instance.getValidAccessToken(account.email);

    final escaped = query.replaceAll(r'\', r'\\').replaceAll("'", r"\'");
    final q = "(name contains '$escaped' or fullText contains '$escaped') "
        'and trashed = false';

    final uri = Uri.parse(_endpoint).replace(queryParameters: {
      'q': q,
      'pageSize': '15',
      'orderBy': 'modifiedTime desc',
      'fields': 'files(id,name,mimeType,modifiedTime,webViewLink,sharedWithMeTime)',
    });

    final res = await http.get(uri, headers: {'Authorization': 'Bearer $token'});
    if (res.statusCode != 200) {
      throw Exception('Drive search failed (${res.statusCode})');
    }

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final files = (body['files'] as List<dynamic>?) ?? const [];

    return files
        .cast<Map<String, dynamic>>()
        .map((f) => _toDriveFile(f, account))
        .toList();
  }

  DriveFile _toDriveFile(Map<String, dynamic> json, LinkedAccount account) {
    final name = json['name'] as String? ?? 'Untitled';
    final mimeType = json['mimeType'] as String? ?? 'application/octet-stream';
    return DriveFile(
      id: json['id'] as String,
      name: name,
      pathHint: json['sharedWithMeTime'] != null ? 'Shared with me' : 'My Drive',
      typeTag: typeTagForMimeType(mimeType, name),
      modifiedAt: DateTime.tryParse(json['modifiedTime'] as String? ?? '') ??
          DateTime.now(),
      accountEmail: account.email,
      accountLabel: account.label.toLowerCase(),
      accountInkIndex: account.inkIndex,
      webViewLink: json['webViewLink'] as String? ?? '',
    );
  }
}
