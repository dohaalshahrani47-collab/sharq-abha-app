
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:video_player/video_player.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:google_fonts/google_fonts.dart';

class TaskChatPage extends StatefulWidget {
  final String taskId;
  final String currentEmail;
  final String currentRole;
  final Map<String, dynamic> taskData;

  const TaskChatPage({
    super.key,
    required this.taskId,
    required this.currentEmail,
    required this.currentRole,
    required this.taskData,
  });

  @override
  State<TaskChatPage> createState() => _TaskChatPageState();
}

class _TaskChatPageState extends State<TaskChatPage> {
  static const Color navy = Color(0xFF172B4D);
  static const Color navy2 = Color(0xFF243B5A);
  static const Color grey = Color(0xFF6B7280);
  static const Color lightGrey = Color(0xFFF3F5F8);
  static const Color border = Color(0xFFE1E5EA);

  final TextEditingController messageController =
      TextEditingController();

  final ScrollController scrollController =
      ScrollController();

  final AudioRecorder audioRecorder =
      AudioRecorder();

  bool isSending = false;
  bool isRecording = false;

  DateTime? recordingStartedAt;

  bool get isAdmin =>
      widget.currentRole == 'admin';

  String get otherRole =>
      isAdmin ? 'marketing' : 'admin';

  // المحادثة أصبحت مرتبطة بالموظف وليس بالمهمة.
  String get employeeEmail {
    if (widget.currentRole == 'marketing') {
      return widget.currentEmail.trim();
    }

    final fromData =
        widget.taskData['employeeEmail']?.toString().trim() ?? '';
    if (fromData.isNotEmpty) {
      return fromData;
    }

    return widget.taskData['assignedTo']?.toString().trim() ?? '';
  }

  String get employeeName {
    final name =
        widget.taskData['employeeName']?.toString().trim() ?? '';
    if (name.isNotEmpty) return name;

    final assignedName =
        widget.taskData['assignedToName']?.toString().trim() ?? '';
    if (assignedName.isNotEmpty) return assignedName;

    return employeeEmail;
  }

  String get employeeChatId =>
      employeeEmail.replaceAll('/', '_');

  DocumentReference<Map<String, dynamic>> get chatReference =>
      FirebaseFirestore.instance
          .collection('employeeChats')
          .doc(employeeChatId);

  CollectionReference<Map<String, dynamic>> get messagesReference =>
      chatReference.collection('messages');

