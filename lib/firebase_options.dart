// File generated for Apna Clinic Production Firebase Configuration.
// Project: apna-clinic-96541
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'core/config/app_config.dart';

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static String get _apiKey => AppConfig.current.firebaseApiKey.isNotEmpty
      ? AppConfig.current.firebaseApiKey
      : const String.fromEnvironment('FIREBASE_API_KEY', defaultValue: '');

  static String get projectId => AppConfig.current.firebaseProjectId.isNotEmpty
      ? AppConfig.current.firebaseProjectId
      : 'apna-clinic-96541-fd638';

  static String get messagingSenderId =>
      AppConfig.current.firebaseMessagingSenderId.isNotEmpty
          ? AppConfig.current.firebaseMessagingSenderId
          : '949559594307';

  static String get storageBucket =>
      AppConfig.current.firebaseStorageBucket.isNotEmpty
          ? AppConfig.current.firebaseStorageBucket
          : 'apna-clinic-96541-fd638.firebasestorage.app';

  static String get authDomain => AppConfig.current.firebaseAuthDomain.isNotEmpty
      ? AppConfig.current.firebaseAuthDomain
      : 'apna-clinic-96541-fd638.firebaseapp.com';

  static String get appId => AppConfig.current.firebaseAppId.isNotEmpty
      ? AppConfig.current.firebaseAppId
      : '1:949559594307:web:32948214f641df3a3ff3f6';

  static FirebaseOptions get web => FirebaseOptions(
        apiKey: _apiKey,
        appId: appId,
        messagingSenderId: messagingSenderId,
        projectId: projectId,
        authDomain: authDomain,
        storageBucket: storageBucket,
      );

  static FirebaseOptions get android => FirebaseOptions(
        apiKey: _apiKey,
        appId: appId,
        messagingSenderId: messagingSenderId,
        projectId: projectId,
        authDomain: authDomain,
        storageBucket: storageBucket,
      );

  static FirebaseOptions get ios => FirebaseOptions(
        apiKey: _apiKey,
        appId: appId,
        messagingSenderId: messagingSenderId,
        projectId: projectId,
        authDomain: authDomain,
        storageBucket: storageBucket,
      );

  static FirebaseOptions get macos => FirebaseOptions(
        apiKey: _apiKey,
        appId: appId,
        messagingSenderId: messagingSenderId,
        projectId: projectId,
        authDomain: authDomain,
        storageBucket: storageBucket,
      );

  static FirebaseOptions get windows => FirebaseOptions(
        apiKey: _apiKey,
        appId: appId,
        messagingSenderId: messagingSenderId,
        projectId: projectId,
        authDomain: authDomain,
        storageBucket: storageBucket,
      );
}
