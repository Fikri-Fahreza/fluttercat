import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import 'profile/profile_screen.dart';
import 'feed/feed_screen.dart';
import 'camera/camera_screen.dart';
import 'catdex/catdex_screen.dart';
import 'chat/chat_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  DateTime? _lastPressedAt;
  final List<int> _history = [];

  final List<Widget> _screens = const [
    ProfileScreen(),
    FeedScreen(),
    CatDexScreen(),
    ChatScreen(),
  ];

  void _changeTab(int index) {
    if (_currentIndex != index) {
      setState(() {
        _history.add(_currentIndex);
        _currentIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        // 1. Jika ada riwayat halaman sebelumnya, kembali ke halaman sebelumnya dulu
        if (_history.isNotEmpty) {
          final prevIndex = _history.removeLast();
          setState(() {
            _currentIndex = prevIndex;
          });
          return;
        }

        // 2. Jika riwayat sudah kosong, tampilkan notifikasi "tekan sekali lagi"
        final now = DateTime.now();
        if (_lastPressedAt == null || now.difference(_lastPressedAt!) > const Duration(seconds: 2)) {
          _lastPressedAt = now;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tekan sekali lagi untuk keluar aplikasi'),
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }

        // 3. Keluar dari aplikasi secara bersih
        await SystemNavigator.pop();
      },
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: _screens,
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: AppColors.cardCream,
            border: Border(top: BorderSide(color: AppColors.borderCream, width: 1)),
            boxShadow: [
              BoxShadow(
                color: AppColors.textBrown.withOpacity(0.06),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _navItem(0, Icons.person, Icons.person_outline, 'Profile'),
                  _navItem(1, Icons.newspaper, Icons.newspaper_outlined, 'Feed'),
                  _cameraButton(),
                  _navItem(2, Icons.photo_library, Icons.photo_library_outlined, 'Album'),
                  _navItem(3, Icons.forum, Icons.forum_outlined, 'Chat'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData activeIcon, IconData inactiveIcon, String label) {
    final isActive = _currentIndex == index;
    return GestureDetector(
      onTap: () => _changeTab(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.lightGreen : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? activeIcon : inactiveIcon,
              color: isActive ? AppColors.primaryGreen : AppColors.textMuted,
              size: 22,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.nunito(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                color: isActive ? AppColors.primaryGreen : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cameraButton() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CameraScreen()),
        );
      },
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: AppColors.primaryGreen,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.cardCream, width: 3),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryGreen.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 26),
      ),
    );
  }
}
