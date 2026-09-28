import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../data/seed_real_estates.dart';

class RealEstatesPage extends StatefulWidget {
  final String userRole;

  const RealEstatesPage({
    super.key,
    required this.userRole,
  });

  @override
  State<RealEstatesPage> createState() => _RealEstatesPageState();
}

class _RealEstatesPageState extends State<RealEstatesPage> {
  static const Color navy = Color(0xFF172B4D);
  static const Color navy2 = Color(0xFF243B5A);
  static const Color grey = Color(0xFF6B7280);
  static const Color lightGrey = Color(0xFFF3F5F8);
  static const Color border = Color(0xFFE1E5EA);

  final TextEditingController searchController = TextEditingController();
  final TextEditingController minPriceController = TextEditingController();
  final TextEditingController maxPriceController = TextEditingController();

  final ScrollController scrollController = ScrollController();

  final ImagePicker _imagePicker = ImagePicker();

  String searchQuery = '';
  String selectedPropertyType = 'الكل';
  String selectedCity = 'الكل';
  String selectedDistrict = 'الكل';

  double? minPrice;
  double? maxPrice;

  bool get isAdmin => widget.userRole == 'admin';

  // المدير والمسوق يستطيعان تغيير حالة العقار
  bool get canManagePropertyStatus =>
      widget.userRole == 'admin' ||
      widget.userRole == 'marketing';

  final List<String> propertyTypes = [
    'الكل',
    'أرض',
    'فيلا',
    'شقة',
    'عمارة',
    'استراحة',
    'مكتب',
    'محل',
    'مزرعة',
    'مستودع',
    'بيت',
    'عمارة سكنية',
    'أخرى',
  ];

  final List<String> cities = [
    'الكل',
    'أبها',
    'خميس مشيط',
    'الرياض',
  ];

  final Map<String, List<String>> districts = {
    'أبها': [
  'الكل',
  'المحالة',
  'المروج',
  'المنهل',
  'البديع',
  'المنسك',
  'الضباب',
  'الموظفين',
  'شمسان',
  'السد',
  'الروابي',
  'الروضة',
  'العرين',
  'النميص',
  'درة المنسك',
],
    'خميس مشيط': [
      'الكل',
      'الراقي',
      'الموسى',
      'الواحة',
      'الخالدية',
      'الضيافة',
    ],
    'الرياض': [
      'الكل',
      'الياسمين',
      'النرجس',
      'الملقا',
      'العقيق',
      'حطين',
      'الصحافة',
    ],
  };

