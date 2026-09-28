import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:record/record.dart';
import 'package:google_fonts/google_fonts.dart';

class CreateTaskPage extends StatefulWidget {
  const CreateTaskPage({super.key});

  @override
  State<CreateTaskPage> createState() => _CreateTaskPageState();
}

class _CreateTaskPageState extends State<CreateTaskPage> {
  // =========================
  // الألوان
  // =========================

  static const Color navy = Color(0xFF172B4D);
  static const Color navy2 = Color(0xFF243B5A);
  static const Color grey = Color(0xFF6B7280);
  static const Color lightGrey = Color(0xFFF3F5F8);
  static const Color border = Color(0xFFE1E5EA);

  // =========================
  // Controllers
  // =========================

  final clientNameController = TextEditingController();
  final phoneController = TextEditingController();
  final propertyTypeController = TextEditingController();
  final taskTypeController = TextEditingController();
  final notesController = TextEditingController();
  final linkController = TextEditingController();

  // =========================
  // Media
  // =========================

  final ImagePicker imagePicker = ImagePicker();
  final AudioRecorder audioRecorder = AudioRecorder();

  File? selectedImage;
  File? selectedVideo;
  String? selectedAudioPath;

  bool isRecording = false;
  bool isSaving = false;

  // =========================
  // Dispose
  // =========================

  @override
  void dispose() {
    clientNameController.dispose();
    phoneController.dispose();
    propertyTypeController.dispose();
    taskTypeController.dispose();
    notesController.dispose();
    linkController.dispose();
    audioRecorder.dispose();

    super.dispose();
  }

  // =========================
  // اختيار صورة
  // =========================

  Future<void> pickImage() async {
    final XFile? image = await imagePicker.pickImage(
      source: ImageSource.gallery,
    );

    if (image == null) return;

    setState(() {
      selectedImage = File(image.path);
    });
  }

  // =========================
  // اختيار فيديو
  // =========================

  Future<void> pickVideo() async {
    final XFile? video = await imagePicker.pickVideo(
      source: ImageSource.gallery,
    );

    if (video == null) return;

    setState(() {
      selectedVideo = File(video.path);
    });
  }

  // =========================
  // اختيار ملف صوتي
  // =========================

