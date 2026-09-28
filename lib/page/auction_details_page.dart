import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AuctionDetailsPage extends StatefulWidget {
  final String auctionId;
  final Map<String, dynamic> auctionData;

  const AuctionDetailsPage({
    super.key,
    required this.auctionId,
    required this.auctionData,
  });

  @override
  State<AuctionDetailsPage> createState() =>
      _AuctionDetailsPageState();
}

class _AuctionDetailsPageState
    extends State<AuctionDetailsPage> {
  static const Color navy = Color(0xFF172B4D);
  static const Color lightGrey = Color(0xFFF3F5F8);
  static const Color border = Color(0xFFE1E5EA);
  static const Color textDark = Color(0xFF1F2937);
  static const Color textGrey = Color(0xFF6B7280);

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final TextEditingController _nameController =
      TextEditingController();

  final TextEditingController _assetsCountController =
      TextEditingController();

  String _selectedCity = 'أبها';

  bool _savingAuction = false;
  bool _uploadingBrochure = false;

  @override
  void initState() {
    super.initState();

    _nameController.text =
        (widget.auctionData['name'] ?? '').toString();

    _assetsCountController.text =
        (widget.auctionData['assetsCount'] ?? 0).toString();

    final city =
        (widget.auctionData['city'] ?? '').toString();

    if ([
      'أبها',
      'جدة',
      'الأفلاج',
      'الرياض',
    ].contains(city)) {
      _selectedCity = city;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _assetsCountController.dispose();
    super.dispose();
  }

  DocumentReference<Map<String, dynamic>>
      get _auctionRef {
    return _firestore
        .collection('auctions')
        .doc(widget.auctionId);
  }

  CollectionReference<Map<String, dynamic>>
      get _assetsRef {
    return _auctionRef.collection('assets');
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: lightGrey,
        appBar: AppBar(
          backgroundColor: navy,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          title: Text(
            'تفاصيل المزاد',
            style: GoogleFonts.cairo(
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: StreamBuilder<DocumentSnapshot>(
          stream: _auctionRef.snapshots(),
          builder: (context, auctionSnapshot) {
            if (auctionSnapshot.connectionState ==
                ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            final auctionData =
                auctionSnapshot.data?.data()
                        as Map<String, dynamic>? ??
                    widget.auctionData;

            return StreamBuilder<QuerySnapshot>(
              stream: _assetsRef
                  .orderBy('assetNumber')
                  .snapshots(),
              builder: (context, assetsSnapshot) {
                if (assetsSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final assets =
                    assetsSnapshot.data?.docs ?? [];

                return _buildPage(
                  context,
                  auctionData,
                  assets,
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildPage(
    BuildContext context,
    Map<String, dynamic> auctionData,
    List<QueryDocumentSnapshot> assets,
  ) {
    final brochureUrl =
        (auctionData['brochureUrl'] ?? '').toString();

    final brochureName =
        (auctionData['brochureName'] ?? '').toString();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 1400,
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.stretch,
                children: [
                  _buildPageTitle(assets.length),
                  const SizedBox(height: 20),
                  _buildAuctionInformationCard(
                    auctionData,
                    brochureUrl,
                    brochureName,
                    isWide,
                  ),
                  const SizedBox(height: 24),
                  _buildAssetsHeader(assets.length),
                  const SizedBox(height: 12),
                  _buildAssetsTable(
                    context,
                    assets,
                    isWide,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPageTitle(int assetsLength) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                'بيانات المزاد',
                style: GoogleFonts.cairo(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: navy,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'إدارة معلومات المزاد والأصول التابعة له',
                style: GoogleFonts.cairo(
                  fontSize: 13,
                  color: textGrey,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 9,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: border),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.home_work_outlined,
                size: 18,
                color: navy,
              ),
              const SizedBox(width: 7),
              Text(
                '$assetsLength أصل مضاف',
                style: GoogleFonts.cairo(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: navy,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAuctionInformationCard(
    Map<String, dynamic> auctionData,
    String brochureUrl,
    String brochureName,
    bool isWide,
  ) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: navy.withOpacity(.08),
                  borderRadius:
                      BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.gavel_outlined,
                  color: navy,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'معلومات المزاد',
                style: GoogleFonts.cairo(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: navy,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          if (isWide)
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _nameController,
                    label: 'اسم المزاد',
                    hint: 'أدخل اسم المزاد',
                    icon: Icons.gavel_outlined,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _buildCityDropdown(),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _buildTextField(
                    controller:
                        _assetsCountController,
                    label: 'عدد الأصول',
                    hint: 'مثال: 20',
                    icon:
                        Icons.format_list_numbered,
                    keyboardType:
                        TextInputType.number,
                  ),
                ),
              ],
            )
          else
            Column(
              children: [
                _buildTextField(
                  controller: _nameController,
                  label: 'اسم المزاد',
                  hint: 'أدخل اسم المزاد',
                  icon: Icons.gavel_outlined,
                ),
                const SizedBox(height: 14),
                _buildCityDropdown(),
                const SizedBox(height: 14),
                _buildTextField(
                  controller:
                      _assetsCountController,
                  label: 'عدد الأصول',
                  hint: 'مثال: 20',
                  icon:
                      Icons.format_list_numbered,
                  keyboardType:
                      TextInputType.number,
                ),
              ],
            ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildBrochureBox(
                  brochureUrl,
                  brochureName,
                ),
              ),
              const SizedBox(width: 14),
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed:
                      _savingAuction ||
                              _uploadingBrochure
                          ? null
                          : _saveAuctionInformation,
                  style:
                      ElevatedButton.styleFrom(
                    backgroundColor: navy,
                    foregroundColor:
                        Colors.white,
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: 22,
                    ),
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(
                        10,
                      ),
                    ),
                  ),
                  icon: _savingAuction
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.save_outlined,
                          size: 19,
                        ),
                  label: Text(
                    'حفظ بيانات المزاد',
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBrochureBox(
    String brochureUrl,
    String brochureName,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: lightGrey,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(.08),
              borderRadius:
                  BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.picture_as_pdf_outlined,
              color: Colors.red,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  brochureName.isEmpty
                      ? 'لم يتم رفع البروشور'
                      : brochureName,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  brochureUrl.isEmpty
                      ? 'ملف PDF'
                      : 'تم رفع البروشور',
                  style: GoogleFonts.cairo(
                    fontSize: 10,
                    color: textGrey,
                  ),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: _uploadingBrochure
                ? null
                : _uploadBrochure,
            icon: _uploadingBrochure
                ? const SizedBox(
                    width: 15,
                    height: 15,
                    child:
                        CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(
                    Icons.upload_file_outlined,
                    size: 17,
                  ),
            label: Text(
              brochureUrl.isEmpty
                  ? 'رفع PDF'
                  : 'تغيير',
              style: GoogleFonts.cairo(
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssetsHeader(int count) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                'أصول المزاد',
                style: GoogleFonts.cairo(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: navy,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'أضيفي كل أصل بشكل مستقل وسيتم ترقيمه تلقائيًا',
                style: GoogleFonts.cairo(
                  fontSize: 12,
                  color: textGrey,
                ),
              ),
            ],
          ),
        ),
        ElevatedButton.icon(
          onPressed: () {
            _showAddAssetDialog();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: navy,
            foregroundColor: Colors.white,
            padding:
                const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 13,
            ),
            shape: RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(10),
            ),
          ),
          icon: const Icon(
            Icons.add_rounded,
            size: 20,
          ),
          label: Text(
            'إضافة أصل',
            style: GoogleFonts.cairo(
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAssetsTable(
    BuildContext context,
    List<QueryDocumentSnapshot> assets,
    bool isWide,
  ) {
    if (assets.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(
          vertical: 55,
          horizontal: 20,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border),
        ),
        child: Column(
          children: [
            Container(
              width: 65,
              height: 65,
              decoration: BoxDecoration(
                color: navy.withOpacity(.07),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.home_work_outlined,
                color: navy,
                size: 31,
              ),
            ),
            const SizedBox(height: 15),
            Text(
              'لا توجد أصول مضافة',
              style: GoogleFonts.cairo(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: textDark,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'اضغطي على "إضافة أصل" لإضافة أول أصل للمزاد',
              style: GoogleFonts.cairo(
                fontSize: 12,
                color: textGrey,
              ),
            ),
          ],
        ),
      );
    }

    if (!isWide) {
      return Column(
        children: assets.map((asset) {
          return _buildMobileAssetCard(
            context,
            asset,
          );
        }).toList(),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: 1050,
          ),
          child: DataTable(
            headingRowHeight: 55,
            dataRowMinHeight: 65,
            dataRowMaxHeight: 75,
            columnSpacing: 25,
            horizontalMargin: 20,
            headingRowColor:
                WidgetStateProperty.all(
              lightGrey,
            ),
            columns: [
              _tableColumn('#'),
              _tableColumn('اسم الأصل'),
              _tableColumn('رقم الصك'),
              _tableColumn('الحي'),
              _tableColumn('السعر النهائي'),
              _tableColumn('الحالة'),
              _tableColumn('سومتك'),
              _tableColumn('إجراءات'),
            ],
            rows: assets.map((asset) {
              final data =
                  asset.data()
                      as Map<String, dynamic>;

              return DataRow(
                cells: [
                  DataCell(
                    _numberBadge(
                      data['assetNumber'],
                    ),
                  ),
                  DataCell(
                    SizedBox(
                      width: 180,
                      child: Text(
                        (data['name'] ?? '')
                            .toString(),
                        maxLines: 2,
                        overflow:
                            TextOverflow.ellipsis,
                        style: GoogleFonts.cairo(
                          fontSize: 12,
                          fontWeight:
                              FontWeight.bold,
                          color: textDark,
                        ),
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      (data['deedNumber'] ?? '')
                          .toString(),
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        color: textDark,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      (data['district'] ?? '')
                          .toString(),
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        color: textDark,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      _formatPrice(
                        data['finalPrice'],
                      ),
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        fontWeight:
                            FontWeight.bold,
                        color: navy,
                      ),
                    ),
                  ),
                  DataCell(
                    _saleStatusBadge(
                      data['sold'] == true,
                    ),
                  ),
                  DataCell(
                    data['soomLink']
                                ?.toString()
                                .isNotEmpty ==
                            true
                        ? TextButton(
                            onPressed: () {
                              _showLink(
                                data['soomLink']
                                    .toString(),
                              );
                            },
                            child: Text(
                              'فتح الرابط',
                              style:
                                  GoogleFonts.cairo(
                                fontSize: 11,
                                fontWeight:
                                    FontWeight.bold,
                                color: navy,
                              ),
                            ),
                          )
                        : Text(
                            '—',
                            style:
                                GoogleFonts.cairo(
                              color: textGrey,
                            ),
                          ),
                  ),
                  DataCell(
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'تعديل',
                          onPressed: () {
                            _showEditAssetDialog(
                              asset,
                            );
                          },
                          icon: const Icon(
                            Icons.edit_outlined,
                            size: 19,
                            color: navy,
                          ),
                        ),
                        IconButton(
                          tooltip: 'حذف',
                          onPressed: () {
                            _confirmDeleteAsset(
                              asset,
                            );
                          },
                          icon: const Icon(
                            Icons.delete_outline,
                            size: 19,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileAssetCard(
    BuildContext context,
    QueryDocumentSnapshot asset,
  ) {
    final data =
        asset.data() as Map<String, dynamic>;

    final sold = data['sold'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _numberBadge(data['assetNumber']),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  (data['name'] ?? '')
                      .toString(),
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: textDark,
                  ),
                ),
              ),
              _saleStatusBadge(sold),
            ],
          ),
          const SizedBox(height: 15),
          _mobileInfoRow(
            'رقم الصك',
            data['deedNumber'],
          ),
          _mobileInfoRow(
            'الحي',
            data['district'],
          ),
          _mobileInfoRow(
            'السعر النهائي',
            _formatPrice(
              data['finalPrice'],
            ),
          ),
          if ((data['soomLink'] ?? '')
              .toString()
              .isNotEmpty)
            Align(
              alignment:
                  Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () {
                  _showLink(
                    data['soomLink'].toString(),
                  );
                },
                icon: const Icon(
                  Icons.open_in_new,
                  size: 16,
                ),
                label: Text(
                  'رابط الأصل في سومتك',
                  style: GoogleFonts.cairo(
                    fontSize: 11,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),
            ),
          const Divider(color: border),
          Row(
            mainAxisAlignment:
                MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () {
                  _showEditAssetDialog(
                    asset,
                  );
                },
                icon: const Icon(
                  Icons.edit_outlined,
                  size: 17,
                ),
                label: Text(
                  'تعديل',
                  style: GoogleFonts.cairo(
                    fontSize: 11,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  _confirmDeleteAsset(
                    asset,
                  );
                },
                icon: const Icon(
                  Icons.delete_outline,
                  size: 17,
                  color: Colors.red,
                ),
                label: Text(
                  'حذف',
                  style: GoogleFonts.cairo(
                    fontSize: 11,
                    color: Colors.red,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  DataColumn _tableColumn(String title) {
    return DataColumn(
      label: Text(
        title,
        style: GoogleFonts.cairo(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: navy,
        ),
      ),
    );
  }

  Widget _numberBadge(dynamic number) {
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: navy,
        borderRadius:
            BorderRadius.circular(9),
      ),
      child: Text(
        '${number ?? ''}',
        style: GoogleFonts.cairo(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _saleStatusBadge(bool sold) {
    final color =
        sold ? Colors.green : Colors.red;

    final text =
        sold ? 'بيع' : 'لم يتم البيع';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(.09),
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

  Widget _mobileInfoRow(
    String label,
    dynamic value,
  ) {
    return Padding(
      padding:
          const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: GoogleFonts.cairo(
                fontSize: 11,
                color: textGrey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              (value ?? '—').toString(),
              style: GoogleFonts.cairo(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: GoogleFonts.cairo(
        fontSize: 13,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(
          icon,
          color: navy,
          size: 20,
        ),
        labelStyle: GoogleFonts.cairo(
          fontSize: 12,
        ),
        hintStyle: GoogleFonts.cairo(
          fontSize: 11,
          color: Colors.grey.shade400,
        ),
        filled: true,
        fillColor: lightGrey,
        border: OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(10),
          borderSide:
              const BorderSide(
            color: navy,
            width: 1.2,
          ),
        ),
      ),
    );
  }

  Widget _buildCityDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedCity,
      decoration: InputDecoration(
        labelText: 'المدينة',
        prefixIcon: const Icon(
          Icons.location_city_outlined,
          color: navy,
          size: 20,
        ),
        labelStyle: GoogleFonts.cairo(
          fontSize: 12,
        ),
        filled: true,
        fillColor: lightGrey,
        border: OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(10),
          borderSide:
              const BorderSide(
            color: navy,
            width: 1.2,
          ),
        ),
      ),
      items: const [
        DropdownMenuItem(
          value: 'أبها',
          child: Text('أبها'),
        ),
        DropdownMenuItem(
          value: 'جدة',
          child: Text('جدة'),
        ),
        DropdownMenuItem(
          value: 'الأفلاج',
          child: Text('الأفلاج'),
        ),
        DropdownMenuItem(
          value: 'الرياض',
          child: Text('الرياض'),
        ),
      ],
      onChanged: (value) {
        if (value != null) {
          setState(() {
            _selectedCity = value;
          });
        }
      },
    );
  }

  Future<void> _saveAuctionInformation() async {
    final name =
        _nameController.text.trim();

    final assetsCount =
        int.tryParse(
              _assetsCountController.text
                  .trim(),
            ) ??
            0;

    if (name.isEmpty) {
      _showMessage(
        'فضلاً أدخل اسم المزاد',
        isError: true,
      );
      return;
    }

    if (assetsCount < 0) {
      _showMessage(
        'عدد الأصول غير صحيح',
        isError: true,
      );
      return;
    }

    setState(() {
      _savingAuction = true;
    });

    try {
      await _auctionRef.update({
        'name': name,
        'city': _selectedCity,
        'assetsCount': assetsCount,
      });

      _showMessage(
        'تم حفظ بيانات المزاد',
      );
    } catch (e) {
      _showMessage(
        'تعذر حفظ البيانات',
        isError: true,
      );
    }

    if (mounted) {
      setState(() {
        _savingAuction = false;
      });
    }
  }

  Future<void> _uploadBrochure() async {
  try {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result == null || result.isEmpty) {
      return;
    }

    final file = result.first;

    if (file.path == null || file.path!.isEmpty) {
      _showMessage(
        'تعذر الوصول إلى ملف PDF',
        isError: true,
      );
      return;
    }

    setState(() {
      _uploadingBrochure = true;
    });

    final storageRef = FirebaseStorage.instance
        .ref()
        .child(
          'auctions/${widget.auctionId}/brochure/${file.name}',
        );

    await storageRef.putFile(
      File(file.path!),
      SettableMetadata(
        contentType: 'application/pdf',
      ),
    );

    final url = await storageRef.getDownloadURL();

    await _auctionRef.update({
      'brochureUrl': url,
      'brochureName': file.name,
    });

    _showMessage(
      'تم رفع البروشور بنجاح',
    );
  } catch (e) {
    _showMessage(
      'تعذر رفع البروشور: $e',
      isError: true,
    );
  }

  if (mounted) {
    setState(() {
      _uploadingBrochure = false;
    });
  }
}

  Future<void> _showAddAssetDialog() async {
    final nameController =
        TextEditingController();

    final deedController =
        TextEditingController();

    final districtController =
        TextEditingController();

    final priceController =
        TextEditingController();

    final soomController =
        TextEditingController();

    bool sold = true;
    bool saving = false;

    final nextNumber =
        await _getNextAssetNumber();

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (
            context,
            setDialogState,
          ) {
            return Directionality(
              textDirection:
                  TextDirection.rtl,
              child: AlertDialog(
                backgroundColor:
                    Colors.white,
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    18,
                  ),
                ),
                title: Row(
                  children: [
                    _numberBadge(nextNumber),
                    const SizedBox(width: 12),
                    Text(
                      'إضافة أصل رقم $nextNumber',
                      style:
                          GoogleFonts.cairo(
                        fontSize: 17,
                        fontWeight:
                            FontWeight.bold,
                        color: navy,
                      ),
                    ),
                  ],
                ),
                content:
                    SingleChildScrollView(
                  child: SizedBox(
                    width: 520,
                    child: Column(
                      children: [
                        _dialogField(
                          nameController,
                          'اسم الأصل',
                          'مثال: أرض سكنية',
                          Icons.home_work_outlined,
                        ),
                        const SizedBox(height: 12),
                        _dialogField(
                          deedController,
                          'رقم الصك',
                          'أدخل رقم الصك',
                          Icons.description_outlined,
                        ),
                        const SizedBox(height: 12),
                        _dialogField(
                          districtController,
                          'الحي',
                          'أدخل اسم الحي',
                          Icons.location_on_outlined,
                        ),
                        const SizedBox(height: 12),
                        _dialogField(
                          priceController,
                          'السعر النهائي',
                          'مثال: 850000',
                          Icons.payments_outlined,
                          keyboardType:
                              TextInputType.number,
                        ),
                        const SizedBox(height: 12),
                        _dialogField(
                          soomController,
                          'رابط الأصل في سومتك',
                          'الصق رابط الأصل هنا',
                          Icons.link_outlined,
                          keyboardType:
                              TextInputType.url,
                        ),
                        const SizedBox(height: 18),
                        Align(
                          alignment:
                              Alignment.centerRight,
                          child: Text(
                            'حالة الأصل',
                            style:
                                GoogleFonts.cairo(
                              fontSize: 12,
                              fontWeight:
                                  FontWeight.bold,
                              color: textDark,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child:
                                  _statusChoice(
                                title: 'بيع',
                                selected:
                                    sold,
                                color:
                                    Colors.green,
                                onTap: () {
                                  setDialogState(
                                    () {
                                      sold = true;
                                    },
                                  );
                                },
                              ),
                            ),
                            const SizedBox(
                              width: 10,
                            ),
                            Expanded(
                              child:
                                  _statusChoice(
                                title:
                                    'لم يتم البيع',
                                selected:
                                    !sold,
                                color:
                                    Colors.red,
                                onTap: () {
                                  setDialogState(
                                    () {
                                      sold = false;
                                    },
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: saving
                        ? null
                        : () {
                            Navigator.pop(
                              dialogContext,
                            );
                          },
                    child: Text(
                      'إلغاء',
                      style:
                          GoogleFonts.cairo(
                        color: textGrey,
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: saving
                        ? null
                        : () async {
                            if (nameController
                                .text
                                .trim()
                                .isEmpty) {
                              _showMessage(
                                'فضلاً أدخل اسم الأصل',
                                isError:
                                    true,
                              );
                              return;
                            }

                            setDialogState(
                              () {
                                saving = true;
                              },
                            );

                            try {
                              await _assetsRef
                                  .add({
                                'assetNumber':
                                    nextNumber,
                                'name':
                                    nameController
                                        .text
                                        .trim(),
                                'deedNumber':
                                    deedController
                                        .text
                                        .trim(),
                                'district':
                                    districtController
                                        .text
                                        .trim(),
                                'finalPrice':
                                    priceController
                                        .text
                                        .trim(),
                                'sold': sold,
                                'soomLink':
                                    soomController
                                        .text
                                        .trim(),
                                'createdAt':
                                    FieldValue
                                        .serverTimestamp(),
                              });

                              await _auctionRef
                                  .update({
                                'assetsCount':
                                    FieldValue
                                        .increment(
                                  1,
                                ),
                              });

                              if (dialogContext
                                  .mounted) {
                                Navigator.pop(
                                  dialogContext,
                                );
                              }

                              _showMessage(
                                'تمت إضافة الأصل رقم $nextNumber',
                              );
                            } catch (e) {
                              setDialogState(
                                () {
                                  saving = false;
                                },
                              );

                              _showMessage(
                                'تعذر إضافة الأصل',
                                isError:
                                    true,
                              );
                            }
                          },
                    style:
                        ElevatedButton.styleFrom(
                      backgroundColor: navy,
                      foregroundColor:
                          Colors.white,
                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(
                          9,
                        ),
                      ),
                    ),
                    child: saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                              color:
                                  Colors.white,
                            ),
                          )
                        : Text(
                            'حفظ الأصل',
                            style:
                                GoogleFonts.cairo(
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
    deedController.dispose();
    districtController.dispose();
    priceController.dispose();
    soomController.dispose();
  }

  Future<int> _getNextAssetNumber() async {
    final snapshot = await _assetsRef
        .orderBy(
          'assetNumber',
          descending: true,
        )
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      return 1;
    }

    final data =
        snapshot.docs.first.data();

    final current =
        int.tryParse(
              data['assetNumber']
                  .toString(),
            ) ??
            0;

    return current + 1;
  }

  Future<void> _showEditAssetDialog(
    QueryDocumentSnapshot asset,
  ) async {
    final data =
        asset.data() as Map<String, dynamic>;

    final nameController =
        TextEditingController(
      text: (data['name'] ?? '').toString(),
    );

    final deedController =
        TextEditingController(
      text:
          (data['deedNumber'] ?? '').toString(),
    );

    final districtController =
        TextEditingController(
      text:
          (data['district'] ?? '').toString(),
    );

    final priceController =
        TextEditingController(
      text:
          (data['finalPrice'] ?? '').toString(),
    );

    final soomController =
        TextEditingController(
      text:
          (data['soomLink'] ?? '').toString(),
    );

    bool sold = data['sold'] == true;
    bool saving = false;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (
            context,
            setDialogState,
          ) {
            return Directionality(
              textDirection:
                  TextDirection.rtl,
              child: AlertDialog(
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    18,
                  ),
                ),
                title: Text(
                  'تعديل الأصل رقم ${data['assetNumber']}',
                  style: GoogleFonts.cairo(
                    fontSize: 17,
                    fontWeight:
                        FontWeight.bold,
                    color: navy,
                  ),
                ),
                content:
                    SingleChildScrollView(
                  child: SizedBox(
                    width: 520,
                    child: Column(
                      children: [
                        _dialogField(
                          nameController,
                          'اسم الأصل',
                          'اسم الأصل',
                          Icons.home_work_outlined,
                        ),
                        const SizedBox(height: 12),
                        _dialogField(
                          deedController,
                          'رقم الصك',
                          'رقم الصك',
                          Icons.description_outlined,
                        ),
                        const SizedBox(height: 12),
                        _dialogField(
                          districtController,
                          'الحي',
                          'الحي',
                          Icons.location_on_outlined,
                        ),
                        const SizedBox(height: 12),
                        _dialogField(
                          priceController,
                          'السعر النهائي',
                          'السعر النهائي',
                          Icons.payments_outlined,
                          keyboardType:
                              TextInputType.number,
                        ),
                        const SizedBox(height: 12),
                        _dialogField(
                          soomController,
                          'رابط الأصل في سومتك',
                          'رابط الأصل',
                          Icons.link_outlined,
                          keyboardType:
                              TextInputType.url,
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child:
                                  _statusChoice(
                                title: 'بيع',
                                selected:
                                    sold,
                                color:
                                    Colors.green,
                                onTap: () {
                                  setDialogState(
                                    () {
                                      sold = true;
                                    },
                                  );
                                },
                              ),
                            ),
                            const SizedBox(
                              width: 10,
                            ),
                            Expanded(
                              child:
                                  _statusChoice(
                                title:
                                    'لم يتم البيع',
                                selected:
                                    !sold,
                                color:
                                    Colors.red,
                                onTap: () {
                                  setDialogState(
                                    () {
                                      sold = false;
                                    },
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: saving
                        ? null
                        : () {
                            Navigator.pop(
                              dialogContext,
                            );
                          },
                    child: Text(
                      'إلغاء',
                      style:
                          GoogleFonts.cairo(
                        color: textGrey,
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: saving
                        ? null
                        : () async {
                            setDialogState(
                              () {
                                saving = true;
                              },
                            );

                            try {
                              await asset.reference
                                  .update({
                                'name':
                                    nameController
                                        .text
                                        .trim(),
                                'deedNumber':
                                    deedController
                                        .text
                                        .trim(),
                                'district':
                                    districtController
                                        .text
                                        .trim(),
                                'finalPrice':
                                    priceController
                                        .text
                                        .trim(),
                                'sold': sold,
                                'soomLink':
                                    soomController
                                        .text
                                        .trim(),
                              });

                              if (dialogContext
                                  .mounted) {
                                Navigator.pop(
                                  dialogContext,
                                );
                              }

                              _showMessage(
                                'تم تعديل الأصل بنجاح',
                              );
                            } catch (e) {
                              setDialogState(
                                () {
                                  saving = false;
                                },
                              );

                              _showMessage(
                                'تعذر تعديل الأصل',
                                isError:
                                    true,
                              );
                            }
                          },
                    style:
                        ElevatedButton.styleFrom(
                      backgroundColor: navy,
                      foregroundColor:
                          Colors.white,
                    ),
                    child: saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                              color:
                                  Colors.white,
                            ),
                          )
                        : Text(
                            'حفظ التعديل',
                            style:
                                GoogleFonts.cairo(
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
    deedController.dispose();
    districtController.dispose();
    priceController.dispose();
    soomController.dispose();
  }

  Widget _dialogField(
    TextEditingController controller,
    String label,
    String hint,
    IconData icon, {
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: GoogleFonts.cairo(
        fontSize: 13,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(
          icon,
          color: navy,
          size: 20,
        ),
        labelStyle: GoogleFonts.cairo(
          fontSize: 12,
        ),
        hintStyle: GoogleFonts.cairo(
          fontSize: 11,
          color: Colors.grey.shade400,
        ),
        filled: true,
        fillColor: lightGrey,
        border: OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(10),
          borderSide:
              const BorderSide(
            color: navy,
            width: 1.2,
          ),
        ),
      ),
    );
  }

  Widget _statusChoice({
    required String title,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius:
          BorderRadius.circular(10),
      onTap: onTap,
      child: AnimatedContainer(
        duration:
            const Duration(milliseconds: 180),
        padding:
            const EdgeInsets.symmetric(
          vertical: 13,
        ),
        decoration: BoxDecoration(
          color: selected
              ? color.withOpacity(.09)
              : lightGrey,
          borderRadius:
              BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? color
                : border,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
              color: selected
                  ? color
                  : textGrey,
              size: 18,
            ),
            const SizedBox(width: 7),
            Text(
              title,
              style: GoogleFonts.cairo(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: selected
                    ? color
                    : textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatPrice(dynamic value) {
    if (value == null ||
        value.toString().isEmpty) {
      return '—';
    }

    final raw = value.toString();

    final number = double.tryParse(
      raw.replaceAll(',', ''),
    );

    if (number == null) {
      return raw;
    }

    if (number % 1 == 0) {
      return '${number.toInt()} ريال';
    }

    return '$number ريال';
  }

  void _showLink(String link) {
    showDialog(
      context: context,
      builder: (context) {
        return Directionality(
          textDirection:
              TextDirection.rtl,
          child: AlertDialog(
            title: Text(
              'رابط الأصل في سومتك',
              style: GoogleFonts.cairo(
                fontWeight:
                    FontWeight.bold,
                color: navy,
              ),
            ),
            content: SelectableText(
              link,
              style: GoogleFonts.cairo(
                fontSize: 12,
                color: textDark,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Text(
                  'إغلاق',
                  style: GoogleFonts.cairo(
                    color: navy,
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
  }

  Future<void> _confirmDeleteAsset(
    QueryDocumentSnapshot asset,
  ) async {
    final data =
        asset.data() as Map<String, dynamic>;

    final number = data['assetNumber'];

    final confirmed =
        await showDialog<bool>(
      context: context,
      builder: (context) {
        return Directionality(
          textDirection:
              TextDirection.rtl,
          child: AlertDialog(
            title: Text(
              'حذف الأصل',
              style: GoogleFonts.cairo(
                fontWeight:
                    FontWeight.bold,
                color: Colors.red,
              ),
            ),
            content: Text(
              'هل أنتِ متأكدة من حذف الأصل رقم $number؟',
              style: GoogleFonts.cairo(
                fontSize: 13,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(
                    context,
                    false,
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
                style:
                    ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor:
                      Colors.white,
                ),
                onPressed: () {
                  Navigator.pop(
                    context,
                    true,
                  );
                },
                child: Text(
                  'حذف',
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

    if (confirmed != true) {
      return;
    }

    try {
      await asset.reference.delete();

      _showMessage(
        'تم حذف الأصل',
      );
    } catch (e) {
      _showMessage(
        'تعذر حذف الأصل',
        isError: true,
      );
    }
  }

  void _showMessage(
    String message, {
    bool isError = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.cairo(
            fontSize: 12,
          ),
        ),
        backgroundColor:
            isError ? Colors.red : navy,
        behavior:
            SnackBarBehavior.floating,
      ),
    );
  }
}