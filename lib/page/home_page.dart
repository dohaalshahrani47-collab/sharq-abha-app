import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

import 'permissions_page.dart';
import 'reports_page.dart';
import 'admin_messages_page.dart';
import 'real_estate_page.dart';
import 'task_details_page.dart';
import 'create_task_page.dart';
import 'auctions_page.dart';

// ============================================================
// COLORS
// ============================================================

class AppColors {
  static const Color navy = Color(0xFF172B4D);
  static const Color navy2 = Color(0xFF243B5A);
  static const Color grey = Color(0xFF6B7280);
  static const Color lightGrey = Color(0xFFF3F5F8);
  static const Color border = Color(0xFFE1E5EA);

  static const Color green = Color(0xFF2E7D32);
  static const Color orange = Color(0xFFE58A00);
  static const Color red = Color(0xFFC62828);
  static const Color blue = Color(0xFF1976D2);
}

// ============================================================
// ADMIN DASHBOARD
// ============================================================

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() =>
      _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  int selectedIndex = 1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      body: IndexedStack(
        index: selectedIndex,
        children: [
          RealEstatesPage(userRole: 'admin'),
          const AdminTasksHomePage(),
          const AdminMessagesPage(),
          const AuctionsPage(),
          const PermissionsPage(),
          const ReportsPage(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(
            top: BorderSide(
              color: AppColors.border,
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: BottomNavigationBar(
            currentIndex: selectedIndex,
            onTap: (index) {
              setState(() {
                selectedIndex = index;
              });
            },
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.white,
            elevation: 0,
            selectedItemColor: AppColors.navy,
            unselectedItemColor: AppColors.grey,
            selectedLabelStyle: GoogleFonts.cairo(
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
            unselectedLabelStyle: GoogleFonts.cairo(
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_work_outlined),
                activeIcon: Icon(Icons.home_work),
                label: 'العقارات',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.task_alt_outlined),
                activeIcon: Icon(Icons.task_alt),
                label: 'المهام',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.chat_bubble_outline),
                activeIcon: Icon(Icons.chat_bubble),
                label: 'المحادثات',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.gavel_outlined),
                activeIcon: Icon(Icons.gavel),
                label: 'المزادات',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.admin_panel_settings_outlined),
                activeIcon: Icon(Icons.admin_panel_settings),
                label: 'الصلاحيات',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.description_outlined),
                activeIcon: Icon(Icons.description),
                label: 'التقارير',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// ADMIN TASKS HOME
// ============================================================

class AdminTasksHomePage extends StatefulWidget {
  const AdminTasksHomePage({super.key});

  @override
  State<AdminTasksHomePage> createState() =>
      _AdminTasksHomePageState();
}

class _AdminTasksHomePageState extends State<AdminTasksHomePage> {
  int selectedTaskTab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'المهام',
          style: GoogleFonts.cairo(
            color: AppColors.navy,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('tasks')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'حدث خطأ أثناء تحميل المهام',
                style: GoogleFonts.cairo(
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          int completed = 0;
          int inProgress = 0;
          int newTasks = 0;
          int reposted = 0;
          int marketerCompleted = 0;

          for (final doc in docs) {
            final data = doc.data() as Map<String, dynamic>;

            final status =
                (data['status'] ?? '').toString();

            final assignedTo =
                (data['assignedTo'] ?? '').toString();

            final submittedToAdminBy =
                (data['submittedToAdminBy'] ?? '')
                    .toString()
                    .trim();

            final repostReason =
                (data['repostReason'] ?? '')
                    .toString()
                    .trim();

            final isMarketingSubmitted =
                data['isMarketingSubmitted'] == true;

            // ==================================================
            // المهام التي أنجزها المسوق
            // ==================================================

            if (isMarketingSubmitted ||
                status == 'submitted_to_admin') {
              marketerCompleted++;
            }

            // ==================================================
            // جميع المهام المنجزة
            // ==================================================

            if (status == 'completed' &&
                !isMarketingSubmitted &&
                submittedToAdminBy.isEmpty) {
              completed++;
            }

            // ==================================================
            // جميع المهام الجاري العمل عليها
            // ==================================================

            if (status == 'in_progress' &&
                !isMarketingSubmitted) {
              inProgress++;
            }

            // ==================================================
            // جميع المهام الجديدة / المعاد إرسالها
            // ==================================================

            if (!isMarketingSubmitted &&
                (status == 'ready' || status == 'pending') &&
                assignedTo == 'لم يتم استلامها بعد') {
              if (repostReason.isEmpty) {
                newTasks++;
              } else {
                reposted++;
              }
            }
          }

          return RefreshIndicator(
            color: AppColors.navy,
            onRefresh: () async {
              await Future.delayed(
                const Duration(milliseconds: 500),
              );
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 30),
              children: [
                // ==================================================
                // TOP TABS
                // ==================================================

                Container(
                  margin: const EdgeInsets.only(
                    top: 12,
                    bottom: 16,
                  ),
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _TaskTopTab(
                          title: 'جميع المهام',
                          icon: Icons.task_alt_outlined,
                          selected: selectedTaskTab == 0,
                          color: AppColors.navy,
                          onTap: () {
                            setState(() {
                              selectedTaskTab = 0;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: _TaskTopTab(
                          title: 'المهام المرسلة من المسوق',
                          icon: Icons.person_outline,
                          selected: selectedTaskTab == 1,
                          color: AppColors.blue,
                          onTap: () {
                            setState(() {
                              selectedTaskTab = 1;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                // ==================================================
                // ALL TASKS
                // ==================================================

                if (selectedTaskTab == 0) ...[
                  Row(
                    children: [
                      Expanded(
                        child: _MiniStatCard(
                          title: 'مهام جديدة',
                          value: newTasks.toString(),
                          icon: Icons.fiber_new_outlined,
                          color: AppColors.navy,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _MiniStatCard(
                          title: 'جاري العمل',
                          value: inProgress.toString(),
                          icon: Icons.pending_actions_outlined,
                          color: AppColors.orange,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(
                        child: _MiniStatCard(
                          title: 'منجزة',
                          value: completed.toString(),
                          icon: Icons.check_circle_outline,
                          color: AppColors.green,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _MiniStatCard(
                          title: 'من المسوقين',
                          value: marketerCompleted.toString(),
                          icon: Icons.person_outline,
                          color: AppColors.blue,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 22),

                  _MainTaskCategoryHeader(
                    title: 'جميع المهام',
                    subtitle:
                        'جميع المهام التي تم نشرها للمسوقين',
                    icon: Icons.task_alt_outlined,
                    color: AppColors.navy,
                  ),

                  const SizedBox(height: 12),

                  // ==================================================
                  // IN PROGRESS
                  // ==================================================

                  _TaskSectionCard(
                    title: 'الجاري العمل عليها',
                    subtitle:
                        'جميع المهام التي يعمل عليها المسوقون حاليًا',
                    icon: Icons.pending_actions_outlined,
                    count: inProgress,
                    accentColor: AppColors.orange,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const AdminTaskListPage(
                            pageTitle: 'الجاري العمل عليها',
                            filterType: 'in_progress',
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 12),

                  // ==================================================
                  // COMPLETED
                  // ==================================================

                  _TaskSectionCard(
                    title: 'المنجزة',
                    subtitle:
                        'جميع المهام التي تم إنجازها',
                    icon: Icons.check_circle_outline,
                    count: completed,
                    accentColor: AppColors.green,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const AdminTaskListPage(
                            pageTitle: 'المهام المنجزة',
                            filterType: 'completed',
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 12),

                  // ==================================================
                  // REPOSTED
                  // ==================================================

                  _TaskSectionCard(
                    title: 'المعاد إرسالها',
                    subtitle:
                        'المهام التي أعيد إرسالها للمسوقين',
                    icon: Icons.replay_outlined,
                    count: reposted,
                    accentColor: AppColors.red,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const AdminTaskListPage(
                            pageTitle: 'المهام المعاد إرسالها',
                            filterType: 'reposted',
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 16),

                  // ==================================================
                  // NEW TASK
                  // ==================================================

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                const CreateTaskPage(),
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.add_task_rounded,
                        color: Colors.white,
                      ),
                      label: Text(
                        'نشر مهمة جديدة',
                        style: GoogleFonts.cairo(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.red,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          vertical: 15,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ]

                // ==================================================
                // MARKETING SUBMITTED TASKS
                // ==================================================

                else ...[
                  _MainTaskCategoryHeader(
                    title: 'المهام المرسلة من المسوق',
                    subtitle:
                        'المهام التي أنجزها المسوق وأرسلها للمدير',
                    icon: Icons.person_outline,
                    color: AppColors.blue,
                  ),

                  const SizedBox(height: 12),

                  _TaskSectionCard(
                    title: 'المهام التي تم إنجازها من المسوق',
                    subtitle:
                        'المهام التي قام المسوق بإنجازها وإرسالها للمدير',
                    icon:
                        Icons.assignment_turned_in_outlined,
                    count: marketerCompleted,
                    accentColor: AppColors.blue,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const AdminTaskListPage(
                            pageTitle:
                                'المهام التي تم إنجازها من المسوق',
                            filterType:
                                'marketing_submitted',
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

// ============================================================
// TOP TAB
// ============================================================

class _TaskTopTab extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _TaskTopTab({
    required this.title,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 13,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 19,
                color:
                    selected ? Colors.white : AppColors.grey,
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.cairo(
                    color: selected
                        ? Colors.white
                        : AppColors.grey,
                    fontSize: 11,
                    fontWeight: selected
                        ? FontWeight.w800
                        : FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// MAIN HEADER
// ============================================================

class _MainTaskCategoryHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _MainTaskCategoryHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: color.withValues(alpha: 0.18),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.cairo(
                    color: AppColors.navy,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.cairo(
                    color: AppColors.grey,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// MINI STAT CARD
// ============================================================

class _MiniStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _MiniStatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: color,
              size: 22,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: GoogleFonts.cairo(
                    color: color,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.cairo(
                    color: AppColors.grey,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// TASK SECTION CARD
// ============================================================

class _TaskSectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final int? count;
  final Color accentColor;
  final VoidCallback onTap;

  const _TaskSectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.count,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.border,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.025),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color:
                      accentColor.withValues(alpha: 0.09),
                  borderRadius:
                      BorderRadius.circular(15),
                ),
                child: Icon(
                  icon,
                  color: accentColor,
                  size: 25,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.cairo(
                        color: AppColors.navy,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.cairo(
                        color: AppColors.grey,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (count != null) ...[
                const SizedBox(width: 8),
                Container(
                  constraints: const BoxConstraints(
                    minWidth: 32,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius:
                        BorderRadius.circular(20),
                  ),
                  child: Text(
                    count.toString(),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cairo(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 6),
              const Icon(
                Icons.arrow_forward_ios,
                size: 15,
                color: AppColors.grey,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// ADMIN TASK LIST PAGE
// ============================================================

class AdminTaskListPage extends StatelessWidget {
  final String pageTitle;
  final String filterType;

  const AdminTaskListPage({
    super.key,
    required this.pageTitle,
    required this.filterType,
  });

  // ==========================================================
  // فلترة المهام
  // ==========================================================

  bool _showTask(
    Map<String, dynamic> data,
  ) {
    final status =
        (data['status'] ?? '').toString();

    final assignedTo =
        (data['assignedTo'] ?? '').toString();

    final repostReason =
        (data['repostReason'] ?? '')
            .toString()
            .trim();

    final submittedToAdminBy =
        (data['submittedToAdminBy'] ?? '')
            .toString()
            .trim();

    final isMarketingSubmitted =
        data['isMarketingSubmitted'] == true;

    // ==========================================================
    // الجاري العمل عليها
    // ==========================================================

    if (filterType == 'in_progress') {
      return status == 'in_progress' &&
          !isMarketingSubmitted;
    }

    // ==========================================================
    // المنجزة
    // ==========================================================

    if (filterType == 'completed') {
      return status == 'completed' &&
          !isMarketingSubmitted &&
          submittedToAdminBy.isEmpty;
    }

    // ==========================================================
    // المعاد إرسالها
    // ==========================================================

    if (filterType == 'reposted') {
      return !isMarketingSubmitted &&
          (status == 'ready' ||
              status == 'pending') &&
          assignedTo == 'لم يتم استلامها بعد' &&
          repostReason.isNotEmpty;
    }

    // ==========================================================
    // المهام التي أرسلها المسوق للمدير
    // ==========================================================

    if (filterType == 'marketing_submitted') {
      return isMarketingSubmitted ||
          status == 'submitted_to_admin';
    }

    // ==========================================================
    // المهام القديمة
    // ==========================================================

    if (filterType == 'submitted_to_admin') {
      return status == 'submitted_to_admin';
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(
          color: AppColors.navy,
        ),
        title: Text(
          pageTitle,
          style: GoogleFonts.cairo(
            color: AppColors.navy,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('tasks')
            .orderBy(
              'createdAt',
              descending: true,
            )
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'حدث خطأ أثناء تحميل المهام',
                style: GoogleFonts.cairo(
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          }

          final allDocs =
              snapshot.data?.docs ?? [];

          final tasks = allDocs.where((doc) {
            final data =
                doc.data()
                    as Map<String, dynamic>;

            return _showTask(data);
          }).toList();

          if (tasks.isEmpty) {
            return Center(
              child: Padding(
                padding:
                    const EdgeInsets.all(30),
                child: Column(
                  mainAxisSize:
                      MainAxisSize.min,
                  children: [
                    Container(
                      width: 70,
                      height: 70,
                      decoration:
                          BoxDecoration(
                        color: AppColors.navy
                            .withValues(
                          alpha: 0.07,
                        ),
                        borderRadius:
                            BorderRadius.circular(
                          20,
                        ),
                      ),
                      child: const Icon(
                        Icons.inbox_outlined,
                        size: 35,
                        color:
                            AppColors.navy,
                      ),
                    ),
                    const SizedBox(
                        height: 14),
                    Text(
                      'لا توجد مهام',
                      style:
                          GoogleFonts.cairo(
                        color:
                            Colors.grey.shade600,
                        fontSize: 15,
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding:
                const EdgeInsets.all(16),
            itemCount:
                tasks.length,
            itemBuilder:
                (context, index) {
              final doc =
                  tasks[index];

              final data =
                  doc.data()
                      as Map<String, dynamic>;

              return Padding(
                padding:
                    const EdgeInsets.only(
                  bottom: 12,
                ),
                child:
                    _AdminTaskCard(
                  taskId: doc.id,
                  data: data,
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ============================================================
// ADMIN TASK CARD
// ============================================================

class _AdminTaskCard extends StatelessWidget {
  final String taskId;
  final Map<String, dynamic> data;

  const _AdminTaskCard({
    required this.taskId,
    required this.data,
  });

  String _statusText() {
    final status =
        (data['status'] ?? '').toString();

    final repostReason =
        (data['repostReason'] ?? '')
            .toString()
            .trim();

    final isMarketingSubmitted =
        data['isMarketingSubmitted'] == true;

    if (isMarketingSubmitted ||
        status == 'submitted_to_admin') {
      return 'تم الإنجاز من المسوق';
    }

    if (status == 'completed') {
      return 'مكتملة';
    }

    if (status == 'in_progress') {
      return 'جاري العمل';
    }

    if ((status == 'ready' ||
            status == 'pending') &&
        repostReason.isNotEmpty) {
      return 'معاد إرسالها';
    }

    if (status == 'ready' ||
        status == 'pending') {
      return 'بانتظار الاستلام';
    }

    return 'غير محددة';
  }

  Color _statusColor() {
    final status =
        (data['status'] ?? '').toString();

    final repostReason =
        (data['repostReason'] ?? '')
            .toString()
            .trim();

    final isMarketingSubmitted =
        data['isMarketingSubmitted'] == true;

    if (isMarketingSubmitted ||
        status == 'submitted_to_admin') {
      return AppColors.blue;
    }

    if (status == 'completed') {
      return AppColors.green;
    }

    if (status == 'in_progress') {
      return AppColors.orange;
    }

    if ((status == 'ready' ||
            status == 'pending') &&
        repostReason.isNotEmpty) {
      return AppColors.red;
    }

    if (status == 'ready' ||
        status == 'pending') {
      return AppColors.navy;
    }

    return AppColors.grey;
  }

  Future<void> _deleteTask(
    BuildContext context,
  ) async {
    final confirmed =
        await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(20),
          ),
          title: Text(
            'حذف المهمة',
            textAlign:
                TextAlign.center,
            style:
                GoogleFonts.cairo(
              color:
                  AppColors.navy,
              fontWeight:
                  FontWeight.w800,
            ),
          ),
          content: Text(
            'هل أنت متأكد من حذف هذه المهمة؟',
            textAlign:
                TextAlign.center,
            style:
                GoogleFonts.cairo(),
          ),
          actionsAlignment:
              MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: Text(
                'إلغاء',
                style:
                    GoogleFonts.cairo(
                  color:
                      AppColors.navy,
                  fontWeight:
                      FontWeight.w700,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              child: Text(
                'حذف',
                style:
                    GoogleFonts.cairo(
                  color:
                      AppColors.red,
                  fontWeight:
                      FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await FirebaseFirestore
          .instance
          .collection('tasks')
          .doc(taskId)
          .delete();

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          SnackBar(
            content: Text(
              'تم حذف المهمة بنجاح',
              style:
                  GoogleFonts.cairo(),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          SnackBar(
            content: Text(
              'تعذر حذف المهمة',
              style:
                  GoogleFonts.cairo(),
            ),
            backgroundColor:
                AppColors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final clientName =
        (data['clientName'] ??
                'بدون اسم')
            .toString();

    final phone =
        (data['phone'] ?? '')
            .toString();

    final propertyType =
        (data['propertyType'] ?? '')
            .toString();

    final notes =
        (data['notes'] ?? '')
            .toString();

    final assignedTo =
        (data['assignedTo'] ??
                'لم يتم استلامها بعد')
            .toString();

    final submittedToAdminBy =
        (data['submittedToAdminBy'] ??
                '')
            .toString()
            .trim();

    final isMarketingSubmitted =
        data['isMarketingSubmitted'] == true;

    // ==========================================================
    // اسم المسوق
    // ==========================================================

    final marketingSubmitter =
        (data['submittedByName'] ??
                data['createdByName'] ??
                data['assignedToName'] ??
                data['submittedBy'] ??
                data['submittedToAdminByName'] ??
                data['completedByName'] ??
                data['assignedTo'] ??
                submittedToAdminBy)
            .toString()
            .trim();

    final submittedToAdminByName =
        (data['submittedToAdminByName'] ??
                data['completedByName'] ??
                data['assignedToName'] ??
                submittedToAdminBy)
            .toString()
            .trim();

    final isSubmittedByEmployee =
        isMarketingSubmitted ||
        (data['status'] == 'submitted_to_admin' &&
            submittedToAdminBy.isNotEmpty);

    final employeeName =
        isMarketingSubmitted
            ? marketingSubmitter
            : (submittedToAdminByName.isNotEmpty
                ? submittedToAdminByName
                : submittedToAdminBy);

    final repostReason =
        (data['repostReason'] ?? '')
            .toString()
            .trim();

    final statusColor =
        _statusColor();

    return Material(
      color: Colors.white,
      borderRadius:
          BorderRadius.circular(20),
      child: InkWell(
        borderRadius:
            BorderRadius.circular(20),
        onTap: () {
          final currentEmail =
              FirebaseAuth
                  .instance
                  .currentUser
                  ?.email ??
              '';

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  TaskDetailsPage(
                taskId: taskId,
                taskData: data,
                currentEmail:
                    currentEmail,
                currentRole:
                    'admin',
              ),
            ),
          );
        },
        child: Container(
          padding:
              const EdgeInsets.all(16),
          decoration:
              BoxDecoration(
            color: Colors.white,
            borderRadius:
                BorderRadius.circular(20),
            border: Border.all(
              color:
                  AppColors.border,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black
                    .withValues(
                  alpha: 0.025,
                ),
                blurRadius: 8,
                offset:
                    const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              // ==================================================
              // HEADER
              // ==================================================

              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration:
                        BoxDecoration(
                      color:
                          isSubmittedByEmployee
                              ? AppColors.blue
                                  .withValues(
                                  alpha: 0.08,
                                )
                              : AppColors.navy
                                  .withValues(
                                  alpha: 0.07,
                                ),
                      borderRadius:
                          BorderRadius
                              .circular(
                        14,
                      ),
                    ),
                    child: Icon(
                      isSubmittedByEmployee
                          ? Icons
                              .person_outline
                          : Icons.task_alt,
                      color:
                          isSubmittedByEmployee
                              ? AppColors.blue
                              : AppColors.navy,
                      size: 23,
                    ),
                  ),

                  const SizedBox(
                      width: 11),

                  Expanded(
                    child: Text(
                      clientName,
                      maxLines: 2,
                      overflow:
                          TextOverflow
                              .ellipsis,
                      style:
                          GoogleFonts.cairo(
                        color:
                            AppColors.navy,
                        fontSize: 16,
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),
                  ),

                  const SizedBox(
                      width: 6),

                  Flexible(
                    child: Container(
                      padding:
                          const EdgeInsets
                              .symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration:
                          BoxDecoration(
                        color:
                            statusColor
                                .withValues(
                          alpha: 0.10,
                        ),
                        borderRadius:
                            BorderRadius
                                .circular(
                          20,
                        ),
                      ),
                      child: Text(
                        _statusText(),
                        maxLines: 1,
                        overflow:
                            TextOverflow
                                .ellipsis,
                        style:
                            GoogleFonts.cairo(
                          color:
                              statusColor,
                          fontSize: 10,
                          fontWeight:
                              FontWeight.w800,
                        ),
                      ),
                    ),
                  ),

                  IconButton(
                    onPressed: () {
                      _deleteTask(
                        context,
                      );
                    },
                    tooltip:
                        'حذف المهمة',
                    icon:
                        const Icon(
                      Icons
                          .delete_outline,
                      color:
                          AppColors.red,
                      size: 21,
                    ),
                  ),
                ],
              ),

              const SizedBox(
                  height: 14),

              // ==================================================
              // MARKETER
              // ==================================================

              if (isSubmittedByEmployee &&
                  employeeName.isNotEmpty)
                Container(
                  width:
                      double.infinity,
                  padding:
                      const EdgeInsets
                          .symmetric(
                    horizontal: 12,
                    vertical: 11,
                  ),
                  decoration:
                      BoxDecoration(
                    color:
                        AppColors.blue
                            .withValues(
                      alpha: 0.06,
                    ),
                    borderRadius:
                        BorderRadius.circular(
                      14,
                    ),
                    border: Border.all(
                      color:
                          AppColors.blue
                              .withValues(
                        alpha: 0.16,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons
                            .person_outline,
                        color:
                            AppColors.blue,
                        size: 19,
                      ),
                      const SizedBox(
                          width: 8),
                      Text(
                        'المسوق المنجز:',
                        style:
                            GoogleFonts.cairo(
                          color:
                              AppColors.grey,
                          fontSize: 10,
                          fontWeight:
                              FontWeight.w700,
                        ),
                      ),
                      const SizedBox(
                          width: 6),
                      Expanded(
                        child: Text(
                          employeeName,
                          maxLines: 1,
                          overflow:
                              TextOverflow.ellipsis,
                          style:
                              GoogleFonts.cairo(
                            color:
                                AppColors.blue,
                            fontSize: 11,
                            fontWeight:
                                FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              if (isSubmittedByEmployee)
                const SizedBox(
                    height: 10),

              // ==================================================
              // PHONE
              // ==================================================

              if (phone.isNotEmpty)
                _InfoBox(
                  icon:
                      Icons.phone_outlined,
                  title:
                      'رقم العميل',
                  value: phone,
                ),

              // ==================================================
              // PROPERTY TYPE
              // ==================================================

              if (propertyType.isNotEmpty) ...[
                const SizedBox(
                    height: 8),
                _InfoBox(
                  icon:
                      Icons.home_work_outlined,
                  title:
                      'نوع العقار',
                  value:
                      propertyType,
                ),
              ],

              const SizedBox(
                  height: 8),

              // ==================================================
              // ASSIGNED EMPLOYEE
              // ==================================================

              _InfoBox(
                icon:
                    Icons.person_outline,
                title:
                    isSubmittedByEmployee
                        ? 'الموظف'
                        : 'الموظف المستلم',
                value:
                    isSubmittedByEmployee
                        ? employeeName
                        : assignedTo,
              ),

              // ==================================================
              // MARKETING ACCOUNT
              // ==================================================

              if (submittedToAdminBy.isNotEmpty &&
                  isSubmittedByEmployee) ...[
                const SizedBox(
                    height: 8),
                _InfoBox(
                  icon:
                      Icons.email_outlined,
                  title:
                      'حساب المسوق',
                  value:
                      submittedToAdminBy,
                ),
              ],

              // ==================================================
              // NOTES
              // ==================================================

              if (notes.isNotEmpty) ...[
                const SizedBox(
                    height: 10),
                Container(
                  width:
                      double.infinity,
                  padding:
                      const EdgeInsets.all(
                    12,
                  ),
                  decoration:
                      BoxDecoration(
                    color:
                        AppColors.lightGrey,
                    borderRadius:
                        BorderRadius.circular(
                      14,
                    ),
                    border: Border.all(
                      color:
                          AppColors.border,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      const Icon(
                        Icons
                            .notes_outlined,
                        color:
                            AppColors.grey,
                        size: 18,
                      ),
                      const SizedBox(
                          width: 8),
                      Expanded(
                        child: Text(
                          notes,
                          style:
                              GoogleFonts.cairo(
                            color:
                                AppColors.grey,
                            fontSize: 11,
                            fontWeight:
                                FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // ==================================================
              // REPOST REASON
              // ==================================================

              if (repostReason.isNotEmpty) ...[
                const SizedBox(
                    height: 10),
                Container(
                  width:
                      double.infinity,
                  padding:
                      const EdgeInsets.all(
                    12,
                  ),
                  decoration:
                      BoxDecoration(
                    color:
                        AppColors.red
                            .withValues(
                      alpha: 0.07,
                    ),
                    borderRadius:
                        BorderRadius.circular(
                      14,
                    ),
                    border: Border.all(
                      color:
                          AppColors.red
                              .withValues(
                        alpha: 0.20,
                      ),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      const Icon(
                        Icons
                            .replay_outlined,
                        color:
                            AppColors.red,
                        size: 19,
                      ),
                      const SizedBox(
                          width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                          children: [
                            Text(
                              'سبب الإعادة',
                              style:
                                  GoogleFonts.cairo(
                                color:
                                    AppColors.red,
                                fontSize:
                                    11,
                                fontWeight:
                                    FontWeight
                                        .w800,
                              ),
                            ),
                            const SizedBox(
                                height: 2),
                            Text(
                              repostReason,
                              style:
                                  GoogleFonts.cairo(
                                color:
                                    AppColors.red,
                                fontSize:
                                    11,
                                fontWeight:
                                    FontWeight
                                        .w600,
                              ),
                            ),
                          ],
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
    );
  }
}

// ============================================================
// INFO BOX
// ============================================================

class _InfoBox extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _InfoBox({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 9,
      ),
      decoration: BoxDecoration(
        color:
            AppColors.lightGrey,
        borderRadius:
            BorderRadius.circular(12),
        border: Border.all(
          color:
              AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 17,
            color:
                AppColors.navy,
          ),
          const SizedBox(width: 8),
          Text(
            '$title:',
            style:
                GoogleFonts.cairo(
              color:
                  AppColors.grey,
              fontSize: 10,
              fontWeight:
                  FontWeight.w700,
            ),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow:
                  TextOverflow.ellipsis,
              style:
                  GoogleFonts.cairo(
                color:
                    AppColors.navy,
                fontSize: 10,
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// EMPLOYEE PERFORMANCE PAGE
// ============================================================

class EmployeePerformancePage
    extends StatelessWidget {
  const EmployeePerformancePage({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          AppColors.lightGrey,
      appBar: AppBar(
        backgroundColor:
            Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme:
            const IconThemeData(
          color: AppColors.navy,
        ),
        title: Text(
          'أداء الموظفين',
          style:
              GoogleFonts.cairo(
            color: AppColors.navy,
            fontSize: 18,
            fontWeight:
                FontWeight.w800,
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore
            .instance
            .collection('tasks')
            .snapshots(),
        builder:
            (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child:
                  CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'حدث خطأ أثناء تحميل البيانات',
                style:
                    GoogleFonts.cairo(
                  color: Colors.red,
                ),
              ),
            );
          }

          final docs =
              snapshot.data?.docs ?? [];

          final Map<
                  String,
                  Map<String, int>>
              performance = {};

          for (final doc in docs) {
            final data =
                doc.data()
                    as Map<String, dynamic>;

            final status =
                (data['status'] ?? '')
                    .toString();

            final isMarketingSubmitted =
                data['isMarketingSubmitted'] ==
                    true;

            final submittedToAdminBy =
                (data['submittedToAdminBy'] ??
                        '')
                    .toString()
                    .trim();

            final assignedTo =
                (data['assignedTo'] ?? '')
                    .toString()
                    .trim();

            final submittedBy =
                (data['submittedBy'] ??
                        data['createdBy'] ??
                        data['submittedToAdminBy'] ??
                        '')
                    .toString()
                    .trim();

            final email =
                isMarketingSubmitted &&
                        submittedBy.isNotEmpty
                    ? submittedBy
                    : status ==
                                'submitted_to_admin' &&
                            submittedToAdminBy
                                .isNotEmpty
                        ? submittedToAdminBy
                        : assignedTo;

            if (email.isEmpty ||
                email ==
                    'لم يتم استلامها بعد') {
              continue;
            }

            performance.putIfAbsent(
              email,
              () => {
                'completed': 0,
                'in_progress': 0,
                'reposted': 0,
              },
            );

            if (isMarketingSubmitted ||
                status == 'completed' ||
                status == 'submitted_to_admin') {
              performance[email]![
                      'completed'] =
                  performance[email]![
                          'completed']! +
                      1;
            }

            if (status ==
                    'in_progress' &&
                !isMarketingSubmitted) {
              performance[email]![
                      'in_progress'] =
                  performance[email]![
                          'in_progress']! +
                      1;
            }

            final repostedBy =
                (data['repostedBy'] ?? '')
                    .toString()
                    .trim();

            if (repostedBy == email) {
              performance[email]![
                      'reposted'] =
                  performance[email]![
                          'reposted']! +
                      1;
            }
          }

          if (performance.isEmpty) {
            return Center(
              child: Text(
                'لا توجد بيانات أداء حاليًا',
                style:
                    GoogleFonts.cairo(
                  color:
                      Colors.grey.shade600,
                  fontWeight:
                      FontWeight.w600,
                ),
              ),
            );
          }

          final entries =
              performance.entries.toList();

          return ListView.builder(
            padding:
                const EdgeInsets.all(16),
            itemCount:
                entries.length,
            itemBuilder:
                (context, index) {
              final entry =
                  entries[index];

              return Padding(
                padding:
                    const EdgeInsets.only(
                  bottom: 12,
                ),
                child:
                    _EmployeePerformanceCard(
                  email: entry.key,
                  completed:
                      entry.value[
                              'completed'] ??
                          0,
                  inProgress:
                      entry.value[
                              'in_progress'] ??
                          0,
                  reposted:
                      entry.value[
                              'reposted'] ??
                          0,
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ============================================================
// EMPLOYEE PERFORMANCE CARD
// ============================================================

class _EmployeePerformanceCard
    extends StatelessWidget {
  final String email;
  final int completed;
  final int inProgress;
  final int reposted;

  const _EmployeePerformanceCard({
    required this.email,
    required this.completed,
    required this.inProgress,
    required this.reposted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(20),
        border: Border.all(
          color:
              AppColors.border,
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
                  color:
                      AppColors.navy
                          .withValues(
                    alpha: 0.08,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    14,
                  ),
                ),
                child: const Icon(
                  Icons.person_outline,
                  color:
                      AppColors.navy,
                ),
              ),
              const SizedBox(
                  width: 12),
              Expanded(
                child:
                    _MarketingUserName(
                  email: email,
                ),
              ),
            ],
          ),
          const SizedBox(
              height: 16),
          Row(
            children: [
              Expanded(
                child:
                    _PerformanceNumber(
                  title: 'منجزة',
                  value: completed,
                  icon: Icons
                      .check_circle_outline,
                  color:
                      AppColors.green,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child:
                    _PerformanceNumber(
                  title: 'جاري العمل',
                  value: inProgress,
                  icon: Icons
                      .pending_actions_outlined,
                  color:
                      AppColors.orange,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child:
                    _PerformanceNumber(
                  title: 'معاد إرسالها',
                  value: reposted,
                  icon:
                      Icons.replay_outlined,
                  color:
                      AppColors.red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================
// USER NAME
// ============================================================

class _MarketingUserName
    extends StatelessWidget {
  final String email;

  const _MarketingUserName({
    required this.email,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore
          .instance
          .collection('users')
          .where(
            'email',
            isEqualTo: email,
          )
          .limit(1)
          .get(),
      builder:
          (context, snapshot) {
        String name = email;

        if (snapshot.hasData &&
            snapshot.data!.docs
                .isNotEmpty) {
          final data =
              snapshot.data!.docs.first
                      .data()
                  as Map<String, dynamic>;

          name =
              (data['name'] ??
                      data['fullName'] ??
                      data['displayName'] ??
                      email)
                  .toString();
        }

        if (snapshot.hasError) {
          name = email;
        }

        return Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              name,
              maxLines: 1,
              overflow:
                  TextOverflow.ellipsis,
              style:
                  GoogleFonts.cairo(
                color:
                    AppColors.navy,
                fontSize: 14,
                fontWeight:
                    FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              email,
              maxLines: 1,
              overflow:
                  TextOverflow.ellipsis,
              style:
                  GoogleFonts.cairo(
                color:
                    AppColors.grey,
                fontSize: 10,
                fontWeight:
                    FontWeight.w500,
              ),
            ),
          ],
        );
      },
    );
  }
}

// ============================================================
// PERFORMANCE NUMBER
// ============================================================

class _PerformanceNumber
    extends StatelessWidget {
  final String title;
  final int value;
  final IconData icon;
  final Color color;

  const _PerformanceNumber({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        vertical: 10,
        horizontal: 6,
      ),
      decoration: BoxDecoration(
        color:
            color.withValues(
          alpha: 0.07,
        ),
        borderRadius:
            BorderRadius.circular(13),
        border: Border.all(
          color:
              color.withValues(
            alpha: 0.12,
          ),
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: 19,
          ),
          const SizedBox(height: 5),
          Text(
            value.toString(),
            style:
                GoogleFonts.cairo(
              color: color,
              fontSize: 17,
              fontWeight:
                  FontWeight.w800,
            ),
          ),
          Text(
            title,
            maxLines: 1,
            overflow:
                TextOverflow.ellipsis,
            style:
                GoogleFonts.cairo(
              color:
                  AppColors.grey,
              fontSize: 9,
              fontWeight:
                  FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}