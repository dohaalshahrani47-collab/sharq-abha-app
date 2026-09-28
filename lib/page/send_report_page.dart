
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:excel/excel.dart' as excel;

class SendReportPage extends StatefulWidget {
  const SendReportPage({super.key});

  @override
  State<SendReportPage> createState() => _SendReportPageState();
}

class _SendReportPageState extends State<SendReportPage> {
  static const Color navy = Color(0xFF172B4D);
  static const Color grey = Color(0xFF6B7280);
  static const Color lightGrey = Color(0xFFF3F5F8);
  static const Color border = Color(0xFFE1E5EA);
  static const Color green = Color(0xFF2E7D32);
  static const Color red = Color(0xFFC62828);

  final User? currentUser = FirebaseAuth.instance.currentUser;

  final TextEditingController hoursController =
      TextEditingController();

  final TextEditingController descriptionController =
      TextEditingController();

  final TextEditingController namesController =
      TextEditingController();

  final TextEditingController numbersController =
      TextEditingController();

  final TextEditingController notesController =
      TextEditingController();

  String reportType = 'daily';

  bool isSending = false;
  bool isTestingFirestore = false;

  String get currentEmail => currentUser?.email ?? '';

  String get currentName {
    final name = currentUser?.displayName?.trim() ?? '';

    if (name.isNotEmpty) {
      return name;
    }

    return currentEmail;
  }

  String formatDate(DateTime date) {
    return '${date.year}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  String get todayKey {
    return formatDate(DateTime.now());
  }

  String get currentMonthKey {
    final now = DateTime.now();

    return '${now.year}-'
        '${now.month.toString().padLeft(2, '0')}';
  }

  bool isFridayOrSaturday(DateTime date) {
    return date.weekday == DateTime.friday ||
        date.weekday == DateTime.saturday;
  }

  @override
  void dispose() {
    hoursController.dispose();
    descriptionController.dispose();
    namesController.dispose();
    numbersController.dispose();
    notesController.dispose();

    super.dispose();
  }

  // ============================================================
  // تنظيف اسم الملف والمسار
  // ============================================================

  String sanitizeStorageName(String value) {
    final cleaned = value
        .trim()
        .replaceAll(RegExp(r'[^a-zA-Z0-9@._-]'), '_');

    if (cleaned.isEmpty) {
      return 'unknown';
    }

    return cleaned;
  }

  // ============================================================
  // قراءة بيانات الموظف من Firestore
  // ============================================================

  Future<Map<String, dynamic>> getUserData() async {
    if (currentUser == null) {
      return {};
    }

    debugPrint('🔎 البحث عن بيانات الموظف في users...');
    debugPrint('📧 البريد المستخدم في البحث: $currentEmail');

    final query = await FirebaseFirestore.instance
        .collection('users')
        .where(
          'email',
          isEqualTo: currentEmail,
        )
        .limit(1)
        .get();

    debugPrint(
      '📦 عدد المستخدمين الذين تم العثور عليهم: ${query.docs.length}',
    );

    if (query.docs.isEmpty) {
      debugPrint('⚠️ لم يتم العثور على بيانات الموظف');
      return {};
    }

    return query.docs.first.data();
  }

  // ============================================================
  // اختبار اتصال Firestore
  // ============================================================

