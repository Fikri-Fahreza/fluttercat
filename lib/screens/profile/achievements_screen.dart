import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../config/api_config.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  final Dio _dio = Dio();
  List<dynamic> _achievements = [];
  int _earnedCount = 0;
  int _total = 0;
  bool _isLoading = true;
  bool _isRefreshing = false;
  String _activeCategory = 'all';

  final Map<String, Map<String, dynamic>> _categoryInfo = {
    'collector': {'label': 'Kolektor', 'icon': '📦', 'color': const Color(0xFF4A9EDB)},
    'hunter': {'label': 'Pemburu', 'icon': '🎯', 'color': const Color(0xFF9B59B6)},
    'explorer': {'label': 'Penjelajah', 'icon': '🗺️', 'color': const Color(0xFF27AE60)},
    'streak': {'label': 'Streak', 'icon': '🔥', 'color': const Color(0xFFE74C3C)},
  };

  final List<String> _categories = ['collector', 'hunter', 'explorer', 'streak'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchAchievements());
  }

  String get _token => context.read<AuthProvider>().token ?? '';
  Options get _authOptions => Options(headers: {'Authorization': 'Bearer $_token'});

  Future<void> _fetchAchievements() async {
    try {
      final res = await _dio.get('${ApiConfig.baseUrl}/api/achievements', options: _authOptions);
      setState(() {
        _achievements = res.data['achievements'] ?? [];
        _earnedCount = res.data['earned_count'] ?? 0;
        _total = res.data['total'] ?? 0;
        _isLoading = false;
        _isRefreshing = false;
      });
    } catch (e) {
      debugPrint('Achievements error: $e');
      setState(() {
        _isLoading = false;
        _isRefreshing = false;
      });
    }
  }

  Future<void> _onRefresh() async {
    setState(() => _isRefreshing = true);
    await _fetchAchievements();
  }

  List<dynamic> get _filtered {
    if (_activeCategory == 'all') {
      return _achievements;
    }
    return _achievements.where((a) => a['category'] == _activeCategory).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredList = _filtered;
    final double progress = _total > 0 ? _earnedCount / _total : 0.0;

    return Scaffold(
      backgroundColor: AppColors.bgCream,
      appBar: AppBar(
        title: const Text('🏅 Achievement'),
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
                  Text('Memuat achievement...', style: TextStyle(fontWeight: FontWeight.bold)),
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
                        '$_earnedCount dari $_total lencana diraih',
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

                // Category filter row
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      _filterChip(
                        category: 'all',
                        label: 'Semua',
                        icon: '🏅',
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      ..._categories.map((cat) {
                        final info = _categoryInfo[cat]!;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _filterChip(
                            category: cat,
                            label: info['label'],
                            icon: info['icon'],
                            color: info['color'],
                          ),
                        );
                      }),
                    ],
                  ),
                ),

                Expanded(
                  child: filteredList.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('🏅', style: TextStyle(fontSize: 48)),
                              const SizedBox(height: 10),
                              Text('Tidak ada achievement', style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textBrown)),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          color: AppColors.primaryGreen,
                          onRefresh: _onRefresh,
                          child: GridView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 0.85,
                            ),
                            itemCount: filteredList.length,
                            itemBuilder: (context, index) {
                              final item = filteredList[index];
                              return _buildAchievementCard(item);
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _filterChip({
    required String category,
    required String label,
    required String icon,
    required Color color,
  }) {
    final isActive = _activeCategory == category;
    return GestureDetector(
      onTap: () => setState(() => _activeCategory = category),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primaryGreen.withOpacity(0.15) : AppColors.cardCream,
          border: Border.all(color: isActive ? AppColors.primaryGreen : AppColors.borderCream),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          '$icon $label',
          style: GoogleFonts.nunito(
            color: isActive ? AppColors.primaryGreen : AppColors.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildAchievementCard(Map<String, dynamic> item) {
    final bool earned = item['earned'] == 1 || item['earned'] == true;
    final catInfo = _categoryInfo[item['category']] ?? {'color': Colors.grey};
    final Color catColor = catInfo['color'];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardCream,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderCream),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Stack(
          children: [
            if (earned)
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [catColor.withOpacity(0.15), Colors.transparent],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Opacity(
                    opacity: earned ? 1.0 : 0.3,
                    child: Text(
                      earned ? (item['icon'] ?? '🏆') : '🔒',
                      style: const TextStyle(fontSize: 36),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    earned ? (item['title'] ?? '') : '???',
                    style: GoogleFonts.nunito(
                      color: earned ? AppColors.textBrown : AppColors.textMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item['description'] ?? '',
                    style: GoogleFonts.nunito(
                      color: earned ? const Color(0xFF666666) : AppColors.textMuted,
                      fontSize: 10,
                      height: 1.3,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '+${item['reward_points']} poin',
                        style: GoogleFonts.nunito(
                          color: earned ? const Color(0xFFF39C12) : AppColors.textMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (earned)
                        Text(
                          '✓ Diraih',
                          style: GoogleFonts.nunito(
                            color: AppColors.primaryGreen,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
