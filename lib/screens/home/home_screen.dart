import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../config/api_config.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final Dio _dio = Dio();
  List<dynamic> _cats = [];
  bool _isLoading = true;
  String? _error;
  int _catCount = 0;
  int _achievements = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchCats());
  }

  Future<void> _fetchCats() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final token = context.read<AuthProvider>().token;
      final response = await _dio.get(
        '${ApiConfig.baseUrl}/api/cats',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final data = response.data;
      List<dynamic> cats = [];
      if (data is Map && data['data'] != null) {
        cats = data['data'] as List<dynamic>;
      } else if (data is List) {
        cats = data;
      }
      setState(() {
        _cats = cats;
        _catCount = cats.length;
        _achievements = cats.length ~/ 3;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Gagal memuat data kucing: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardCream,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Logout',
            style: GoogleFonts.nunito(
                color: AppColors.textBrown, fontWeight: FontWeight.bold)),
        content: Text('Yakin mau logout?',
            style: GoogleFonts.nunito(color: AppColors.textBrown)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Batal',
                style: GoogleFonts.nunito(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8))),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Logout',
                style: GoogleFonts.nunito(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await context.read<AuthProvider>().logout();
    }
  }

  String _buildImageUrl(String? photoPath) {
    if (photoPath == null || photoPath.isEmpty) return '';
    if (photoPath.startsWith('http')) return photoPath;
    return '${ApiConfig.baseUrl}$photoPath';
  }

  Color _rarityColor(String? rarity) {
    switch (rarity?.toLowerCase()) {
      case 'legendary':
        return const Color(0xFFFF9800);
      case 'epic':
        return const Color(0xFF9C27B0);
      case 'rare':
        return const Color(0xFF2196F3);
      case 'uncommon':
        return const Color(0xFF4CAF50);
      default:
        return AppColors.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    return Scaffold(
      backgroundColor: AppColors.bgCream,
      body: RefreshIndicator(
        color: AppColors.primaryGreen,
        onRefresh: _fetchCats,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 200,
              floating: false,
              pinned: true,
              backgroundColor: AppColors.primaryGreen,
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.logout, color: Colors.white),
                  onPressed: _logout,
                  tooltip: 'Logout',
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF708A5A), Color(0xFF5A6E48)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 30,
                                backgroundColor: AppColors.softGold,
                                child: Text(
                                  (user?['name'] ??
                                          user?['username'] ??
                                          'U')
                                      .substring(0, 1)
                                      .toUpperCase(),
                                  style: GoogleFonts.nunito(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textBrown),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      user?['name'] ?? 'Cat Hunter',
                                      style: GoogleFonts.nunito(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      '@${user?['username'] ?? ''}',
                                      style: GoogleFonts.nunito(
                                          fontSize: 14,
                                          color: Colors.white70),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.softGold,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.star,
                                        size: 16,
                                        color: Color(0xFF4A3E3D)),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${user?['points'] ?? user?['poin'] ?? 0} pts',
                                      style: GoogleFonts.nunito(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textBrown),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              _StatChip(
                                  icon: Icons.pets,
                                  label: '$_catCount Kucing'),
                              const SizedBox(width: 10),
                              _StatChip(
                                  icon: Icons.emoji_events,
                                  label: '$_achievements Achievements'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Kucingmu 🐱',
                      style: GoogleFonts.nunito(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textBrown),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                      ),
                      onPressed: () => Navigator.pushNamed(context, '/camera')
                          .then((_) => _fetchCats()),
                      icon: const Icon(Icons.add_a_photo,
                          color: Colors.white, size: 18),
                      label: Text('Tambah',
                          style: GoogleFonts.nunito(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14)),
                    ),
                  ],
                ),
              ),
            ),
            if (_isLoading)
              const SliverFillRemaining(
                child: Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primaryGreen)),
              )
            else if (_error != null)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline,
                          color: AppColors.danger, size: 48),
                      const SizedBox(height: 12),
                      Text(_error!,
                          style: GoogleFonts.nunito(
                              color: AppColors.textBrown),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryGreen),
                        onPressed: _fetchCats,
                        child: Text('Coba Lagi',
                            style:
                                GoogleFonts.nunito(color: Colors.white)),
                      ),
                    ],
                  ),
                ),
              )
            else if (_cats.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🐾',
                          style: TextStyle(fontSize: 56)),
                      const SizedBox(height: 12),
                      Text('Belum ada kucing!',
                          style: GoogleFonts.nunito(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textBrown)),
                      const SizedBox(height: 6),
                      Text('Tambahkan kucing pertamamu',
                          style: GoogleFonts.nunito(
                              color: AppColors.textMuted)),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final cat = _cats[index];
                      final imgUrl = _buildImageUrl(
                          cat['photo_path'] ??
                              cat['image'] ??
                              cat['photo']);
                      final rarity = cat['rarity'] ?? 'Common';
                      return GestureDetector(
                        onTap: () {},
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.cardCream,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: AppColors.borderCream),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black
                                      .withOpacity(0.05),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2)),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius:
                                      const BorderRadius.vertical(
                                          top: Radius.circular(16)),
                                  child: imgUrl.isNotEmpty
                                      ? CachedNetworkImage(
                                          imageUrl: imgUrl,
                                          fit: BoxFit.cover,
                                          width: double.infinity,
                                          placeholder: (_, __) =>
                                              Container(
                                                  color: AppColors
                                                      .lightGreen,
                                                  child: const Center(
                                                      child:
                                                          CircularProgressIndicator(
                                                              color: AppColors.primaryGreen,
                                                              strokeWidth: 2))),
                                          errorWidget: (_, __, ___) =>
                                              Container(
                                                  color: AppColors
                                                      .lightGreen,
                                                  child: const Icon(
                                                      Icons.pets,
                                                      color: AppColors
                                                          .primaryGreen,
                                                      size: 40)))
                                      : Container(
                                          color: AppColors.lightGreen,
                                          child: const Center(
                                              child: Icon(Icons.pets,
                                                  color: AppColors
                                                      .primaryGreen,
                                                  size: 40))),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(10),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                        cat['custom_name'] ??
                                            cat['name'] ??
                                            'Unknown',
                                        style: GoogleFonts.nunito(
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textBrown,
                                            fontSize: 14),
                                        overflow:
                                            TextOverflow.ellipsis),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Container(
                                          padding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 6,
                                                  vertical: 2),
                                          decoration: BoxDecoration(
                                            color: _rarityColor(rarity)
                                                .withOpacity(0.15),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                                color:
                                                    _rarityColor(rarity)
                                                        .withOpacity(
                                                            0.4)),
                                          ),
                                          child: Text(rarity,
                                              style: GoogleFonts.nunito(
                                                  fontSize: 11,
                                                  fontWeight:
                                                      FontWeight.bold,
                                                  color: _rarityColor(
                                                      rarity))),
                                        ),
                                        const Spacer(),
                                        Text(cat['breed'] ?? '',
                                            style: GoogleFonts.nunito(
                                                fontSize: 11,
                                                color:
                                                    AppColors.textMuted),
                                            overflow:
                                                TextOverflow.ellipsis),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    childCount: _cats.length,
                  ),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.75,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _StatChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: Colors.white.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(label,
              style: GoogleFonts.nunito(
                  fontSize: 13,
                  color: Colors.white,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
