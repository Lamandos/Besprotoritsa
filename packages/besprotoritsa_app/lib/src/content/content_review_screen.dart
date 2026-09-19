import 'dart:convert';

import 'package:besprotoritsa_app/src/content/review_status_store.dart';
import 'package:flutter/material.dart';

/// A localization key and the resolved string shown next to it in the audit.
final class LocalizationBinding {
  /// Creates a localization binding.
  const LocalizationBinding({required this.key, required this.value});

  /// Source key from the content JSON.
  final String key;

  /// Resolved string for the selected locale.
  final String value;
}

/// The normalized data needed to audit one content card or asset.
final class ContentReviewItem {
  /// Creates a review item.
  const ContentReviewItem({
    required this.id,
    required this.title,
    required this.imageAsset,
    required this.jsonFields,
    required this.localizationBindings,
    required this.behaviorId,
    required this.unitTestStatus,
  });

  /// Stable content id used as the key in review_status.json.
  final String id;

  /// Human-readable label for the review list.
  final String title;

  /// Asset path produced by `tool/slice_assets.dart`.
  final String imageAsset;

  /// Parsed JSON fields, kept in their original value shapes.
  final Map<String, Object?> jsonFields;

  /// Localization keys and their resolved Russian strings.
  final List<LocalizationBinding> localizationBindings;

  /// Assigned behavior hook.
  final String? behaviorId;

  /// Result of the content unit-test suite.
  final String unitTestStatus;
}

/// A small, usable fixture for the internal dev menu until generated assets are
/// added to the repository.
const defaultContentReviewItems = <ContentReviewItem>[
  ContentReviewItem(
    id: 'monster.volot',
    title: 'Волот',
    imageAsset: 'assets/images/card-icons/monsters-03-01.webp',
    jsonFields: <String, Object?>{
      'id': 'volot',
      'health': 3,
      'defense': 3,
      'attack': 4,
      'movement': 1,
      'copies': 2,
      'features': <String>['slow', 'strong'],
    },
    localizationBindings: <LocalizationBinding>[
      LocalizationBinding(
        key: 'content.monster.volot.name',
        value: 'Волот',
      ),
      LocalizationBinding(
        key: 'content.monster.volot.description',
        value: 'Медленный, но сильный противник.',
      ),
    ],
    behaviorId: 'monster-standard',
    unitTestStatus: 'Пройдено · monster behavior registry',
  ),
];

/// Internal content audit screen exposed from the development menu.
class ContentReviewScreen extends StatefulWidget {
  /// Creates the content review screen.
  const ContentReviewScreen({
    this.items = defaultContentReviewItems,
    this.statusStore,
    super.key,
  });

  /// Content records to audit.
  final List<ContentReviewItem> items;

  /// Optional store override, primarily useful for widget tests.
  final ReviewStatusStore? statusStore;

  @override
  State<ContentReviewScreen> createState() => _ContentReviewScreenState();
}

class _ContentReviewScreenState extends State<ContentReviewScreen> {
  late final ReviewStatusStore _statusStore;
  final Set<String> _reviewedIds = <String>{};
  var _selectedIndex = 0;
  var _loading = true;
  var _saving = false;

  ContentReviewItem get _selectedItem => widget.items[_selectedIndex];

  @override
  void initState() {
    super.initState();
    _statusStore = widget.statusStore ?? createReviewStatusStore();
    _loadStatuses();
  }

  Future<void> _loadStatuses() async {
    final reviewed = await _statusStore.reviewedIds();
    if (!mounted) return;
    setState(() {
      _reviewedIds
        ..clear()
        ..addAll(reviewed);
      _loading = false;
    });
  }

  Future<void> _markReviewed() async {
    setState(() => _saving = true);
    try {
      await _statusStore.markHumanReviewed(_selectedItem.id);
      if (!mounted) return;
      setState(() => _reviewedIds.add(_selectedItem.id));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Статус записан в content/review_status.json'),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const _EmptyReviewState();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Аудит контента'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text('${_selectedIndex + 1} / ${widget.items.length}'),
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) => constraints.maxWidth >= 860
            ? _wideLayout(constraints)
            : _compactLayout(),
      ),
    );
  }

  Widget _wideLayout(BoxConstraints constraints) => Row(
    children: [
      SizedBox(width: 280, child: _reviewList()),
      const VerticalDivider(width: 1),
      Expanded(child: _reviewWorkspace(constraints.maxWidth - 281)),
    ],
  );

  Widget _compactLayout() => Column(
    children: [
      SizedBox(height: 86, child: _reviewList(horizontal: true)),
      const Divider(height: 1),
      Expanded(child: _reviewWorkspace(0)),
    ],
  );

  Widget _reviewWorkspace(double? availableWidth) => _ReviewWorkspace(
    item: _selectedItem,
    isReviewed: _reviewedIds.contains(_selectedItem.id),
    isLoading: _loading,
    isSaving: _saving,
    availableWidth: availableWidth,
    onMarkReviewed: _markReviewed,
  );

  Widget _reviewList({bool horizontal = false}) => ListView.builder(
    scrollDirection: horizontal ? Axis.horizontal : Axis.vertical,
    padding: const EdgeInsets.all(12),
    itemCount: widget.items.length,
    itemBuilder: (context, index) {
      final item = widget.items[index];
      return SizedBox(
        width: horizontal ? 260 : null,
        child: ListTile(
          selected: index == _selectedIndex,
          leading: Icon(
            _reviewedIds.contains(item.id)
                ? Icons.task_alt
                : Icons.radio_button_unchecked,
            color: _reviewedIds.contains(item.id)
                ? Colors.green
                : Theme.of(context).colorScheme.outline,
          ),
          title: Text(item.title),
          subtitle: Text(item.id),
          onTap: () => setState(() => _selectedIndex = index),
        ),
      );
    },
  );
}

