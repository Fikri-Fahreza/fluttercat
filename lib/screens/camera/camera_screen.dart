import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../config/api_config.dart';
import '../profile/detail_screen.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  final Dio _dio = Dio();
  final ImagePicker _picker = ImagePicker();

  File? _imageFile;
  String? _photoBase64;
  bool _isLoading = false;
  String _loadingText = '';

  @override
  void initState() {
    super.initState();
    // Buka kamera otomatis saat halaman dibuka pertama kali
    WidgetsBinding.instance.addPostFrameCallback((_) => _takePhoto());
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 50,
      );
      if (photo != null) {
        final file = File(photo.path);
        final bytes = await file.readAsBytes();
        setState(() {
          _imageFile = file;
          _photoBase64 = base64Encode(bytes);
        });
      } else if (_imageFile == null) {
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Take photo error: $e');
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 50,
      );
      if (photo != null) {
        final file = File(photo.path);
        final bytes = await file.readAsBytes();
        setState(() {
          _imageFile = file;
          _photoBase64 = base64Encode(bytes);
        });
      }
    } catch (e) {
      debugPrint('Pick image error: $e');
    }
  }

  Future<void> _analyzeAndCatch() async {
    if (_photoBase64 == null) return;

    setState(() {
      _isLoading = true;
      _loadingText = 'Membaca GPS Lokasi Anda...';
    });

    try {
      // Baca lokasi GPS
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Layanan lokasi dinonaktifkan. Aktifkan GPS Anda.')),
        );
        setState(() => _isLoading = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Izin GPS ditolak.')),
          );
          setState(() => _isLoading = false);
          return;
        }
      }

      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      final double latitude = position.latitude;
      final double longitude = position.longitude;

      setState(() {
        _loadingText = 'AI sedang menganalisis kucing...';
      });

      final token = context.read<AuthProvider>().token;
      final response = await _dio.post(
        '${ApiConfig.baseUrl}/api/cats/catch',
        data: {
          'photo': _photoBase64,
          'latitude': latitude,
          'longitude': longitude,
        },
        options: Options(headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        }),
      );

      final newCat = response.data['cat'];

      setState(() {
        _isLoading = false;
        _imageFile = null;
        _photoBase64 = null;
      });

      // Buka DetailScreen dengan layout "TANGKAPAN BARU!"
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DetailScreen(cat: newCat, showWelcome: true),
          ),
        );
      }

    } catch (e) {
      debugPrint('AI Scan catch error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal mendeteksi kucing. Pastikan objek terlihat jelas.')),
      );
      setState(() => _isLoading = false);
    }
  }

  void _reset() {
    setState(() {
      _imageFile = null;
      _photoBase64 = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background/Preview Area
          if (_imageFile != null)
            Positioned.fill(
              child: Image.file(
                _imageFile!,
                fit: BoxFit.cover,
              ),
            )
          else
            Positioned.fill(
              child: Container(
                color: AppColors.bgCream,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.photo_camera_rounded, size: 70, color: AppColors.primaryGreen),
                    const SizedBox(height: 15),
                    Text(
                      'AI MAIA Scanner',
                      style: GoogleFonts.nunito(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textBrown,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Potret kucing jalanan untuk analisis AI',
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 30),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      onPressed: _takePhoto,
                      icon: const Icon(Icons.camera_alt, color: Colors.white),
                      label: Text('BUKA KAMERA', style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.primaryGreen),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _pickFromGallery,
                      icon: const Icon(Icons.photo_library, color: AppColors.primaryGreen),
                      label: Text('PILIH DARI GALERI', style: GoogleFonts.nunito(color: AppColors.primaryGreen, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),

          // Top Header Instruction Overlay (Only in Preview)
          if (_imageFile != null && !_isLoading)
            Positioned(
              top: 50,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.75),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: AppColors.primaryGreen, size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Kucing Berhasil Terfoto!',
                            style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          Text(
                            'Tekan Analisis untuk melihat tingkat kelangkaan dan statistiknya.',
                            style: GoogleFonts.nunito(color: Colors.white70, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Bottom Action Panel (Only in Preview)
          if (_imageFile != null && !_isLoading)
            Positioned(
              bottom: 40,
              left: 20,
              right: 20,
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.2),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: _reset,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: Text('ULANGI FOTO', style: GoogleFonts.nunito(fontWeight: FontWeight.bold, fontSize: 11)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: _analyzeAndCatch,
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: Text('ANALISIS SEKARANG', style: GoogleFonts.nunito(fontWeight: FontWeight.bold, fontSize: 11)),
                    ),
                  ),
                ],
              ),
            ),

          // Loading Overlay
          if (_isLoading)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(color: AppColors.primaryGreen),
                    const SizedBox(height: 20),
                    Text(
                      _loadingText,
                      style: GoogleFonts.nunito(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
