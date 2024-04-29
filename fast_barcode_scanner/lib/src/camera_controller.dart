import 'dart:async';

import 'package:fast_barcode_scanner_platform_interface/fast_barcode_scanner_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

import '../fast_barcode_scanner.dart';

class ScannerState {
  PreviewConfiguration? _previewConfig;
  ScannerConfiguration? _scannerConfig;
  bool _torch = false;
  Object? _error;

  PreviewConfiguration? get previewConfig => _previewConfig;

  ScannerConfiguration? get scannerConfig => _scannerConfig;

  bool get torchState => _torch;

  bool get isInitialized => _previewConfig != null;

  Object? get error => _error;
}

/// This class facilitates the communication with the platform interface.
/// It is purely for convinience. You can always use the
/// `FastBarcodeScannerPlatform` or `MethodChannelFastBarcodeScanner` yourself.
///
class CameraController {
  CameraController._internal() : super();

  static final _instance = CameraController._internal();

  factory CameraController() => _instance;

  StreamSubscription? _scanSilencerSubscription;

  final FastBarcodeScannerPlatform _platform =
      FastBarcodeScannerPlatform.instance;

  final state = ScannerState();

  final events = ValueNotifier(ScannerEvent.uninitialized);

  static const scannedCodeTimeout = Duration(milliseconds: 250);
  DateTime? _lastScanTime;

  ValueNotifier<List<Barcode>> scannedBarcodes = ValueNotifier([]);

  Size? get analysisSize {
    final previewConfig = state.previewConfig;
    if (previewConfig != null) {
      return Size(previewConfig.analysisWidth.toDouble(),
          previewConfig.analysisHeight.toDouble());
    }
    return null;
  }

  /// Indicates if the torch is currently switching.
  ///
  /// Used to prevent command-spamming.
  bool _togglingTorch = false;

  /// Indicates if the camera is currently configuring itself.
  ///
  /// Used to prevent command-spamming.
  bool _configuring = false;

  /// User-defined handler, called when a barcode is detected
  OnDetectionHandler? _onScan;

  /// Curried function for [_onScan]. This ensures that each scan receipt is done
  /// consistently. We log [_lastScanTime] and update the [scannedBarcodes] ValueNotifier
  OnDetectionHandler _buildScanHandler(OnDetectionHandler? onScan) {
    return (barcodes) {
      _lastScanTime = DateTime.now();
      scannedBarcodes.value = barcodes;
      onScan?.call(barcodes);
    };
  }

  Future<void> initialize({
    required List<BarcodeType> types,
    required Resolution resolution,
    required Framerate framerate,
    required CameraPosition position,
    required DetectionMode detectionMode,
    ApiMode? apiMode,
    OnDetectionHandler? onScan,
  }) async {
    try {
      state._previewConfig = await _platform.init(
        types,
        resolution,
        framerate,
        detectionMode,
        position,
        apiMode: apiMode,
      );

      _onScan = _buildScanHandler(onScan);
      _scanSilencerSubscription =
          Stream.periodic(scannedCodeTimeout).listen((event) {
        final scanTime = _lastScanTime;
        if (scanTime != null &&
            DateTime.now().difference(scanTime) > scannedCodeTimeout) {
          // it's been too long since we've seen a scanned code, clear the list
          scannedBarcodes.value = const <Barcode>[];
        }
      });

      _platform.setOnDetectHandler(_onDetectHandler);

      state._scannerConfig = ScannerConfiguration(
          types, resolution, framerate, position, detectionMode);

      state._error = null;

      events.value = ScannerEvent.resumed;
    } catch (error) {
      state._error = error;
      events.value = ScannerEvent.error;
      rethrow;
    }
  }

  Future<void> dispose() async {
    try {
      await _platform.dispose();
      state._scannerConfig = null;
      state._previewConfig = null;
      state._torch = false;
      state._error = null;
      events.value = ScannerEvent.uninitialized;
      _scanSilencerSubscription?.cancel();
    } catch (error) {
      state._error = error;
      events.value = ScannerEvent.error;
      rethrow;
    }
  }

  Future<void> pauseCamera() async {
    try {
      await _platform.stop();
      events.value = ScannerEvent.paused;
    } catch (error) {
      state._error = error;
      events.value = ScannerEvent.error;
      rethrow;
    }
  }

  Future<void> resumeCamera() async {
    try {
      await _platform.start();
      events.value = ScannerEvent.resumed;
    } catch (error) {
      state._error = error;
      events.value = ScannerEvent.error;
      rethrow;
    }
  }

  Future<void> pauseScanner() async {
    try {
      await _platform.stopDetector();
    } catch (error) {
      state._error = error;
      events.value = ScannerEvent.error;
      rethrow;
    }
  }

  Future<void> resumeScanner() async {
    try {
      await _platform.startDetector();
    } catch (error) {
      state._error = error;
      events.value = ScannerEvent.error;
      rethrow;
    }
  }

  Future<bool> toggleTorch() async {
    if (!_togglingTorch) {
      _togglingTorch = true;

      try {
        state._torch = await _platform.toggleTorch();
      } catch (error) {
        state._error = error;
        events.value = ScannerEvent.error;
        rethrow;
      }

      _togglingTorch = false;
    }

    return state._torch;
  }

  Future<void> configure({
    List<BarcodeType>? types,
    Resolution? resolution,
    Framerate? framerate,
    DetectionMode? detectionMode,
    CameraPosition? position,
    OnDetectionHandler? onScan,
  }) async {
    if (state.isInitialized && !_configuring) {
      final scannerConfig = state._scannerConfig!;
      _configuring = true;

      try {
        state._previewConfig = await _platform.changeConfiguration(
          types: types,
          resolution: resolution,
          framerate: framerate,
          detectionMode: detectionMode,
          position: position,
        );

        state._scannerConfig = scannerConfig.copyWith(
          types: types,
          resolution: resolution,
          framerate: framerate,
          detectionMode: detectionMode,
          position: position,
        );

        _onScan = _buildScanHandler(onScan);
      } catch (error) {
        state._error = error;
        events.value = ScannerEvent.error;
        rethrow;
      }

      _configuring = false;
    }
  }

  Future<List<Barcode>?> scanImage(ImageSource source) async {
    try {
      return _platform.scanImage(source);
    } catch (error) {
      state._error = error;
      events.value = ScannerEvent.error;
      rethrow;
    }
  }

  void _onDetectHandler(List<Barcode> codes) {
    events.value = ScannerEvent.detected;
    _onScan?.call(codes);
  }
}

class ScannedBarcodes {
  final List<Barcode> barcodes;
  final DateTime timestamp;

  ScannedBarcodes(this.barcodes) : timestamp = DateTime.now();

  ScannedBarcodes.none() : this([]);

  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScannedBarcodes &&
          runtimeType == other.runtimeType &&
          barcodes == other.barcodes &&
          timestamp == other.timestamp;

  int get hashCode => barcodes.hashCode ^ timestamp.hashCode;
}
