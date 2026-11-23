import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../core/view_models/live_list_view_model.dart';
import '../design_system/foundations/radius/app_radius.dart';
import '../design_system/foundations/spacing/app_spacing.dart';
import 'app_3d_decorations.dart';
import 'app_text_field.dart';
import 'empty_state.dart';
import 'liquid_glass.dart';
import 'list_skeleton.dart';

/// Full page for a live list (searchable when a search controller is given): app bar, search box, optional [header],
/// loading skeleton, error with Retry, the list, and an "Add" button.
/// The whole page is one scrollable so every part stays reachable on short screens.
/// Wrap in a ListenableBuilder on [viewModel] so [visible] is recomputed on changes.
class SearchableListPage<T> extends StatelessWidget {
  const SearchableListPage({
    super.key,
    required this.title,
    this.subtitle,
    this.titleIcon,
    required this.viewModel,
    required this.visible,
    this.searchController,
    this.searchHint = 'Search',
    this.onQueryChanged,
    this.searchTrailing,
    required this.itemBuilder,
    required this.emptyBuilder,
    this.addLabel,
    this.onAdd,
    this.header,
    this.footer,
    this.actions,
  });

  final String title;

  /// A line under the title (e.g. "4 parcels").
  final String? subtitle;

  /// An icon tile before the title.
  final IconData? titleIcon;
  final LiveListViewModel<T> viewModel;

  /// Items to show (already filtered by the caller's view model).
  final List<T> visible;

  /// The search box is shown only when a [searchController] is given.
  final TextEditingController? searchController;
  final String searchHint;
  final ValueChanged<String>? onQueryChanged;

  /// A control beside the search box (e.g. a Filters button).
  final Widget? searchTrailing;
  final Widget Function(BuildContext context, T item) itemBuilder;

  /// Shown when [visible] is empty; the caller decides between "nothing yet" and "no matches".
  final Widget Function() emptyBuilder;

  /// The floating Add button is shown only when both are given.
  final String? addLabel;
  final VoidCallback? onAdd;

  /// Extra controls under the search box (e.g. segments).
  final Widget? header;

  /// Shown after the list when there are items (e.g. a "Load more" button).
  final Widget? footer;

  /// Optional actions for the curved app bar.
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    // The search box sits half over the header's bottom edge and stays put.
    // With large text or a short screen it scrolls with the list instead, so
    // the list keeps its room.
    final pinSearch =
        searchController != null &&
        textScale <= 1.3 &&
        MediaQuery.heightOf(context) >= 480;
    final searchHeight = 36 + 20 * textScale;
    return Scaffold(
      // The backdrop continues behind the header's curve and the search box.
      extendBodyBehindAppBar: true,
      appBar: appCurvedAppBar(
        bottomOverhang: pinSearch ? searchHeight / 2 + AppSpacing.sm : 0,
        bottom: pinSearch
            ? PreferredSize(
                preferredSize: Size.fromHeight(searchHeight + AppSpacing.sm),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: _maxWidth),
                    child: Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        AppSpacing.lg,
                        0,
                        AppSpacing.lg,
                        AppSpacing.sm,
                      ),
                      child: _searchRow(context),
                    ),
                  ),
                ),
              )
            : null,
        // Two lines of text need a taller bar, more so with large text.
        toolbarHeight: subtitle == null && titleIcon == null
            ? kToolbarHeight
            : AppBarTitle.heightFor(context),
        title: AppBarTitle(title, subtitle: subtitle, icon: titleIcon),
        actions: actions,
      ),
      floatingActionButton: addLabel == null || onAdd == null
          ? null
          // A pill with the solid 3D ledge under it.
          : DecoratedBox(
              decoration: const ShapeDecoration(
                shape: StadiumBorder(),
                gradient: AppColors.mintFabGradient,
                shadows: [
                  BoxShadow(color: AppColors.fabBevel, offset: Offset(0, 4)),
                ],
              ),
              // No hero animation: the tabs stay alive side by side, and two buttons with the default hero tag
              // make Flutter throw when any screen is pushed.
              child: FloatingActionButton.extended(
                heroTag: null,
                onPressed: onAdd,
                backgroundColor: Colors.transparent,
                foregroundColor: AppColors.primaryDark,
                elevation: 0,
                focusElevation: 0,
                hoverElevation: 0,
                highlightElevation: 0,
                shape: const StadiumBorder(),
                icon: const Icon(Icons.add),
                label: Text(
                  addLabel!,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
      body: LiquidBackground(
        // The list runs to the bottom edge (under the floating tab bar); its
        // own bottom padding keeps the last row reachable.
        child: SafeArea(
          bottom: false,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _maxWidth),
              child: CustomScrollView(
                slivers: [
                  if (searchController != null && !pinSearch)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(
                          AppSpacing.lg,
                          AppSpacing.lg,
                          AppSpacing.lg,
                          AppSpacing.sm,
                        ),
                        child: _searchRow(context),
                      ),
                    ),
                  if (header != null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsetsDirectional.fromSTEB(
                          AppSpacing.lg,
                          pinSearch ? AppSpacing.sm : 0,
                          AppSpacing.lg,
                          0,
                        ),
                        child: header,
                      ),
                    ),
                  ..._content(MediaQuery.paddingOf(context).bottom),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static const double _maxWidth = 640;

  /// The search box with [searchTrailing] beside it, or under it when large
  /// text leaves no room for both.
  Widget _searchRow(BuildContext context) {
    // Glass, blurred: the green header shows through the half that lies on it.
    final search = GlassSurface(
      radius: AppRadius.control,
      blurSigma: 12,
      ledgeHeight: 0,
      child: AppTextField.search(
        controller: searchController!,
        hint: searchHint,
        onChanged: onQueryChanged,
        glass: true,
      ),
    );
    final trailing = searchTrailing;
    if (trailing == null) return search;
    if (MediaQuery.textScalerOf(context).scale(1) > 1.3) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          search,
          const SizedBox(height: AppSpacing.sm),
          trailing,
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: search),
        const SizedBox(width: AppSpacing.sm),
        trailing,
      ],
    );
  }

  /// [bottomInset] is the room to keep free under the content (the system
  /// inset, plus the floating tab bar on a tab page).
  List<Widget> _content(double bottomInset) {
    if (viewModel.errorMessage != null) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: EdgeInsets.only(bottom: bottomInset),
            child: EmptyState(
              icon: Icons.error_outline_rounded,
              title: "Couldn't load the list",
              message: viewModel.errorMessage,
              actionLabel: 'Retry',
              onAction: viewModel.retry,
            ),
          ),
        ),
      ];
    }
    if (viewModel.isLoading) {
      return const [SliverToBoxAdapter(child: ListSkeleton())];
    }
    if (visible.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: EdgeInsets.only(bottom: bottomInset),
            child: emptyBuilder(),
          ),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: EdgeInsetsDirectional.fromSTEB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          footer == null
              ? AppSpacing.x6l + AppSpacing.lg + bottomInset
              : AppSpacing.xs,
        ),
        sliver: SliverList.separated(
          itemCount: visible.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
          itemBuilder: (context, index) => itemBuilder(context, visible[index]),
        ),
      ),
      if (footer != null)
        SliverPadding(
          padding: EdgeInsetsDirectional.only(
            bottom: AppSpacing.x6l + AppSpacing.lg + bottomInset,
          ),
          sliver: SliverToBoxAdapter(child: Center(child: footer)),
        ),
    ];
  }
}
