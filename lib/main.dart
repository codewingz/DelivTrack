import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'constants/app_colors.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/customers/data/customer_repository.dart';
import 'features/customers/data/contact_picker.dart';
import 'features/customers/data/phone_dialer.dart';
import 'features/parcels/data/parcel_repository.dart';
import 'features/products/data/product_repository.dart';
import 'features/reminders/data/reminder_scheduler.dart';
import 'firebase_options.dart';
import 'routes/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (const bool.fromEnvironment('USE_EMULATORS')) {
    // Local testing only: flutter run --dart-define=USE_EMULATORS=true
    await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
    FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
  }
  // Wait for the saved session to be restored so a logged-in user is never
  // mistaken for a signed-out one at startup.
  await FirebaseAuth.instance.authStateChanges().first;

  final reminderScheduler = LocalNotificationScheduler();
  await reminderScheduler.init();

  runApp(
    DelivTrackApp(
      reminderScheduler: reminderScheduler,
      dialer: const UrlLauncherDialer(),
      contactPicker: const SystemContactPicker(),
      repository: FirebaseAuthRepository(),
      productRepository: FirestoreProductRepository(),
      customerRepository: FirestoreCustomerRepository(),
      parcelRepository: FirestoreParcelRepository(),
    ),
  );
}

class DelivTrackApp extends StatefulWidget {
  const DelivTrackApp({
    super.key,
    required this.repository,
    required this.productRepository,
    required this.customerRepository,
    required this.parcelRepository,
    this.reminderScheduler = const NoReminderScheduler(),
    this.dialer = const NoPhoneDialer(),
    this.contactPicker = const NoContactPicker(),
  });
  final AuthRepository repository;
  final ProductRepository productRepository;
  final CustomerRepository customerRepository;
  final ParcelRepository parcelRepository;
  final ReminderScheduler reminderScheduler;
  final PhoneDialer dialer;
  final ContactPicker contactPicker;

  @override
  State<DelivTrackApp> createState() => _DelivTrackAppState();
}

class _DelivTrackAppState extends State<DelivTrackApp>
    with WidgetsBindingObserver {
  late final GoRouter _router = createRouter(
    widget.repository,
    widget.productRepository,
    widget.customerRepository,
    widget.parcelRepository,
    reminderScheduler: widget.reminderScheduler,
    dialer: widget.dialer,
    contactPicker: widget.contactPicker,
  );
  StreamSubscription<bool>? _signedIn;
  StreamSubscription<String>? _notificationTaps;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.repository.verifySession();
    // Nothing scheduled for one user may show up for the next: sign-out clears the phone's reminders.
    _signedIn = widget.repository.signedInChanges.listen((signedIn) {
      if (!signedIn) widget.reminderScheduler.cancelAll();
    });
    _notificationTaps = widget.reminderScheduler.taps.listen((parcelId) {
      if (widget.repository.isSignedIn) {
        _router.push(AppRoutes.parcelPath(parcelId));
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) widget.repository.verifySession();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _signedIn?.cancel();
    _notificationTaps?.cancel();
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'DelivTrack',
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          secondary: AppColors.accent,
          surface: AppColors.surface,
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
    );
  }
}
