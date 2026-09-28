import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  static const Color navy = Color(0xFF172B4D);
  static const Color grey = Color(0xFF6B7280);
  static const Color lightGrey = Color(0xFFF3F5F8);
  static const Color border = Color(0xFFE1E5EA);
  static const Color green = Color(0xFF2E7D32);
  static const Color red = Color(0xFFC62828);
  static const Color orange = Color(0xFFE58A00);

  DateTime selectedMonth = DateTime.now();

  String get monthKey {
    return '${selectedMonth.year}-'
        '${selectedMonth.month.toString().padLeft(2, '0')}';
  }

  // الجمعة والسبت إجازة
  bool isWorkDay(DateTime date) {
    return date.weekday >= DateTime.sunday &&
        date.weekday <= DateTime.thursday;
  }

  String formatDate(DateTime date) {
    return '${date.year}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  String displayDate(String dateKey) {
    final parts = dateKey.split('-');

    if (parts.length != 3) {
      return dateKey;
    }

    return '${parts[2]}/${parts[1]}/${parts[0]}';
  }

  // جميع أيام الدوام في الشهر
  List<DateTime> getAllWorkDaysForMonth() {
    final firstDay = DateTime(
      selectedMonth.year,
      selectedMonth.month,
      1,
    );

    final lastDay = DateTime(
      selectedMonth.year,
      selectedMonth.month + 1,
      0,
    );

    final days = <DateTime>[];

    DateTime current = firstDay;

    while (!current.isAfter(lastDay)) {
      if (isWorkDay(current)) {
        days.add(current);
      }

      current = current.add(
        const Duration(days: 1),
      );
    }

    return days;
  }

  // الأيام المطلوبة فعليًا حتى اليوم
  List<String> getRequiredWorkDaysForMonth() {
    final now = DateTime.now();

    final allDays = getAllWorkDaysForMonth();

    return allDays.where((date) {
      // إذا كان شهر سابق
      if (selectedMonth.year < now.year ||
          (selectedMonth.year == now.year &&
              selectedMonth.month < now.month)) {
        return true;
      }

      // إذا كان شهر مستقبلي
      if (selectedMonth.year > now.year ||
          (selectedMonth.year == now.year &&
              selectedMonth.month > now.month)) {
        return false;
      }

      // الشهر الحالي:
      // نحسب حتى تاريخ اليوم فقط
      return !date.isAfter(
        DateTime(now.year, now.month, now.day),
      );
    }).map(formatDate).toList();
  }

  Future<void> chooseMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedMonth,
      firstDate: DateTime(2025),
      lastDate: DateTime(2035),
      helpText: 'اختر الشهر',
      cancelText: 'إلغاء',
      confirmText: 'اختيار',
    );

    if (picked == null) return;

    setState(() {
      selectedMonth = DateTime(
        picked.year,
        picked.month,
        1,
      );
    });
  }

  Widget statCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border),
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: color,
                  size: 21,
                ),
                const Spacer(),
                Text(
                  value,
                  style: GoogleFonts.cairo(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: navy,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              title,
              style: GoogleFonts.cairo(
                fontSize: 11,
                color: grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget reportNumber(
    String title,
    String value,
    Color color,
  ) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.cairo(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          title,
          style: GoogleFonts.cairo(
            fontSize: 10,
            color: grey,
          ),
        ),
      ],
    );
  }

  Widget reportCard({
    required String name,
    required String email,
    required String role,
    required int expected,
    required int submitted,
    required List<String> missingDates,
  }) {
    final missing = missingDates.length;

    final percentage = expected == 0
        ? 0
        : ((submitted / expected) * 100).round();

    final Color progressColor =
        missing == 0 ? green : red;

    final department =
        role == 'marketing' ? 'التسويق' : 'المزاد';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: navy.withValues(alpha: .08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_outline,
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
                      name,
                      style: GoogleFonts.cairo(
                        fontWeight: FontWeight.bold,
                        color: navy,
                      ),
                    ),

                    Text(
                      department,
                      style: GoogleFonts.cairo(
                        fontSize: 11,
                        color: orange,
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),

                    Text(
                      email,
                      style: GoogleFonts.cairo(
                        fontSize: 10,
                        color: grey,
                      ),
                    ),
                  ],
                ),
              ),

              Text(
                '$percentage%',
                style: GoogleFonts.cairo(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: progressColor,
                ),
              ),
            ],
          ),

          const SizedBox(height: 15),

          Row(
            children: [
              Expanded(
                child: reportNumber(
                  'المطلوب',
                  expected.toString(),
                  navy,
                ),
              ),

              Expanded(
                child: reportNumber(
                  'تم الإرسال',
                  submitted.toString(),
                  green,
                ),
              ),

              Expanded(
                child: reportNumber(
                  'الناقص',
                  missing.toString(),
                  missing == 0
                      ? green
                      : red,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          if (missingDates.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: red.withValues(alpha: .06),
                borderRadius:
                    BorderRadius.circular(13),
                border: Border.all(
                  color: red.withValues(alpha: .15),
                ),
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: red,
                        size: 20,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'التقارير غير المكتملة',
                        style: GoogleFonts.cairo(
                          color: red,
                          fontSize: 12,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children:
                        missingDates.map((date) {
                      return Container(
                        padding:
                            const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius:
                              BorderRadius.circular(8),
                          border: Border.all(
                            color:
                                red.withValues(alpha: .20),
                          ),
                        ),
                        child: Row(
                          mainAxisSize:
                              MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.circle,
                              color: red,
                              size: 7,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              displayDate(date),
                              style:
                                  GoogleFonts.cairo(
                                fontSize: 11,
                                color: red,
                                fontWeight:
                                    FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: green.withValues(alpha: .07),
                borderRadius:
                    BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    color: green,
                    size: 20,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    'تم إرسال جميع التقارير المطلوبة',
                    style: GoogleFonts.cairo(
                      color: green,
                      fontSize: 12,
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final requiredWorkDays =
        getRequiredWorkDaysForMonth();

    return Scaffold(
      backgroundColor: lightGrey,

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,

        title: Text(
          'التقارير اليومية',
          style: GoogleFonts.cairo(
            color: navy,
            fontWeight: FontWeight.bold,
          ),
        ),

        actions: [
          IconButton(
            onPressed: chooseMonth,
            icon: const Icon(
              Icons.calendar_month_outlined,
              color: navy,
            ),
          ),
        ],
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where(
              'status',
              isEqualTo: 'approved',
            )
            .snapshots(),

        builder: (context, usersSnapshot) {
          if (usersSnapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (usersSnapshot.hasError) {
            return Center(
              child: Text(
                'حدث خطأ في تحميل الموظفين',
                style: GoogleFonts.cairo(
                  color: red,
                ),
              ),
            );
          }

          final users =
              usersSnapshot.data?.docs ?? [];

          // المزاد + التسويق فقط
          final employees =
              users.where((doc) {
            final data =
                doc.data()
                    as Map<String, dynamic>;

            final role =
                (data['role'] ?? '')
                    .toString()
                    .trim();

            return role == 'marketing' ||
                role == 'employee';
          }).toList();

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('daily_reports')
                .where(
                  'monthKey',
                  isEqualTo: monthKey,
                )
                .snapshots(),

            builder:
                (context, reportsSnapshot) {
              if (reportsSnapshot.connectionState ==
                  ConnectionState.waiting) {
                return const Center(
                  child:
                      CircularProgressIndicator(),
                );
              }

              if (reportsSnapshot.hasError) {
                return Center(
                  child: Text(
                    'حدث خطأ في تحميل التقارير',
                    style: GoogleFonts.cairo(
                      color: red,
                    ),
                  ),
                );
              }

              final reports =
                  reportsSnapshot.data?.docs ?? [];

              // email => الأيام التي أرسل فيها
              final reportsByEmail =
                  <String, Set<String>>{};

              for (final reportDoc in reports) {
                final data =
                    reportDoc.data()
                        as Map<String, dynamic>;

                final email =
                    (data['employeeEmail'] ?? '')
                        .toString()
                        .trim();

                final date =
                    (data['dateKey'] ?? '')
                        .toString()
                        .trim();

                if (email.isEmpty ||
                    date.isEmpty) {
                  continue;
                }

                reportsByEmail
                    .putIfAbsent(
                      email,
                      () => <String>{},
                    )
                    .add(date);
              }

              int totalExpected = 0;
              int totalSubmitted = 0;
              int totalMissing = 0;

              final cards = <Widget>[];

              for (final employee
                  in employees) {
                final data =
                    employee.data()
                        as Map<String, dynamic>;

                final name =
                    (data['name'] ??
                            data['fullName'] ??
                            data['displayName'] ??
                            'بدون اسم')
                        .toString();

                final email =
                    (data['email'] ?? '')
                        .toString()
                        .trim();

                final role =
                    (data['role'] ?? '')
                        .toString()
                        .trim();

                final submittedDates =
                    reportsByEmail[email] ??
                        <String>{};

                final missingDates =
                    requiredWorkDays
                        .where(
                          (date) =>
                              !submittedDates
                                  .contains(date),
                        )
                        .toList();

                final expected =
                    requiredWorkDays.length;

                final submitted =
                    requiredWorkDays
                        .where(
                          (date) =>
                              submittedDates
                                  .contains(date),
                        )
                        .length;

                totalExpected += expected;
                totalSubmitted += submitted;
                totalMissing +=
                    missingDates.length;

                cards.add(
                  reportCard(
                    name: name,
                    email: email,
                    role: role,
                    expected: expected,
                    submitted: submitted,
                    missingDates:
                        missingDates,
                  ),
                );
              }

              return Column(
                children: [
                  Padding(
                    padding:
                        const EdgeInsets.fromLTRB(
                      16,
                      16,
                      16,
                      10,
                    ),
                    child: Column(
                      children: [
                        Text(
                          'تقرير شهر ${selectedMonth.month}/'
                          '${selectedMonth.year}',
                          style: GoogleFonts.cairo(
                            color: navy,
                            fontWeight:
                                FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),

                        const SizedBox(height: 5),

                        Text(
                          'أيام الدوام: الأحد إلى الخميس',
                          style: GoogleFonts.cairo(
                            color: grey,
                            fontSize: 11,
                          ),
                        ),

                        const SizedBox(height: 12),

                        Row(
                          children: [
                            statCard(
                              'المطلوب',
                              totalExpected
                                  .toString(),
                              Icons
                                  .assignment_outlined,
                              navy,
                            ),

                            const SizedBox(width: 8),

                            statCard(
                              'تم الإرسال',
                              totalSubmitted
                                  .toString(),
                              Icons
                                  .check_circle_outline,
                              green,
                            ),

                            const SizedBox(width: 8),

                            statCard(
                              'الناقص',
                              totalMissing
                                  .toString(),
                              Icons
                                  .warning_amber_outlined,
                              red,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: cards.isEmpty
                        ? Center(
                            child: Text(
                              'لا يوجد موظفون',
                              style:
                                  GoogleFonts.cairo(
                                color: grey,
                              ),
                            ),
                          )
                        : ListView(
                            padding:
                                const EdgeInsets
                                    .fromLTRB(
                              16,
                              4,
                              16,
                              20,
                            ),
                            children: cards,
                          ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}