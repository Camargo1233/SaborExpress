import 'package:flutter/foundation.dart';

class ApiConfig {
  static String get host {
    if (kIsWeb) {
      return 'localhost';
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return '10.0.2.2';
      default:
        return 'localhost';
    }
  }

  static String get baseUrl => 'http://$host:3000';
}
