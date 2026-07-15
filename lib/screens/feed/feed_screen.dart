import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../config/api_config.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final Dio _dio = Dio();
  List<dynamic> _posts = [];
  List<dynamic> _challenges = [];
  Map<String, dynamic>? _catOfDay;
  bool _isLoading = true;
  String? _error;
  final Set<int> _likedPosts = {};
  final Map<int, int> _likeCounts = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchAll());
  }

  String get _token => context.read<AuthProvider>().token ?? '';

  Options get _authOptions =>
      Options(headers: {'Authorization': 'Bearer $_token'});

  String _buildImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return '${ApiConfig.baseUrl}$path';
  }

  Future<void> _fetchAll() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _dio
            .get('${ApiConfig.baseUrl}/api/posts', options: _authOptions)
            .catchError((_) => Response(
                requestOptions: RequestOptions(path: ''), data: null)),
        _dio
            .get('${ApiConfig.baseUrl}/api/cat-of-the-day',
                options: _authOptions)
            .catchError((_) => Response(
                requestOptions: RequestOptions(path: ''), data: null)),
        _dio
            .get('${ApiConfig.baseUrl}/api/challenges',
                options: _authOptions)
            .catchError((_) => Response(
                requestOptions: RequestOptions(path: ''), data: null)),
      ]);

      // Parse posts
      final postsData = results[0].data;
      List<dynamic> posts = [];
      if (postsData is Map && postsData['data'] != null) {
        posts = postsData['data'] as List<dynamic>;
      } else if (postsData is List) {
        posts = postsData;
      }

      // Parse cat of day
      final codData = results[1].data;
      Map<String, dynamic>? catOfDay;
      if (codData is Map) {
        catOfDay = (codData['data'] as Map<String, dynamic>?) ??
            codData.cast<String, dynamic>();
      }

      // Parse challenges
      final challengesData = results[2].data;
      List<dynamic> challenges = [];
      if (challengesData is Map && challengesData['data'] != null) {
        challenges = challengesData['data'] as List<dynamic>;
      } else if (challengesData is List) {
        challenges = challengesData;
      }

      // Initialize like counts
      for (var post in posts) {
        final id = (post['id'] as int?) ?? 0;
        _likeCounts[id] =
            (post['likes_count'] ?? post['likes'] ?? 0) as int;
      }

      setState(() {
        _posts = posts;
        _catOfDay = catOfDay;
        _challenges = challenges;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Gagal memuat feed: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleLike(int postId) async {
    try {
      if (_likedPosts.contains(postId)) {
        await _dio.delete(
            '${ApiConfig.baseUrl}/api/posts/$postId/like',
            options: _authOptions);
        setState(() {
          _likedPosts.remove(postId);
          _likeCounts[postId] = (_likeCounts[postId] ?? 1) - 1;
        });
      } else {
        await _dio.post(
            '${ApiConfig.baseUrl}/api/posts/$postId/like',
            options: _authOptions);
        setState(() {
          _likedPosts.add(postId);
          _likeCounts[postId] = (_likeCounts[postId] ?? 0) + 1;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgCream,
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        title: Text('StreetCat Feed 🐱',
            style: GoogleFonts.nunito(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20)),
        automaticallyImplyLeading: false,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                  color: AppColors.primaryGreen))
          : _error != null
              ? Center(
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
                        onPressed: _fetchAll,
                        child: Text('Coba Lagi',
                            style: GoogleFonts.nunito(
                                color: Colors.white)),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: AppColors.primaryGreen,
                  onRefresh: _fetchAll,
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      if (_catOfDay != null) _buildCatOfDay(),
                      if (_challenges.isNotEmpty) _buildChallenges(),
                      Padding(
                        padding:
                            const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Text('Postingan Komunitas',
                            style: GoogleFonts.nunito(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textBrown)),
                      ),
                      if (_posts.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              children: [
                                const Text('📭',
                                    style: TextStyle(fontSize: 48)),
                                const SizedBox(height: 12),
                                Text('Belum ada postingan',
                                    style: GoogleFonts.nunito(
                                        color: AppColors.textMuted,
                                        fontSize: 16)),
                              ],
                            ),
                          ),
                        )
                      else
                        ...List.generate(_posts.length,
                            (i) => _buildPostCard(_posts[i])),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
    );
  }

  Widget _buildCatOfDay() {
    final cat = _catOfDay!;
    final imgUrl = _buildImageUrl(
        cat['photo_path'] ?? cat['image'] ?? cat['photo']);
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF708A5A), Color(0xFF5A6E48)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: AppColors.primaryGreen.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                const Text('⭐', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Text('Cat of the Day',
                    style: GoogleFonts.nunito(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18)),
              ],
            ),
          ),
          if (imgUrl.isNotEmpty)
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(0)),
              child: CachedNetworkImage(
                imageUrl: imgUrl,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                    height: 200,
                    color: Colors.white10,
                    child: const Center(
                        child: CircularProgressIndicator(
                            color: Colors.white))),
                errorWidget: (_, __, ___) => Container(
                    height: 200,
                    color: Colors.white10,
                    child: const Icon(Icons.pets,
                        color: Colors.white54, size: 60)),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    cat['custom_name'] ??
                        cat['name'] ??
                        'Unknown Cat',
                    style: GoogleFonts.nunito(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20)),
                if (cat['breed'] != null)
                  Text(cat['breed'],
                      style: GoogleFonts.nunito(
                          color: Colors.white70, fontSize: 14)),
                if (cat['description'] != null) ...[
                  const SizedBox(height: 6),
                  Text(cat['description'],
                      style: GoogleFonts.nunito(
                          color: Colors.white70, fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChallenges() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Text('Tantangan Aktif 🏆',
              style: GoogleFonts.nunito(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textBrown)),
        ),
        SizedBox(
          height: 110,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemCount: _challenges.length,
            itemBuilder: (context, i) {
              final ch = _challenges[i];
              return Container(
                width: 200,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.cardCream,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.borderCream),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 6)
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('🎯',
                            style: TextStyle(fontSize: 18)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                              ch['title'] ?? ch['name'] ?? 'Challenge',
                              style: GoogleFonts.nunito(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textBrown,
                                  fontSize: 13),
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(ch['description'] ?? '',
                        style: GoogleFonts.nunito(
                            color: AppColors.textMuted, fontSize: 12),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    const Spacer(),
                    if (ch['points'] != null ||
                        ch['reward_points'] != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                            color:
                                AppColors.softGold.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(8)),
                        child: Text(
                            '+${ch['points'] ?? ch['reward_points']} pts',
                            style: GoogleFonts.nunito(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textBrown)),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildPostCard(dynamic post) {
    final int postId = (post['id'] as int?) ?? 0;
    final bool isLiked = _likedPosts.contains(postId);
    final int likeCount = _likeCounts[postId] ?? 0;
    final int commentCount =
        (post['comments_count'] ?? post['comments'] ?? 0) as int;
    final imgUrl = _buildImageUrl(
        post['image'] ?? post['photo'] ?? post['photo_path']);
    final user =
        (post['user'] as Map<String, dynamic>?) ?? {};
    final cat =
        (post['cat'] as Map<String, dynamic>?) ?? {};

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.cardCream,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderCream),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.lightGreen,
                  child: Text(
                    (user['name'] ?? user['username'] ?? 'U')
                        .substring(0, 1)
                        .toUpperCase(),
                    style: GoogleFonts.nunito(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryGreen),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          user['name'] ?? user['username'] ?? 'Unknown',
                          style: GoogleFonts.nunito(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textBrown,
                              fontSize: 14)),
                      Text('@${user['username'] ?? ''}',
                          style: GoogleFonts.nunito(
                              color: AppColors.textMuted, fontSize: 12)),
                    ],
                  ),
                ),
                if (cat['rarity'] != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: AppColors.lightGreen,
                        borderRadius: BorderRadius.circular(8)),
                    child: Text(cat['rarity'],
                        style: GoogleFonts.nunito(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryGreen)),
                  ),
              ],
            ),
          ),
          // Image
          if (imgUrl.isNotEmpty)
            CachedNetworkImage(
              imageUrl: imgUrl,
              height: 220,
              width: double.infinity,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                  height: 220,
                  color: AppColors.lightGreen,
                  child: const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primaryGreen))),
              errorWidget: (_, __, ___) => Container(
                  height: 180,
                  color: AppColors.lightGreen,
                  child: const Icon(Icons.pets,
                      color: AppColors.primaryGreen, size: 60)),
            ),
          // Content
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (post['caption'] != null || post['content'] != null)
                  Text(post['caption'] ?? post['content'] ?? '',
                      style: GoogleFonts.nunito(
                          color: AppColors.textBrown, fontSize: 14)),
                if (cat['custom_name'] != null || cat['name'] != null) ...[
                  const SizedBox(height: 6),
                  Text('🐱 ${cat['custom_name'] ?? cat['name']}',
                      style: GoogleFonts.nunito(
                          color: AppColors.primaryGreen,
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => _toggleLike(postId),
                      child: Row(
                        children: [
                          Icon(
                              isLiked
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color: isLiked
                                  ? AppColors.danger
                                  : AppColors.textMuted,
                              size: 22),
                          const SizedBox(width: 5),
                          Text('$likeCount',
                              style: GoogleFonts.nunito(
                                  color: AppColors.textMuted,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    Row(
                      children: [
                        const Icon(Icons.chat_bubble_outline,
                            color: AppColors.textMuted, size: 20),
                        const SizedBox(width: 5),
                        Text('$commentCount',
                            style: GoogleFonts.nunito(
                                color: AppColors.textMuted,
                                fontWeight: FontWeight.w600,
                                fontSize: 14)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
