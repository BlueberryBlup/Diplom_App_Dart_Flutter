// widgets/defect_marker_editor.dart
import 'dart:io';
import 'dart:ui' as ui;
import 'package:diplomgrinenko/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class DefectMarkerEditor extends StatefulWidget {
  final String imagePath;

  const DefectMarkerEditor({super.key, required this.imagePath});

  @override
  State<DefectMarkerEditor> createState() => _DefectMarkerEditorState();
}

class _DefectMarkerEditorState extends State<DefectMarkerEditor> {
  Offset? _relativePosition; 
  final GlobalKey _imageKey = GlobalKey();
  bool _isSaving = false;
  Size? _imageSize;

  @override
  void initState() {
    super.initState();
    _loadImageSize();
  }

  Future<void> _loadImageSize() async {
    final file = File(widget.imagePath);
    final bytes = await file.readAsBytes();
    final decodedImage = await decodeImageFromList(bytes);
    setState(() {
      _imageSize = Size(
        decodedImage.width.toDouble(),
        decodedImage.height.toDouble(),
      );
    });
  }

  Future<String?> _saveImageWithMarker(Offset relativePosition) async {
    try {
      final bytes = await File(widget.imagePath).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawImage(image, Offset.zero, Paint());

      // Конвертируем относительные координаты в абсолютные для рисования
      final absoluteX = relativePosition.dx * image.width;
      final absoluteY = relativePosition.dy * image.height;
      final markerPosition = Offset(absoluteX, absoluteY);

      final radius = (image.width * 0.02).clamp(20.0, 80.0);

      // Рисуем маркер
      final paint = Paint()
        ..color = AppTheme.redApp
        ..style = PaintingStyle.fill;
      canvas.drawCircle(markerPosition, radius, paint);

      final strokePaint = Paint()
        ..color = const Color(0xFFFFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4;
      canvas.drawCircle(markerPosition, radius, strokePaint);

      final picture = recorder.endRecording();
      final img = await picture.toImage(image.width, image.height);
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

      final tempDir = await getTemporaryDirectory();
      final outputPath =
          '${tempDir.path}/marked_${DateTime.now().millisecondsSinceEpoch}.png';
      await File(outputPath).writeAsBytes(byteData!.buffer.asUint8List());

      return outputPath;
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Отметить дефект', style: TextStyle(fontSize: 18)),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _isSaving
                ? null
                : () async {
                    if (_relativePosition != null) {
                      setState(() => _isSaving = true);
                      final savedPath = await _saveImageWithMarker(
                        _relativePosition!,
                      );
                      setState(() => _isSaving = false);
                      if (mounted && savedPath != null) {
                        Navigator.pop(context, savedPath);
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Сначала отметьте место дефекта'),
                        ),
                      );
                    }
                  },
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save, color: Colors.white, size: 25),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.blue.shade50,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.touch_app, color: Colors.blue),
                SizedBox(width: 8),
                Text('Нажмите на изображение', style: TextStyle(fontSize: 14)),
              ],
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return GestureDetector(
                  onTapDown: (details) {
                    if (_imageKey.currentContext == null) return;

                    final RenderBox box =
                        _imageKey.currentContext!.findRenderObject()
                            as RenderBox;
                    final Offset localPosition = box.globalToLocal(
                      details.globalPosition,
                    );

                    // Получаем размеры отображаемого изображения
                    final boxSize = box.size;
                    final imageSize = _imageSize;

                    if (imageSize == null) return;

                    // Вычисляем, как изображение вписано в контейнер
                    final imageAspect = imageSize.width / imageSize.height;
                    final containerAspect = boxSize.width / boxSize.height;

                    double renderWidth, renderHeight;
                    double offsetX = 0, offsetY = 0;

                    if (imageAspect > containerAspect) {
                      renderWidth = boxSize.width;
                      renderHeight = renderWidth / imageAspect;
                      offsetY = (boxSize.height - renderHeight) / 2;
                    } else {
                      renderHeight = boxSize.height;
                      renderWidth = renderHeight * imageAspect;
                      offsetX = (boxSize.width - renderWidth) / 2;
                    }

                    // Проверяем, что нажали на изображение
                    if (localPosition.dx >= offsetX &&
                        localPosition.dx <= offsetX + renderWidth &&
                        localPosition.dy >= offsetY &&
                        localPosition.dy <= offsetY + renderHeight) {
                      // Вычисляем относительные координаты (в процентах от 0 до 1)
                      final relativeX =
                          (localPosition.dx - offsetX) / renderWidth;
                      final relativeY =
                          (localPosition.dy - offsetY) / renderHeight;

                      final relativePosition = Offset(relativeX, relativeY);

                      setState(() {
                        _relativePosition = relativePosition;
                      });
                    }
                  },
                  child: Container(
                    key: _imageKey,
                    color: Colors.black12,
                    alignment: Alignment.center,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.file(File(widget.imagePath), fit: BoxFit.contain),
                        if (_relativePosition != null)
                          _buildMarker(constraints.biggest),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (_relativePosition != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton.icon(
                onPressed: () => setState(() => _relativePosition = null),

                label: const Text('Удалить отметку'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.redApp,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMarker(Size containerSize) {
    if (_imageSize == null) return const SizedBox();

    // Вычисляем позицию маркера на основе относительных координат
    final imageAspect = _imageSize!.width / _imageSize!.height;
    final containerAspect = containerSize.width / containerSize.height;

    double renderWidth, renderHeight;
    double offsetX = 0, offsetY = 0;

    if (imageAspect > containerAspect) {
      renderWidth = containerSize.width;
      renderHeight = renderWidth / imageAspect;
      offsetY = (containerSize.height - renderHeight) / 2;
    } else {
      renderHeight = containerSize.height;
      renderWidth = renderHeight * imageAspect;
      offsetX = (containerSize.width - renderWidth) / 2;
    }

    // Вычисляем экранные координаты
    final screenX = offsetX + (_relativePosition!.dx * renderWidth);
    final screenY = offsetY + (_relativePosition!.dy * renderHeight);

    return Positioned(
      left: screenX - 25,
      top: screenY - 25,
      child: IgnorePointer(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_on, color: AppTheme.redApp, size: 35),
          ],
        ),
      ),
    );
  }
}
