import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';

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
    setState(() {
      if (_selectedAssetIds.contains(id)) {
        _selectedAssetIds.remove(id);
      } else {
        _selectedAssetIds.add(id);
      }
    });
  }

  void _selectAllVisible(List<ScreenshotAsset> visibleAssets) {
    setState(() {
      _selectedAssetIds.addAll(visibleAssets.map((asset) => asset.id));
    });
  }

  void _clearSelection() {
    setState(_selectedAssetIds.clear);
  }

  Future<void> _confirmAndDelete(List<ScreenshotAsset> selectedAssets) async {
    final selectedCount = selectedAssets.length;
    final selectedBytes = _selectedBytes(selectedAssets);
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete screenshots?'),
          content: Text(
            'Delete $selectedCount screenshots and free ${formatBytes(selectedBytes)}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true || !mounted) {
      return;
    }

    final result =
        await ref.read(cleanupControllerProvider.notifier).deleteSelected(selectedAssets);
    if (!mounted || result == null) {
      return;
    }

    if (result.deletedCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Deleted ${result.deletedCount} screenshots and reclaimed ${formatBytes(result.reclaimedBytes)}.',
          ),
        ),
      );
    }

    if (result.failedIds.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not delete ${result.failedIds.length} screenshots.'),
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('ScreenClean'),
        actions: [
          IconButton(
            tooltip: 'Scan',
            onPressed: scanState.isLoading
                ? null
                : () => ref.read(scanControllerProvider.notifier).rescan(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      bottomNavigationBar: selectedAssets.isEmpty
          ? const AdBannerSlot()
          : SafeArea(
              minimum: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      key: const Key('delete-selected-button'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.error,
                      ),
                      onPressed: cleanupState.isDeleting
                          ? null
                          : () => _confirmAndDelete(selectedAssets),
                      icon: cleanupState.isDeleting
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.delete_outline_rounded),
                      label: Text(
                        'Delete ${selectedAssets.length} (${formatBytes(_selectedBytes(selectedAssets))})',
                      ),
                    ),
                  ),
                ],
              ),
            ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              const Text(
                'Reclaim your space in seconds.',
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),
              const SizedBox(height: 12),
              _SummarySection(report: scanState.report),
              const SizedBox(height: 12),
              _FilterBar(
                currentFilter: _currentFilter,
                visibleCount: visibleAssets.length,
                onFilterChanged: (filter) {
                  _applyFilter(filter, allAssets);
                },
                onSelectAll: () => _selectAllVisible(visibleAssets),
              ),
              if (scanState.errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  scanState.errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 10),
              if (!scanState.hasPermission)
                Expanded(
                  child: _PermissionView(
                    onRetry: () => ref.read(scanControllerProvider.notifier).initialize(),
                  ),
                )
              else if (scanState.isLoading && scanState.report.totalCount == 0)
                const Expanded(child: Center(child: CircularProgressIndicator()))
              else
                Expanded(
                  child: _AssetGrid(
                    assets: visibleAssets,
                    selectedAssetIds: _selectedAssetIds,
                    thumbnailFutureFor: _thumbnailFutureFor,
                    onTap: _toggleAssetSelection,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummarySection extends StatelessWidget {
  const _SummarySection({required this.report});

  final ScanReport report;

  @override
  Widget build(BuildContext context) {
    final reclaimableBytes = report.assets
        .where(
          (asset) =>
              asset.isOld || asset.isDuplicateCandidate || asset.isSimilarCandidate,
        )
        .fold<int>(0, (sum, asset) => sum + asset.sizeBytes);
    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            label: 'Screenshots',
            value: '${report.totalCount}',
            keyValue: const Key('summary-total-count'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SummaryCard(
            label: 'Total',
            value: formatBytes(report.totalBytes),
            keyValue: const Key('summary-total-bytes'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SummaryCard(
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
    required this.label,
    required this.value,
    required this.keyValue,
  });

  final String label;
  final String value;
  final Key keyValue;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              key: keyValue,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.currentFilter,
    required this.visibleCount,
    required this.onFilterChanged,
    required this.onSelectAll,
  });

  final AssetFilter currentFilter;
  final int visibleCount;
  final ValueChanged<AssetFilter> onFilterChanged;
  final VoidCallback onSelectAll;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          ChoiceChip(
            key: const Key('filter-all'),
            label: const Text('All'),
            selected: currentFilter == AssetFilter.all,
            onSelected: (_) => onFilterChanged(AssetFilter.all),
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            key: const Key('filter-old'),
            selectedColor: Colors.orange.shade100,
            labelStyle: TextStyle(
              color: currentFilter == AssetFilter.old
                  ? Colors.deepOrange
                  : Colors.black87,
            ),
            label: const Text('Old (30+ days)'),
            selected: currentFilter == AssetFilter.old,
            onSelected: (_) => onFilterChanged(AssetFilter.old),
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            key: const Key('filter-duplicates'),
            label: const Text('Duplicates'),
            selected: currentFilter == AssetFilter.duplicates,
            onSelected: (_) => onFilterChanged(AssetFilter.duplicates),
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            key: const Key('filter-similar'),
            selectedColor: const Color(0xFFD8F3EE),
            labelStyle: TextStyle(
              color: currentFilter == AssetFilter.similar
                  ? const Color(0xFF0E8070)
                  : Colors.black87,
            ),
            label: const Text('Similar'),
            selected: currentFilter == AssetFilter.similar,
            onSelected: (_) => onFilterChanged(AssetFilter.similar),
          ),
          const SizedBox(width: 8),
          ActionChip(
            key: const Key('select-all-button'),
            avatar: const Icon(Icons.done_all_rounded, size: 18),
            label: const Text('Select all'),
            onPressed: visibleCount == 0 ? null : onSelectAll,
          ),
        ],
      ),
    );
  }
}

