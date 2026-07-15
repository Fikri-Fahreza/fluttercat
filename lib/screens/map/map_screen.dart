import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../config/api_config.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final Dio _dio = Dio();
  final MapController _mapController = MapController();

  List<dynamic> _cats = [];
  bool _isLoading = true;
  String? _error;
  LatLng? _userLocation;
  Map<String, dynamic>? _selectedCat;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _getUserLocation();
      await _fetchCats();
    });
  }

  String get _token => context.read<AuthProvider>().token ?? '';

  Options get _authOptions =>
      Options(headers: {'Authorization': 'Bearer $_token'});

  Future<void> _getUserLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;
      final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium);
      if (mounted) {
        setState(() =>
            _userLocation = LatLng(position.latitude, position.longitude));
        _mapController.move(_userLocation!, 14);
      }
    } catch (_) {}
  }

  Future<void> _fetchCats() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      Response response;
      try {
        response = await _dio.get(
            '${ApiConfig.baseUrl}/api/cats/map',
            options: _authOptions);
      } catch (_) {
        response = await _dio.get('${ApiConfig.baseUrl}/api/cats',
            options: _authOptions);
      }
      final data = response.data;
      List<dynamic> cats = [];
      if (data is Map && data['data'] != null) {
        cats = data['data'] as List<dynamic>;
      } else if (data is List) {
        cats = data;
      }
      setState(() {
        _cats = cats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Gagal memuat data: $e';
        _isLoading = false;
      });
    }
  }

  String _buildImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return '${ApiConfig.baseUrl}$path';
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
        return AppColors.primaryGreen;
    }
  }

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];
    // User location marker
    if (_userLocation != null) {
      markers.add(Marker(
        point: _userLocation!,
        width: 40,
        height: 40,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.blue,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                  color: Colors.blue.withOpacity(0.4), blurRadius: 8)
            ],
          ),
          child: const Icon(Icons.person, color: Colors.white, size: 20),
        ),
      ));
    }
    // Cat markers
    for (var cat in _cats) {
      final lat =
          double.tryParse(cat['latitude']?.toString() ?? '');
      final lng =
          double.tryParse(cat['longitude']?.toString() ?? '');
      if (lat == null || lng == null) continue;
      final catMap = cat as Map<String, dynamic>;
      markers.add(Marker(
        point: LatLng(lat, lng),
        width: 44,
        height: 44,
        child: GestureDetector(
          onTap: () => setState(() => _selectedCat = catMap),
          child: Container(
            decoration: BoxDecoration(
              color: _rarityColor(cat['rarity']),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                    color:
                        _rarityColor(cat['rarity']).withOpacity(0.4),
                    blurRadius: 8)
              ],
            ),
            child: const Icon(Icons.pets, color: Colors.white, size: 22),
          ),
        ),
      ));
    }
    return markers;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgCream,
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        title: Text('Peta Kucing 🗺️',
            style: GoogleFonts.nunito(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20)),
        automaticallyImplyLeading: false,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location, color: Colors.white),
            onPressed: () async {
              await _getUserLocation();
              if (_userLocation != null) {
                _mapController.move(_userLocation!, 14);
              }
            },
            tooltip: 'Lokasi saya',
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _fetchCats,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter:
                  _userLocation ?? const LatLng(-6.2088, 106.8456),
              initialZoom: 13,
              onTap: (_, __) => setState(() => _selectedCat = null),
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.streetcat.app',
              ),
              MarkerLayer(markers: _buildMarkers()),
            ],
          ),

          // Loading overlay
          if (_isLoading)
            const Center(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(
                      color: AppColors.primaryGreen),
                ),
              ),
            ),

          // Error banner
          if (_error != null)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Card(
                color: AppColors.cardCream,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: AppColors.danger),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(_error!,
                              style: GoogleFonts.nunito(
                                  color: AppColors.textBrown))),
                      TextButton(
                          onPressed: _fetchCats,
                          child: Text('Retry',
                              style: GoogleFonts.nunito(
                                  color: AppColors.primaryGreen))),
                    ],
                  ),
                ),
              ),
            ),

          // Stats bar
          Positioned(
            bottom: _selectedCat != null ? 220 : 16,
            left: 16,
            right: 16,
            child: Card(
              color: AppColors.cardCream,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _StatItem(
                        icon: Icons.pets,
                        label: '${_cats.length}',
                        sublabel: 'Kucing'),
                    Container(
                        width: 1,
                        height: 30,
                        color: AppColors.borderCream),
                    _StatItem(
                        icon: Icons.location_on,
                        label: _userLocation != null ? 'ON' : 'OFF',
                        sublabel: 'Lokasi'),
                  ],
                ),
              ),
            ),
          ),

          // Selected cat detail panel
          if (_selectedCat != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildCatDetail(_selectedCat!),
            ),
        ],
      ),
    );
  }

  Widget _buildCatDetail(Map<String, dynamic> cat) {
    final imgUrl = _buildImageUrl(
        cat['photo_path'] ?? cat['image'] ?? cat['photo']);
    final rarity = cat['rarity'] ?? 'Common';
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardCream,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 12,
              offset: const Offset(0, -4))
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.borderCream,
                    borderRadius: BorderRadius.circular(2))),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: imgUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: imgUrl,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                            width: 80,
                            height: 80,
                            color: AppColors.lightGreen,
                            child: const Center(
                                child: CircularProgressIndicator(
                                    color: AppColors.primaryGreen,
                                    strokeWidth: 2))),
                        errorWidget: (_, __, ___) => Container(
                            width: 80,
                            height: 80,
                            color: AppColors.lightGreen,
                            child: const Icon(Icons.pets,
                                color: AppColors.primaryGreen)),
                      )
                    : Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                            color: AppColors.lightGreen,
                            borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.pets,
                            color: AppColors.primaryGreen, size: 36)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        cat['custom_name'] ?? cat['name'] ?? 'Unknown',
                        style: GoogleFonts.nunito(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textBrown,
                            fontSize: 18)),
                    if (cat['breed'] != null &&
                        cat['breed'].toString().isNotEmpty)
                      Text(cat['breed'],
                          style: GoogleFonts.nunito(
                              color: AppColors.textMuted, fontSize: 13)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _rarityColor(rarity).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: _rarityColor(rarity).withOpacity(0.5)),
                      ),
                      child: Text(rarity,
                          style: GoogleFonts.nunito(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _rarityColor(rarity))),
                    ),
                    if (cat['description'] != null &&
                        cat['description'].toString().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(cat['description'],
                          style: GoogleFonts.nunito(
                              color: AppColors.textMuted, fontSize: 12),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.textMuted),
                onPressed: () => setState(() => _selectedCat = null),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  const _StatItem(
      {required this.icon, required this.label, required this.sublabel});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppColors.primaryGreen, size: 18),
        const SizedBox(width: 6),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: GoogleFonts.nunito(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textBrown,
                    fontSize: 14)),
            Text(sublabel,
                style: GoogleFonts.nunito(
                    color: AppColors.textMuted, fontSize: 11)),
          ],
        ),
      ],
    );
  }
}
