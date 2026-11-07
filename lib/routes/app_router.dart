import 'package:go_router/go_router.dart';
import '../screens/splash_screen.dart';

class AppRoutes {
  static const String splash = '/';
}

final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.splash,
  routes: [
    GoRoute(
      path: AppRoutes.splash,
      name: 'splash',
      builder: (context, state) => const SplashScreen(),
    ),
  ],
);
