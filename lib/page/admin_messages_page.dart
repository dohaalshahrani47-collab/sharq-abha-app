import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

import 'task_chat_page.dart';

class AdminMessagesPage extends StatelessWidget {
  const AdminMessagesPage({super.key});

  static const Color navy = Color(0xFF172B4D);
  static const Color navy2 = Color(0xFF243B5A);
  static const Color grey = Color(0xFF6B7280);
  static const Color lightGrey = Color(0xFFF3F5F8);
  static const Color border = Color(0xFFE1E5EA);

  // ============================================================
  // تحويل الإيميل إلى ID آمن
  // ============================================================

  String employeeChatId(String email) {
    return email.trim().replaceAll('/', '_');
  }

  // ============================================================
  // الوقت
  // ============================================================

  String formatTime(Timestamp? timestamp) {
    if (timestamp == null) return '';

    final date = timestamp.toDate();

    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  // ============================================================
  // استخراج اسم المستخدم
  // ============================================================

  String getUserName(Map<String, dynamic> data, String fallback) {
    final possibleNames = [
      data['name'],
      data['fullName'],
      data['displayName'],
      data['employeeName'],
      data['submittedByName'],
      data['completedByName'],
      data['assignedToName'],
      data['createdByName'],
      data['submittedToAdminByName'],
    ];

    for (final value in possibleNames) {
      final name = value?.toString().trim() ?? '';

      if (name.isNotEmpty) {
        return name;
      }
    }

    return fallback;
  }

  // ============================================================
  // الصفحة
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final currentEmail =
        FirebaseAuth.instance.currentUser?.email?.trim() ?? '';

    return Scaffold(
      backgroundColor: lightGrey,

      appBar: AppBar(
        backgroundColor: navy,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
        title: Text(
          'رسائل الموظفين',
          style: GoogleFonts.cairo(
            color: Colors.white,
            fontSize: 19,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('employeeChats')
            .snapshots(),

        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(25),
                child: Text(
                  'حدث خطأ:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cairo(
                    color: Colors.red,
                    fontSize: 14,
                  ),
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(
                color: navy,
              ),
            );
          }

          final docs = snapshot.data!.docs.toList();

          // --------------------------------------------------------
          // إظهار المحادثات التي لديها رسالة فقط
          // --------------------------------------------------------

          docs.removeWhere((doc) {
            final data = doc.data();

            final lastMessage =
                data['lastMessage']?.toString().trim() ?? '';

            return lastMessage.isEmpty;
          });

          // --------------------------------------------------------
          // ترتيب الأحدث أولاً
          // --------------------------------------------------------

          docs.sort((a, b) {
            final aTime = a.data()['lastMessageAt'];
            final bTime = b.data()['lastMessageAt'];

            final aTimestamp =
                aTime is Timestamp ? aTime : null;

            final bTimestamp =
                bTime is Timestamp ? bTime : null;

            if (aTimestamp == null && bTimestamp == null) {
              return 0;
            }

            if (aTimestamp == null) {
              return 1;
            }

            if (bTimestamp == null) {
              return -1;
            }

            return bTimestamp.compareTo(aTimestamp);
          });

          // --------------------------------------------------------
          // إجمالي غير المقروء
          // --------------------------------------------------------

          int totalUnread = 0;

          for (final doc in docs) {
            final unread = doc.data()['unreadForAdmin'];

            if (unread is num) {
              totalUnread += unread.toInt();
            }
          }

          // ========================================================
          // الواجهة
          // ========================================================

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  6,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _ActionCard(
                        icon: Icons.add_comment_outlined,
                        title: 'رسالة جديدة',
                        subtitle: 'إرسال رسالة لموظف',
                        onTap: () {
                          _showNewMessageSheet(context);
                        },
                      ),
                    ),

                    const SizedBox(width: 12),

                    Expanded(
                      child: _ActionCard(
                        icon: Icons.mark_chat_unread_outlined,
                        title: 'الرسائل',
                        subtitle: totalUnread > 0
                            ? '$totalUnread رسالة جديدة'
                            : 'جميع الرسائل',
                        badge: totalUnread > 0
                            ? totalUnread
                            : null,
                        onTap: () {},
                      ),
                    ),
                  ],
                ),
              ),

              // ----------------------------------------------------
              // لا توجد رسائل
              // ----------------------------------------------------

              if (docs.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: border,
                            ),
                          ),
                          child: const Icon(
                            Icons.chat_bubble_outline,
                            color: grey,
                            size: 45,
                          ),
                        ),

                        const SizedBox(height: 18),

                        Text(
                          'لا توجد رسائل',
                          style: GoogleFonts.cairo(
                            color: navy,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 5),

                        Text(
                          'يمكنك بدء محادثة جديدة من الزر أعلاه',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.cairo(
                            color: grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                )

              // ----------------------------------------------------
              // قائمة المحادثات
              // ----------------------------------------------------

              else
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      14,
                      10,
                      14,
                      20,
                    ),
                    itemCount: docs.length,

                    itemBuilder: (context, index) {
                      final chat = docs[index];
                      final data = chat.data();

                      final employeeEmail =
                          data['employeeEmail']
                                  ?.toString()
                                  .trim() ??
                              '';

                      if (employeeEmail.isEmpty) {
                        return const SizedBox.shrink();
                      }

                      final employeeName =
                          getUserName(
                        data,
                        employeeEmail,
                      );

                      final lastTaskId =
                          data['lastTaskId']
                                  ?.toString()
                                  .trim() ??
                              '';

                      // ------------------------------------------------
                      // البيانات التي سترسل إلى TaskChatPage
                      // ------------------------------------------------

                      final taskData = <String, dynamic>{
                        'assignedTo': employeeEmail,
                        'assignedToName': employeeName,
                        'employeeEmail': employeeEmail,
                        'employeeName': employeeName,

                        // حقول إضافية لضمان ظهور الاسم
                        'submittedBy': employeeEmail,
                        'submittedByName': employeeName,
                        'completedBy': employeeEmail,
                        'completedByName': employeeName,
                        'createdBy': employeeEmail,
                        'createdByName': employeeName,
                      };

                      return _ConversationCard(
                        employeeName: employeeName,
                        employeeEmail: employeeEmail,
                        data: data,
                        formatTime: formatTime,

                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TaskChatPage(
                                taskId: lastTaskId,
                                currentEmail: currentEmail,
                                currentRole: 'admin',
                                taskData: taskData,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  // ============================================================
  // رسالة جديدة
  // ============================================================

  Future<void> _showNewMessageSheet(
    BuildContext context,
  ) async {
    final messageController = TextEditingController();

    String? selectedEmployee;
    String selectedEmployeeName = '';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(25),
        ),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  18,
                  14,
                  18,
                  MediaQuery.of(context).viewInsets.bottom + 18,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Center(
                        child: Container(
                          width: 45,
                          height: 5,
                          decoration: BoxDecoration(
                            color: border,
                            borderRadius:
                                BorderRadius.circular(20),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      Text(
                        'إرسال رسالة جديدة',
                        style: GoogleFonts.cairo(
                          color: navy,
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 5),

                      Text(
                        'اختاري الموظف ثم اكتبي رسالتك',
                        style: GoogleFonts.cairo(
                          color: grey,
                          fontSize: 11,
                        ),
                      ),

                      const SizedBox(height: 20),

                      Text(
                        'الموظف',
                        style: GoogleFonts.cairo(
                          color: navy,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 8),

                      StreamBuilder<
                          QuerySnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .where(
                              'role',
                              isEqualTo: 'marketing',
                            )
                            .where(
                              'status',
                              isEqualTo: 'approved',
                            )
                            .snapshots(),

                        builder: (
                          context,
                          userSnapshot,
                        ) {
                          if (userSnapshot.connectionState ==
                              ConnectionState.waiting) {
                            return _loadingBox();
                          }

                          if (userSnapshot.hasError) {
                            return _errorBox(
                              'تعذر تحميل الموظفين',
                            );
                          }

                          final users =
                              userSnapshot.data?.docs ?? [];

                          if (users.isEmpty) {
                            return _errorBox(
                              'لا يوجد موظفون معتمدون',
                            );
                          }

                          return Container(
                            decoration: BoxDecoration(
                              color: lightGrey,
                              borderRadius:
                                  BorderRadius.circular(14),
                              border: Border.all(
                                color: border,
                              ),
                            ),
                            padding:
                                const EdgeInsets.symmetric(
                              horizontal: 14,
                            ),
                            child:
                                DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: selectedEmployee,
                                isExpanded: true,

                                hint: Text(
                                  'اختاري الموظف',
                                  style:
                                      GoogleFonts.cairo(
                                    color: grey,
                                    fontSize: 12,
                                  ),
                                ),

                                icon: const Icon(
                                  Icons
                                      .keyboard_arrow_down_rounded,
                                  color: navy,
                                ),

                                items: users.map((doc) {
                                  final data = doc.data();

                                  final email =
                                      data['email']
                                              ?.toString()
                                              .trim() ??
                                          doc.id;

                                  final name =
                                      getUserName(
                                    data,
                                    email,
                                  );

                                  return DropdownMenuItem<
                                      String>(
                                    value: email,
                                    child: Text(
                                      name,
                                      overflow:
                                          TextOverflow.ellipsis,
                                      style:
                                          GoogleFonts.cairo(
                                        color: navy,
                                        fontSize: 12,
                                      ),
                                    ),
                                  );
                                }).toList(),

                                onChanged: (value) {
                                  if (value == null) {
                                    return;
                                  }

                                  final selectedUser =
                                      users.where((doc) {
                                    final data = doc.data();

                                    final email =
                                        data['email']
                                                ?.toString()
                                                .trim() ??
                                            doc.id;

                                    return email == value;
                                  }).toList();

                                  String name = value;

                                  if (selectedUser.isNotEmpty) {
                                    name = getUserName(
                                      selectedUser.first.data(),
                                      value,
                                    );
                                  }

                                  setModalState(() {
                                    selectedEmployee = value;
                                    selectedEmployeeName = name;
                                  });
                                },
                              ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 18),

                      Text(
                        'الرسالة',
                        style: GoogleFonts.cairo(
                          color: navy,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 8),

                      Container(
                        decoration: BoxDecoration(
                          color: lightGrey,
                          borderRadius:
                              BorderRadius.circular(14),
                          border: Border.all(
                            color: border,
                          ),
                        ),
                        child: TextField(
                          controller: messageController,
                          minLines: 4,
                          maxLines: 6,
                          textDirection:
                              TextDirection.rtl,
                          style: GoogleFonts.cairo(
                            color: navy,
                            fontSize: 13,
                          ),
                          decoration: InputDecoration(
                            hintText:
                                'اكتبي رسالتك هنا...',
                            hintStyle:
                                GoogleFonts.cairo(
                              color: grey,
                              fontSize: 12,
                            ),
                            border: InputBorder.none,
                            contentPadding:
                                const EdgeInsets.all(14),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            if (selectedEmployee == null ||
                                selectedEmployee!
                                    .trim()
                                    .isEmpty) {
                              _showMessage(
                                context,
                                'اختاري الموظف أولاً',
                                Colors.red,
                              );
                              return;
                            }

                            final message =
                                messageController.text.trim();

                            if (message.isEmpty) {
                              _showMessage(
                                context,
                                'اكتبي الرسالة أولاً',
                                Colors.red,
                              );
                              return;
                            }

                            final currentUser =
                                FirebaseAuth
                                    .instance
                                    .currentUser;

                            final currentEmail =
                                currentUser
                                        ?.email
                                        ?.trim() ??
                                    '';

                            if (currentEmail.isEmpty) {
                              _showMessage(
                                context,
                                'تعذر تحديد حساب المدير',
                                Colors.red,
                              );
                              return;
                            }

                            final email =
                                selectedEmployee!.trim();

                            final chatId =
                                employeeChatId(email);

                            final firestore =
                                FirebaseFirestore.instance;

                            final chatRef = firestore
                                .collection('employeeChats')
                                .doc(chatId);

                            final messageRef = chatRef
                                .collection('messages')
                                .doc();

                            try {
                              // ------------------------------------
                              // إضافة الرسالة
                              // ------------------------------------

                              await messageRef.set({
                                'taskId': '',
                                'employeeEmail': email,
                                'senderEmail':
                                    currentEmail,
                                'senderRole': 'admin',
                                'message': message,
                                'messageType': 'text',
                                'createdAt':
                                    FieldValue
                                        .serverTimestamp(),
                                'read': false,
                              });

                              // ------------------------------------
                              // تحديث المحادثة
                              // ------------------------------------

                              await chatRef.set(
                                {
                                  'employeeEmail': email,
                                  'employeeName':
                                      selectedEmployeeName
                                              .trim()
                                              .isNotEmpty
                                          ? selectedEmployeeName
                                          : email,

                                  'lastMessage': message,

                                  'lastMessageAt':
                                      FieldValue
                                          .serverTimestamp(),

                                  'lastMessageSenderEmail':
                                      currentEmail,

                                  'lastMessageSenderRole':
                                      'admin',

                                  'unreadForEmployee':
                                      FieldValue.increment(1),

                                  // المدير قرأ رسائله السابقة
                                  'unreadForAdmin': 0,
                                },
                                SetOptions(
                                  merge: true,
                                ),
                              );

                              if (!context.mounted) {
                                return;
                              }

                              Navigator.of(
                                sheetContext,
                              ).pop();

                              ScaffoldMessenger.of(context)
                                ..hideCurrentSnackBar()
                                ..showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'تم إرسال الرسالة بنجاح',
                                      style:
                                          GoogleFonts.cairo(
                                        color:
                                            Colors.white,
                                      ),
                                    ),
                                    backgroundColor: navy,
                                    behavior:
                                        SnackBarBehavior
                                            .floating,
                                    shape:
                                        RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(
                                        12,
                                      ),
                                    ),
                                  ),
                                );
                            } catch (e) {
                              _showMessage(
                                context,
                                'تعذر إرسال الرسالة:\n$e',
                                Colors.red,
                              );
                            }
                          },
                          icon: const Icon(
                            Icons.send_rounded,
                            color: Colors.white,
                          ),
                          label: Text(
                            'إرسال الرسالة',
                            style: GoogleFonts.cairo(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style:
                              ElevatedButton.styleFrom(
                            backgroundColor: navy,
                            elevation: 0,
                            shape:
                                RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    messageController.dispose();
  }

  // ============================================================
  // Loading
  // ============================================================

  Widget _loadingBox() {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: lightGrey,
        borderRadius:
            BorderRadius.circular(14),
        border: Border.all(
          color: border,
        ),
      ),
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: navy,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // Error
  // ============================================================

  Widget _errorBox(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: .06),
        borderRadius:
            BorderRadius.circular(14),
        border: Border.all(
          color: Colors.red.withValues(alpha: .20),
        ),
      ),
      child: Text(
        text,
        style: GoogleFonts.cairo(
          color: Colors.red,
          fontSize: 11,
        ),
      ),
    );
  }

  // ============================================================
  // رسالة
  // ============================================================

  void _showMessage(
    BuildContext context,
    String text,
    Color color,
  ) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            text,
            style: GoogleFonts.cairo(
              color: Colors.white,
            ),
          ),
          backgroundColor: color,
          behavior:
              SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(12),
          ),
        ),
      );
  }
}

// ============================================================================
// الزر العلوي
// ============================================================================

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final int? badge;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
  });

  static const Color navy =
      Color(0xFF172B4D);

  static const Color grey =
      Color(0xFF6B7280);

  static const Color lightGrey =
      Color(0xFFF3F5F8);

  static const Color border =
      Color(0xFFE1E5EA);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color: border,
        ),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withValues(
              alpha: .035,
            ),
            blurRadius: 8,
            offset:
                const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius:
              BorderRadius.circular(18),
          child: Padding(
            padding:
                const EdgeInsets.all(13),
            child: Row(
              children: [
                Container(
                  width: 43,
                  height: 43,
                  decoration:
                      BoxDecoration(
                    color: lightGrey,
                    borderRadius:
                        BorderRadius.circular(
                      13,
                    ),
                  ),
                  child: Icon(
                    icon,
                    color: navy,
                    size: 22,
                  ),
                ),

                const SizedBox(width: 9),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style:
                            GoogleFonts.cairo(
                          color: navy,
                          fontSize: 12,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow:
                            TextOverflow.ellipsis,
                        style:
                            GoogleFonts.cairo(
                          color: grey,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                ),

                if (badge != null)
                  Container(
                    constraints:
                        const BoxConstraints(
                      minWidth: 24,
                      minHeight: 24,
                    ),
                    padding:
                        const EdgeInsets
                            .symmetric(
                      horizontal: 6,
                    ),
                    decoration:
                        BoxDecoration(
                      color: Colors.red,
                      borderRadius:
                          BorderRadius.circular(
                        20,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '$badge',
                        style:
                            GoogleFonts.cairo(
                          color:
                              Colors.white,
                          fontSize: 9,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// بطاقة المحادثة
// ============================================================================

class _ConversationCard extends StatelessWidget {
  final String employeeName;
  final String employeeEmail;
  final Map<String, dynamic> data;
  final String Function(Timestamp?) formatTime;
  final VoidCallback onTap;

  const _ConversationCard({
    required this.employeeName,
    required this.employeeEmail,
    required this.data,
    required this.formatTime,
    required this.onTap,
  });

  static const Color navy =
      Color(0xFF172B4D);

  static const Color navy2 =
      Color(0xFF243B5A);

  static const Color grey =
      Color(0xFF6B7280);

  static const Color lightGrey =
      Color(0xFFF3F5F8);

  static const Color border =
      Color(0xFFE1E5EA);

  @override
  Widget build(BuildContext context) {
    final lastMessage =
        data['lastMessage']?.toString() ?? '';

    final lastMessageRole =
        data['lastMessageSenderRole']
                ?.toString() ??
            '';

    final lastMessageAt =
        data['lastMessageAt'] is Timestamp
            ? data['lastMessageAt']
                as Timestamp
            : null;

    final unread =
        data['unreadForAdmin'];

    final unreadCount =
        unread is num
            ? unread.toInt()
            : 0;

    final isUnread =
        unreadCount > 0;

    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 12,
      ),
      decoration:
          BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(17),
        border: Border.all(
          color: isUnread
              ? navy
              : border,
          width:
              isUnread
                  ? 1.3
                  : 1,
        ),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withValues(
              alpha: .035,
            ),
            blurRadius: 8,
            offset:
                const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color:
            Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius:
              BorderRadius.circular(
            17,
          ),
          child: Padding(
            padding:
                const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration:
                      BoxDecoration(
                    color: isUnread
                        ? navy
                        : lightGrey,
                    shape:
                        BoxShape.circle,
                  ),
                  child: Icon(
                    isUnread
                        ? Icons
                            .mark_chat_unread_outlined
                        : Icons
                            .chat_bubble_outline,
                    color: isUnread
                        ? Colors.white
                        : navy,
                    size: 24,
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              employeeName,
                              maxLines: 1,
                              overflow:
                                  TextOverflow
                                      .ellipsis,
                              style:
                                  GoogleFonts.cairo(
                                color:
                                    navy,
                                fontSize:
                                    15,
                                fontWeight:
                                    FontWeight
                                        .bold,
                              ),
                            ),
                          ),

                          if (isUnread)
                            Container(
                              padding:
                                  const EdgeInsets
                                      .symmetric(
                                horizontal:
                                    8,
                                vertical:
                                    3,
                              ),
                              decoration:
                                  BoxDecoration(
                                color:
                                    Colors.red,
                                borderRadius:
                                    BorderRadius
                                        .circular(
                                  20,
                                ),
                              ),
                              child: Text(
                                '$unreadCount',
                                style:
                                    GoogleFonts
                                        .cairo(
                                  color:
                                      Colors.white,
                                  fontSize:
                                      10,
                                  fontWeight:
                                      FontWeight
                                          .bold,
                                ),
                              ),
                            ),
                        ],
                      ),

                      if (employeeEmail
                          .isNotEmpty)
                        Padding(
                          padding:
                              const EdgeInsets
                                  .only(
                            top: 3,
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons
                                    .email_outlined,
                                color:
                                    grey,
                                size: 14,
                              ),
                              const SizedBox(
                                  width: 4),
                              Expanded(
                                child: Text(
                                  employeeEmail,
                                  maxLines: 1,
                                  overflow:
                                      TextOverflow
                                          .ellipsis,
                                  style:
                                      GoogleFonts
                                          .cairo(
                                    color:
                                        grey,
                                    fontSize:
                                        10,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 7),

                      Row(
                        children: [
                          Text(
                            lastMessageRole ==
                                        'marketing' ||
                                    lastMessageRole ==
                                        'employee'
                                ? 'الموظف: '
                                : 'أنت: ',
                            style:
                                GoogleFonts.cairo(
                              color:
                                  lastMessageRole ==
                                              'marketing' ||
                                          lastMessageRole ==
                                              'employee'
                                      ? navy2
                                      : grey,
                              fontSize:
                                  11,
                              fontWeight:
                                  FontWeight
                                      .bold,
                            ),
                          ),

                          Expanded(
                            child: Text(
                              lastMessage,
                              maxLines: 1,
                              overflow:
                                  TextOverflow
                                      .ellipsis,
                              style:
                                  GoogleFonts.cairo(
                                color:
                                    isUnread
                                        ? navy
                                        : grey,
                                fontSize:
                                    11,
                                fontWeight:
                                    isUnread
                                        ? FontWeight
                                            .bold
                                        : FontWeight
                                            .normal,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 4),

                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.end,
                        children: [
                          if (lastMessageAt !=
                              null)
                            Text(
                              formatTime(
                                lastMessageAt,
                              ),
                              style:
                                  GoogleFonts.cairo(
                                color:
                                    grey,
                                fontSize:
                                    9,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 5),

                Container(
                  width: 30,
                  height: 30,
                  decoration:
                      BoxDecoration(
                    color: lightGrey,
                    borderRadius:
                        BorderRadius.circular(
                      9,
                    ),
                  ),
                  child: const Icon(
                    Icons
                        .arrow_forward_ios_rounded,
                    color: grey,
                    size: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}