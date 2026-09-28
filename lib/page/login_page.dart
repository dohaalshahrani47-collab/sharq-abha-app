import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

import 'signup_page.dart';
import 'employee_tasks_page.dart';
import 'home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // ============================================================
  // الألوان الموحدة
  // ============================================================

  static const Color navy = Color(0xFF172B4D);
  static const Color navy2 = Color(0xFF243B5A);
  static const Color grey = Color(0xFF6B7280);
  static const Color lightGrey = Color(0xFFF3F5F8);
  static const Color border = Color(0xFFE1E5EA);

  // ============================================================
  // Controllers
  // ============================================================

  final TextEditingController emailController =
      TextEditingController();

  final TextEditingController passwordController =
      TextEditingController();

  bool isLoading = false;
  bool obscurePassword = true;

  // ============================================================
  // Dispose
  // ============================================================

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // ============================================================
  // تسجيل الدخول
  // ============================================================

  Future<void> loginUser() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      showMessage(
        'الرجاء إدخال البريد الإلكتروني وكلمة المرور',
        Colors.orange,
      );
      return;
    }

    if (isLoading) return;

    setState(() {
      isLoading = true;
    });

    try {
      // ========================================================
      // تسجيل الدخول في Firebase Authentication
      // ========================================================

      final UserCredential userCredential =
          await FirebaseAuth.instance
              .signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final User? user = userCredential.user;

      if (user == null) {
        throw Exception(
          'تعذر الحصول على بيانات المستخدم',
        );
      }

      // ========================================================
      // جلب بيانات المستخدم من Firestore
      // ========================================================

      final DocumentSnapshot<Map<String, dynamic>>
          userDocument =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

      if (!userDocument.exists) {
        await FirebaseAuth.instance.signOut();

        if (!mounted) return;

        showMessage(
          'حسابك موجود في Firebase ولكن بياناته غير موجودة في قاعدة البيانات.',
          Colors.red,
        );

        return;
      }

      final data = userDocument.data() ?? {};

      final String role =
          (data['role'] ?? '')
              .toString()
              .trim()
              .toLowerCase();

      final String status =
          (data['status'] ?? '')
              .toString()
              .trim()
              .toLowerCase();

      // ========================================================
      // التحقق من حالة الحساب
      // ========================================================

      if (status != 'approved') {
        await FirebaseAuth.instance.signOut();

        if (!mounted) return;

        if (status == 'pending') {
          showMessage(
            'حسابك ما زال بانتظار موافقة الإدارة.',
            Colors.orange,
          );
        } else {
          showMessage(
            'حسابك غير مقبول للدخول حالياً.',
            Colors.red,
          );
        }

        return;
      }

      if (!mounted) return;

      // ========================================================
      // المدير
      // ========================================================

      if (role == 'admin') {
        await Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) =>
                const AdminDashboardPage(),
          ),
        );

        return;
      }

      // ========================================================
      // المسوق
      // ========================================================

      if (role == 'marketing') {
        await Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) =>
                const EmployeeTasksPage(),
          ),
        );

        return;
      }

      // ========================================================
      // الدور غير معروف
      // ========================================================

      await FirebaseAuth.instance.signOut();

      if (!mounted) return;

      showMessage(
        'نوع الحساب غير معروف. تأكدي من بيانات المستخدم في قاعدة البيانات.',
        Colors.red,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String message;

      switch (e.code) {
        case 'invalid-credential':
        case 'wrong-password':
        case 'user-not-found':
          message =
              'البريد الإلكتروني أو كلمة المرور غير صحيحة';
          break;

        case 'invalid-email':
          message =
              'البريد الإلكتروني غير صحيح';
          break;

        case 'user-disabled':
          message =
              'هذا الحساب تم تعطيله';
          break;

        case 'too-many-requests':
          message =
              'تمت محاولات كثيرة، حاول مرة أخرى لاحقاً';
          break;

        case 'network-request-failed':
          message =
              'تأكد من اتصالك بالإنترنت';
          break;

        default:
          message =
              'حدث خطأ أثناء تسجيل الدخول';
      }

      showMessage(
        message,
        Colors.red,
      );
    } catch (e) {
      if (!mounted) return;

      showMessage(
        'حدث خطأ غير متوقع أثناء تسجيل الدخول',
        Colors.red,
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // ============================================================
  // رسالة
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
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),

          backgroundColor: color,

          behavior:
              SnackBarBehavior.floating,

          margin:
              const EdgeInsets.all(16),

          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(12),
          ),
        ),
      );
  }

  // ============================================================
  // فتح صفحة التسجيل
  // ============================================================

  void openSignupPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            const SignupPage(),
      ),
    );
  }

  // ============================================================
  // حقل إدخال موحد
  // ============================================================

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,

      hintStyle: GoogleFonts.cairo(
        color: grey,
        fontSize: 12,
      ),

      prefixIcon: Icon(
        icon,
        color: grey,
        size: 21,
      ),

      suffixIcon: suffixIcon,

      filled: true,

      fillColor: Colors.white,

      contentPadding:
          const EdgeInsets.symmetric(
        horizontal: 15,
        vertical: 15,
      ),

      border: OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(13),
        borderSide: const BorderSide(
          color: border,
        ),
      ),

      enabledBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(13),
        borderSide: const BorderSide(
          color: border,
        ),
      ),

      focusedBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(13),
        borderSide:
            const BorderSide(
          color: navy,
          width: 1.5,
        ),
      ),
    );
  }

  // ============================================================
  // Build
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,

      child: Scaffold(
        backgroundColor: lightGrey,

        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 25,
              ),

              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(
                  maxWidth: 500,
                ),

                child: Column(
                  children: [

                    // ==================================================
                    // الشعار
                    // ==================================================

                    Container(
                      width: 92,
                      height: 92,

                      decoration:
                          BoxDecoration(
                        color: navy,

                        borderRadius:
                            BorderRadius.circular(
                          25,
                        ),

                        boxShadow: [
                          BoxShadow(
                            color: navy
                                .withValues(alpha :0.15,),
                            blurRadius: 15,
                            offset:
                                const Offset(
                              0,
                              6,
                            ),
                          ),
                        ],
                      ),

                      child: const Icon(
                        Icons.business_outlined,
                        color: Colors.white,
                        size: 46,
                      ),
                    ),

                    const SizedBox(
                      height: 22,
                    ),

                    // ==================================================
                    // اسم التطبيق
                    // ==================================================

                    Text(
                      'شرق أبها',
                      style:
                          GoogleFonts.cairo(
                        color: navy,
                        fontSize: 28,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    const SizedBox(
                      height: 2,
                    ),

                    Text(
                      'نظام إدارة الشركة',
                      style:
                          GoogleFonts.cairo(
                        color: grey,
                        fontSize: 12,
                      ),
                    ),

                    const SizedBox(
                      height: 30,
                    ),

                    // ==================================================
                    // بطاقة تسجيل الدخول
                    // ==================================================

                    Container(
                      width: double.infinity,

                      padding:
                          const EdgeInsets
                              .all(20),

                      decoration:
                          BoxDecoration(
                        color: Colors.white,

                        borderRadius:
                            BorderRadius
                                .circular(
                          20,
                        ),

                        border:
                            Border.all(
                          color: border,
                        ),

                        boxShadow: [
                          BoxShadow(
                            color: Colors.black
                                .withValues(alpha: 
                              0.04,
                            ),
                            blurRadius: 15,
                            offset:
                                const Offset(
                              0,
                              5,
                            ),
                          ),
                        ],
                      ),

                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,

                        children: [

                          // ==========================================
                          // العنوان
                          // ==========================================

                          Center(
                            child: Text(
                              'تسجيل الدخول',
                              style:
                                  GoogleFonts
                                      .cairo(
                                color: navy,
                                fontSize: 20,
                                fontWeight:
                                    FontWeight
                                        .bold,
                              ),
                            ),
                          ),

                          const SizedBox(
                            height: 5,
                          ),

                          Center(
                            child: Text(
                              'أدخل بيانات حسابك للمتابعة',
                              style:
                                  GoogleFonts
                                      .cairo(
                                color: grey,
                                fontSize: 11,
                              ),
                            ),
                          ),

                          const SizedBox(
                            height: 25,
                          ),

                          // ==========================================
                          // البريد الإلكتروني
                          // ==========================================

                          Text(
                            'البريد الإلكتروني',
                            style:
                                GoogleFonts
                                    .cairo(
                              color: navy,
                              fontSize: 12,
                              fontWeight:
                                  FontWeight
                                      .bold,
                            ),
                          ),

                          const SizedBox(
                            height: 7,
                          ),

                          TextField(
                            controller:
                                emailController,

                            keyboardType:
                                TextInputType
                                    .emailAddress,

                            textDirection:
                                TextDirection
                                    .ltr,

                            style:
                                GoogleFonts
                                    .cairo(
                              color: navy,
                              fontSize: 13,
                            ),

                            decoration:
                                _inputDecoration(
                              hint:
                                  'example@email.com',
                              icon:
                                  Icons
                                      .email_outlined,
                            ),
                          ),

                          const SizedBox(
                            height: 18,
                          ),

                          // ==========================================
                          // كلمة المرور
                          // ==========================================

                          Text(
                            'كلمة المرور',
                            style:
                                GoogleFonts
                                    .cairo(
                              color: navy,
                              fontSize: 12,
                              fontWeight:
                                  FontWeight
                                      .bold,
                            ),
                          ),

                          const SizedBox(
                            height: 7,
                          ),

                          TextField(
                            controller:
                                passwordController,

                            obscureText:
                                obscurePassword,

                            textDirection:
                                TextDirection
                                    .ltr,

                            style:
                                GoogleFonts
                                    .cairo(
                              color: navy,
                              fontSize: 13,
                            ),

                            onSubmitted: (_) {
                              if (!isLoading) {
                                loginUser();
                              }
                            },

                            decoration:
                                _inputDecoration(
                              hint:
                                  'كلمة المرور',
                              icon:
                                  Icons
                                      .lock_outline,

                              suffixIcon:
                                  IconButton(
                                onPressed: () {
                                  setState(() {
                                    obscurePassword =
                                        !obscurePassword;
                                  });
                                },

                                icon: Icon(
                                  obscurePassword
                                      ? Icons
                                          .visibility_off_outlined
                                      : Icons
                                          .visibility_outlined,

                                  color: grey,

                                  size: 21,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(
                            height: 25,
                          ),

                          // ==========================================
                          // زر تسجيل الدخول
                          // ==========================================

                          SizedBox(
                            width:
                                double.infinity,

                            height: 52,

                            child:
                                ElevatedButton(
                              onPressed:
                                  isLoading
                                      ? null
                                      : loginUser,

                              style:
                                  ElevatedButton
                                      .styleFrom(
                                backgroundColor:
                                    navy,

                                foregroundColor:
                                    Colors.white,

                                disabledBackgroundColor:
                                    const Color(
                                  0xFF9CA3AF,
                                ),

                                elevation: 0,

                                shape:
                                    RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius
                                          .circular(
                                    13,
                                  ),
                                ),
                              ),

                              child: isLoading
                                  ? const SizedBox(
                                      width: 23,
                                      height: 23,
                                      child:
                                          CircularProgressIndicator(
                                        strokeWidth:
                                            2.5,
                                        color:
                                            Colors
                                                .white,
                                      ),
                                    )
                                  : Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment
                                              .center,
                                      children: [

                                        const Icon(
                                          Icons
                                              .login_rounded,
                                          size: 20,
                                        ),

                                        const SizedBox(
                                          width: 8,
                                        ),

                                        Text(
                                          'تسجيل الدخول',
                                          style:
                                              GoogleFonts
                                                  .cairo(
                                            color:
                                                Colors
                                                    .white,
                                            fontSize:
                                                15,
                                            fontWeight:
                                                FontWeight
                                                    .bold,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),

                          const SizedBox(
                            height: 18,
                          ),

                          // ==========================================
                          // إنشاء حساب
                          // ==========================================

                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment
                                    .center,

                            children: [

                              Text(
                                'ليس لديك حساب؟',
                                style:
                                    GoogleFonts
                                        .cairo(
                                  color: grey,
                                  fontSize: 11,
                                ),
                              ),

                              TextButton(
                                onPressed:
                                    isLoading
                                        ? null
                                        : openSignupPage,

                                style:
                                    TextButton
                                        .styleFrom(
                                  padding:
                                      const EdgeInsets
                                          .symmetric(
                                    horizontal: 6,
                                  ),
                                ),

                                child: Text(
                                  'إنشاء حساب جديد',
                                  style:
                                      GoogleFonts
                                          .cairo(
                                    color: navy,
                                    fontSize: 12,
                                    fontWeight:
                                        FontWeight
                                            .bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(
                      height: 15,
                    ),

                    // ==================================================
                    // ملاحظة
                    // ==================================================

                    Container(
                      width: double.infinity,

                      padding:
                          const EdgeInsets
                              .symmetric(
                        horizontal: 14,
                        vertical: 11,
                      ),

                      decoration:
                          BoxDecoration(
                        color: Colors.white,
                        borderRadius:
                            BorderRadius
                                .circular(
                          12,
                        ),
                        border:
                            Border.all(
                          color: border,
                        ),
                      ),

                      child: Row(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,

                        children: [

                          const Icon(
                            Icons
                                .info_outline,
                            color: grey,
                            size: 18,
                          ),

                          const SizedBox(
                            width: 8,
                          ),

                          Expanded(
                            child: Text(
                              'يجب أن تتم الموافقة على حسابك من الإدارة قبل تسجيل الدخول.',
                              textAlign:
                                  TextAlign.right,

                              style:
                                  GoogleFonts
                                      .cairo(
                                color: grey,
                                fontSize: 10,
                                height: 1.6,
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
          ),
        ),
      ),
    );
  }
}