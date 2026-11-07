import 'package:flutter/material.dart';
import '../../../common_widgets/confirm_dialog.dart';
import '../../../constants/app_colors.dart';
import '../../auth/data/auth_repository.dart';

/// Secondary sections. Products and Reports are here; Settings is added when it is built.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key, required this.repository, required this.onOpenProducts, required this.onOpenReports});
  final AuthRepository repository;
  final VoidCallback onOpenProducts;
  final VoidCallback onOpenReports;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: SafeArea(
        child: ListView(
          children: [
            ListTile(
              minTileHeight: 56,
              leading: const Icon(Icons.inventory_2_outlined, color: AppColors.label),
              title: const Text('Products'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: onOpenProducts,
            ),
            const Divider(height: 1),
            ListTile(
              minTileHeight: 56,
              leading: const Icon(Icons.assessment_outlined, color: AppColors.label),
              title: const Text('Reports'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: onOpenReports,
            ),
            const Divider(height: 1),
            ListTile(
              minTileHeight: 56,
              leading: const Icon(Icons.logout_rounded, color: AppColors.error),
              title: const Text('Log out'),
              onTap: () => confirmLogout(context, repository),
            ),
          ],
        ),
      ),
    );
  }
}

/// Confirms, then signs out. The router sends the user to the login screen.
Future<void> confirmLogout(BuildContext context, AuthRepository repository) async {
  final confirmed = await showConfirmDialog(
    context,
    title: 'Log out?',
    message: 'You will need to log in again to use DelivTrack.',
    confirmLabel: 'Log out',
    destructive: true,
  );
  if (confirmed) await repository.signOut();
}