class _PermissionView extends StatelessWidget {
  const _PermissionView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Storage permission is required to scan screenshots.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: onRetry,
            child: const Text('Grant permission'),
          ),
        ],
      ),
    );
  }
}

class _AssetGrid extends StatelessWidget {
  const _AssetGrid({
    required this.assets,
    required this.selectedAssetIds,
    required this.thumbnailFutureFor,
    required this.onTap,
  });

  final List<ScreenshotAsset> assets;
  final Set<String> selectedAssetIds;
  final Future<Uint8List?> Function(String assetId) thumbnailFutureFor;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    if (assets.isEmpty) {
      return const Center(
        child: Text('No screenshots found for this filter.'),
      );
    }

    return GridView.builder(
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
    );
  }
}

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
    return InkWell(
      key: Key('asset-tile-${asset.id}'),
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Colors.black12,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(10)),
                      child: asset.thumbnailData != null
                          ? Image.memory(asset.thumbnailData!, fit: BoxFit.cover)
                          : FutureBuilder<Uint8List?>(
                              future: thumbnailFuture,
                              builder: (context, snapshot) {
                                if (snapshot.hasData && snapshot.data != null) {
                                  return Image.memory(
                                    snapshot.data!,
                                    fit: BoxFit.cover,
                                  );
                                }
                                return Container(
                                  color: Colors.black12,
                                  alignment: Alignment.center,
                                  child: const Icon(Icons.image_outlined),
                                );
                              },
                            ),
                    ),
                  ),
                  if (selected)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: CircleAvatar(
                        radius: 10,
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        child: const Icon(Icons.check, size: 14, color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 6, 6, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formatBytes(asset.sizeBytes),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    formatDate(asset.createdAt),
                    style: const TextStyle(fontSize: 10, color: Colors.black54),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 4,
                    runSpacing: 2,
                    children: [
                      if (asset.isOld)
                        const _Tag(
                          label: 'Old',
                          color: Color(0xFFFF9500),
                        ),
                      if (asset.isDuplicateCandidate)
                        const _Tag(
                          label: 'Duplicate',
                          color: Color(0xFF007AFF),
                        ),
                      if (asset.isSimilarCandidate)
                        const _Tag(
                          label: 'Similar',
                          color: Color(0xFF0AA58C),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}
