import 'package:fast_barcode_scanner/fast_barcode_scanner.dart';
import 'package:fast_barcode_scanner_platform_interface/fast_barcode_scanner_platform_interface.dart';
import 'package:flutter/material.dart';
import 'material_finder_painter.dart';

/// Mimics the official Material Design Barcode Scanner
/// (https://material.io/design/machine-learning/barcode-scanning.html)
///
class MaterialPreviewOverlay extends StatefulWidget {
  /// Creates a material barcode overlay.
  ///
  /// * `showSensing` animates the finder border.
  /// (Increased cpu usage confirmed on iOS when enabled)
  ///
  /// * `aspectRatio` of the finder border.
  ///
  const MaterialPreviewOverlay({
    super.key,
    required this.rectOfInterest,
    this.showSensing = false,
    this.sensingColor = Colors.white,
    this.backgroundColor = Colors.black38,
    this.cutOutBorderColor = Colors.black87,
    this.onScan,
    this.onScannedBoundsColor,
  });

  final bool showSensing;
  final Color? backgroundColor;
  final Color sensingColor;
  final Color cutOutBorderColor;
  final Color? Function(List<Barcode> scannedCodes)? onScannedBoundsColor;
  final RectOfInterest rectOfInterest;
  final OnDetectionHandler? onScan;

  @override
  State createState() {
    if (!showSensing)
      return StaticMaterialPreviewOverlayState();
    else
      return MaterialPreviewOverlayState();
  }
}

class StaticMaterialPreviewOverlayState extends State<MaterialPreviewOverlay> {
  List<Barcode> _filteredBarcodes = [];

  @override
  void initState() {
    super.initState();
    CameraController.shared.scannedBarcodes.addListener(_onBarcodesDetected);
  }

  @override
  void dispose() {
    super.dispose();
    CameraController.shared.scannedBarcodes.removeListener(_onBarcodesDetected);
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = widget.onScannedBoundsColor?.call(_filteredBarcodes) ??
        widget.cutOutBorderColor;

    final defaultBorderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..color = borderColor;

    return RepaintBoundary(
      child: SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              painter: MaterialFinderPainter(
                borderPaint: defaultBorderPaint,
                backgroundColor: widget.backgroundColor,
                rectOfInterest: widget.rectOfInterest,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onBarcodesDetected() {
    final analysisSize = CameraController.shared.analysisSize;
    final previewSize = context.size;

    setState(() {
      if (analysisSize != null && previewSize != null) {
        _filteredBarcodes = CameraController.shared.scannedBarcodes.value
            .where(widget.rectOfInterest.buildCodeFilter(
              analysisSize: analysisSize,
              previewSize: previewSize,
            ))
            .toList();
      } else {
        _filteredBarcodes = [];
      }
    });
  }
}

class MaterialPreviewOverlayState extends State<MaterialPreviewOverlay>
    with SingleTickerProviderStateMixin {
  List<Barcode> _filteredCodes = [];

  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  late Animation<double> _inflateAnimation;

  @override
  void initState() {
    super.initState();

    const fadeIn = 20.0;
    const wait = 2.0;
    const expand = 25.0;

    _controller = AnimationController(
      duration: const Duration(milliseconds: 1100),
      vsync: this,
    );

    final opacitySequence = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: fadeIn),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: wait),
      TweenSequenceItem(
          tween: Tween(begin: 1.0, end: 0.0)
              .chain(CurveTween(curve: Curves.easeOutCubic)),
          weight: expand),
      // TweenSequenceItem(tween: ConstantTween(0.0), weight: wait),
    ]);

    final inflateSequence = TweenSequence([
      TweenSequenceItem(tween: ConstantTween(0.0), weight: fadeIn + wait),
      TweenSequenceItem(
          tween: Tween(begin: 0.0, end: 1.0)
              .chain(CurveTween(curve: Curves.easeOutCubic)),
          weight: expand),
      // TweenSequenceItem(tween: ConstantTween(0.0), weight: wait),
    ]);

    _opacityAnimation = opacitySequence.animate(_controller);
    _inflateAnimation = inflateSequence.animate(_controller);

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && _filteredCodes.isEmpty) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!mounted) return;
          _controller.forward(from: _controller.lowerBound);
        });
      }
    });

    _controller.forward();

    CameraController.shared.scannedBarcodes.addListener(_onCodesScanned);
  }

  @override
  void dispose() {
    CameraController.shared.scannedBarcodes.removeListener(_onCodesScanned);
    _controller.dispose();
    super.dispose();
  }

  void _onCodesScanned() {
    final analysisSize = CameraController.shared.analysisSize;
    final previewSize = context.size;

    setState(() {
      if (analysisSize != null && previewSize != null) {
        _filteredCodes = CameraController.shared.scannedBarcodes.value
            .where(widget.rectOfInterest.buildCodeFilter(
              analysisSize: analysisSize,
              previewSize: previewSize,
            ))
            .toList();
      } else {
        _filteredCodes = [];
      }
    });

    if (_filteredCodes.isEmpty) {
      _controller.forward();
    } else {
      widget.onScan?.call(_filteredCodes);
      _controller.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = widget.onScannedBoundsColor?.call(_filteredCodes) ??
        widget.cutOutBorderColor;

    final defaultBorderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..color = borderColor;

    final sensingBorderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5;

    return RepaintBoundary(
      child: SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              painter: MaterialFinderPainter(
                borderPaint: defaultBorderPaint,
                backgroundColor: widget.backgroundColor,
                rectOfInterest: widget.rectOfInterest,
              ),
            ),
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) => CustomPaint(
                foregroundPainter: MaterialFinderPainter(
                  inflate: _inflateAnimation.value,
                  opacity: _opacityAnimation.value,
                  sensingColor: widget.sensingColor,
                  borderPaint: sensingBorderPaint,
                  backgroundColor: widget.backgroundColor,
                  rectOfInterest: widget.rectOfInterest,
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
