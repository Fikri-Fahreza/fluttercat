import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../config/api_config.dart';

class DetailScreen extends StatefulWidget {
  final Map<String, dynamic> cat;
  final bool showWelcome;

  const DetailScreen({super.key, required this.cat, this.showWelcome = false});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  final Dio _dio = Dio();
  late Map<String, dynamic> _currentCat;
  
  bool _isEditing = false;
  late TextEditingController _nameController;
  late TextEditingController _breedController;
  late TextEditingController _notesController;
  
  bool _isFavorite = false;
  bool _isSaving = false;
  String? _address;
  bool _isLoadingAddress = false;

  // Gifting
  bool _showGiftModal = false;
  String? _selectedFriendId;
  final TextEditingController _giftMsgController = TextEditingController();
  bool _isSendingGift = false;
  List<dynamic> _friendsList = [];
  bool _isLoadingFriends = false;

  // Deletion
  bool _showDeleteModal = false;
  final TextEditingController _deletePasswordController = TextEditingController();
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _currentCat = Map<String, dynamic>.from(widget.cat);
    _nameController = TextEditingController(text: _currentCat['custom_name'] ?? '');
    _breedController = TextEditingController(text: _currentCat['breed'] ?? '');
    _notesController = TextEditingController(text: _currentCat['notes'] ?? '');
    _isFavorite = _currentCat['is_favorite'] == 1 || _currentCat['is_favorite'] == true;
    _fetchAddress();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _breedController.dispose();
    _notesController.dispose();
    _giftMsgController.dispose();
    _deletePasswordController.dispose();
    super.dispose();
  }

  String get _token => context.read<AuthProvider>().token ?? '';
  Options get _authOptions => Options(headers: {'Authorization': 'Bearer $_token', 'Accept': 'application/json'});

  Future<void> _fetchAddress() async {
    final double? lat = double.tryParse(_currentCat['latitude']?.toString() ?? '');
    final double? lng = double.tryParse(_currentCat['longitude']?.toString() ?? '');
    if (lat == null || lng == null || lat == 0 || lng == 0) return;

    setState(() => _isLoadingAddress = true);
    try {
      final response = await _dio.get(
        'https://nominatim.openstreetmap.org/reverse',
        queryParameters: {
          'lat': lat,
          'lon': lng,
          'format': 'json',
          'addressdetails': 1,
        },
        options: Options(headers: {'User-Agent': 'MeowApp/1.0', 'Accept-Language': 'id'}),
      );
      final data = response.data;
      if (data != null && data['address'] != null) {
        final a = data['address'];
        final parts = [
          a['village'] ?? a['suburb'] ?? a['neighbourhood'] ?? a['hamlet'],
          a['town'] ?? a['city_district'] ?? a['municipality'],
          a['city'] ?? a['county'] ?? a['regency'],
          a['state'],
        ].where((e) => e != null).toList();
        setState(() {
          _address = parts.isNotEmpty ? parts.join(', ') : data['display_name'];
        });
      }
    } catch (_) {}
    setState(() => _isLoadingAddress = false);
  }

  Future<void> _handleShare() async {
    final shareUrl = '${ApiConfig.baseUrl}/share/cat/${_currentCat['id']}';
    try {
      await Share.share(
        'Kucing bernama "${_currentCat['custom_name']}" (${_currentCat['breed']}) tingkat kelangkaan ${_currentCat['rarity']} telah ditangkap! Lihat detail kartunya disini: $shareUrl',
      );
    } catch (_) {}
  }

  Future<void> _handleSaveDetails() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama kucing tidak boleh kosong.')),
      );
      return;
    }
    if (_breedController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Jenis/Ras kucing tidak boleh kosong.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final response = await _dio.put(
        '${ApiConfig.baseUrl}/api/cats/${_currentCat['id']}',
        data: {
          'custom_name': _nameController.text.trim(),
          'breed': _breedController.text.trim(),
          'notes': _notesController.text.trim(),
          'is_favorite': _isFavorite ? 1 : 0,
        },
        options: _authOptions,
      );
      
      setState(() {
        _currentCat = Map<String, dynamic>.from(response.data['cat']);
        _isEditing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Detail kucing berhasil diperbarui!')),
      );
    } catch (e) {
      debugPrint('Update Cat Error: $e');
    }
    setState(() => _isSaving = false);
  }

  Future<void> _toggleFavorite(bool newVal) async {
    setState(() => _isFavorite = newVal);
    try {
      final response = await _dio.put(
        '${ApiConfig.baseUrl}/api/cats/${_currentCat['id']}',
        data: {'is_favorite': newVal ? 1 : 0},
        options: _authOptions,
      );
      setState(() {
        _currentCat = Map<String, dynamic>.from(response.data['cat']);
      });
    } catch (_) {}
  }

  Future<void> _fetchFriends() async {
    setState(() => _isLoadingFriends = true);
    try {
      final res = await _dio.get('${ApiConfig.baseUrl}/api/friends', options: _authOptions);
      setState(() {
        _friendsList = res.data['friends'] ?? [];
      });
    } catch (_) {}
    setState(() => _isLoadingFriends = false);
  }

  Future<void> _sendGift() async {
    if (_selectedFriendId == null) return;

    setState(() => _isSendingGift = true);
    try {
      await _dio.post(
        '${ApiConfig.baseUrl}/api/gifts',
        data: {
          'cat_id': _currentCat['id'],
          'to_user_id': int.parse(_selectedFriendId!),
          'message': _giftMsgController.text.trim(),
        },
        options: _authOptions,
      );
      setState(() {
        _showGiftModal = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kado kucing berhasil dikirim ke teman!')),
      );
      Navigator.pop(context, true); // Pop detail screen and tell dex to refresh
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal mengirim kado kucing.')),
      );
    }
    setState(() => _isSendingGift = false);
  }

  Future<void> _deleteCat() async {
    if (_deletePasswordController.text.trim().isEmpty) return;

    setState(() => _isDeleting = true);
    try {
      await _dio.delete(
        '${ApiConfig.baseUrl}/api/cats/${_currentCat['id']}',
        data: {'password': _deletePasswordController.text.trim()},
        options: _authOptions,
      );
      setState(() {
        _showDeleteModal = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kucing berhasil dihapus dari album Anda.')),
      );
      Navigator.pop(context, true); // Tell parent to refresh
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal menghapus kucing. Pastikan password Anda benar.')),
      );
    }
    setState(() => _isDeleting = false);
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
    final rarity = (_currentCat['rarity'] ?? 'Common').toString();
    final rarityColor = _getRarityColor(rarity);

    final photoPath = _currentCat['photo_path'] ?? '';
    final imageUrl = photoPath.startsWith('http')
        ? photoPath
        : '${ApiConfig.baseUrl}$photoPath';

    final parsedDate = DateTime.tryParse(_currentCat['created_at'] ?? '') ?? DateTime.now();
    final formattedDate = DateFormat('dd MMM yyyy', 'id_ID').format(parsedDate);

    final stats = _currentCat['stats'] as Map?;
    final int cuteness = stats?['cuteness'] ?? 70;
    final int playfulness = stats?['playfulness'] ?? 60;
    final int energy = stats?['energy'] ?? 65;

    final double lat = double.tryParse(_currentCat['latitude']?.toString() ?? '') ?? 0.0;
    final double lng = double.tryParse(_currentCat['longitude']?.toString() ?? '') ?? 0.0;

    final int level = _currentCat['level'] ?? 1;
    final int xp = _currentCat['xp'] ?? 0;
    final int maxXp = level * 50;

    return Scaffold(
      backgroundColor: AppColors.bgCream,
      appBar: AppBar(
        title: Text(widget.showWelcome ? 'Tangkapan Baru!' : 'Detail Kucing'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                if (widget.showWelcome) ...[
                  const Icon(Icons.auto_awesome, color: AppColors.primaryGreen, size: 32),
                  const SizedBox(height: 6),
                  Text(
                    'TANGKAPAN BARU!',
                    style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.primaryGreen, letterSpacing: 2),
                  ),
                  Text(
                    'Kucing berhasil diidentifikasi oleh AI MAIA Router',
                    style: GoogleFonts.nunito(fontSize: 12, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 15),
                ],

                // Cozy Digital Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.cardCream,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: rarityColor, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.textBrown.withOpacity(0.05),
                        blurRadius: 15,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Photo
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Stack(
                          children: [
                            CachedNetworkImage(
                              imageUrl: imageUrl,
                              height: 240,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                            Positioned(
                              top: 12,
                              right: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: rarityColor,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  rarity.toUpperCase(),
                                  style: GoogleFonts.nunito(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 15),

                      // Edit mode / display mode info
                      if (_isEditing) ...[
                        _buildFieldLabel('Nama Kucing'),
                        TextField(
                          controller: _nameController,
                          style: GoogleFonts.nunito(color: AppColors.textBrown, fontSize: 14),
                          decoration: InputDecoration(fillColor: AppColors.bgCream, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                        ),
                        const SizedBox(height: 10),
                        _buildFieldLabel('Jenis/Ras Kucing'),
                        TextField(
                          controller: _breedController,
                          style: GoogleFonts.nunito(color: AppColors.textBrown, fontSize: 14),
                          decoration: InputDecoration(fillColor: AppColors.bgCream, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
                              onPressed: _isSaving ? null : _handleSaveDetails,
                              child: _isSaving ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Simpan'),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                side: const BorderSide(color: AppColors.borderCream),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              ),
                              onPressed: () {
                                setState(() {
                                  _isEditing = false;
                                  _nameController.text = _currentCat['custom_name'] ?? '';
                                  _breedController.text = _currentCat['breed'] ?? '';
                                });
                              },
                              child: Text('Batal', style: GoogleFonts.nunito(color: AppColors.textBrown)),
                            ),
                          ],
                        )
                      ] else ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          _currentCat['custom_name'] ?? 'Kucing',
                                          style: GoogleFonts.nunito(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textBrown),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      IconButton(
                                        icon: Icon(_isFavorite ? Icons.star : Icons.star_border, color: const Color(0xFFF1C40F)),
                                        onPressed: () => _toggleFavorite(!_isFavorite),
                                      ),
                                      GestureDetector(
                                        onTap: () => setState(() => _isEditing = true),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(color: AppColors.lightGreen, border: Border.all(color: AppColors.primaryGreen, width: 0.5), borderRadius: BorderRadius.circular(6)),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.edit, size: 10, color: AppColors.primaryGreen),
                                              const SizedBox(width: 2),
                                              Text('Edit', style: GoogleFonts.nunito(color: AppColors.primaryGreen, fontSize: 10, fontWeight: FontWeight.w800)),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(_currentCat['breed'] ?? 'Unknown Breed', style: GoogleFonts.nunito(fontSize: 13, color: AppColors.primaryGreen, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 8),
                                  // Level / XP Bar
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(color: AppColors.primaryGreen, borderRadius: BorderRadius.circular(8)),
                                        child: Text('LVL $level', style: GoogleFonts.nunito(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(4),
                                          child: LinearProgressIndicator(
                                            value: xp / maxXp,
                                            backgroundColor: AppColors.borderCream,
                                            color: AppColors.primaryGreen,
                                            minHeight: 6,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text('$xp/$maxXp XP', style: GoogleFonts.nunito(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w700)),
                                    ],
                                  )
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: AppColors.bgCream, border: Border.all(color: AppColors.borderCream), borderRadius: BorderRadius.circular(8)),
                              child: Text(formattedDate, style: GoogleFonts.nunito(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 15),

                      // Stats
                      _buildStatRow('Cuteness', cuteness),
                      const SizedBox(height: 6),
                      _buildStatRow('Playfulness', playfulness),
                      const SizedBox(height: 6),
                      _buildStatRow('Energy', energy),
                      const SizedBox(height: 15),

                      // GPS Location
                      Row(
                        children: [
                          const Icon(Icons.location_on, color: AppColors.textMuted, size: 14),
                          const SizedBox(width: 4),
                          Text('Lokasi Penangkapan:', style: GoogleFonts.nunito(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w700)),
                        ],
                      ),
                      Text('${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}', style: GoogleFonts.nunito(color: AppColors.textBrown, fontSize: 12, fontWeight: FontWeight.w800)),
                      if (_isLoadingAddress)
                        Text('Memuat alamat...', style: GoogleFonts.nunito(color: AppColors.textMuted, fontSize: 11))
                      else if (_address != null)
                        Text(_address!, style: GoogleFonts.nunito(color: AppColors.textMuted, fontSize: 11)),
                      
                      const SizedBox(height: 15),

                      // Notes
                      Text('📝 Catatan Kucing:', style: GoogleFonts.nunito(color: AppColors.textBrown, fontSize: 12, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      if (_isEditing)
                        TextField(
                          controller: _notesController,
                          maxLines: 3,
                          style: GoogleFonts.nunito(color: AppColors.textBrown, fontSize: 13),
                          decoration: InputDecoration(
                            fillColor: AppColors.bgCream,
                            hintText: 'Tambahkan catatan pribadi...',
                            hintStyle: GoogleFonts.nunito(color: AppColors.textMuted),
                          ),
                        )
                      else
                        Text(
                          _currentCat['notes']?.toString().isNotEmpty == true
                              ? _currentCat['notes']!
                              : 'Belum ada catatan. Klik Edit untuk menambahkan catatan pribadi.',
                          style: GoogleFonts.nunito(color: AppColors.textBrown, fontSize: 12, height: 1.5),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Button Groups
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3498DB),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _handleShare,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.share, size: 16, color: Colors.white),
                        const SizedBox(width: 8),
                        Text('PAMERIN KE TEMAN', style: GoogleFonts.nunito(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF9B59B6),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () {
                      setState(() => _showGiftModal = true);
                      _fetchFriends();
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.card_giftcard, size: 16, color: Colors.white),
                        const SizedBox(width: 8),
                        Text('HADIAHKAN KUCING', style: GoogleFonts.nunito(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      side: const BorderSide(color: AppColors.borderCream),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      widget.showWelcome ? 'TUTUP & KEMBALI KE FEED' : 'KEMBALI',
                      style: GoogleFonts.nunito(color: AppColors.textBrown, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.danger,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () => setState(() => _showDeleteModal = true),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.delete_outline, size: 16, color: Colors.white),
                        const SizedBox(width: 8),
                        Text('HAPUS KUCING DARI ALBUM', style: GoogleFonts.nunito(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),

          // Gift Modal
          if (_showGiftModal)
            _buildModal(
              title: '🎁 Hadiahkan Kucing',
              sub: 'Kirim "${_currentCat['custom_name']}" ke teman pilihanmu.',
              content: _isLoadingFriends
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF9B59B6)))
                  : _friendsList.isEmpty
                      ? Text(
                          'Kamu belum memiliki teman untuk dikirimi hadiah.',
                          style: GoogleFonts.nunito(color: AppColors.textMuted),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Pilih Teman:', style: GoogleFonts.nunito(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textBrown)),
                            const SizedBox(height: 6),
                            Container(
                              height: 150,
                              decoration: BoxDecoration(border: Border.all(color: AppColors.borderCream), borderRadius: BorderRadius.circular(12), color: AppColors.bgCream),
                              child: ListView.builder(
                                itemCount: _friendsList.length,
                                itemBuilder: (context, index) {
                                  final friend = _friendsList[index];
                                  final isSelected = _selectedFriendId == friend['id'].toString();
                                  return ListTile(
                                    dense: true,
                                    selected: isSelected,
                                    selectedTileColor: AppColors.primaryGreen,
                                    title: Text(
                                      '${friend['name']} (@${friend['username']})',
                                      style: GoogleFonts.nunito(
                                        color: isSelected ? Colors.white : AppColors.textBrown,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    ),
                                    onTap: () => setState(() => _selectedFriendId = friend['id'].toString()),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text('Pesan Tambahan:', style: GoogleFonts.nunito(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textBrown)),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _giftMsgController,
                              style: GoogleFonts.nunito(fontSize: 12, color: AppColors.textBrown),
                              decoration: InputDecoration(fillColor: AppColors.bgCream, hintText: 'Tulis pesan manis...'),
                            ),
                          ],
                        ),
              actions: [
                TextButton(
                  onPressed: () => setState(() => _showGiftModal = false),
                  child: Text('Batal', style: GoogleFonts.nunito(color: AppColors.textMuted)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF9B59B6)),
                  onPressed: _isSendingGift || _selectedFriendId == null ? null : _sendGift,
                  child: _isSendingGift
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Kirim Hadiah'),
                ),
              ],
            ),

          // Delete Modal
          if (_showDeleteModal)
            _buildModal(
              title: '🗑️ Hapus Kucing',
              sub: 'Apakah Anda yakin ingin menghapus "${_currentCat['custom_name']}"? Tindakan ini tidak dapat dibatalkan.',
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Masukkan Password Akun Anda:', style: GoogleFonts.nunito(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textBrown)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _deletePasswordController,
                    obscureText: true,
                    style: GoogleFonts.nunito(fontSize: 12, color: AppColors.textBrown),
                    decoration: InputDecoration(fillColor: AppColors.bgCream, hintText: 'Password Akun'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    setState(() => _showDeleteModal = false);
                    _deletePasswordController.clear();
                  },
                  child: Text('Batal', style: GoogleFonts.nunito(color: AppColors.textMuted)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
                  onPressed: _isDeleting ? null : _deleteCat,
                  child: _isDeleting
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Hapus Kucing'),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4, top: 8),
      child: Text(text.toUpperCase(), style: GoogleFonts.nunito(fontSize: 9, color: AppColors.textMuted, fontWeight: FontWeight.w800)),
    );
  }

  Widget _buildStatRow(String label, int val) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(label.toUpperCase(), style: GoogleFonts.nunito(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w700)),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: val / 100.0,
              backgroundColor: AppColors.bgCream,
              color: AppColors.primaryGreen,
              minHeight: 6,
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 25,
          child: Text('$val', style: GoogleFonts.nunito(color: AppColors.primaryGreen, fontSize: 12, fontWeight: FontWeight.w800), textAlign: TextAlign.right),
        ),
      ],
    );
  }

  Widget _buildModal({
    required String title,
    required String sub,
    required Widget content,
    required List<Widget> actions,
  }) {
    return Container(
      color: Colors.black54,
      width: double.infinity,
      height: double.infinity,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(30),
      child: Material(
        color: AppColors.cardCream,
        borderRadius: BorderRadius.circular(20),
        elevation: 10,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textBrown)),
              const SizedBox(height: 4),
              Text(sub, style: GoogleFonts.nunito(fontSize: 12, color: AppColors.textMuted)),
              const SizedBox(height: 15),
              content,
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: actions,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
