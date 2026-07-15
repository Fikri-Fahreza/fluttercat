import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
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

  // Create Post
  final TextEditingController _captionController = TextEditingController();
  Map<String, dynamic>? _selectedCat;
  final List<Map<String, dynamic>> _taggedFriends = [];
  bool _isCreatingPost = false;

  // Comments
  Map<String, dynamic>? _activePostForComments;
  final TextEditingController _commentController = TextEditingController();
  bool _isSendingComment = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchAll());
  }

  @override
  void dispose() {
    _captionController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  String get _token => context.read<AuthProvider>().token ?? '';
  Options get _authOptions => Options(headers: {'Authorization': 'Bearer $_token', 'Accept': 'application/json'});

  String _buildImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return '${ApiConfig.baseUrl}$path';
  }

  Future<void> _fetchAll() async {
    try {
      final results = await Future.wait([
        _dio.get('${ApiConfig.baseUrl}/api/posts', options: _authOptions),
        _dio.get('${ApiConfig.baseUrl}/api/feed/cat-of-the-day', options: _authOptions),
        _dio.get('${ApiConfig.baseUrl}/api/challenges', options: _authOptions),
      ]);

      setState(() {
        _posts = results[0].data['posts'] ?? [];
        _catOfDay = results[1].data['cat_of_the_day'];
        _challenges = results[2].data['challenges'] ?? results[2].data['data'] ?? [];
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Fetch Feed Error: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleLike(Map<String, dynamic> post) async {
    final postId = post['id'];
    final bool currentlyLiked = post['is_liked_by_me'] == true || post['is_liked_by_me'] == 1;
    
    // Optimistic Update
    setState(() {
      post['is_liked_by_me'] = !currentlyLiked;
      post['likes_count'] = (post['likes_count'] ?? 0) + (currentlyLiked ? -1 : 1);
    });

    try {
      await _dio.post(
        '${ApiConfig.baseUrl}/api/posts/$postId/like',
        options: _authOptions,
      );
    } catch (_) {
      // Revert if error
      setState(() {
        post['is_liked_by_me'] = currentlyLiked;
        post['likes_count'] = (post['likes_count'] ?? 0) + (currentlyLiked ? 1 : -1);
      });
    }
  }

  Future<void> _createPost() async {
    final caption = _captionController.text.trim();
    if (caption.isEmpty && _selectedCat == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tulis caption atau pilih foto kucing terlebih dahulu.')),
      );
      return;
    }

    setState(() => _isCreatingPost = true);
    try {
      final response = await _dio.post(
        '${ApiConfig.baseUrl}/api/posts',
        data: {
          'caption': caption.isNotEmpty ? caption : null,
          'cat_id': _selectedCat != null ? _selectedCat!['id'] : null,
          'tagged_usernames': _taggedFriends.map((f) => f['username']).toList(),
        },
        options: _authOptions,
      );

      final newPost = response.data['post'];
      setState(() {
        _posts.insert(0, newPost);
        _captionController.clear();
        _selectedCat = null;
        _taggedFriends.clear();
      });
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Postingan berhasil dibagikan!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal membagikan postingan.')),
      );
    }
    setState(() => _isCreatingPost = false);
  }

  Future<void> _sendComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _activePostForComments == null || _isSendingComment) return;

    setState(() => _isSendingComment = true);
    final post = _activePostForComments!;
    try {
      final res = await _dio.post(
        '${ApiConfig.baseUrl}/api/posts/${post['id']}/comment',
        data: {'comment': text},
        options: _authOptions,
      );

      final newComment = res.data['comment'];
      setState(() {
        post['comments'] = [...(post['comments'] ?? []), newComment];
        post['comments_count'] = (post['comments_count'] ?? 0) + 1;
        _commentController.clear();
      });
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal mengirim komentar.')),
      );
    }
    setState(() => _isSendingComment = false);
  }

  void _sharePost(Map<String, dynamic> post) async {
    if (post['cat_id'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Postingan tanpa lampiran kucing tidak mendukung web preview.')),
      );
      return;
    }
    final shareUrl = '${ApiConfig.baseUrl}/share/cat/${post['cat_id']}';
    try {
      await Share.share(
        'Lihat postingan kucing "${post['cat']?['custom_name']}" dari @${post['user']?['username']}: $shareUrl',
      );
    } catch (_) {}
  }

  Color _getRarityColor(String rarity) {
    switch (rarity.toLowerCase()) {
      case 'legendary': return const Color(0xFFE4C078);
      case 'epic': return const Color(0xFFB590CA);
      case 'rare': return const Color(0xFF78B3C4);
      default: return const Color(0xFFA8A29A);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgCream,
      appBar: AppBar(
        title: Text(
          'Komunitas Kucing',
          style: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: AppColors.primaryGreen, size: 28),
            onPressed: _showCreatePostSheet,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
          : RefreshIndicator(
              color: AppColors.primaryGreen,
              onRefresh: _fetchAll,
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 80),
                itemCount: _posts.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _buildHeaderSection();
                  }
                  final post = _posts[index - 1];
                  return _buildPostCard(post);
                },
              ),
            ),
    );
  }

  Widget _buildHeaderSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cat of the Day
        if (_catOfDay != null) ...[
          Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardCream,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.borderCream),
              boxShadow: [
                BoxShadow(
                  color: AppColors.textBrown.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(19),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    color: AppColors.primaryGreen.withOpacity(0.05),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '👑 CAT OF THE DAY',
                          style: GoogleFonts.nunito(fontWeight: FontWeight.w900, fontSize: 11, color: AppColors.primaryGreen),
                        ),
                        Text(
                          'oleh @${_catOfDay!['owner']?['username'] ?? 'owner'}',
                          style: GoogleFonts.nunito(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: CachedNetworkImage(
                            imageUrl: _buildImageUrl(_catOfDay!['photo']),
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _catOfDay!['name'] ?? '',
                                style: GoogleFonts.nunito(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textBrown),
                              ),
                              Text(
                                '${_catOfDay!['breed'] ?? ''} · ${_catOfDay!['rarity'] ?? ''}',
                                style: GoogleFonts.nunito(fontSize: 11, color: AppColors.primaryGreen, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _catOfDay!['stats']?['description'] ?? 'Kucing tercantik hari ini.',
                                style: GoogleFonts.nunito(fontSize: 11, color: AppColors.textMuted, height: 1.3),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],

        // Tantangan Aktif
        if (_challenges.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Tantangan Aktif 🏆',
              style: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.textBrown),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _challenges.length,
              itemBuilder: (context, i) {
                final ch = _challenges[i];
                return Container(
                  width: 200,
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.cardCream,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.borderCream),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '🎯 ${ch['title'] ?? ch['name'] ?? 'Tantangan'}',
                        style: GoogleFonts.nunito(fontWeight: FontWeight.bold, color: AppColors.textBrown, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Expanded(
                        child: Text(
                          ch['description'] ?? '',
                          style: GoogleFonts.nunito(color: AppColors.textMuted, fontSize: 10, height: 1.3),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: const Color(0xFFF39C12).withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                        child: Text('+${ch['points'] ?? ch['reward_points'] ?? 10} pts', style: GoogleFonts.nunito(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFFD35400))),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],

        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Text(
            'Postingan Komunitas',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.textBrown),
          ),
        ),
      ],
    );
  }

  Widget _buildPostCard(Map<String, dynamic> post) {
    final user = post['user'] ?? {};
    final cat = post['cat'];
    final tags = post['tags'] as List? ?? [];
    final bool isLiked = post['is_liked_by_me'] == true || post['is_liked_by_me'] == 1;

    final parsedDate = DateTime.tryParse(post['created_at'] ?? '') ?? DateTime.now();
    final formattedDate = DateFormat('dd MMM', 'id_ID').format(parsedDate);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.cardCream,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderCream),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User info header
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.lightGreen,
                  child: Text(
                    (user['name'] ?? 'U').toString().substring(0, 1).toUpperCase(),
                    style: GoogleFonts.nunito(fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(user['name'] ?? '', style: GoogleFonts.nunito(fontWeight: FontWeight.bold, color: AppColors.textBrown, fontSize: 13)),
                          const SizedBox(width: 4),
                          Text('@${user['username'] ?? ''}', style: GoogleFonts.nunito(color: AppColors.textMuted, fontSize: 11)),
                        ],
                      ),
                      if (tags.isNotEmpty)
                        Text(
                          'bersama ${tags.map((t) => '@${t['user']?['username'] ?? ''}').join(', ')}',
                          style: GoogleFonts.nunito(fontSize: 10, color: AppColors.primaryGreen, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                Text(formattedDate, style: GoogleFonts.nunito(color: AppColors.textMuted, fontSize: 11)),
              ],
            ),
          ),

          // Caption
          if (post['caption'] != null && post['caption'].toString().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 12, right: 12, bottom: 10),
              child: Text(post['caption'], style: GoogleFonts.nunito(fontSize: 13, color: AppColors.textBrown)),
            ),

          // Attached cat card
          if (cat != null) ...[
            Padding(
              padding: const EdgeInsets.only(left: 12, right: 12, bottom: 12),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _getRarityColor(cat['rarity'] ?? 'Common'), width: 1.5),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CachedNetworkImage(
                        imageUrl: _buildImageUrl(cat['photo_path']),
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                      Container(
                        padding: const EdgeInsets.all(12),
                        color: AppColors.cardCream,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(cat['custom_name'] ?? 'Kucing', style: GoogleFonts.nunito(fontWeight: FontWeight.bold, color: AppColors.textBrown, fontSize: 13)),
                                Text(cat['breed'] ?? 'Unknown Breed', style: GoogleFonts.nunito(color: AppColors.textMuted, fontSize: 11)),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(color: _getRarityColor(cat['rarity'] ?? 'Common'), borderRadius: BorderRadius.circular(10)),
                              child: Text(
                                (cat['rarity'] ?? 'Common').toUpperCase(),
                                style: GoogleFonts.nunito(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],

          // Footer action buttons
          Padding(
            padding: const EdgeInsets.only(left: 12, right: 12, bottom: 12),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => _toggleLike(post),
                  child: Row(
                    children: [
                      Icon(isLiked ? Icons.favorite : Icons.favorite_border, size: 20, color: isLiked ? AppColors.danger : AppColors.textMuted),
                      const SizedBox(width: 4),
                      Text('${post['likes_count'] ?? 0}', style: GoogleFonts.nunito(color: isLiked ? AppColors.danger : AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                GestureDetector(
                  onTap: () => _showCommentsSheet(post),
                  child: Row(
                    children: [
                      const Icon(Icons.chat_bubble_outline, size: 19, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Text('${post['comments_count'] ?? 0}', style: GoogleFonts.nunito(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => _sharePost(post),
                  child: Row(
                    children: [
                      const Icon(Icons.share, size: 18, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Text('Share', style: GoogleFonts.nunito(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Bottom sheets
  void _showCreatePostSheet() {
    _captionController.clear();
    _selectedCat = null;
    _taggedFriends.clear();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(
            color: AppColors.bgCream,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 40,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Bagikan Postingan', style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textBrown)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 10),

              // Attached Cat
              if (_selectedCat != null)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppColors.cardCream, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.borderCream)),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: _buildImageUrl(_selectedCat!['photo_path']),
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_selectedCat!['custom_name'] ?? '', style: GoogleFonts.nunito(fontWeight: FontWeight.bold, fontSize: 12)),
                            Text(_selectedCat!['breed'] ?? '', style: GoogleFonts.nunito(color: AppColors.textMuted, fontSize: 10)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: AppColors.danger),
                        onPressed: () => setModalState(() => _selectedCat = null),
                      ),
                    ],
                  ),
                )
              else
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.lightGreen,
                    foregroundColor: AppColors.primaryGreen,
                    elevation: 0,
                    side: const BorderSide(color: AppColors.primaryGreen, width: 0.5),
                  ),
                  onPressed: () async {
                    final cat = await _showCatPicker();
                    if (cat != null) {
                      setModalState(() => _selectedCat = cat);
                    }
                  },
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Lampirkan Kucing dari Album'),
                ),

              const SizedBox(height: 10),

              // Tag Friends
              if (_taggedFriends.isNotEmpty)
                Wrap(
                  spacing: 6,
                  children: _taggedFriends.map<Widget>((f) => Chip(
                    label: Text('@${f['username']}', style: GoogleFonts.nunito(fontSize: 10, color: AppColors.primaryGreen)),
                    backgroundColor: AppColors.lightGreen,
                    onDeleted: () => setModalState(() => _taggedFriends.remove(f)),
                  )).toList(),
                )
              else
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.lightGreen,
                    foregroundColor: AppColors.primaryGreen,
                    elevation: 0,
                    side: const BorderSide(color: AppColors.primaryGreen, width: 0.5),
                  ),
                  onPressed: () async {
                    final friend = await _showFriendPicker();
                    if (friend != null) {
                      setModalState(() {
                        if (!_taggedFriends.any((f) => f['id'] == friend['id'])) {
                          _taggedFriends.add(friend);
                        }
                      });
                    }
                  },
                  icon: const Icon(Icons.person_add_alt_1_outlined),
                  label: const Text('Tag Teman'),
                ),

              const SizedBox(height: 15),

              // Caption input
              TextField(
                controller: _captionController,
                maxLines: 4,
                style: GoogleFonts.nunito(fontSize: 13, color: AppColors.textBrown),
                decoration: InputDecoration(
                  hintText: 'Tulis sesuatu tentang kucing ini...',
                  fillColor: AppColors.cardCream,
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen, padding: const EdgeInsets.symmetric(vertical: 14)),
                  onPressed: _isCreatingPost ? null : _createPost,
                  child: _isCreatingPost
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text('BAGIKAN POSTINGAN', style: GoogleFonts.nunito(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<Map<String, dynamic>?> _showCatPicker() async {
    List<dynamic> cats = [];
    bool loading = true;

    try {
      final res = await _dio.get('${ApiConfig.baseUrl}/api/cats', options: _authOptions);
      cats = res.data['cats'] ?? [];
      loading = false;
    } catch (_) {
      loading = false;
    }

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardCream,
        title: Text('Pilih Kucing', style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
        content: loading
            ? const SizedBox(height: 100, child: Center(child: CircularProgressIndicator(color: AppColors.primaryGreen)))
            : cats.isEmpty
                ? Text('Album Anda kosong.', style: GoogleFonts.nunito())
                : SizedBox(
                    width: double.maxFinite,
                    height: 250,
                    child: ListView.builder(
                      itemCount: cats.length,
                      itemBuilder: (c, i) {
                        final cat = cats[i];
                        return ListTile(
                          dense: true,
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: CachedNetworkImage(imageUrl: _buildImageUrl(cat['photo_path']), width: 32, height: 32, fit: BoxFit.cover),
                          ),
                          title: Text(cat['custom_name'] ?? '', style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
                          subtitle: Text(cat['breed'] ?? '', style: GoogleFonts.nunito(fontSize: 10)),
                          onTap: () => Navigator.pop(ctx, cat),
                        );
                      },
                    ),
                  ),
      ),
    );
  }

  Future<Map<String, dynamic>?> _showFriendPicker() async {
    List<dynamic> friends = [];
    bool loading = true;

    try {
      final res = await _dio.get('${ApiConfig.baseUrl}/api/friends', options: _authOptions);
      friends = res.data['friends'] ?? [];
      loading = false;
    } catch (_) {
      loading = false;
    }

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardCream,
        title: Text('Tag Teman', style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
        content: loading
            ? const SizedBox(height: 100, child: Center(child: CircularProgressIndicator(color: AppColors.primaryGreen)))
            : friends.isEmpty
                ? Text('Daftar teman Anda kosong.', style: GoogleFonts.nunito())
                : SizedBox(
                    width: double.maxFinite,
                    height: 250,
                    child: ListView.builder(
                      itemCount: friends.length,
                      itemBuilder: (c, i) {
                        final friend = friends[i];
                        return ListTile(
                          dense: true,
                          title: Text(friend['name'] ?? '', style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
                          subtitle: Text('@${friend['username'] ?? ''}', style: GoogleFonts.nunito(fontSize: 10)),
                          onTap: () => Navigator.pop(ctx, friend),
                        );
                      },
                    ),
                  ),
      ),
    );
  }

  void _showCommentsSheet(Map<String, dynamic> post) {
    _activePostForComments = post;
    _commentController.clear();
    final comments = post['comments'] as List? ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(
            color: AppColors.bgCream,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          height: MediaQuery.of(context).size.height * 0.75,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Komentar (${comments.length})', style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textBrown)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const Divider(),
              Expanded(
                child: comments.isEmpty
                    ? Center(child: Text('Belum ada komentar.', style: GoogleFonts.nunito(color: AppColors.textMuted)))
                    : ListView.builder(
                        itemCount: comments.length,
                        itemBuilder: (c, idx) {
                          final item = comments[idx];
                          final cUser = item['user'] ?? {};
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Row(
                              children: [
                                Text(cUser['name'] ?? '', style: GoogleFonts.nunito(fontWeight: FontWeight.bold, fontSize: 12)),
                                const SizedBox(width: 6),
                                Text('@${cUser['username'] ?? ''}', style: GoogleFonts.nunito(color: AppColors.textMuted, fontSize: 10)),
                              ],
                            ),
                            subtitle: Text(item['comment'] ?? '', style: GoogleFonts.nunito(color: AppColors.textBrown, fontSize: 12)),
                          );
                        },
                      ),
              ),
              const Divider(),
              // Comment input row
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      style: GoogleFonts.nunito(fontSize: 13, color: AppColors.textBrown),
                      decoration: InputDecoration(
                        hintText: 'Tulis komentar...',
                        fillColor: AppColors.cardCream,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send, color: AppColors.primaryGreen),
                    onPressed: () async {
                      await _sendComment();
                      setModalState(() {});
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