class _ReviewWorkspace extends StatelessWidget {
  const _ReviewWorkspace({
    required this.item,
    required this.isReviewed,
    required this.isLoading,
    required this.isSaving,
    required this.availableWidth,
    required this.onMarkReviewed,
  });

  final ContentReviewItem item;
  final bool isReviewed;
  final bool isLoading;
  final bool isSaving;
  final double? availableWidth;
  final VoidCallback onMarkReviewed;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(20),
    child: availableWidth != null && availableWidth! < 1080
        ? ListView(
            key: const ValueKey<String>('content-review-details'),
            children: _sections(context),
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _AssetPreview(item: item)),
              const SizedBox(width: 24),
              Expanded(
                child: ListView(
                  key: const ValueKey<String>('content-review-details'),
                  children: _sections(context),
                ),
              ),
            ],
          ),
  );

  List<Widget> _sections(BuildContext context) => [
    if (availableWidth != null && availableWidth! < 1080)
      SizedBox(height: 320, child: _AssetPreview(item: item)),
    Text(item.title, style: Theme.of(context).textTheme.headlineSmall),
    const SizedBox(height: 4),
    Text(item.id, style: Theme.of(context).textTheme.bodySmall),
    const SizedBox(height: 16),
    _SectionCard(
      title: 'Поля JSON',
      child: Column(
        children: [
          for (final field in item.jsonFields.entries)
            _KeyValueRow(label: field.key, value: _displayValue(field.value)),
        ],
      ),
    ),
    _SectionCard(
      title: 'Локализация',
      child: Column(
        children: [
          for (final binding in item.localizationBindings)
            _KeyValueRow(label: binding.key, value: binding.value),
        ],
      ),
    ),
    _SectionCard(
      title: 'Поведение и тесты',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatusLine(
            icon: Icons.account_tree,
            label: 'behaviorId',
            value: item.behaviorId ?? 'Не назначен',
          ),
          _StatusLine(
            icon: Icons.rule,
            label: 'Юнит-тест',
            value: item.unitTestStatus,
            positive: item.unitTestStatus.startsWith('Пройдено'),
          ),
        ],
      ),
    ),
    const SizedBox(height: 8),
    FilledButton.icon(
      key: const ValueKey<String>('mark-human-reviewed'),
      onPressed: isSaving ? null : onMarkReviewed,
      icon: isSaving
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.verified),
      label: Text(
        isReviewed ? 'Сверено человеком ✓' : 'Сверено человеком',
      ),
    ),
    if (isLoading)
      const Padding(
        padding: EdgeInsets.only(top: 8),
        child: LinearProgressIndicator(),
      ),
  ];
}

class _AssetPreview extends StatelessWidget {
  const _AssetPreview({required this.item});

  final ContentReviewItem item;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Center(
        child: Image.asset(
          item.imageAsset,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.image_not_supported_outlined, size: 52),
                const SizedBox(height: 12),
                const Text('Ассет ещё не нарезан'),
                const SizedBox(height: 4),
                Text(
                  item.imageAsset,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          child,
        ],
      ),
    ),
  );
}

class _KeyValueRow extends StatelessWidget {
  const _KeyValueRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: SelectableText(
            label,
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(flex: 3, child: SelectableText(value)),
      ],
    ),
  );
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({
    required this.icon,
    required this.label,
    required this.value,
    this.positive = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool positive;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    dense: true,
    leading: Icon(icon, color: positive ? Colors.green : null),
    title: Text(label),
    subtitle: SelectableText(value),
  );
}

class _EmptyReviewState extends StatelessWidget {
  const _EmptyReviewState();

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(child: Text('Нет контента для сверки')),
  );
}

String _displayValue(Object? value) =>
    value is String ? value : jsonEncode(value);