  @override
  void initState() {
    super.initState();

    // تحديث الأيقونة عند الكتابة
    messageController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      markMessagesAsRead();
    });
  }

  @override
  void dispose() {
    messageController.dispose();
    scrollController.dispose();
    audioRecorder.dispose();
    super.dispose();
  }

  Future<void> markMessagesAsRead() async {
    if (employeeEmail.isEmpty) return;

    try {
      final messagesSnapshot = await messagesReference
          .where('senderRole', isEqualTo: otherRole)
          .where('read', isEqualTo: false)
          .get();

      final batch = FirebaseFirestore.instance.batch();

      for (final doc in messagesSnapshot.docs) {
        batch.update(doc.reference, {'read': true});
      }

      batch.set(
        chatReference,
        {
          isAdmin ? 'unreadForAdmin' : 'unreadForEmployee': 0,
        },
        SetOptions(merge: true),
      );

      await batch.commit();
    } catch (e) {
      debugPrint('MARK READ ERROR: $e');
    }
  }

  Future<void> sendMessage() async {
    final message =
        messageController.text.trim();

    if (message.isEmpty || isSending) {
      return;
    }

    await sendMessageData(
      message: message,
      messageType: 'text',
    );

    if (mounted) {
      messageController.clear();
    }
  }

  Future<void> _writeMessageData({
    String message = '',
    String messageType = 'text',
    String? attachmentUrl,
    String? attachmentName,
    String? attachmentType,
    int? attachmentSize,
  }) async {
    if (message.trim().isEmpty && attachmentUrl == null) {
      return;
    }

    if (employeeEmail.isEmpty) {
      throw Exception('لم يتم العثور على بريد الموظف');
    }

    final messageData = <String, dynamic>{
      'taskId': widget.taskId,
      'employeeEmail': employeeEmail,
      'senderEmail': widget.currentEmail.trim(),
      'senderRole': widget.currentRole,
      'message': message.trim(),
      'messageType': messageType,
      'createdAt': FieldValue.serverTimestamp(),
      'read': false,
    };

    if (attachmentUrl != null) {
      messageData['attachmentUrl'] = attachmentUrl;
      messageData['attachmentName'] = attachmentName ?? '';
      messageData['attachmentType'] = attachmentType ?? '';

      if (attachmentSize != null) {
        messageData['attachmentSize'] = attachmentSize;
      }
    }

    // جميع رسائل الموظف تذهب إلى محادثة الموظف نفسها.
    await messagesReference.add(messageData);

    String lastMessageText = message.trim();

    if (messageType == 'image') {
      lastMessageText = '📷 صورة';
    } else if (messageType == 'video') {
      lastMessageText = '🎥 فيديو';
    } else if (messageType == 'audio') {
      lastMessageText = '🎙️ تسجيل صوتي';
    } else if (messageType == 'file') {
      lastMessageText = '📎 ${attachmentName ?? 'ملف'}';
    }

    final updateData = <String, dynamic>{
      'employeeEmail': employeeEmail,
      'employeeName': employeeName,
      'lastMessage': lastMessageText,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessageSenderEmail': widget.currentEmail.trim(),
      'lastMessageSenderRole': widget.currentRole,
    };

    // نحتفظ بآخر مهمة فقط كمعلومة مرجعية، ولا نستخدمها لتحديد المحادثة.
    if (widget.taskId.trim().isNotEmpty) {
      updateData['lastTaskId'] = widget.taskId;
    }

    if (widget.currentRole == 'marketing') {
      updateData['unreadForAdmin'] = FieldValue.increment(1);
    } else if (widget.currentRole == 'admin') {
      updateData['unreadForEmployee'] = FieldValue.increment(1);
    }

    await chatReference.set(
      updateData,
      SetOptions(merge: true),
    );

    await Future.delayed(const Duration(milliseconds: 150));

    if (scrollController.hasClients) {
      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> sendMessageData({
    String message = '',
    String messageType = 'text',
    String? attachmentUrl,
    String? attachmentName,
    String? attachmentType,
    int? attachmentSize,
  }) async {
    if (isSending) {
      return;
    }

    if (message.trim().isEmpty &&
        attachmentUrl == null) {
      return;
    }

    setState(() {
      isSending = true;
    });

    try {
      await _writeMessageData(
        message: message,
        messageType: messageType,
        attachmentUrl: attachmentUrl,
        attachmentName: attachmentName,
        attachmentType: attachmentType,
        attachmentSize: attachmentSize,
      );
    } catch (e) {
      debugPrint(
        'SEND MESSAGE ERROR: $e',
      );

      if (!mounted) return;

      showError(
        'تعذر إرسال الرسالة:\n$e',
      );
    } finally {
      if (mounted) {
        setState(() {
          isSending = false;
        });
      }
    }
  }

  Future<void> uploadAttachment({
    required Uint8List bytes,
    required String fileName,
    required String messageType,
    String? mimeType,
  }) async {
    if (bytes.isEmpty ||
        isSending ||
        isRecording) {
      return;
    }

    setState(() {
      isSending = true;
    });

    try {
      final safeFileName =
          fileName.replaceAll(
        RegExp(
          r'[^a-zA-Z0-9._-]',
        ),
        '_',
      );

      final timestamp =
          DateTime.now()
              .millisecondsSinceEpoch;

      final storagePath =
          'chat/$employeeChatId/${timestamp}_$safeFileName';

      final storageReference =
          FirebaseStorage.instance
              .ref()
              .child(storagePath);

      final metadata =
          SettableMetadata(
        contentType:
            mimeType ??
                'application/octet-stream',
      );

      await storageReference.putData(
        bytes,
        metadata,
      );

      final downloadUrl =
          await storageReference
              .getDownloadURL();

      await _writeMessageData(
        messageType: messageType,
        attachmentUrl: downloadUrl,
        attachmentName: fileName,
        attachmentType:
            mimeType ??
                'application/octet-stream',
        attachmentSize:
            bytes.length,
      );
    } catch (e) {
      debugPrint(
        'UPLOAD ATTACHMENT ERROR: $e',
      );

      if (!mounted) return;

      showError(
        'تعذر رفع الملف:\n$e',
      );
    } finally {
      if (mounted) {
        setState(() {
          isSending = false;
        });
      }
    }
  }

  Future<void> pickImage() async {
    if (isSending || isRecording) {
      return;
    }

    try {
      final picker =
          ImagePicker();

      final XFile? image =
          await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );

      if (image == null) {
        return;
      }

      final bytes =
          await image.readAsBytes();

      await uploadAttachment(
        bytes: bytes,
        fileName:
            image.name.isNotEmpty
                ? image.name
                : 'image.jpg',
        messageType: 'image',
        mimeType: 'image/jpeg',
      );
    } catch (e) {
      showError(
        'تعذر اختيار الصورة:\n$e',
      );
    }
  }

  Future<void> pickVideo() async {
    if (isSending || isRecording) {
      return;
    }

    try {
      final picker =
          ImagePicker();

      final XFile? video =
          await picker.pickVideo(
        source: ImageSource.gallery,
      );

      if (video == null) {
        return;
      }

      final bytes =
          await video.readAsBytes();

      String mimeType =
          'video/mp4';

      final lower =
          video.name.toLowerCase();

      if (lower.endsWith('.mov')) {
        mimeType =
            'video/quicktime';
      } else if (lower.endsWith('.webm')) {
        mimeType =
            'video/webm';
      }

      await uploadAttachment(
        bytes: bytes,
        fileName:
            video.name.isNotEmpty
                ? video.name
                : 'video.mp4',
        messageType: 'video',
        mimeType: mimeType,
      );
    } catch (e) {
      showError(
        'تعذر اختيار الفيديو:\n$e',
      );
    }
  }

  Future<void> pickFile() async {
    if (isSending || isRecording) {
      return;
    }

    try {
      final files =
          await FilePicker.pickFiles();

      if (files.isEmpty) {
        return;
      }

      final file =
          files.first;

      final bytes =
          await file.readAsBytes();

      String mimeType =
          'application/octet-stream';

      final extension =
          file.extension?.toLowerCase();

      if (extension == 'pdf') {
        mimeType =
            'application/pdf';
      } else if (extension == 'doc') {
        mimeType =
            'application/msword';
      } else if (extension == 'docx') {
        mimeType =
            'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      } else if (extension == 'xls') {
        mimeType =
            'application/vnd.ms-excel';
      } else if (extension == 'xlsx') {
        mimeType =
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      } else if (extension == 'zip') {
        mimeType =
            'application/zip';
      } else if (extension == 'txt') {
        mimeType =
            'text/plain';
      } else if (extension == 'mp3') {
        mimeType =
            'audio/mpeg';
      } else if (extension == 'm4a') {
        mimeType =
            'audio/mp4';
      } else if (extension == 'wav') {
        mimeType =
            'audio/wav';
      }

      await uploadAttachment(
        bytes: bytes,
        fileName: file.name,
        messageType: 'file',
        mimeType: mimeType,
      );
    } catch (e) {
      showError(
        'تعذر اختيار الملف:\n$e',
      );
    }
  }
    Future<void> startRecording() async {
    if (isSending || isRecording) {
      return;
    }

    try {
      final hasPermission =
          await audioRecorder.hasPermission();

      if (!hasPermission) {
        showError(
          'لا يوجد إذن لاستخدام الميكروفون',
        );
        return;
      }

      String path = '';

      if (!kIsWeb) {
        final directory =
            await getTemporaryDirectory();

        path =
            '${directory.path}/chat_${DateTime.now().millisecondsSinceEpoch}.wav';
      }

      await audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 44100,
          numChannels: 1,
        ),
        path: path,
      );

      setState(() {
        isRecording = true;
        recordingStartedAt =
            DateTime.now();
      });
    } catch (e) {
      showError(
        'تعذر بدء التسجيل:\n$e',
      );
    }
  }

  Future<void> stopRecording() async {
    if (!isRecording) {
      return;
    }

    try {
      final duration =
          recordingStartedAt == null
              ? Duration.zero
              : DateTime.now().difference(
                  recordingStartedAt!,
                );

      final path =
          await audioRecorder.stop();

      if (mounted) {
        setState(() {
          isRecording = false;
          recordingStartedAt = null;
        });
      }

      if (path == null ||
          path.isEmpty) {
        showError(
          'لم يتم إنشاء التسجيل الصوتي',
        );
        return;
      }

      if (duration.inMilliseconds < 500) {
        showError(
          'سجلي لمدة أطول قليلاً',
        );
        return;
      }

      final audioFile =
          XFile(path);

      final bytes =
          await audioFile.readAsBytes();

      final fileName =
          'recording_${DateTime.now().millisecondsSinceEpoch}.wav';

      await uploadAttachment(
        bytes: bytes,
        fileName: fileName,
        messageType: 'audio',
        mimeType: 'audio/wav',
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          isRecording = false;
          recordingStartedAt = null;
        });
      }

      showError(
        'تعذر إرسال التسجيل:\n$e',
      );
    }
  }

  Future<void> cancelRecording() async {
    if (!isRecording) {
      return;
    }

    try {
      await audioRecorder.cancel();

      if (mounted) {
        setState(() {
          isRecording = false;
          recordingStartedAt = null;
        });
      }
    } catch (e) {
      debugPrint(
        'CANCEL RECORDING ERROR: $e',
      );
    }
  }

  Future<void> showAttachmentMenu() async {
    if (isSending || isRecording) return;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape:
          const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding:
                const EdgeInsets.fromLTRB(
              20,
              12,
              20,
              20,
            ),
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                Container(
                  width: 45,
                  height: 5,
                  decoration:
                      BoxDecoration(
                    color: border,
                    borderRadius:
                        BorderRadius.circular(
                      20,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'إرسال مرفق',
                  style:
                      GoogleFonts.cairo(
                    fontSize: 18,
                    fontWeight:
                        FontWeight.bold,
                    color: navy,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment:
                      MainAxisAlignment
                          .spaceEvenly,
                  children: [
                    _attachmentOption(
                      icon: Icons
                          .photo_outlined,
                      title: 'صورة',
                      onTap: () async {
                        Navigator.pop(
                          context,
                        );
                        await pickImage();
                      },
                    ),
                    _attachmentOption(
                      icon: Icons
                          .video_library_outlined,
                      title: 'فيديو',
                      onTap: () async {
                        Navigator.pop(
                          context,
                        );
                        await pickVideo();
                      },
                    ),
                    _attachmentOption(
                      icon: Icons
                          .insert_drive_file_outlined,
                      title: 'ملف',
                      onTap: () async {
                        Navigator.pop(
                          context,
                        );
                        await pickFile();
                      },
                    ),
                    _attachmentOption(
                      icon: Icons
                          .mic_none_rounded,
                      title: 'تسجيل',
                      onTap: () async {
                        Navigator.pop(
                          context,
                        );
                        await startRecording();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _attachmentOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius:
          BorderRadius.circular(16),
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration:
                BoxDecoration(
              color: lightGrey,
              borderRadius:
                  BorderRadius.circular(
                16,
              ),
            ),
            child: Icon(
              icon,
              color: navy,
              size: 28,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            title,
            style: GoogleFonts.cairo(
              fontSize: 12,
              color: grey,
              fontWeight:
                  FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> openFile(
    String url,
  ) async {
    try {
      final uri =
          Uri.parse(url);

      if (!await launchUrl(
        uri,
        mode:
            LaunchMode.externalApplication,
      )) {
        showError(
          'تعذر فتح الملف',
        );
      }
    } catch (e) {
      showError(
        'تعذر فتح الملف',
      );
    }
  }

  Widget buildImageMessage(
    String url,
  ) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) {
              return Scaffold(
                backgroundColor:
                    Colors.black,
                appBar: AppBar(
                  backgroundColor:
                      Colors.black,
                  foregroundColor:
                      Colors.white,
                ),
                body: Center(
                  child:
                      InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4,
                    child:
                        Image.network(
                      url,
                      fit: BoxFit
                          .contain,
                      loadingBuilder:
                          (
                        context,
                        child,
                        loadingProgress,
                      ) {
                        if (loadingProgress ==
                            null) {
                          return child;
                        }

                        return const CircularProgressIndicator(
                          color: Colors
                              .white,
                        );
                      },
                      errorBuilder:
                          (
                        context,
                        error,
                        stackTrace,
                      ) {
                        return const Icon(
                          Icons
                              .broken_image_outlined,
                          color: Colors
                              .white,
                          size: 60,
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
      child: ClipRRect(
        borderRadius:
            BorderRadius.circular(
          14,
        ),
        child: Image.network(
          url,
          width: 230,
          height: 230,
          fit: BoxFit.cover,
          loadingBuilder:
              (
            context,
            child,
            loadingProgress,
          ) {
            if (loadingProgress ==
                null) {
              return child;
            }

            return Container(
              width: 230,
              height: 230,
              color: lightGrey,
              child: const Center(
                child:
                    CircularProgressIndicator(),
              ),
            );
          },
          errorBuilder:
              (
            context,
            error,
            stackTrace,
          ) {
            return Container(
              width: 230,
              height: 150,
              color: lightGrey,
              child: const Icon(
                Icons
                    .broken_image_outlined,
                color: grey,
                size: 45,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget buildVideoMessage(
    String url,
  ) {
    return VideoMessageWidget(
      url: url,
    );
  }

  Widget buildAudioMessage(
    String url,
  ) {
    return AudioMessageWidget(
      url: url,
    );
  }

  Widget buildFileMessage({
    required String url,
    required String fileName,
  }) {
    return InkWell(
      onTap: () =>
          openFile(url),
      borderRadius:
          BorderRadius.circular(14),
      child: Container(
        width: 250,
        padding:
            const EdgeInsets.all(12),
        decoration:
            BoxDecoration(
          color: lightGrey,
          borderRadius:
              BorderRadius.circular(
            14,
          ),
          border: Border.all(
            color: border,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration:
                  BoxDecoration(
                color: navy,
                borderRadius:
                    BorderRadius.circular(
                  12,
                ),
              ),
              child: const Icon(
                Icons
                    .insert_drive_file_outlined,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                fileName,
                maxLines: 2,
                overflow:
                    TextOverflow.ellipsis,
                style:
                    GoogleFonts.cairo(
                  fontSize: 12,
                  fontWeight:
                      FontWeight.w600,
                  color: navy,
                ),
              ),
            ),
            const SizedBox(width: 5),
            const Icon(
              Icons
                  .open_in_new_rounded,
              color: grey,
              size: 19,
            ),
          ],
        ),
      ),
    );
  }

  Widget buildMessageBubble(
    QueryDocumentSnapshot<
            Map<String, dynamic>>
        messageDoc,
  ) {
    final data =
        messageDoc.data();

    final senderRole =
        data['senderRole']
                ?.toString() ??
            '';

    final isMine =
        senderRole ==
            widget.currentRole;

    final messageType =
        data['messageType']
                ?.toString() ??
            'text';

    // تم تصحيح أسماء الحقول هنا
    final text =
        data['message']
                ?.toString() ??
            '';

    final fileUrl =
        data['attachmentUrl']
                ?.toString() ??
            '';

    final fileName =
        data['attachmentName']
                ?.toString() ??
            'ملف';

    final createdAt =
        data['createdAt']
            as Timestamp?;

    final time =
        createdAt != null
            ? formatTime(
                createdAt.toDate(),
              )
            : '';

    final bubbleColor =
        isMine
            ? navy
            : Colors.white;

    final textColor =
        isMine
            ? Colors.white
            : navy;

    return Align(
      alignment: isMine
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: Container(
        constraints:
            BoxConstraints(
          maxWidth:
              MediaQuery.of(context)
                      .size
                      .width *
                  0.78,
        ),
        margin:
            const EdgeInsets.only(
          bottom: 10,
          left: 12,
          right: 12,
        ),
        padding:
            const EdgeInsets.all(10),
        decoration:
            BoxDecoration(
          color: bubbleColor,
          borderRadius:
              BorderRadius.only(
            topLeft:
                const Radius
                    .circular(18),
            topRight:
                const Radius
                    .circular(18),
            bottomLeft:
                Radius.circular(
              isMine ? 18 : 4,
            ),
            bottomRight:
                Radius.circular(
              isMine ? 4 : 18,
            ),
          ),
          border: isMine
              ? null
              : Border.all(
                  color: border,
                ),
          boxShadow: [
            BoxShadow(
              color: Colors.black
                  .withValues(
                alpha: .04,
              ),
              blurRadius: 6,
              offset:
                  const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment
                  .start,
          children: [
            if (messageType ==
                    'image' &&
                fileUrl.isNotEmpty)
              buildImageMessage(
                fileUrl,
              ),
            if (messageType ==
                    'video' &&
                fileUrl.isNotEmpty)
              buildVideoMessage(
                fileUrl,
              ),
            if (messageType ==
                    'audio' &&
                fileUrl.isNotEmpty)
              buildAudioMessage(
                fileUrl,
              ),
            if (messageType ==
                    'file' &&
                fileUrl.isNotEmpty)
              buildFileMessage(
                url: fileUrl,
                fileName: fileName,
              ),
            if (messageType ==
                    'text' &&
                text.isNotEmpty)
              Text(
                text,
                style:
                    GoogleFonts.cairo(
                  color: textColor,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            if (time.isNotEmpty) ...[
              const SizedBox(height: 5),
              Align(
                alignment:
                    Alignment.bottomRight,
                child: Text(
                  time,
                  style:
                      GoogleFonts.cairo(
                    fontSize: 9,
                    color: isMine
                        ? Colors.white70
                        : grey,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String formatTime(
    DateTime dateTime,
  ) {
    final hour =
        dateTime.hour == 0
            ? 12
            : dateTime.hour > 12
                ? dateTime.hour - 12
                : dateTime.hour;

    final minute =
        dateTime.minute
            .toString()
            .padLeft(2, '0');

    final period =
        dateTime.hour >= 12
            ? 'م'
            : 'ص';

    return '$hour:$minute $period';
  }

  void showError(
    String message,
  ) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style:
                GoogleFonts.cairo(
              color: Colors.white,
            ),
          ),
          backgroundColor: navy,
          behavior:
              SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(
              12,
            ),
          ),
        ),
      );
  }
    @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor: lightGrey,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: navy,
        foregroundColor:
            Colors.white,
        centerTitle: true,
        title: Text(
          'المحادثة',
          style: GoogleFonts.cairo(
            fontSize: 18,
            fontWeight:
                FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            decoration:
                const BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom:
                    BorderSide(
                  color: border,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration:
                      BoxDecoration(
                    color: lightGrey,
                    borderRadius:
                        BorderRadius
                            .circular(
                      13,
                    ),
                  ),
                  child: const Icon(
                    Icons
                        .task_alt_rounded,
                    color: navy,
                    size: 24,
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
                        isAdmin ? employeeName : 'المدير',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.cairo(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: navy,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isAdmin
                            ? employeeEmail
                            : 'المحادثة مع المدير',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.cairo(
                          fontSize: 11,
                          color: grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: StreamBuilder<
                QuerySnapshot<
                    Map<String, dynamic>>>(
              stream:
                  messagesReference
                      .orderBy('createdAt')
                      .snapshots(),
              builder:
                  (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'حدث خطأ في تحميل المحادثة',
                      style:
                          GoogleFonts.cairo(
                        color: grey,
                        fontSize: 14,
                      ),
                    ),
                  );
                }

                if (snapshot
                        .connectionState ==
                    ConnectionState
                        .waiting) {
                  return const Center(
                    child:
                        CircularProgressIndicator(
                      color: navy,
                    ),
                  );
                }

                final messages =
                    snapshot.data?.docs ??
                        [];

                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment:
                          MainAxisAlignment
                              .center,
                      children: [
                        Container(
                          width: 75,
                          height: 75,
                          decoration:
                              BoxDecoration(
                            color:
                                Colors.white,
                            borderRadius:
                                BorderRadius
                                    .circular(
                              22,
                            ),
                          ),
                          child:
                              const Icon(
                            Icons
                                .chat_bubble_outline_rounded,
                            color: navy,
                            size: 35,
                          ),
                        ),
                        const SizedBox(
                          height: 15,
                        ),
                        Text(
                          'لا توجد رسائل بعد',
                          style:
                              GoogleFonts
                                  .cairo(
                            color: navy,
                            fontSize: 15,
                            fontWeight:
                                FontWeight
                                    .bold,
                          ),
                        ),
                        const SizedBox(
                          height: 4,
                        ),
                        Text(
                          'ابدأ المحادثة الآن',
                          style:
                              GoogleFonts
                                  .cairo(
                            color: grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller:
                      scrollController,
                  padding:
                      const EdgeInsets
                          .only(
                    top: 16,
                    bottom: 12,
                  ),
                  itemCount:
                      messages.length,
                  itemBuilder:
                      (context, index) {
                    return buildMessageBubble(
                      messages[index],
                    );
                  },
                );
              },
            ),
          ),

          if (isRecording)
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              decoration:
                  const BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(
                    color: border,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration:
                        BoxDecoration(
                      color: Colors.red
                          .withValues(
                        alpha: .10,
                      ),
                      shape:
                          BoxShape.circle,
                    ),
                    child:
                        const Icon(
                      Icons.mic,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(
                    width: 10,
                  ),
                  Expanded(
                    child: Text(
                      'جارٍ تسجيل الصوت...',
                      style:
                          GoogleFonts.cairo(
                        color: navy,
                        fontSize: 13,
                        fontWeight:
                            FontWeight
                                .w600,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed:
                        cancelRecording,
                    icon:
                        const Icon(
                      Icons.close_rounded,
                      color: grey,
                    ),
                  ),
                  Container(
                    decoration:
                        BoxDecoration(
                      color: navy,
                      borderRadius:
                          BorderRadius
                              .circular(
                        12,
                      ),
                    ),
                    child:
                        IconButton(
                      onPressed:
                          stopRecording,
                      icon:
                          const Icon(
                        Icons
                            .send_rounded,
                        color:
                            Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          if (!isRecording)
            Container(
              padding:
                  const EdgeInsets
                      .fromLTRB(
                10,
                8,
                10,
                10,
              ),
              decoration:
                  const BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(
                    color: border,
                  ),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .end,
                  children: [
                    Container(
                      width: 45,
                      height: 45,
                      decoration:
                          BoxDecoration(
                        color: lightGrey,
                        borderRadius:
                            BorderRadius
                                .circular(
                          14,
                        ),
                      ),
                      child: IconButton(
                        onPressed:
                            isSending
                                ? null
                                : showAttachmentMenu,
                        icon:
                            const Icon(
                          Icons.add_rounded,
                          color: navy,
                        ),
                      ),
                    ),

                    const SizedBox(
                      width: 8,
                    ),

                    Expanded(
                      child: Container(
                        constraints:
                            const BoxConstraints(
                          minHeight: 45,
                          maxHeight: 120,
                        ),
                        decoration:
                            BoxDecoration(
                          color:
                              lightGrey,
                          borderRadius:
                              BorderRadius
                                  .circular(
                            16,
                          ),
                          border:
                              Border.all(
                            color: border,
                          ),
                        ),
                        child:
                            TextField(
                          controller:
                              messageController,
                          minLines: 1,
                          maxLines: 5,
                          textInputAction:
                              TextInputAction
                                  .newline,
                          style:
                              GoogleFonts.cairo(
                            fontSize: 13,
                            color: navy,
                          ),
                          decoration:
                              InputDecoration(
                            hintText:
                                'اكتب رسالتك...',
                            hintStyle:
                                GoogleFonts
                                    .cairo(
                              fontSize: 12,
                              color: grey,
                            ),
                            border:
                                InputBorder
                                    .none,
                            contentPadding:
                                const EdgeInsets
                                    .symmetric(
                              horizontal: 14,
                              vertical: 11,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(
                      width: 8,
                    ),

                    Container(
                      width: 45,
                      height: 45,
                      decoration:
                          BoxDecoration(
                        color: navy,
                        borderRadius:
                            BorderRadius
                                .circular(
                          14,
                        ),
                      ),
                      child: IconButton(
                        onPressed:
                            isSending
                                ? null
                                : () async {
                                    // تم إصلاح زر الإرسال
                                    if (messageController
                                        .text
                                        .trim()
                                        .isNotEmpty) {
                                      await sendMessage();
                                    } else {
                                      await startRecording();
                                    }
                                  },
                        icon: Icon(
                          messageController
                                  .text
                                  .trim()
                                  .isNotEmpty
                              ? Icons
                                  .send_rounded
                              : Icons
                                  .mic_none_rounded,
                          color:
                              Colors.white,
                          size: 21,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// =====================================================
// Audio Message Widget
// =====================================================

class AudioMessageWidget
    extends StatefulWidget {
  final String url;

  const AudioMessageWidget({
    super.key,
    required this.url,
  });

  @override
  State<AudioMessageWidget>
      createState() =>
          _AudioMessageWidgetState();
}

class _AudioMessageWidgetState
    extends State<AudioMessageWidget> {
  final AudioPlayer player =
      AudioPlayer();

  bool isPlaying = false;

  Duration duration =
      Duration.zero;

  Duration position =
      Duration.zero;

  @override
  void initState() {
    super.initState();

    player.onDurationChanged.listen(
      (value) {
        if (!mounted) return;

        setState(() {
          duration = value;
        });
      },
    );

    player.onPositionChanged.listen(
      (value) {
        if (!mounted) return;

        setState(() {
          position = value;
        });
      },
    );

    player.onPlayerComplete.listen(
      (_) {
        if (!mounted) return;

        setState(() {
          isPlaying = false;
          position = Duration.zero;
        });
      },
    );
  }

  Future<void> togglePlay() async {
    try {
      if (isPlaying) {
        await player.pause();

        if (!mounted) return;

        setState(() {
          isPlaying = false;
        });
      } else {
        await player.play(
          UrlSource(widget.url),
        );

        if (!mounted) return;

        setState(() {
          isPlaying = true;
        });
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'تعذر تشغيل التسجيل الصوتي',
            style:
                GoogleFonts.cairo(),
          ),
        ),
      );
    }
  }

  String formatDuration(
    Duration value,
  ) {
    final minutes =
        value.inMinutes
            .toString()
            .padLeft(2, '0');

    final seconds =
        (value.inSeconds % 60)
            .toString()
            .padLeft(2, '0');

    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final maxValue =
        duration.inMilliseconds > 0
            ? duration.inMilliseconds
                .toDouble()
            : 1.0;

    final currentValue =
        position.inMilliseconds
            .toDouble()
            .clamp(
              0.0,
              maxValue,
            );

    return Container(
      width: 260,
      padding:
          const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),
      decoration:
          BoxDecoration(
        color:
            const Color(0xFFF3F5F8),
        borderRadius:
            BorderRadius.circular(
          14,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration:
                BoxDecoration(
              color:
                  const Color(
                0xFF172B4D,
              ),
              borderRadius:
                  BorderRadius.circular(
                12,
              ),
            ),
            child: IconButton(
              padding:
                  EdgeInsets.zero,
              onPressed:
                  togglePlay,
              icon: Icon(
                isPlaying
                    ? Icons.pause_rounded
                    : Icons
                        .play_arrow_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),

          const SizedBox(width: 6),

          Expanded(
            child: SliderTheme(
              data:
                  SliderTheme.of(
                context,
              ).copyWith(
                trackHeight: 3,
                thumbShape:
                    const RoundSliderThumbShape(
                  enabledThumbRadius: 5,
                ),
                overlayShape:
                    const RoundSliderOverlayShape(
                  overlayRadius: 10,
                ),
              ),
              child: Slider(
                min: 0,
                max: maxValue,
                value: currentValue,
                onChanged:
                    duration.inMilliseconds ==
                            0
                        ? null
                        : (value) async {
                            await player
                                .seek(
                              Duration(
                                milliseconds:
                                    value
                                        .toInt(),
                              ),
                            );
                          },
              ),
            ),
          ),

          Text(
            formatDuration(
              isPlaying
                  ? position
                  : duration,
            ),
            style:
                GoogleFonts.cairo(
              fontSize: 9,
              color:
                  const Color(
                0xFF6B7280,
              ),
              fontWeight:
                  FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================
// Video Message Widget
// =====================================================

class VideoMessageWidget
    extends StatefulWidget {
  final String url;

  const VideoMessageWidget({
    super.key,
    required this.url,
  });

  @override
  State<VideoMessageWidget>
      createState() =>
          _VideoMessageWidgetState();
}

class _VideoMessageWidgetState
    extends State<VideoMessageWidget> {
  late VideoPlayerController
      controller;

  @override
  void initState() {
    super.initState();

    controller =
        VideoPlayerController
            .networkUrl(
      Uri.parse(
        widget.url,
      ),
    );

    controller.initialize().then(
      (_) {
        if (!mounted) return;

        setState(() {});
      },
    );

    controller.addListener(() {
      if (!mounted) return;

      setState(() {});
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    if (!controller
        .value
        .isInitialized) {
      return Container(
        width: 250,
        height: 180,
        decoration:
            BoxDecoration(
          color:
              const Color(
            0xFFF3F5F8,
          ),
          borderRadius:
              BorderRadius.circular(
            14,
          ),
        ),
        child: const Center(
          child:
              CircularProgressIndicator(
            color:
                Color(0xFF172B4D),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        if (controller
            .value
            .isPlaying) {
          controller.pause();
        } else {
          controller.play();
        }
      },
      child: ClipRRect(
        borderRadius:
            BorderRadius.circular(
          14,
        ),
        child: Stack(
          alignment:
              Alignment.center,
          children: [
            SizedBox(
              width: 250,
              height: 180,
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: controller
                      .value
                      .size
                      .width,
                  height: controller
                      .value
                      .size
                      .height,
                  child: VideoPlayer(
                    controller,
                  ),
                ),
              ),
            ),

            if (!controller
                .value
                .isPlaying)
              Container(
                width: 52,
                height: 52,
                decoration:
                    BoxDecoration(
                  color: Colors.black
                      .withValues(
                    alpha: .55,
                  ),
                  shape:
                      BoxShape.circle,
                ),
                child:
                    const Icon(
                  Icons
                      .play_arrow_rounded,
                  color:
                      Colors.white,
                  size: 32,
                ),
              ),

            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child:
                  VideoProgressIndicator(
                controller,
                allowScrubbing:
                    true,
                padding:
                    const EdgeInsets
                        .only(
                  top: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}