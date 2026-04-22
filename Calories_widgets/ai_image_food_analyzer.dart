import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:permission_handler/permission_handler.dart';
import 'package:fitness2/utils/image_validator.dart';
import 'package:fitness2/services/firebase_functions_service.dart';
import 'package:fitness2/services/image_upload_service.dart';
import 'package:fitness2/Calories_widgets/voice_input_mixin.dart';
import '../features/extra/constants.dart';

/// AI Image Food Analyzer: capture photo, add optional text, analyze with AI.
/// Includes image compression, retry logic, and idempotency.
class AIImageFoodAnalyzer extends StatefulWidget {
  final Function(Map<String, dynamic> analysisResult) onAnalysisComplete;

  const AIImageFoodAnalyzer({
    super.key,
    required this.onAnalysisComplete,
  });

  @override
  State<AIImageFoodAnalyzer> createState() => _AIImageFoodAnalyzerState();
}

class _AIImageFoodAnalyzerState extends State<AIImageFoodAnalyzer>
    with VoiceInputMixin, WidgetsBindingObserver {
  File? _imageFile;
  final TextEditingController _clarificationController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  
  // Analysis state
  bool _isAnalyzing = false;
  bool _hasAnalyzed = false;
  Map<String, dynamic>? _analysisResult;
  String? _errorMessage;

  // Request ID for idempotency
  String? _currentRequestId;

  // Live camera
  CameraController? _cameraController;
  bool _cameraReady = false;
  String? _cameraError;
  bool _isInitializingCamera = false;
  bool _appInBackground = false;
  bool _isCapturing = false;
  FlashMode _flashMode = FlashMode.off;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Lock screen to portrait so camera preview matches UI (avoids horizontal/weird preview)
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    _initCamera();
  }

  @override
  void dispose() {
    _disposeCamera();
    // Restore all orientations when leaving camera screen
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    if (_currentRequestId != null && !_hasAnalyzed) {
      ImageUploadService.deleteFoodImage(_currentRequestId!);
    }
    WidgetsBinding.instance.removeObserver(this);
    _clarificationController.dispose();
    super.dispose();
  }

  Future<void> _initCamera() async {
    if (_imageFile != null) return;
    if (_isInitializingCamera) return;
    setState(() {
      _isInitializingCamera = true;
      _cameraError = null;
      _cameraReady = false;
    });
    try {
      final status = await Permission.camera.status;
      if (!status.isGranted) {
        final result = await Permission.camera.request();
        if (!result.isGranted && mounted) {
          setState(() {
            _isInitializingCamera = false;
            _cameraError = 'Camera permission is required to scan food.';
          });
          return;
        }
      }
      if (!mounted) return;
      final cameras = await availableCameras();
      if (cameras.isEmpty || !mounted) {
        if (mounted) {
          setState(() {
            _isInitializingCamera = false;
            _cameraError = 'No camera found.';
          });
        }
        return;
      }
      final camera = cameras.first;
      final controller = CameraController(
        camera,
        ResolutionPreset.high,
        imageFormatGroup: ImageFormatGroup.jpeg,
        enableAudio: false,
      );
      await controller.initialize();
      await controller.lockCaptureOrientation(DeviceOrientation.portraitUp);
      await controller.setFlashMode(_flashMode);
      try {
        await controller.setFocusMode(FocusMode.auto);
      } catch (_) {}
      try {
        await controller.setExposureMode(ExposureMode.auto);
      } catch (_) {}
      if (!mounted) {
        controller.dispose();
        return;
      }
      // Do not assign if app is in background (e.g. init finished while paused)
      if (_appInBackground) {
        controller.dispose();
        if (mounted) {
          setState(() {
            _isInitializingCamera = false;
            _cameraError = 'Camera was paused. Tap Retry to use camera again.';
          });
        }
        return;
      }
      _cameraController?.dispose();
      _cameraController = controller;
      setState(() {
        _cameraReady = true;
        _isInitializingCamera = false;
        _cameraError = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInitializingCamera = false;
          _cameraError = 'Camera failed: ${e.toString().replaceFirst('Exception: ', '')}';
        });
      }
    }
  }

  void _disposeCamera() {
    _cameraController?.dispose();
    _cameraController = null;
    _cameraReady = false;
    _flashMode = FlashMode.off;
  }

  Future<void> _toggleFlash() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;
    final nextMode = _flashMode == FlashMode.off
        ? FlashMode.auto
        : _flashMode == FlashMode.auto
            ? FlashMode.torch
            : FlashMode.off;
    try {
      await controller.setFlashMode(nextMode);
      if (mounted) setState(() => _flashMode = nextMode);
    } catch (_) {}
  }

  IconData get _flashIcon {
    switch (_flashMode) {
      case FlashMode.auto:
        return Icons.flash_auto;
      case FlashMode.torch:
      case FlashMode.always:
        return Icons.flash_on;
      default:
        return Icons.flash_off;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _appInBackground = true;
      if (_imageFile == null) {
        _disposeCamera();
        _isInitializingCamera = false;
      }
    } else if (state == AppLifecycleState.resumed) {
      _appInBackground = false;
      if (mounted && _imageFile == null && !_isInitializingCamera) {
        _initCamera();
      } else if (mounted) {
        setState(() {});
      }
    }
  }

  /// Generate a unique request ID for idempotency
  String _generateRequestId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(999999).toString().padLeft(6, '0');
    return '$timestamp-$random';
  }

  /// Capture from the live camera (shoot button).
  /// Disposing the camera immediately after takePicture() can cause a race on Android
  /// (Reply already submitted / Handler on dead thread). We defer dispose so native
  /// cleanup can finish before the controller is disposed.
  Future<void> _captureFromCamera() async {
    if (_isCapturing) return;
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;
    if (controller.value.isTakingPicture) return;
    setState(() => _isCapturing = true);
    try {
      final XFile xFile = await controller.takePicture();
      if (!mounted) return;
      final file = File(xFile.path);
      final validationError = ImageValidator.validateImageFile(file);
      if (validationError != null) {
        _showError(validationError);
        _isCapturing = false;
        _deferDisposeCamera();
        return;
      }
      setState(() {
        _imageFile = file;
        _errorMessage = null;
        _currentRequestId = _generateRequestId();
      });
      _deferDisposeCamera();
    } catch (e) {
      if (mounted) {
        _showError('Failed to take photo: $e');
        _deferDisposeCamera();
        setState(() {
          _cameraError = 'Camera error. Tap Retry to try again.';
          _isInitializingCamera = false;
        });
      }
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  /// Dispose camera after a short delay so native Android callbacks can complete
  /// and the plugin does not hit "Reply already submitted" or dead-handler errors.
  /// Only disposes the controller that was used for this capture; if the user
  /// already took another photo or tapped "Retake" and re-inited, we do not touch
  /// the new controller (avoid crash when taking second photo).
  void _deferDisposeCamera() {
    final controllerToDispose = _cameraController;
    if (controllerToDispose == null) return;
    Future.delayed(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      if (_cameraController != controllerToDispose) {
        // User re-initialized (e.g. Retake / second photo); old controller was
        // already disposed in _initCamera. Do not dispose current controller.
        return;
      }
      _disposeCamera();
    });
  }

  /// Pick image from gallery (gallery button).
  Future<void> _pickFromGallery() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 85,
      );
      if (!mounted) return;
      if (pickedFile == null) return;
      final file = File(pickedFile.path);
      final validationError = ImageValidator.validateImageFile(file);
      if (validationError != null) {
        _showError(validationError);
        return;
      }
      setState(() {
        _imageFile = file;
        _errorMessage = null;
        _currentRequestId = _generateRequestId();
      });
      _disposeCamera();
    } catch (e) {
      _showError('Failed to pick image: $e');
    }
  }

  /// Size under which we skip compression (already small enough).
  static const int _skipCompressFileSizeBytes = 500 * 1024; // 500 KB

  Future<File> _compressImage(File file) async {
    try {
      // Read image
      final bytes = await file.readAsBytes();
      final image = img.decodeImage(bytes);

      if (image == null) {
        throw Exception('Failed to decode image');
      }

      // If image is already too small per validator, skip compression and use original
      if (image.width < ImageValidator.minWidth || image.height < ImageValidator.minHeight) {
        return file;
      }

      // If image is already small (no resize needed and file size modest), skip compression
      final fileSize = await file.length();
      if (image.width <= 1024 &&
          image.height <= 1024 &&
          fileSize <= _skipCompressFileSizeBytes) {
        return file;
      }

      // Validate dimensions (too large)
      final dimensionError = ImageValidator.validateImageDimensions(
        image.width,
        image.height,
      );
      if (dimensionError != null) {
        throw Exception(dimensionError);
      }

      // Resize if too large (max 1024x1024 — keeps enough detail for food AI)
      img.Image resized = image;
      if (image.width > 1024 || image.height > 1024) {
        resized = img.copyResize(
          image,
          width: image.width > image.height ? 1024 : null,
          height: image.height > image.width ? 1024 : null,
        );
      }

      // Compress as JPEG (quality 80)
      final compressed = img.encodeJpg(resized, quality: 80);

      // Save to temp file
      final tempDir = await Directory.systemTemp.createTemp('food_img_');
      final tempFile = File('${tempDir.path}/compressed.jpg');
      await tempFile.writeAsBytes(compressed);

      return tempFile;
    } catch (e) {
      throw Exception('Image compression failed: $e');
    }
  }

  Future<String> _uploadImageToStorage(File file) async {
    return await ImageUploadService.uploadFoodImage(file, _currentRequestId!);
  }

  Future<void> _analyzeImage() async {
    if (_imageFile == null || _currentRequestId == null) return;
    if (_isAnalyzing || _hasAnalyzed) return;

    setState(() {
      _isAnalyzing = true;
      _errorMessage = null;
    });

    try {
      // Compress image (or use original if already small)
      final compressedFile = await _compressImage(_imageFile!);

      // Upload to Firebase Storage
      final imageUrl = await _uploadImageToStorage(compressedFile);

      // Delete temp compressed file only when it was actually created (not the original)
      if (compressedFile.path != _imageFile!.path) {
        await compressedFile.delete();
      }

      // Call Cloud Function
      final result = await FirebaseFunctionsService.analyzeFoodImage(
        imageUrl: imageUrl,
        clarificationText: _clarificationController.text.trim(),
        requestId: _currentRequestId!,
      );

      if (result == null) {
        throw Exception('No response from AI service');
      }

      if (result['error'] != null) {
        throw Exception(result['error']);
      }

      setState(() {
        _isAnalyzing = false;
        _hasAnalyzed = true;
        _analysisResult = result;
      });
    } catch (e) {
      setState(() {
        _isAnalyzing = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _retryAnalysis() async {
    setState(() {
      _errorMessage = null;
    });

    await _analyzeImage();
  }

  void _addToLog() {
    if (_analysisResult == null || !_hasAnalyzed) return;
    
    // Disable further adds (idempotency)
    widget.onAnalysisComplete(_analysisResult!);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A192F),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Scan Food Photo',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: _imageFile == null
          ? _buildCaptureView()
          : _buildPreviewView(),
    );
  }

  Widget _buildCaptureView() {
    if (_cameraError != null) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(32.r),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, color: Colors.white70, size: 48),
                SizedBox(height: 16.rh),
                Text(
                  _cameraError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                ),
                SizedBox(height: 24.rh),
                TextButton.icon(
                  onPressed: _initCamera,
                  icon: const Icon(Icons.refresh, color: Color(0xFF4895EF)),
                  label: const Text('Retry', style: TextStyle(color: Color(0xFF4895EF))),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final controller = _cameraController;
    if (_isInitializingCamera || !_cameraReady || controller == null || !controller.value.isInitialized) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4361EE)),
          ),
        ),
      );
    }
    final ratio = controller.value.aspectRatio;
    final safeRatio = ratio > 0 ? ratio : 3 / 4;
    return Stack(
      fit: StackFit.expand,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final h = constraints.maxHeight;
            double previewW = w;
            double previewH = h;
            if (w / h > safeRatio) {
              previewW = h * safeRatio;
            } else {
              previewH = w / safeRatio;
            }
            return Center(
              child: SizedBox(
                width: previewW,
                height: previewH,
                child: CameraPreview(controller),
              ),
            );
          },
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 32.rw, vertical: 24.rh),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Semantics(
                    label: 'Pick from gallery',
                    button: true,
                    child: IconButton(
                      onPressed: _pickFromGallery,
                      icon: const Icon(Icons.photo_library, color: Colors.white, size: 32),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black45,
                        padding: EdgeInsets.all(16.r),
                      ),
                    ),
                  ),
                  Semantics(
                    label: 'Take photo',
                    button: true,
                    child: GestureDetector(
                      onTap: _isCapturing ? null : _captureFromCamera,
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                          color: _isCapturing
                              ? Colors.white.withOpacity(0.5)
                              : Colors.white.withOpacity(0.2),
                        ),
                        child: _isCapturing
                            ? const Padding(
                                padding: EdgeInsets.all(18),
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Icon(Icons.camera_alt, color: Colors.white, size: 36),
                      ),
                    ),
                  ),
                  Semantics(
                    label: 'Toggle flash',
                    button: true,
                    child: IconButton(
                      onPressed: _toggleFlash,
                      icon: Icon(_flashIcon, color: Colors.white, size: 32),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black45,
                        padding: EdgeInsets.all(16.r),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewView() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0A192F), Colors.black],
        ),
      ),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(24.r),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Optional clarification text – above image so users see it without scrolling
                  if (!_hasAnalyzed) ...[
                    const Text(
                      'Add Details (Optional)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 12.rh),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                      child: Stack(
                        children: [
                          TextField(
                            controller: _clarificationController,
                            maxLines: 3,
                            style: const TextStyle(color: Colors.white, fontSize: 15),
                            decoration: InputDecoration(
                              hintText: 'e.g., "Large portion", "No sauce", "Extra cheese"...',
                              hintStyle: TextStyle(
                                color: Colors.white.withOpacity(0.4),
                                fontSize: 14,
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.fromLTRB(16.rw, 16.rh, 56.rw, 16.rh),
                            ),
                            enabled: !_isAnalyzing,
                          ),
                          Positioned(
                            right: 8,
                            top: 8,
                            child: buildVoiceMicButton(
                              controller: _clarificationController,
                              iconColor: Colors.white70,
                              listeningColor: const Color(0xFF4361EE),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 24.rh),
                  ],
                  // Image preview
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.file(
                      _imageFile!,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  SizedBox(height: 24.rh),
                  // Retake button
                  if (!_isAnalyzing && !_hasAnalyzed)
                    Center(
                      child: TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _imageFile = null;
                            _clarificationController.clear();
                            _currentRequestId = null;
                          });
                          _initCamera();
                        },
                        icon: const Icon(Icons.refresh, color: Color(0xFF4895EF)),
                        label: const Text(
                          'Retake Photo',
                          style: TextStyle(
                            color: Color(0xFF4895EF),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  SizedBox(height: 24.rh),
                  // Error message
                  if (_errorMessage != null) ...[
                    Container(
                      padding: EdgeInsets.all(16.r),
                      decoration: BoxDecoration(
                        color: Colors.red.shade900.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.red.shade700.withOpacity(0.5),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red.shade400),
                          SizedBox(width: 12.rw),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(
                                color: Colors.red.shade300,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16.rh),
                  ],
                  // Analysis result
                  if (_hasAnalyzed && _analysisResult != null)
                    _buildAnalysisResult(),
                ],
              ),
            ),
          ),
          // Bottom action buttons
          _buildBottomActions(),
        ],
      ),
    );
  }

  Widget _buildAnalysisResult() {
    final foods = _analysisResult!['foods'] as List<dynamic>? ?? [];
    
    return Container(
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: const Color(0xFF4361EE).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF4361EE).withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle, color: Color(0xFF38B000), size: 24),
              SizedBox(width: 12.rw),
              const Text(
                'Analysis Complete',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.rh),
          Text(
            'Found ${foods.length} food item${foods.length != 1 ? 's' : ''}',
            style: TextStyle(
              fontSize: 15,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
          SizedBox(height: 12.rh),
          ...foods.map((food) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF4895EF),
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: 12.rw),
                    Expanded(
                      child: Text(
                        food['name'] ?? 'Unknown',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    Text(
                      '${food['calories'] ?? 0} cal',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildBottomActions() {
    return Container(
      padding: EdgeInsets.all(24.r),
      decoration: BoxDecoration(
        color: const Color(0xFF0A192F),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isAnalyzing) ...[
              // Analyzing state – upgraded look
              Container(
                padding: EdgeInsets.symmetric(vertical: 28.rh, horizontal: 24.rw),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF4361EE).withOpacity(0.15),
                      const Color(0xFF4895EF).withOpacity(0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF4361EE).withOpacity(0.25),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: const Color(0xFF4361EE).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4361EE)),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 20.rw),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Processing your food',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'AI is identifying items and calories…',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.65),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Usually under 60 seconds',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.45),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (_hasAnalyzed) ...[
              // Add to log button
              _buildActionButton(
                label: 'Add to Log',
                icon: Icons.check,
                onTap: _addToLog,
                isPrimary: true,
              ),
            ] else if (_errorMessage != null) ...[
              // Retry button (unlimited retries)
              _buildActionButton(
                label: 'Retry Analysis',
                icon: Icons.refresh,
                onTap: _retryAnalysis,
                isPrimary: true,
              ),
            ] else if (_errorMessage == null) ...[
              // Analyze button
              _buildActionButton(
                label: 'Analyze Food',
                icon: Icons.auto_awesome,
                onTap: _analyzeImage,
                isPrimary: true,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    required bool isPrimary,
  }) {
    return Semantics(
      label: label,
      button: true,
      child: GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 18.rh),
        decoration: BoxDecoration(
          gradient: isPrimary
              ? const LinearGradient(
                  colors: [Color(0xFF4361EE), Color(0xFF4895EF)],
                )
              : null,
          color: isPrimary ? null : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          boxShadow: isPrimary
              ? [
                  BoxShadow(
                    color: const Color(0xFF4361EE).withOpacity(0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 24),
            SizedBox(width: 12.rw),
            Text(
              label,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }
}
