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
import '../profile/detail_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final Dio _dio = Dio();
  final MapController _mapController = MapController();

  LatLng _currentLocation = const LatLng(-6.200000, 106.816666); // Default Jakarta
  List<dynamic> _catsHeatmap = [];
  bool _isLoading = true;
  Map<String, dynamic>? _selectedCat;

  @override
  void initState() {
    super.initState();
    _initMapAndData();
  }

  String get _token => context.read<AuthProvider>().token ?? '';
  Options get _authOptions => Options(headers: {'Authorization': 'Bearer $_token', 'Accept': 'application/json'});

  Future<void> _initMapAndData() async {
    try {
      // 1. Get GPS Location
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.deniedForever) {
          debugPrint('Location permission denied forever');
        } else if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
          final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium);
          setState(() {
            _currentLocation = LatLng(position.latitude, position.longitude);
          });
        }
      }

      // 2. Fetch Heatmap Locations
      final res = await _dio.get('${ApiConfig.baseUrl}/api/feed/heatmap', options: _authOptions);
      setState(() {
        _catsHeatmap = res.data['cats'] ?? [];
        _isLoading = false;
      });

      // Move map to current location
      _mapController.move(_currentLocation, 16.0);

    } catch (e) {
      debugPrint('Map initialization error: $e');
      setState(() => _isLoading = false);
    }
  }

  String _buildImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return '${ApiConfig.baseUrl}$path';
  }

  Color _getRarityColor(String rarity) {
    switch (rarity.toLowerCase()) {
      case 'legendary': return const Color(0xFFFF9800);
      case 'epic': return const Color(0xFF9C27B0);
      case 'rare': return const Color(0xFF2196F3);
      default: return AppColors.primaryGreen;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Flutter Map View
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentLocation,
              initialZoom: 15.0,
              onTap: (_, __) {
                setState(() => _selectedCat = null);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.fikri.pawfinder',
              ),

              // Markers
              MarkerLayer(
                markers: [
                  // User Location Pin
                  Marker(
                    point: _currentLocation,
                    width: 40,
                    height: 40,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen.withOpacity(0.2),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Center(
                        child: Icon(Icons.my_location, color: AppColors.primaryGreen, size: 20),
                      ),
                    ),
                  ),

                  // Cat Spawns Heatmap Markers
                  ..._catsHeatmap.map((cat) {
                    final double lat = double.tryParse(cat['latitude']?.toString() ?? '') ?? 0.0;
                    final double lng = double.tryParse(cat['longitude']?.toString() ?? '') ?? 0.0;
                    final rarity = cat['rarity'] ?? 'Common';
                    final rarityColor = _getRarityColor(rarity);

                    return Marker(
                      point: LatLng(lat, lng),
                      width: 50,
                      height: 50,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedCat = cat;
                          });
                        },
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Outer Glow
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: rarityColor.withOpacity(0.3),
                              ),
                            ),
                            // Profile Frame
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: rarityColor, width: 2.5),
                                color: AppColors.cardCream,
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(15),
                                child: CachedNetworkImage(
                                  imageUrl: _buildImageUrl(cat['photo_path'] ?? cat['photo']),
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => const Center(
                                    child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.primaryGreen),
                                  ),
                                  errorWidget: (_, __, ___) => const Icon(Icons.pets, size: 14, color: AppColors.textMuted),
                                ),
                              ),
                            ),
                            // Small Paw Overlay
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: rarityColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 1),
                                ),
                                child: const Icon(Icons.pets, size: 8, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ],
          ),

          // Custom AppBar Overlays
          Positioned(
            top: 50,
            left: 20,
            child: CircleAvatar(
              backgroundColor: Colors.white,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textBrown, size: 18),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),

          // Center Map to Current GPS Action Button
          Positioned(
            bottom: _selectedCat != null ? 180 : 30,
            right: 20,
            child: FloatingActionButton(
              mini: true,
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primaryGreen,
              onPressed: () {
                _mapController.move(_currentLocation, 16.0);
              },
              child: const Icon(Icons.gps_fixed),
            ),
          ),

          // Selected Cat Quick Card Preview (Bottom Overlay)
          if (_selectedCat != null)
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.cardCream,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.borderCream),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.textBrown.withOpacity(0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: CachedNetworkImage(
                        imageUrl: _buildImageUrl(_selectedCat!['photo_path'] ?? _selectedCat!['photo']),
                        width: 70,
                        height: 70,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _selectedCat!['custom_name'] ?? _selectedCat!['name'] ?? 'Kucing',
                            style: GoogleFonts.nunito(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textBrown),
                          ),
                          Text(
                            _selectedCat!['breed'] ?? 'Unknown Breed',
                            style: GoogleFonts.nunito(color: AppColors.textMuted, fontSize: 11),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _getRarityColor(_selectedCat!['rarity'] ?? 'Common').withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              (_selectedCat!['rarity'] ?? 'Common').toUpperCase(),
                              style: GoogleFonts.nunito(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: _getRarityColor(_selectedCat!['rarity'] ?? 'Common'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Detail button
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DetailScreen(cat: _selectedCat!),
                          ),
                        );
                      },
                      child: Text('DETAIL', style: GoogleFonts.nunito(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 10)),
                    ),
                  ],
                ),
              ),
            ),

          // Global loading indicator
          if (_isLoading)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.3),
                child: const Center(
                  child: CircularProgressIndicator(color: AppColors.primaryGreen),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
