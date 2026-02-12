import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../../app/theme.dart';
import '../../ads/ad_service.dart';
import '../../cleanup/application/cleanup_controller.dart';
import '../../scan/application/scan_controller.dart';
import '../../scan/domain/models.dart';
import '../../../../shared/utils/formatters.dart';

enum AssetFilter { all, old, duplicates, similar }

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key, this.thumbnailLoader});

  final Future<Uint8List?> Function(String assetId)? thumbnailLoader;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final Map<String, Future<Uint8List?>> _thumbnailFutures = {};
  final Set<String> _selectedAssetIds = <String>{};
  AssetFilter _currentFilter = AssetFilter.all;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(
      () => ref.read(scanControllerProvider.notifier).initialize(),
    );
  }

  Future<Uint8List?> _loadThumbnail(String assetId) async {
    if (widget.thumbnailLoader != null) {
      return widget.thumbnailLoader!(assetId);
    }

    final entity = await AssetEntity.fromId(assetId);
    if (entity == null) {
      return null;
    }
    return entity.thumbnailDataWithSize(const ThumbnailSize.square(300));
  }

  Future<Uint8List?> _thumbnailFutureFor(String assetId) {
    return _thumbnailFutures.putIfAbsent(assetId, () => _loadThumbnail(assetId));
  }

  List<ScreenshotAsset> _assetsForFilterValue(
    List<ScreenshotAsset> assets,
    AssetFilter filter,
  ) {
    return switch (filter) {
      AssetFilter.all => assets,
      AssetFilter.old => assets.where((asset) => asset.isOld).toList(growable: false),
      AssetFilter.duplicates =>
        assets.where((asset) => asset.isDuplicateCandidate).toList(growable: false),
      AssetFilter.similar =>
        assets.where((asset) => asset.isSimilarCandidate).toList(growable: false),
    };
  }

  List<ScreenshotAsset> _assetsForFilter(List<ScreenshotAsset> assets) {
    return _assetsForFilterValue(assets, _currentFilter);
  }

  void _applyFilter(AssetFilter filter, List<ScreenshotAsset> allAssets) {
    final visibleIdsInNewFilter = _assetsForFilterValue(allAssets, filter)
        .map((asset) => asset.id)
        .toSet();

    setState(() {
      _currentFilter = filter;
      _selectedAssetIds.removeWhere((id) => !visibleIdsInNewFilter.contains(id));
    });
  }

  int _selectedBytes(List<ScreenshotAsset> selectedAssets) {
    return selectedAssets.fold<int>(0, (sum, asset) => sum + asset.sizeBytes);
  }

  void _toggleAssetSelection(String id) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedAssetIds.contains(id)) {
        _selectedAssetIds.remove(id);
      } else {
        _selectedAssetIds.add(id);
      }
    });
  }

  void _selectAllVisible(List<ScreenshotAsset> visibleAssets) {
    HapticFeedback.mediumImpact();
    setState(() {
      _selectedAssetIds.addAll(visibleAssets.map((asset) => asset.id));
    });
  }

  void _clearSelection() {
    HapticFeedback.lightImpact();
    setState(_selectedAssetIds.clear);
  }

  bool _allVisibleSelected(List<ScreenshotAsset> visibleAssets) {
    if (visibleAssets.isEmpty) return false;
    return visibleAssets.every((asset) => _selectedAssetIds.contains(asset.id));
  }

  Future<void> _confirmAndDelete(List<ScreenshotAsset> selectedAssets) async {
    final selectedCount = selectedAssets.length;
    final selectedBytes = _selectedBytes(selectedAssets);
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.delete.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.delete_forever_rounded,
                  color: AppColors.delete,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text('Delete screenshots?'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.delete.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            '$selectedCount',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: AppColors.delete,
                            ),
                          ),
                          const Text(
                            'screenshots',
                            style: TextStyle(fontSize: 12, color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: Colors.black12,
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            formatBytes(selectedBytes),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: AppColors.delete,
                            ),
                          ),
                          const Text(
                            'freed up',
                            style: TextStyle(fontSize: 12, color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'This action cannot be undone.',
                style: TextStyle(fontSize: 13, color: Colors.black45),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              label: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true || !mounted) {
      return;
    }

    HapticFeedback.heavyImpact();

    final result =
        await ref.read(cleanupControllerProvider.notifier).deleteSelected(selectedAssets);
    if (!mounted || result == null) {
      return;
    }

    if (result.deletedCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Deleted ${result.deletedCount} screenshots, freed ${formatBytes(result.reclaimedBytes)}',
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.secondary,
        ),
      );
    }

    if (result.failedIds.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.warning_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Could not delete ${result.failedIds.length} screenshots.'),
              ),
            ],
          ),
        ),
      );
    }

    _clearSelection();
  }

  @override
  Widget build(BuildContext context) {
    final scanState = ref.watch(scanControllerProvider);
    final cleanupState = ref.watch(cleanupControllerProvider);
    final allAssets = scanState.report.assets;
    final visibleAssets = _assetsForFilter(allAssets);
    final validAssetIds = allAssets.map((asset) => asset.id).toSet();
    final selectedAssets = _selectedAssetIds
        .where(validAssetIds.contains)
        .map((id) => allAssets.firstWhere((asset) => asset.id == id))
        .toList(growable: false);

    if (selectedAssets.length != _selectedAssetIds.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        setState(() {
          _selectedAssetIds
            ..clear()
            ..addAll(selectedAssets.map((asset) => asset.id));
        });
      });
    }

    final hasSelection = selectedAssets.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.auto_delete_rounded,
                color: AppColors.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'ScreenClean',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
            ),
          ],
        ),
        actions: [
          if (hasSelection)
            TextButton.icon(
              onPressed: _clearSelection,
              icon: const Icon(Icons.close_rounded, size: 18),
              label: Text('${selectedAssets.length}'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                visualDensity: VisualDensity.compact,
              ),
            ),
          if (scanState.isLoading)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              tooltip: 'Scan',
              onPressed: () => ref.read(scanControllerProvider.notifier).rescan(),
              icon: const Icon(Icons.refresh_rounded),
            ),
        ],
      ),
      bottomNavigationBar: _BottomBar(
        hasSelection: hasSelection,
        selectedAssets: selectedAssets,
        selectedBytes: _selectedBytes(selectedAssets),
        isDeleting: cleanupState.isDeleting,
        onDelete: () => _confirmAndDelete(selectedAssets),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    hasSelection
                        ? '${selectedAssets.length} selected \u00B7 ${formatBytes(_selectedBytes(selectedAssets))}'
                        : 'Reclaim your space in seconds.',
                    style: TextStyle(
                      fontSize: 13,
                      color: hasSelection ? AppColors.primary : Colors.black54,
                      fontWeight: hasSelection ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SummarySection(report: scanState.report),
                  const SizedBox(height: 14),
                ],
              ),
            ),
            _FilterBar(
              currentFilter: _currentFilter,
              report: scanState.report,
              onFilterChanged: (filter) => _applyFilter(filter, allAssets),
            ),
            if (scanState.hasPermission && visibleAssets.isNotEmpty)
              _SelectionRow(
                visibleCount: visibleAssets.length,
                selectedCount: selectedAssets.length,
                allSelected: _allVisibleSelected(visibleAssets),
                onSelectAll: () => _selectAllVisible(visibleAssets),
                onDeselectAll: _clearSelection,
              ),
            if (scanState.errorMessage != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.delete.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          color: AppColors.delete, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          scanState.errorMessage!,
                          style:
                              const TextStyle(color: AppColors.delete, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 8),
            if (!scanState.hasPermission)
              const Expanded(child: _PermissionView())
            else if (scanState.isLoading && scanState.report.totalCount == 0)
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text(
                        'Scanning screenshots...',
                        style: TextStyle(color: Colors.black54, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _AssetGrid(
                    filter: _currentFilter,
                    assets: visibleAssets,
                    selectedAssetIds: _selectedAssetIds,
                    thumbnailFutureFor: _thumbnailFutureFor,
                    onTap: _toggleAssetSelection,
                    onRefresh: () =>
                        ref.read(scanControllerProvider.notifier).rescan(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom bar
// ---------------------------------------------------------------------------

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.hasSelection,
    required this.selectedAssets,
    required this.selectedBytes,
    required this.isDeleting,
    required this.onDelete,
  });

  final bool hasSelection;
  final List<ScreenshotAsset> selectedAssets;
  final int selectedBytes;
  final bool isDeleting;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        );
      },
      child: hasSelection
          ? SafeArea(
              key: const ValueKey('delete-bar'),
              minimum: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: FilledButton.icon(
                key: const Key('delete-selected-button'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.delete,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: isDeleting ? null : onDelete,
                icon: isDeleting
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.delete_outline_rounded),
                label: Text(
                  'Delete ${selectedAssets.length} \u00B7 ${formatBytes(selectedBytes)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 15),
                ),
              ),
            )
          : const AdBannerSlot(key: ValueKey('ad-bar')),
    );
  }
}