  @override
  void initState() {
    super.initState();

    searchController.addListener(() {
      if (!mounted) return;

      setState(() {
        searchQuery = searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    minPriceController.dispose();
    maxPriceController.dispose();
    scrollController.dispose();
    super.dispose();
  }

  void showAddPropertyTypeDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'إضافة عقار',
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: navy,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _operationChoice(
                icon: Icons.sell_outlined,
                title: 'عقار للبيع',
                subtitle: 'إضافة العقار إلى قسم البيع',
                iconColor: Colors.green,
                onTap: () {
                  Navigator.pop(dialogContext);
                  showAddRealEstateBottomSheet('sale');
                },
              ),
              const SizedBox(height: 12),
              _operationChoice(
                icon: Icons.home_work_outlined,
                title: 'عقار للإيجار',
                subtitle: 'إضافة العقار إلى قسم الإيجار',
                iconColor: Colors.blue,
                onTap: () {
                  Navigator.pop(dialogContext);
                  showAddRealEstateBottomSheet('rent');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _operationChoice({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: lightGrey,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 25,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    title,
                    textAlign: TextAlign.right,
                    style: GoogleFonts.cairo(
                      fontWeight: FontWeight.bold,
                      color: navy,
                    ),
                  ),
                  Text(
                    subtitle,
                    textAlign: TextAlign.right,
                    style: GoogleFonts.cairo(
                      fontSize: 11,
                      color: grey,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_back_ios_new,
              size: 16,
              color: grey,
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> isShortIdAvailable(
    String shortId, {
    String? excludeDocumentId,
  }) async {
    final query = await FirebaseFirestore.instance
        .collection('real_estates')
        .where('shortId', isEqualTo: shortId)
        .limit(10)
        .get();

    for (final doc in query.docs) {
      if (excludeDocumentId == null || doc.id != excludeDocumentId) {
        return false;
      }
    }

    return true;
  }

  Future<List<XFile>> _pickImages() async {
    try {
      final images = await _imagePicker.pickMultiImage(
        imageQuality: 85,
        maxWidth: 1800,
        maxHeight: 1800,
      );

      return images;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تعذر اختيار الصور',
              style: GoogleFonts.cairo(),
            ),
          ),
        );
      }

      return [];
    }
  }

  Future<String> _uploadPropertyImage({
    required String propertyId,
    required XFile image,
    required int index,
  }) async {
    final file = File(image.path);

    final extension = image.name.contains('.')
        ? image.name.split('.').last.toLowerCase()
        : 'jpg';

    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}_$index.$extension';

    final reference = FirebaseStorage.instance
        .ref()
        .child('real_estates')
        .child(propertyId)
        .child(fileName);

    await reference.putFile(file);

    return await reference.getDownloadURL();
  }

  Future<void> _deleteImageFromStorage(String imageUrl) async {
    if (imageUrl.trim().isEmpty) return;

    try {
      final reference =
          FirebaseStorage.instance.refFromURL(imageUrl);

      await reference.delete();
    } catch (_) {
      // إذا كانت الصورة محذوفة مسبقًا أو الرابط غير صالح
    }
  }

  Widget _buildImagePickerSection({
    required List<XFile> selectedImages,
    required VoidCallback onAddImages,
    required void Function(int index) onRemoveImage,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: lightGrey,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'صور العقار',
                  textAlign: TextAlign.right,
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: navy,
                  ),
                ),
              ),
              const Icon(
                Icons.photo_library_outlined,
                color: navy,
                size: 22,
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            'يمكنك إضافة أكثر من صورة للعقار',
            textAlign: TextAlign.right,
            style: GoogleFonts.cairo(
              fontSize: 11,
              color: grey,
            ),
          ),
          const SizedBox(height: 12),
          if (selectedImages.isNotEmpty)
            SizedBox(
              height: 105,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                reverse: true,
                itemCount: selectedImages.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.file(
                          File(selectedImages[index].path),
                          width: 105,
                          height: 105,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: -7,
                        right: -7,
                        child: InkWell(
                          onTap: () => onRemoveImage(index),
                          child: Container(
                            width: 27,
                            height: 27,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 17,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          if (selectedImages.isNotEmpty)
            const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: onAddImages,
              icon: const Icon(
                Icons.add_photo_alternate_outlined,
                size: 20,
              ),
              label: Text(
                selectedImages.isEmpty
                    ? 'إضافة صور'
                    : 'إضافة صور أخرى',
                style: GoogleFonts.cairo(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: navy,
                side: const BorderSide(color: navy),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
            ),
          ),
          if (selectedImages.isNotEmpty) ...[
            const SizedBox(height: 7),
            Text(
              'تم اختيار ${selectedImages.length} صورة',
              style: GoogleFonts.cairo(
                fontSize: 10,
                color: grey,
              ),
            ),
          ],
        ],
      ),
    );
  }

  void showAddRealEstateBottomSheet(String operationType) {
    final formKey = GlobalKey<FormState>();

    final shortIdController = TextEditingController();
    final titleController = TextEditingController();
    final priceController = TextEditingController();
    final phoneController = TextEditingController();
    final descriptionController = TextEditingController();

    String propertyType = 'فيلا';
    String city = 'أبها';
    String district = 'الكل';

    bool isSaving = false;

    List<XFile> selectedImages = [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final availableDistricts =
                districts[city] ?? ['الكل'];

            if (!availableDistricts.contains(district)) {
              district = 'الكل';
            }

            return Container(
              height: MediaQuery.of(context).size.height * 0.92,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              child: SafeArea(
                child: Form(
                  key: formKey,
                  child: Column(
                    children: [
                      const SizedBox(height: 10),
                      Container(
                        width: 45,
                        height: 5,
                        decoration: BoxDecoration(
                          color: border,
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          20,
                          15,
                          20,
                          10,
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: isSaving
                                  ? null
                                  : () => Navigator.pop(sheetContext),
                              icon: const Icon(Icons.close),
                            ),
                            Expanded(
                              child: Text(
                                operationType == 'sale'
                                    ? 'إضافة عقار للبيع'
                                    : 'إضافة عقار للإيجار',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.cairo(
                                  fontSize: 19,
                                  fontWeight: FontWeight.bold,
                                  color: navy,
                                ),
                              ),
                            ),
                            const SizedBox(width: 48),
                          ],
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(
                            20,
                            5,
                            20,
                            30,
                          ),
                          child: Column(
                            children: [
                              _buildTextField(
                                controller: shortIdController,
                                label: 'رقم العقار',
                                hint: 'مثال: 1025',
                                icon: Icons.tag,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(4),
                                ],
                                validator: (value) {
                                  if (value == null ||
                                      value.trim().isEmpty) {
                                    return 'أدخلي رقم العقار';
                                  }

                                  if (value.trim().length != 4) {
                                    return 'رقم العقار يجب أن يكون 4 أرقام';
                                  }

                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),
                              _buildTextField(
                                controller: titleController,
                                label: 'عنوان العقار',
                                hint: 'مثال: فيلا في حي المروج',
                                icon: Icons.home_outlined,
                                validator: (value) {
                                  if (value == null ||
                                      value.trim().isEmpty) {
                                    return 'أدخلي عنوان العقار';
                                  }

                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),
                              _buildDropdown(
                                label: 'نوع العقار',
                                value: propertyType,
                                items: propertyTypes
                                    .where((e) => e != 'الكل')
                                    .toList(),
                                icon: Icons.apartment_outlined,
                                onChanged: (value) {
                                  if (value != null) {
                                    setSheetState(() {
                                      propertyType = value;
                                    });
                                  }
                                },
                              ),
                              const SizedBox(height: 14),
                              _buildDropdown(
                                label: 'المدينة',
                                value: city,
                                items: cities
                                    .where((e) => e != 'الكل')
                                    .toList(),
                                icon: Icons.location_city_outlined,
                                onChanged: (value) {
                                  if (value != null) {
                                    setSheetState(() {
                                      city = value;
                                      district = 'الكل';
                                    });
                                  }
                                },
                              ),
                              const SizedBox(height: 14),
                              _buildDropdown(
                                label: 'الحي',
                                value: district,
                                items: availableDistricts,
                                icon: Icons.location_on_outlined,
                                onChanged: (value) {
                                  if (value != null) {
                                    setSheetState(() {
                                      district = value;
                                    });
                                  }
                                },
                              ),
                              const SizedBox(height: 14),
                              _buildTextField(
                                controller: priceController,
                                label: 'السعر',
                                hint: 'مثال: 850000',
                                icon: Icons.payments_outlined,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                validator: (value) {
                                  if (value == null ||
                                      value.trim().isEmpty) {
                                    return 'أدخلي السعر';
                                  }

                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),
                              _buildTextField(
                                controller: phoneController,
                                label: 'رقم المالك',
                                hint: '05xxxxxxxx',
                                icon: Icons.phone_outlined,
                                keyboardType: TextInputType.phone,
                              ),
                              const SizedBox(height: 14),
                              _buildTextField(
                                controller: descriptionController,
                                label: 'وصف العقار',
                                hint: 'اكتبي تفاصيل العقار...',
                                icon: Icons.description_outlined,
                                maxLines: 5,
                              ),
                              const SizedBox(height: 16),
                              _buildImagePickerSection(
                                selectedImages: selectedImages,
                                onAddImages: () async {
                                  final images =
                                      await _pickImages();

                                  if (images.isEmpty) return;

                                  setSheetState(() {
                                    selectedImages.addAll(images);
                                  });
                                },
                                onRemoveImage: (index) {
                                  setSheetState(() {
                                    selectedImages.removeAt(index);
                                  });
                                },
                              ),
                              const SizedBox(height: 25),
                              SizedBox(
                                width: double.infinity,
                                height: 54,
                                child: ElevatedButton(
                                  onPressed: isSaving
                                      ? null
                                      : () async {
                                          if (!formKey
                                              .currentState!
                                              .validate()) {
                                            return;
                                          }

                                          setSheetState(() {
                                            isSaving = true;
                                          });

                                          try {
                                            final shortId =
                                                shortIdController.text
                                                    .trim();

                                            final available =
                                                await isShortIdAvailable(
                                              shortId,
                                            );

                                            if (!available) {
                                              setSheetState(() {
                                                isSaving = false;
                                              });

                                              if (context.mounted) {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      'رقم العقار $shortId مستخدم مسبقًا',
                                                      style:
                                                          GoogleFonts.cairo(),
                                                    ),
                                                  ),
                                                );
                                              }

                                              return;
                                            }

                                            final price =
                                                double.tryParse(
                                                      priceController.text
                                                          .trim(),
                                                    ) ??
                                                    0;

                                            final propertyRef =
                                                await FirebaseFirestore
                                                    .instance
                                                    .collection(
                                                      'real_estates',
                                                    )
                                                    .add({
                                              'shortId': shortId,
                                              'type': operationType,
                                              'status': 'active',
                                              'propertyType':
                                                  propertyType,
                                              'city': city,
                                              'district': district,
                                              'title':
                                                  titleController.text.trim(),
                                              'price': price,
                                              'ownerPhone':
                                                  phoneController.text.trim(),
                                              'description':
                                                  descriptionController.text
                                                      .trim(),
                                              'images': [],
                                              'createdAt':
                                                  FieldValue.serverTimestamp(),
                                            });

                                            final imageUrls = <String>[];

                                            for (int i = 0;
                                                i < selectedImages.length;
                                                i++) {
                                              final url =
                                                  await _uploadPropertyImage(
                                                propertyId: propertyRef.id,
                                                image: selectedImages[i],
                                                index: i,
                                              );

                                              imageUrls.add(url);
                                            }

                                            if (imageUrls.isNotEmpty) {
                                              await propertyRef.update({
                                                'images': imageUrls,
                                              });
                                            }

                                            if (sheetContext.mounted) {
                                              Navigator.pop(sheetContext);
                                            }

                                            if (mounted) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    operationType == 'sale'
                                                        ? 'تمت إضافة العقار إلى قسم البيع'
                                                        : 'تمت إضافة العقار إلى قسم الإيجار',
                                                    style:
                                                        GoogleFonts.cairo(),
                                                  ),
                                                ),
                                              );
                                            }
                                          } catch (e) {
                                            setSheetState(() {
                                              isSaving = false;
                                            });

                                            if (context.mounted) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'حدث خطأ أثناء إضافة العقار',
                                                    style:
                                                        GoogleFonts.cairo(),
                                                  ),
                                                ),
                                              );
                                            }
                                          }
                                        },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: navy,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(15),
                                    ),
                                  ),
                                  child: isSaving
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child:
                                              CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Text(
                                          'إضافة العقار',
                                          style: GoogleFonts.cairo(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                ),
                              ),
                            ],
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
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      maxLines: maxLines,
      textDirection: TextDirection.rtl,
      style: GoogleFonts.cairo(
        fontSize: 14,
        color: navy,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(
          icon,
          color: navy,
        ),
        labelStyle: GoogleFonts.cairo(
          color: grey,
        ),
        hintStyle: GoogleFonts.cairo(
          color: Colors.grey.shade400,
          fontSize: 12,
        ),
        filled: true,
        fillColor: lightGrey,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: border,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: border,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: navy,
            width: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required IconData icon,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: items.contains(value) ? value : items.first,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(
          icon,
          color: navy,
        ),
        filled: true,
        fillColor: lightGrey,
        labelStyle: GoogleFonts.cairo(
          color: grey,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: border,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: border,
          ),
        ),
      ),
      items: items.map((item) {
        return DropdownMenuItem<String>(
          value: item,
          child: Text(
            item,
            style: GoogleFonts.cairo(
              color: navy,
              fontSize: 13,
            ),
          ),
        );
      }).toList(),
    );
  }
    void showEditRealEstateBottomSheet(DocumentSnapshot doc) {
    if (!isAdmin) {
      return;
    }

    final data = doc.data() as Map<String, dynamic>? ?? {};

    final formKey = GlobalKey<FormState>();

    final shortIdController = TextEditingController(
      text: data['shortId']?.toString() ?? '',
    );

    final titleController = TextEditingController(
      text: data['title']?.toString() ?? '',
    );

    final priceController = TextEditingController(
      text: _formatPriceForInput(data['price']),
    );

    final phoneController = TextEditingController(
      text: data['ownerPhone']?.toString() ?? '',
    );

    final descriptionController = TextEditingController(
      text: data['description']?.toString() ?? '',
    );

    String operationType =
        data['type']?.toString() == 'rent' ? 'rent' : 'sale';

    String propertyType =
        data['propertyType']?.toString() ?? 'فيلا';

    String city =
        data['city']?.toString() ?? 'أبها';

    String district =
        data['district']?.toString() ?? 'الكل';

    if (!propertyTypes.contains(propertyType) ||
        propertyType == 'الكل') {
      propertyType = 'فيلا';
    }

    if (!cities.contains(city) || city == 'الكل') {
      city = 'أبها';
    }

    final availableDistricts =
        districts[city] ?? ['الكل'];

    if (!availableDistricts.contains(district)) {
      district = 'الكل';
    }

    List<String> existingImages = [];

    final imagesData = data['images'];

    if (imagesData is List) {
      existingImages = imagesData
          .map((e) => e.toString())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    List<XFile> newImages = [];

    bool isUpdating = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final currentDistricts =
                districts[city] ?? ['الكل'];

            return Container(
              height: MediaQuery.of(context).size.height * 0.92,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              child: SafeArea(
                child: Form(
                  key: formKey,
                  child: Column(
                    children: [
                      const SizedBox(height: 10),
                      Container(
                        width: 45,
                        height: 5,
                        decoration: BoxDecoration(
                          color: border,
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          20,
                          15,
                          20,
                          10,
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: isUpdating
                                  ? null
                                  : () => Navigator.pop(sheetContext),
                              icon: const Icon(Icons.close),
                            ),
                            Expanded(
                              child: Text(
                                'تعديل العقار',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.cairo(
                                  fontSize: 19,
                                  fontWeight: FontWeight.bold,
                                  color: navy,
                                ),
                              ),
                            ),
                            const SizedBox(width: 48),
                          ],
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(
                            20,
                            5,
                            20,
                            30,
                          ),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: lightGrey,
                                  borderRadius:
                                      BorderRadius.circular(14),
                                  border: Border.all(
                                    color: border,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: ChoiceChip(
                                        label: SizedBox(
                                          width: double.infinity,
                                          child: Text(
                                            'بيع',
                                            textAlign:
                                                TextAlign.center,
                                            style: GoogleFonts.cairo(
                                              color: operationType ==
                                                      'sale'
                                                  ? Colors.white
                                                  : navy,
                                              fontWeight:
                                                  FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        selected:
                                            operationType == 'sale',
                                        selectedColor: navy,
                                        backgroundColor:
                                            Colors.transparent,
                                        onSelected: isUpdating
                                            ? null
                                            : (_) {
                                                setSheetState(() {
                                                  operationType =
                                                      'sale';
                                                });
                                              },
                                      ),
                                    ),
                                    Expanded(
                                      child: ChoiceChip(
                                        label: SizedBox(
                                          width: double.infinity,
                                          child: Text(
                                            'إيجار',
                                            textAlign:
                                                TextAlign.center,
                                            style: GoogleFonts.cairo(
                                              color: operationType ==
                                                      'rent'
                                                  ? Colors.white
                                                  : navy,
                                              fontWeight:
                                                  FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        selected:
                                            operationType == 'rent',
                                        selectedColor: navy,
                                        backgroundColor:
                                            Colors.transparent,
                                        onSelected: isUpdating
                                            ? null
                                            : (_) {
                                                setSheetState(() {
                                                  operationType =
                                                      'rent';
                                                });
                                              },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildTextField(
                                controller: shortIdController,
                                label: 'رقم العقار',
                                hint: 'مثال: 1025',
                                icon: Icons.tag,
                                keyboardType:
                                    TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter
                                      .digitsOnly,
                                  LengthLimitingTextInputFormatter(
                                    4,
                                  ),
                                ],
                                validator: (value) {
                                  if (value == null ||
                                      value.trim().isEmpty) {
                                    return 'أدخلي رقم العقار';
                                  }

                                  if (value.trim().length != 4) {
                                    return 'رقم العقار يجب أن يكون 4 أرقام';
                                  }

                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),
                              _buildTextField(
                                controller: titleController,
                                label: 'عنوان العقار',
                                hint: 'عنوان العقار',
                                icon: Icons.home_outlined,
                                validator: (value) {
                                  if (value == null ||
                                      value.trim().isEmpty) {
                                    return 'أدخلي عنوان العقار';
                                  }

                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),
                              _buildDropdown(
                                label: 'نوع العقار',
                                value: propertyType,
                                items: propertyTypes
                                    .where(
                                      (e) => e != 'الكل',
                                    )
                                    .toList(),
                                icon: Icons.apartment_outlined,
                                onChanged: (value) {
                                  if (value != null) {
                                    setSheetState(() {
                                      propertyType = value;
                                    });
                                  }
                                },
                              ),
                              const SizedBox(height: 14),
                              _buildDropdown(
                                label: 'المدينة',
                                value: city,
                                items: cities
                                    .where(
                                      (e) => e != 'الكل',
                                    )
                                    .toList(),
                                icon:
                                    Icons.location_city_outlined,
                                onChanged: (value) {
                                  if (value != null) {
                                    setSheetState(() {
                                      city = value;
                                      district = 'الكل';
                                    });
                                  }
                                },
                              ),
                              const SizedBox(height: 14),
                              _buildDropdown(
                                label: 'الحي',
                                value: district,
                                items: currentDistricts,
                                icon:
                                    Icons.location_on_outlined,
                                onChanged: (value) {
                                  if (value != null) {
                                    setSheetState(() {
                                      district = value;
                                    });
                                  }
                                },
                              ),
                              const SizedBox(height: 14),
                              _buildTextField(
                                controller: priceController,
                                label: 'السعر',
                                hint: 'مثال: 850000',
                                icon:
                                    Icons.payments_outlined,
                                keyboardType:
                                    TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter
                                      .digitsOnly,
                                ],
                                validator: (value) {
                                  if (value == null ||
                                      value.trim().isEmpty) {
                                    return 'أدخلي السعر';
                                  }

                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),
                              _buildTextField(
                                controller: phoneController,
                                label: 'رقم المالك',
                                hint: '05xxxxxxxx',
                                icon: Icons.phone_outlined,
                                keyboardType:
                                    TextInputType.phone,
                              ),
                              const SizedBox(height: 14),
                              _buildTextField(
                                controller:
                                    descriptionController,
                                label: 'وصف العقار',
                                hint:
                                    'اكتبي تفاصيل العقار...',
                                icon:
                                    Icons.description_outlined,
                                maxLines: 5,
                              ),
                              const SizedBox(height: 16),
                              if (existingImages.isNotEmpty)
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: lightGrey,
                                    borderRadius:
                                        BorderRadius.circular(16),
                                    border: Border.all(
                                      color: border,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.end,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              'الصور الحالية',
                                              textAlign:
                                                  TextAlign.right,
                                              style:
                                                  GoogleFonts.cairo(
                                                fontSize: 14,
                                                fontWeight:
                                                    FontWeight.bold,
                                                color: navy,
                                              ),
                                            ),
                                          ),
                                          const Icon(
                                            Icons
                                                .photo_library_outlined,
                                            color: navy,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      SizedBox(
                                        height: 105,
                                        child: ListView.separated(
                                          scrollDirection:
                                              Axis.horizontal,
                                          reverse: true,
                                          itemCount:
                                              existingImages.length,
                                          separatorBuilder:
                                              (_, _) =>
                                                  const SizedBox(
                                            width: 10,
                                          ),
                                          itemBuilder:
                                              (context, index) {
                                            final imageUrl =
                                                existingImages[
                                                    index];

                                            return Stack(
                                              clipBehavior:
                                                  Clip.none,
                                              children: [
                                                ClipRRect(
                                                  borderRadius:
                                                      BorderRadius
                                                          .circular(
                                                    14,
                                                  ),
                                                  child:
                                                      Image.network(
                                                    imageUrl,
                                                    width: 105,
                                                    height: 105,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (
                                                      context,
                                                      error,
                                                      stackTrace,
                                                    ) {
                                                      return Container(
                                                        width: 105,
                                                        height: 105,
                                                        decoration:
                                                            BoxDecoration(
                                                          color:
                                                              Colors.grey.shade200,
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                            14,
                                                          ),
                                                        ),
                                                        child:
                                                            const Icon(
                                                          Icons
                                                              .broken_image_outlined,
                                                          color:
                                                              grey,
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                ),
                                                Positioned(
                                                  top: -7,
                                                  right: -7,
                                                  child: InkWell(
                                                    onTap:
                                                        isUpdating
                                                            ? null
                                                            : () {
                                                                setSheetState(
                                                                  () {
                                                                    existingImages
                                                                        .removeAt(
                                                                      index,
                                                                    );
                                                                  },
                                                                );
                                                              },
                                                    child:
                                                        Container(
                                                      width: 27,
                                                      height: 27,
                                                      decoration:
                                                          const BoxDecoration(
                                                        color:
                                                            Colors.red,
                                                        shape:
                                                            BoxShape.circle,
                                                      ),
                                                      child:
                                                          const Icon(
                                                        Icons.close,
                                                        color:
                                                            Colors.white,
                                                        size: 17,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            );
                                          },
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'اضغطي على × لحذف الصورة من العقار',
                                        style: GoogleFonts.cairo(
                                          fontSize: 10,
                                          color: grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (existingImages.isNotEmpty)
                                const SizedBox(height: 12),

                              _buildImagePickerSection(
                                selectedImages: newImages,
                                onAddImages: () async {
                                  final images =
                                      await _pickImages();

                                  if (images.isEmpty) return;

                                  setSheetState(() {
                                    newImages.addAll(images);
                                  });
                                },
                                onRemoveImage: (index) {
                                  setSheetState(() {
                                    newImages.removeAt(index);
                                  });
                                },
                              ),

                              const SizedBox(height: 25),

                              SizedBox(
                                width: double.infinity,
                                height: 54,
                                child: ElevatedButton(
                                  onPressed: isUpdating
                                      ? null
                                      : () async {
                                          if (!formKey
                                              .currentState!
                                              .validate()) {
                                            return;
                                          }

                                          setSheetState(() {
                                            isUpdating = true;
                                          });

                                          try {
                                            final shortId =
                                                shortIdController
                                                    .text
                                                    .trim();

                                            final available =
                                                await isShortIdAvailable(
                                              shortId,
                                              excludeDocumentId:
                                                  doc.id,
                                            );

                                            if (!available) {
                                              setSheetState(() {
                                                isUpdating = false;
                                              });

                                              if (context.mounted) {
                                                ScaffoldMessenger
                                                        .of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      'رقم العقار مستخدم مسبقًا',
                                                      style:
                                                          GoogleFonts.cairo(),
                                                    ),
                                                  ),
                                                );
                                              }

                                              return;
                                            }

                                            final price =
                                                double.tryParse(
                                                      priceController
                                                          .text
                                                          .trim(),
                                                    ) ??
                                                    0;

                                            final oldImages =
                                                <String>[];

                                            final originalImages =
                                                data['images'];

                                            if (originalImages
                                                is List) {
                                              oldImages.addAll(
                                                originalImages
                                                    .map(
                                                      (e) =>
                                                          e.toString(),
                                                    )
                                                    .where(
                                                      (e) =>
                                                          e.isNotEmpty,
                                                    ),
                                              );
                                            }

                                            final removedImages =
                                                oldImages
                                                    .where(
                                                      (url) =>
                                                          !existingImages
                                                              .contains(
                                                        url,
                                                      ),
                                                    )
                                                    .toList();

                                            await FirebaseFirestore
                                                .instance
                                                .collection(
                                                  'real_estates',
                                                )
                                                .doc(doc.id)
                                                .update({
                                              'shortId': shortId,
                                              'type':
                                                  operationType,
                                              'propertyType':
                                                  propertyType,
                                              'city': city,
                                              'district': district,
                                              'title':
                                                  titleController
                                                      .text
                                                      .trim(),
                                              'price': price,
                                              'ownerPhone':
                                                  phoneController
                                                      .text
                                                      .trim(),
                                              'description':
                                                  descriptionController
                                                      .text
                                                      .trim(),
                                              'images':
                                                  existingImages,
                                              'updatedAt':
                                                  FieldValue
                                                      .serverTimestamp(),
                                            });

                                            for (final imageUrl
                                                in removedImages) {
                                              await _deleteImageFromStorage(
                                                imageUrl,
                                              );
                                            }

                                            final newImageUrls =
                                                <String>[];

                                            for (int i = 0;
                                                i <
                                                    newImages.length;
                                                i++) {
                                              final url =
                                                  await _uploadPropertyImage(
                                                propertyId:
                                                    doc.id,
                                                image:
                                                    newImages[i],
                                                index: i +
                                                    existingImages
                                                        .length,
                                              );

                                              newImageUrls.add(url);
                                            }

                                            if (newImageUrls
                                                .isNotEmpty) {
                                              await FirebaseFirestore
                                                  .instance
                                                  .collection(
                                                    'real_estates',
                                                  )
                                                  .doc(doc.id)
                                                  .update({
                                                'images': [
                                                  ...existingImages,
                                                  ...newImageUrls,
                                                ],
                                              });
                                            }

                                            if (sheetContext
                                                .mounted) {
                                              Navigator.pop(
                                                sheetContext,
                                              );
                                            }

                                            if (mounted) {
                                              ScaffoldMessenger
                                                      .of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'تم تعديل العقار بنجاح',
                                                    style:
                                                        GoogleFonts.cairo(),
                                                  ),
                                                ),
                                              );
                                            }
                                          } catch (e) {
                                            setSheetState(() {
                                              isUpdating = false;
                                            });

                                            if (context.mounted) {
                                              ScaffoldMessenger
                                                      .of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'حدث خطأ أثناء تعديل العقار',
                                                    style:
                                                        GoogleFonts.cairo(),
                                                  ),
                                                ),
                                              );
                                            }
                                          }
                                        },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: navy,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(15),
                                    ),
                                  ),
                                  child: isUpdating
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child:
                                              CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Text(
                                          'حفظ التعديلات',
                                          style: GoogleFonts.cairo(
                                            fontWeight:
                                                FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                ),
                              ),
                            ],
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
  }

  String _formatPriceForInput(dynamic value) {
    if (value == null) return '';

    if (value is num) {
      return value.toInt().toString();
    }

    return value.toString();
  }

  // =========================================================
  // تغيير حالة العقار - المدير والمسوق
  // =========================================================

  Future<void> _changePropertyStatus(
    String documentId,
    String newStatus,
    String statusLabel,
  ) async {
    if (!canManagePropertyStatus) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'تغيير حالة العقار',
            textAlign: TextAlign.right,
            style: GoogleFonts.cairo(
              fontWeight: FontWeight.bold,
              color: navy,
            ),
          ),
          content: Text(
            'هل أنتِ متأكدة من تغيير حالة العقار إلى "$statusLabel"؟',
            textAlign: TextAlign.right,
            style: GoogleFonts.cairo(
              fontSize: 13,
              color: navy,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: Text(
                'إلغاء',
                style: GoogleFonts.cairo(
                  color: grey,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: navy,
                foregroundColor: Colors.white,
              ),
              child: Text(
                'تأكيد',
                style: GoogleFonts.cairo(
                  fontWeight: FontWeight.bold,
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
      await FirebaseFirestore.instance
          .collection('real_estates')
          .doc(documentId)
          .update({
        'status': newStatus,
        'statusUpdatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم تغيير حالة العقار إلى $statusLabel',
            style: GoogleFonts.cairo(),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'حدث خطأ أثناء تغيير حالة العقار',
            style: GoogleFonts.cairo(),
          ),
        ),
      );
    }
  }

  // =========================================================
  // حذف العقار - المدير فقط
  // =========================================================

  Future<void> _deleteRealEstate(
    String documentId,
    String title,
  ) async {
    if (!isAdmin) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'حذف العقار',
            textAlign: TextAlign.right,
            style: GoogleFonts.cairo(
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          content: Text(
            'هل أنتِ متأكدة من حذف العقار "$title"؟\nلا يمكن التراجع عن هذه العملية.',
            textAlign: TextAlign.right,
            style: GoogleFonts.cairo(
              fontSize: 13,
              color: navy,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: Text(
                'إلغاء',
                style: GoogleFonts.cairo(
                  color: grey,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: Text(
                'حذف',
                style: GoogleFonts.cairo(
                  fontWeight: FontWeight.bold,
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
      final doc = await FirebaseFirestore.instance
          .collection('real_estates')
          .doc(documentId)
          .get();

      final data = doc.data() ?? {};

      final images = <String>[];

      if (data['images'] is List) {
        images.addAll(
          (data['images'] as List)
              .map((e) => e.toString())
              .where((e) => e.isNotEmpty),
        );
      }

      await FirebaseFirestore.instance
          .collection('real_estates')
          .doc(documentId)
          .delete();

      for (final imageUrl in images) {
        await _deleteImageFromStorage(imageUrl);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم حذف العقار والصور بنجاح',
              style: GoogleFonts.cairo(),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'حدث خطأ أثناء حذف العقار',
              style: GoogleFonts.cairo(),
            ),
          ),
        );
      }
    }
  }
    // =========================================================
  // الفلاتر
  // =========================================================

  void showFilterBottomSheet() {
    String tempPropertyType = selectedPropertyType;
    String tempCity = selectedCity;
    String tempDistrict = selectedDistrict;

    final tempMinController = TextEditingController(
      text: minPriceController.text,
    );

    final tempMaxController = TextEditingController(
      text: maxPriceController.text,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final availableDistricts = tempCity == 'الكل'
                ? ['الكل']
                : districts[tempCity] ?? ['الكل'];

            if (!availableDistricts.contains(tempDistrict)) {
              tempDistrict = 'الكل';
            }

            return Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 15,
                bottom:
                    MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Container(
                      width: 45,
                      height: 5,
                      decoration: BoxDecoration(
                        color: border,
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    const SizedBox(height: 15),
                    Text(
                      'فلترة العقارات',
                      style: GoogleFonts.cairo(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: navy,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildDropdown(
                      label: 'نوع العقار',
                      value: tempPropertyType,
                      items: propertyTypes,
                      icon: Icons.apartment_outlined,
                      onChanged: (value) {
                        if (value != null) {
                          setSheetState(() {
                            tempPropertyType = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                    _buildDropdown(
                      label: 'المدينة',
                      value: tempCity,
                      items: cities,
                      icon: Icons.location_city_outlined,
                      onChanged: (value) {
                        if (value != null) {
                          setSheetState(() {
                            tempCity = value;
                            tempDistrict = 'الكل';
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                    _buildDropdown(
                      label: 'الحي',
                      value: tempDistrict,
                      items: availableDistricts,
                      icon: Icons.location_on_outlined,
                      onChanged: (value) {
                        if (value != null) {
                          setSheetState(() {
                            tempDistrict = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: tempMaxController,
                            label: 'أعلى سعر',
                            hint: '0',
                            icon: Icons.arrow_upward,
                            keyboardType:
                                TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter
                                  .digitsOnly,
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildTextField(
                            controller: tempMinController,
                            label: 'أقل سعر',
                            hint: '0',
                            icon: Icons.arrow_downward,
                            keyboardType:
                                TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter
                                  .digitsOnly,
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            selectedPropertyType =
                                tempPropertyType;
                            selectedCity = tempCity;
                            selectedDistrict =
                                tempDistrict;

                            minPrice =
                                double.tryParse(
                              tempMinController.text.trim(),
                            );

                            maxPrice =
                                double.tryParse(
                              tempMaxController.text.trim(),
                            );

                            minPriceController.text =
                                tempMinController.text;

                            maxPriceController.text =
                                tempMaxController.text;
                          });

                          Navigator.pop(sheetContext);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: navy,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          'تطبيق الفلترة',
                          style: GoogleFonts.cairo(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          selectedPropertyType = 'الكل';
                          selectedCity = 'الكل';
                          selectedDistrict = 'الكل';
                          minPrice = null;
                          maxPrice = null;
                          minPriceController.clear();
                          maxPriceController.clear();
                        });

                        Navigator.pop(sheetContext);
                      },
                      child: Text(
                        'مسح جميع الفلاتر',
                        style: GoogleFonts.cairo(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // =========================================================
  // مطابقة الفلاتر
  // =========================================================

  bool matchesFilters(Map<String, dynamic> data) {
    final title =
        data['title']?.toString().toLowerCase() ?? '';

    final shortId =
        data['shortId']?.toString().toLowerCase() ?? '';

    final city =
        data['city']?.toString() ?? '';

    final district =
        data['district']?.toString() ?? '';

    final propertyType =
        data['propertyType']?.toString() ?? '';

    final price = _getPrice(data['price']);

    if (searchQuery.isNotEmpty) {
      final matchesSearch =
          title.contains(searchQuery) ||
          shortId.contains(searchQuery) ||
          city.toLowerCase().contains(searchQuery) ||
          district.toLowerCase().contains(searchQuery) ||
          propertyType.toLowerCase().contains(searchQuery);

      if (!matchesSearch) {
        return false;
      }
    }

    if (selectedPropertyType != 'الكل' &&
        propertyType != selectedPropertyType) {
      return false;
    }

    if (selectedCity != 'الكل' &&
        city != selectedCity) {
      return false;
    }

    if (selectedDistrict != 'الكل' &&
        district != selectedDistrict) {
      return false;
    }

    if (minPrice != null && price < minPrice!) {
      return false;
    }

    if (maxPrice != null && price > maxPrice!) {
      return false;
    }

    return true;
  }

  double _getPrice(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }

  String _formatPrice(dynamic value) {
    final price = _getPrice(value);

    if (price == 0) {
      return 'غير محدد';
    }

    final text = price.toInt().toString();

    final buffer = StringBuffer();

    for (int i = 0; i < text.length; i++) {
      if (i > 0 &&
          (text.length - i) % 3 == 0) {
        buffer.write(',');
      }

      buffer.write(text[i]);
    }

    return '${buffer.toString()} ريال';
  }

  // =========================================================
  // الصور في تفاصيل العقار
  // =========================================================

  Widget _buildPropertyImages(List<String> images) {
    if (images.isEmpty) {
      return Container(
        width: double.infinity,
        height: 180,
        decoration: BoxDecoration(
          color: lightGrey,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.image_not_supported_outlined,
              size: 45,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 8),
            Text(
              'لا توجد صور للعقار',
              style: GoogleFonts.cairo(
                color: grey,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: 230,
      child: PageView.builder(
        itemCount: images.length,
        itemBuilder: (context, index) {
          return Container(
            margin:
                const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: border),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.network(
                images[index],
                fit: BoxFit.cover,
                loadingBuilder:
                    (context, child, loadingProgress) {
                  if (loadingProgress == null) {
                    return child;
                  }

                  return const Center(
                    child: CircularProgressIndicator(
                      color: navy,
                    ),
                  );
                },
                errorBuilder:
                    (context, error, stackTrace) {
                  return Container(
                    color: lightGrey,
                    child: const Center(
                      child: Icon(
                        Icons.broken_image_outlined,
                        size: 45,
                        color: grey,
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  // =========================================================
  // تفاصيل العقار
  // =========================================================

  void openRealEstateDetails(DocumentSnapshot doc) {
    final data =
        doc.data() as Map<String, dynamic>? ?? {};

    final shortId =
        data['shortId']?.toString() ?? '-';

    final title =
        data['title']?.toString() ?? 'بدون عنوان';

    final propertyType =
        data['propertyType']?.toString() ?? '-';

    final city =
        data['city']?.toString() ?? '-';

    final district =
        data['district']?.toString() ?? '-';

    final ownerPhone =
        data['ownerPhone']?.toString() ?? '-';

    final description =
        data['description']?.toString() ?? '';

    final type =
        data['type']?.toString() ?? 'sale';

    final status =
        data['status']?.toString() ?? 'active';

    final images = <String>[];

    if (data['images'] is List) {
      images.addAll(
        (data['images'] as List)
            .map((e) => e.toString())
            .where((e) => e.isNotEmpty),
      );
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          constraints: BoxConstraints(
            maxHeight:
                MediaQuery.of(context).size.height * 0.90,
          ),
          padding: const EdgeInsets.fromLTRB(
            20,
            15,
            20,
            25,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(28),
            ),
          ),
          child: SingleChildScrollView(
            child: Column(
              children: [
                Container(
                  width: 45,
                  height: 5,
                  decoration: BoxDecoration(
                    color: border,
                    borderRadius:
                        BorderRadius.circular(20),
                  ),
                ),

                const SizedBox(height: 18),

                _buildPropertyImages(images),

                const SizedBox(height: 18),

                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        textAlign: TextAlign.right,
                        style: GoogleFonts.cairo(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: navy,
                        ),
                      ),
                    ),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: type == 'sale'
                            ? Colors.green.withValues(alpha: .1)
                            : Colors.blue.withValues(alpha: .1),
                        borderRadius:
                            BorderRadius.circular(20),
                      ),
                      child: Text(
                        type == 'sale'
                            ? 'للبيع'
                            : 'للإيجار',
                        style: GoogleFonts.cairo(
                          color: type == 'sale'
                              ? Colors.green
                              : Colors.blue,
                          fontWeight:
                              FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),

                // حالة العقار
                if (status == 'rented') ...[
                  const SizedBox(height: 10),
                  _statusBadge(
                    text: 'مؤجر',
                    icon: Icons.check_circle_outline,
                    color: Colors.green,
                  ),
                ],

                if (status == 'sold') ...[
                  const SizedBox(height: 10),
                  _statusBadge(
                    text: 'تم البيع',
                    icon: Icons.done_all,
                    color: Colors.red,
                  ),
                ],

                const SizedBox(height: 20),

                _detailRow(
                  icon: Icons.tag,
                  title: 'رقم العقار',
                  value: shortId,
                ),

                _detailRow(
                  icon: Icons.apartment_outlined,
                  title: 'نوع العقار',
                  value: propertyType,
                ),

                _detailRow(
                  icon: Icons.location_city_outlined,
                  title: 'المدينة',
                  value: city,
                ),

                _detailRow(
                  icon: Icons.location_on_outlined,
                  title: 'الحي',
                  value: district,
                ),

                _detailRow(
                  icon: Icons.payments_outlined,
                  title: 'السعر',
                  value: _formatPrice(data['price']),
                ),

                _detailRow(
                  icon: Icons.phone_outlined,
                  title: 'رقم المالك',
                  value: ownerPhone,
                ),

                if (description.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'الوصف',
                      style: GoogleFonts.cairo(
                        fontWeight: FontWeight.bold,
                        color: navy,
                      ),
                    ),
                  ),
                  const SizedBox(height: 7),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: lightGrey,
                      borderRadius:
                          BorderRadius.circular(14),
                      border: Border.all(
                        color: border,
                      ),
                    ),
                    child: Text(
                      description,
                      textAlign: TextAlign.right,
                      style: GoogleFonts.cairo(
                        fontSize: 13,
                        color: grey,
                        height: 1.7,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: navy,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      'إغلاق',
                      style: GoogleFonts.cairo(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _statusBadge({
    required String text,
    required IconData icon,
    required Color color,
  }) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              style: GoogleFonts.cairo(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(width: 5),
            Icon(
              icon,
              size: 15,
              color: color,
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: lightGrey,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: border,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: navy,
            size: 21,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.end,
              children: [
                Text(
                  title,
                  style: GoogleFonts.cairo(
                    fontSize: 10,
                    color: grey,
                  ),
                ),
                Text(
                  value,
                  textAlign: TextAlign.right,
                  style: GoogleFonts.cairo(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: navy,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // قائمة العقارات
  // =========================================================

  Widget _buildRealEstateList(String operationType) {
    final firestoreType =
        operationType == 'sold' ? 'sale' : operationType;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('real_estates')
          .where(
            'type',
            isEqualTo: firestoreType,
          )
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: navy,
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'حدث خطأ في تحميل العقارات',
              style: GoogleFonts.cairo(
                color: Colors.red,
              ),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        final filteredDocs = docs.where((doc) {
          final data =
              doc.data() as Map<String, dynamic>? ?? {};

          final status =
              (data['status'] ?? 'active').toString();

          // قسم بيع منتهي
          if (operationType == 'sold') {
            if (status != 'sold') {
              return false;
            }
          }

          // قسم البيع العادي
          if (operationType == 'sale') {
            if (status == 'sold') {
              return false;
            }
          }

          return matchesFilters(data);
        }).toList();

        filteredDocs.sort((a, b) {
          final aData =
              a.data() as Map<String, dynamic>? ?? {};

          final bData =
              b.data() as Map<String, dynamic>? ?? {};

          final aDate = aData['createdAt'];
          final bDate = bData['createdAt'];

          if (aDate is Timestamp &&
              bDate is Timestamp) {
            return bDate.compareTo(aDate);
          }

          return 0;
        });

        if (filteredDocs.isEmpty) {
          return RefreshIndicator(
            color: navy,
            onRefresh: () async {
              setState(() {});
            },
            child: ListView(
              physics:
                  const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height:
                      MediaQuery.of(context).size.height *
                          0.5,
                  child: Center(
                    child: Column(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.home_work_outlined,
                          size: 65,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          operationType == 'sale'
                              ? 'لا توجد عقارات للبيع'
                              : operationType == 'rent'
                                  ? 'لا توجد عقارات للإيجار'
                                  : 'لا توجد عقارات مباعة',
                          style: GoogleFonts.cairo(
                            color: grey,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        final Map<String,
            Map<String, List<DocumentSnapshot>>> groupedData = {};

        for (final doc in filteredDocs) {
          final data =
              doc.data() as Map<String, dynamic>? ?? {};

          final city =
              data['city']?.toString().trim() ?? '';

          final district =
              data['district']?.toString().trim() ?? '';

          if (city.isEmpty || city == 'الكل') {
            continue;
          }

          final safeDistrict =
              district.isEmpty || district == 'الكل'
                  ? 'بدون حي'
                  : district;

          groupedData.putIfAbsent(
            city,
            () => {},
          );

          groupedData[city]!.putIfAbsent(
            safeDistrict,
            () => [],
          );

          groupedData[city]![safeDistrict]!.add(doc);
        }

        final citiesList = groupedData.keys.toList()
          ..sort();

        if (citiesList.isEmpty) {
          return Center(
            child: Text(
              'لا توجد مدن أو أحياء مضافة',
              style: GoogleFonts.cairo(
                color: grey,
              ),
            ),
          );
        }

        return RefreshIndicator(
          color: navy,
          onRefresh: () async {
            setState(() {});
          },
          child: ListView.builder(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(
              15,
              15,
              15,
              100,
            ),
            physics:
                const AlwaysScrollableScrollPhysics(),
            itemCount: citiesList.length,
            itemBuilder: (context, cityIndex) {
              final city =
                  citiesList[cityIndex];

              final districtsMap =
                  groupedData[city]!;

              final districtsList =
                  districtsMap.keys.toList()
                    ..sort();

              return Container(
                margin:
                    const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.circular(20),
                  border: Border.all(
                    color: border,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black
                          .withValues(alpha: .04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Theme(
                  data: Theme.of(context).copyWith(
                    dividerColor: Colors.transparent,
                  ),
                  child: ExpansionTile(
                    tilePadding:
                        const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 4,
                    ),
                    childrenPadding:
                        const EdgeInsets.fromLTRB(
                      12,
                      0,
                      12,
                      14,
                    ),
                    leading: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color:
                            navy.withValues(alpha: .08),
                        borderRadius:
                            BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.location_city,
                        color: navy,
                      ),
                    ),
                    title: Text(
                      city,
                      textAlign: TextAlign.right,
                      style: GoogleFonts.cairo(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: navy,
                      ),
                    ),
                    subtitle: Text(
                      '${districtsList.length} أحياء',
                      textAlign: TextAlign.right,
                      style: GoogleFonts.cairo(
                        fontSize: 11,
                        color: grey,
                      ),
                    ),
                    iconColor: navy,
                    collapsedIconColor: navy,
                    children: districtsList.map(
                      (district) {
                        final districtProperties =
                            districtsMap[district] ?? [];

                        return Container(
                          width: double.infinity,
                          margin:
                              const EdgeInsets.only(
                            bottom: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius:
                                BorderRadius.circular(16),
                            border: Border.all(
                              color: border,
                            ),
                          ),
                          child: Theme(
                            data: Theme.of(context)
                                .copyWith(
                              dividerColor:
                                  Colors.transparent,
                            ),
                            child: ExpansionTile(
                              tilePadding:
                                  const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 2,
                              ),
                              childrenPadding:
                                  const EdgeInsets.fromLTRB(
                                10,
                                0,
                                10,
                                10,
                              ),
                              leading: Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: lightGrey,
                                  borderRadius:
                                      BorderRadius.circular(
                                    12,
                                  ),
                                ),
                                child: const Icon(
                                  Icons
                                      .location_on_outlined,
                                  color: navy,
                                  size: 22,
                                ),
                              ),
                              title: Text(
                                district,
                                textAlign:
                                    TextAlign.right,
                                style: GoogleFonts.cairo(
                                  fontSize: 15,
                                  fontWeight:
                                      FontWeight.bold,
                                  color: navy,
                                ),
                              ),
                              subtitle: Text(
                                '${districtProperties.length} عقار',
                                textAlign:
                                    TextAlign.right,
                                style: GoogleFonts.cairo(
                                  fontSize: 10,
                                  color: grey,
                                ),
                              ),
                              iconColor: navy,
                              collapsedIconColor: navy,
                              children:
                                  districtProperties
                                      .map(
                                (propertyDoc) =>
                                    _buildPropertyCard(
                                  propertyDoc,
                                ),
                              ).toList(),
                            ),
                          ),
                        );
                      },
                    ).toList(),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  // =========================================================
  // بطاقة العقار
  // =========================================================

  Widget _buildPropertyCard(DocumentSnapshot doc) {
    final data =
        doc.data() as Map<String, dynamic>? ?? {};

    final title =
        data['title']?.toString() ?? 'بدون عنوان';

    final shortId =
        data['shortId']?.toString() ?? '-';

    final propertyType =
        data['propertyType']?.toString() ?? '-';

    final city =
        data['city']?.toString() ?? '-';

    final district =
        data['district']?.toString() ?? '-';

    final type =
        data['type']?.toString() ?? 'sale';

    final status =
        (data['status'] ?? 'active').toString();

    final price = data['price'];

    final images = <String>[];

    if (data['images'] is List) {
      images.addAll(
        (data['images'] as List)
            .map((e) => e.toString())
            .where((e) => e.isNotEmpty),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: border,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          children: [
            if (images.isNotEmpty)
              GestureDetector(
                onTap: () {
                  openRealEstateDetails(doc);
                },
                child: ClipRRect(
                  borderRadius:
                      BorderRadius.circular(17),
                  child: SizedBox(
                    height: 180,
                    width: double.infinity,
                    child: Image.network(
                      images.first,
                      fit: BoxFit.cover,
                      errorBuilder:
                          (context, error, stackTrace) {
                        return Container(
                          color: lightGrey,
                          child: const Icon(
                            Icons.broken_image_outlined,
                            size: 45,
                            color: grey,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              )
            else
              Container(
                height: 100,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: lightGrey,
                  borderRadius:
                      BorderRadius.circular(17),
                ),
                child: const Icon(
                  Icons.home_work_outlined,
                  color: navy,
                  size: 35,
                ),
              ),

            const SizedBox(height: 14),

            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: navy.withValues(alpha: .08),
                    borderRadius:
                        BorderRadius.circular(15),
                  ),
                  child: const Icon(
                    Icons.home_work_outlined,
                    color: navy,
                    size: 27,
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.end,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow:
                            TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: GoogleFonts.cairo(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: navy,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'رقم العقار: $shortId',
                        style: GoogleFonts.cairo(
                          fontSize: 11,
                          color: grey,
                        ),
                      ),
                      if (images.isNotEmpty)
                        Text(
                          '${images.length} صور',
                          style: GoogleFonts.cairo(
                            fontSize: 10,
                            color: grey,
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment:
                      CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding:
                          const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: type == 'sale'
                            ? Colors.green.withValues(alpha: .1)
                            : Colors.blue.withValues(alpha: .1),
                        borderRadius:
                            BorderRadius.circular(20),
                      ),
                      child: Text(
                        type == 'sale'
                            ? 'بيع'
                            : 'إيجار',
                        style: GoogleFonts.cairo(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: type == 'sale'
                              ? Colors.green
                              : Colors.blue,
                        ),
                      ),
                    ),

                    if (status == 'rented') ...[
                      const SizedBox(height: 5),
                      _statusBadge(
                        text: 'مؤجر',
                        icon: Icons.check_circle_outline,
                        color: Colors.green,
                      ),
                    ],

                    if (status == 'sold') ...[
                      const SizedBox(height: 5),
                      _statusBadge(
                        text: 'تم البيع',
                        icon: Icons.done_all,
                        color: Colors.red,
                      ),
                    ],
                  ],
                ),

                if (canManagePropertyStatus) ...[
                  const SizedBox(width: 2),
                  PopupMenuButton<String>(
                    tooltip: 'تغيير حالة العقار',
                    icon: const Icon(
                      Icons.more_vert,
                      color: navy,
                    ),
                    onSelected: (value) {
                      if (value == 'sold') {
                        _changePropertyStatus(
                          doc.id,
                          'sold',
                          'تم البيع',
                        );
                      } else if (value == 'rented') {
                        _changePropertyStatus(
                          doc.id,
                          'rented',
                          'مؤجر',
                        );
                      }
                    },
                    itemBuilder: (context) {
                      return [
                        if (type == 'sale' &&
                            status != 'sold')
                          PopupMenuItem<String>(
                            value: 'sold',
                            child: Text(
                              'تم البيع',
                              style: GoogleFonts.cairo(
                                color: navy,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        if (type == 'rent' &&
                            status != 'rented')
                          PopupMenuItem<String>(
                            value: 'rented',
                            child: Text(
                              'تم التأجير',
                              style: GoogleFonts.cairo(
                                color: navy,
                                fontSize: 13,
                              ),
                            ),
                          ),
                      ];
                    },
                  ),
                ],
              ],
            ),

            const SizedBox(height: 14),

            Wrap(
              alignment: WrapAlignment.end,
              spacing: 7,
              runSpacing: 7,
              children: [
                _smallInfo(
                  Icons.apartment_outlined,
                  propertyType,
                ),
                _smallInfo(
                  Icons.location_city_outlined,
                  city,
                ),
                if (district != 'الكل' &&
                    district.isNotEmpty)
                  _smallInfo(
                    Icons.location_on_outlined,
                    district,
                  ),
              ],
            ),

            const SizedBox(height: 13),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 9,
              ),
              decoration: BoxDecoration(
                color: lightGrey,
                borderRadius:
                    BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment:
                    MainAxisAlignment.end,
                children: [
                  Text(
                    _formatPrice(price),
                    style: GoogleFonts.cairo(
                      fontWeight: FontWeight.bold,
                      color: navy,
                    ),
                  ),
                  const SizedBox(width: 7),
                  const Icon(
                    Icons.payments_outlined,
                    size: 18,
                    color: navy,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      openRealEstateDetails(doc);
                    },
                    icon: const Icon(
                      Icons.visibility_outlined,
                      size: 18,
                    ),
                    label: Text(
                      'التفاصيل',
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                    style:
                        OutlinedButton.styleFrom(
                      foregroundColor: navy,
                      side: const BorderSide(
                        color: border,
                      ),
                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(
                          12,
                        ),
                      ),
                    ),
                  ),
                ),

                if (isAdmin) ...[
                  const SizedBox(width: 8),

                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        showEditRealEstateBottomSheet(
                          doc,
                        );
                      },
                      icon: const Icon(
                        Icons.edit_outlined,
                        size: 18,
                      ),
                      label: Text(
                        'تعديل',
                        style: GoogleFonts.cairo(
                          fontSize: 12,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                      style:
                          OutlinedButton.styleFrom(
                        foregroundColor: navy,
                        side: const BorderSide(
                          color: navy,
                        ),
                        shape:
                            RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(
                            12,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        _deleteRealEstate(
                          doc.id,
                          title,
                        );
                      },
                      icon: const Icon(
                        Icons.delete_outline,
                        size: 18,
                      ),
                      label: Text(
                        'حذف',
                        style: GoogleFonts.cairo(
                          fontSize: 12,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                      style:
                          OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: BorderSide(
                          color: Colors.red
                              .withValues(alpha: .35),
                        ),
                        shape:
                            RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(
                            12,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _smallInfo(
    IconData icon,
    String text,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: lightGrey,
        borderRadius:
            BorderRadius.circular(20),
        border: Border.all(
          color: border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: GoogleFonts.cairo(
              fontSize: 10,
              color: grey,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            icon,
            size: 14,
            color: navy,
          ),
        ],
      ),
    );
  }

  // =========================================================
  // الصفحة الرئيسية
  // =========================================================

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: lightGrey,

        appBar: AppBar(
          backgroundColor: navy,
          foregroundColor: Colors.white,
          elevation: 0,

          title: Text(
            'العقارات',
            style: GoogleFonts.cairo(
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),

          centerTitle: true,

         actions: [
  if (isAdmin)
    IconButton(
      onPressed: () async {
        try {
          final result = await importEastAbhaProperties();

          if (!context.mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'تم الاستيراد: ${result['added']} عقار | تم التخطي: ${result['skipped']}',
                style: GoogleFonts.cairo(),
              ),
            ),
          );
        } catch (e) {
          if (!context.mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'حدث خطأ أثناء الاستيراد: $e',
                style: GoogleFonts.cairo(),
              ),
            ),
          );
        }
      },
      tooltip: 'استيراد عقارات شرق أبها',
      icon: const Icon(
        Icons.cloud_upload_outlined,
      ),
    ),

  IconButton(
    onPressed: showFilterBottomSheet,
    tooltip: 'فلترة',
    icon: const Icon(
      Icons.filter_alt_outlined,
    ),
  ),
],
          bottom: PreferredSize(
            preferredSize:
                const Size.fromHeight(105),
            child: Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.fromLTRB(
                    15,
                    0,
                    15,
                    10,
                  ),
                  child: TextField(
                    controller: searchController,
                    textDirection:
                        TextDirection.rtl,
                    style: GoogleFonts.cairo(
                      color: navy,
                    ),
                    decoration: InputDecoration(
                      hintText:
                          'ابحث برقم العقار أو الاسم أو المدينة...',
                      hintStyle:
                          GoogleFonts.cairo(
                        color: grey,
                        fontSize: 11,
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: navy,
                      ),
                      suffixIcon:
                          searchController.text.isNotEmpty
                              ? IconButton(
                                  onPressed: () {
                                    searchController
                                        .clear();
                                  },
                                  icon: const Icon(
                                    Icons.clear,
                                    color: grey,
                                  ),
                                )
                              : null,
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(
                          14,
                        ),
                        borderSide:
                            BorderSide.none,
                      ),
                    ),
                  ),
                ),

                const TabBar(
                  indicatorColor: Colors.white,
                  indicatorWeight: 3,
                  labelColor: Colors.white,
                  unselectedLabelColor:
                      Colors.white70,
                  tabs: [
                    Tab(
                      icon: Icon(
                        Icons.sell_outlined,
                      ),
                      text: 'بيع',
                    ),
                    Tab(
                      icon: Icon(
                        Icons.home_work_outlined,
                      ),
                      text: 'إيجار',
                    ),
                    Tab(
                      icon: Icon(
                        Icons.done_all_outlined,
                      ),
                      text: 'بيع منتهي',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        body: TabBarView(
          children: [
            _buildRealEstateList('sale'),
            _buildRealEstateList('rent'),
            _buildRealEstateList('sold'),
          ],
        ),

        floatingActionButton:
            FloatingActionButton.extended(
          onPressed: showAddPropertyTypeDialog,
          backgroundColor: navy,
          foregroundColor: Colors.white,
          icon: const Icon(
            Icons.add_home_work_outlined,
          ),
          label: Text(
            'إضافة عقار',
            style: GoogleFonts.cairo(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}