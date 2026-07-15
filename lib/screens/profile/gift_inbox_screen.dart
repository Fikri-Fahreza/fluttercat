import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../config/api_config.dart';

class GiftInboxScreen extends StatefulWidget {
  const GiftInboxScreen({super.key});

  @override
  State<GiftInboxScreen> createState() => _GiftInboxScreenState();
}

class _GiftInboxScreenState extends State<GiftInboxScreen> {
  final Dio _dio = Dio();
  List<dynamic> _gifts = [];
  bool _isLoading = true;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchGifts());
  }

  String get _token => context.read<AuthProvider>().token ?? '';
  Options get _authOptions => Options(headers: {'Authorization': 'Bearer $_token', 'Accept': 'application/json'});

  Future<void> _fetchGifts() async {
    try {
      final res = await _dio.get('${ApiConfig.baseUrl}/api/gifts/inbox', options: _authOptions);
      setState(() {
        _gifts = res.data['gifts'] ?? [];
        _isLoading = false;
        _isRefreshing = false;
      });
    } catch (e) {
      debugPrint('Fetch gifts error: $e');
      setState(() {
        _isLoading = false;
        _isRefreshing = false;
      });
    }
  }

  Future<void> _onRefresh() async {
    setState(() => _isRefreshing = true);
    await _fetchGifts();
  }

  Future<void> _handleAccept(int giftId) async {
    try {
      await _dio.post('${ApiConfig.baseUrl}/api/gifts/$giftId/accept', data: {}, options: _authOptions);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hadiah kucing diterima! Kucing sekarang ada di album milikmu.')),
      );
      _fetchGifts();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal menerima hadiah.')),
      );
    }
  }

  Future<void> _handleReject(int giftId) async {
    try {
      await _dio.post('${ApiConfig.baseUrl}/api/gifts/$giftId/reject', data: {}, options: _authOptions);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hadiah ditolak.')),
      );
      _fetchGifts();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal menolak hadiah.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgCream,
      appBar: AppBar(
        title: const Text('🎁 Kotak Masuk Hadiah'),
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
                  Text('Memuat kotak masuk hadiah...', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            )
          : _gifts.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('🎁', style: TextStyle(fontSize: 48)),
                        const SizedBox(height: 10),
                        Text(
                          'Kotak masuk hadiah masih kosong',
                          style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textMuted),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  color: AppColors.primaryGreen,
                  onRefresh: _onRefresh,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _gifts.length,
                    itemBuilder: (context, index) {
                      final item = _gifts[index];
                      return _buildGiftCard(item);
                    },
                  ),
                ),
    );
  }

  Widget _buildGiftCard(Map<String, dynamic> item) {
    final fromUser = item['from_user'] ?? {};
    final cat = item['cat'] ?? {};
    final status = (item['status'] ?? 'pending').toString().toLowerCase();

    final avatarUrl = fromUser['avatar'] ?? 'https://via.placeholder.com/150';
    final photoPath = cat['photo'] ?? '';
    final catImageUrl = photoPath.startsWith('http') ? photoPath : '${ApiConfig.baseUrl}$photoPath';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardCream,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderCream),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header info
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.lightGreen,
                backgroundImage: NetworkImage(avatarUrl),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fromUser['name'] ?? '',
                      style: GoogleFonts.nunito(color: AppColors.textBrown, fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                    Text(
                      '@${fromUser['username'] ?? ''}',
                      style: GoogleFonts.nunito(color: AppColors.primaryGreen, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: status == 'pending' ? AppColors.danger.withOpacity(0.15) : AppColors.primaryGreen.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: GoogleFonts.nunito(
                    color: status == 'pending' ? AppColors.danger : AppColors.primaryGreen,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Cat details
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.bgCream,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderCream),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: catImageUrl,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(color: AppColors.lightGreen),
                    errorWidget: (_, __, ___) => const Center(child: Text('🐱')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cat['name'] ?? '',
                        style: GoogleFonts.nunito(color: AppColors.textBrown, fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                      Text(
                        cat['breed'] ?? '',
                        style: GoogleFonts.nunito(color: AppColors.primaryGreen, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        cat['rarity'] ?? 'Common',
                        style: GoogleFonts.nunito(color: const Color(0xFFE4C078), fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Custom message
          if (item['message'] != null && item['message'].toString().isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '"${item['message']}"',
                style: GoogleFonts.nunito(color: AppColors.textBrown, fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ),
          ],

          // Actions row
          if (status == 'pending') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      side: const BorderSide(color: AppColors.borderCream),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: () => _handleReject(item['id']),
                    child: Text('Tolak', style: GoogleFonts.nunito(color: AppColors.textBrown, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: () => _handleAccept(item['id']),
                    child: Text('Terima Kucing', style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
