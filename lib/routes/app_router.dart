import 'package:go_router/go_router.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/auth/views/forgot_password_screen.dart';
import '../features/auth/views/login_screen.dart';
import '../features/auth/views/sign_up_screen.dart';
import '../screens/splash_screen.dart';

class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String signUp = '/signup';
  static const String forgotPassword = '/forgot-password';
}

final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.splash,
  routes: [
    GoRoute(
      path: AppRoutes.splash,
      name: 'splash',
      builder: (context, state) => SplashScreen(onFinished: () => context.go(AppRoutes.login)),
    ),
    GoRoute(
      path: AppRoutes.login,
      name: 'login',
      builder: (context, state) => LoginScreen(
        repository: FirebaseAuthRepository(),
        onSignUp: () => context.go(AppRoutes.signUp),
        onForgotPassword: () => context.push(AppRoutes.forgotPassword),
      ),
    ),
    GoRoute(
      path: AppRoutes.forgotPassword,
      name: 'forgotPassword',
      builder: (context, state) => ForgotPasswordScreen(
        repository: FirebaseAuthRepository(),
        onBackToLogin: () => context.pop(),
      ),
    ),
    GoRoute(
      path: AppRoutes.signUp,
      name: 'signUp',
      builder: (context, state) => SignUpScreen(
        repository: FirebaseAuthRepository(),
        onLogIn: () => context.go(AppRoutes.login),
      ),
    ),
  ],
);
