import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/data/auth_repository.dart';
import '../features/auth/views/forgot_password_screen.dart';
import '../features/auth/views/login_screen.dart';
import '../features/auth/views/sign_up_screen.dart';
import '../features/customers/data/customer_repository.dart';
import '../features/customers/domain/customer.dart';
import '../features/customers/views/customer_form_screen.dart';
import '../features/customers/data/phone_dialer.dart';
import '../features/customers/views/customer_details_screen.dart';
import '../features/customers/views/customers_screen.dart';
import '../features/dashboard/views/dashboard_screen.dart';
import '../features/parcels/data/parcel_repository.dart';
import '../features/parcels/domain/parcel.dart';
import '../features/parcels/domain/parcel_search.dart';
import '../features/parcels/views/archived_parcels_screen.dart';
import '../features/parcels/views/parcel_details_screen.dart';
import '../features/parcels/views/parcel_form_screen.dart';
import '../features/parcels/views/parcels_screen.dart';
import '../features/payments/views/payments_screen.dart';
import '../features/reminders/data/reminder_scheduler.dart';
import '../features/reports/domain/reports.dart';
import '../features/settings/views/settings_screen.dart';
import '../features/reports/views/reports_screens.dart';
import '../features/reminders/views/reminders_screen.dart';
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
  static const String customers = '/customers';
  static const String parcels = '/parcels';
  static const String payments = '/payments';
  static const String parcelNew = '/parcels/new';
  static const String parcelDetails = '/parcels/:id';
  static const String parcelEdit = '/parcels/edit';

  static String parcelPath(String id) => '/parcels/$id';
  static const String reminders = '/reminders';
  static const String archived = '/archived';
  static const String settings = '/settings';
  static const String reports = '/reports';
  static const String reportDetails = '/reports/:type';

  static String reportPath(String type) => '/reports/$type';
  static const String products = '/products';
  static const String customerNew = '/customers/new';
  static const String customerEdit = '/customers/edit';
  static const String customerDetails = '/customers/:id';

  static String customerPath(String id) => '/customers/$id';

  static const _public = {login, signUp, forgotPassword};
}

/// Each tab page gets its own snackbar host. The tabs stay alive side by side, and one shared host
/// would show the same snackbar on every tab's Scaffold at once (duplicate animations, wrong place).
Widget _tabPage(Widget page) => ScaffoldMessenger(child: page);

