import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'ui/screens/home/home_screen.dart';
import 'services/update_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: SplitCountApp(),
    ),
  );
}

class SplitCountApp extends ConsumerStatefulWidget {
  const SplitCountApp({super.key});

  @override
  ConsumerState<SplitCountApp> createState() => _SplitCountAppState();
}

class _SplitCountAppState extends ConsumerState<SplitCountApp> {
  @override
  void initState() {
    super.initState();
    _checkAppUpdate();
  }

  Future<void> _checkAppUpdate() async {
    // Optionally supply your GitHub repo 'username/splitCount' to check releases
    final info = await UpdateService.checkForUpdate();
    if (info.hasUpdate && mounted) {
      ScaffoldMessenger.of(context).showMaterialBanner(
        MaterialBanner(
          content: Text('New SplitCount update available (v${info.latestVersion})'),
          actions: [
            TextButton(
              onPressed: () => UpdateService.launchDownload(info.downloadUrl),
              child: const Text('Update Now'),
            ),
            TextButton(
              onPressed: () => ScaffoldMessenger.of(context).hideCurrentMaterialBanner(),
              child: const Text('Dismiss'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SplitCount',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0284C7),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        cardColor: const Color(0xFF1E293B),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E293B),
          elevation: 0,
        ),
      ),
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0284C7),
          brightness: Brightness.light,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
