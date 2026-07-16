import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../config/api_config.dart';
import '../profile/detail_screen.dart';

class CatDexScreen extends StatefulWidget {
  const CatDexScreen({super.key});

  @override
  State<CatDexScreen> createState() => _CatDexScreenState();
}

class _CatDexScreenState extends State<CatDexScreen> {
  final Dio _dio = Dio();
  List<dynamic> _cats = [];
  bool _isLoading = true;
  bool _isRefreshing = false;

  String _searchQuery = '';
  String _filterRarity = 'All';
  bool _showFavoritesOnly = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchCats());
  }

  String get _token => context.read<AuthProvider>().token ?? '';
  Options get _authOptions => Options(headers: {'Authorization': 'Bearer $_token'});

  Future<void> _fetchCats() async {
    try {
      final response = await _dio.get(
        '${ApiConfig.baseUrl}/api/cats',
        options: _authOptions,
      );
      // Backend mengembalikan cats di key 'cats'
      final catsData = response.data['cats'];
      List<dynamic> loadedCats = [];
      if (catsData is List) {
        loadedCats = catsData;
      }
      setState(() {
        _cats = loadedCats;
        _isLoading = false;
        _isRefreshing = false;
      });
    } catch (e) {
      debugPrint('Failed to fetch CatDex: $e');
      setState(() {
        _isLoading = false;
        _isRefreshing = false;
      });
    }
  }

  Future<void> _onRefresh() async {
    setState(() => _isRefreshing = true);
    await _fetchCats();
  }

  Color _getRarityColor(String rarity) {
    switch (rarity.toLowerCase()) {
      case 'legendary': return const Color(0xFFE4C078); // Soft Gold
      case 'epic': return const Color(0xFFB590CA); // Soft Purple
      case 'rare': return const Color(0xFF78B3C4); // Soft Pastel Blue
      default: return const Color(0xFFA8A29A); // Soft Grey-Brown
    }
  }

  List<dynamic> get _filteredCats {
    return _cats.where((cat) {
      final name = (cat['custom_name'] ?? '').toString().toLowerCase();
      final breed = (cat['breed'] ?? '').toString().toLowerCase();
      final rarity = (cat['rarity'] ?? '').toString().toLowerCase();
      final isFavorite = cat['is_favorite'] == 1 || cat['is_favorite'] == true;

      final matchesSearch = name.contains(_searchQuery.toLowerCase()) ||
          breed.contains(_searchQuery.toLowerCase());
      final matchesRarity = _filterRarity == 'All' || rarity == _filterRarity.toLowerCase();
      final matchesFavorite = !_showFavoritesOnly || isFavorite;

      return matchesSearch && matchesRarity && matchesFavorite;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredCats;

    return Scaffold(
      backgroundColor: AppColors.bgCream,
      body: SafeArea(
        child: Column(
          children: [
            // Top Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back button
                  const SizedBox(width: 40), // Placeholder to center title, or keep it empty
                  Text(
                    'Album Jurnal',
                    style: GoogleFonts.nunito(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textBrown,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${filtered.length} Ekor',
                      style: GoogleFonts.nunito(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: AppColors.borderCream, height: 1),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.cardCream,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderCream),
                ),
                child: TextField(
                  style: GoogleFonts.nunito(color: AppColors.textBrown, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Cari kucing berdasarkan nama/ras...',
                    hintStyle: GoogleFonts.nunito(color: AppColors.textMuted),
                    prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
              ),
            ),

            // Filters Row
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Row(
                children: [
                  // Favorite chip
                  _filterChip(
                    label: 'Favorit',
                    isActive: _showFavoritesOnly,
                    icon: _showFavoritesOnly ? Icons.star : Icons.star_border,
                    onTap: () => setState(() => _showFavoritesOnly = !_showFavoritesOnly),
                  ),
                  const SizedBox(width: 6),
                  ...['All', 'Common', 'Rare', 'Epic', 'Legendary'].map((rarity) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: _filterChip(
                        label: rarity,
                        isActive: _filterRarity == rarity,
                        onTap: () => setState(() => _filterRarity = rarity),
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Main Content List
            Expanded(
              child: _isLoading
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(color: AppColors.primaryGreen),
                          const SizedBox(height: 15),
                          Text(
                            'Membuka Album CatDex...',
                            style: GoogleFonts.nunito(
                              color: AppColors.textBrown,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      color: AppColors.primaryGreen,
                      onRefresh: _onRefresh,
                      child: filtered.isEmpty
                          ? LayoutBuilder(
                              builder: (context, constraints) => ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: [
                                  Container(
                                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                                    alignment: Alignment.center,
                                    padding: const EdgeInsets.all(30),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Text('😿', style: TextStyle(fontSize: 50)),
                                        const SizedBox(height: 10),
                                        Text(
                                          'Tidak ada kucing ditemukan!',
                                          style: GoogleFonts.nunito(
                                            color: AppColors.textBrown,
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Coba ubah filter pencarian Anda atau potret kucing baru.',
                                          style: GoogleFonts.nunito(
                                            color: AppColors.textMuted,
                                            fontSize: 12,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : GridView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 15),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 0.78,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                              ),
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final cat = filtered[index];
                                return _buildCatCard(cat);
                              },
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip({
    required String label,
    required bool isActive,
    IconData? icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primaryGreen : AppColors.cardCream,
          border: Border.all(color: isActive ? AppColors.primaryGreen : AppColors.borderCream),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 12, color: isActive ? Colors.white : AppColors.textMuted),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: GoogleFonts.nunito(
                color: isActive ? Colors.white : AppColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCatCard(Map<String, dynamic> cat) {
    final rarity = (cat['rarity'] ?? 'Common').toString();
    final borderColor = _getRarityColor(rarity);
    final isFavorite = cat['is_favorite'] == 1 || cat['is_favorite'] == true;

    final photoPath = cat['photo_path'] ?? '';
    final imageUrl = photoPath.startsWith('http')
        ? photoPath
        : '${ApiConfig.baseUrl}$photoPath';

    return GestureDetector(
      onTap: () async {
        final needRefresh = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DetailScreen(cat: cat),
          ),
        );
        if (needRefresh == true) {
          _fetchCats();
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardCream,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: AppColors.textBrown.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image container
              Expanded(
                child: Stack(
                  children: [
                    CachedNetworkImage(
                      imageUrl: imageUrl,
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(color: AppColors.lightGreen),
                      errorWidget: (_, __, ___) => Container(
                        color: AppColors.lightGreen,
                        child: const Center(child: Text('🐱', style: TextStyle(fontSize: 32))),
                      ),
                    ),
                    // Rarity Badge
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: borderColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          rarity,
                          style: GoogleFonts.nunito(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    // Favorite Badge
                    if (isFavorite)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.star, size: 10, color: Color(0xFFF1C40F)),
                        ),
                      ),
                    // Level Tag Overlay
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primaryGreen,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'LVL ${cat['level'] ?? 1}',
                          style: GoogleFonts.nunito(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Cat details
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cat['custom_name'] ?? 'Kucing',
                      style: GoogleFonts.nunito(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textBrown,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      cat['breed'] ?? 'Unknown Breed',
                      style: GoogleFonts.nunito(
                        fontSize: 10,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
