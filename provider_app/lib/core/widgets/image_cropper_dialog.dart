import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../constants/app_colors.dart';
import '../utils/image_compression_helper.dart';

/// WhatsApp-Style Image Cropper Screen for Jamui Services Provider App
/// Supports:
/// - Smooth pinch-to-zoom and pan/drag gestures
/// - WhatsApp-style circular (or square) crop frame
/// - Rule-of-thirds 3x3 alignment grid while adjusting
/// - 90-degree rotation & reset
/// - Intelligent initial framing for portrait, landscape, and square images
/// - True pixel-accurate high-resolution canvas cropping (800x800)
/// - Preview dialog before confirmation
/// - Cancellation safety (preserves previous photo)
class ImageCropperDialog extends StatefulWidget {
  final String imagePath;
  final Uint8List? initialBytes;
  final bool initialIsCircle;

  const ImageCropperDialog({
    super.key,
    required this.imagePath,
    this.initialBytes,
    this.initialIsCircle = true,
  });

  static Future<String?> show(
    BuildContext context, {
    required String imagePath,
    Uint8List? initialBytes,
    bool isCircle = true,
  }) async {
    return Navigator.push<String>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ImageCropperDialog(
          imagePath: imagePath,
          initialBytes: initialBytes,
          initialIsCircle: isCircle,
        ),
      ),
    );
  }

  @override
  State<ImageCropperDialog> createState() => _ImageCropperDialogState();
}

class _ImageCropperDialogState extends State<ImageCropperDialog> {
  ui.Image? _rawImage;
  bool _isLoading = true;
  String? _errorMessage;

  // Cropper shape
  late bool _isCircle;

  // Active crop bounds for confirmation
  Rect? _currentCropRect;
  Size? _currentViewportSize;

  // Gesture transformation state
  Offset _offset = Offset.zero;
  Offset _baseOffset = Offset.zero;
  double _scale = 1.0;
  double _baseScale = 1.0;
  int _quarterTurns = 0;
  bool _isInteracting = false;
  Offset _focalPoint = Offset.zero;

  // Layout sizing
  double _initWidth = 300.0;
  double _initHeight = 300.0;
  Offset _initialOffset = Offset.zero;
  bool _initializedLayout = false;

  // Processing state during crop
  bool _isProcessingCrop = false;

  @override
  void initState() {
    super.initState();
    _isCircle = widget.initialIsCircle;
    _loadImage();
  }

  Future<void> _loadImage() async {
    try {
      Uint8List bytes;
      if (widget.initialBytes != null && widget.initialBytes!.isNotEmpty) {
        bytes = widget.initialBytes!;
      } else {
        final path = widget.imagePath.trim();
        if (path.startsWith('http://') || path.startsWith('https://')) {
          final res = await http.get(Uri.parse(path));
          if (res.statusCode != 200) throw Exception('Image download failed: ${res.statusCode}');
          bytes = res.bodyBytes;
        } else if (path.startsWith('data:image/')) {
          final comma = path.indexOf('base64,');
          if (comma == -1) throw Exception('Invalid data URI format');
          bytes = base64Decode(path.substring(comma + 7).trim());
        } else if (kIsWeb || path.startsWith('blob:')) {
          final res = await http.get(Uri.parse(path));
          bytes = res.bodyBytes;
        } else {
          final file = File(path);
          if (!await file.exists()) throw Exception('Image file not found at: $path');
          bytes = await file.readAsBytes();
        }
      }

      final codec = await ui.instantiateImageCodec(bytes);
      final frameInfo = await codec.getNextFrame();
      if (mounted) {
        setState(() {
          _rawImage = frameInfo.image;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'फोटो लोड करने में असमर्थ: $e';
        });
      }
    }
  }