// ---------------------------------------------------------------------------
// Summary section
// ---------------------------------------------------------------------------

class _SummarySection extends StatelessWidget {
  const _SummarySection({required this.report});

  final ScanReport report;

  @override
  Widget build(BuildContext context) {
    final reclaimableBytes = report.assets
        .where(
          (asset) =>
              asset.isOld ||
              asset.isDuplicateCandidate ||
              asset.isSimilarCandidate,
        )
        .fold<int>(0, (sum, asset) => sum + asset.sizeBytes);
    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            icon: Icons.photo_library_rounded,
            iconColor: AppColors.primary,
            label: 'Screenshots',
            value: '${report.totalCount}',
            keyValue: const Key('summary-total-count'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SummaryCard(
            icon: Icons.storage_rounded,
            iconColor: AppColors.orange,
            label: 'Total size',
            value: formatBytes(report.totalBytes),
            keyValue: const Key('summary-total-bytes'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SummaryCard(
            icon: Icons.cleaning_services_rounded,
            iconColor: AppColors.secondary,
            label: 'Reclaimable',
            value: formatBytes(reclaimableBytes),
            keyValue: const Key('summary-reclaimable-bytes'),
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.keyValue,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final Key keyValue;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: iconColor),
            const SizedBox(height: 8),
            Text(
              value,
              key: keyValue,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: Colors.black45),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Filter bar
// ---------------------------------------------------------------------------

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.currentFilter,
    required this.report,
    required this.onFilterChanged,
  });

  final AssetFilter currentFilter;
  final ScanReport report;
  final ValueChanged<AssetFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _FilterChip(
            key: const Key('filter-all'),
            label: 'All',
            count: report.totalCount,
            selected: currentFilter == AssetFilter.all,
            onSelected: () => onFilterChanged(AssetFilter.all),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            key: const Key('filter-old'),
            label: 'Old',
            count: report.oldCount,
            selected: currentFilter == AssetFilter.old,
            selectedColor: AppColors.orange,
            onSelected: () => onFilterChanged(AssetFilter.old),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            key: const Key('filter-duplicates'),
            label: 'Duplicates',
            count: report.duplicateCount,
            selected: currentFilter == AssetFilter.duplicates,
            selectedColor: AppColors.primary,
            onSelected: () => onFilterChanged(AssetFilter.duplicates),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            key: const Key('filter-similar'),
            label: 'Similar',
            count: report.similarCount,
            selected: currentFilter == AssetFilter.similar,
            selectedColor: AppColors.teal,
            onSelected: () => onFilterChanged(AssetFilter.similar),
          ),
        ],
      ),
    );
  }
}

