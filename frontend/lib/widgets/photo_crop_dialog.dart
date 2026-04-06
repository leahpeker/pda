import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';

enum PhotoCropMode { circle, rectangle }

/// Shows a crop dialog for photos.
///
/// Use [mode] to select circle (profile photos) or rectangle (event photos).
/// For rectangle mode, pass [aspectRatio] (e.g. `2 / 1` for a 2:1 banner crop).
///
/// Returns the cropped [Uint8List], or `null` if the user cancels.
Future<Uint8List?> showPhotoCropDialog({
  required BuildContext context,
  required Uint8List imageBytes,
  PhotoCropMode mode = PhotoCropMode.circle,
  double aspectRatio = 1,
}) {
  return showDialog<Uint8List>(
    context: context,
    builder: (_) => _PhotoCropDialog(
      imageBytes: imageBytes,
      mode: mode,
      aspectRatio: aspectRatio,
    ),
  );
}

class _PhotoCropDialog extends StatefulWidget {
  const _PhotoCropDialog({
    required this.imageBytes,
    required this.mode,
    required this.aspectRatio,
  });

  final Uint8List imageBytes;
  final PhotoCropMode mode;
  final double aspectRatio;

  @override
  State<_PhotoCropDialog> createState() => _PhotoCropDialogState();
}

class _PhotoCropDialogState extends State<_PhotoCropDialog> {
  final _controller = CropController();
  bool _cropping = false;

  void _onDone() {
    setState(() => _cropping = true);
    if (widget.mode == PhotoCropMode.circle) {
      _controller.cropCircle();
    } else {
      _controller.crop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isCircle = widget.mode == PhotoCropMode.circle;
    final title = isCircle ? 'crop profile photo' : 'crop event photo';
    final cropHeight = isCircle ? 360.0 : 260.0;

    return AlertDialog(
      title: Text(title),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 360,
            height: cropHeight,
            child: Semantics(
              label: 'crop area — pinch to zoom, drag to reposition',
              child: Crop(
                image: widget.imageBytes,
                controller: _controller,
                withCircleUi: isCircle,
                aspectRatio: widget.aspectRatio,
                onCropped: (croppedBytes) {
                  if (mounted) Navigator.of(context).pop(croppedBytes);
                },
                onStatusChanged: (status) {
                  if (status != CropStatus.cropping && mounted) {
                    setState(() => _cropping = false);
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'pinch to zoom, drag to reposition',
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _cropping ? null : () => Navigator.of(context).pop(),
          child: const Text('cancel'),
        ),
        FilledButton(
          onPressed: _cropping ? null : _onDone,
          child: _cropping
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('save crop'),
        ),
      ],
    );
  }
}