  Future<void> testFirestore() async {
    debugPrint('🟢🟢🟢 بدأ اختبار Firestore 🟢🟢🟢');

    if (currentUser == null) {
      debugPrint('❌ لا يوجد مستخدم مسجل الدخول');

      showMessage(
        'يجب تسجيل الدخول أولاً',
        red,
      );

      return;
    }

    setState(() {
      isTestingFirestore = true;
    });

    try {
      debugPrint('📧 المستخدم الحالي: $currentEmail');

      debugPrint('1️⃣ محاولة الكتابة في Firestore...');

      await FirebaseFirestore.instance
          .collection('test_connection')
          .doc('test')
          .set({
        'message': 'Firebase يعمل',
        'email': currentEmail,
        'name': currentName,
        'createdAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅✅✅ Firestore يعمل بنجاح ✅✅✅');

      if (!mounted) return;

      showMessage(
        'Firestore يعمل بنجاح',
        green,
      );
    } catch (e, stackTrace) {
      debugPrint('❌❌❌ Firestore فشل ❌❌❌');
      debugPrint('❌ ERROR: $e');
      debugPrint('❌ STACK TRACE: $stackTrace');

      if (!mounted) return;

      showMessage(
        'Firestore فشل:\n$e',
        red,
      );
    } finally {
      if (mounted) {
        setState(() {
          isTestingFirestore = false;
        });
      }
    }
  }

  // ============================================================
  // إرسال التقرير
  // ============================================================

  Future<void> sendReport() async {
    debugPrint(
      '🔴🔴🔴 تم الضغط على زر إرسال التقرير 🔴🔴🔴',
    );

    if (currentUser == null) {
      showMessage(
        'يجب تسجيل الدخول أولاً',
        red,
      );
      return;
    }

    final hours = hoursController.text.trim();

    final description =
        descriptionController.text.trim();

    if (hours.isEmpty) {
      showMessage(
        'أدخلي عدد ساعات العمل',
        red,
      );
      return;
    }

    if (double.tryParse(hours) == null) {
      showMessage(
        'أدخلي عدد ساعات صحيح مثل 8',
        red,
      );
      return;
    }

    if (description.isEmpty) {
      showMessage(
        'أدخلي وصف التقرير',
        red,
      );
      return;
    }

    final now = DateTime.now();

    if (reportType == 'daily' &&
        isFridayOrSaturday(now)) {
      showMessage(
        'لا يوجد تقرير يومي يوم الجمعة والسبت',
        red,
      );
      return;
    }

    if (mounted) {
      setState(() {
        isSending = true;
      });
    }

    try {
      debugPrint('==============================');
      debugPrint('🚀 بدأ إرسال التقرير');
      debugPrint('📧 البريد: $currentEmail');
      debugPrint('👤 الاسم: $currentName');
      debugPrint('📅 التاريخ: $todayKey');
      debugPrint('📄 نوع التقرير: $reportType');

      // ========================================================
      // 1 - قراءة بيانات الموظف
      // ========================================================

      debugPrint('1️⃣ جاري قراءة بيانات الموظف...');

      final userData = await getUserData();

      debugPrint('✅ تم الحصول على بيانات الموظف');
      debugPrint('📦 userData: $userData');

      final role =
          (userData['role'] ?? 'employee').toString();

      final jobTitle =
          (userData['jobTitle'] ??
                  userData['position'] ??
                  userData['title'] ??
                  'موظف')
              .toString();

      final department =
          role == 'marketing'
              ? 'التسويق'
              : 'المزاد';

      debugPrint('👔 role: $role');
      debugPrint('💼 jobTitle: $jobTitle');
      debugPrint('🏢 department: $department');

      // ========================================================
      // 2 - إنشاء معرف التقرير
      // ========================================================

      final reportId =
          '${currentEmail}_${todayKey}_$reportType'
              .replaceAll(
        RegExp(r'[^a-zA-Z0-9_-]'),
        '_',
      );

      final safeName =
          sanitizeStorageName(currentName);

      final safeEmail =
          sanitizeStorageName(currentEmail);

      final fileName =
          'report_${safeName}_$todayKey.xlsx';

      final safeFileName =
          sanitizeStorageName(fileName);

      debugPrint('🆔 Report ID: $reportId');
      debugPrint('📄 File Name: $safeFileName');

      // ========================================================
      // 3 - إنشاء ملف Excel
      // ========================================================

      debugPrint('2️⃣ جاري إنشاء ملف Excel...');

      final excelBytes = await createExcelFile(
        name: currentName,
        email: currentEmail,
        jobTitle: jobTitle,
        department: department,
        hours: hours,
        description: description,
        names: namesController.text.trim(),
        numbers: numbersController.text.trim(),
        notes: notesController.text.trim(),
        date: todayKey,
        type: reportType,
      );

      debugPrint(
        '✅ تم إنشاء Excel بنجاح',
      );

      debugPrint(
        '📦 حجم الملف: ${excelBytes.length} bytes',
      );

      if (excelBytes.isEmpty) {
        throw Exception(
          'ملف Excel فارغ ولا يمكن رفعه',
        );
      }

      // ========================================================
      // 4 - تجهيز Firebase Storage
      // ========================================================

      debugPrint(
        '3️⃣ جاري تجهيز Firebase Storage...',
      );

      const storageBucket =
          'gs://sharqabhaapp.firebasestorage.app';

      debugPrint(
        '🪣 Firebase Storage Bucket: $storageBucket',
      );

      final storage =
          FirebaseStorage.instanceFor(
        bucket: storageBucket,
      );

      final storagePath =
          'daily_reports/'
          '$currentMonthKey/'
          '$safeEmail/'
          '$safeFileName';

      debugPrint(
        '📁 Storage Path: $storagePath',
      );

      final storageRef =
          storage.ref().child(storagePath);

      debugPrint(
        '🔗 Full Storage Reference: ${storageRef.fullPath}',
      );

      final metadata = SettableMetadata(
        contentType:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        customMetadata: {
          'employeeEmail': currentEmail,
          'employeeName': currentName,
          'reportType': reportType,
          'dateKey': todayKey,
        },
      );

      // ========================================================
      // 5 - رفع Excel
      // ========================================================

      debugPrint(
        '4️⃣ جاري رفع ملف Excel إلى Storage...',
      );

      final Uint8List fileBytes =
          Uint8List.fromList(excelBytes);

      final UploadTask uploadTask =
          storageRef.putData(
        fileBytes,
        metadata,
      );

      debugPrint(
        '📤 بدأ رفع الملف...',
      );

      uploadTask.snapshotEvents.listen(
        (TaskSnapshot snapshot) {
          final totalBytes =
              snapshot.totalBytes;

          final transferredBytes =
              snapshot.bytesTransferred;

          if (totalBytes > 0) {
            final progress =
                (transferredBytes / totalBytes) * 100;

            debugPrint(
              '📤 رفع الملف: '
              '${progress.toStringAsFixed(1)}%',
            );
          }

          debugPrint(
            '📦 Storage State: ${snapshot.state}',
          );
        },
        onError: (Object error) {
          debugPrint(
            '❌ خطأ أثناء متابعة الرفع: $error',
          );
        },
      );

      // الانتظار حتى يكتمل الرفع بالكامل
      final TaskSnapshot uploadSnapshot =
          await uploadTask;

      debugPrint(
        '📦 الحالة النهائية للرفع: '
        '${uploadSnapshot.state}',
      );

      if (uploadSnapshot.state !=
          TaskState.success) {
        throw Exception(
          'لم يكتمل رفع ملف Excel',
        );
      }

      debugPrint(
        '✅✅ تم رفع ملف Excel بالكامل إلى Firebase Storage',
      );

      // ========================================================
      // 6 - الحصول على رابط الملف
      // ========================================================

      debugPrint(
        '5️⃣ جاري الحصول على رابط الملف...',
      );

      final downloadUrl =
          await storageRef.getDownloadURL();

      debugPrint(
        '✅ تم الحصول على الرابط بنجاح',
      );

      debugPrint(
        '🔗 URL: $downloadUrl',
      );

      // ========================================================
      // 7 - حفظ التقرير في Firestore
      // ========================================================

      debugPrint(
        '6️⃣ جاري حفظ التقرير في Firestore...',
      );

      await FirebaseFirestore.instance
          .collection('daily_reports')
          .doc(reportId)
          .set({
        'employeeEmail': currentEmail,
        'employeeName': currentName,

        'role': role,
        'department': department,
        'jobTitle': jobTitle,

        'dateKey': todayKey,
        'monthKey': currentMonthKey,

        'reportType': reportType,

        'workingHours':
            double.tryParse(hours) ?? 0,

        'description': description,

        'names':
            namesController.text.trim(),

        'numbers':
            numbersController.text.trim(),

        'notes':
            notesController.text.trim(),

        'excelFileName': safeFileName,
        'excelUrl': downloadUrl,
        'storagePath': storageRef.fullPath,
        'storageBucket': storageBucket,

        'createdAt':
            FieldValue.serverTimestamp(),

        'status': 'submitted',
      });

      debugPrint(
        '✅ تم حفظ التقرير في Firestore بنجاح',
      );

      debugPrint(
        '🎉🎉🎉 تم إرسال التقرير بالكامل بنجاح 🎉🎉🎉',
      );

      debugPrint(
        '📁 الملف موجود في Firebase Storage',
      );

      debugPrint(
        '🔗 $downloadUrl',
      );

      debugPrint(
        '==============================',
      );

      if (!mounted) return;

      clearForm();

      showMessage(
        'تم رفع ملف Excel وإرسال التقرير بنجاح',
        green,
      );
    } on FirebaseException catch ( e,stackTrace) {
      debugPrint('==============================');
      debugPrint('❌ FirebaseException');
      debugPrint('❌ CODE: ${e.code}');
      debugPrint('❌ MESSAGE: ${e.message}');
      debugPrint('❌ PLUGIN: ${e.plugin}');
      debugPrint(
        '❌ STACK TRACE: $stackTrace',
      );
      debugPrint('==============================');

      if (!mounted) return;

      String message;

      switch (e.code) {
        case 'storage/unauthorized':
          message =
              'ليس لديك صلاحية لرفع الملفات إلى Firebase Storage';
          break;

        case 'storage/unauthenticated':
          message =
              'انتهت جلسة تسجيل الدخول، سجلي الدخول مرة أخرى';
          break;

        case 'storage/retry-limit-exceeded':
          message =
              'تعذر الاتصال بـ Firebase Storage. '
              'تأكدي من اتصال الإنترنت وأن Firebase Storage مفعّل';
          break;

        case 'storage/canceled':
          message =
              'تم إلغاء رفع الملف';
          break;

        case 'storage/quota-exceeded':
          message =
              'تم تجاوز مساحة Firebase Storage المتاحة';
          break;

        case 'storage/object-not-found':
          message =
              'لم يتم العثور على الملف في Firebase Storage';
          break;

        case 'storage/invalid-checksum':
          message =
              'حدث خطأ أثناء التحقق من الملف المرفوع';
          break;

        case 'storage/invalid-argument':
          message =
              'بيانات الملف غير صحيحة';
          break;

        case 'storage/unknown':
          message =
              'حدث خطأ غير معروف في Firebase Storage';
          break;

        default:
          message =
              'فشل Firebase Storage:\n'
              '${e.message ?? e.code}';
      }

      showMessage(
        message,
        red,
      );
    } catch (e, stackTrace) {
      debugPrint('==============================');
      debugPrint('❌ فشل إرسال التقرير');
      debugPrint('❌ ERROR: $e');
      debugPrint(
        '❌ STACK TRACE: $stackTrace',
      );
      debugPrint('==============================');

      if (!mounted) return;

      showMessage(
        'فشل إرسال التقرير:\n$e',
        red,
      );
    } finally {
      if (mounted) {
        setState(() {
          isSending = false;
        });
      }
    }
  }

  // ============================================================
  // إنشاء ملف Excel
  // ============================================================

  Future<List<int>> createExcelFile({
    required String name,
    required String email,
    required String jobTitle,
    required String department,
    required String hours,
    required String description,
    required String names,
    required String numbers,
    required String notes,
    required String date,
    required String type,
  }) async {
    final excelFile =
        excel.Excel.createExcel();

    final sheet =
        excelFile['التقرير'];

    sheet.appendRow([
      excel.TextCellValue(
        'التقرير اليومي',
      ),
    ]);

    sheet.appendRow([
      excel.TextCellValue(''),
    ]);

    sheet.appendRow([
      excel.TextCellValue(
        'اسم الموظف',
      ),
      excel.TextCellValue(name),
    ]);

    sheet.appendRow([
      excel.TextCellValue(
        'البريد الإلكتروني',
      ),
      excel.TextCellValue(email),
    ]);

    sheet.appendRow([
      excel.TextCellValue(
        'المسمى الوظيفي',
      ),
      excel.TextCellValue(jobTitle),
    ]);

    sheet.appendRow([
      excel.TextCellValue(
        'القسم',
      ),
      excel.TextCellValue(department),
    ]);

    sheet.appendRow([
      excel.TextCellValue(
        'نوع التقرير',
      ),
      excel.TextCellValue(
        type == 'daily'
            ? 'يومي'
            : type == 'weekly'
                ? 'أسبوعي'
                : 'شهري',
      ),
    ]);

    sheet.appendRow([
      excel.TextCellValue(
        'التاريخ',
      ),
      excel.TextCellValue(date),
    ]);

    sheet.appendRow([
      excel.TextCellValue(
        'ساعات العمل',
      ),
      excel.TextCellValue(hours),
    ]);

    sheet.appendRow([
      excel.TextCellValue(
        'الأسماء',
      ),
      excel.TextCellValue(names),
    ]);

    sheet.appendRow([
      excel.TextCellValue(
        'الأرقام',
      ),
      excel.TextCellValue(numbers),
    ]);

    sheet.appendRow([
      excel.TextCellValue(
        'الوصف',
      ),
      excel.TextCellValue(description),
    ]);

    sheet.appendRow([
      excel.TextCellValue(
        'ملاحظات',
      ),
      excel.TextCellValue(notes),
    ]);

    final bytes =
        excelFile.encode();

    if (bytes == null ||
        bytes.isEmpty) {
      throw Exception(
        'تعذر إنشاء ملف Excel',
      );
    }

    return bytes;
  }

  // ============================================================
  // تفريغ النموذج
  // ============================================================

  void clearForm() {
    hoursController.clear();
    descriptionController.clear();
    namesController.clear();
    numbersController.clear();
    notesController.clear();

    setState(() {
      reportType = 'daily';
    });
  }

  // ============================================================
  // الرسائل
  // ============================================================

  void showMessage(
    String message,
    Color color,
  ) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: GoogleFonts.cairo(
              color: Colors.white,
            ),
          ),
          backgroundColor: color,
          behavior:
              SnackBarBehavior.floating,
          duration:
              const Duration(seconds: 5),
        ),
      );
  }

  // ============================================================
  // حقول الإدخال
  // ============================================================

  Widget inputField({
    required String label,
    required String hint,
    required TextEditingController controller,
    int maxLines = 1,
    TextInputType keyboardType =
        TextInputType.text,
  }) {
    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 14,
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        textDirection:
            TextDirection.rtl,
        style: GoogleFonts.cairo(
          color: navy,
          fontSize: 13,
        ),
        decoration:
            InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle:
              GoogleFonts.cairo(
            color: grey,
            fontSize: 12,
          ),
          hintStyle:
              GoogleFonts.cairo(
            color:
                grey.withValues(alpha: .6),
            fontSize: 12,
          ),
          filled: true,
          fillColor: lightGrey,
          border:
              OutlineInputBorder(
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
    );
  }

  // ============================================================
  // أزرار نوع التقرير
  // ============================================================

  Widget reportTypeButton({
    required String value,
    required String title,
    required IconData icon,
  }) {
    final selected =
        reportType == value;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            reportType = value;
          });
        },
        child: Container(
          padding:
              const EdgeInsets.symmetric(
            vertical: 12,
          ),
          margin:
              const EdgeInsets.symmetric(
            horizontal: 3,
          ),
          decoration:
              BoxDecoration(
            color: selected
                ? navy
                : Colors.white,
            borderRadius:
                BorderRadius.circular(13),
            border: Border.all(
              color: selected
                  ? navy
                  : border,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: selected
                    ? Colors.white
                    : navy,
                size: 21,
              ),
              const SizedBox(
                height: 5,
              ),
              Text(
                title,
                style:
                    GoogleFonts.cairo(
                  color: selected
                      ? Colors.white
                      : navy,
                  fontSize: 11,
                  fontWeight:
                      FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // الواجهة
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor: lightGrey,
      appBar: AppBar(
        backgroundColor:
            Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'إرسال التقارير',
          style:
              GoogleFonts.cairo(
            color: navy,
            fontWeight:
                FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding:
            const EdgeInsets.all(16),
        child: Column(
          children: [
            // ==================================================
            // بيانات الموظف
            // ==================================================

            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.all(18),
              decoration:
                  BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.circular(18),
                border: Border.all(
                  color: border,
                ),
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  Text(
                    'بيانات الموظف',
                    style:
                        GoogleFonts.cairo(
                      color: navy,
                      fontSize: 16,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                  const SizedBox(
                    height: 12,
                  ),
                  infoRow(
                    'اسم الموظف',
                    currentName,
                  ),
                  infoRow(
                    'البريد',
                    currentEmail,
                  ),
                  infoRow(
                    'التاريخ',
                    todayKey,
                  ),
                ],
              ),
            ),

            const SizedBox(
              height: 14,
            ),

            // ==================================================
            // نوع التقرير
            // ==================================================

            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.all(16),
              decoration:
                  BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.circular(18),
                border: Border.all(
                  color: border,
                ),
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  Text(
                    'نوع التقرير',
                    style:
                        GoogleFonts.cairo(
                      color: navy,
                      fontWeight:
                          FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(
                    height: 10,
                  ),
                  Row(
                    children: [
                      reportTypeButton(
                        value: 'daily',
                        title: 'يومي',
                        icon:
                            Icons.today_outlined,
                      ),
                      reportTypeButton(
                        value: 'weekly',
                        title: 'أسبوعي',
                        icon:
                            Icons.date_range,
                      ),
                      reportTypeButton(
                        value: 'monthly',
                        title: 'شهري',
                        icon:
                            Icons.calendar_month,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(
              height: 14,
            ),

            // ==================================================
            // بيانات التقرير
            // ==================================================

            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.all(16),
              decoration:
                  BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.circular(18),
                border: Border.all(
                  color: border,
                ),
              ),
              child: Column(
                children: [
                  inputField(
                    label: 'ساعات العمل',
                    hint: 'مثال: 8',
                    controller:
                        hoursController,
                    keyboardType:
                        const TextInputType
                            .numberWithOptions(
                      decimal: true,
                    ),
                  ),

                  inputField(
                    label: 'الأسماء',
                    hint:
                        'أدخل الأسماء إذا وجدت',
                    controller:
                        namesController,
                    maxLines: 3,
                  ),

                  inputField(
                    label: 'الأرقام',
                    hint:
                        'أدخل الأرقام المطلوبة',
                    controller:
                        numbersController,
                    maxLines: 3,
                  ),

                  inputField(
                    label: 'الوصف',
                    hint:
                        'اكتب وصف الأعمال التي تم إنجازها',
                    controller:
                        descriptionController,
                    maxLines: 5,
                  ),

                  inputField(
                    label: 'ملاحظات',
                    hint:
                        'ملاحظات إضافية - اختياري',
                    controller:
                        notesController,
                    maxLines: 3,
                  ),
                ],
              ),
            ),

            const SizedBox(
              height: 18,
            ),

            // ==================================================
            // زر إرسال التقرير
            // ==================================================

            SizedBox(
              width: double.infinity,
              height: 54,
              child:
                  ElevatedButton.icon(
                onPressed:
                    isSending
                        ? null
                        : sendReport,
                icon: isSending
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
                    : const Icon(
                        Icons
                            .file_upload_outlined,
                      ),
                label: Text(
                  isSending
                      ? 'جاري إنشاء وإرسال التقرير...'
                      : 'إنشاء وإرسال تقرير Excel',
                  style:
                      GoogleFonts.cairo(
                    fontWeight:
                        FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),

            const SizedBox(
              height: 12,
            ),

            // ==================================================
            // زر اختبار Firestore
            // ==================================================

            SizedBox(
              width: double.infinity,
              height: 50,
              child:
                  OutlinedButton.icon(
                onPressed:
                    isTestingFirestore
                        ? null
                        : testFirestore,
                icon:
                    isTestingFirestore
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(
                            Icons
                                .cloud_done_outlined,
                          ),
                label: Text(
                  isTestingFirestore
                      ? 'جاري اختبار قاعدة البيانات...'
                      : 'اختبار قاعدة البيانات',
                  style:
                      GoogleFonts.cairo(
                    color: navy,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(
              height: 20,
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // صف بيانات الموظف
  // ============================================================

  Widget infoRow(
    String title,
    String value,
  ) {
    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 8,
      ),
      child: Row(
        children: [
          Text(
            '$title:',
            style:
                GoogleFonts.cairo(
              color: grey,
              fontSize: 12,
            ),
          ),
          const SizedBox(
            width: 8,
          ),
          Expanded(
            child: Text(
              value,
              textAlign:
                  TextAlign.right,
              style:
                  GoogleFonts.cairo(
                color: navy,
                fontSize: 12,
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
