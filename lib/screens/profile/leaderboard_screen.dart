import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../config/api_config.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  final Dio _dio = Dio();
  List<dynamic> _leaderboard = [];
  Map<String, dynamic>? _myRank;
  bool _isLoading = true;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchLeaderboard());
  }

  String get _token => context.read<AuthProvider>().token ?? '';
  Options get _authOptions => Options(headers: {'Authorization': 'Bearer $_token'});

  Future<void> _fetchLeaderboard() async {
    try {
      final res = await _dio.get('${ApiConfig.baseUrl}/api/leaderboard', options: _authOptions);
      setState(() {
        _leaderboard = res.data['leaderboard'] ?? [];
        _myRank = res.data['my_rank'];
        _isLoading = false;
        _isRefreshing = false;
      });
    } catch (e) {
      debugPrint('Leaderboard error: $e');
      setState(() {
        _isLoading = false;
        _isRefreshing = false;
      });
    }
  }

  Future<void> _onRefresh() async {
    setState(() => _isRefreshing = true);
    await _fetchLeaderboard();
  }

  String _getRankIcon(int rank) {
    if (rank == 1) return '🥇';
    if (rank == 2) return '🥈';
    if (rank == 3) return '🥉';
    return '#$rank';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgCream,
      appBar: AppBar(
        title: const Text('🏆 Papan Peringkat'),
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
                  Text('Memuat peringkat...', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            )
          : Column(
              children: [
                // My Rank banner
                if (_myRank != null && _myRank!['rank_shown_in_list'] != true)
                  Container(
                    width: double.infinity,
                    color: AppColors.primaryGreen.withOpacity(0.1),
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                    child: Text(
                      'Peringkatmu: #${_myRank!['rank']} · ${_myRank!['total_score']} poin · ${_myRank!['cats_count']} kucing',
                      style: GoogleFonts.nunito(
                        color: AppColors.primaryGreen,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                Expanded(
                  child: _leaderboard.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('🏆', style: TextStyle(fontSize: 48)),
                              const SizedBox(height: 10),
                              Text('Belum ada data peringkat', style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textBrown)),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          color: AppColors.primaryGreen,
                          onRefresh: _onRefresh,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _leaderboard.length,
                            itemBuilder: (context, index) {
                              final item = _leaderboard[index];
                              return _buildLeaderboardCard(item);
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildLeaderboardCard(Map<String, dynamic> item) {
    final int rank = item['rank'] ?? 0;
    final bool isTop3 = rank <= 3;
    final bool isMe = item['is_me'] == true || item['id'] == context.read<AuthProvider>().user?['id'];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.cardCream,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isMe
              ? AppColors.primaryGreen
              : isTop3
                  ? const Color(0xFFE4C078)
                  : AppColors.borderCream,
          width: isMe ? 2 : 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Container(
          decoration: isTop3
              ? BoxDecoration(
                  gradient: LinearGradient(
                    colors: [const Color(0xFFE4C078).withOpacity(0.15), Colors.transparent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                )
              : null,
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Rank badge
              SizedBox(
                width: 40,
                child: Text(
                  _getRankIcon(rank),
                  style: GoogleFonts.nunito(
                    color: AppColors.textBrown,
                    fontSize: isTop3 ? 24 : 15,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 6),

              // Avatar
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.lightGreen,
                    backgroundImage: item['avatar'] != null ? NetworkImage(item['avatar']) : null,
                    child: item['avatar'] == null
                        ? Text(
                            (item['name'] ?? 'U').toString().substring(0, 1).toUpperCase(),
                            style: GoogleFonts.nunito(color: AppColors.primaryGreen, fontSize: 20, fontWeight: FontWeight.bold),
                          )
                        : null,
                  ),
                  if (isMe)
                    Positioned(
                      bottom: -4,
                      right: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(color: AppColors.primaryGreen, borderRadius: BorderRadius.circular(8)),
                        child: Text(
                          'You',
                          style: GoogleFonts.nunito(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),

              // User Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['name'] ?? '',
                      style: GoogleFonts.nunito(
                        color: isMe ? AppColors.primaryGreen : AppColors.textBrown,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '@${item['username'] ?? ''}',
                      style: GoogleFonts.nunito(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    // Stats Row
                    Row(
                      children: [
                        _buildStatChip('🐱 ${item['cats_count']}'),
                        if ((item['legendary_count'] ?? 0) > 0) ...[
                          const SizedBox(width: 6),
                          _buildStatChip('⭐ ${item['legendary_count']}'),
                        ],
                        if ((item['current_streak'] ?? 0) > 0) ...[
                          const SizedBox(width: 6),
                          _buildStatChip('🔥 ${item['current_streak']}'),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Score
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${item['total_score'] ?? 0}',
                    style: GoogleFonts.nunito(color: const Color(0xFFE4C078), fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  Text(
                    'poin',
                    style: GoogleFonts.nunito(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primaryGreen.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: GoogleFonts.nunito(color: AppColors.textBrown, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
