// File generated manually for Firebase configuration.
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    // إعدادات مشتركة للمنصات (الويب، أندرويد، وماك)
    const firebaseOptions = FirebaseOptions(
      apiKey: 'AIzaSyCCD1JATV_uBi8UDCs8u10h7b-BV1yT8nQ',
      appId: '1:964837654334:android:cfb294b608853e9e6d766f',
      messagingSenderId: '964837654334',
      projectId: 'sharqabhaapp',
      storageBucket: 'sharqabhaapp.firebasestorage.app',
    );

    if (kIsWeb) {
      return firebaseOptions;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.macOS: // إضافة دعم الماك هنا
        return firebaseOptions;
      case TargetPlatform.iOS:
        throw UnsupportedError('iOS options not configured yet.');
      default:
        return firebaseOptions;
    }
  }
}