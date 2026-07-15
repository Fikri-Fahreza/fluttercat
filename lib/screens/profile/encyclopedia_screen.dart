import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../config/api_config.dart';

class EncyclopediaScreen extends StatefulWidget {
  const EncyclopediaScreen({super.key});

  @override
  State<EncyclopediaScreen> createState() => _EncyclopediaScreenState();
}

class _EncyclopediaScreenState extends State<EncyclopediaScreen> {
  final Dio _dio = Dio();
  List<dynamic> _entries = [];
  int _caughtCount = 0;
  int _total = 0;
  bool _isLoading = true;
  bool _isRefreshing = false;
  String _searchQuery = '';
  String _filterRarity = 'All';

  final Map<String, Color> _rarityColors = {
    'Common': const Color(0xFF27AE60),
    'Rare': const Color(0xFF2980B9),
    'Epic': const Color(0xFF8E44AD),
    'Legendary': const Color(0xFFD35400),
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchEncyclopedia());
  }

  String get _token => context.read<AuthProvider>().token ?? '';
  Options get _authOptions => Options(headers: {'Authorization': 'Bearer $_token'});

  Future<void> _fetchEncyclopedia() async {
    try {
      final res = await _dio.get('${ApiConfig.baseUrl}/api/encyclopedia', options: _authOptions);
      setState(() {
        _entries = res.data['encyclopedia'] ?? [];
        _caughtCount = res.data['caught_count'] ?? 0;
        _total = res.data['total'] ?? 0;
        _isLoading = false;
        _isRefreshing = false;
      });
    } catch (e) {
      debugPrint('Encyclopedia error: $e');
      setState(() {
        _isLoading = false;
        _isRefreshing = false;
      });
    }
  }

  Future<void> _onRefresh() async {
    setState(() => _isRefreshing = true);
    await _fetchEncyclopedia();
  }

  List<dynamic> get _filteredEntries {
    return _entries.where((entry) {
      final name = (entry['name'] ?? '').toString().toLowerCase();
      final desc = (entry['description'] ?? '').toString().toLowerCase();
      final rarity = (entry['rarity'] ?? '').toString().toLowerCase();

      final matchesSearch = name.contains(_searchQuery.toLowerCase()) ||
          desc.contains(_searchQuery.toLowerCase());
      final matchesRarity = _filterRarity == 'All' || rarity == _filterRarity.toLowerCase();

      return matchesSearch && matchesRarity;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredEntries;
    final double progress = _total > 0 ? _caughtCount / _total : 0.0;

    return Scaffold(
      backgroundColor: AppColors.bgCream,
      appBar: AppBar(
        title: const Text('📖 Catlogue Kucing'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.primaryGreen),
                  SizedBox(height: 12),
                  Text('Memuat Catlogue Kucing...', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            )
          : Column(
              children: [
                // Header progress
                Container(
                  color: AppColors.cardCream,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text(
                        '$_caughtCount dari $_total Ras Kucing Ditemukan',
                        style: GoogleFonts.nunito(
                          color: AppColors.primaryGreen,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: AppColors.borderCream,
                          color: AppColors.primaryGreen,
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                ),

                // Search Filter Container
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.cardCream,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.borderCream),
                        ),
                        child: TextField(
                          style: GoogleFonts.nunito(color: AppColors.textBrown, fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Cari ras kucing...',
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
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: ['All', 'Common', 'Rare', 'Epic', 'Legendary'].map((rarity) {
                            final isActive = _filterRarity == rarity;
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: GestureDetector(
                                onTap: () => setState(() => _filterRarity = rarity),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isActive ? AppColors.primaryGreen : AppColors.cardCream,
                                    border: Border.all(color: isActive ? AppColors.primaryGreen : AppColors.borderCream),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    rarity,
                                    style: GoogleFonts.nunito(
                                      color: isActive ? Colors.white : AppColors.textMuted,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: RefreshIndicator(
                    color: AppColors.primaryGreen,
                    onRefresh: _onRefresh,
                    child: GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.74,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        return _buildEncyclopediaCard(item);
                      },
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildEncyclopediaCard(Map<String, dynamic> item) {
    final bool isCaught = item['caught'] == 1 || item['caught'] == true;
    final rarity = item['rarity'] ?? 'Common';
    final Color rarityColor = _rarityColors[rarity] ?? Colors.grey;

    final photoPath = item['caught_photo'] ?? '';
    final imageUrl = photoPath.startsWith('http')
        ? photoPath
        : '${ApiConfig.baseUrl}$photoPath';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardCream,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderCream),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Opacity(
          opacity: isCaught ? 1.0 : 0.6,
          child: Container(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: rarityColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        rarity,
                        style: GoogleFonts.nunito(color: rarityColor, fontSize: 8, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Text(
                      item['origin_country'] ?? '',
                      style: GoogleFonts.nunito(color: AppColors.textMuted, fontSize: 8, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Image silhouette / photo container
                Container(
                  height: 90,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.bgCream,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderCream),
                  ),
                  child: isCaught && photoPath.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                        )
                      : Center(
                          child: Opacity(
                            opacity: 0.3,
                            child: Text(
                              item['icon_emoji'] ?? '🐱',
                              style: const TextStyle(fontSize: 40),
                            ),
                          ),
                        ),
                ),
                const SizedBox(height: 8),

                Text(
                  isCaught ? (item['name'] ?? '') : '???',
                  style: GoogleFonts.nunito(
                    color: isCaught ? AppColors.textBrown : AppColors.textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),

                Expanded(
                  child: Text(
                    isCaught
                        ? (item['description'] ?? '')
                        : 'Temukan kucing jenis ini untuk membuka informasi ensiklopedia.',
                    style: GoogleFonts.nunito(
                      color: const Color(0xFF666666),
                      fontSize: 9,
                      height: 1.3,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                if (isCaught) ...[
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '✓ Ditangkap',
                      style: GoogleFonts.nunito(color: AppColors.primaryGreen, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
