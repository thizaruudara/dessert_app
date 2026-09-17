import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:url_launcher/url_launcher.dart';

import '../../../core/models/dessert_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/haptic_feedback_service.dart';
import '../../../core/widgets/media_image_view.dart';
import '../../auth/providers/auth_provider.dart';
import '../../desserts/providers/desserts_provider.dart';

// Official EduPeak Telegram Bot constants
const String kInstituteTelegramBot = 'edupeakbot';
const String kInstituteTelegramName = 'EduPeak AI Tutor (@edupeakbot)';

class StudentSubmitGuideScreen extends StatefulWidget {
  final int initialTabIndex;

  const StudentSubmitGuideScreen({super.key, this.initialTabIndex = 0});

  @override
  State<StudentSubmitGuideScreen> createState() => _StudentSubmitGuideScreenState();
}

class _StudentSubmitGuideScreenState extends State<StudentSubmitGuideScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  final ImagePicker _picker = ImagePicker();

  // Form State
  final String _selectedSubject = 'Physics';
  final TextEditingController _captionController = TextEditingController();
  final List<File> _selectedPhotos = [];

  bool _isUploading = false;
  String _uploadStatusMessage = '';
  String _selectedFilter = 'All'; // 'All', 'Pending', 'Approved', 'Rejected'
  bool _showTelegramGuide = false;

  final List<String> _quickTopicTags = const [
    'Mechanics',
    'Waves & Optics',
    'Thermal Physics',
    'Electricity & Mag',
    'Modern Physics',
    'Unit Test',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 1),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.94, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initStudentDesserts();
    });
  }

  void _initStudentDesserts() {
    final user = context.read<AuthProvider>().userModel;
    if (user != null) {
      context.read<DessertsProvider>().listenToStudentDesserts(
            user.id,
            studentPhone: user.phone,
          );
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pulseController.dispose();
    _captionController.dispose();
    super.dispose();
  }

  // ──────────────── Photo Picking Methods ────────────────

  Future<void> _pickFromCamera() async {
    HapticFeedbackService.light();
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1800,
        maxHeight: 1800,
        imageQuality: 85,
      );

      if (photo != null) {
        setState(() {
          _selectedPhotos.add(File(photo.path));
        });
      }
    } catch (e) {
      debugPrint('Error capturing photo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open camera: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _pickFromGallery() async {
    HapticFeedbackService.light();
    try {
      final List<XFile> images = await _picker.pickMultiImage(
        maxWidth: 1800,
        maxHeight: 1800,
        imageQuality: 85,
      );

      if (images.isNotEmpty) {
        setState(() {
          _selectedPhotos.addAll(images.map((img) => File(img.path)));
        });
      }
    } catch (e) {
      debugPrint('Error picking images from gallery: $e');
      try {
        final XFile? single = await _picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 1800,
          maxHeight: 1800,
          imageQuality: 85,
        );
        if (single != null) {
          setState(() {
            _selectedPhotos.add(File(single.path));
          });
        }
      } catch (_) {}
    }
  }

  void _removePhoto(int index) {
    HapticFeedbackService.light();
    setState(() {
      _selectedPhotos.removeAt(index);
    });
  }

  void _clearForm() {
    setState(() {
      _captionController.clear();
      _selectedPhotos.clear();
      _isUploading = false;
      _uploadStatusMessage = '';
    });
  }

  void _insertQuickTag(String tag) {
    HapticFeedbackService.selection();
    final current = _captionController.text.trim();
    if (current.contains(tag)) return;
    if (current.isEmpty) {
      _captionController.text = '[$tag] ';
    } else {
      _captionController.text = '[$tag] $current';
    }
    _captionController.selection = TextSelection.fromPosition(
      TextPosition(offset: _captionController.text.length),
    );
    setState(() {});
  }

  void _previewPhotoDialog(File file, int index) {
    HapticFeedbackService.light();
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.9),
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Page ${index + 1} Preview',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: InteractiveViewer(
                      child: Image.file(
                        file,
                        fit: BoxFit.contain,
                        height: MediaQuery.of(context).size.height * 0.6,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────── Resilient Upload Logic ────────────────

  Future<String?> _uploadToTelegramCDN(File file, int index, String userId) async {
    const token = '8837234143:AAEFLrgpMuTa4bxwIxl-SDqAuOy4P_o7vtI';
    const chatId = '6516172480';

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 25);

    try {
      final uri = Uri.parse('https://api.telegram.org/bot$token/sendDocument');
      final request = await client.postUrl(uri);

      final boundary = '----Boundary${DateTime.now().millisecondsSinceEpoch}';
      request.headers.set('content-type', 'multipart/form-data; boundary=$boundary');

      final fileBytes = await file.readAsBytes();
      final fileName = 'dessert_${userId}_${DateTime.now().millisecondsSinceEpoch}_$index.jpg';
      final caption = '🍰 Homework: $_selectedSubject | Student: $userId | Page: ${index + 1}';

      final header = '--$boundary\r\n'
          'Content-Disposition: form-data; name="chat_id"\r\n\r\n'
          '$chatId\r\n'
          '--$boundary\r\n'
          'Content-Disposition: form-data; name="caption"\r\n\r\n'
          '$caption\r\n'
          '--$boundary\r\n'
          'Content-Disposition: form-data; name="document"; filename="$fileName"\r\n'
          'Content-Type: image/jpeg\r\n\r\n';

      final footer = '\r\n--$boundary--\r\n';

      request.add(utf8.encode(header));
      request.add(fileBytes);
      request.add(utf8.encode(footer));

      final response = await request.close().timeout(const Duration(seconds: 25));
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode == 200) {
        final json = jsonDecode(responseBody);
        if (json['ok'] == true) {
          final doc = json['result']['document'];
          final fileId = doc['file_id'];

          final getFileUri = Uri.parse('https://api.telegram.org/bot$token/getFile?file_id=$fileId');
          final getFileReq = await client.getUrl(getFileUri);
          final getFileRes = await getFileReq.close().timeout(const Duration(seconds: 15));
          final getFileBody = await getFileRes.transform(utf8.decoder).join();
          final getFileJson = jsonDecode(getFileBody);

          if (getFileJson['ok'] == true) {
            final filePath = getFileJson['result']['file_path'];
            return 'https://api.telegram.org/file/bot$token/$filePath';
          }
        }
      }
    } catch (e) {
      debugPrint('Telegram CDN upload failed for item $index: $e');
    } finally {
      client.close();
    }
    return null;
  }

  Future<String> _uploadSinglePhoto(File file, int index, String userId) async {
    try {
      final tgUrl = await _uploadToTelegramCDN(file, index, userId);
      if (tgUrl != null && tgUrl.startsWith('http')) {
        return tgUrl;
      }
    } catch (_) {}

    try {
      final filename = 'hw_${userId}_${DateTime.now().millisecondsSinceEpoch}_$index.jpg';
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('dessert_submissions')
          .child(userId)
          .child(filename);

      final uploadTask = await storageRef.putFile(
        file,
        SettableMetadata(contentType: 'image/jpeg'),
      ).timeout(const Duration(seconds: 15));

      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Firebase storage upload failed for item $index: $e');
      throw Exception('Photo #${index + 1} upload failed. Please check internet connection.');
    }
  }

  Future<void> _submitHomework() async {
    final user = context.read<AuthProvider>().userModel;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to submit homework')),
      );
      return;
    }

    final caption = _captionController.text.trim();
    if (_selectedPhotos.isEmpty && caption.isEmpty) {
      HapticFeedbackService.warning();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please take a photo or enter your answer notes!'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadStatusMessage = _selectedPhotos.isNotEmpty
          ? 'Uploading page 1 of ${_selectedPhotos.length}...'
          : 'Submitting homework...';
    });

    try {
      final List<String> uploadedUrls = [];

      for (int i = 0; i < _selectedPhotos.length; i++) {
        if (mounted) {
          setState(() {
            _uploadStatusMessage = 'Uploading page ${i + 1} of ${_selectedPhotos.length}...';
          });
        }
        final url = await _uploadSinglePhoto(_selectedPhotos[i], i, user.id);
        uploadedUrls.add(url);
      }

      if (mounted) {
        setState(() {
          _uploadStatusMessage = 'Saving your submission...';
        });
      }

      await context.read<DessertsProvider>().submitDessert(
            studentId: user.id,
            studentName: user.name,
            studentPhone: user.phone,
            subject: _selectedSubject,
            caption: caption,
            mediaUrls: uploadedUrls,
            type: uploadedUrls.isNotEmpty ? DessertType.image : DessertType.text,
          );

      HapticFeedbackService.success();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Text('🎉', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Physics homework submitted successfully!\nTeachers will review it shortly to award XP.',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 4),
          ),
        );

        _clearForm();
        _tabController.animateTo(1);
      }
    } catch (e) {
      debugPrint('Submission failed: $e');
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: AppColors.error),
                const SizedBox(width: 10),
                Text('Submission Failed', style: GoogleFonts.outfit(color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.bold)),
              ],
            ),
            content: Text(
              'Could not upload homework: ${e.toString().replaceAll('Exception:', '')}\n\nPlease check your internet connection and try again.',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
    }
  }

  // ──────────────── UI Builder ────────────────

  @override
  Widget build(BuildContext context) {
    final dessertsProvider = context.watch<DessertsProvider>();
    final myDesserts = dessertsProvider.desserts;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Homework & Desserts 🍰',
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        automaticallyImplyLeading: false,
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(14),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: const Color(0xFF2563EB),
              unselectedLabelColor: const Color(0xFF64748B),
              labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13.5),
              unselectedLabelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w500, fontSize: 13.5),
              tabs: [
                const Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cloud_upload_rounded, size: 18),
                      SizedBox(width: 8),
                      Text('Submit Work'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.history_rounded, size: 18),
                      const SizedBox(width: 8),
                      Text('My Submissions (${myDesserts.length})'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSubmitTab(),
          _buildHistoryTab(myDesserts, dessertsProvider),
        ],
      ),
    );
  }

  // ──────────────── TAB 1: SUBMIT HOMEWORK FORM ────────────────

  Widget _buildSubmitTab() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 1. Unified Clean Hero Card with Live Pulse XP Tag ────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFF334155)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withOpacity(0.2),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Subject Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withOpacity(0.25),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.5)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('⚡', style: TextStyle(fontSize: 13)),
                          const SizedBox(width: 5),
                          Text(
                            'A/L Physics Only',
                            style: GoogleFonts.outfit(
                              color: const Color(0xFF60A5FA),
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Live Animated XP Badge
                    ScaleTransition(
                      scale: _pulseAnimation,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFF59E0B).withOpacity(0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('⭐', style: TextStyle(fontSize: 11)),
                            const SizedBox(width: 4),
                            Text(
                              '+25 to +50 XP',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'Direct Homework Submission',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Upload clear photos of your solved questions & homework. Teachers evaluate your work to boost your leaderboard ranking!',
                  style: GoogleFonts.outfit(
                    color: const Color(0xFF94A3B8),
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 22),

          // ── 2. Question Details & Quick Topic Selection ─────────────────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.edit_note_rounded, color: Color(0xFF2563EB), size: 18),
              ),
              const SizedBox(width: 8),
              Text(
                'Question Details & Topics',
                style: GoogleFonts.outfit(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                '(Optional)',
                style: GoogleFonts.outfit(
                  color: const Color(0xFF94A3B8),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Quick Topic Chips (Live interactive tap to auto-fill)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: _quickTopicTags.map((tag) {
                final isContained = _captionController.text.contains(tag);
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _BouncingTap(
                    onTap: () => _insertQuickTag(tag),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isContained ? const Color(0xFFEFF6FF) : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isContained ? const Color(0xFF3B82F6) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isContained) ...[
                            const Icon(Icons.check_rounded, size: 12, color: Color(0xFF2563EB)),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            tag,
                            style: GoogleFonts.outfit(
                              color: isContained ? const Color(0xFF2563EB) : const Color(0xFF475569),
                              fontSize: 11.5,
                              fontWeight: isContained ? FontWeight.bold : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),

          // Notes Input Box
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _captionController,
              maxLines: 3,
              style: GoogleFonts.outfit(color: AppColors.textPrimary, fontSize: 13.5),
              decoration: InputDecoration(
                hintText: 'e.g. Unit 3 Problem #04, Circular Motion Tutorial...',
                hintStyle: GoogleFonts.outfit(color: const Color(0xFF94A3B8), fontSize: 13),
                filled: false,
                contentPadding: const EdgeInsets.all(14),
                border: InputBorder.none,
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ── 3. High-Contrast, Tactile Photo Upload Zone ─────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.add_a_photo_rounded, color: Color(0xFF16A34A), size: 18),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Attach Written Work',
                    style: GoogleFonts.outfit(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              if (_selectedPhotos.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_selectedPhotos.length} Page${_selectedPhotos.length > 1 ? 's' : ''} Selected',
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF2563EB),
                      fontWeight: FontWeight.bold,
                      fontSize: 11.5,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // High-Contrast Dual Action Tiles
          Row(
            children: [
              // 1. Camera Tile
              Expanded(
                child: _BouncingTap(
                  onTap: _isUploading ? null : _pickFromCamera,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFBFDBFE), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2563EB).withOpacity(0.06),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF2563EB).withOpacity(0.15),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.camera_alt_rounded, color: Color(0xFF2563EB), size: 22),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Take Photo',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1E3A8A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Snap via camera',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // 2. Gallery Tile
              Expanded(
                child: _BouncingTap(
                  onTap: _isUploading ? null : _pickFromGallery,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAF5FF),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFDDD6FE), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF7C3AED).withOpacity(0.06),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF7C3AED).withOpacity(0.15),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.photo_library_rounded, color: Color(0xFF7C3AED), size: 22),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'From Gallery',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF581C87),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Select multiple',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Selected Photos Preview Strip
          if (_selectedPhotos.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Attached Pages (${_selectedPhotos.length})',
                        style: GoogleFonts.outfit(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF334155),
                        ),
                      ),
                      Text(
                        'Tap to inspect full screen',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 110,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: _selectedPhotos.length + 1,
                      itemBuilder: (context, index) {
                        if (index == _selectedPhotos.length) {
                          // "+ Add Page" card at end
                          return _BouncingTap(
                            onTap: _isUploading ? null : _pickFromGallery,
                            child: Container(
                              width: 85,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFCBD5E1), style: BorderStyle.solid),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.add_photo_alternate_outlined, color: Color(0xFF64748B), size: 24),
                                  const SizedBox(height: 4),
                                  Text(
                                    '+ Add Page',
                                    style: GoogleFonts.outfit(
                                      color: const Color(0xFF64748B),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        final file = _selectedPhotos[index];
                        return Container(
                          width: 85,
                          margin: const EdgeInsets.only(right: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              GestureDetector(
                                onTap: () => _previewPhotoDialog(file, index),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(13),
                                  child: Image.file(
                                    file,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              // Page Chip
                              Positioned(
                                bottom: 4,
                                left: 4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.75),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'P${index + 1}',
                                    style: GoogleFonts.outfit(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              // Delete Button
                              Positioned(
                                top: 4,
                                right: 4,
                                child: _BouncingTap(
                                  onTap: () => _removePhoto(index),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFEF4444),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.close, size: 12, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Uploading Status indicator
          if (_isUploading) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Row(
                children: [
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF2563EB)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      _uploadStatusMessage,
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF1E3A8A),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
          ],

          // ── 4. Primary Submit Button with Live Bounce ──────────────────────
          _BouncingTap(
            onTap: _isUploading ? null : _submitHomework,
            child: Container(
              width: double.infinity,
              height: 54,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _selectedPhotos.isNotEmpty
                      ? const [Color(0xFF2563EB), Color(0xFF1D4ED8)]
                      : const [Color(0xFF3B82F6), Color(0xFF2563EB)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withOpacity(0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isUploading)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                      )
                    else ...[
                      const Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        _selectedPhotos.isNotEmpty
                            ? 'Submit ${_selectedPhotos.length} Page${_selectedPhotos.length > 1 ? 's' : ''} for Review'
                            : 'Submit Homework Now 🚀',
                        style: GoogleFonts.outfit(
                          fontSize: 15.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 26),

          // ── 5. Minimalist Telegram Bot Alternative ──────────────────────────
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                initiallyExpanded: _showTelegramGuide,
                onExpansionChanged: (val) => setState(() => _showTelegramGuide = val),
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0088CC).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(child: Text('✈️', style: TextStyle(fontSize: 18))),
                ),
                title: Text(
                  'Prefer Telegram? Submit via Bot',
                  style: GoogleFonts.outfit(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'Chat with @edupeakbot to drop files anytime',
                  style: GoogleFonts.outfit(color: const Color(0xFF64748B), fontSize: 12),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _BouncingTap(
                          onTap: () => _openTelegram(context),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0088CC),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.open_in_new, color: Colors.white, size: 16),
                                const SizedBox(width: 8),
                                Text(
                                  'Open Telegram Bot (@edupeakbot)',
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Step-by-step bot guide:',
                          style: GoogleFonts.outfit(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ..._steps.map((step) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(step.icon, style: const TextStyle(fontSize: 15)),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: RichText(
                                      text: TextSpan(
                                        style: GoogleFonts.outfit(
                                          color: const Color(0xFF64748B),
                                          fontSize: 12,
                                          height: 1.3,
                                        ),
                                        children: [
                                          TextSpan(
                                            text: '${step.title}: ',
                                            style: GoogleFonts.outfit(
                                              color: AppColors.textPrimary,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          TextSpan(text: step.desc),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ──────────────── TAB 2: MY SUBMISSIONS HISTORY ────────────────

  Widget _buildHistoryTab(List<DessertModel> allDesserts, DessertsProvider provider) {
    final pendingCount = allDesserts.where((d) => d.isPending).length;
    final approvedCount = allDesserts.where((d) => d.isApproved).length;
    final totalCredits = allDesserts.fold<int>(0, (sum, d) => sum + d.creditsAwarded);

    final filtered = allDesserts.where((d) {
      if (_selectedFilter == 'Pending') return d.isPending;
      if (_selectedFilter == 'Approved') return d.isApproved;
      if (_selectedFilter == 'Rejected') return d.isRejected;
      return true;
    }).toList();

    return RefreshIndicator(
      color: const Color(0xFF2563EB),
      backgroundColor: Colors.white,
      onRefresh: () async {
        final user = context.read<AuthProvider>().userModel;
        if (user != null) {
          await provider.refreshStudentDesserts(user.id, studentPhone: user.phone);
        }
      },
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(18),
        children: [
          // 4-Card Balanced Summary Stats Grid
          Row(
            children: [
              Expanded(
                child: _buildMiniStatCard(
                  title: 'Total',
                  value: '${allDesserts.length}',
                  emoji: '📦',
                  color: const Color(0xFF2563EB),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMiniStatCard(
                  title: 'Pending',
                  value: '$pendingCount',
                  emoji: '⏳',
                  color: const Color(0xFFF59E0B),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMiniStatCard(
                  title: 'Approved',
                  value: '$approvedCount',
                  emoji: '✅',
                  color: const Color(0xFF10B981),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMiniStatCard(
                  title: 'Earned XP',
                  value: '+$totalCredits',
                  emoji: '⭐',
                  color: const Color(0xFF7C3AED),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: ['All', 'Pending', 'Approved', 'Rejected'].map((filter) {
                final isSelected = _selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _BouncingTap(
                    onTap: () {
                      setState(() => _selectedFilter = filter);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF2563EB) : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF2563EB).withOpacity(0.25),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Text(
                        filter,
                        style: GoogleFonts.outfit(
                          color: isSelected ? Colors.white : const Color(0xFF475569),
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 16),

          // Submissions List or Empty State
          if (filtered.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Center(
                        child: Text('🍰', style: TextStyle(fontSize: 32)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _selectedFilter == 'All'
                          ? 'No submissions yet!'
                          : 'No $_selectedFilter submissions found',
                      style: GoogleFonts.outfit(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Complete your physics homework and submit photos to earn XP on the leaderboard!',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(color: const Color(0xFF64748B), fontSize: 13, height: 1.4),
                    ),
                    const SizedBox(height: 20),
                    _BouncingTap(
                      onTap: () {
                        _tabController.animateTo(0);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Submit Homework Now',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...filtered.map((dessert) => _buildDessertHistoryCard(dessert)),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildMiniStatCard({
    required String title,
    required String value,
    required String emoji,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 13)),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(color: const Color(0xFF64748B), fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.outfit(
              color: color,
              fontSize: 16.5,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDessertHistoryCard(DessertModel dessert) {
    Color statusBgColor;
    Color statusTextColor;
    String statusText;
    IconData statusIcon;

    if (dessert.isApproved) {
      statusBgColor = const Color(0xFFECFDF5);
      statusTextColor = const Color(0xFF059669);
      statusText = 'Approved (+${dessert.creditsAwarded} XP)';
      statusIcon = Icons.check_circle_rounded;
    } else if (dessert.isRejected) {
      statusBgColor = const Color(0xFFFEF2F2);
      statusTextColor = const Color(0xFFDC2626);
      statusText = 'Needs Revision';
      statusIcon = Icons.cancel_rounded;
    } else {
      statusBgColor = const Color(0xFFFFFBEB);
      statusTextColor = const Color(0xFFD97706);
      statusText = 'Under Review';
      statusIcon = Icons.hourglass_top_rounded;
    }

    final hasImages = dessert.mediaUrls.isNotEmpty;
    final firstImg = hasImages ? dessert.mediaUrls.first : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: dessert.isApproved
              ? const Color(0xFF10B981).withOpacity(0.3)
              : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: () {
            HapticFeedbackService.light();
            context.push('/student/dessert/${dessert.id}');
          },
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: Subject & Status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Subject tag
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('⚡', style: TextStyle(fontSize: 12)),
                          const SizedBox(width: 5),
                          Text(
                            dessert.subject ?? 'Physics',
                            style: GoogleFonts.outfit(
                              color: const Color(0xFF2563EB),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusBgColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: statusTextColor.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, size: 12, color: statusTextColor),
                          const SizedBox(width: 4),
                          Text(
                            statusText,
                            style: GoogleFonts.outfit(
                              color: statusTextColor,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Middle row: Thumbnail + Details
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (hasImages && firstImg != null && firstImg.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          width: 56,
                          height: 56,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              MediaImageView(url: firstImg, fit: BoxFit.cover),
                              if (dessert.mediaUrls.length > 1)
                                Positioned(
                                  bottom: 2,
                                  right: 2,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.75),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '+${dessert.mediaUrls.length}',
                                      style: GoogleFonts.outfit(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      )
                    else
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Text('📝', style: TextStyle(fontSize: 22)),
                        ),
                      ),

                    const SizedBox(width: 12),

                    // Content preview
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            dessert.caption?.isNotEmpty == true
                                ? dessert.caption!
                                : (hasImages
                                    ? '${dessert.mediaUrls.length} Page${dessert.mediaUrls.length > 1 ? 's' : ''} attached'
                                    : 'Physics Homework submission'),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            timeago.format(dessert.submittedAt),
                            style: GoogleFonts.outfit(color: const Color(0xFF94A3B8), fontSize: 11.5),
                          ),
                        ],
                      ),
                    ),

                    const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8), size: 20),
                  ],
                ),

                // Teacher Feedback Bubble if present
                if (dessert.adminFeedback?.isNotEmpty == true) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        const Text('💬', style: TextStyle(fontSize: 14)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            dessert.adminFeedback!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(color: const Color(0xFF475569), fontSize: 11.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ──────────────── External Links ────────────────

  Future<void> _openTelegram(BuildContext context) async {
    final appUri = Uri.parse('tg://resolve?domain=edupeakbot&start=submit_dessert');
    final webUri = Uri.parse('https://t.me/edupeakbot?start=submit_dessert');
    try {
      if (await canLaunchUrl(appUri)) {
        await launchUrl(appUri, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(webUri)) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      if (await canLaunchUrl(webUri)) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    }
  }
}

// ──────────────── Micro-Animation: Bouncing Tap Wrapper ────────────────

class _BouncingTap extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scaleDown;

  const _BouncingTap({
    required this.child,
    required this.onTap,
    this.scaleDown = 0.96,
  });

  @override
  State<_BouncingTap> createState() => _BouncingTapState();
}

class _BouncingTapState extends State<_BouncingTap> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
      reverseDuration: const Duration(milliseconds: 140),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: widget.scaleDown).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    if (widget.onTap == null) return;
    _controller.forward();
  }

  void _onTapUp(TapUpDetails _) {
    if (widget.onTap == null) return;
    _controller.reverse();
    HapticFeedbackService.light();
    widget.onTap?.call();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}

const _steps = [
  (
    title: 'Open Telegram Bot',
    desc: 'Tap the button above or search for @edupeakbot in Telegram.',
    icon: '✈️',
  ),
  (
    title: 'Start the Bot',
    desc: 'Tap Start or tap "Submit Homework" in the menu.',
    icon: '🚀',
  ),
  (
    title: 'Send your homework',
    desc: 'Attach photos of your written work or send a PDF file with a short note.',
    icon: '📸',
  ),
  (
    title: 'Wait for review',
    desc: 'Your teachers and AI grader will review it and award XP credits!',
    icon: '⏳',
  ),
  (
    title: 'Earn credits',
    desc: 'Correct homework earns you XP and moves you up the Leaderboard!',
    icon: '⭐',
  ),
];