  Future<void> pickAudioFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'mp3',
        'm4a',
        'wav',
        'aac',
        'ogg',
      ],
    );

    if (result.isEmpty || result.first.path == null) {
      return;
    }

    setState(() {
      selectedAudioPath = result.first.path;
    });
  }

  // =========================
  // بدء التسجيل
  // =========================

  Future<void> startRecording() async {
    final hasPermission = await audioRecorder.hasPermission();

    if (!hasPermission) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text(
            'يجب السماح باستخدام الميكروفون',
            style: GoogleFonts.cairo(
              color: Colors.white,
            ),
          ),
        ),
      );

      return;
    }

    final directory = Directory.systemTemp;

    final path =
        '${directory.path}/task_audio_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await audioRecorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
      ),
      path: path,
    );

    setState(() {
      isRecording = true;
    });
  }

  // =========================
  // إيقاف التسجيل
  // =========================

  Future<void> stopRecording() async {
    final path = await audioRecorder.stop();

    if (!mounted) return;

    setState(() {
      isRecording = false;
      selectedAudioPath = path;
    });
  }

  // =========================
  // رفع الملفات
  // =========================

  Future<String?> uploadFile(
    File file,
    String folder,
  ) async {
    try {
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';

      final reference = FirebaseStorage.instance
          .ref()
          .child(folder)
          .child(fileName);

      await reference.putFile(file);

      return await reference.getDownloadURL();
    } catch (e) {
      debugPrint('Upload error: $e');
      return null;
    }
  }

  // =========================
  // رفع الصوت
  // =========================

  Future<String?> uploadAudio(
    String path,
  ) async {
    return uploadFile(
      File(path),
      'task_audio',
    );
  }

  // =========================
  // رسالة
  // =========================

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: navy,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        content: Text(
          message,
          textAlign: TextAlign.right,
          style: GoogleFonts.cairo(
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  // =========================
  // نشر المهمة
  // =========================

  Future<void> publishTask() async {
    final clientName = clientNameController.text.trim();
    final phone = phoneController.text.trim();
    final propertyType = propertyTypeController.text.trim();
    final taskType = taskTypeController.text.trim();
    final notes = notesController.text.trim();
    final link = linkController.text.trim();

    if (clientName.isEmpty) {
      showMessage('اكتبي اسم العميل');
      return;
    }

    if (phone.isEmpty) {
      showMessage('اكتبي رقم العميل');
      return;
    }

    if (taskType.isEmpty) {
      showMessage('اكتبي نوع المهمة');
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      String? imageUrl;
      String? videoUrl;
      String? audioUrl;

      // =========================
      // رفع الصورة
      // =========================

      if (selectedImage != null) {
        imageUrl = await uploadFile(
          selectedImage!,
          'task_images',
        );
      }

      // =========================
      // رفع الفيديو
      // =========================

      if (selectedVideo != null) {
        videoUrl = await uploadFile(
          selectedVideo!,
          'task_videos',
        );
      }

      // =========================
      // رفع الصوت
      // =========================

      if (selectedAudioPath != null) {
        audioUrl = await uploadAudio(
          selectedAudioPath!,
        );
      }

      // =========================
      // المستخدم الحالي
      // =========================

      final currentUser =
          FirebaseAuth.instance.currentUser;

      final currentEmail =
          currentUser?.email?.trim() ?? '';

      final currentUserName =
          currentUser?.displayName?.trim().isNotEmpty == true
              ? currentUser!.displayName!.trim()
              : currentEmail;

      // =========================
      // إنشاء المهمة
      // =========================

      await FirebaseFirestore.instance
          .collection('tasks')
          .add({
        // =========================
        // بيانات المهمة
        // =========================

        'clientName': clientName,
        'phone': phone,
        'propertyType': propertyType,
        'taskType': taskType,
        'notes': notes,
        'link': link,

        // =========================
        // المرفقات
        // =========================

        'imageUrl': imageUrl ?? '',
        'videoUrl': videoUrl ?? '',
        'audioUrl': audioUrl ?? '',

        // =========================
        // حالة المهمة
        // =========================

        'status': 'ready',

        'assignedTo': 'لم يتم استلامها بعد',
        'assignedToName': '',

        // =========================
        // بيانات إعادة الإرسال
        // =========================

        'repostReason': '',
        'repostedBy': '',
        'repostedByName': '',
        'repostedAt': null,

        // =========================
        // منشئ المهمة
        // =========================

        'createdBy': currentEmail,
        'createdByName': currentUserName,
        'createdByRole': 'admin',

        // =========================
        // هذه مهمة من المدير
        // وليست مهمة مرسلة من المسوق
        // =========================

        'isMarketingSubmitted': false,

        // =========================
        // التاريخ والوقت
        // يتم حفظهما تلقائياً من Firebase
        // =========================

        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF2E7D32),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          content: Text(
            'تم نشر المهمة بنجاح',
            textAlign: TextAlign.right,
            style: GoogleFonts.cairo(
              color: Colors.white,
            ),
          ),
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          content: Text(
            'حدث خطأ أثناء نشر المهمة',
            textAlign: TextAlign.right,
            style: GoogleFonts.cairo(
              color: Colors.white,
            ),
          ),
        ),
      );

      debugPrint('Publish task error: $e');
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  // =========================
  // Text Field
  // =========================

  Widget buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.right,
        style: GoogleFonts.cairo(
          fontSize: 14,
          color: navy,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.cairo(
            fontSize: 13,
            color: grey,
          ),
          floatingLabelStyle: GoogleFonts.cairo(
            color: navy,
            fontSize: 13,
          ),
          prefixIcon: Icon(
            icon,
            color: navy,
            size: 21,
          ),
          filled: true,
          fillColor: lightGrey,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 15,
            vertical: 15,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
              color: border,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
              color: border,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
              color: navy,
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }

  // =========================
  // عنوان القسم
  // =========================

  Widget buildSectionTitle({
    required String title,
    required IconData icon,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(
        top: 5,
        bottom: 12,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: lightGrey,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: border,
        ),
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: navy,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: GoogleFonts.cairo(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: navy,
            ),
          ),
        ],
      ),
    );
  }

  // =========================
  // زر مرفق
  // =========================

  Widget attachmentButton({
    required String title,
    required IconData icon,
    required VoidCallback onPressed,
    bool active = false,
  }) {
    return Expanded(
      child: SizedBox(
        height: 52,
        child: OutlinedButton.icon(
          onPressed: onPressed,
          icon: Icon(
            icon,
            size: 20,
          ),
          label: Text(
            title,
            style: GoogleFonts.cairo(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor:
                active ? Colors.white : navy,
            backgroundColor:
                active ? navy : lightGrey,
            side: BorderSide(
              color: active ? navy : border,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(13),
            ),
          ),
        ),
      ),
    );
  }

  // =========================
  // بطاقة المرفق
  // =========================

  Widget attachmentPreview({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onRemove,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: border,
        ),
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: lightGrey,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: navy,
              size: 22,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.end,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.right,
                  style: GoogleFonts.cairo(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: navy,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  textAlign: TextAlign.right,
                  style: GoogleFonts.cairo(
                    fontSize: 11,
                    color: grey,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: onRemove,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color:
                    Colors.red.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close,
                color: Color(0xFFC62828),
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================
  // معاينة الصورة
  // =========================

  Widget buildImagePreview() {
    if (selectedImage == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 10),
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: border,
        ),
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              selectedImage!,
              width: 75,
              height: 75,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.end,
              children: [
                Text(
                  'تم اختيار صورة',
                  style: GoogleFonts.cairo(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: navy,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'الصورة جاهزة للرفع مع المهمة',
                  textAlign: TextAlign.right,
                  style: GoogleFonts.cairo(
                    fontSize: 11,
                    color: grey,
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: () {
              setState(() {
                selectedImage = null;
              });
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color:
                    Colors.red.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close,
                color: Color(0xFFC62828),
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================
  // Build
  // =========================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightGrey,

      // =========================
      // AppBar
      // =========================

      appBar: AppBar(
        backgroundColor: navy,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        title: Text(
          'نشر مهمة جديدة',
          style: GoogleFonts.cairo(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      // =========================
      // Body
      // =========================

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            16,
            16,
            16,
            100,
          ),
          child: Column(
            children: [
              // =========================
              // معلومات المهمة
              // =========================

              buildSectionTitle(
                title: 'بيانات المهمة',
                icon: Icons.assignment_outlined,
              ),

              buildTextField(
                controller: clientNameController,
                label: 'اسم العميل',
                icon: Icons.person_outline,
              ),

              buildTextField(
                controller: phoneController,
                label: 'رقم العميل',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
              ),

              buildTextField(
                controller: propertyTypeController,
                label: 'نوع العقار',
                icon: Icons.home_work_outlined,
              ),

              buildTextField(
                controller: taskTypeController,
                label: 'نوع المهمة',
                icon: Icons.assignment_outlined,
              ),

              buildTextField(
                controller: linkController,
                label: 'رابط الموقع أو المهمة',
                icon: Icons.link,
              ),

              buildTextField(
                controller: notesController,
                label: 'ملاحظات',
                icon: Icons.notes_outlined,
                maxLines: 4,
              ),

              // =========================
              // المرفقات
              // =========================

              buildSectionTitle(
                title: 'المرفقات',
                icon: Icons.attach_file,
              ),

              Row(
                children: [
                  attachmentButton(
                    title: 'إضافة صورة',
                    icon: Icons.image_outlined,
                    onPressed: pickImage,
                    active: selectedImage != null,
                  ),
                  const SizedBox(width: 8),
                  attachmentButton(
                    title: 'إضافة فيديو',
                    icon: Icons.video_library_outlined,
                    onPressed: pickVideo,
                    active: selectedVideo != null,
                  ),
                ],
              ),

              const SizedBox(height: 9),

              Row(
                children: [
                  attachmentButton(
                    title: 'ملف صوتي',
                    icon: Icons.audio_file_outlined,
                    onPressed: pickAudioFile,
                    active: selectedAudioPath != null,
                  ),
                  const SizedBox(width: 8),
                  attachmentButton(
                    title: isRecording
                        ? 'إيقاف التسجيل'
                        : 'تسجيل صوت',
                    icon: isRecording
                        ? Icons.stop
                        : Icons.mic_none,
                    onPressed: isRecording
                        ? stopRecording
                        : startRecording,
                    active: isRecording,
                  ),
                ],
              ),

              // =========================
              // معاينة الصورة
              // =========================

              buildImagePreview(),

              // =========================
              // معاينة الفيديو
              // =========================

              if (selectedVideo != null)
                attachmentPreview(
                  icon: Icons.video_library_outlined,
                  title: 'تم اختيار فيديو',
                  subtitle:
                      'الفيديو جاهز للرفع مع المهمة',
                  onRemove: () {
                    setState(() {
                      selectedVideo = null;
                    });
                  },
                ),

              // =========================
              // معاينة الصوت
              // =========================

              if (selectedAudioPath != null)
                attachmentPreview(
                  icon: Icons.audiotrack,
                  title: isRecording
                      ? 'جاري تسجيل الصوت'
                      : 'تم اختيار ملف صوتي',
                  subtitle:
                      'الملف الصوتي جاهز للرفع مع المهمة',
                  onRemove: () {
                    setState(() {
                      selectedAudioPath = null;
                    });
                  },
                ),

              const SizedBox(height: 20),

              // =========================
              // زر النشر
              // =========================

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed:
                      isSaving ? null : publishTask,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: navy,
                    disabledBackgroundColor:
                        navy.withValues(alpha: 0.55),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(15),
                    ),
                  ),
                  child: isSaving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Row(
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.publish_outlined,
                              size: 21,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'نشر المهمة',
                              style: GoogleFonts.cairo(
                                fontSize: 15,
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                ),
              ),

              const SizedBox(height: 12),

              // =========================
              // ملاحظة أسفل الزر
              // =========================

              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.circular(14),
                  border: Border.all(
                    color: border,
                  ),
                ),
                child: Row(
                  textDirection: TextDirection.rtl,
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: grey,
                      size: 19,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'بعد نشر المهمة ستظهر للموظفين لاستلامها والبدء بالعمل عليها.',
                        textAlign: TextAlign.right,
                        style: GoogleFonts.cairo(
                          fontSize: 11,
                          color: grey,
                          height: 1.7,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}