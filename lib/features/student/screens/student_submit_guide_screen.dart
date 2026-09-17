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
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ImagePicker _picker = ImagePicker();

  // Form State
  String _selectedSubject = 'Physics';
  final TextEditingController _captionController = TextEditingController();
  final List<File> _selectedPhotos = [];

  bool _isUploading = false;
  String _uploadStatusMessage = '';
  String _selectedFilter = 'All'; // 'All', 'Pending', 'Approved', 'Rejected'
  bool _showTelegramGuide = false;

  final List<String> _subjectOptions = [
    'Physics',
    'Combined Maths',
    'Chemistry',
    'Biology',
    'ICT',
    'General English',
    'Other',
  ];

  final Map<String, String> _subjectIcons = {
    'Physics': '⚡',
    'Combined Maths': '📐',
    'Chemistry': '🧪',
    'Biology': '🧬',
    'ICT': '💻',
    'General English': '🇬🇧',
    'Other': '✍️',
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 1),
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
      // Fallback to single image pick if multi-picker has issues on device
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
      _selectedSubject = 'Physics';
      _isUploading = false;
      _uploadStatusMessage = '';
    });
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
    // 1. Try high-speed direct CDN upload
    try {
      final tgUrl = await _uploadToTelegramCDN(file, index, userId);
      if (tgUrl != null && tgUrl.startsWith('http')) {
        return tgUrl;
      }
    } catch (_) {}

    // 2. Fallback to Firebase Storage
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
          ? 'Uploading photo 1 of ${_selectedPhotos.length}...'
          : 'Submitting homework...';
    });

    try {
      final List<String> uploadedUrls = [];

      for (int i = 0; i < _selectedPhotos.length; i++) {
        if (mounted) {
          setState(() {
            _uploadStatusMessage = 'Uploading photo ${i + 1} of ${_selectedPhotos.length}...';
          });
        }
        final url = await _uploadSinglePhoto(_selectedPhotos[i], i, user.id);
        uploadedUrls.add(url);
      }

      if (mounted) {
        setState(() {
          _uploadStatusMessage = 'Saving homework submission...';
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

      HapticFeedbackService.heavy();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Text('🎉', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Homework submitted successfully!\nTeachers will review it soon and award XP.',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
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

        // Switch to My History tab to view submission
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
            backgroundColor: AppColors.darkCard,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.error_outline, color: AppColors.error),
                const SizedBox(width: 10),
                Text('Submission Failed', style: GoogleFonts.poppins(color: Colors.white, fontSize: 16)),
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
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        title: const Text('Homework & Desserts 🍰'),
        elevation: 0,
        backgroundColor: AppColors.darkCard,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.darkBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.darkBorder),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: const LinearGradient(
                  colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withOpacity(0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: Colors.white,
              unselectedLabelColor: AppColors.textSecondary,
              labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
              tabs: [
                const Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_photo_alternate_rounded, size: 18),
                      SizedBox(width: 8),
                      Text('Submit HW'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.history_edu_rounded, size: 18),
                      const SizedBox(width: 8),
                      Text('My History (${myDesserts.length})'),
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
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Hero Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2563EB).withOpacity(0.25),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                    child: Text('🚀', style: TextStyle(fontSize: 26)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Direct Homework Submission',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Snap photos of your written work & earn XP credits on the leaderboard!',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 22),

          // 1. Subject Selector
          Text(
            '1. Select Subject',
            style: GoogleFonts.poppins(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _subjectOptions.map((sub) {
                final isSelected = _selectedSubject == sub;
                final icon = _subjectIcons[sub] ?? '📚';
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(icon, style: const TextStyle(fontSize: 15)),
                        const SizedBox(width: 6),
                        Text(sub),
                      ],
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        HapticFeedbackService.selection();
                        setState(() => _selectedSubject = sub);
                      }
                    },
                    selectedColor: const Color(0xFF2563EB),
                    backgroundColor: AppColors.darkCard,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : AppColors.textSecondary,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      fontSize: 13,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isSelected ? const Color(0xFF3B82F6) : AppColors.darkBorder,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 22),

          // 2. Question notes / Caption
          Text(
            '2. Question Details & Notes',
            style: GoogleFonts.poppins(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _captionController,
            maxLines: 3,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'e.g., 2023 Paper Part B Q4, or Newton\'s Laws Problem #3...',
              hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
              filled: true,
              fillColor: AppColors.darkCard,
              contentPadding: const EdgeInsets.all(14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.darkBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.darkBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 1.5),
              ),
            ),
          ),

          const SizedBox(height: 22),

          // 3. Attach Photos of Work
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '3. Attach Photos of Work',
                style: GoogleFonts.poppins(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (_selectedPhotos.isNotEmpty)
                Text(
                  '${_selectedPhotos.length} photo${_selectedPhotos.length > 1 ? 's' : ''}',
                  style: const TextStyle(
                    color: Color(0xFF38BDF8),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Photo capture buttons row
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isUploading ? null : _pickFromCamera,
                  icon: const Icon(Icons.camera_alt_rounded, color: Color(0xFF38BDF8), size: 20),
                  label: Text('Take Photo', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7).withOpacity(0.12),
                    side: BorderSide(color: const Color(0xFF0284C7).withOpacity(0.4)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isUploading ? null : _pickFromGallery,
                  icon: const Icon(Icons.photo_library_rounded, color: Color(0xFFA855F7), size: 20),
                  label: Text('From Gallery', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: const Color(0xFF9333EA).withOpacity(0.12),
                    side: BorderSide(color: const Color(0xFF9333EA).withOpacity(0.4)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),

          // Photos Preview Strip
          if (_selectedPhotos.isNotEmpty) ...[
            const SizedBox(height: 14),
            SizedBox(
              height: 110,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _selectedPhotos.length,
                itemBuilder: (context, index) {
                  final file = _selectedPhotos[index];
                  return Container(
                    width: 90,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.darkBorder),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            file,
                            fit: BoxFit.cover,
                          ),
                        ),
                        // Page badge
                        Positioned(
                          bottom: 4,
                          left: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'P${index + 1}',
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        // Remove button
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () => _removePhoto(index),
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                color: Color(0xFFEF4444),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close, size: 14, color: Colors.white),
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

          const SizedBox(height: 26),

          // Uploading Status indicator
          if (_isUploading) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.5)),
              ),
              child: Row(
                children: [
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF38BDF8)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      _uploadStatusMessage,
                      style: GoogleFonts.poppins(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
          ],

          // Primary Submit Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _isUploading ? null : _submitHomework,
              icon: _isUploading
                  ? const SizedBox.shrink()
                  : const Icon(Icons.send_rounded, size: 20),
              label: Text(
                _isUploading ? 'Submitting...' : 'Submit Homework Now 🚀',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 4,
                shadowColor: const Color(0xFF2563EB).withOpacity(0.5),
              ),
            ),
          ),

          const SizedBox(height: 28),

          // Alternative: Submit via Telegram Card / Accordion
          Container(
            decoration: BoxDecoration(
              color: AppColors.darkCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.darkBorder),
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
                    color: const Color(0xFF0088CC).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(child: Text('✈️', style: TextStyle(fontSize: 18))),
                ),
                title: Text(
                  'Prefer Telegram? Submit via Bot',
                  style: GoogleFonts.poppins(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: const Text(
                  'Chat with @edupeakbot to drop files anytime',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => _openTelegram(context),
                          icon: const Icon(Icons.open_in_new, size: 16),
                          label: const Text('Open Telegram Bot (@edupeakbot)'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0088CC),
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 44),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Step-by-step bot guide:',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        ..._steps.map((step) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(step.icon, style: const TextStyle(fontSize: 16)),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: RichText(
                                      text: TextSpan(
                                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.3),
                                        children: [
                                          TextSpan(text: '${step.title}: ', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
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

          const SizedBox(height: 30),
        ],
      ),
    );
  }

  // ──────────────── TAB 2: MY SUBMISSIONS HISTORY ────────────────

  Widget _buildHistoryTab(List<DessertModel> allDesserts, DessertsProvider provider) {
    final pendingCount = allDesserts.where((d) => d.isPending).length;
    final approvedCount = allDesserts.where((d) => d.isApproved).length;
    final totalCredits = allDesserts.fold<int>(0, (sum, d) => sum + d.creditsAwarded);

    // Apply Filter
    final filtered = allDesserts.where((d) {
      if (_selectedFilter == 'Pending') return d.isPending;
      if (_selectedFilter == 'Approved') return d.isApproved;
      if (_selectedFilter == 'Rejected') return d.isRejected;
      return true;
    }).toList();

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.darkCard,
      onRefresh: () async {
        final user = context.read<AuthProvider>().userModel;
        if (user != null) {
          await provider.refreshStudentDesserts(user.id, studentPhone: user.phone);
        }
      },
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          // 4-Card Summary Stats Grid
          Row(
            children: [
              Expanded(
                child: _buildMiniStatCard(
                  title: 'Total',
                  value: '${allDesserts.length}',
                  emoji: '📦',
                  color: const Color(0xFF60A5FA),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMiniStatCard(
                  title: 'Pending',
                  value: '$pendingCount',
                  emoji: '⏳',
                  color: const Color(0xFFFBBF24),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMiniStatCard(
                  title: 'Approved',
                  value: '$approvedCount',
                  emoji: '✅',
                  color: const Color(0xFF34D399),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMiniStatCard(
                  title: 'Earned XP',
                  value: '$totalCredits',
                  emoji: '⭐',
                  color: const Color(0xFFF59E0B),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['All', 'Pending', 'Approved', 'Rejected'].map((filter) {
                final isSelected = _selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(filter),
                    selected: isSelected,
                    onSelected: (_) {
                      HapticFeedbackService.selection();
                      setState(() => _selectedFilter = filter);
                    },
                    selectedColor: AppColors.primary.withOpacity(0.25),
                    backgroundColor: AppColors.darkCard,
                    labelStyle: TextStyle(
                      color: isSelected ? AppColors.primary : AppColors.textSecondary,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                        color: isSelected ? AppColors.primary : AppColors.darkBorder,
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
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: AppColors.darkCard,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.darkBorder),
                      ),
                      child: const Center(
                        child: Text('🍰', style: TextStyle(fontSize: 36)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _selectedFilter == 'All'
                          ? 'No submissions yet!'
                          : 'No $_selectedFilter submissions found',
                      style: GoogleFonts.poppins(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Complete your daily exercises and submit them to earn XP and move up the ranks!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.4),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () {
                        HapticFeedbackService.light();
                        _tabController.animateTo(0);
                      },
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Submit Homework Now'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.poppins(
              color: color,
              fontSize: 16,
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
      statusBgColor = const Color(0xFF065F46);
      statusTextColor = const Color(0xFF34D399);
      statusText = 'Approved (+${dessert.creditsAwarded} XP)';
      statusIcon = Icons.check_circle_rounded;
    } else if (dessert.isRejected) {
      statusBgColor = const Color(0xFF7F1D1D);
      statusTextColor = const Color(0xFFF87171);
      statusText = 'Needs Revision';
      statusIcon = Icons.cancel_rounded;
    } else {
      statusBgColor = const Color(0xFF78350F);
      statusTextColor = const Color(0xFFFBBF24);
      statusText = 'Under Review';
      statusIcon = Icons.hourglass_top_rounded;
    }

    final hasImages = dessert.mediaUrls.isNotEmpty;
    final firstImg = hasImages ? dessert.mediaUrls.first : null;
    final subjectIcon = _subjectIcons[dessert.subject ?? ''] ?? '📚';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: dessert.isApproved
              ? const Color(0xFF10B981).withOpacity(0.3)
              : AppColors.darkBorder,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () {
            HapticFeedbackService.light();
            context.push('/student/dessert/${dessert.id}');
          },
          borderRadius: BorderRadius.circular(16),
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
                        color: AppColors.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(subjectIcon, style: const TextStyle(fontSize: 12)),
                          const SizedBox(width: 5),
                          Text(
                            dessert.subject ?? 'Homework',
                            style: const TextStyle(
                              color: Color(0xFF60A5FA),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusBgColor.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: statusTextColor.withOpacity(0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, size: 12, color: statusTextColor),
                          const SizedBox(width: 4),
                          Text(
                            statusText,
                            style: TextStyle(
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
                    // Image thumbnail
                    if (hasImages && firstImg != null && firstImg.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox(
                          width: 54,
                          height: 54,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              MediaImageView(url: firstImg, fit: BoxFit.cover),
                              if (dessert.mediaUrls.length > 1)
                                Positioned(
                                  bottom: 2,
                                  right: 2,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.7),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '+${dessert.mediaUrls.length}',
                                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      )
                    else
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: AppColors.darkBg,
                          borderRadius: BorderRadius.circular(10),
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
                                    ? '${dessert.mediaUrls.length} Photo${dessert.mediaUrls.length > 1 ? 's' : ''} attached'
                                    : 'Homework submission'),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            timeago.format(dessert.submittedAt),
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                          ),
                        ],
                      ),
                    ),

                    const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 20),
                  ],
                ),

                // Teacher Feedback Bubble if present
                if (dessert.adminFeedback?.isNotEmpty == true) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.darkBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.darkBorder),
                    ),
                    child: Row(
                      children: [
                        const Text('💬', style: TextStyle(fontSize: 13)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            dessert.adminFeedback!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
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
