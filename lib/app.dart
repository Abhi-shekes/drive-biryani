import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/stacks_screen.dart';
import 'services/account_repository.dart';
import 'services/recent_searches_repository.dart';
import 'theme/app_theme.dart';

class DriveBiryaniApp extends StatelessWidget {
  const DriveBiryaniApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DriveBiryani',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      home: const _RootShell(),
    );
  }
}

class _RootShell extends StatefulWidget {
  const _RootShell();

  @override
  State<_RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<_RootShell> {
  int _index = 0;

  static const _screens = [HomeScreen(), StacksScreen()];

  @override
  void initState() {
    super.initState();
    AccountRepository.instance.load();
    RecentSearchesRepository.instance.load();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: c.surface,
          indicatorColor: Colors.transparent,
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final active = states.contains(WidgetState.selected);
            return TextStyle(
              fontFamily: 'IBM Plex Mono',
              fontSize: 10.5,
              color: active ? c.brass : c.textMuted,
            );
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            final active = states.contains(WidgetState.selected);
            return IconThemeData(color: active ? c.brass : c.textMuted, size: 20);
          }),
        ),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.search), label: 'Search'),
            NavigationDestination(icon: Icon(Icons.dns_outlined), label: 'Stacks'),
          ],
        ),
      ),
    );
  }
}
