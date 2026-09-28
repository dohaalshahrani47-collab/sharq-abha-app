import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

import 'task_details_page.dart';
import 'real_estate_page.dart';
import 'send_report_page.dart';

class EmployeeTasksPage extends StatefulWidget {
  const EmployeeTasksPage({super.key});

  @override
  State<EmployeeTasksPage> createState() => _EmployeeTasksPageState();
}

class _EmployeeTasksPageState extends State<EmployeeTasksPage> {
  final User? currentUser = FirebaseAuth.instance.currentUser;

  String get currentEmail => currentUser?.email ?? '';

  String get currentUserName {
    final name = currentUser?.displayName?.trim() ?? '';

    if (name.isNotEmpty) {
      return name;
    }

    return currentEmail;
  }

  int selectedIndex = 0;

  // ============================================================
  // ألوان التصميم
  // ============================================================

  static const Color navy = Color(0xFF172B4D);
  static const Color navy2 = Color(0xFF243B5A);
  static const Color grey = Color(0xFF6B7280);
  static const Color lightGrey = Color(0xFFF3F5F8);
  static const Color border = Color(0xFFE1E5EA);
  static const Color green = Color(0xFF16A34A);
  static const Color orange = Color(0xFFF59E0B);
  static const Color blue = Color(0xFF2563EB);
  static const Color purple = Color(0xFF7C3AED);
  static const Color red = Color(0xFFDC2626);

  // ============================================================
  // التحقق من أن المهمة غير مستلمة
  // ============================================================

  bool isUnassigned(dynamic value) {
    final assigned = value?.toString().trim() ?? '';

    return assigned.isEmpty || assigned == 'لم يتم استلامها بعد';
  }

  // ============================================================
  // الصفحة الرئيسية
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final pages = [
      buildTasksPage(),
      const RealEstatesPage(
        userRole: 'marketing',
      ),
      const SendReportPage(),
    ];

