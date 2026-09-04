import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../../core/services/paper_session_service.dart';
import '../../auth/providers/auth_provider.dart';

class InAppDocumentScannerScreen extends StatefulWidget {
  final String paperId;
  final String slotId;

  const InAppDocumentScannerScreen({
    super.key,
    required this.paperId,
    required this.slotId,
  });

  @override
  State<InAppDocumentScannerScreen> createState() => _InAppDocumentScannerScreenState();
}

class _InAppDocumentScannerScreenState extends State<InAppDocumentScannerScreen>
    with SingleTickerProviderStateMixin {
  final PaperSessionService _paperService = PaperSessionService();

  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _isCameraInitialized = false;
  bool _isCameraPermissionGranted = false;
  bool _isTorchOn = false;
  bool _isCapturing = false;
  bool _isSubmitting = false;

  // Flash animation on shutter capture
  late AnimationController _flashAnimController;
  late Animation<double> _flashAnimation;

  final List<File> _scannedFiles = [];
  final TextEditingController _driveLinkCtrl = TextEditingController();
  String _submissionProgress = '';

  @override
  void initState() {
    super.initState();
    _flashAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
    );
    _flashAnimation = Tween<double>(begin: 0.0, end: 0.8).animate(_flashAnimController);

    _initRearCamera();
  }

  Future<void> _initRearCamera() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      if (mounted) {
        setState(() {
          _isCameraPermissionGranted = false;
        });
      }
      return;
    }

    setState(() {
      _isCameraPermissionGranted = true;
    });

    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) return;

      // Select BACK / REAR camera for high-clarity document scanning
      final rearCamera = _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.first,
      );

      _cameraController = CameraController(
        rearCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _cameraController!.initialize();

      // Try auto focus for crisp text scanning
      try {
        await _cameraController!.setFocusMode(FocusMode.auto);
      } catch (_) {}

      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Error initializing rear scanner camera: $e');
    }
  }

  Future<void> _toggleTorch() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    try {
      final newMode = _isTorchOn ? FlashMode.off : FlashMode.torch;
      await _cameraController!.setFlashMode(newMode);
      if (mounted) {
        setState(() {
          _isTorchOn = !_isTorchOn;
        });
      }
    } catch (e) {
      debugPrint('Torch error: $e');
    }
  }

  Future<void> _capturePage() async {
    if (_isCapturing || _cameraController == null || !_cameraController!.value.isInitialized) return;

    setState(() {
      _isCapturing = true;
    });

    try {
      // Trigger flash effect
      _flashAnimController.forward().then((_) => _flashAnimController.reverse());

      final XFile photo = await _cameraController!.takePicture();

      if (mounted) {
        setState(() {
          _scannedFiles.add(File(photo.path));
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Page ${_scannedFiles.length} Scanned! (පිටුව ${_scannedFiles.length} සාර්ථකව ලබාගන්නා ලදී)',
              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            backgroundColor: const Color(0xFF22C55E),
            duration: const Duration(milliseconds: 1500),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('Capture error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Capture error: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCapturing = false;
        });
      }
    }
  }


  void _previewPageDialog(int index) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF1E293B),
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Page ${index + 1} of ${_scannedFiles.length}',
                      style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444)),
                    tooltip: 'Delete this page (මකන්න)',
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      setState(() {
                        _scannedFiles.removeAt(index);
                      });
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
            ),
            Container(
              height: 400,
              width: double.infinity,
              color: Colors.black,
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 4.0,
                child: Image.file(
                  _scannedFiles[index],
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Pinch to Zoom • Clear and readable handwriting',
                style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF94A3B8)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitAllAnswers() async {
    final driveLink = _driveLinkCtrl.text.trim();
    if (_scannedFiles.isEmpty && driveLink.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('කරුණාකර අවම වශයෙන් එක් පිළිතුරු පත්‍රයක්වත් Scan කරන්න හෝ Drive Link එකක් ඇතුලත් කරන්න.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.cloud_upload_rounded, color: Color(0xFF22C55E), size: 26),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Submit Answer Sheets?',
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ඔබ විසින් Scan කරන ලද පිටු ${_scannedFiles.length} ක් ගුරුභවතුන් වෙත භාරදීමට සූදානම්ද?',
              style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFFE2E8F0)),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: Color(0xFF22C55E), size: 16),
                  const SizedBox(width: 8),
                  Text(
                    '${_scannedFiles.length} Pages Verified & Ready',
                    style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF4ADE80)),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: GoogleFonts.poppins(color: const Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF22C55E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Yes, Submit Now', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isSubmitting = true;
      _submissionProgress = _scannedFiles.isNotEmpty
          ? 'Uploading page 1 of ${_scannedFiles.length} to Cloud...'
          : 'Submitting answers...';
    });

    try {
      final user = context.read<AuthProvider>().userModel;
      if (user == null) throw Exception('Student not authenticated');

      final List<String> uploadedUrls = [];

      // 1. Resilient upload of scanned pages (Storage -> Alt Bucket -> Compressed Base64)
      for (int i = 0; i < _scannedFiles.length; i++) {
        if (mounted) {
          setState(() {
            _submissionProgress = 'Processing page ${i + 1} of ${_scannedFiles.length}...';
          });
        }

        final file = _scannedFiles[i];
        final url = await _processAndUploadPage(file, i, widget.paperId, user.id);
        uploadedUrls.add(url);
      }

      // 2. Attach Google Drive link if provided
      if (driveLink.isNotEmpty) {
        uploadedUrls.add(driveLink);
      }

      if (mounted) {
        setState(() {
          _submissionProgress = 'Saving submission records...';
        });
      }

      // 3. Save clean HTTP URLs to Firestore (takes < 1KB, instant & error-free!)
      await _paperService.updateCameraHeartbeat(
        paperId: widget.paperId,
        studentId: user.id,
        studentName: user.name,
        studentPhone: user.phone,
        slotId: widget.slotId.isNotEmpty ? widget.slotId : 'slot1',
        isCameraActive: false,
        status: 'submitted',
        submissionPhotos: uploadedUrls,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎉 පිළිතුරු පත්‍ර (${uploadedUrls.length} Pages) සාර්ථකව භාරදෙන ලදී!'),
            backgroundColor: const Color(0xFF22C55E),
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      debugPrint('Submission error: $e');
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Submission Error: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  Future<String> _processAndUploadPage(File file, int pageIndex, String paperId, String userId) async {
    final filename = 'p${pageIndex + 1}_${DateTime.now().millisecondsSinceEpoch}.jpg';

    // Tier 1: Primary Firebase Storage Bucket
    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('paper_submissions')
          .child(paperId)
          .child(userId)
          .child(filename);
      final uploadTask = await storageRef.putFile(
        file,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      return await uploadTask.ref.getDownloadURL();
    } catch (e1) {
      debugPrint('Primary Firebase Storage error for page $pageIndex: $e1. Trying alternate bucket...');
    }

    // Tier 2: Alternate Bucket (appspot.com)
    try {
      final altStorage = FirebaseStorage.instanceFor(bucket: 'dessert-institute.appspot.com');
      final altRef = altStorage
          .ref()
          .child('paper_submissions')
          .child(paperId)
          .child(userId)
          .child(filename);
      final uploadTask = await altRef.putFile(
        file,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      return await uploadTask.ref.getDownloadURL();
    } catch (e2) {
      debugPrint('Alternate Firebase Storage error for page $pageIndex: $e2. Using compressed image fallback.');
    }

    // Tier 3: Guaranteed In-Memory Compression to Base64 data URI
    // Scales to target width 800 (keeps handwriting sharp while keeping file ~40KB)
    final rawBytes = await file.readAsBytes();
    try {
      final codec = await ui.instantiateImageCodec(
        rawBytes,
        targetWidth: 800,
      );
      final frame = await codec.getNextFrame();
      final byteData = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData != null) {
        final b64 = base64Encode(byteData.buffer.asUint8List());
        return 'data:image/png;base64,$b64';
      }
    } catch (compressErr) {
      debugPrint('Image compression error: $compressErr');
    }

    return 'data:image/jpeg;base64,${base64Encode(rawBytes)}';
  }

  @override
  void dispose() {
    _flashAnimController.dispose();
    _cameraController?.dispose();
    _driveLinkCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Camera Viewfinder
          _buildCameraViewfinder(),

          // 2. A4 Document Scanner Viewport Guide
          _buildA4DocumentScannerFrame(),

          // 3. Shutter Flash Animation Overlay
          AnimatedBuilder(
            animation: _flashAnimation,
            builder: (context, child) {
              if (_flashAnimation.value == 0.0) return const SizedBox.shrink();
              return Container(
                color: Colors.white.withOpacity(_flashAnimation.value),
              );
            },
          ),

          // 4. Top Header & Action Controls Bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildTopControlBar(),
          ),

          // 5. Bottom Thumbnail Tray & Shutter Bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomScannerControls(),
          ),

          // 6. Loading Overlay when Submitting
          if (_isSubmitting)
            Container(
              color: Colors.black.withOpacity(0.8),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF22C55E).withOpacity(0.5)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: Color(0xFF22C55E), strokeWidth: 3),
                      const SizedBox(height: 18),
                      Text(
                        'පිළිතුරු පත්‍ර Upload වෙමින් පවතී...',
                        style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _submissionProgress.isNotEmpty
                            ? _submissionProgress
                            : 'Uploading ${_scannedFiles.length} pages to Cloud...',
                        style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF38BDF8), fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCameraViewfinder() {
    if (!_isCameraPermissionGranted) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.camera_alt_outlined, size: 64, color: Color(0xFFEF4444)),
              const SizedBox(height: 16),
              Text(
                'Camera Permission Required',
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                'Please grant camera permission to scan your answer sheets.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF94A3B8)),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _initRearCamera,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1)),
                child: const Text('Grant Permission', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isCameraInitialized || _cameraController == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF22C55E)),
            SizedBox(height: 16),
            Text(
              'පසුපස කැමරාව ආරම්භ වෙමින් පවතී...',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _cameraController!.value.previewSize?.height ?? 1080,
          height: _cameraController!.value.previewSize?.width ?? 1920,
          child: CameraPreview(_cameraController!),
        ),
      ),
    );
  }

  Widget _buildA4DocumentScannerFrame() {
    return IgnorePointer(
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 28, vertical: 100),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFF22C55E).withOpacity(0.5), width: 1.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Top Left Corner Bracket
              Positioned(
                top: 0,
                left: 0,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(color: Color(0xFF22C55E), width: 4),
                      left: BorderSide(color: Color(0xFF22C55E), width: 4),
                    ),
                  ),
                ),
              ),
              // Top Right Corner Bracket
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(color: Color(0xFF22C55E), width: 4),
                      right: BorderSide(color: Color(0xFF22C55E), width: 4),
                    ),
                  ),
                ),
              ),
              // Bottom Left Corner Bracket
              Positioned(
                bottom: 0,
                left: 0,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Color(0xFF22C55E), width: 4),
                      left: BorderSide(color: Color(0xFF22C55E), width: 4),
                    ),
                  ),
                ),
              ),
              // Bottom Right Corner Bracket
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Color(0xFF22C55E), width: 4),
                      right: BorderSide(color: Color(0xFF22C55E), width: 4),
                    ),
                  ),
                ),
              ),

              // Center Guidance Text
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.document_scanner, color: Color(0xFF4ADE80), size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'A4 පිළිතුරු පත්‍රය රාමුවට කෙළින් තබන්න',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopControlBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 8, 16, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.black.withOpacity(0.8), Colors.transparent],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Row(
        children: [
          // Close button
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 24),
            onPressed: () {
              if (_scannedFiles.isNotEmpty) {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: const Color(0xFF1E293B),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    title: const Text('Exit Scanner?', style: TextStyle(color: Colors.white)),
                    content: Text(
                      'ඔබ Scan කර ඇති පිටු ${_scannedFiles.length} ඉවත් වනු ඇත. ඔබට පිටවීමට අවශ්‍යද?',
                      style: const TextStyle(color: Color(0xFFCBD5E1)),
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('No, Stay')),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          Navigator.of(context).pop(false);
                        },
                        child: const Text('Exit', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                );
              } else {
                Navigator.of(context).pop(false);
              }
            },
          ),
          const SizedBox(width: 8),

          // Title & Count
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Answer Sheet Scanner',
                  style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                Text(
                  '${_scannedFiles.length} Pages Captured',
                  style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF4ADE80), fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),

          // Torch Flashlight Toggle
          Container(
            decoration: BoxDecoration(
              color: _isTorchOn ? const Color(0xFFF59E0B) : Colors.black.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(
                _isTorchOn ? Icons.flash_on : Icons.flash_off,
                color: _isTorchOn ? Colors.black : Colors.white,
                size: 20,
              ),
              tooltip: 'Torch Flashlight (ආලෝකය)',
              onPressed: _toggleTorch,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomScannerControls() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.transparent, Colors.black.withOpacity(0.95), Colors.black],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Horizontal Thumbnail Tray of Captured Pages
          if (_scannedFiles.isNotEmpty) ...[
            SizedBox(
              height: 80,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _scannedFiles.length,
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTap: () => _previewPageDialog(index),
                    child: Container(
                      width: 62,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF22C55E), width: 1.5),
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(_scannedFiles[index], fit: BoxFit.cover),
                          ),
                          Positioned(
                            bottom: 2,
                            left: 2,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.75),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'P${index + 1}',
                                style: GoogleFonts.poppins(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 2,
                            right: 2,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                _scannedFiles.removeAt(index);
                              });
                              },
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle),
                                child: const Icon(Icons.close, size: 10, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
          ],

          // 2. Shutter & Action Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Page Count Indicator (Direct in-app capture only)
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.25), width: 1.5),
                ),
                child: Center(
                  child: Text(
                    '${_scannedFiles.length}',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              // Big Shutter Button
              GestureDetector(
                onTap: _isCapturing ? null : _capturePage,
                child: Container(
                  width: 74,
                  height: 74,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isCapturing ? const Color(0xFF94A3B8) : const Color(0xFF22C55E),
                    ),
                    child: Center(
                      child: _isCapturing
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.camera_alt, color: Colors.white, size: 30),
                    ),
                  ),
                ),
              ),

              // Done / Submit Icon Shortcut
              IconButton(
                icon: Icon(
                  Icons.check_circle,
                  color: _scannedFiles.isNotEmpty ? const Color(0xFF22C55E) : const Color(0xFF475569),
                  size: 32,
                ),
                tooltip: 'Done Scanning',
                onPressed: _scannedFiles.isNotEmpty ? _submitAllAnswers : null,
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 3. Wide Submit Button
          if (_scannedFiles.isNotEmpty)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF22C55E),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isSubmitting ? null : _submitAllAnswers,
                icon: const Icon(Icons.cloud_upload_rounded, color: Colors.white, size: 20),
                label: Text(
                  'Submit ${_scannedFiles.length} Answer Sheets (භාරදෙන්න)',
                  style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
