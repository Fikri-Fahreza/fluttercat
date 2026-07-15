import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../config/api_config.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final Dio _dio = Dio();
  List<dynamic> _leaderboard = [];
  bool _isLoadingLeaderboard = true;
  Map<String, dynamic>? _userStats;
  bool _isLoadingStats = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchLeaderboard();
      _fetchStats();
    });
  }

  String get _token => context.read<AuthProvider>().token ?? '';

  Options get _authOptions =>
      Options(headers: {'Authorization': 'Bearer $_token'});

  Future<void> _fetchLeaderboard() async {
    try {
      final response = await _dio.get(
          '${ApiConfig.baseUrl}/api/leaderboard',
          options: _authOptions);
      final data = response.data;
      List<dynamic> board = [];
      if (data is Map && data['data'] != null) {
        board = data['data'] as List<dynamic>;
      } else if (data is List) {
        board = data;
      }
      setState(() {
        _leaderboard = board.take(5).toList();
        _isLoadingLeaderboard = false;
      });
    } catch (_) {
      setState(() => _isLoadingLeaderboard = false);
    }
  }

  Future<void> _fetchStats() async {
    try {
      final results = await Future.wait([
        _dio
            .get('${ApiConfig.baseUrl}/api/cats', options: _authOptions)
            .catchError((_) => Response(
                requestOptions: RequestOptions(path: ''), data: null)),
        _dio
            .get('${ApiConfig.baseUrl}/api/user/stats',
                options: _authOptions)
            .catchError((_) => Response(
                requestOptions: RequestOptions(path: ''), data: null)),
      ]);
      final catsData = results[0].data;
      int catCount = 0;
      if (catsData is Map && catsData['data'] != null) {
        catCount = (catsData['data'] as List).length;
      } else if (catsData is List) {
        catCount = catsData.length;
      }

      final statsData = results[1].data;
      Map<String, dynamic> stats = {'cat_count': catCount};
      if (statsData is Map) {
        final s = statsData['data'] ?? statsData;
        if (s is Map) stats.addAll(s.cast<String, dynamic>());
      }
      stats['cat_count'] = catCount;
      setState(() {
        _userStats = stats;
        _isLoadingStats = false;
      });
    } catch (_) {
      setState(() => _isLoadingStats = false);
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardCream,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Text('Logout',
            style: GoogleFonts.nunito(
                color: AppColors.textBrown,
                fontWeight: FontWeight.bold)),
        content: Text('Yakin mau logout dari StreetCat?',
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

  Future<void> _refreshAll() async {
    setState(() {
      _isLoadingLeaderboard = true;
      _isLoadingStats = true;
    });
    await Future.wait([_fetchLeaderboard(), _fetchStats()]);
  }

  String _getRankEmoji(int rank) {
    switch (rank) {
      case 1:
        return '🥇';
      case 2:
        return '🥈';
      case 3:
        return '🥉';
      default:
        return '#$rank';
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final int catCount = _userStats?['cat_count'] ?? 0;
    final int points = int.tryParse(
            user?['points']?.toString() ??
                user?['poin']?.toString() ??
                '0') ??
        0;
    final int achievements = catCount ~/ 3;

    return Scaffold(
      backgroundColor: AppColors.bgCream,
      body: RefreshIndicator(
        color: AppColors.primaryGreen,
        onRefresh: _refreshAll,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 240,
              pinned: true,
              automaticallyImplyLeading: false,
              backgroundColor: AppColors.primaryGreen,
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
                      colors: [Color(0xFF708A5A), Color(0xFF4A5E3C)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: SafeArea(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 40),
                        CircleAvatar(
                          radius: 44,
                          backgroundColor: AppColors.softGold,
                          child: Text(
                            (user?['name'] ??
                                    user?['username'] ??
                                    'U')
                                .substring(0, 1)
                                .toUpperCase(),
                            style: GoogleFonts.nunito(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textBrown),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          user?['name'] ?? 'Cat Hunter',
                          style: GoogleFonts.nunito(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                        Text(
                          '@${user?['username'] ?? ''}',
                          style: GoogleFonts.nunito(
                              fontSize: 14, color: Colors.white70),
                        ),
                        if (user?['email'] != null)
                          Text(
                            user!['email'],
                            style: GoogleFonts.nunito(
                                fontSize: 13, color: Colors.white60),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Stats row
                    Row(
                      children: [
                        _buildStatCard('🐱', '$catCount', 'Kucing'),
                        const SizedBox(width: 12),
                        _buildStatCard('⭐', '$points', 'Poin'),
                        const SizedBox(width: 12),
                        _buildStatCard(
                            '🏆', '$achievements', 'Achievements'),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Profile info card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.cardCream,
                        borderRadius: BorderRadius.circular(16),
                        border:
                            Border.all(color: AppColors.borderCream),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Informasi Akun',
                              style: GoogleFonts.nunito(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textBrown,
                                  fontSize: 16)),
                          const SizedBox(height: 12),
                          _buildInfoRow(Icons.person, 'Nama',
                              user?['name'] ?? '-'),
                          const Divider(color: AppColors.borderCream),
                          _buildInfoRow(Icons.alternate_email,
                              'Username',
                              '@${user?['username'] ?? '-'}'),
                          const Divider(color: AppColors.borderCream),
                          _buildInfoRow(Icons.email, 'Email',
                              user?['email'] ?? '-'),
                          if (user?['role'] != null) ...[
                            const Divider(
                                color: AppColors.borderCream),
                            _buildInfoRow(Icons.badge, 'Role',
                                user!['role']),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Leaderboard section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Leaderboard 🏆',
                            style: GoogleFonts.nunito(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textBrown,
                                fontSize: 18)),
                        if (!_isLoadingLeaderboard)
                          TextButton(
                            onPressed: _fetchLeaderboard,
                            child: Text('Refresh',
                                style: GoogleFonts.nunito(
                                    color: AppColors.primaryGreen,
                                    fontWeight: FontWeight.w600)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _isLoadingLeaderboard
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: CircularProgressIndicator(
                                  color: AppColors.primaryGreen),
                            ),
                          )
                        : _leaderboard.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Text(
                                      'Leaderboard belum tersedia',
                                      style: GoogleFonts.nunito(
                                          color: AppColors.textMuted)),
                                ),
                              )
                            : Column(
                                children: List.generate(
                                    _leaderboard.length, (i) {
                                  final entry = _leaderboard[i];
                                  final rank = i + 1;
                                  final isCurrentUser =
                                      entry['username'] ==
                                          user?['username'];
                                  return Container(
                                    margin: const EdgeInsets.only(
                                        bottom: 8),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: isCurrentUser
                                          ? AppColors.lightGreen
                                          : AppColors.cardCream,
                                      borderRadius:
                                          BorderRadius.circular(12),
                                      border: Border.all(
                                          color: isCurrentUser
                                              ? AppColors.primaryGreen
                                                  .withOpacity(0.4)
                                              : AppColors.borderCream),
                                    ),
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 36,
                                          child: Text(
                                            _getRankEmoji(rank),
                                            style: TextStyle(
                                                fontSize: rank <= 3
                                                    ? 22
                                                    : 16),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        CircleAvatar(
                                          radius: 16,
                                          backgroundColor: isCurrentUser
                                              ? AppColors.primaryGreen
                                              : AppColors.lightGreen,
                                          child: Text(
                                            (entry['name'] ??
                                                    entry['username'] ??
                                                    'U')
                                                .substring(0, 1)
                                                .toUpperCase(),
                                            style: GoogleFonts.nunito(
                                                fontWeight:
                                                    FontWeight.bold,
                                                color: isCurrentUser
                                                    ? Colors.white
                                                    : AppColors
                                                        .primaryGreen,
                                                fontSize: 13),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                  entry['name'] ??
                                                      entry['username'] ??
                                                      '-',
                                                  style: GoogleFonts.nunito(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: AppColors
                                                          .textBrown,
                                                      fontSize: 14),
                                                  overflow:
                                                      TextOverflow
                                                          .ellipsis),
                                              Text(
                                                  '@${entry['username'] ?? ''}',
                                                  style: GoogleFonts.nunito(
                                                      color: AppColors
                                                          .textMuted,
                                                      fontSize: 12)),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                  vertical: 4),
                                          decoration: BoxDecoration(
                                            color: AppColors.softGold
                                                .withOpacity(0.3),
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          child: Text(
                                              '${entry['points'] ?? entry['poin'] ?? 0} pts',
                                              style: GoogleFonts.nunito(
                                                  fontWeight:
                                                      FontWeight.bold,
                                                  color:
                                                      AppColors.textBrown,
                                                  fontSize: 13)),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ),

                    const SizedBox(height: 20),

                    // Logout button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.danger,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: _logout,
                        icon: const Icon(Icons.logout,
                            color: Colors.white),
                        label: Text('Logout',
                            style: GoogleFonts.nunito(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16)),
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String emoji, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: AppColors.cardCream,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderCream),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04), blurRadius: 6)
          ],
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 4),
            Text(value,
                style: GoogleFonts.nunito(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textBrown)),
            Text(label,
                style: GoogleFonts.nunito(
                    fontSize: 11, color: AppColors.textMuted),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primaryGreen),
          const SizedBox(width: 10),
          Text('$label:',
              style: GoogleFonts.nunito(
                  color: AppColors.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Expanded(
              child: Text(value,
                  style: GoogleFonts.nunito(
                      color: AppColors.textBrown,
                      fontSize: 14,
                      fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}
