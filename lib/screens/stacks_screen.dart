import 'package:flutter/material.dart';
import '../models/linked_account.dart';
import '../services/account_repository.dart';
import '../theme/app_text.dart';
import '../theme/app_theme.dart';
import '../widgets/account_avatar.dart';
import '../widgets/status_pill.dart';
import 'reconnect_sheet.dart';

/// Account management, named after the library stacks rather than
/// "Settings" — each linked account is a shelf: its own ink, a plain-language
/// status pill, and (when relevant) a one-tap way to reconnect.
class StacksScreen extends StatefulWidget {
  const StacksScreen({super.key});

  @override
  State<StacksScreen> createState() => _StacksScreenState();
}

class _StacksScreenState extends State<StacksScreen> {
  final _repo = AccountRepository.instance;
  bool _linking = false;

  /// Kept on screen rather than shown in a snackbar: a linking failure is
  /// something you need to read, and often act on, after the browser hands
  /// control back — a toast that fades in four seconds loses exactly the
  /// detail that explains what went wrong.
  String? _linkError;

  Future<void> _addAccount() async {
    setState(() {
      _linking = true;
      _linkError = null;
    });
    try {
      await _repo.linkNewAccount();
    } catch (e) {
      if (mounted) setState(() => _linkError = e.toString());
    } finally {
      if (mounted) setState(() => _linking = false);
    }
  }

  void _openReconnect(LinkedAccount account) {
    if (account.status == ConnectionStatus.connected) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ReconnectSheet(account: account),
    );
  }

  Future<void> _renameAccount(LinkedAccount account) async {
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => _RenameDialog(account: account),
    );
    if (result == null) return;
    await _repo.renameAccount(account.email, result);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SafeArea(
      child: ListenableBuilder(
        listenable: _repo,
        builder: (context, _) {
          final accounts = _repo.accounts;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 4),
                child: Text(
                  'The Stacks',
                  style: AppText.display(color: c.text, size: 28),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
                  children: [
                    if (accounts.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'No accounts linked yet. Add one below to start '
                          'searching its Drive.',
                          style: AppText.body(color: c.textMuted, size: 13),
                        ),
                      ),
                    ...accounts.map(
                      (a) => _StackRow(
                        account: a,
                        onTapStatus: () => _openReconnect(a),
                        onRename: () => _renameAccount(a),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _AddAccountRow(loading: _linking, onTap: _addAccount),
                    if (_linkError != null) _LinkErrorBox(message: _linkError!),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StackRow extends StatelessWidget {
  const _StackRow({
    required this.account,
    required this.onTapStatus,
    required this.onRename,
  });

  final LinkedAccount account;
  final VoidCallback onTapStatus;
  final VoidCallback onRename;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 3, color: account.ink),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                child: Row(
                  children: [
                    AccountAvatar(account: account, size: 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  account.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppText.body(
                                    color: c.text,
                                    size: 14,
                                    weight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: onRename,
                                icon: Icon(
                                  Icons.edit_outlined,
                                  size: 17,
                                  color: c.textMuted,
                                ),
                                tooltip: 'Rename',
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints:
                                    const BoxConstraints(minWidth: 32, minHeight: 32),
                              ),
                              const SizedBox(width: 4),
                              GestureDetector(
                                onTap: onTapStatus,
                                child: StatusPill(
                                  status: account.status,
                                  daysUntilExpiry: account.daysUntilExpiry,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          // Full width, no maxLines/ellipsis: the email must
                          // never be clipped just because the status pill
                          // above it is wide (e.g. "Connected").
                          Text(
                            account.email,
                            softWrap: true,
                            style: AppText.mono(color: c.textMuted, size: 11.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dialog content for setting an account's nickname. A StatefulWidget so the
/// controller's dispose() is tied to this widget actually leaving the tree —
/// disposing it manually right after showDialog's future resolves fires
/// while the dialog's exit transition is still animating the TextField.
class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.account});

  final LinkedAccount account;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final _controller = TextEditingController(
    text: widget.account.customLabel ?? '',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AlertDialog(
      backgroundColor: c.surface,
      title: Text('Name this account', style: AppText.body(color: c.text, size: 16)),
      content: TextField(
        controller: _controller,
        autofocus: true,
        style: AppText.body(color: c.text, size: 14),
        decoration: InputDecoration(
          hintText: widget.account.googleName,
          hintStyle: AppText.body(color: c.textMuted, size: 14),
        ),
        onSubmitted: (value) => Navigator.pop(context, value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, ''),
          child: Text('Reset', style: AppText.body(color: c.textMuted, size: 13)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: Text('Save', style: AppText.body(color: c.brass, size: 13)),
        ),
      ],
    );
  }
}

class _AddAccountRow extends StatelessWidget {
  const _AddAccountRow({required this.onTap, required this.loading});
  final VoidCallback onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: loading ? null : onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: c.border, width: 1.4),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading)
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 1.6,
                  color: c.textMuted,
                ),
              )
            else
              Icon(Icons.add, size: 16, color: c.textMuted),
            const SizedBox(width: 8),
            Text(
              loading ? 'Opening Google sign-in…' : 'Add a Google account',
              style: AppText.body(color: c.textMuted, size: 13),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows why a link attempt failed, in full and selectable — the underlying
/// OAuth/network errors carry the actionable detail (a scope that wasn't
/// granted, a revoked consent, no connectivity) and truncating them just
/// forces a second attempt to learn the same thing.
class _LinkErrorBox extends StatelessWidget {
  const _LinkErrorBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.danger.withValues(alpha: 0.10),
        border: Border.all(color: c.danger.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline, size: 16, color: c.danger),
              const SizedBox(width: 8),
              Text(
                "That account didn't link",
                style: AppText.body(
                  color: c.danger,
                  size: 13,
                  weight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SelectableText(
            message,
            style: AppText.mono(color: c.textMuted, size: 11),
          ),
        ],
      ),
    );
  }
}
