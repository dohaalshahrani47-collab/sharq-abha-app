import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:video_player/video_player.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';

import 'task_chat_page.dart';

class TaskDetailsPage extends StatefulWidget {
  final String taskId;
  final Map<String, dynamic> taskData;
  final String currentEmail;
  final String currentRole;

  const TaskDetailsPage({
    super.key,
    required this.taskId,
    required this.taskData,
    required this.currentEmail,
    required this.currentRole,
  });

  @override
  State<TaskDetailsPage> createState() => _TaskDetailsPageState();
}

class _TaskDetailsPageState extends State<TaskDetailsPage> {
  static const Color navy = Color(0xFF172B4D);
  static const Color navy2 = Color(0xFF243B5A);
  static const Color grey = Color(0xFF6B7280);
  static const Color lightGrey = Color(0xFFF3F5F8);
  static const Color border = Color(0xFFE1E5EA);

  final TextEditingController reasonController =
      TextEditingController();

  final AudioPlayer audioPlayer = AudioPlayer();

  VideoPlayerController? videoController;

  bool isAudioPlaying = false;
  bool isVideoReady = false;
  bool isVideoPlaying = false;

  bool isClaiming = false;
  bool isCompleting = false;
  bool isReposting = false;
  bool isSubmittingToAdmin = false;

  @override
  void initState() {
    super.initState();

    final attachmentType =
        widget.taskData['attachmentType']?.toString() ?? '';

    final attachmentUrl =
        widget.taskData['attachmentUrl']?.toString() ?? '';

    debugPrint('==============================');
    debugPrint('TASK DETAILS ATTACHMENT');
    debugPrint('type: $attachmentType');
    debugPrint('url: $attachmentUrl');
    debugPrint(
      'name: ${widget.taskData['attachmentName']?.toString() ?? ''}',
    );
    debugPrint('==============================');

    if (attachmentType == 'video' && attachmentUrl.isNotEmpty) {
      _initializeVideo(attachmentUrl);
    }

    audioPlayer.onPlayerStateChanged.listen(
      (PlayerState state) {
        if (!mounted) return;

        setState(() {
          isAudioPlaying = state == PlayerState.playing;
        });
      },
    );
  }