class _SelectionRow extends StatelessWidget {
  const _SelectionRow({
    required this.visibleCount,
    required this.selectedCount,
    required this.allSelected,
    required this.onSelectAll,
    required this.onDeselectAll,
  });

  final int visibleCount;
  final int selectedCount;
  final bool allSelected;
  final VoidCallback onSelectAll;
  final VoidCallback onDeselectAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 8, 0),
      child: Row(
        children: [
          Text(
            '$visibleCount items',
            style: const TextStyle(fontSize: 12, color: Colors.black45),
          ),
          const Spacer(),
          GestureDetector(
            key: const Key('select-all-button'),
            onTap: allSelected ? onDeselectAll : onSelectAll,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(
                allSelected ? 'Deselect all' : 'Select all',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    super.key,
    required this.label,
    required this.count,
    required this.selected,
    required this.onSelected,
    this.selectedColor,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onSelected;
  final Color? selectedColor;

  @override
  Widget build(BuildContext context) {
    final color = selectedColor ?? AppColors.primary;
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (count > 0) ...[
            const SizedBox(width: 4),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: selected
                    ? color.withValues(alpha: 0.2)
                    : Colors.black.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: selected ? color : Colors.black45,
                ),
              ),
            ),
          ],
        ],
      ),
      selected: selected,
      selectedColor: color.withValues(alpha: 0.12),
      labelStyle: TextStyle(
        color: selected ? color : Colors.black87,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
      ),
      side: BorderSide(
        color: selected
            ? color.withValues(alpha: 0.4)
            : Colors.grey.withValues(alpha: 0.25),
      ),
      onSelected: (_) => onSelected(),
    );
  }
}

// ---------------------------------------------------------------------------
// Permission view
// ---------------------------------------------------------------------------

