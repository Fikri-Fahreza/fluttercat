import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'providers/auth_provider.dart';
import 'theme/app_theme.dart';
import 'screens/auth/login_screen.dart';
import 'screens/main_shell.dart';

import 'package:intl/date_symbol_data_local.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null);
  runApp(
    ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: const StreetCatApp(),
    ),
  );
}

class StreetCatApp extends StatelessWidget {
  const StreetCatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PawFinder',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const AppGate(),
    );
  }
}

class AppGate extends StatefulWidget {
  const AppGate({super.key});

  @override
  State<AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<AppGate> {
  bool _isLoading = true;
  double _loadProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // Load token
    await context.read<AuthProvider>().loadToken();
    
    // Simulate loading progress
    Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 250));
      if (!mounted) return false;
      setState(() {
        _loadProgress += 0.1;
        if (_loadProgress >= 1.0) {
          _loadProgress = 1.0;
          _isLoading = false;
        }
      });
      return _isLoading;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.bgCream,
        body: Stack(
          children: [
            // Center Content
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Getting headbutted',
                      style: GoogleFonts.nunito(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textBrown,
                        height: 1.3,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      'awake at sunrise...',
                      style: GoogleFonts.nunito(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textBrown,
                        height: 1.3,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 25),
                    // Progress Bar
                    Container(
                      width: 200,
                      height: 12,
                      decoration: BoxDecoration(
                        color: AppColors.borderCream,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Stack(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 200 * _loadProgress,
                            height: 12,
                            decoration: BoxDecoration(
                              color: AppColors.primaryGreen,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Peeking Cat bottom-left
            Positioned(
              bottom: -30,
              left: -35,
              child: Transform.rotate(
                angle: 15 * 3.14159 / 180,
                child: Image.asset(
                  'assets/images/app_icon.png',
                  width: 140,
                  height: 140,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    // Fallback if image doesn't exist
                    return const SizedBox(
                      width: 140,
                      height: 140,
                      child: Center(child: Text('🐱', style: TextStyle(fontSize: 48))),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      );
    }

    final auth = context.watch<AuthProvider>();
    return auth.isLoggedIn ? const MainShell() : const LoginScreen();
  }
}
