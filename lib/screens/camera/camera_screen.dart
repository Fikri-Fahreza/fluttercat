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

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  final Dio _dio = Dio();
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();

  File? _imageFile;
  bool _isUploading = false;
  bool _isGettingLocation = false;
  String? _uploadError;
  String? _uploadSuccess;

  final _nameController = TextEditingController();
  final _breedController = TextEditingController();
  final _colorController = TextEditingController();
  final _descController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();

  String _selectedRarity = 'Common';
  final List<String> _rarities = [
    'Common',
    'Uncommon',
    'Rare',
    'Epic',
    'Legendary'
  ];

  @override
  void initState() {
    super.initState();
    _getLocation();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _breedController.dispose();
    _colorController.dispose();
    _descController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  Future<void> _getLocation() async {
    setState(() => _isGettingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _isGettingLocation = false);
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _isGettingLocation = false);
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        setState(() => _isGettingLocation = false);
        return;
      }
      final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _latController.text = position.latitude.toStringAsFixed(6);
        _lngController.text = position.longitude.toStringAsFixed(6);
        _isGettingLocation = false;
      });
    } catch (_) {
      setState(() => _isGettingLocation = false);
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? file = await _picker.pickImage(
          source: ImageSource.gallery, imageQuality: 80);
      if (file != null) setState(() => _imageFile = File(file.path));
    } catch (_) {}
  }

  Future<void> _submit() async {
    if (_imageFile == null) {
      setState(() =>
          _uploadError = 'Pilih foto kucing terlebih dahulu!');
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isUploading = true;
      _uploadError = null;
      _uploadSuccess = null;
    });
    try {
      final token = context.read<AuthProvider>().token;
      final formData = FormData.fromMap({
        'custom_name': _nameController.text.trim(),
        'breed': _breedController.text.trim(),
        'color': _colorController.text.trim(),
        'rarity': _selectedRarity,
        'description': _descController.text.trim(),
        'latitude': _latController.text.trim(),
        'longitude': _lngController.text.trim(),
        'photo': await MultipartFile.fromFile(_imageFile!.path,
            filename: 'cat_photo.jpg'),
      });
      final response = await _dio.post(
        '${ApiConfig.baseUrl}/api/cats',
        data: formData,
        options: Options(headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'multipart/form-data',
        }),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        setState(() {
          _uploadSuccess = 'Kucing berhasil ditambahkan! 🎉';
          _isUploading = false;
        });
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) Navigator.pop(context, true);
      } else {
        setState(() {
          _uploadError =
              'Gagal menambahkan kucing (${response.statusCode})';
          _isUploading = false;
        });
      }
    } on DioException catch (e) {
      setState(() {
        _uploadError = e.response?.data?['message'] ??
            e.response?.data?['error'] ??
            'Upload gagal: ${e.message}';
        _isUploading = false;
      });
    } catch (e) {
      setState(() {
        _uploadError = 'Error: $e';
        _isUploading = false;
      });
    }
  }

  Color _rarityColor(String rarity) {
    switch (rarity.toLowerCase()) {
      case 'legendary':
        return const Color(0xFFFF9800);
      case 'epic':
        return const Color(0xFF9C27B0);
      case 'rare':
        return const Color(0xFF2196F3);
      case 'uncommon':
        return const Color(0xFF4CAF50);
      default:
        return AppColors.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgCream,
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        title: Text('Tambah Kucing 🐱',
            style: GoogleFonts.nunito(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Photo picker
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 220,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.lightGreen,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: AppColors.primaryGreen.withOpacity(0.5),
                        width: 2),
                  ),
                  child: _imageFile != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Image.file(_imageFile!,
                              fit: BoxFit.cover,
                              width: double.infinity),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                                Icons.add_photo_alternate_outlined,
                                color: AppColors.primaryGreen,
                                size: 56),
                            const SizedBox(height: 10),
                            Text('Pilih foto kucing',
                                style: GoogleFonts.nunito(
                                    color: AppColors.primaryGreen,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16)),
                            Text('dari galeri',
                                style: GoogleFonts.nunito(
                                    color: AppColors.textMuted,
                                    fontSize: 13)),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.photo_library,
                      color: AppColors.primaryGreen),
                  label: Text('Pilih dari Galeri',
                      style: GoogleFonts.nunito(
                          color: AppColors.primaryGreen,
                          fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 16),

              // Form fields
              _buildLabel('Nama Kucing *'),
              _buildTextField(
                controller: _nameController,
                hint: 'Contoh: Si Oyen',
                validator: (v) =>
                    v == null || v.isEmpty ? 'Nama wajib diisi' : null,
              ),
              const SizedBox(height: 14),

              _buildLabel('Ras/Breed'),
              _buildTextField(
                  controller: _breedController,
                  hint: 'Contoh: Domestic Shorthair'),
              const SizedBox(height: 14),

              _buildLabel('Warna'),
              _buildTextField(
                  controller: _colorController,
                  hint: 'Contoh: Orange, Putih'),
              const SizedBox(height: 14),

              _buildLabel('Raritas *'),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppColors.cardCream,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderCream),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedRarity,
                    isExpanded: true,
                    style: GoogleFonts.nunito(
                        color: AppColors.textBrown, fontSize: 15),
                    dropdownColor: AppColors.cardCream,
                    items: _rarities
                        .map((r) => DropdownMenuItem(
                              value: r,
                              child: Row(
                                children: [
                                  Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                          color: _rarityColor(r),
                                          shape: BoxShape.circle)),
                                  const SizedBox(width: 10),
                                  Text(r,
                                      style: GoogleFonts.nunito(
                                          color: AppColors.textBrown,
                                          fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _selectedRarity = v);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 14),

              _buildLabel('Deskripsi'),
              TextFormField(
                controller: _descController,
                maxLines: 3,
                style: GoogleFonts.nunito(color: AppColors.textBrown),
                decoration: InputDecoration(
                  hintText: 'Ceritakan tentang kucing ini...',
                  hintStyle:
                      GoogleFonts.nunito(color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.cardCream,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: AppColors.borderCream)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: AppColors.borderCream)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: AppColors.primaryGreen, width: 2)),
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),
              const SizedBox(height: 14),

              _buildLabel('Lokasi'),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                        controller: _latController,
                        hint: 'Latitude',
                        keyboardType: TextInputType.number),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildTextField(
                        controller: _lngController,
                        hint: 'Longitude',
                        keyboardType: TextInputType.number),
                  ),
                  const SizedBox(width: 10),
                  if (_isGettingLocation)
                    const SizedBox(
                        width: 40,
                        height: 40,
                        child: CircularProgressIndicator(
                            color: AppColors.primaryGreen, strokeWidth: 2))
                  else
                    IconButton(
                      onPressed: _getLocation,
                      icon: const Icon(Icons.my_location,
                          color: AppColors.primaryGreen),
                      tooltip: 'Dapatkan lokasi',
                    ),
                ],
              ),
              const SizedBox(height: 24),

              if (_uploadError != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppColors.danger.withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: AppColors.danger, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(_uploadError!,
                              style: GoogleFonts.nunito(
                                  color: AppColors.danger, fontSize: 13))),
                    ],
                  ),
                ),

              if (_uploadSuccess != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.lightGreen,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppColors.primaryGreen.withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle,
                          color: AppColors.primaryGreen, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(_uploadSuccess!,
                              style: GoogleFonts.nunito(
                                  color: AppColors.primaryGreen,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13))),
                    ],
                  ),
                ),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 2,
                  ),
                  onPressed: _isUploading ? null : _submit,
                  child: _isUploading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5))
                      : Text('Simpan Kucing 🐾',
                          style: GoogleFonts.nunito(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 17)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text,
          style: GoogleFonts.nunito(
              color: AppColors.textBrown,
              fontWeight: FontWeight.w700,
              fontSize: 14)),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    String? hint,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: GoogleFonts.nunito(color: AppColors.textBrown),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.nunito(color: AppColors.textMuted),
        filled: true,
        fillColor: AppColors.cardCream,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.borderCream)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.borderCream)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: AppColors.primaryGreen, width: 2)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.danger)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}
