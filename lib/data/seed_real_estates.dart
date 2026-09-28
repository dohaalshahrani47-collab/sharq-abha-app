import 'package:cloud_firestore/cloud_firestore.dart';
import 'east_abha_properties.dart';

/// استيراد عقارات شرق أبها من بيانات WordPress إلى Firestore.
/// شغّلي هذه الدالة مرة واحدة فقط من شاشة مؤقتة/زر للمشرف.
Future<Map<String, int>> importEastAbhaProperties() async {
  final db = FirebaseFirestore.instance;
  final collection = db.collection('real_estates');

  // نقرأ العقارات الحالية لمنع التكرار، ونحافظ على shortId غير مستخدم.
  final existingSnapshot = await collection.get();
  final existingSourceIds = <String>{};
  final usedShortIds = <String>{};

  for (final doc in existingSnapshot.docs) {
    final data = doc.data();
    final sourceId = data['sourceId'];
    final shortId = data['shortId'];

    if (sourceId != null) {
      existingSourceIds.add(sourceId.toString());
    }
    if (shortId != null) {
      usedShortIds.add(shortId.toString());
    }
  }

  String nextShortId() {
    for (var number = 1000; number <= 9999; number++) {
      final value = number.toString();
      if (!usedShortIds.contains(value)) {
        usedShortIds.add(value);
        return value;
      }
    }
    throw StateError('لا توجد أرقام عقارات من 4 أرقام متاحة.');
  }

  String normalizePropertyType(String value) {
    switch (value.trim()) {
      case 'دوبلكس':
        return 'فيلا';
      case 'روف للبيع':
        return 'فيلا';
      case 'شقه للبيع':
      case 'شقق سكنية':
      case 'شقة إيجار':
        return 'شقة';
      case 'دور سكني':
        return 'بيت';
      case 'ارض سكنية':
        return 'أرض';
      default:
        const allowed = {
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
        };
        return allowed.contains(value.trim()) ? value.trim() : 'أخرى';
    }
  }

  String normalizeType(String action) {
    return action.trim() == 'إيجار' ? 'rent' : 'sale';
  }

  // حالات WordPress ليست حالات Firestore في تطبيقك؛ لذلك نبدأ العقارات
  // المستوردة كـ active، ثم يمكن للمشرف/التسويق تغييرها إلى sold/rented.
  const importedStatus = 'active';

  var added = 0;
  var skipped = 0;
  var batch = db.batch();
  var batchCount = 0;

  Future<void> commitBatch() async {
    if (batchCount == 0) return;
    await batch.commit();
    batch = db.batch();
    batchCount = 0;
  }

  for (final property in eastAbhaProperties) {
    final sourceId = property['id']?.toString();
    if (sourceId == null || sourceId.isEmpty) {
      skipped++;
      continue;
    }

    if (existingSourceIds.contains(sourceId)) {
      skipped++;
      continue;
    }

    final action = property['action']?.toString() ?? 'بيع';
    final type = normalizeType(action);
    final propertyType =
        normalizePropertyType(property['type']?.toString() ?? 'أخرى');

    final docRef = collection.doc();
    final data = <String, dynamic>{
      'shortId': nextShortId(),
      'sourceId': sourceId,
      'source': 'wordpress_east_abha',
      'type': type,
      'status': importedStatus,
      'propertyType': propertyType,
      'city': property['city']?.toString() ?? 'أبها',
      'district': property['area']?.toString() ?? 'بدون حي',
      'title': property['title']?.toString() ?? 'عقار في شرق أبها',
      'price': property['price'] ?? 0,
      'ownerPhone': '',
      'description': property['description']?.toString() ?? '',
      'images': <String>[],
      'size': property['size'] ?? 0,
      'lotSize': property['lotSize'] ?? 0,
      'rooms': property['rooms'] ?? 0,
      'bedrooms': property['bedrooms'] ?? 0,
      'bathrooms': property['bathrooms'] ?? 0,
      'latitude': property['latitude'],
      'longitude': property['longitude'],
      'address': property['address']?.toString() ?? '',
      'featured': property['featured'] == true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    batch.set(docRef, data);
    batchCount++;
    added++;
    existingSourceIds.add(sourceId);

    // Firestore batched writes لها حد أقصى 500 عملية؛ نلتزم به بهامش آمن.
    if (batchCount >= 450) {
      await commitBatch();
    }
  }

  await commitBatch();

  return {
    'added': added,
    'skipped': skipped,
  };
}
