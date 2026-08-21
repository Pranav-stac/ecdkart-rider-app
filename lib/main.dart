import 'dart:ui';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'firebase_options.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vegbox_driver_app/presentation/screens/splash_screen.dart';
import 'logic/blocs/auth/auth_bloc.dart';
import 'logic/blocs/driver/driver_bloc.dart'; // ✅ Import DriverBloc
// ... other imports

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (!kIsWeb) {
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
      kReleaseMode,
    );

    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      FirebaseCrashlytics.instance.recordFlutterFatalError(details);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (context) => AuthBloc()),
        BlocProvider(create: (context) => DriverBloc()), // ✅ Provide DriverBloc
      ],
      child: MaterialApp(
        title: 'ECD KART Driver',
        // theme: ThemeData(
        //   primarySwatch: const Color(0xFF22C55E),
        //   useMaterial3: true,
        // ),
        theme: ThemeData(
          primaryColor: const Color(0xFF22C55E),
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF22C55E)),
        ),

        debugShowCheckedModeBanner: false,
        home: const SplashScreen(), // Your initial screen
      ),
    );
  }
}
