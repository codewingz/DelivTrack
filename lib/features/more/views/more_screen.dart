import 'package:flutter/material.dart';

import '../../../common_widgets/app_3d_decorations.dart';
import '../../../common_widgets/confirm_dialog.dart';
import '../../../common_widgets/initial_avatar.dart';
import '../../../common_widgets/liquid_glass.dart';
import '../../../constants/app_colors.dart';
import '../../../design_system/foundations/radius/app_radius.dart';
import '../../../design_system/foundations/spacing/app_spacing.dart';
import '../../../utils/text.dart';
import '../../auth/data/auth_repository.dart';

/// Who is signed in, then the secondary sections in two groups.
class MoreScreen extends StatelessWidget {
  const MoreScreen({
    super.key,
    required this.repository,
    required this.onOpenProducts,
    required this.onOpenReports,
    required this.onOpenArchived,
    required this.onOpenSettings,
    required this.onOpenSenderProfile,
  });
  final AuthRepository repository;
  final VoidCallback onOpenProducts;
  final VoidCallback onOpenReports;
  final VoidCallback onOpenArchived;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenSenderProfile;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // The backdrop continues behind the header's curve.
      extendBodyBehindAppBar: true,
      appBar: appCurvedAppBar(
        toolbarHeight: AppBarTitle.heightFor(context),
        title: const AppBarTitle(
          'More',
          subtitle: 'Workspace & settings',
          icon: Icons.grid_view_outlined,
        ),
      ),
      body: LiquidBackground(
        child: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListView(
                padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
                children: [
                  _Account(repository: repository),
                  const _SectionLabel('Business & catalog'),
                  _Group(
                    tiles: [
                      _Tile(
                        icon: Icons.storefront_outlined,
                        title: 'Sender & return details',
                        subtitle: 'Slip address & return contact',
                        onTap: onOpenSenderProfile,
                      ),
                      _Tile(
                        icon: Icons.inventory_2_outlined,
                        title: 'Products',
                        subtitle: 'Manage products & selling units',
                        onTap: onOpenProducts,
                      ),
                      _Tile(
                        icon: Icons.assessment_outlined,
                        title: 'Reports',
                        subtitle: 'Collections, payments & parcel totals',
                        onTap: onOpenReports,
                      ),
                      _Tile(
                        icon: Icons.archive_outlined,
                        title: 'Archived parcels',
                        subtitle: 'Parcels hidden from the lists',
                        onTap: onOpenArchived,
                      ),
                    ],
                  ),
                  const _SectionLabel('Preferences & account'),
                  _Group(
                    tiles: [
                      _Tile(
                        icon: Icons.settings_outlined,
                        title: 'Settings',
                        onTap: onOpenSettings,
                      ),
                      _Tile(
                        icon: Icons.logout_rounded,
                        title: 'Log out',
                        color: AppColors.error,
                        showChevron: false,
                        onTap: () => confirmLogout(context, repository),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Who is signed in: initial, name and email.
class _Account extends StatelessWidget {
  const _Account({required this.repository});
  final AuthRepository repository;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<String?>(
      stream: repository.displayNameChanges,
      initialData: repository.displayName,
      builder: (context, snapshot) {
        final name = collapseSpaces(snapshot.data ?? '');
        final email = repository.email ?? '';
        final title = name.isNotEmpty ? name : 'DelivTrack account';
        return App3DCard(
          glass: true,
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              InitialAvatar(name: title, filled: true),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (email.isNotEmpty)
                      Text(
                        email,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Small uppercase heading above a group of rows.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.xs,
        AppSpacing.xl,
        AppSpacing.xs,
        AppSpacing.sm,
      ),
      child: Semantics(
        header: true,
        child: Text(
          text.toUpperCase(),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
            color: AppColors.label,
          ),
        ),
      ),
    );
  }
}

/// One row of the More screen.
class _Tile {
  const _Tile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.color = AppColors.primary,
    this.showChevron = true,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Color color;
  final bool showChevron;
}

/// A glass card of rows separated by thin lines.
class _Group extends StatelessWidget {
  const _Group({required this.tiles});
  final List<_Tile> tiles;

  @override
  Widget build(BuildContext context) {
    return App3DCard(
      glass: true,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final (index, tile) in tiles.indexed) ...[
            if (index > 0) const Divider(height: 1, color: AppColors.border),
            ListTile(
              minTileHeight: 72,
              contentPadding: const EdgeInsetsDirectional.fromSTEB(
                AppSpacing.lg,
                AppSpacing.xs,
                AppSpacing.md,
                AppSpacing.xs,
              ),
              leading: DecoratedBox(
                decoration: BoxDecoration(
                  color: tile.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.control),
                ),
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Icon(tile.icon, color: tile.color, size: 22),
                ),
              ),
              title: Text(
                tile.title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: tile.color == AppColors.primary
                      ? AppColors.textPrimary
                      : tile.color,
                ),
              ),
              subtitle: tile.subtitle == null
                  ? null
                  : Text(
                      tile.subtitle!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
              trailing: tile.showChevron
                  ? const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.label,
                    )
                  : null,
              onTap: tile.onTap,
            ),
          ],
        ],
      ),
    );
  }
}

/// Confirms, then signs out. The router sends the user to the login screen.
Future<void> confirmLogout(
  BuildContext context,
  AuthRepository repository,
) async {
  final confirmed = await showConfirmDialog(
    context,
    title: 'Log out?',
    message: 'You will need to log in again to use DelivTrack.',
    confirmLabel: 'Log out',
    destructive: true,
  );
  if (confirmed) await repository.signOut();
}
