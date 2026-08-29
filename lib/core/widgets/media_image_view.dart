import 'dart:convert';
import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class MediaImageView extends StatelessWidget {
  final String url;
  final BoxFit fit;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  const MediaImageView({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    Widget content;

    if (url.startsWith('data:image') || url.startsWith('data:')) {
      try {
        final commaIdx = url.indexOf(',');
        final base64Data = commaIdx != -1 ? url.substring(commaIdx + 1).trim() : url.trim();
        final Uint8List bytes = base64Decode(base64Data);
        content = Image.memory(
          bytes,
          fit: fit,
          width: width,
          height: height,
          errorBuilder: (_, __, ___) => _buildPlaceholder(),
        );
      } catch (e) {
        content = _buildPlaceholder();
      }
    } else if (url.startsWith('http://') || url.startsWith('https://')) {
      content = CachedNetworkImage(
        imageUrl: url,
        fit: fit,
        width: width,
        height: height,
        placeholder: (_, __) => Container(
          width: width,
          height: height ?? 220,
          color: AppColors.darkCard,
          child: const Center(
            child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
          ),
        ),
        errorWidget: (_, __, ___) => _buildPlaceholder(),
      );
    } else {
      try {
        final Uint8List bytes = base64Decode(url.trim());
        content = Image.memory(
          bytes,
          fit: fit,
          width: width,
          height: height,
          errorBuilder: (_, __, ___) => _buildPlaceholder(),
        );
      } catch (_) {
        content = _buildPlaceholder();
      }
    }

    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: content);
    }
    return content;
  }

  Widget _buildPlaceholder() {
    return Container(
      width: width,
      height: height ?? 200,
      color: AppColors.darkCard,
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.image_outlined, color: AppColors.textMuted, size: 40),
            SizedBox(height: 8),
            Text('Photo attachment', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