  void _calculateInitialFraming(double viewportWidth, double viewportHeight, double cropSize) {
    if (_initializedLayout || _rawImage == null) return;

    final imgW = _rawImage!.width.toDouble();
    final imgH = _rawImage!.height.toDouble();

    if (imgW >= imgH) {
      // Landscape or square photo: match height to circle diameter so circle is fully covered
      _initHeight = cropSize;
      _initWidth = cropSize * (imgW / imgH);
      _initialOffset = Offset.zero; // Perfectly centered
    } else {
      // Portrait photo: match width to circle diameter
      _initWidth = cropSize;
      _initHeight = cropSize * (imgH / imgW);

      // In portrait photos, human faces/heads are almost always in top 35%.
      // Offset slightly downwards so head/face is centered in crop circle, preventing face cutoff.
      final excessHeight = _initHeight - cropSize;
      final yShift = (excessHeight * 0.35).clamp(0.0, excessHeight / 2);
      _initialOffset = Offset(0, yShift);
    }

    _offset = _initialOffset;
    _scale = 1.0;
    _quarterTurns = 0;
    _initializedLayout = true;
  }

  void _resetTransform() {
    setState(() {
      _offset = _initialOffset;
      _scale = 1.0;
      _quarterTurns = 0;
    });
  }

  void _rotateRight() {
    setState(() {
      _quarterTurns = (_quarterTurns + 1) % 4;
    });
  }

  void _rotateLeft() {
    setState(() {
      _quarterTurns = (_quarterTurns - 1) % 4;
    });
  }

  void _zoomIn() {
    setState(() {
      _scale = (_scale * 1.2).clamp(0.4, 6.0);
    });
  }

  void _zoomOut() {
    setState(() {
      _scale = (_scale / 1.2).clamp(0.4, 6.0);
    });
  }

  Future<Uint8List> _generateCroppedBytes({
    required ui.Image rawImage,
    required Rect cropRect,
    required Size viewportSize,
    required Offset offset,
    required double scale,
    required int quarterTurns,
    required double initWidth,
    required double initHeight,
    double outputSize = 800.0,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, outputSize, outputSize));

    // The scale factor from screen cropRect to output image:
    final factor = outputSize / cropRect.width;

    // 1. Center of output canvas
    canvas.translate(outputSize / 2, outputSize / 2);
    canvas.scale(factor);

    // 2. User's interactive pan, rotate, and scale
    canvas.translate(offset.dx, offset.dy);
    canvas.rotate(quarterTurns * (math.pi / 2));
    canvas.scale(scale);

    // 3. Draw rawImage centered at Offset.zero with size initWidth x initHeight
    final srcRect = Rect.fromLTWH(0, 0, rawImage.width.toDouble(), rawImage.height.toDouble());
    final destRect = Rect.fromCenter(
      center: Offset.zero,
      width: initWidth,
      height: initHeight,
    );
    final paint = Paint()..filterQuality = FilterQuality.high;
    canvas.drawImageRect(rawImage, srcRect, destRect, paint);