  Future<void> _initializeVideo(String url) async {
    try {
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(url),
      );

      await controller.initialize();

      if (!mounted) {
        controller.dispose();
        return;
      }

      controller.addListener(() {
        if (!mounted) return;

        setState(() {
          isVideoPlaying = controller.value.isPlaying;
        });
      });

      setState(() {
        videoController = controller;
        isVideoReady = true;
      });
    } catch (e) {
      debugPrint('Video error: $e');
    }
  }

  @override
  void dispose() {
    reasonController.dispose();
    audioPlayer.dispose();
    videoController?.dispose();
    super.dispose();
  }

  // ============================================================
  // هل المستخدم مسوق؟
  // ============================================================

  bool get isEmployeeRole {
    return widget.currentRole == 'marketing' ||
        widget.currentRole == 'employee';
  }

  // ============================================================
  // البريد المستخدم للمحادثة
  // ============================================================

  String get chatEmployeeEmail {
    if (isEmployeeRole) {
      return widget.currentEmail.trim();
    }

    final employeeEmail =
        widget.taskData['employeeEmail']
                ?.toString()
                .trim() ??
            '';

    if (employeeEmail.isNotEmpty) {
      return employeeEmail;
    }

    final assignedTo =
        widget.taskData['assignedTo']
                ?.toString()
                .trim() ??
            '';

    if (assignedTo.isNotEmpty &&
        assignedTo != 'لم يتم استلامها بعد') {
      return assignedTo;
    }

    final submittedBy =
        widget.taskData['submittedBy']
                ?.toString()
                .trim() ??
            '';

    if (submittedBy.isNotEmpty) {
      return submittedBy;
    }

    final completedBy =
        widget.taskData['completedBy']
                ?.toString()
                .trim() ??
            '';

    return completedBy;
  }

  String get chatEmployeeId {
    return chatEmployeeEmail.replaceAll('/', '_');
  }

  // ============================================================
  // استلام المهمة
  // ============================================================

  Future<void> setInProgress() async {
    if (isClaiming) return;

    if (widget.currentEmail.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تعذر تحديد حساب الموظف الحالي',
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      isClaiming = true;
    });

    try {
      final taskRef = FirebaseFirestore.instance
          .collection('tasks')
          .doc(widget.taskId);

      bool claimed = false;

      await FirebaseFirestore.instance.runTransaction(
        (transaction) async {
          final snapshot = await transaction.get(taskRef);

          if (!snapshot.exists) {
            return;
          }

          final data = snapshot.data() ?? {};

          final assignedTo =
              data['assignedTo']?.toString() ??
                  'لم يتم استلامها بعد';

          final status =
              data['status']?.toString() ?? 'ready';

          final isMarketingSubmitted =
              data['isMarketingSubmitted'] == true;

          if (status == 'completed' ||
              status == 'submitted_to_admin' ||
              isMarketingSubmitted) {
            return;
          }

          if (assignedTo != 'لم يتم استلامها بعد' &&
              assignedTo != widget.currentEmail.trim()) {
            return;
          }

          claimed = true;

          transaction.update(
            taskRef,
            {
              'status': 'in_progress',
              'assignedTo': widget.currentEmail.trim(),
            },
          );
        },
      );

      if (!mounted) return;

      if (!claimed) {
        setState(() {
          isClaiming = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم استلام هذه المهمة من موظف آخر أو تم إنجازها مسبقًا',
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: Colors.orange,
          ),
        );

        Navigator.pop(context);
        return;
      }

      setState(() {
        widget.taskData['status'] = 'in_progress';
        widget.taskData['assignedTo'] =
            widget.currentEmail.trim();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم استلام المهمة بنجاح، يمكنك الآن بدء العمل عليها',
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: navy,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'حدث خطأ أثناء استلام المهمة: $e',
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isClaiming = false;
        });
      }
    }
  }

  // ============================================================
  // جلب اسم الموظف أو المسوق الحالي
  // ============================================================

  Future<String> _getCurrentUserName() async {
    final email = widget.currentEmail.trim();

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data();

        final name = (data['name'] ??
                data['fullName'] ??
                data['displayName'] ??
                data['employeeName'] ??
                '')
            .toString()
            .trim();

        if (name.isNotEmpty) {
          return name;
        }
      }
    } catch (e) {
      debugPrint('Get current user name error: $e');
    }

    final existingName =
        (widget.taskData['assignedToName'] ??
                widget.taskData['submittedByName'] ??
                widget.taskData['completedByName'] ??
                widget.taskData['submittedToAdminByName'] ??
                widget.taskData['createdByName'] ??
                '')
            .toString()
            .trim();

    if (existingName.isNotEmpty) {
      return existingName;
    }

    return email;
  }

  // ============================================================
  // إنهاء المهمة وإرسالها للمدير
  // ============================================================

  Future<bool> submitTaskToAdmin() async {
    if (isSubmittingToAdmin) return false;

    if (widget.currentEmail.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تعذر تحديد حساب الموظف الحالي',
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: Colors.red,
        ),
      );

      return false;
    }

    setState(() {
      isSubmittingToAdmin = true;
    });

    try {
      final taskRef = FirebaseFirestore.instance
          .collection('tasks')
          .doc(widget.taskId);

      final currentUserName =
          await _getCurrentUserName();

      bool submitted = false;

      await FirebaseFirestore.instance.runTransaction(
        (transaction) async {
          final snapshot = await transaction.get(taskRef);

          if (!snapshot.exists) {
            return;
          }

          final data = snapshot.data() ?? {};

          final assignedTo =
              data['assignedTo']
                      ?.toString()
                      .trim() ??
                  'لم يتم استلامها بعد';

          final status =
              data['status']?.toString() ?? '';

          // لا يستطيع المسوق إرسال المهمة
          // إلا إذا كانت قيد العمل عنده
          if (status != 'in_progress' ||
              assignedTo != widget.currentEmail.trim()) {
            return;
          }

          submitted = true;

          transaction.update(
            taskRef,
            {
              // الحالة النهائية للمهمة
              'status': 'completed',

              // هذا الحقل هو الأساس لظهورها
              // في المهام المرسلة من المسوق
              'isMarketingSubmitted': true,

              // بيانات المسوق
              'submittedBy':
                  widget.currentEmail.trim(),
              'submittedByName':
                  currentUserName,
              'submittedAt':
                  FieldValue.serverTimestamp(),

              // بيانات الإنجاز
              'completedBy':
                  widget.currentEmail.trim(),
              'completedByName':
                  currentUserName,
              'completedAt':
                  FieldValue.serverTimestamp(),

              // بيانات الإرسال للمدير
              'submittedToAdminBy':
                  widget.currentEmail.trim(),
              'submittedToAdminByName':
                  currentUserName,
              'submittedToAdminAt':
                  FieldValue.serverTimestamp(),

              // اسم المسؤول عن المهمة
              'assignedToName':
                  currentUserName,
            },
          );
        },
      );

      if (!mounted) return false;

      if (!submitted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'لا يمكنك إرسال هذه المهمة لأنها ليست مستلمة منك',
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: Colors.orange,
          ),
        );

        return false;
      }

      setState(() {
        widget.taskData['status'] = 'completed';

        widget.taskData['isMarketingSubmitted'] = true;

        widget.taskData['submittedBy'] =
            widget.currentEmail.trim();

        widget.taskData['submittedByName'] =
            currentUserName;

        widget.taskData['completedBy'] =
            widget.currentEmail.trim();

        widget.taskData['completedByName'] =
            currentUserName;

        widget.taskData['submittedToAdminBy'] =
            widget.currentEmail.trim();

        widget.taskData['submittedToAdminByName'] =
            currentUserName;

        widget.taskData['assignedToName'] =
            currentUserName;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم تنفيذ المهمة وإرسالها للمدير بنجاح',
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: Colors.green,
        ),
      );

      return true;
    } catch (e) {
      if (!mounted) return false;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'حدث خطأ أثناء إرسال المهمة للمدير: $e',
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: Colors.red,
        ),
      );

      return false;
    } finally {
      if (mounted) {
        setState(() {
          isSubmittingToAdmin = false;
        });
      }
    }
  }

  // ============================================================
  // إنهاء المهمة العادي - للمدير
  // ============================================================

  Future<bool> setCompleted() async {
    if (isCompleting) return false;

    if (widget.currentEmail.trim().isEmpty) {
      return false;
    }

    setState(() {
      isCompleting = true;
    });

    try {
      final taskRef = FirebaseFirestore.instance
          .collection('tasks')
          .doc(widget.taskId);

      bool completed = false;

      await FirebaseFirestore.instance.runTransaction(
        (transaction) async {
          final snapshot = await transaction.get(taskRef);

          if (!snapshot.exists) {
            return;
          }

          final data = snapshot.data() ?? {};

          final assignedTo =
              data['assignedTo']?.toString() ??
                  'لم يتم استلامها بعد';

          final status =
              data['status']?.toString() ?? '';

          final isMarketingSubmitted =
              data['isMarketingSubmitted'] == true;

          if (isMarketingSubmitted) {
            return;
          }

          if (status != 'in_progress' ||
              assignedTo != widget.currentEmail.trim()) {
            return;
          }

          completed = true;

          transaction.update(
            taskRef,
            {
              'status': 'completed',
              'completedBy':
                  widget.currentEmail.trim(),
              'completedAt':
                  FieldValue.serverTimestamp(),
            },
          );
        },
      );

      if (!mounted) return false;

      if (!completed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'لا يمكنك إنهاء هذه المهمة لأنها ليست مستلمة منك',
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: Colors.orange,
          ),
        );

        return false;
      }

      setState(() {
        widget.taskData['status'] = 'completed';
        widget.taskData['completedBy'] =
            widget.currentEmail.trim();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم تحديد المهمة كمنجزة بنجاح',
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: Colors.green,
        ),
      );

      return true;
    } catch (e) {
      if (!mounted) return false;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'حدث خطأ أثناء إنهاء المهمة: $e',
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: Colors.red,
        ),
      );

      return false;
    } finally {
      if (mounted) {
        setState(() {
          isCompleting = false;
        });
      }
    }
  }

  // ============================================================
  // إعادة نشر المهمة
  // ============================================================

  Future<bool> reassignTask(String reason) async {
    if (isReposting) return false;

    if (widget.currentEmail.trim().isEmpty) {
      return false;
    }

    setState(() {
      isReposting = true;
    });

    try {
      final taskRef = FirebaseFirestore.instance
          .collection('tasks')
          .doc(widget.taskId);

      bool reposted = false;

      await FirebaseFirestore.instance.runTransaction(
        (transaction) async {
          final snapshot = await transaction.get(taskRef);

          if (!snapshot.exists) {
            return;
          }

          final data = snapshot.data() ?? {};

          final assignedTo =
              data['assignedTo']?.toString() ??
                  'لم يتم استلامها بعد';

          final status =
              data['status']?.toString() ?? '';

          if (status != 'in_progress' ||
              assignedTo != widget.currentEmail.trim()) {
            return;
          }

          reposted = true;

          transaction.update(
            taskRef,
            {
              'status': 'ready',
              'assignedTo': 'لم يتم استلامها بعد',
              'repostReason': reason,
              'repostedBy':
                  widget.currentEmail.trim(),
              'repostedAt':
                  FieldValue.serverTimestamp(),
              'rejectionReason': reason,
            },
          );
        },
      );

      if (!mounted) return false;

      if (!reposted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'لا يمكنك إعادة نشر هذه المهمة لأنها ليست مستلمة منك',
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: Colors.orange,
          ),
        );

        return false;
      }

      setState(() {
        widget.taskData['status'] = 'ready';
        widget.taskData['assignedTo'] =
            'لم يتم استلامها بعد';
        widget.taskData['repostReason'] = reason;
        widget.taskData['repostedBy'] =
            widget.currentEmail.trim();
        widget.taskData['rejectionReason'] = reason;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تمت إعادة نشر المهمة وإتاحتها لجميع الموظفين',
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: Colors.orange,
        ),
      );

      return true;
    } catch (e) {
      if (!mounted) return false;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'حدث خطأ أثناء إعادة نشر المهمة: $e',
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: Colors.red,
        ),
      );

      return false;
    } finally {
      if (mounted) {
        setState(() {
          isReposting = false;
        });
      }
    }
  }

  // ============================================================
  // نافذة إعادة النشر
  // ============================================================

  void showReassignDialog() {
    reasonController.clear();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            'إعادة نشر المهمة',
            style: GoogleFonts.cairo(
              fontWeight: FontWeight.bold,
              color: navy,
            ),
          ),
          content: TextField(
            controller: reasonController,
            maxLines: 4,
            style: GoogleFonts.cairo(),
            decoration: InputDecoration(
              hintText:
                  'اكتب سبب عدم قدرتك على التعامل مع المهمة...',
              hintStyle: GoogleFonts.cairo(
                color: grey,
              ),
              border: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: navy,
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: Text(
                'إلغاء',
                style: GoogleFonts.cairo(
                  color: grey,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: isReposting
                  ? null
                  : () async {
                      final reason =
                          reasonController.text.trim();

                      if (reason.isEmpty) {
                        ScaffoldMessenger.of(
                          dialogContext,
                        ).showSnackBar(
                          SnackBar(
                            content: Text(
                              'يجب كتابة سبب إعادة نشر المهمة',
                              style:
                                  GoogleFonts.cairo(),
                            ),
                          ),
                        );
                        return;
                      }

                      final success =
                          await reassignTask(reason);

                      if (!mounted) return;

                      if (success) {
                        Navigator.pop(dialogContext);
                        Navigator.pop(context);
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: navy,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(10),
                ),
              ),
              child: Text(
                'تأكيد وإعادة نشرها',
                style: GoogleFonts.cairo(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // الصوت
  // ============================================================

  Future<void> playAudio(String url) async {
    try {
      if (isAudioPlaying) {
        await audioPlayer.pause();
      } else {
        await audioPlayer.play(
          UrlSource(url),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تعذر تشغيل التسجيل الصوتي',
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> stopAudio() async {
    try {
      await audioPlayer.stop();
    } catch (e) {
      debugPrint('Audio stop error: $e');
    }
  }

  // ============================================================
  // فتح الملف
  // ============================================================

  Future<void> openAttachmentFile(
    String url,
  ) async {
    try {
      final uri = Uri.parse(url);

      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تعذر فتح الملف',
              style: GoogleFonts.cairo(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint('Open file error: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تعذر فتح الملف',
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ============================================================
  // المرفقات
  // ============================================================

  Widget buildAttachment(
    String attachmentType,
    String attachmentUrl,
    String attachmentName,
  ) {
    final bool hasAttachment =
        attachmentUrl.isNotEmpty &&
        attachmentType.isNotEmpty &&
        attachmentType != 'none';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color: border,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: lightGrey,
                  borderRadius:
                      BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.attach_file_rounded,
                  color: navy,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'المرفق',
                style: GoogleFonts.cairo(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: navy,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          if (!hasAttachment)
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: lightGrey,
                borderRadius:
                    BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.attach_file_rounded,
                    color: grey,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'لا يوجد مرفق لهذه المهمة',
                    style: GoogleFonts.cairo(
                      color: grey,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

          if (hasAttachment &&
              attachmentType == 'image')
            ClipRRect(
              borderRadius:
                  BorderRadius.circular(14),
              child: Image.network(
                attachmentUrl,
                width: double.infinity,
                fit: BoxFit.contain,
                loadingBuilder: (
                  context,
                  child,
                  loadingProgress,
                ) {
                  if (loadingProgress == null) {
                    return child;
                  }

                  return const SizedBox(
                    height: 220,
                    child: Center(
                      child:
                          CircularProgressIndicator(
                        color: navy,
                      ),
                    ),
                  );
                },
                errorBuilder: (
                  context,
                  error,
                  stackTrace,
                ) {
                  return Container(
                    height: 150,
                    width: double.infinity,
                    alignment: Alignment.center,
                    decoration:
                        BoxDecoration(
                      color: lightGrey,
                      borderRadius:
                          BorderRadius.circular(14),
                    ),
                    child: Column(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons
                              .broken_image_outlined,
                          size: 42,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'تعذر تحميل الصورة',
                          style:
                              GoogleFonts.cairo(
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

          if (hasAttachment &&
              attachmentType == 'audio')
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: lightGrey,
                borderRadius:
                    BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration:
                        BoxDecoration(
                      color: navy,
                      borderRadius:
                          BorderRadius.circular(14),
                    ),
                    child: IconButton(
                      icon: Icon(
                        isAudioPlaying
                            ? Icons.pause_rounded
                            : Icons
                                .play_arrow_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
                      onPressed: () {
                        playAudio(attachmentUrl);
                      },
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          'تسجيل صوتي',
                          style: GoogleFonts.cairo(
                            fontSize: 12,
                            color: grey,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          attachmentName.isNotEmpty
                              ? attachmentName
                              : 'التسجيل الصوتي',
                          style: GoogleFonts.cairo(
                            fontSize: 14,
                            fontWeight:
                                FontWeight.w600,
                            color: navy,
                          ),
                          overflow:
                              TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  if (isAudioPlaying)
                    IconButton(
                      onPressed: stopAudio,
                      icon: const Icon(
                        Icons.stop_rounded,
                        color: Colors.red,
                      ),
                    ),
                ],
              ),
            ),

          if (hasAttachment &&
              attachmentType == 'video')
            Column(
              children: [
                if (isVideoReady &&
                    videoController != null)
                  ClipRRect(
                    borderRadius:
                        BorderRadius.circular(14),
                    child: AspectRatio(
                      aspectRatio:
                          videoController!
                              .value
                              .aspectRatio,
                      child: VideoPlayer(
                        videoController!,
                      ),
                    ),
                  )
                else
                  Container(
                    height: 220,
                    width: double.infinity,
                    decoration:
                        BoxDecoration(
                      color: lightGrey,
                      borderRadius:
                          BorderRadius.circular(14),
                    ),
                    child: const Center(
                      child:
                          CircularProgressIndicator(
                        color: navy,
                      ),
                    ),
                  ),

                const SizedBox(height: 10),

                if (isVideoReady &&
                    videoController != null)
                  Column(
                    children: [
                      VideoProgressIndicator(
                        videoController!,
                        allowScrubbing: true,
                        padding:
                            const EdgeInsets.symmetric(
                          vertical: 8,
                        ),
                      ),

                      const SizedBox(height: 5),

                      SizedBox(
                        width: double.infinity,
                        child:
                            ElevatedButton.icon(
                          onPressed: () {
                            if (videoController!
                                .value
                                .isPlaying) {
                              videoController!.pause();
                            } else {
                              videoController!.play();
                            }
                          },
                          icon: Icon(
                            isVideoPlaying
                                ? Icons.pause_rounded
                                : Icons
                                    .play_arrow_rounded,
                          ),
                          label: Text(
                            isVideoPlaying
                                ? 'إيقاف الفيديو'
                                : 'تشغيل الفيديو',
                            style:
                                GoogleFonts.cairo(
                              fontWeight:
                                  FontWeight.w600,
                            ),
                          ),
                          style:
                              ElevatedButton
                                  .styleFrom(
                            backgroundColor: navy,
                            foregroundColor:
                                Colors.white,
                            padding:
                                const EdgeInsets.all(
                              13,
                            ),
                            shape:
                                RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(
                                12,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                if (attachmentName.isNotEmpty)
                  Padding(
                    padding:
                        const EdgeInsets.only(
                      top: 8,
                    ),
                    child: Align(
                      alignment:
                          Alignment.centerRight,
                      child: Text(
                        attachmentName,
                        style: GoogleFonts.cairo(
                          color: grey,
                          fontSize: 12,
                        ),
                        overflow:
                            TextOverflow.ellipsis,
                      ),
                    ),
                  ),
              ],
            ),

          if (hasAttachment &&
              attachmentType == 'file')
            Container(
              padding:
                  const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: lightGrey,
                borderRadius:
                    BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration:
                            BoxDecoration(
                          color: Colors.white,
                          borderRadius:
                              BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons
                              .insert_drive_file_outlined,
                          color: navy,
                          size: 28,
                        ),
                      ),

                      const SizedBox(width: 10),

                      Expanded(
                        child: Text(
                          attachmentName.isNotEmpty
                              ? attachmentName
                              : 'ملف مرفق',
                          style: GoogleFonts.cairo(
                            fontWeight:
                                FontWeight.w600,
                            color: navy,
                          ),
                          overflow:
                              TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  SizedBox(
                    width: double.infinity,
                    child:
                        ElevatedButton.icon(
                      onPressed: () {
                        openAttachmentFile(
                          attachmentUrl,
                        );
                      },
                      icon: const Icon(
                        Icons.open_in_new_rounded,
                      ),
                      label: Text(
                        'فتح الملف',
                        style: GoogleFonts.cairo(
                          fontWeight:
                              FontWeight.w600,
                        ),
                      ),
                      style:
                          ElevatedButton.styleFrom(
                        backgroundColor: navy,
                        foregroundColor:
                            Colors.white,
                        padding:
                            const EdgeInsets.all(
                          13,
                        ),
                        shape:
                            RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(
                            12,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // فتح المحادثة
  // ============================================================

  void openChat() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TaskChatPage(
          taskId: widget.taskId,
          currentEmail: widget.currentEmail,
          currentRole: widget.currentRole,
          taskData: {
            ...widget.taskData,
            'employeeEmail':
                chatEmployeeEmail,
            'employeeName':
                widget.taskData['employeeName'] ??
                    widget.taskData['assignedToName'] ??
                    widget.taskData['submittedByName'] ??
                    widget.taskData['completedByName'] ??
                    widget.taskData['createdByName'] ??
                    chatEmployeeEmail,
          },
        ),
      ),
    );
  }

  // ============================================================
  // صف المعلومات
  // ============================================================

  Widget buildInfoRow(
    IconData icon,
    String title,
    String value,
  ) {
    return Padding(
      padding:
          const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: lightGrey,
              borderRadius:
                  BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 20,
              color: navy,
            ),
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.cairo(
                    fontSize: 11,
                    color: grey,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    fontWeight:
                        FontWeight.w600,
                    color: navy,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // زر إجراء
  // ============================================================

  Widget buildActionButton({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
    required Color color,
    bool loading = false,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child:
                    CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(icon),
        label: Text(
          label,
          style: GoogleFonts.cairo(
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          disabledBackgroundColor:
              color.withValues(alpha: .55),
          padding:
              const EdgeInsets.symmetric(
            vertical: 14,
          ),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final String assignedTo =
        widget.taskData['assignedTo']?.toString() ??
            'لم يتم استلامها بعد';

    final String status =
        widget.taskData['status']?.toString() ??
            'ready';

    final bool isMarketingSubmitted =
        widget.taskData['isMarketingSubmitted'] == true;

    final String clientName =
        widget.taskData['clientName']?.toString() ??
            'بدون اسم';

    final String phone =
        widget.taskData['phone']?.toString() ?? '';

    final String propertyType =
        widget.taskData['propertyType']?.toString() ??
            'خاص';

    final String notes =
        widget.taskData['notes']?.toString() ??
            'لا توجد ملاحظات';

    final String repostReason =
        widget.taskData['repostReason']?.toString() ??
            widget.taskData['rejectionReason']
                ?.toString() ??
            '';

    final String repostedBy =
        widget.taskData['repostedBy']?.toString() ??
            '';

    final String attachmentType =
        widget.taskData['attachmentType']?.toString() ??
            'none';

    final String attachmentUrl =
        widget.taskData['attachmentUrl']?.toString() ??
            '';

    final String attachmentName =
        widget.taskData['attachmentName']?.toString() ??
            '';

    final bool isSubmittedToAdmin =
        status == 'submitted_to_admin' ||
        isMarketingSubmitted;

    final bool isAvailable =
        (status == 'ready' ||
                status == 'pending') &&
            assignedTo ==
                'لم يتم استلامها بعد';

    final bool isMine =
        status == 'in_progress' &&
            assignedTo ==
                widget.currentEmail.trim();

    final bool isTakenByOther =
        status == 'in_progress' &&
            assignedTo !=
                'لم يتم استلامها بعد' &&
            assignedTo !=
                widget.currentEmail.trim();

    String statusText;

    if (isMarketingSubmitted) {
      statusText = 'تم الإنجاز من المسوق';
    } else if (status == 'completed') {
      statusText = 'مكتملة';
    } else if (status == 'submitted_to_admin') {
      statusText = 'مرسلة للمدير';
    } else if (isMine) {
      statusText = 'جاري العمل';
    } else if (isAvailable) {
      statusText = 'متاحة';
    } else if (isTakenByOther) {
      statusText = 'جاري العمل من موظف آخر';
    } else {
      statusText = 'متاحة';
    }

    Color statusColor;

    if (isMarketingSubmitted) {
      statusColor = Colors.blue;
    } else if (status == 'completed') {
      statusColor = Colors.green;
    } else if (status == 'submitted_to_admin') {
      statusColor = Colors.blue;
    } else if (isMine) {
      statusColor = navy;
    } else if (isTakenByOther) {
      statusColor = Colors.red;
    } else {
      statusColor = Colors.orange;
    }

    return Scaffold(
      backgroundColor: lightGrey,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: navy,
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
        title: Text(
          'تفاصيل المهمة',
          style: GoogleFonts.cairo(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            // ====================================================
            // بيانات المهمة
            // ====================================================

            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.circular(18),
                border: Border.all(
                  color: border,
                ),
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding:
                            const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor,
                          borderRadius:
                              BorderRadius.circular(
                            20,
                          ),
                        ),
                        child: Text(
                          statusText,
                          style:
                              GoogleFonts.cairo(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  Text(
                    clientName,
                    style: GoogleFonts.cairo(
                      fontSize: 22,
                      fontWeight:
                          FontWeight.bold,
                      color: navy,
                    ),
                  ),

                  const SizedBox(height: 16),

                  buildInfoRow(
                    Icons.phone_outlined,
                    'رقم الجوال',
                    phone.isNotEmpty
                        ? phone
                        : 'غير مضاف',
                  ),

                  buildInfoRow(
                    Icons.home_work_outlined,
                    'نوع العقار',
                    propertyType,
                  ),

                  const Divider(
                    color: border,
                    height: 20,
                  ),

                  Text(
                    'الملاحظات',
                    style: GoogleFonts.cairo(
                      fontSize: 15,
                      fontWeight:
                          FontWeight.bold,
                      color: navy,
                    ),
                  ),

                  const SizedBox(height: 6),

                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: lightGrey,
                      borderRadius:
                          BorderRadius.circular(
                        12,
                      ),
                    ),
                    child: Text(
                      notes,
                      style: GoogleFonts.cairo(
                        fontSize: 13,
                        color: grey,
                        height: 1.7,
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: lightGrey,
                      borderRadius:
                          BorderRadius.circular(
                        12,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.person_outline,
                          color: navy,
                          size: 21,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isMine
                                ? 'المسؤول عن المهمة: أنت'
                                : isTakenByOther
                                    ? 'المسؤول عن المهمة: $assignedTo'
                                    : isMarketingSubmitted
                                        ? 'تم تنفيذ المهمة بواسطة المسوق'
                                        : isSubmittedToAdmin
                                            ? 'تم تنفيذ المهمة وإرسالها للمدير'
                                            : 'المسؤول عن المهمة: لم يتم الاستلام بعد',
                            style:
                                GoogleFonts.cairo(
                              fontSize: 13,
                              color: isMine
                                  ? navy
                                  : isTakenByOther
                                      ? Colors.red
                                      : isMarketingSubmitted ||
                                              isSubmittedToAdmin
                                          ? Colors.blue
                                          : grey,
                              fontWeight:
                                  FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ==================================================
                  // معلومات المهمة المرسلة من المسوق
                  // ==================================================

                  if (isMarketingSubmitted)
                    Container(
                      width: double.infinity,
                      margin:
                          const EdgeInsets.only(
                        top: 14,
                      ),
                      padding:
                          const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue
                            .withValues(alpha: .08),
                        borderRadius:
                            BorderRadius.circular(
                          12,
                        ),
                        border: Border.all(
                          color: Colors.blue
                              .withValues(alpha: .20),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons
                                .assignment_turned_in_rounded,
                            color: Colors.blue,
                            size: 21,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'تم تنفيذ المهمة وإرسالها للمدير، وهي الآن ظاهرة ضمن "المهام المرسلة من المسوق".',
                              style:
                                  GoogleFonts.cairo(
                                fontSize: 12,
                                color: Colors.blue,
                                fontWeight:
                                    FontWeight.w600,
                                height: 1.6,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  if (repostReason.isNotEmpty) ...[
                    const SizedBox(height: 14),

                    Container(
                      width: double.infinity,
                      padding:
                          const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange
                            .withValues(alpha: .08),
                        borderRadius:
                            BorderRadius.circular(
                          12,
                        ),
                        border: Border.all(
                          color: Colors.orange
                              .withValues(alpha: .25),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.info_outline,
                                color: Colors.orange,
                                size: 20,
                              ),
                              const SizedBox(width: 7),
                              Text(
                                'سبب إعادة النشر',
                                style:
                                    GoogleFonts.cairo(
                                  color:
                                      Colors.orange,
                                  fontWeight:
                                      FontWeight.bold,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 6),

                          Text(
                            repostReason,
                            style:
                                GoogleFonts.cairo(
                              color:
                                  Colors.orange,
                              fontSize: 13,
                              height: 1.6,
                            ),
                          ),

                          if (repostedBy.isNotEmpty) ...[
                            const SizedBox(height: 5),
                            Text(
                              'أعاد نشرها: $repostedBy',
                              style:
                                  GoogleFonts.cairo(
                                color:
                                    Colors.orange,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // ====================================================
            // المرفق
            // ====================================================

            buildAttachment(
              attachmentType,
              attachmentUrl,
              attachmentName,
            ),

            const SizedBox(height: 18),

            // ====================================================
            // المهمة متاحة
            // ====================================================

            if (isAvailable)
              buildActionButton(
                label: isClaiming
                    ? 'جاري استلام المهمة...'
                    : 'استلام وبدء العمل',
                icon:
                    Icons.play_arrow_rounded,
                onPressed: isClaiming
                    ? null
                    : setInProgress,
                color: navy,
                loading: isClaiming,
              ),

            // ====================================================
            // المهمة قيد العمل عند المستخدم الحالي
            // ====================================================

            if (isMine) ...[
              if (isEmployeeRole)
                buildActionButton(
                  label: isSubmittingToAdmin
                      ? 'جاري إرسال المهمة للمدير...'
                      : 'إنهاء وإرسال للمدير',
                  icon: Icons.send_rounded,
                  onPressed:
                      isSubmittingToAdmin
                          ? null
                          : () async {
                              final success =
                                  await submitTaskToAdmin();

                              if (success &&
                                  mounted) {
                                Navigator.pop(
                                  context,
                                );
                              }
                            },
                  color: Colors.green,
                  loading:
                      isSubmittingToAdmin,
                )
              else
                buildActionButton(
                  label: isCompleting
                      ? 'جاري إنهاء المهمة...'
                      : 'إنهاء المهمة',
                  icon: Icons.check_rounded,
                  onPressed:
                      isCompleting
                          ? null
                          : () async {
                              final success =
                                  await setCompleted();

                              if (success &&
                                  mounted) {
                                Navigator.pop(
                                  context,
                                );
                              }
                            },
                  color: Colors.green,
                  loading: isCompleting,
                ),

              const SizedBox(height: 10),

              buildActionButton(
                label: 'إعادة نشر المهمة',
                icon: Icons.refresh_rounded,
                onPressed:
                    isReposting
                        ? null
                        : showReassignDialog,
                color: Colors.orange,
                loading: isReposting,
              ),
            ],

            // ====================================================
            // المهمة قيد العمل من موظف آخر
            // ====================================================

            if (isTakenByOther)
              Container(
                width: double.infinity,
                margin:
                    const EdgeInsets.only(top: 2),
                padding:
                    const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange
                      .withValues(alpha: .08),
                  borderRadius:
                      BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.orange
                        .withValues(alpha: .25),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.orange
                            .withValues(alpha: .12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lock_outline_rounded,
                        color: Colors.orange,
                        size: 27,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Text(
                      'هذه المهمة قيد العمل من موظف آخر',
                      textAlign:
                          TextAlign.center,
                      style: GoogleFonts.cairo(
                        color: Colors.orange,
                        fontWeight:
                            FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      'المسؤول: $assignedTo',
                      textAlign:
                          TextAlign.center,
                      style: GoogleFonts.cairo(
                        color: grey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

            // ====================================================
            // المهمة المكتملة
            // ====================================================

            if (status == 'completed')
              Container(
                width: double.infinity,
                margin:
                    const EdgeInsets.only(top: 2),
                padding:
                    const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: (isMarketingSubmitted
                          ? Colors.blue
                          : Colors.green)
                      .withValues(alpha: .08),
                  borderRadius:
                      BorderRadius.circular(16),
                  border: Border.all(
                    color: (isMarketingSubmitted
                            ? Colors.blue
                            : Colors.green)
                        .withValues(alpha: .20),
                  ),
                ),
                child: Row(
                  mainAxisAlignment:
                      MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      color: isMarketingSubmitted
                          ? Colors.blue
                          : Colors.green,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isMarketingSubmitted
                          ? 'تم إنجاز المهمة وإرسالها للمدير'
                          : 'تم إنجاز هذه المهمة',
                      style:
                          GoogleFonts.cairo(
                        color:
                            isMarketingSubmitted
                                ? Colors.blue
                                : Colors.green,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 22),

            // ====================================================
            // المحادثة
            // ====================================================

            StreamBuilder<
                DocumentSnapshot<
                    Map<String, dynamic>>>(
              stream: chatEmployeeEmail.isEmpty
                  ? null
                  : FirebaseFirestore.instance
                      .collection('employeeChats')
                      .doc(chatEmployeeId)
                      .snapshots(),
              builder: (
                context,
                snapshot,
              ) {
                int unreadCount = 0;

                if (snapshot.hasData &&
                    snapshot.data!.exists) {
                  final data =
                      snapshot.data!.data() ?? {};

                  final bool isAdmin =
                      widget.currentRole ==
                          'admin';

                  final unreadValue =
                      data[
                          isAdmin
                              ? 'unreadForAdmin'
                              : 'unreadForEmployee'];

                  unreadCount =
                      unreadValue is num
                          ? unreadValue.toInt()
                          : 0;
                }

                final bool isAdmin =
                    widget.currentRole == 'admin';

                final String chatTitle =
                    isAdmin
                        ? 'التواصل مع المسوق'
                        : 'المحادثة مع المدير';

                final String chatSubtitle =
                    isAdmin
                        ? 'تواصل مع المسوق بخصوص هذه المهمة'
                        : 'تواصل مع المدير بخصوص هذه المهمة';

                final String chatButtonLabel =
                    isAdmin
                        ? (unreadCount > 0
                            ? 'التواصل مع المسوق ($unreadCount رسالة جديدة)'
                            : 'التواصل مع المسوق')
                        : (unreadCount > 0
                            ? 'فتح المحادثة ($unreadCount رسالة جديدة)'
                            : 'فتح المحادثة مع المدير');

                return Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.circular(18),
                    border: Border.all(
                      color: border,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration:
                                BoxDecoration(
                              color: navy,
                              borderRadius:
                                  BorderRadius.circular(
                                14,
                              ),
                            ),
                            child: const Icon(
                              Icons
                                  .chat_bubble_outline,
                              color:
                                  Colors.white,
                            ),
                          ),

                          const SizedBox(width: 12),

                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment
                                      .start,
                              children: [
                                Text(
                                  chatTitle,
                                  style:
                                      GoogleFonts.cairo(
                                    fontSize: 16,
                                    fontWeight:
                                        FontWeight.bold,
                                    color: navy,
                                  ),
                                ),

                                const SizedBox(
                                  height: 2,
                                ),

                                Text(
                                  chatSubtitle,
                                  style:
                                      GoogleFonts.cairo(
                                    color: grey,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          if (unreadCount > 0)
                            Container(
                              padding:
                                  const EdgeInsets
                                      .symmetric(
                                horizontal: 8,
                                vertical: 5,
                              ),
                              decoration:
                                  BoxDecoration(
                                color: Colors.red,
                                borderRadius:
                                    BorderRadius
                                        .circular(
                                  20,
                                ),
                              ),
                              child: Text(
                                '$unreadCount',
                                style:
                                    GoogleFonts.cairo(
                                  color:
                                      Colors.white,
                                  fontSize: 10,
                                  fontWeight:
                                      FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),

                      const SizedBox(height: 15),

                      SizedBox(
                        width: double.infinity,
                        child:
                            ElevatedButton.icon(
                          onPressed: openChat,
                          icon: const Icon(
                            Icons
                                .chat_bubble_rounded,
                          ),
                          label: Text(
                            chatButtonLabel,
                            style:
                                GoogleFonts.cairo(
                              fontWeight:
                                  FontWeight.w600,
                            ),
                          ),
                          style:
                              ElevatedButton
                                  .styleFrom(
                            backgroundColor: navy,
                            foregroundColor:
                                Colors.white,
                            padding:
                                const EdgeInsets.all(
                              13,
                            ),
                            elevation: 0,
                            shape:
                                RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(
                                12,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}