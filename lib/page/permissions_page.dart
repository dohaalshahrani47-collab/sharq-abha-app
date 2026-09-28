import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class PermissionsPage extends StatefulWidget {
  const PermissionsPage({super.key});

  @override
  State<PermissionsPage> createState() => _PermissionsPageState();
}

class _PermissionsPageState extends State<PermissionsPage> {
  final TextEditingController searchController = TextEditingController();

  String searchText = '';
  String selectedFilter = 'all';

  static const Color navy = Color(0xFF172B4D);
  static const Color navy2 = Color(0xFF243B5A);
  static const Color grey = Color(0xFF6B7280);
  static const Color lightGrey = Color(0xFFF3F5F8);
  static const Color border = Color(0xFFE1E5EA);
  static const Color green = Color(0xFF2E7D32);
  static const Color orange = Color(0xFFE58A00);
  static const Color red = Color(0xFFC62828);

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  String roleName(String role) {
    switch (role) {
      case 'admin':
        return 'مدير';
      case 'marketing':
        return 'مسوق / موظف ميداني';
      case 'hr':
        return 'الموارد البشرية';
      case 'auction':
        return 'موظف مزادات';
      case 'employee':
        return 'موظف';
      default:
        return role.isEmpty ? 'غير محدد' : role;
    }
  }

  Color statusColor(String status) {
    switch (status) {
      case 'approved':
        return green;
      case 'pending':
        return orange;
      case 'rejected':
        return red;
      default:
        return grey;
    }
  }

  String statusName(String status) {
    switch (status) {
      case 'approved':
        return 'معتمد';
      case 'pending':
        return 'بانتظار الموافقة';
      case 'rejected':
        return 'مرفوض';
      default:
        return 'غير معروف';
    }
  }

  bool matches(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    final name = (data['name'] ?? '').toString().toLowerCase();
    final email = (data['email'] ?? '').toString().toLowerCase();
    final role = (data['role'] ?? '').toString();
    final status = (data['status'] ?? '').toString();

    final search = searchText.toLowerCase().trim();

    final matchesSearch =
        search.isEmpty ||
        name.contains(search) ||
        email.contains(search);

    final matchesFilter =
        selectedFilter == 'all' || status == selectedFilter;

    return matchesSearch && matchesFilter;
  }

