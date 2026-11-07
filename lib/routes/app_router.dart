import 'package:go_router/go_router.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/auth/views/forgot_password_screen.dart';
import '../features/auth/views/login_screen.dart';
import '../features/auth/views/sign_up_screen.dart';
import '../features/customers/data/customer_repository.dart';
import '../features/customers/domain/customer.dart';
import '../features/customers/views/customer_form_screen.dart';
import '../features/dashboard/views/dashboard_screen.dart';
import '../features/products/data/product_repository.dart';
import '../features/products/views/products_screen.dart';
import '../features/more/views/more_screen.dart';
import '../screens/splash_screen.dart';
import 'app_shell.dart';
import 'stream_listenable.dart';

class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String signUp = '/signup';
  static const String forgotPassword = '/forgot-password';
  static const String home = '/home';
  static const String more = '/more';
  static const String products = '/products';
  static const String customerNew = '/customers/new';
  static const String customerEdit = '/customers/edit';

  static const _public = {login, signUp, forgotPassword};
}

/// Signed-in users never see the auth screens; signed-out users never see the app.
/// Re-evaluated on every sign-in / sign-out, including a remote password reset.
GoRouter createRouter(
  AuthRepository repository,
  ProductRepository productRepository,
  CustomerRepository customerRepository,
) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: StreamListenable(repository.signedInChanges),
    redirect: (context, state) {
      final path = state.matchedLocation;
      if (path == AppRoutes.splash) return null;
      final isPublic = AppRoutes._public.contains(path);
      if (repository.isSignedIn) return isPublic ? AppRoutes.home : null;
      return isPublic ? null : AppRoutes.login;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        name: 'splash',
        builder: (context, state) => SplashScreen(onFinished: () => context.go(AppRoutes.home)),
      ),
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (context, state) => LoginScreen(
          repository: repository,
          onSignUp: () => context.go(AppRoutes.signUp),
          onForgotPassword: () => context.push(AppRoutes.forgotPassword),
        ),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        name: 'forgotPassword',
        builder: (context, state) => ForgotPasswordScreen(
          repository: repository,
          onBackToLogin: () => context.pop(),
        ),
      ),
      GoRoute(
        path: AppRoutes.signUp,
        name: 'signUp',
        builder: (context, state) => SignUpScreen(
          repository: repository,
          onLogIn: () => context.go(AppRoutes.login),
        ),
      ),
      GoRoute(
        path: AppRoutes.products,
        name: 'products',
        builder: (context, state) => ProductsScreen(repository: productRepository),
      ),
      GoRoute(
        path: AppRoutes.customerNew,
        name: 'customerNew',
        builder: (context, state) => CustomerFormScreen(repository: customerRepository),
      ),
      GoRoute(
        path: AppRoutes.customerEdit,
        name: 'customerEdit',
        // The customer to edit travels as `extra`; without it there is nothing to edit.
        redirect: (context, state) => state.extra is Customer ? null : AppRoutes.home,
        builder: (context, state) =>
            CustomerFormScreen(repository: customerRepository, customer: state.extra! as Customer),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.home,
              name: 'home',
              builder: (context, state) => DashboardScreen(repository: repository),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.more,
              name: 'more',
              builder: (context, state) => MoreScreen(
                repository: repository,
                onOpenProducts: () => context.push(AppRoutes.products),
              ),
            ),
          ]),
        ],
      ),
    ],
  );
}
