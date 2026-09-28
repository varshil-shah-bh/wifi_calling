import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// Override at build time with: flutter run --dart-define=API_BASE_URL=http://192.168.1.5:4000
const _override = String.fromEnvironment('API_BASE_URL');

String get apiBaseUrl {
  if (_override.isNotEmpty) return _override;
  // The Android emulator reaches the host machine through 10.0.2.2, not localhost.
  if (!kIsWeb && Platform.isAndroid) return 'http://10.0.2.2:4000';
  return 'http://localhost:4000';
}

const iceServers = <String, dynamic>{
  'iceServers': [
    {
      'urls': [
        'stun:stun.l.google.com:19302',
        'stun:stun1.l.google.com:19302',
      ],
    },
  ],
  'sdpSemantics': 'unified-plan',
};
