import 'package:flutter/material.dart';
import '../../../constants/app_colors.dart';
import '../../../design_system/foundations/spacing/app_spacing.dart';
import '../../auth/data/auth_repository.dart';
import '../../more/views/more_screen.dart';

/// Placeholder dashboard: greets the user and offers log out.
/// Parcel and payment totals (FR-11) come with the parcel features.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.repository});
  final AuthRepository repository;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DelivTrack'),
        actions: [
          IconButton(
            tooltip: 'Log out',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => confirmLogout(context, repository),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsetsDirectional.all(AppSpacing.xxl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: StreamBuilder<String?>(
                stream: repository.displayNameChanges,
                initialData: repository.displayName,
                builder: (context, snapshot) {
                  final name = snapshot.data?.trim() ?? '';
                  return Text(
                    name.isEmpty ? 'Welcome' : 'Welcome, $name',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryDark,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