/// Signed-in users never see the auth screens; signed-out users never see the app.
/// Re-evaluated on every sign-in / sign-out, including a remote password reset.
GoRouter createRouter(
  AuthRepository repository,
  ProductRepository productRepository,
  CustomerRepository customerRepository,
  ParcelRepository parcelRepository, {
  ReminderScheduler reminderScheduler = const NoReminderScheduler(),
  PhoneDialer dialer = const UrlLauncherDialer(),
}) {
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
        builder: (context, state) =>
            SplashScreen(onFinished: () => context.go(AppRoutes.home)),
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
        builder: (context, state) =>
            ProductsScreen(repository: productRepository),
      ),
      GoRoute(
        path: AppRoutes.settings,
        name: 'settings',
        builder: (context, state) => SettingsScreen(
          repository: repository,
          scheduler: reminderScheduler,
        ),
      ),
      GoRoute(
        path: AppRoutes.archived,
        name: 'archived',
        builder: (context, state) => ArchivedParcelsScreen(
          repository: parcelRepository,
          onOpen: (parcel) => context.push(AppRoutes.parcelPath(parcel.id)),
        ),
      ),
      GoRoute(
        path: AppRoutes.reports,
        name: 'reports',
        builder: (context, state) => ReportsScreen(
          onOpen: (type) => context.push(AppRoutes.reportPath(type.name)),
        ),
      ),
      GoRoute(
        path: AppRoutes.reportDetails,
        name: 'reportDetails',
        // An unknown report name leads back to the list instead of a broken screen.
        redirect: (context, state) =>
            ReportType.byName(state.pathParameters['type']!) == null
            ? AppRoutes.reports
            : null,
        builder: (context, state) => ReportScreen(
          repository: parcelRepository,
          type: ReportType.byName(state.pathParameters['type']!)!,
          onOpenParcel: (id) => context.push(AppRoutes.parcelPath(id)),
        ),
      ),
      GoRoute(
        path: AppRoutes.reminders,
        name: 'reminders',
        builder: (context, state) => RemindersScreen(
          repository: parcelRepository,
          scheduler: reminderScheduler,
          onOpen: (parcel) => context.push(AppRoutes.parcelPath(parcel.id)),
        ),
      ),
      GoRoute(
        path: AppRoutes.parcelNew,
        name: 'parcelNew',
        builder: (context, state) => ParcelFormScreen(
          parcelRepository: parcelRepository,
          customerRepository: customerRepository,
          productRepository: productRepository,
          onAddCustomer: () => context.push<String>(AppRoutes.customerNew),
        ),
      ),
      // Declared before the details route so "edit" is not read as a parcel id.
      GoRoute(
        path: AppRoutes.parcelEdit,
        name: 'parcelEdit',
        // The parcel to edit travels as `extra`; without it there is nothing to edit.
        redirect: (context, state) =>
            state.extra is Parcel ? null : AppRoutes.parcels,
        builder: (context, state) => ParcelFormScreen(
          parcelRepository: parcelRepository,
          customerRepository: customerRepository,
          productRepository: productRepository,
          onAddCustomer: () => context.push<String>(AppRoutes.customerNew),
          parcel: state.extra! as Parcel,
        ),
      ),
      GoRoute(
        path: AppRoutes.parcelDetails,
        name: 'parcelDetails',
        builder: (context, state) => ParcelDetailsScreen(
          repository: parcelRepository,
          parcelId: state.pathParameters['id']!,
          onEdit: (parcel) =>
              context.push<String>(AppRoutes.parcelEdit, extra: parcel),
        ),
      ),
      GoRoute(
        path: AppRoutes.customerNew,
        name: 'customerNew',
        builder: (context, state) =>
            CustomerFormScreen(repository: customerRepository),
      ),
      GoRoute(
        path: AppRoutes.customerEdit,
        name: 'customerEdit',
        // The customer to edit travels as `extra`; without it there is nothing to edit.
        redirect: (context, state) =>
            state.extra is Customer ? null : AppRoutes.customers,
        builder: (context, state) => CustomerFormScreen(
          repository: customerRepository,
          customer: state.extra! as Customer,
        ),
      ),
      // After /customers/new and /customers/edit, so those words are not read as a customer id.
      GoRoute(
        path: AppRoutes.customerDetails,
        name: 'customerDetails',
        builder: (context, state) => CustomerDetailsScreen(
          customerRepository: customerRepository,
          parcelRepository: parcelRepository,
          customerId: state.pathParameters['id']!,
          dialer: dialer,
          onEdit: (customer) =>
              context.push<String>(AppRoutes.customerEdit, extra: customer),
          onOpenParcel: (parcel) =>
              context.push(AppRoutes.parcelPath(parcel.id)),
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                name: 'home',
                builder: (context, state) => _tabPage(
                  DashboardScreen(
                    repository: repository,
                    parcelRepository: parcelRepository,
                    reminderScheduler: reminderScheduler,
                    onOpenReminders: () => context.push(AppRoutes.reminders),
                    onOpenParcel: (id) =>
                        context.push(AppRoutes.parcelPath(id)),
                    onOpenParcels: (filters) => context.go(
                      AppRoutes.parcels,
                      extra: filters.copyWith(),
                    ),
                    onOpenPayments: () => context.go(AppRoutes.payments),
                    onAddParcel: () async {
                      final id = await context.push<String>(
                        AppRoutes.parcelNew,
                      );
                      if (id != null && context.mounted) {
                        unawaited(context.push(AppRoutes.parcelPath(id)));
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.parcels,
                name: 'parcels',
                builder: (context, state) => _tabPage(
                  ParcelsScreen(
                    repository: parcelRepository,
                    // Home's figures open this list already narrowed (extra carries the filters).
                    initialFilters: state.extra is ParcelFilters
                        ? state.extra! as ParcelFilters
                        : null,
                    // After saving, open the new parcel's details (the list stays underneath).
                    onAdd: () async {
                      final id = await context.push<String>(
                        AppRoutes.parcelNew,
                      );
                      if (id != null && context.mounted) {
                        unawaited(context.push(AppRoutes.parcelPath(id)));
                      }
                    },
                    onOpen: (parcel) =>
                        context.push(AppRoutes.parcelPath(parcel.id)),
                  ),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.payments,
                name: 'payments',
                builder: (context, state) => _tabPage(
                  PaymentsScreen(
                    repository: parcelRepository,
                    onOpen: (parcel) =>
                        context.push(AppRoutes.parcelPath(parcel.id)),
                  ),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.customers,
                name: 'customers',
                builder: (context, state) => _tabPage(
                  CustomersScreen(
                    repository: customerRepository,
                    parcelRepository: parcelRepository,
                    onAdd: () => context.push<String>(AppRoutes.customerNew),
                    onOpen: (customer) =>
                        context.push(AppRoutes.customerPath(customer.id)),
                  ),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.more,
                name: 'more',
                builder: (context, state) => _tabPage(
                  MoreScreen(
                    repository: repository,
                    onOpenProducts: () => context.push(AppRoutes.products),
                    onOpenReports: () => context.push(AppRoutes.reports),
                    onOpenArchived: () => context.push(AppRoutes.archived),
                    onOpenSettings: () => context.push(AppRoutes.settings),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
