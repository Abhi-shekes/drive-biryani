import 'package:flutter/material.dart';
import '../models/linked_account.dart';
import '../services/account_repository.dart';
import '../theme/app_text.dart';
import '../theme/app_theme.dart';

/// Explains the real, boring reason a reconnect is needed — Google's 7-day
/// testing-mode token limit — instead of a vague "session expired." Named
/// plainly so a weekly reconnect reads as an understood routine, not a
/// trust problem. See PLAN.md section 6 ("Known limitations").
class ReconnectSheet extends StatefulWidget {
  const ReconnectSheet({super.key, required this.account});

  final LinkedAccount account;

  @override
  State<ReconnectSheet> createState() => _ReconnectSheetState();
}

class _ReconnectSheetState extends State<ReconnectSheet> {
  bool _busy = false;

  Future<void> _reconnect() async {
    setState(() => _busy = true);
    try {
      await AccountRepository.instance.reconnectAccount(widget.account.email);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Reconnect failed: $e')),
        );
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _remove() async {
    await AccountRepository.instance.removeAccount(widget.account.email);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border.all(color: c.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: c.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: c.warn.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(Icons.history_toggle_off, color: c.warn, size: 22),
            ),
            const SizedBox(height: 14),
            Text(
              'Reconnect ${widget.account.email}',
              style: AppText.display(color: c.text, size: 18),
            ),
            const SizedBox(height: 8),
            Text(
              "Google limits this app to a 7-day connection while it's in "
              "testing. Your other accounts and search history aren't "
              "affected — this just re-opens the sign-in for this one.",
              style: AppText.body(color: c.textMuted, size: 13.5),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: c.brass,
                  foregroundColor: c.bg,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: _busy ? null : _reconnect,
                child: _busy
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: c.bg,
                        ),
                      )
                    : Text(
                        'Reconnect with Google',
                        style: AppText.body(color: c.bg, weight: FontWeight.w500),
                      ),
              ),
            ),
            TextButton(
              onPressed: _busy ? null : _remove,
              child: Text(
                'Remove this account',
                style: AppText.body(color: c.textMuted, size: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
