import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'auction_details_page.dart';

class AuctionsPage extends StatelessWidget {
  const AuctionsPage({super.key});

  static const Color navy = Color(0xFF172B4D);
  static const Color lightGrey = Color(0xFFF3F5F8);
  static const Color border = Color(0xFFE1E5EA);
  static const Color textDark = Color(0xFF1F2937);
  static const Color textGrey = Color(0xFF6B7280);

  static const List<String> cities = [
    'أبها',
    'جدة',
    'الأفلاج',
    'الرياض',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightGrey,
      appBar: AppBar(
        backgroundColor: navy,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'المزادات',
          style: GoogleFonts.cairo(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: navy,
        foregroundColor: Colors.white,
        onPressed: () {
          _showAddAuctionDialog(context);
        },
        icon: const Icon(Icons.add_rounded),
        label: Text(
          'إضافة مزاد',
          style: GoogleFonts.cairo(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('auctions')
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
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'حدث خطأ أثناء تحميل المزادات\n\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cairo(
                    color: Colors.red,
                    fontSize: 14,
                  ),
                ),
              ),
            );
          }

          final documents = snapshot.data?.docs ?? [];

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              16,
              20,
              16,
              100,
            ),
            children: [
              _buildHeader(documents.length),
              const SizedBox(height: 20),
              ...cities.map(
                (city) => _buildCitySection(
                  context,
                  city,
                  documents,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(int totalAuctions) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: navy,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.gavel_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'إدارة المزادات',
                  style: GoogleFonts.cairo(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: navy,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$totalAuctions مزاد مسجل',
                  style: GoogleFonts.cairo(
                    fontSize: 13,
                    color: textGrey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCitySection(
    BuildContext context,
    String city,
    List<QueryDocumentSnapshot> documents,
  ) {
    final cityAuctions = documents.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return data['city'] == city;
    }).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 4,
        ),
        childrenPadding: const EdgeInsets.fromLTRB(
          12,
          0,
          12,
          12,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        collapsedShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: navy.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.location_on_outlined,
            color: navy,
          ),
        ),
        title: Text(
          'مزادات $city',
          style: GoogleFonts.cairo(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: navy,
          ),
        ),
        subtitle: Text(
          '${cityAuctions.length} مزاد',
          style: GoogleFonts.cairo(
            fontSize: 12,
            color: textGrey,
          ),
        ),
        children: cityAuctions.isEmpty
            ? [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'لا توجد مزادات في $city حاليًا',
                    style: GoogleFonts.cairo(
                      fontSize: 13,
                      color: textGrey,
                    ),
                  ),
                ),
              ]
            : cityAuctions.map((doc) {
                return _buildAuctionCard(
                  context,
                  doc,
                );
              }).toList(),
      ),
    );
  }

  Widget _buildAuctionCard(
    BuildContext context,
    QueryDocumentSnapshot doc,
  ) {
    final data = doc.data() as Map<String, dynamic>;

    final String name =
        (data['name'] ?? 'مزاد بدون اسم').toString();

    final String city =
        (data['city'] ?? '').toString();

    final String location =
        (data['location'] ?? 'لم يتم تحديد المكان').toString();

    final String date =
        (data['date'] ?? 'لم يتم تحديد التاريخ').toString();

    final int assetsCount =
        (data['assetsCount'] ?? 0) is int
            ? data['assetsCount'] as int
            : int.tryParse(
                  data['assetsCount'].toString(),
                ) ??
                0;

    final int interestedCount =
        (data['interestedCount'] ?? 0) is int
            ? data['interestedCount'] as int
            : int.tryParse(
                  data['interestedCount'].toString(),
                ) ??
                0;

    final int registeredCount =
        (data['registeredCount'] ?? 0) is int
            ? data['registeredCount'] as int
            : int.tryParse(
                  data['registeredCount'].toString(),
                ) ??
                0;

    final String status =
        (data['status'] ?? 'upcoming').toString();

    return InkWell(
      borderRadius: BorderRadius.circular(15),
      onTap: () {
        _openAuctionDetails(
          context,
          doc.id,
          data,
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 45,
                  height: 45,
                  decoration: BoxDecoration(
                    color: navy.withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.gavel_rounded,
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
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.cairo(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: textDark,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 15,
                            color: textGrey,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              location.isEmpty
                                  ? city
                                  : location,
                              maxLines: 1,
                              overflow:
                                  TextOverflow.ellipsis,
                              style: GoogleFonts.cairo(
                                fontSize: 12,
                                color: textGrey,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                _statusBadge(status),
              ],
            ),

            const SizedBox(height: 15),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _infoChip(
                  Icons.calendar_today_outlined,
                  date,
                ),
                _infoChip(
                  Icons.home_work_outlined,
                  '$assetsCount أصل',
                ),
                _infoChip(
                  Icons.people_outline_rounded,
                  '$interestedCount مهتم',
                ),
                _infoChip(
                  Icons.assignment_ind_outlined,
                  '$registeredCount مسجل',
                ),
              ],
            ),

            const SizedBox(height: 13),

            Container(
              height: 1,
              color: border,
            ),

            const SizedBox(height: 10),

            Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'عرض تفاصيل المزاد',
                  style: GoogleFonts.cairo(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: navy,
                  ),
                ),
                const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 15,
                  color: navy,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(
    IconData icon,
    String text,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: lightGrey,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: navy,
          ),
          const SizedBox(width: 5),
          Text(
            text,
            style: GoogleFonts.cairo(
              fontSize: 11,
              color: textDark,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    String text;
    Color color;

    switch (status) {
      case 'live':
        text = 'جاري';
        color = Colors.green;
        break;

      case 'ended':
        text = 'منتهي';
        color = Colors.grey;
        break;

      case 'cancelled':
        text = 'ملغي';
        color = Colors.red;
        break;

      default:
        text = 'قادم';
        color = Colors.blue;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: GoogleFonts.cairo(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Future<void> _showAddAuctionDialog(
    BuildContext context,
  ) async {
    final nameController = TextEditingController();
    final locationController = TextEditingController();
    final dateController = TextEditingController();

    String selectedCity = cities.first;
    String selectedStatus = 'upcoming';

    bool isSaving = false;

    await showDialog(
      context: context,
      barrierDismissible: !isSaving,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (
            context,
            setState,
          ) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: AlertDialog(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                title: Text(
                  'إضافة مزاد جديد',
                  style: GoogleFonts.cairo(
                    fontWeight: FontWeight.bold,
                    color: navy,
                  ),
                ),
                content: SingleChildScrollView(
                  child: SizedBox(
                    width: 450,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _dialogTextField(
                          controller: nameController,
                          label: 'اسم المزاد',
                          hint:
                              'مثال: مزاد عقارات شرق أبها',
                          icon: Icons.gavel_outlined,
                        ),

                        const SizedBox(height: 12),

                        DropdownButtonFormField<String>(
                          value: selectedCity,
                          decoration:
                              _inputDecoration(
                            'المدينة',
                            Icons.location_city_outlined,
                          ),
                          items: cities.map((city) {
                            return DropdownMenuItem(
                              value: city,
                              child: Text(
                                city,
                                style: GoogleFonts.cairo(
                                  fontSize: 13,
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: isSaving
                              ? null
                              : (value) {
                                  if (value != null) {
                                    setState(() {
                                      selectedCity =
                                          value;
                                    });
                                  }
                                },
                        ),

                        const SizedBox(height: 12),

                        _dialogTextField(
                          controller:
                              locationController,
                          label: 'مكان المزاد',
                          hint:
                              'مثال: فندق ... / منصة إلكترونية',
                          icon: Icons.place_outlined,
                        ),

                        const SizedBox(height: 12),

                        _dialogTextField(
                          controller: dateController,
                          label: 'تاريخ المزاد',
                          hint:
                              'مثال: 15 أكتوبر 2026',
                          icon:
                              Icons.calendar_today_outlined,
                        ),

                        const SizedBox(height: 12),

                        DropdownButtonFormField<String>(
                          value: selectedStatus,
                          decoration:
                              _inputDecoration(
                            'حالة المزاد',
                            Icons.flag_outlined,
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'upcoming',
                              child: Text('قادم'),
                            ),
                            DropdownMenuItem(
                              value: 'live',
                              child: Text('جاري'),
                            ),
                            DropdownMenuItem(
                              value: 'ended',
                              child: Text('منتهي'),
                            ),
                            DropdownMenuItem(
                              value: 'cancelled',
                              child: Text('ملغي'),
                            ),
                          ],
                          onChanged: isSaving
                              ? null
                              : (value) {
                                  if (value != null) {
                                    setState(() {
                                      selectedStatus =
                                          value;
                                    });
                                  }
                                },
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: isSaving
                        ? null
                        : () {
                            Navigator.pop(
                              dialogContext,
                            );
                          },
                    child: Text(
                      'إلغاء',
                      style: GoogleFonts.cairo(
                        color: textGrey,
                      ),
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: navy,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: isSaving
                        ? null
                        : () async {
                            final name =
                                nameController.text
                                    .trim();

                            if (name.isEmpty) {
                              _showMessage(
                                context,
                                'فضلاً اكتب اسم المزاد',
                                isError: true,
                              );
                              return;
                            }

                            setState(() {
                              isSaving = true;
                            });

                            try {
                              await FirebaseFirestore
                                  .instance
                                  .collection('auctions')
                                  .add({
                                'name': name,
                                'city': selectedCity,
                                'location':
                                    locationController
                                        .text
                                        .trim(),
                                'date':
                                    dateController.text
                                        .trim(),
                                'status':
                                    selectedStatus,
                                'assetsCount': 0,
                                'interestedCount': 0,
                                'registeredCount': 0,
                                'brochureUrl': '',
                                'brochureName': '',
                                'createdAt':
                                    FieldValue
                                        .serverTimestamp(),
                              });

                              if (dialogContext
                                  .mounted) {
                                Navigator.pop(
                                  dialogContext,
                                );
                              }

                              if (context.mounted) {
                                _showMessage(
                                  context,
                                  'تم إضافة المزاد بنجاح',
                                );
                              }
                            } catch (e) {
                              setState(() {
                                isSaving = false;
                              });

                              _showMessage(
                                context,
                                'تعذر إضافة المزاد: $e',
                                isError: true,
                              );
                            }
                          },
                    child: isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'حفظ المزاد',
                            style: GoogleFonts.cairo(
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    nameController.dispose();
    locationController.dispose();
    dateController.dispose();
  }

  Widget _dialogTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      style: GoogleFonts.cairo(
        fontSize: 13,
      ),
      decoration: _inputDecoration(
        label,
        icon,
      ).copyWith(
        hintText: hint,
        hintStyle: GoogleFonts.cairo(
          fontSize: 12,
          color: Colors.grey.shade400,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(
    String label,
    IconData icon,
  ) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.cairo(
        fontSize: 12,
      ),
      prefixIcon: Icon(
        icon,
        color: navy,
        size: 20,
      ),
      filled: true,
      fillColor: lightGrey,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: const BorderSide(
          color: border,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: const BorderSide(
          color: navy,
          width: 1.2,
        ),
      ),
    );
  }

  // فتح صفحة تفاصيل المزاد
  void _openAuctionDetails(
    BuildContext context,
    String auctionId,
    Map<String, dynamic> data,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AuctionDetailsPage(
          auctionId: auctionId,
          auctionData: data,
        ),
      ),
    );
  }

  void _showMessage(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.cairo(
            fontSize: 13,
          ),
        ),
        backgroundColor:
            isError ? Colors.red : navy,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}