    return Scaffold(
      backgroundColor: lightGrey,
      body: IndexedStack(
        index: selectedIndex,
        children: pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedIndex,
        onTap: (index) {
          setState(() {
            selectedIndex = index;
          });
        },
        backgroundColor: Colors.white,
        selectedItemColor: navy,
        unselectedItemColor: grey,
        type: BottomNavigationBarType.fixed,
        elevation: 12,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment_outlined),
            activeIcon: Icon(Icons.assignment),
            label: 'المهام',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.home_work_outlined),
            activeIcon: Icon(Icons.home_work),
            label: 'العقارات',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.description_outlined),
            activeIcon: Icon(Icons.description),
            label: 'التقارير',
          ),
        ],
      ),
    );
  }

  // ============================================================
  // صفحة المهام
  // ============================================================

  Widget buildTasksPage() {
    return Scaffold(
      backgroundColor: lightGrey,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'المهام',
          style: GoogleFonts.cairo(
            color: navy,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'إرسال مهمة منجزة',
            onPressed: showSendCompletedTaskDialog,
            icon: const Icon(
              Icons.add_task,
              color: navy,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: showSendCompletedTaskDialog,
        backgroundColor: navy,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_task),
        label: Text(
          'إرسال مهمة منجزة',
          style: GoogleFonts.cairo(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          // ======================================================
          // تعريف المسوق الحالي
          // ======================================================

          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: border,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: navy.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.person_outline,
                    color: navy,
                    size: 25,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'مرحبًا',
                        style: GoogleFonts.cairo(
                          color: grey,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        currentUserName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.cairo(
                          color: navy,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: navy.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'مسوق',
                    style: GoogleFonts.cairo(
                      color: navy,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ======================================================
          // قائمة المهام
          // ======================================================

          Expanded(
            flex: 4,
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('tasks')
                  .orderBy(
                    'createdAt',
                    descending: true,
                  )
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        'حدث خطأ:\n${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.cairo(
                          color: red,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                }

                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: navy,
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return buildEmptyTasks();
                }

                final tasks = snapshot.data!.docs;

                // ==================================================
                // فلترة مهام المسوق
                // ==================================================

                final activeTasks = tasks.where((doc) {
                  final data =
                      doc.data() as Map<String, dynamic>;

                  final assignedTo =
                      data['assignedTo']?.toString().trim() ?? '';

                  final status =
                      data['status']?.toString().trim() ?? 'ready';

                  final unassigned =
                      isUnassigned(assignedTo);

                  // المهام المرسلة من المسوق للمدير
                  // لا تظهر ضمن قائمة المهام النشطة
                  if (data['isMarketingSubmitted'] == true) {
                    return false;
                  }

                  // المهام المكتملة لا تظهر في القائمة
                  if (status == 'completed') {
                    return false;
                  }

                  // المهام المتاحة للجميع
                  if (status == 'ready' ||
                      status == 'pending') {
                    return unassigned;
                  }

                  // المهمة تظهر فقط لمن استلمها
                  if (status == 'in_progress') {
                    return assignedTo == currentEmail;
                  }

                  return false;
                }).toList();

                if (activeTasks.isEmpty) {
                  return buildEmptyTasks();
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(
                    left: 14,
                    right: 14,
                    top: 4,
                    bottom: 100,
                  ),
                  itemCount: activeTasks.length,
                  itemBuilder: (context, index) {
                    final task = activeTasks[index];

                    final data =
                        task.data() as Map<String, dynamic>;

                    return buildTaskCard(
                      context,
                      task,
                      data,
                    );
                  },
                );
              },
            ),
          ),

          // ======================================================
          // الإحصائيات
          // ======================================================

          Expanded(
            flex: 1,
            child: buildStatistics(),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // كرت المهمة
  // ============================================================

  Widget buildTaskCard(
    BuildContext context,
    QueryDocumentSnapshot task,
    Map<String, dynamic> data,
  ) {
    final assignedTo =
        data['assignedTo']?.toString().trim() ?? '';

    final status =
        data['status']?.toString().trim() ?? 'ready';

    final unreadCount =
        ((data['unreadForEmployee'] ?? 0) as num).toInt();

    final repostReason =
        data['repostReason']?.toString() ?? '';

    final unassigned =
        isUnassigned(assignedTo);

    final isMine =
        status == 'in_progress' &&
        assignedTo == currentEmail;

    final isAvailable =
        (status == 'ready' ||
            status == 'pending') &&
        unassigned;

    final isReposted =
        isAvailable &&
        repostReason.trim().isNotEmpty;

    final assignedName =
        data['assignedToName']?.toString().trim() ?? '';

    String statusText;
    Color statusColor;
    IconData statusIcon;

    if (isMine) {
      statusText = 'قيد العمل';
      statusColor = blue;
      statusIcon = Icons.work_outline;
    } else if (isReposted) {
      statusText = 'إعادة نشر';
      statusColor = orange;
      statusIcon = Icons.refresh;
    } else {
      statusText = 'مهمة جديدة';
      statusColor = green;
      statusIcon = Icons.fiber_new;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: border,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => TaskDetailsPage(
                  taskId: task.id,
                  taskData: data,
                  currentEmail: currentEmail,
                  currentRole: 'marketing',
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                // ==================================================
                // رأس الكرت
                // ==================================================

                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: navy.withValues(alpha: 0.08),
                        borderRadius:
                            BorderRadius.circular(13),
                      ),
                      child: const Icon(
                        Icons.assignment_outlined,
                        color: navy,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            'مهمة تسويقية',
                            style: GoogleFonts.cairo(
                              color: navy,
                              fontSize: 15,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'رقم الجوال: ${data['phone'] ?? 'غير متوفر'}',
                            style: GoogleFonts.cairo(
                              color: grey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (unreadCount > 0)
                      Container(
                        padding:
                            const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: red,
                          borderRadius:
                              BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize:
                              MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.chat_bubble_outline,
                              color: Colors.white,
                              size: 13,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$unreadCount',
                              style: GoogleFonts.cairo(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(width: 5),
                    const Icon(
                      Icons.arrow_forward_ios,
                      color: grey,
                      size: 15,
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // ==================================================
                // حالة المهمة
                // ==================================================

                Row(
                  children: [
                    Container(
                      padding:
                          const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor
                            .withValues(alpha: 0.10),
                        borderRadius:
                            BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize:
                            MainAxisSize.min,
                        children: [
                          Icon(
                            statusIcon,
                            color: statusColor,
                            size: 14,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            statusText,
                            style: GoogleFonts.cairo(
                              color: statusColor,
                              fontSize: 11,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    if (isMine)
                      Text(
                        'أنت المسؤول',
                        style: GoogleFonts.cairo(
                          color: blue,
                          fontSize: 11,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 14),

                // ==================================================
                // تفاصيل المهمة
                // ==================================================

                buildTaskInfoRow(
                  Icons.home_work_outlined,
                  'نوع العقار',
                  data['propertyType']?.toString() ??
                      'خاص',
                ),

                const SizedBox(height: 8),

                buildTaskInfoRow(
                  Icons.assignment_outlined,
                  'نوع المهمة',
                  data['taskType']?.toString() ??
                      'غير محدد',
                ),

                const SizedBox(height: 8),

                buildTaskInfoRow(
                  Icons.person_outline,
                  'المسؤول',
                  isMine
                      ? currentUserName
                      : assignedName.isNotEmpty
                          ? assignedName
                          : 'لم يتم الاستلام بعد',
                ),

                // ==================================================
                // الملاحظات
                // ==================================================

                if ((data['notes']?.toString() ?? '')
                    .trim()
                    .isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: lightGrey,
                      borderRadius:
                          BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.notes_outlined,
                          color: grey,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            data['notes'].toString(),
                            maxLines: 3,
                            overflow:
                                TextOverflow.ellipsis,
                            style:
                                GoogleFonts.cairo(
                              color: grey,
                              fontSize: 12,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // ==================================================
                // المرفق
                // ==================================================

                if ((data['attachmentName']
                            ?.toString() ??
                        '')
                    .trim()
                    .isNotEmpty ||
                    (data['attachmentType']
                            ?.toString() ??
                        '')
                        .trim()
                        .isNotEmpty) ...[
                  const SizedBox(height: 10),
                  buildTaskInfoRow(
                    Icons.attach_file,
                    'المرفق',
                    data['attachmentName']
                            ?.toString() ??
                        data['attachmentType']
                            ?.toString() ??
                        'مرفق',
                  ),
                ],

                // ==================================================
                // سبب إعادة النشر
                // ==================================================

                if (isReposted &&
                    repostReason.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: orange
                          .withValues(alpha: 0.08),
                      borderRadius:
                          BorderRadius.circular(12),
                      border: Border.all(
                        color: orange
                            .withValues(alpha: 0.20),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.refresh,
                          color: orange,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'سبب إعادة النشر: '
                            '$repostReason',
                            style:
                                GoogleFonts.cairo(
                              color: orange,
                              fontSize: 12,
                              fontWeight:
                                  FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // ==================================================
                // رسالة جديدة من المدير
                // ==================================================

                if (unreadCount > 0) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: red
                          .withValues(alpha: 0.06),
                      borderRadius:
                          BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.mark_chat_unread_outlined,
                          color: red,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'لديك $unreadCount رسالة جديدة من المدير',
                            style:
                                GoogleFonts.cairo(
                              color: red,
                              fontSize: 12,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 14),

                // ==================================================
                // فتح التفاصيل
                // ==================================================

                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: navy,
                    borderRadius:
                        BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      isMine
                          ? 'فتح المهمة والمحادثة مع المدير'
                          : 'فتح تفاصيل المهمة',
                      style: GoogleFonts.cairo(
                        color: Colors.white,
                        fontSize: 12,
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

  // ============================================================
  // صف معلومات المهمة
  // ============================================================

  Widget buildTaskInfoRow(
    IconData icon,
    String title,
    String value,
  ) {
    return Row(
      children: [
        Icon(
          icon,
          color: grey,
          size: 18,
        ),
        const SizedBox(width: 8),
        Text(
          '$title:',
          style: GoogleFonts.cairo(
            color: grey,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.cairo(
              color: navy,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // الحالة الفارغة
  // ============================================================

  Widget buildEmptyTasks() {
    return Center(
      child: Column(
        mainAxisAlignment:
            MainAxisAlignment.center,
        children: [
          Container(
            width: 75,
            height: 75,
            decoration: BoxDecoration(
              color: navy.withValues(alpha: 0.07),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.assignment_outlined,
              color: navy,
              size: 38,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'لا توجد مهام متاحة حالياً',
            style: GoogleFonts.cairo(
              color: navy,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'ستظهر هنا المهام الجديدة المرسلة لك',
            style: GoogleFonts.cairo(
              color: grey,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // الإحصائيات
  // ============================================================

  Widget buildStatistics() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('tasks')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final allTasks = snapshot.data!.docs;

        // ========================================================
        // المنجزة الخاصة بهذا المسوق
        // ========================================================

        final completed =
            allTasks.where((d) {
          final data =
              d.data() as Map<String, dynamic>;

          return data['status'] == 'completed' &&
              data['assignedTo'] == currentEmail &&
              data['isMarketingSubmitted'] != true;
        }).length;

        // ========================================================
        // المعاد نشرها
        // ========================================================

        final reposted =
            allTasks.where((d) {
          final data =
              d.data() as Map<String, dynamic>;

          final status =
              data['status']?.toString().trim() ??
                  'ready';

          final assignedTo =
              data['assignedTo']?.toString().trim() ??
                  '';

          final repostReason =
              data['repostReason']?.toString() ?? '';

          return (status == 'ready' ||
                  status == 'pending') &&
              isUnassigned(assignedTo) &&
              repostReason.trim().isNotEmpty;
        }).length;

        // ========================================================
        // الجديدة
        // ========================================================

        final newTasks =
            allTasks.where((d) {
          final data =
              d.data() as Map<String, dynamic>;

          // المهام المرسلة من المسوق ليست مهام جديدة
          if (data['isMarketingSubmitted'] == true) {
            return false;
          }

          final status =
              data['status']?.toString().trim() ??
                  'ready';

          final assignedTo =
              data['assignedTo']?.toString().trim() ??
                  '';

          final repostReason =
              data['repostReason']?.toString() ?? '';

          return (status == 'ready' ||
                  status == 'pending') &&
              isUnassigned(assignedTo) &&
              repostReason.trim().isEmpty;
        }).length;

        // ========================================================
        // قيد العمل
        // ========================================================

        final inProgress =
            allTasks.where((d) {
          final data =
              d.data() as Map<String, dynamic>;

          return data['status'] == 'in_progress' &&
              data['assignedTo'] == currentEmail;
        }).length;

        return Container(
          padding: const EdgeInsets.fromLTRB(
            14,
            8,
            14,
            8,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(
              top: BorderSide(
                color: border,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment:
                MainAxisAlignment.spaceBetween,
            children: [
              buildStatCard(
                'الجديدة',
                newTasks.toString(),
                green,
                Icons.fiber_new,
              ),
              buildStatCard(
                'إعادة نشر',
                reposted.toString(),
                orange,
                Icons.refresh,
              ),
              buildStatCard(
                'قيد العمل',
                inProgress.toString(),
                blue,
                Icons.work_outline,
              ),
              buildStatCard(
                'المنجزة',
                completed.toString(),
                purple,
                Icons.check_circle_outline,
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // كرت الإحصائية
  // ============================================================

  Widget buildStatCard(
    String title,
    String count,
    Color color,
    IconData icon,
  ) {
    return Expanded(
      child: Column(
        mainAxisAlignment:
            MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: color,
            size: 18,
          ),
          const SizedBox(height: 2),
          Text(
            count,
            style: GoogleFonts.cairo(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: GoogleFonts.cairo(
              color: grey,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // نافذة إرسال مهمة منجزة للمدير
  // ============================================================

  Future<void> showSendCompletedTaskDialog() async {
    final titleController = TextEditingController();
    final descriptionController =
        TextEditingController();
    final notesController = TextEditingController();

    String selectedPropertyType = 'خاص';

    bool isSaving = false;

    await showDialog(
      context: context,
      barrierDismissible: !isSaving,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(20),
              ),
              title: Text(
                'إرسال مهمة منجزة',
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(
                  color: navy,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  children: [
                    Text(
                      'إذا أنجزت مهمة خاصة بك وغير موجودة في النظام، يمكنك إرسالها للمدير هنا.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.cairo(
                        color: grey,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 18),

                    // ==================================================
                    // عنوان المهمة
                    // ==================================================

                    TextField(
                      controller: titleController,
                      textDirection:
                          TextDirection.rtl,
                      decoration: InputDecoration(
                        labelText: 'عنوان المهمة',
                        labelStyle:
                            GoogleFonts.cairo(
                          color: grey,
                        ),
                        prefixIcon: const Icon(
                          Icons.title,
                          color: navy,
                        ),
                        filled: true,
                        fillColor: lightGrey,
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(14),
                          borderSide:
                              const BorderSide(
                            color: border,
                          ),
                        ),
                        enabledBorder:
                            OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(14),
                          borderSide:
                              const BorderSide(
                            color: border,
                          ),
                        ),
                        focusedBorder:
                            OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(14),
                          borderSide:
                              const BorderSide(
                            color: navy,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ==================================================
                    // نوع العقار
                    // ==================================================

                    DropdownButtonFormField<String>(
                      initialValue:
                          selectedPropertyType,
                      decoration: InputDecoration(
                        labelText: 'نوع العقار',
                        labelStyle:
                            GoogleFonts.cairo(
                          color: grey,
                        ),
                        prefixIcon: const Icon(
                          Icons.home_work_outlined,
                          color: navy,
                        ),
                        filled: true,
                        fillColor: lightGrey,
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(14),
                          borderSide:
                              const BorderSide(
                            color: border,
                          ),
                        ),
                        enabledBorder:
                            OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(14),
                          borderSide:
                              const BorderSide(
                            color: border,
                          ),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'خاص',
                          child: Text('خاص'),
                        ),
                        DropdownMenuItem(
                          value: 'سكني',
                          child: Text('سكني'),
                        ),
                        DropdownMenuItem(
                          value: 'تجاري',
                          child: Text('تجاري'),
                        ),
                        DropdownMenuItem(
                          value: 'أرض',
                          child: Text('أرض'),
                        ),
                        DropdownMenuItem(
                          value: 'فيلا',
                          child: Text('فيلا'),
                        ),
                        DropdownMenuItem(
                          value: 'شقة',
                          child: Text('شقة'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;

                        setDialogState(() {
                          selectedPropertyType =
                              value;
                        });
                      },
                    ),

                    const SizedBox(height: 12),

                    // ==================================================
                    // وصف المهمة
                    // ==================================================

                    TextField(
                      controller:
                          descriptionController,
                      maxLines: 4,
                      textDirection:
                          TextDirection.rtl,
                      decoration: InputDecoration(
                        labelText:
                            'وصف المهمة وما تم إنجازه',
                        alignLabelWithHint: true,
                        labelStyle:
                            GoogleFonts.cairo(
                          color: grey,
                        ),
                        prefixIcon: const Padding(
                          padding:
                              EdgeInsets.only(
                            bottom: 60,
                          ),
                          child: Icon(
                            Icons.description_outlined,
                            color: navy,
                          ),
                        ),
                        filled: true,
                        fillColor: lightGrey,
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(14),
                          borderSide:
                              const BorderSide(
                            color: border,
                          ),
                        ),
                        enabledBorder:
                            OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(14),
                          borderSide:
                              const BorderSide(
                            color: border,
                          ),
                        ),
                        focusedBorder:
                            OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(14),
                          borderSide:
                              const BorderSide(
                            color: navy,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ==================================================
                    // ملاحظات
                    // ==================================================

                    TextField(
                      controller: notesController,
                      maxLines: 3,
                      textDirection:
                          TextDirection.rtl,
                      decoration: InputDecoration(
                        labelText:
                            'ملاحظات إضافية (اختياري)',
                        alignLabelWithHint: true,
                        labelStyle:
                            GoogleFonts.cairo(
                          color: grey,
                        ),
                        prefixIcon: const Padding(
                          padding:
                              EdgeInsets.only(
                            bottom: 35,
                          ),
                          child: Icon(
                            Icons.notes_outlined,
                            color: navy,
                          ),
                        ),
                        filled: true,
                        fillColor: lightGrey,
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(14),
                          borderSide:
                              const BorderSide(
                            color: border,
                          ),
                        ),
                        enabledBorder:
                            OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(14),
                          borderSide:
                              const BorderSide(
                            color: border,
                          ),
                        ),
                        focusedBorder:
                            OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(14),
                          borderSide:
                              const BorderSide(
                            color: navy,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actionsPadding:
                  const EdgeInsets.fromLTRB(
                16,
                0,
                16,
                16,
              ),
              actions: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: isSaving
                            ? null
                            : () {
                                Navigator.pop(
                                  dialogContext,
                                );
                              },
                        style:
                            OutlinedButton.styleFrom(
                          foregroundColor: navy,
                          side:
                              const BorderSide(
                            color: border,
                          ),
                          shape:
                              RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(
                              12,
                            ),
                          ),
                          padding:
                              const EdgeInsets
                                  .symmetric(
                            vertical: 13,
                          ),
                        ),
                        child: Text(
                          'إلغاء',
                          style:
                              GoogleFonts.cairo(
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: isSaving
                            ? null
                            : () async {
                                final title =
                                    titleController
                                        .text
                                        .trim();

                                final description =
                                    descriptionController
                                        .text
                                        .trim();

                                final notes =
                                    notesController
                                        .text
                                        .trim();

                                if (title.isEmpty) {
                                  ScaffoldMessenger.of(
                                    dialogContext,
                                  ).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'اكتبي عنوان المهمة',
                                        style:
                                            GoogleFonts
                                                .cairo(),
                                      ),
                                    ),
                                  );
                                  return;
                                }

                                if (description
                                    .isEmpty) {
                                  ScaffoldMessenger.of(
                                    dialogContext,
                                  ).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'اكتبي وصف المهمة وما تم إنجازه',
                                        style:
                                            GoogleFonts
                                                .cairo(),
                                      ),
                                    ),
                                  );
                                  return;
                                }

                                setDialogState(() {
                                  isSaving = true;
                                });

                                try {
                                  await sendCompletedTask(
                                    title: title,
                                    description:
                                        description,
                                    notes: notes,
                                    propertyType:
                                        selectedPropertyType,
                                  );

                                  if (!mounted) {
                                    return;
                                  }

                                  Navigator.pop(
                                    dialogContext,
                                  );

                                  ScaffoldMessenger.of(
                                    this.context,
                                  ).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'تم إرسال المهمة المنجزة للمدير بنجاح',
                                        style:
                                            GoogleFonts
                                                .cairo(
                                          color:
                                              Colors.white,
                                        ),
                                      ),
                                      backgroundColor:
                                          green,
                                      behavior:
                                          SnackBarBehavior
                                              .floating,
                                    ),
                                  );
                                } catch (e) {
                                  setDialogState(() {
                                    isSaving = false;
                                  });

                                  if (!mounted) {
                                    return;
                                  }

                                  ScaffoldMessenger.of(
                                    dialogContext,
                                  ).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'حدث خطأ أثناء إرسال المهمة:\n$e',
                                        style:
                                            GoogleFonts
                                                .cairo(),
                                      ),
                                      backgroundColor:
                                          red,
                                    ),
                                  );
                                }
                              },
                        style:
                            ElevatedButton.styleFrom(
                          backgroundColor: navy,
                          foregroundColor:
                              Colors.white,
                          elevation: 0,
                          shape:
                              RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(
                              12,
                            ),
                          ),
                          padding:
                              const EdgeInsets
                                  .symmetric(
                            vertical: 13,
                          ),
                        ),
                        child: isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color:
                                      Colors.white,
                                ),
                              )
                            : Text(
                                'إرسال للمدير',
                                style:
                                    GoogleFonts.cairo(
                                  fontWeight:
                                      FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );

    titleController.dispose();
    descriptionController.dispose();
    notesController.dispose();
  }

  // ============================================================
  // إرسال مهمة منجزة للمدير
  // ============================================================
  //
  // مهم:
  // هذه العملية تنشئ "مهمة مرسلة من المسوق" فقط.
  // لا تنشئ رسالة في المحادثات.
  // لا تضع lastMessage.
  // لا تضع unreadForAdmin.
  //
  // ============================================================

  Future<void> sendCompletedTask({
    required String title,
    required String description,
    required String notes,
    required String propertyType,
  }) async {
    if (currentEmail.isEmpty) {
      throw Exception(
        'لا يوجد حساب مستخدم مسجل حاليًا',
      );
    }

    final taskReference =
        FirebaseFirestore.instance
            .collection('tasks')
            .doc();

    await taskReference.set({
      // ==========================================================
      // معلومات المهمة
      // ==========================================================

      'title': title,

      'taskType': 'مهمة خاصة من المسوق',

      'description': description,

      'notes': notes,

      'propertyType': propertyType,

      // ==========================================================
      // حالة المهمة
      // ==========================================================

      'status': 'completed',

      // ==========================================================
      // المسوق الذي أنجز المهمة
      // ==========================================================

      'assignedTo': currentEmail,

      'assignedToName': currentUserName,

      'completedBy': currentEmail,

      'completedByName': currentUserName,

      'completedAt':
          FieldValue.serverTimestamp(),

      // ==========================================================
      // مصدر المهمة
      // ==========================================================

      'createdByRole': 'marketing',

      'createdBy': currentEmail,

      'createdByName': currentUserName,

      // ==========================================================
      // علامة مهمة مرسلة من المسوق
      // ==========================================================

      'isMarketingSubmitted': true,

      'submittedBy': currentEmail,

      'submittedByName': currentUserName,

      'submittedAt':
          FieldValue.serverTimestamp(),

      // ==========================================================
      // وقت إنشاء المهمة
      // ==========================================================

      'createdAt':
          FieldValue.serverTimestamp(),

      // ==========================================================
      // ملاحظة مهمة:
      //
      // لا نضع هنا:
      //
      // unreadForAdmin
      // unreadForEmployee
      // lastMessage
      // lastMessageSenderEmail
      // lastMessageSenderRole
      // lastMessageAt
      //
      // لأن هذه الحقول خاصة بالمحادثة فقط.
      // ==========================================================
    });
  }
}