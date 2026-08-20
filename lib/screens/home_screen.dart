import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/drive_file.dart';
import '../services/account_repository.dart';
import '../services/drive_search_service.dart';
import '../services/recent_searches_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../theme/app_theme.dart';
import '../widgets/account_avatar.dart';
import '../widgets/result_row.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _controller = TextEditingController();
  final _searchService = const DriveSearchService();

  Timer? _debounce;
  StreamSubscription<AccountSearchResult>? _subscription;

  bool _searching = false;
  List<DriveFile> _results = [];
  Set<String> _pendingEmails = {};

  @override
  void dispose() {
    _debounce?.cancel();
    _subscription?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    final query = value.trim();
    if (query.isEmpty) {
      _subscription?.cancel();
      setState(() {
        _searching = false;
        _results = [];
        _pendingEmails = {};
      });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 400), () => _runSearch(query));
  }

  void _runSearch(String query) {
    _subscription?.cancel();
    RecentSearchesRepository.instance.record(query);
    final accounts = AccountRepository.instance.accounts;

    setState(() {
      _results = [];
      _pendingEmails = accounts.map((a) => a.email).toSet();
    });

    if (accounts.isEmpty) return;

    _subscription = _searchService.search(query).listen((event) {
      if (!mounted) return;
      setState(() {
        _pendingEmails.remove(event.account.email);
        if (!event.failed) {
          _results = [..._results, ...event.files]
            ..sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
        }
      });
    });
  }

  Future<void> _openFile(DriveFile file) async {
    final uri = Uri.tryParse(file.webViewLink);
    if (uri == null) return;
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open that file.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
            child: Row(
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: 'DriveBiryani',
                        style: AppText.display(color: c.text, size: 28),
                      ),
                      TextSpan(
                        text: '.',
                        style: AppText.display(
                          color: c.brass,
                          size: 28,
                          italic: true,
                          weight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(18, _searching ? 10 : 26, 18, 0),
            child: _SearchField(controller: _controller, onChanged: _onQueryChanged),
          ),
          if (_searching)
            Expanded(child: _buildSearchBody(c))
          else
            Expanded(child: _buildRecentsBody(c)),
        ],
      ),
    );
  }

  Widget _buildSearchBody(AppColors c) {
    final accounts = AccountRepository.instance.accounts;

    if (accounts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(18, 24, 18, 0),
        child: Text(
          'No accounts linked yet — add one from The Stacks tab, then search '
          'again.',
          style: AppText.body(color: c.textMuted, size: 13),
        ),
      );
    }

    final pendingLabels = accounts
        .where((a) => _pendingEmails.contains(a.email))
        .map((a) => a.label)
        .toList();

    return Column(
      children: [
        if (pendingLabels.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 6),
            child: Row(
              children: [
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 1.6, color: c.brass),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${pendingLabels.join(', ')} still searching…',
                    style: AppText.mono(color: c.textMuted, size: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        if (_results.isEmpty && pendingLabels.isEmpty)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
              child: Text(
                'No results.',
                style: AppText.body(color: c.textMuted, size: 13),
              ),
            ),
          )
        else
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(top: 4, bottom: 12),
              children: [
                ..._results.map(
                  (f) => ResultRow(file: f, onTap: () => _openFile(f)),
                ),
                ...accounts
                    .where((a) => _pendingEmails.contains(a.email))
                    .map((a) => ResultRowSkeleton(inkIndex: a.inkIndex)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildRecentsBody(AppColors c) {
    return Column(
      children: [
        ListenableBuilder(
          listenable: AccountRepository.instance,
          builder: (context, _) {
            final accounts = AccountRepository.instance.accounts;
            if (accounts.isEmpty) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 0),
                child: Text(
                  'No accounts linked yet — add one from The Stacks tab.',
                  style: AppText.body(color: c.textMuted, size: 12.5),
                ),
              );
            }
            return Padding(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 4),
              child: SizedBox(
                height: 34,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: accounts.length,
                  separatorBuilder: (context, i) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final a = accounts[i];
                    return Container(
                      padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
                      decoration: BoxDecoration(
                        color: c.surface,
                        border: Border.all(color: c.border),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AccountAvatar(account: a, size: 24),
                          const SizedBox(width: 7),
                          Text(
                            a.label,
                            style: AppText.body(color: c.textMuted, size: 12),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            );
          },
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 22, 18, 6),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('RECENT SEARCHES', style: AppText.eyebrow(c.textMuted)),
          ),
        ),
        Expanded(
          child: ListenableBuilder(
            listenable: RecentSearchesRepository.instance,
            builder: (context, _) {
              final searches = RecentSearchesRepository.instance.searches;
              if (searches.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 0),
                  child: Text(
                    'Nothing yet — searches you run will show up here.',
                    style: AppText.body(color: c.textMuted, size: 12.5),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                itemCount: searches.length,
                itemBuilder: (context, i) {
                  final q = searches[i];
                  return InkWell(
                    onTap: () {
                      _controller.text = q;
                      _onQueryChanged(q);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: c.border)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.history, size: 15, color: c.textMuted),
                          const SizedBox(width: 10),
                          Text(q, style: AppText.body(color: c.textMuted)),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.search, size: 18, color: c.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              cursorColor: c.brass,
              style: AppText.body(color: c.text, size: 15),
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                hintText: 'Search everything you own…',
                hintStyle: AppText.body(color: c.textMuted, size: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