    final picture = recorder.endRecording();
    final ui.Image croppedImage = await picture.toImage(outputSize.toInt(), outputSize.toInt());
    final ByteData? byteData = await croppedImage.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  Future<void> _handleConfirmCrop(Rect cropRect, Size viewportSize) async {
    if (_rawImage == null || _isProcessingCrop) return;

    setState(() => _isProcessingCrop = true);

    try {
      final rawCroppedBytes = await _generateCroppedBytes(
        rawImage: _rawImage!,
        cropRect: cropRect,
        viewportSize: viewportSize,
        offset: _offset,
        scale: _scale,
        quarterTurns: _quarterTurns,
        initWidth: _initWidth,
        initHeight: _initHeight,
        outputSize: 800.0,
      );

      // Convert raw PNG canvas bytes to true high-quality 80% JPEG with alpha compositing
      final croppedBytes = ImageCompressionHelper.compressToJpeg(
        rawCroppedBytes,
        quality: 80,
        maxDimension: 800,
      );

      if (!mounted) return;

      // Show WhatsApp-style preview dialog
      final bool? confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            title: const Row(
              children: [
                Icon(Icons.remove_red_eye_rounded, color: Colors.greenAccent),
                SizedBox(width: 10),
                Text(
                  'फोटो पूर्वावलोकन (Preview)',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: _isCircle ? BoxShape.circle : BoxShape.rectangle,
                    borderRadius: _isCircle ? null : BorderRadius.circular(16),
                    border: Border.all(color: Colors.greenAccent, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.6),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.memory(
                    croppedBytes,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _isCircle
                      ? 'आपकी प्रोफाइल पर फोटो इसी तरह गोलाकार (Circular) दिखेगी।'
                      : 'आपकी दुकान / वर्कप्लेस की फोटो इसी तरह चौकोर (Square) दिखेगी।',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 6),
                const Text(
                  '800 × 800 HD • हाई क्वालिटी रिज़ॉल्यूशन (Optimized JPEG)',
                  style: TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('दोबारा सेट करें (Adjust)', style: TextStyle(color: Colors.white70)),
              ),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(ctx, true),
                icon: const Icon(Icons.check, size: 16),
                label: const Text('उपयोग करें (Use Photo)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          );
        },
      );

      if (confirmed == true && mounted) {
        if (kIsWeb) {
          final dataUri = 'data:image/jpeg;base64,${base64Encode(croppedBytes)}';
          Navigator.pop(context, dataUri);
        } else {
          final tempDir = Directory.systemTemp;
          final fileName = 'cropped_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final tempFile = File('${tempDir.path}/$fileName');
          await tempFile.writeAsBytes(croppedBytes);
          if (!mounted) return;
          Navigator.pop(context, tempFile.path);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('क्रॉप करने में त्रुटि: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessingCrop = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1117),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          tooltip: 'रद्द करें (Cancel)',
          onPressed: () => Navigator.pop(context, null),
        ),
        title: const Text(
          'फोटो क्रॉप करें (Crop Photo)',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        actions: [
          // Shape toggle button (Circle / Square)
          TextButton.icon(
            onPressed: () => setState(() => _isCircle = !_isCircle),
            icon: Icon(_isCircle ? Icons.circle_outlined : Icons.crop_square_rounded, color: Colors.white70, size: 16),
            label: Text(
              _isCircle ? 'गोलाकार' : 'चौकोर',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
          IconButton(
            icon: _isProcessingCrop
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.greenAccent),
                  )
                : const Icon(Icons.check, color: Colors.greenAccent, size: 28),
            tooltip: 'पुष्टि करें (Confirm)',
            onPressed: (_isProcessingCrop || _currentCropRect == null || _currentViewportSize == null)
                ? null
                : () => _handleConfirmCrop(_currentCropRect!, _currentViewportSize!),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.greenAccent),
                  SizedBox(height: 16),
                  Text('फोटो लोड हो रही है...', style: TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                        const SizedBox(height: 14),
                        Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 14)),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, null),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.white24),
                          child: const Text('वापस जाएं (Back)'),
                        ),
                      ],
                    ),
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final viewportWidth = constraints.maxWidth;
                    final viewportHeight = constraints.maxHeight - 110; // Reserve room for bottom controls

                    // Crop area centered in workspace
                    final cropSize = math.min(viewportWidth - 48, viewportHeight - 60).clamp(240.0, 360.0);
                    final cropLeft = (viewportWidth - cropSize) / 2;
                    final cropTop = (viewportHeight - cropSize) / 2;
                    final cropRect = Rect.fromLTWH(cropLeft, cropTop, cropSize, cropSize);

                    _currentCropRect = cropRect;
                    _currentViewportSize = Size(viewportWidth, viewportHeight);

                    _calculateInitialFraming(viewportWidth, viewportHeight, cropSize);

                    return Stack(
                      children: [
                        // 1. Gesture interactive photo workspace
                        Positioned.fill(
                          bottom: 110,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onScaleStart: (details) {
                              setState(() {
                                _isInteracting = true;
                                _baseScale = _scale;
                                _baseOffset = _offset;
                                _focalPoint = details.focalPoint;
                              });
                            },
                            onScaleUpdate: (details) {
                              setState(() {
                                _scale = (_baseScale * details.scale).clamp(0.4, 6.0);
                                _offset = _baseOffset + (details.focalPoint - _focalPoint);
                              });
                            },
                            onScaleEnd: (details) {
                              setState(() {
                                _isInteracting = false;
                              });
                            },
                            child: Center(
                              child: Transform.translate(
                                offset: _offset,
                                child: Transform.rotate(
                                  angle: _quarterTurns * (math.pi / 2),
                                  child: Transform.scale(
                                    scale: _scale,
                                    child: SizedBox(
                                      width: _initWidth,
                                      height: _initHeight,
                                      child: RawImage(
                                        image: _rawImage,
                                        fit: BoxFit.fill,
                                        filterQuality: FilterQuality.medium,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        // 2. WhatsApp dark mask with circular / square hole & 3x3 grid
                        Positioned.fill(
                          bottom: 110,
                          child: IgnorePointer(
                            child: CustomPaint(
                              painter: CropOverlayPainter(
                                cropRect: cropRect,
                                isCircle: _isCircle,
                                showGrid: _isInteracting,
                              ),
                            ),
                          ),
                        ),

                        // 3. Top helper tip banner
                        Positioned(
                          top: 12,
                          left: 20,
                          right: 20,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.65),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.pinch, color: Colors.greenAccent, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _isCircle
                                        ? 'उंगली से फोटो ज़ूम (Pinch) व ड्रैग करके गोले में सेट करें'
                                        : 'उंगली से फोटो ज़ूम (Pinch) व ड्रैग करके फ्रेम में सेट करें',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // 4. Floating confirm button for direct action
                        Positioned(
                          right: 20,
                          bottom: 125,
                          child: FloatingActionButton.extended(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            elevation: 4,
                            icon: const Icon(Icons.check, size: 20),
                            label: const Text('हो गया (Done)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            onPressed: () => _handleConfirmCrop(cropRect, Size(viewportWidth, viewportHeight)),
                          ),
                        ),

                        // 5. Bottom WhatsApp-Style Control Panel
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            height: 110,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: const BoxDecoration(
                              color: Color(0xFF161B22),
                              border: Border(top: BorderSide(color: Colors.white12)),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Zoom Slider
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.zoom_out, color: Colors.white70, size: 20),
                                      tooltip: 'ज़ूम आउट',
                                      onPressed: _zoomOut,
                                    ),
                                    Expanded(
                                      child: SliderTheme(
                                        data: SliderTheme.of(context).copyWith(
                                          activeTrackColor: Colors.greenAccent,
                                          inactiveTrackColor: Colors.white24,
                                          thumbColor: Colors.greenAccent,
                                          overlayColor: Colors.greenAccent.withValues(alpha: 0.2),
                                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                                          trackHeight: 3,
                                        ),
                                        child: Slider(
                                          value: _scale.clamp(0.4, 5.0),
                                          min: 0.4,
                                          max: 5.0,
                                          onChanged: (v) => setState(() => _scale = v),
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.zoom_in, color: Colors.white70, size: 20),
                                      tooltip: 'ज़ूम इन',
                                      onPressed: _zoomIn,
                                    ),
                                  ],
                                ),
                                // Action Toolbar (Rotate, Reset, Shape)
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    TextButton.icon(
                                      icon: const Icon(Icons.rotate_left, color: Colors.white, size: 18),
                                      label: const Text('बाएं', style: TextStyle(color: Colors.white, fontSize: 11)),
                                      onPressed: _rotateLeft,
                                    ),
                                    TextButton.icon(
                                      icon: const Icon(Icons.refresh, color: Colors.white70, size: 18),
                                      label: const Text('रीसेट', style: TextStyle(color: Colors.white70, fontSize: 11)),
                                      onPressed: _resetTransform,
                                    ),
                                    TextButton.icon(
                                      icon: const Icon(Icons.rotate_right, color: Colors.white, size: 18),
                                      label: const Text('दाएं', style: TextStyle(color: Colors.white, fontSize: 11)),
                                      onPressed: _rotateRight,
                                    ),
                                    TextButton.icon(
                                      icon: Icon(_isCircle ? Icons.crop_square : Icons.circle_outlined, color: Colors.white70, size: 18),
                                      label: Text(_isCircle ? 'चौकोर' : 'गोलाकार', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                                      onPressed: () => setState(() => _isCircle = !_isCircle),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
    );
  }
}

/// CustomPainter that renders:
/// 1. Translucent dark overlay with a circular or square cut-out hole
/// 2. Crisp boundary border (width: 2.0)
/// 3. WhatsApp 3x3 Rule-of-Thirds alignment grid clipped to inside the frame
class CropOverlayPainter extends CustomPainter {
  final Rect cropRect;
  final bool isCircle;
  final bool showGrid;
  final Color overlayColor;
  final Color borderColor;
  final Color gridColor;

  CropOverlayPainter({
    required this.cropRect,
    this.isCircle = true,
    this.showGrid = true,
    this.overlayColor = const Color(0xB8000000), // ~72% dark overlay
    this.borderColor = Colors.white,
    this.gridColor = const Color(0x66FFFFFF), // ~40% white grid lines
  });

  @override
  void paint(Canvas canvas, Size size) {
    final screenRect = Offset.zero & size;

    // 1. Cut out hole in dark overlay using even-odd fill rule
    final path = Path()..addRect(screenRect);
    if (isCircle) {
      path.addOval(cropRect);
    } else {
      path.addRRect(RRect.fromRectAndRadius(cropRect, const Radius.circular(8)));
    }
    path.fillType = PathFillType.evenOdd;

    final overlayPaint = Paint()
      ..color = overlayColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, overlayPaint);

    // 2. Draw crisp border around crop area
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    if (isCircle) {
      canvas.drawOval(cropRect, borderPaint);
    } else {
      canvas.drawRRect(RRect.fromRectAndRadius(cropRect, const Radius.circular(8)), borderPaint);
    }

    // 3. Draw WhatsApp Rule-of-Thirds 3x3 grid
    if (showGrid) {
      final gridPaint = Paint()
        ..color = gridColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;

      final oneThirdW = cropRect.width / 3;
      final twoThirdW = cropRect.width * 2 / 3;
      final oneThirdH = cropRect.height / 3;
      final twoThirdH = cropRect.height * 2 / 3;

      canvas.save();
      if (isCircle) {
        canvas.clipPath(Path()..addOval(cropRect));
      } else {
        canvas.clipRRect(RRect.fromRectAndRadius(cropRect, const Radius.circular(8)));
      }

      // Vertical lines
      canvas.drawLine(
        Offset(cropRect.left + oneThirdW, cropRect.top),
        Offset(cropRect.left + oneThirdW, cropRect.bottom),
        gridPaint,
      );
      canvas.drawLine(
        Offset(cropRect.left + twoThirdW, cropRect.top),
        Offset(cropRect.left + twoThirdW, cropRect.bottom),
        gridPaint,
      );

      // Horizontal lines
      canvas.drawLine(
        Offset(cropRect.left, cropRect.top + oneThirdH),
        Offset(cropRect.right, cropRect.top + oneThirdH),
        gridPaint,
      );
      canvas.drawLine(
        Offset(cropRect.left, cropRect.top + twoThirdH),
        Offset(cropRect.right, cropRect.top + twoThirdH),
        gridPaint,
      );

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CropOverlayPainter oldDelegate) {
    return oldDelegate.cropRect != cropRect ||
        oldDelegate.isCircle != isCircle ||
        oldDelegate.showGrid != showGrid;
  }
}
