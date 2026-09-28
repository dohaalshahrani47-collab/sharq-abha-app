import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

import 'login_page.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  // ============================================================
  // الألوان الموحدة مع باقي صفحات التطبيق
  // ============================================================

  static const Color navy = Color(0xFF172B4D);
  static const Color navy2 = Color(0xFF243B5A);
  static const Color grey = Color(0xFF6B7280);
  static const Color lightGrey = Color(0xFFF3F5F8);
  static const Color border = Color(0xFFE1E5EA);

  // ============================================================
  // Controllers
  // ============================================================

  final TextEditingController nameController =
      TextEditingController();

  final TextEditingController emailController =
      TextEditingController();

  final TextEditingController phoneController =
      TextEditingController();

  final TextEditingController passwordController =
      TextEditingController();

  // مهم:
  // يجب أن تكون القيمة موجودة داخل Dropdown.
  // لذلك نبدأ بـ employee وليس admin.
  String selectedRole = 'employee';

  bool isLoading = false;
  bool obscurePassword = true;

  // ============================================================
  // التخلص من Controllers
  // ============================================================

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    passwordController.dispose();

    super.dispose();
  }

  // ============================================================
  // تسجيل المستخدم
  // ============================================================

  Future<void> registerUser() async {
    final name = nameController.text.trim();
    final email = emailController.text.trim();
    final phone = phoneController.text.trim();
    final password = passwordController.text.trim();

    // ------------------------------------------------------------
    // التحقق من الحقول
    // ------------------------------------------------------------

    if (name.isEmpty ||
        email.isEmpty ||
        phone.isEmpty ||
        password.isEmpty) {
      showMessage(
        'الرجاء تعبئة جميع الحقول المطلوبة',
        Colors.orange,
      );
      return;
    }

    if (password.length < 6) {
      showMessage(
        'كلمة المرور يجب أن تكون 6 أحرف أو أرقام على الأقل',
        Colors.orange,
      );
      return;
    }

    // ------------------------------------------------------------
    // بدء التحميل
    // ------------------------------------------------------------

    setState(() {
      isLoading = true;
    });

    UserCredential? userCredential;

    try {
      // ==========================================================
      // 1. إنشاء الحساب في Firebase Authentication
      // ==========================================================

      userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final User? user = userCredential.user;

      if (user == null) {
        throw Exception('تعذر إنشاء الحساب');
      }

      // ==========================================================
      // 2. حفظ بيانات المستخدم في Firestore
      // ==========================================================

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
        'name': name,
        'email': email,
        'phone': phone,
        'role': selectedRole,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // ==========================================================
      // 3. تسجيل الخروج بعد إنشاء الحساب
      // ==========================================================

      await FirebaseAuth.instance.signOut();

      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      // ==========================================================
      // 4. رسالة نجاح
      // ==========================================================

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.check_circle_outline,
                      color: Colors.green,
                      size: 25,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'تم إرسال طلبك بنجاح',
                      style: GoogleFonts.cairo(
                        color: navy,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              content: Text(
                'تم إنشاء حسابك وحفظ بياناتك بنجاح.\n\n'
                'سيتم مراجعة طلبك من الإدارة، '
                'وبعد الموافقة ستتمكن من تسجيل الدخول.',
                style: GoogleFonts.cairo(
                  color: grey,
                  fontSize: 14,
                  height: 1.7,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(
                      dialogContext,
                      MaterialPageRoute(
                        builder: (context) => const LoginPage(),
                      ),
                      (route) => false,
                    );
                  },
                  child: Text(
                    'موافق',
                    style: GoogleFonts.cairo(
                      color: navy,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    } on FirebaseAuthException catch (e) {
      // ==========================================================
      // خطأ Firebase Authentication
      // ==========================================================

      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }

      String message;

      switch (e.code) {
        case 'email-already-in-use':
          message =
              'هذا البريد الإلكتروني مسجل مسبقاً. حاول تسجيل الدخول.';
          break;

        case 'invalid-email':
          message = 'البريد الإلكتروني غير صحيح.';
          break;

        case 'weak-password':
          message =
              'كلمة المرور ضعيفة. استخدم كلمة مرور أقوى.';
          break;

        case 'operation-not-allowed':
          message =
              'تسجيل الدخول بالبريد الإلكتروني غير مفعل في Firebase.';
          break;

        case 'network-request-failed':
          message = 'تأكد من اتصالك بالإنترنت.';
          break;

        default:
          message =
              'حدث خطأ أثناء إنشاء الحساب. حاول مرة أخرى.';
      }

      showMessage(message, Colors.red);
    } on FirebaseException catch (e) {
      // ==========================================================
      // خطأ Firestore
      // ==========================================================

      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }

      // الحساب تم إنشاؤه في Authentication
      // لكن حصل خطأ أثناء حفظ بياناته
      await FirebaseAuth.instance.signOut();

      String message;

      if (e.code == 'permission-denied') {
        message =
            'تم إنشاء الحساب، لكن لا توجد صلاحية لحفظ بياناته في قاعدة البيانات.';
      } else {
        message =
            'تم إنشاء الحساب لكن حدث خطأ أثناء حفظ بياناتك في قاعدة البيانات.';
      }

      showMessage(message, Colors.red);
    } catch (e) {
      // ==========================================================
      // خطأ غير متوقع
      // ==========================================================

      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }

      await FirebaseAuth.instance.signOut();

      showMessage(
        'حدث خطأ غير متوقع أثناء إنشاء الحساب.',
        Colors.red,
      );
    }
  }

  // ============================================================
  // إظهار الرسائل
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
            textAlign: TextAlign.right,
            style: GoogleFonts.cairo(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
  }

  // ============================================================
  // عنوان الحقل
  // ============================================================

  Widget buildFieldTitle(String title) {
    return Align(
      alignment: Alignment.centerRight,
      child: Text(
        title,
        style: GoogleFonts.cairo(
          color: navy,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // ============================================================
  // شكل الحقول
  // ============================================================

  InputDecoration inputDecoration({
    required String hintText,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: GoogleFonts.cairo(
        color: grey.withValues(alpha: 0.55),
        fontSize: 13,
      ),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 15,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: border,
          width: 1,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: navy,
          width: 1.5,
        ),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: border,
        ),
      ),
    );
  }

  // ============================================================
  // الصفحة
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: lightGrey,

        // ========================================================
        // AppBar
        // ========================================================

        appBar: AppBar(
          elevation: 0,
          backgroundColor: navy,
          centerTitle: true,

          iconTheme: const IconThemeData(
            color: Colors.white,
          ),

          title: Text(
            'طلب انضمام لموظفي شرق أبها',
            style: GoogleFonts.cairo(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        // ========================================================
        // Body
        // ========================================================

        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),

            child: Column(
              children: [
                // ==================================================
                // العنوان العلوي
                // ==================================================

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: navy,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: const Icon(
                          Icons.person_add_alt_1_rounded,
                          color: Colors.white,
                          size: 27,
                        ),
                      ),

                      const SizedBox(width: 14),

                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              'إنشاء حساب جديد',
                              style: GoogleFonts.cairo(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            const SizedBox(height: 3),

                            Text(
                              'أرسل طلب الانضمام إلى فريق شرق أبها',
                              style: GoogleFonts.cairo(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ==================================================
                // بطاقة التسجيل
                // ==================================================

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: border,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // ============================================
                      // الاسم
                      // ============================================

                      buildFieldTitle(
                        'اسم الموظف الكامل',
                      ),

                      const SizedBox(height: 7),

                      TextField(
                        controller: nameController,
                        enabled: !isLoading,
                        textAlign: TextAlign.right,
                        style: GoogleFonts.cairo(
                          color: navy,
                          fontSize: 14,
                        ),
                        decoration: inputDecoration(
                          hintText: 'أدخل الاسم الكامل',
                          prefixIcon: const Icon(
                            Icons.person_outline,
                            color: grey,
                            size: 21,
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ============================================
                      // البريد الإلكتروني
                      // ============================================

                      buildFieldTitle(
                        'البريد الإلكتروني',
                      ),

                      const SizedBox(height: 7),

                      TextField(
                        controller: emailController,
                        enabled: !isLoading,
                        keyboardType:
                            TextInputType.emailAddress,
                        textDirection: TextDirection.ltr,
                        textAlign: TextAlign.left,
                        style: GoogleFonts.cairo(
                          color: navy,
                          fontSize: 14,
                        ),
                        decoration: inputDecoration(
                          hintText: 'example@email.com',
                          prefixIcon: const Icon(
                            Icons.email_outlined,
                            color: grey,
                            size: 21,
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ============================================
                      // رقم الجوال
                      // ============================================

                      buildFieldTitle(
                        'رقم الجوال',
                      ),

                      const SizedBox(height: 7),

                      TextField(
                        controller: phoneController,
                        enabled: !isLoading,
                        keyboardType: TextInputType.phone,
                        textAlign: TextAlign.right,
                        style: GoogleFonts.cairo(
                          color: navy,
                          fontSize: 14,
                        ),
                        decoration: inputDecoration(
                          hintText: '05xxxxxxxx',
                          prefixIcon: const Icon(
                            Icons.phone_outlined,
                            color: grey,
                            size: 21,
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ============================================
                      // كلمة المرور
                      // ============================================

                      buildFieldTitle(
                        'كلمة المرور',
                      ),

                      const SizedBox(height: 7),

                      TextField(
                        controller: passwordController,
                        enabled: !isLoading,
                        obscureText: obscurePassword,
                        textDirection: TextDirection.ltr,
                        textAlign: TextAlign.left,
                        style: GoogleFonts.cairo(
                          color: navy,
                          fontSize: 14,
                        ),
                        decoration: inputDecoration(
                          hintText: 'أدخل كلمة المرور',
                          prefixIcon: const Icon(
                            Icons.lock_outline,
                            color: grey,
                            size: 21,
                          ),
                          suffixIcon: IconButton(
                            onPressed: isLoading
                                ? null
                                : () {
                                    setState(() {
                                      obscurePassword =
                                          !obscurePassword;
                                    });
                                  },
                            icon: Icon(
                              obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: grey,
                              size: 21,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ============================================
                      // القسم / الوظيفة
                      // ============================================

                      buildFieldTitle(
                        'حدد القسم / الوظيفة',
                      ),

                      const SizedBox(height: 7),

                      DropdownButtonFormField<String>(
                        initialValue: selectedRole,

                        isExpanded: true,

                        dropdownColor: Colors.white,

                        style: GoogleFonts.cairo(
                          color: navy,
                          fontSize: 14,
                        ),

                        icon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: grey,
                        ),

                        items: [
                          DropdownMenuItem<String>(
                            value: 'employee',
                            child: Text(
                              'مسوق / موظف ميداني',
                              style: GoogleFonts.cairo(
                                color: navy,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          DropdownMenuItem<String>(
                            value: 'hr',
                            child: Text(
                              'الموارد البشرية (HR)',
                              style: GoogleFonts.cairo(
                                color: navy,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],

                        onChanged: isLoading
                            ? null
                            : (String? value) {
                                if (value == null) return;

                                setState(() {
                                  selectedRole = value;
                                });
                              },

                        decoration: inputDecoration(
                          hintText: 'اختر القسم / الوظيفة',
                          prefixIcon: const Icon(
                            Icons.work_outline,
                            color: grey,
                            size: 21,
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ============================================
                      // ملاحظة
                      // ============================================

                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: lightGrey,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: border,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.info_outline_rounded,
                              color: navy,
                              size: 20,
                            ),

                            const SizedBox(width: 10),

                            Expanded(
                              child: Text(
                                'بعد إنشاء الحساب سيتم حفظ بياناتك في النظام، '
                                'ويجب أن توافق الإدارة على طلبك قبل تسجيل الدخول.',
                                textAlign: TextAlign.right,
                                style: GoogleFonts.cairo(
                                  color: grey,
                                  fontSize: 11,
                                  height: 1.7,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 22),

                      // ============================================
                      // زر إنشاء الحساب
                      // ============================================

                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed:
                              isLoading ? null : registerUser,

                          style: ElevatedButton.styleFrom(
                            backgroundColor: navy,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor:
                                Colors.grey.shade400,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(12),
                            ),
                          ),

                          child: isLoading
                              ? const SizedBox(
                                  width: 23,
                                  height: 23,
                                  child:
                                      CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  'إرسال طلب الانضمام للإدارة',
                                  style: GoogleFonts.cairo(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // ==================================================
                // الرجوع لتسجيل الدخول
                // ==================================================

                TextButton.icon(
                  onPressed: isLoading
                      ? null
                      : () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const LoginPage(),
                            ),
                          );
                        },
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    size: 18,
                  ),
                  label: Text(
                    'لديك حساب بالفعل؟ تسجيل الدخول',
                    style: GoogleFonts.cairo(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: navy,
                  ),
                ),

                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }
}