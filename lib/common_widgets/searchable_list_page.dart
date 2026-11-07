import 'package:flutter/material.dart';
import '../core/view_models/live_list_view_model.dart';
import '../design_system/foundations/spacing/app_spacing.dart';
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
    required this.viewModel,
    required this.visible,
    this.searchController,
    this.searchHint = 'Search',
    this.onQueryChanged,
    required this.itemBuilder,
    required this.emptyBuilder,
    this.addLabel,
    this.onAdd,
    this.header,
    this.footer,
  });

  final String title;
  final LiveListViewModel<T> viewModel;

  /// Items to show (already filtered by the caller's view model).
  final List<T> visible;
  /// The search box is shown only when a [searchController] is given.
  final TextEditingController? searchController;
  final String searchHint;
  final ValueChanged<String>? onQueryChanged;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      floatingActionButton: addLabel == null || onAdd == null
          ? null
          : FloatingActionButton.extended(onPressed: onAdd, icon: const Icon(Icons.add), label: Text(addLabel!)),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: CustomScrollView(
              slivers: [
                if (searchController != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
                      child: AppTextField.search(controller: searchController!, hint: searchHint, onChanged: onQueryChanged),
                    ),
                  ),
                if (header != null)
                  SliverToBoxAdapter(
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Padding(
                        padding: const EdgeInsetsDirectional.symmetric(horizontal: AppSpacing.lg),
                        child: header,
                      ),
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
    if (viewModel.isLoading) return const [SliverToBoxAdapter(child: ListSkeleton())];
    if (visible.isEmpty) return [SliverFillRemaining(hasScrollBody: false, child: emptyBuilder())];
    return [
      SliverPadding(
        padding: EdgeInsetsDirectional.only(top: AppSpacing.sm, bottom: footer == null ? AppSpacing.x6l + AppSpacing.lg : AppSpacing.xs),
        sliver: SliverList.separated(
          itemCount: visible.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) => itemBuilder(context, visible[index]),
        ),
      ),
      if (footer != null)
        SliverPadding(
          padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.x6l + AppSpacing.lg),
          sliver: SliverToBoxAdapter(child: Center(child: footer)),
        ),
    ];
  }
}