  Future<void> updateStatus(
    String uid,
    String status,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == 'approved'
                ? 'تم اعتماد الحساب'
                : 'تم رفض الحساب',
            style: GoogleFonts.cairo(),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'حدث خطأ: $e',
            style: GoogleFonts.cairo(),
          ),
        ),
      );
    }
  }

  Future<void> changeRole(
    String uid,
    String currentRole,
  ) async {
    String selectedRole = currentRole;

    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                'تعديل الصلاحية',
                style: GoogleFonts.cairo(
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: DropdownButtonFormField<String>(
                initialValue: selectedRole,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: lightGrey,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: border,
                    ),
                  ),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'marketing',
                    child: Text('مسوق / موظف ميداني'),
                  ),
                  DropdownMenuItem(
                    value: 'hr',
                    child: Text('الموارد البشرية'),
                  ),
                  DropdownMenuItem(
                    value: 'auction',
                    child: Text('موظف مزادات'),
                  ),
                  DropdownMenuItem(
                    value: 'employee',
                    child: Text('موظف'),
                  ),
                  DropdownMenuItem(
                    value: 'admin',
                    child: Text('مدير'),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;

                  setDialogState(() {
                    selectedRole = value;
                  });
                },
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text(
                    'إلغاء',
                    style: GoogleFonts.cairo(
                      color: grey,
                    ),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: navy,
                  ),
                  onPressed: () {
                    Navigator.pop(
                      context,
                      selectedRole,
                    );
                  },
                  child: Text(
                    'حفظ',
                    style: GoogleFonts.cairo(
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({
        'role': result,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم تعديل الصلاحية',
            style: GoogleFonts.cairo(),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'حدث خطأ: $e',
            style: GoogleFonts.cairo(),
          ),
        ),
      );
    }
  }

  Future<void> deleteUser(
    String uid,
    String name,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'حذف الحساب',
            style: GoogleFonts.cairo(
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'هل أنت متأكد من حذف حساب "$name"؟\n\n'
            'سيتم حذف بيانات الحساب من Firestore.',
            style: GoogleFonts.cairo(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'إلغاء',
                style: GoogleFonts.cairo(),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: red,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                'حذف',
                style: GoogleFonts.cairo(
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .delete();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم حذف الحساب',
            style: GoogleFonts.cairo(),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'حدث خطأ أثناء الحذف: $e',
            style: GoogleFonts.cairo(),
          ),
        ),
      );
    }
  }

  Widget buildFilterButton(
    String value,
    String title,
  ) {
    final selected = selectedFilter == value;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedFilter = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 9,
        ),
        decoration: BoxDecoration(
          color: selected ? navy : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? navy : border,
          ),
        ),
        child: Text(
          title,
          style: GoogleFonts.cairo(
            color: selected ? Colors.white : grey,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget buildUserCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    final uid = doc.id;
    final name = (data['name'] ?? 'بدون اسم').toString();
    final email = (data['email'] ?? '').toString();
    final phone = (data['phone'] ?? '').toString();
    final role = (data['role'] ?? '').toString();
    final status = (data['status'] ?? 'pending').toString();

    final createdAt = data['createdAt'];

    String dateText = '';

    if (createdAt is Timestamp) {
      final date = createdAt.toDate();

      dateText =
          '${date.day.toString().padLeft(2, '0')}/'
          '${date.month.toString().padLeft(2, '0')}/'
          '${date.year}';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: navy.withValues(alpha: .08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_outline,
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
                      name,
                      style: GoogleFonts.cairo(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: navy,
                      ),
                    ),
                    if (email.isNotEmpty)
                      Text(
                        email,
                        style: GoogleFonts.cairo(
                          fontSize: 12,
                          color: grey,
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
                  color: statusColor(status)
                      .withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  statusName(status),
                  style: GoogleFonts.cairo(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: statusColor(status),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: lightGrey,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                buildInfoRow(
                  Icons.badge_outlined,
                  'الصلاحية',
                  roleName(role),
                ),
                if (phone.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  buildInfoRow(
                    Icons.phone_outlined,
                    'الجوال',
                    phone,
                  ),
                ],
                if (dateText.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  buildInfoRow(
                    Icons.calendar_today_outlined,
                    'تاريخ التسجيل',
                    dateText,
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 12),

          if (status == 'pending')
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: green,
                      foregroundColor: Colors.white,
                      padding:
                          const EdgeInsets.symmetric(
                        vertical: 11,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      updateStatus(uid, 'approved');
                    },
                    icon: const Icon(
                      Icons.check,
                      size: 18,
                    ),
                    label: Text(
                      'قبول',
                      style: GoogleFonts.cairo(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: red,
                      side: const BorderSide(
                        color: red,
                      ),
                      padding:
                          const EdgeInsets.symmetric(
                        vertical: 11,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      updateStatus(uid, 'rejected');
                    },
                    icon: const Icon(
                      Icons.close,
                      size: 18,
                    ),
                    label: Text(
                      'رفض',
                      style: GoogleFonts.cairo(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),

          if (status == 'approved')
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: navy,
                      side: const BorderSide(
                        color: border,
                      ),
                      padding:
                          const EdgeInsets.symmetric(
                        vertical: 11,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      changeRole(uid, role);
                    },
                    icon: const Icon(
                      Icons.admin_panel_settings_outlined,
                      size: 18,
                    ),
                    label: Text(
                      'تعديل الصلاحية',
                      style: GoogleFonts.cairo(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'حذف الحساب',
                  onPressed: () {
                    deleteUser(uid, name);
                  },
                  icon: const Icon(
                    Icons.delete_outline,
                    color: red,
                  ),
                ),
              ],
            ),

          if (status == 'rejected')
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      updateStatus(uid, 'approved');
                    },
                    child: Text(
                      'اعتماد الحساب',
                      style: GoogleFonts.cairo(
                        color: green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () {
                    deleteUser(uid, name);
                  },
                  icon: const Icon(
                    Icons.delete_outline,
                    color: red,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget buildInfoRow(
    IconData icon,
    String title,
    String value,
  ) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: grey,
        ),
        const SizedBox(width: 8),
        Text(
          '$title:',
          style: GoogleFonts.cairo(
            fontSize: 12,
            color: grey,
          ),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: GoogleFonts.cairo(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: navy,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightGrey,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'الصلاحيات والحسابات',
          style: GoogleFonts.cairo(
            color: navy,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
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
                'حدث خطأ في تحميل الحسابات',
                style: GoogleFonts.cairo(
                  color: red,
                ),
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          final filteredDocs =
              docs.where(matches).toList();

          final pendingCount = docs.where((doc) {
            final data =
                doc.data() as Map<String, dynamic>;
            return data['status'] == 'pending';
          }).length;

          final approvedCount = docs.where((doc) {
            final data =
                doc.data() as Map<String, dynamic>;
            return data['status'] == 'approved';
          }).length;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius:
                            BorderRadius.circular(14),
                        border: Border.all(
                          color: border,
                        ),
                      ),
                      child: TextField(
                        controller: searchController,
                        onChanged: (value) {
                          setState(() {
                            searchText = value;
                          });
                        },
                        style: GoogleFonts.cairo(),
                        decoration: InputDecoration(
                          hintText:
                              'ابحث باسم الموظف أو البريد...',
                          hintStyle: GoogleFonts.cairo(
                            color: grey,
                            fontSize: 13,
                          ),
                          prefixIcon: const Icon(
                            Icons.search,
                            color: grey,
                          ),
                          border: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: buildFilterButton(
                            'all',
                            'الكل (${docs.length})',
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: buildFilterButton(
                            'pending',
                            'طلبات ($pendingCount)',
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: buildFilterButton(
                            'approved',
                            'معتمد ($approvedCount)',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              Expanded(
                child: filteredDocs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.people_outline,
                              size: 55,
                              color: grey,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'لا توجد حسابات',
                              style: GoogleFonts.cairo(
                                color: grey,
                                fontWeight:
                                    FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding:
                            const EdgeInsets.fromLTRB(
                          16,
                          0,
                          16,
                          20,
                        ),
                        itemCount: filteredDocs.length,
                        itemBuilder: (context, index) {
                          return buildUserCard(
                            filteredDocs[index],
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
}