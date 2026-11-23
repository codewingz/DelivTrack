import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../core/view_models/live_list_view_model.dart';
import '../design_system/foundations/radius/app_radius.dart';
import '../design_system/foundations/spacing/app_spacing.dart';
import 'app_3d_decorations.dart';
import 'app_text_field.dart';
import 'empty_state.dart';
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
            : 24 + 48 * MediaQuery.textScalerOf(context).scale(1),
        title: _title(),
        actions: actions,
      ),
      floatingActionButton: addLabel == null || onAdd == null
          ? null
          // A pill with the solid 3D ledge under it.
          : DecoratedBox(
              decoration: const ShapeDecoration(
                shape: StadiumBorder(),
                shadows: [
                  BoxShadow(color: AppColors.fabBevel, offset: Offset(0, 4)),
                ],
              ),
              // No hero animation: the tabs stay alive side by side, and two buttons with the default hero tag
              // make Flutter throw when any screen is pushed.
              child: FloatingActionButton.extended(
                heroTag: null,
                onPressed: onAdd,
                backgroundColor: AppColors.mint,
                foregroundColor: AppColors.primaryDark,
                elevation: 4,
                shape: const StadiumBorder(),
                icon: const Icon(Icons.add),
                label: Text(
                  addLabel!,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
      body: SafeArea(
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
                ..._content(),
              ],
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
    final search = AppTextField.search(
      controller: searchController!,
      hint: searchHint,
      onChanged: onQueryChanged,
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

  Widget _title() {
    final text = subtitle == null
        ? Text(title)
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(
                subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: AppColors.brand100),
              ),
            ],
          );
    if (titleIcon == null) return text;
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.mint.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(AppRadius.control),
            border: Border.all(color: AppColors.mint.withValues(alpha: 0.3)),
          ),
          child: ExcludeSemantics(
            child: Icon(titleIcon, size: 20, color: AppColors.mint),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Flexible(child: text),
      ],
    );
  }

  List<Widget> _content() {
    if (viewModel.errorMessage != null) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyState(
            icon: Icons.error_outline_rounded,
            title: "Couldn't load the list",
            message: viewModel.errorMessage,
            actionLabel: 'Retry',
            onAction: viewModel.retry,
          ),
        ),
      ];
    }
    if (viewModel.isLoading) {
      return const [SliverToBoxAdapter(child: ListSkeleton())];
    }
    if (visible.isEmpty) {
      return [SliverFillRemaining(hasScrollBody: false, child: emptyBuilder())];
    }
    return [
      SliverPadding(
        padding: EdgeInsetsDirectional.fromSTEB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          footer == null ? AppSpacing.x6l + AppSpacing.lg : AppSpacing.xs,
        ),
        sliver: SliverList.separated(
          itemCount: visible.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
          itemBuilder: (context, index) => itemBuilder(context, visible[index]),
        ),
      ),
      if (footer != null)
        SliverPadding(
          padding: const EdgeInsetsDirectional.only(
            bottom: AppSpacing.x6l + AppSpacing.lg,
          ),
          sliver: SliverToBoxAdapter(child: Center(child: footer)),
        ),
    ];
  }
}
