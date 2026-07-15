import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:io';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../config/api_config.dart';

// Import sub screens
import 'leaderboard_screen.dart';
import 'achievements_screen.dart';
import 'encyclopedia_screen.dart';
import 'gift_inbox_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final Dio _dio = Dio();
  Map<String, dynamic>? _profileData;
  bool _isLoading = true;

  // Edit Profile States
  bool _showEditModal = false;
  final TextEditingController _editNameController = TextEditingController();
  final TextEditingController _editUsernameController = TextEditingController();
  final TextEditingController _editPasswordController = TextEditingController();
  String? _editAvatarBase64;
  File? _selectedAvatarFile;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchProfile());
  }

  @override
  void dispose() {
    _editNameController.dispose();
    _editUsernameController.dispose();
    _editPasswordController.dispose();
    super.dispose();
  }

  String get _token => context.read<AuthProvider>().token ?? '';
  Options get _authOptions => Options(headers: {'Authorization': 'Bearer $_token', 'Accept': 'application/json'});

  Future<void> _fetchProfile() async {
    try {
      final response = await _dio.get(
        '${ApiConfig.baseUrl}/api/user/profile',
        options: _authOptions,
      );
      setState(() {
        _profileData = response.data;
        _isLoading = false;
      });

      // Initialize edit fields
      final user = _profileData?['user'];
      if (user != null) {
        _editNameController.text = user['name'] ?? '';
        _editUsernameController.text = user['username'] ?? '';
        _editAvatarBase64 = user['avatar'];
      }
    } catch (e) {
      debugPrint('Failed to fetch profile: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 200,
      maxHeight: 200,
      imageQuality: 50,
    );

    if (image != null) {
      final file = File(image.path);
      final bytes = await file.readAsBytes();
      setState(() {
        _selectedAvatarFile = file;
        _editAvatarBase64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      });
    }
  }

  Future<void> _updateProfile() async {
    if (_editNameController.text.trim().isEmpty || _editUsernameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama dan Username tidak boleh kosong.')),
      );
      return;
    }

    setState(() => _isUpdating = true);
    try {
      await _dio.post(
        '${ApiConfig.baseUrl}/api/user/profile/update',
        data: {
          'name': _editNameController.text.trim(),
          'username': _editUsernameController.text.trim().toLowerCase(),
          'password': _editPasswordController.text.trim().isNotEmpty ? _editPasswordController.text.trim() : null,
          'avatar': _editAvatarBase64,
        },
        options: _authOptions,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil Anda berhasil diperbarui!')),
      );
      setState(() {
        _showEditModal = false;
        _editPasswordController.clear();
      });
      _fetchProfile(); // Refresh profile screen data
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal memperbarui profil.')),
      );
    }
    setState(() => _isUpdating = false);
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardCream,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Logout', style: GoogleFonts.nunito(color: AppColors.textBrown, fontWeight: FontWeight.bold)),
        content: Text('Yakin mau logout dari PawFinder?', style: GoogleFonts.nunito(color: AppColors.textBrown)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Batal', style: GoogleFonts.nunito(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Logout', style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await context.read<AuthProvider>().logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.bgCream,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: AppColors.primaryGreen),
              const SizedBox(height: 15),
              Text(
                'Memuat Jurnal Kucing...',
                style: GoogleFonts.nunito(color: AppColors.textBrown, fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      );
    }

    final user = _profileData?['user'] ?? {};
    final int catsCount = int.tryParse(_profileData?['cats_count']?.toString() ?? '') ?? 0;
    final int score = int.tryParse(user['total_score']?.toString() ?? '') ?? 0;
    final int level = (score ~/ 100) + 1;
    final double levelProgress = (score % 100) / 100.0;
    final int streak = int.tryParse(user['current_streak']?.toString() ?? '') ?? 0;

    final String? avatar = user['avatar'];
    ImageProvider avatarProvider;
    if (avatar != null && avatar.isNotEmpty) {
      if (avatar.startsWith('data:image')) {
        try {
          final base64Str = avatar.split(',').last;
          avatarProvider = MemoryImage(base64Decode(base64Str));
        } catch (_) {
          avatarProvider = const AssetImage('assets/images/cat_character.png');
        }
      } else {
        final url = avatar.startsWith('http') ? avatar : '${ApiConfig.baseUrl}$avatar';
        avatarProvider = NetworkImage(url);
      }
    } else {
      avatarProvider = const AssetImage('assets/images/cat_character.png');
    }

    return Scaffold(
      backgroundColor: AppColors.bgCream,
      body: Stack(
        children: [
          SafeArea(
            child: RefreshIndicator(
              color: AppColors.primaryGreen,
              onRefresh: _fetchProfile,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Column(
                  children: [
                    // Top Header Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 54,
                              height: 54,
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.primaryGreen, width: 2),
                              ),
                              child: CircleAvatar(
                                radius: 24,
                                backgroundColor: AppColors.cardCream,
                                backgroundImage: avatarProvider,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user['name'] ?? 'Guest',
                                  style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textBrown),
                                ),
                                Text(
                                  '@${user['username'] ?? 'username'}',
                                  style: GoogleFonts.nunito(fontSize: 12, color: AppColors.primaryGreen, fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            // Logout icon
                            IconButton(
                              icon: const Icon(Icons.logout, color: AppColors.danger, size: 20),
                              onPressed: _logout,
                            ),
                            GestureDetector(
                              onTap: () => setState(() => _showEditModal = true),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.lightGreen,
                                  border: Border.all(color: AppColors.primaryGreen),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.edit, size: 12, color: AppColors.primaryGreen),
                                    const SizedBox(width: 4),
                                    Text('EDIT PROFIL', style: GoogleFonts.nunito(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.primaryGreen)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 25),

                    // Mascot Center Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.cardCream,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.borderCream),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.textBrown.withOpacity(0.03),
                            blurRadius: 6,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Image.asset(
                            'assets/images/cat_character.png',
                            width: 140,
                            height: 140,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => const SizedBox(
                              height: 140,
                              child: Center(child: Text('🐱', style: TextStyle(fontSize: 64))),
                            ),
                          ),
                          const SizedBox(height: 15),
                          // Level progress row
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryGreen,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text('LVL $level', style: GoogleFonts.nunito(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: levelProgress,
                                    backgroundColor: AppColors.borderCream,
                                    color: AppColors.primaryGreen,
                                    minHeight: 8,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 25),

                    // Navigation Grid Menu
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 2.6,
                      children: [
                        _gridMenuItem(
                          label: 'Leaderboard',
                          icon: Icons.emoji_events,
                          iconColor: const Color(0xFFFFD700),
                          bgColor: const Color(0xFFFFD700).withOpacity(0.12),
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LeaderboardScreen())),
                        ),
                        _gridMenuItem(
                          label: 'Achievement',
                          icon: Icons.workspace_premium,
                          iconColor: const Color(0xFF9B59B6),
                          bgColor: const Color(0xFF9B59B6).withOpacity(0.12),
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AchievementsScreen())),
                        ),
                        _gridMenuItem(
                          label: 'Catlogue',
                          icon: Icons.menu_book,
                          iconColor: const Color(0xFF27AE60),
                          bgColor: const Color(0xFF27AE60).withOpacity(0.12),
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EncyclopediaScreen())),
                        ),
                        _gridMenuItem(
                          label: 'Kado Masuk',
                          icon: Icons.card_giftcard,
                          iconColor: const Color(0xFFFF6B6B),
                          bgColor: const Color(0xFFFF6B6B).withOpacity(0.12),
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GiftInboxScreen())),
                        ),
                      ],
                    ),
                    const SizedBox(height: 25),

                    // Journal Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.cardCream,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.borderCream),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('SIGHTINGS LOGGED', style: GoogleFonts.nunito(fontSize: 8, fontWeight: FontWeight.w800, color: AppColors.textMuted, letterSpacing: 0.5)),
                                  const SizedBox(height: 2),
                                  Text('Jurnal Kucing Liar', style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textBrown)),
                                ],
                              ),
                              Container(
                                width: 32,
                                height: 32,
                                decoration: const BoxDecoration(color: AppColors.primaryGreen, shape: BoxShape.circle),
                                alignment: Alignment.center,
                                child: Text('$catsCount', style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 15),
                          // Stats List
                          _journalStatItem(num: '01', icon: Icons.star, iconColor: const Color(0xFFE4C078), bgColor: const Color(0xFFFFF9E6), label: 'TOTAL SKOR', value: '$score Poin'),
                          const SizedBox(height: 10),
                          _journalStatItem(num: '02', icon: Icons.camera_alt, iconColor: AppColors.primaryGreen, bgColor: const Color(0xFFEBF3E8), label: 'DITANGKAP HARI INI', value: '$catsCount'),
                          const SizedBox(height: 10),
                          _journalStatItem(num: '03', icon: Icons.local_fire_department, iconColor: const Color(0xFFD96A6A), bgColor: const Color(0xFFF6F2EB), label: 'STREAK PENANGKAPAN', value: '$streak Hari'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ),

          // Edit Profile Modal Overlay
          if (_showEditModal) _buildEditModal(avatarProvider),
        ],
      ),
    );
  }

  Widget _gridMenuItem({
    required String label,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.cardCream,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderCream),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 10),
            Text(label, style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textBrown)),
          ],
        ),
      ),
    );
  }

  Widget _journalStatItem({
    required String num,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(color: Colors.black.withOpacity(0.08), shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(num, style: GoogleFonts.nunito(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textBrown)),
          ),
          const SizedBox(width: 10),
          Icon(icon, color: iconColor, size: 16),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.nunito(fontSize: 8, fontWeight: FontWeight.w800, color: AppColors.textMuted)),
                Text(value, style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textBrown)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditModal(ImageProvider currentAvatar) {
    ImageProvider pickerAvatarProvider;
    if (_editAvatarBase64 != null && _editAvatarBase64!.startsWith('data:image')) {
      final base64Str = _editAvatarBase64!.split(',').last;
      pickerAvatarProvider = MemoryImage(base64Decode(base64Str));
    } else {
      pickerAvatarProvider = currentAvatar;
    }

    return Container(
      color: Colors.black54,
      width: double.infinity,
      height: double.infinity,
      alignment: Alignment.bottomCenter,
      child: Material(
        color: AppColors.bgCream,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 40,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Edit Profil Anda', style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textBrown)),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textBrown),
                    onPressed: () => setState(() => _showEditModal = false),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Avatar Picker
              Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    padding: const EdgeInsets.all(2.5),
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.primaryGreen, width: 2.5)),
                    child: CircleAvatar(
                      radius: 36,
                      backgroundColor: AppColors.cardCream,
                      backgroundImage: pickerAvatarProvider,
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _pickAvatar,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(color: AppColors.primaryGreen, borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.camera_alt, color: Colors.white, size: 12),
                          const SizedBox(width: 4),
                          Text('Ubah Foto', style: GoogleFonts.nunito(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),

              // Name
              _editProfileLabel('Nama Lengkap'),
              TextField(
                controller: _editNameController,
                style: GoogleFonts.nunito(fontSize: 13, color: AppColors.textBrown),
                decoration: const InputDecoration(hintText: 'Masukkan nama lengkap...'),
              ),
              const SizedBox(height: 15),

              // Username
              _editProfileLabel('Username'),
              TextField(
                controller: _editUsernameController,
                style: GoogleFonts.nunito(fontSize: 13, color: AppColors.textBrown),
                decoration: const InputDecoration(hintText: 'Masukkan username...'),
              ),
              const SizedBox(height: 15),

              // Password
              _editProfileLabel('Password Baru'),
              TextField(
                controller: _editPasswordController,
                obscureText: true,
                style: GoogleFonts.nunito(fontSize: 13, color: AppColors.textBrown),
                decoration: const InputDecoration(hintText: 'Kosongkan jika tidak ingin diubah'),
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _isUpdating ? null : _updateProfile,
                  child: _isUpdating
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text('SIMPAN PERUBAHAN', style: GoogleFonts.nunito(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _editProfileLabel(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textBrown)),
      ),
    );
  }
}
