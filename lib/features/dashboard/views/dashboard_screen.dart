import 'package:flutter/material.dart';
import '../../../constants/app_colors.dart';
import '../../../design_system/foundations/spacing/app_spacing.dart';
import '../../auth/data/auth_repository.dart';
import '../../more/views/more_screen.dart';
import '../../parcels/data/parcel_repository.dart';
import '../../reminders/viewmodel/reminder_list_view_model.dart';

/// Placeholder dashboard: greets the user, shows the reminders bell and offers log out.
/// Parcel and payment totals (FR-11) come with the dashboard feature.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.repository, required this.parcelRepository, required this.onOpenReminders});
  final AuthRepository repository;
  final ParcelRepository parcelRepository;
  final VoidCallback onOpenReminders;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final _reminders = ReminderListViewModel(widget.parcelRepository);

  @override
  void dispose() {
    _reminders.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repository = widget.repository;
    return Scaffold(
      appBar: AppBar(
        title: const Text('DelivTrack'),
        actions: [
          ListenableBuilder(
            listenable: _reminders,
            builder: (context, _) {
              final due = _reminders.reminders.dueCount;
              return IconButton(
                tooltip: due == 0 ? 'Reminders' : 'Reminders, $due due',
                icon: Badge(
                  isLabelVisible: due > 0,
                  label: Text('$due'),
                  child: const Icon(Icons.notifications_none_rounded),
                ),
                onPressed: widget.onOpenReminders,
              );
            },
          ),
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