class _PermissionView extends StatelessWidget {
  const _PermissionView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.photo_library_outlined,
                size: 48,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Storage access needed',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'ScreenClean needs access to your photos to find and clean up screenshots.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                final container = ProviderScope.containerOf(context);
                container
                    .read(scanControllerProvider.notifier)
                    .initialize();
              },
              icon: const Icon(Icons.lock_open_rounded, size: 18),
              label: const Text('Grant permission'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(200, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Asset grid
// ---------------------------------------------------------------------------

class _AssetGrid extends StatelessWidget {
  const _AssetGrid({
    required this.filter,
    required this.assets,
    required this.selectedAssetIds,
    required this.thumbnailFutureFor,
    required this.onTap,
    required this.onRefresh,
  });

  final AssetFilter filter;
  final List<ScreenshotAsset> assets;
  final Set<String> selectedAssetIds;
  final Future<Uint8List?> Function(String assetId) thumbnailFutureFor;
  final ValueChanged<String> onTap;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (assets.isEmpty) {
      return _EmptyFilterView(filter: filter);
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColors.primary,
      child: GridView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 0.72,
        ),
        itemCount: assets.length,
        itemBuilder: (context, index) {
          final asset = assets[index];
          final selected = selectedAssetIds.contains(asset.id);
          return _AssetTile(
            asset: asset,
            selected: selected,
            thumbnailFuture: thumbnailFutureFor(asset.id),
            onTap: () => onTap(asset.id),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state per filter
// ---------------------------------------------------------------------------

class _EmptyFilterView extends StatelessWidget {
  const _EmptyFilterView({required this.filter});

  final AssetFilter filter;

  @override
  Widget build(BuildContext context) {
    final (icon, title, subtitle) = switch (filter) {
      AssetFilter.all => (
          Icons.photo_library_outlined,
          'No screenshots found',
          'Take some screenshots and scan again.',
        ),
      AssetFilter.old => (
          Icons.access_time_rounded,
          'No old screenshots',
          'All your screenshots are from the last 30 days.',
        ),
      AssetFilter.duplicates => (
          Icons.file_copy_outlined,
          'No duplicates found',
          'No exact duplicate screenshots detected.',
        ),
      AssetFilter.similar => (
          Icons.compare_rounded,
          'No similar screenshots',
          'No visually similar screenshots detected.',
        ),
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.04),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: Colors.black26),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Colors.black38),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Asset tile
// ---------------------------------------------------------------------------

class _AssetTile extends StatelessWidget {
  const _AssetTile({
    required this.asset,
    required this.selected,
    required this.thumbnailFuture,
    required this.onTap,
  });

  final ScreenshotAsset asset;
  final bool selected;
  final Future<Uint8List?> thumbnailFuture;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: Key('asset-tile-${asset.id}'),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? AppColors.primary
                : Colors.black.withValues(alpha: 0.06),
            width: selected ? 2.5 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(10),
                      ),
                      child: asset.thumbnailData != null
                          ? Image.memory(asset.thumbnailData!,
                              fit: BoxFit.cover)
                          : FutureBuilder<Uint8List?>(
                              future: thumbnailFuture,
                              builder: (context, snapshot) {
                                if (snapshot.hasData &&
                                    snapshot.data != null) {
                                  return Image.memory(
                                    snapshot.data!,
                                    fit: BoxFit.cover,
                                  );
                                }
                                return Container(
                                  color: Colors.grey.shade100,
                                  alignment: Alignment.center,
                                  child: Icon(
                                    Icons.image_outlined,
                                    color: Colors.grey.shade300,
                                  ),
                                );
                              },
                            ),
                    ),
                  ),
                  if (selected)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color:
                                  Colors.black.withValues(alpha: 0.2),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(4),
                        child: const Icon(Icons.check_rounded,
                            size: 14, color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 5, 6, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        formatBytes(asset.sizeBytes),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      Text(
                        formatDate(asset.createdAt),
                        style: const TextStyle(
                            fontSize: 10, color: Colors.black45),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  _TagRow(asset: asset),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TagRow extends StatelessWidget {
  const _TagRow({required this.asset});

  final ScreenshotAsset asset;

  @override
  Widget build(BuildContext context) {
    final tags = <Widget>[];
    if (asset.isOld) {
      tags.add(const _Tag(label: 'Old', color: AppColors.orange));
    }
    if (asset.isDuplicateCandidate) {
      tags.add(const _Tag(label: 'Dup', color: AppColors.primary));
    }
    if (asset.isSimilarCandidate) {
      tags.add(const _Tag(label: 'Sim', color: AppColors.teal));
    }

    if (tags.isEmpty) {
      return const SizedBox(height: 14);
    }

    return Wrap(
      spacing: 3,
      runSpacing: 2,
      children: tags,
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 9, color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}
