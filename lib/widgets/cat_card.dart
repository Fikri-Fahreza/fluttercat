import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/app_theme.dart';
import '../../config/api_config.dart';

class CatCard extends StatelessWidget {
  final Map<String, dynamic> cat;
  final VoidCallback? onTap;

  const CatCard({super.key, required this.cat, this.onTap});

  Color get _rarityColor {
    switch ((cat['rarity'] ?? '').toString().toLowerCase()) {
      case 'legendary': return const Color(0xFFFF8C00);
      case 'epic': return const Color(0xFF9B59B6);
      case 'rare': return const Color(0xFF3498DB);
      case 'uncommon': return const Color(0xFF2ECC71);
      default: return AppColors.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final photoPath = cat['photo_path'] ?? '';
    final imgUrl = photoPath.startsWith('http')
        ? photoPath
        : '${ApiConfig.baseUrl}$photoPath';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardCream,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderCream),
          boxShadow: [
            BoxShadow(
              color: AppColors.textBrown.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Stack(
                children: [
                  CachedNetworkImage(
                    imageUrl: imgUrl,
                    height: 120,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      height: 120,
                      color: AppColors.lightGreen,
                      child: const Center(
                        child: Text('🐱', style: TextStyle(fontSize: 32)),
                      ),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      height: 120,
                      color: AppColors.lightGreen,
                      child: const Center(
                        child: Text('🐱', style: TextStyle(fontSize: 32)),
                      ),
                    ),
                  ),
                  // Rarity badge
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _rarityColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        (cat['rarity'] ?? 'Common').toString().toUpperCase(),
                        style: GoogleFonts.nunito(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Info
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cat['custom_name'] ?? 'Kucing',
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textBrown,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    cat['breed'] ?? '-',
                    style: GoogleFonts.nunito(
                      fontSize: 10,
                      color: AppColors.primaryGreen,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
