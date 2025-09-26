import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/models.dart';
import '../../core/repository.dart';
import '../delivery/edit_delivery_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  final _repo = Repository.instance;
  late Future<List<Delivery>> _future;
  final Map<String, int> _lorryCounts = {};
  late AnimationController _fabAnimationController;
  late Animation<double> _fabAnimation;

  @override
  void initState() {
    super.initState();
    _future = _loadDeliveries();
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fabAnimation = CurvedAnimation(
      parent: _fabAnimationController,
      curve: Curves.easeInOut,
    );
    _fabAnimationController.forward();
  }

  @override
  void dispose() {
    _fabAnimationController.dispose();
    super.dispose();
  }

  Future<List<Delivery>> _loadDeliveries() async {
    final deliveries = await _repo.getDeliveries();
    _lorryCounts.clear();
    for (var d in deliveries) {
      _lorryCounts.update(d.lorryName, (v) => v + 1, ifAbsent: () => 1);
    }
    return deliveries;
  }

  Future<void> _refresh() async {
    setState(() => _future = _loadDeliveries());
  }

  Future<void> _addNew() async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Theme.of(ctx).colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.local_shipping,
                        color: Theme.of(ctx).colorScheme.onSecondaryContainer),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'New Delivery',
                      style: Theme.of(ctx)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: 'Lorry Name',
                  hintText: 'e.g., Supun, Kamal',
                  prefixIcon: const Icon(Icons.drive_eta),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                autofocus: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => Navigator.pop(ctx, true),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: FilledButton.styleFrom(
                      backgroundColor:
                          Theme.of(ctx).colorScheme.secondary, // amber CTA
                      foregroundColor:
                          Theme.of(ctx).colorScheme.onSecondary,
                    ),
                    child: const Text('Create Delivery'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (ok != true) return;
    final name = controller.text.trim();
    if (name.isEmpty) return;

    String finalName = name;
    if (_lorryCounts.containsKey(name)) {
      finalName = '$name ${_lorryCounts[name]! + 1}';
    }

    final id = await _repo.createDelivery(lorryName: finalName);
    if (!mounted) return;

    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => EditDeliveryPage(deliveryId: id)));
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverAppBar.large(
            pinned: true,
            backgroundColor: scheme.primary,
            foregroundColor: scheme.onPrimary,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Dilankara Enterprise'),
                Text(
                  'Wood Logger',
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(color: scheme.onPrimary.withOpacity(0.85)),
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Refresh',
                onPressed: _refresh,
                icon: const Icon(Icons.refresh_rounded),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ],
        body: FutureBuilder<List<Delivery>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator.adaptive());
            }

            final data = snap.data ?? const <Delivery>[];
            if (data.isEmpty) {
              return _buildEmptyState(context);
            }

            return RefreshIndicator.adaptive(
              onRefresh: _refresh,
              child: _buildDeliveryList(context, data),
            );
          },
        ),
      ),
      floatingActionButton: ScaleTransition(
        scale: _fabAnimation,
        child: FloatingActionButton.extended(
          onPressed: _addNew,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add Delivery'),
          elevation: 3,
          backgroundColor: scheme.secondary,      // amber
          foregroundColor: scheme.onSecondary,
        ),
      ),
    );
  }

  /// LIST ONLY (removed “Total Deliveries” and “Recent Deliveries” sections)
  Widget _buildDeliveryList(BuildContext context, List<Delivery> data) {
    return CustomScrollView(
      slivers: [
        // Nice warm header strip with brand—no stats text.
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primaryContainer,
                  Theme.of(context).colorScheme.secondaryContainer,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.15),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.forest_rounded,
                    size: 28, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
                Text(
                  'Deliveries',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),

        // Grid/List responsive layout
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverLayoutBuilder(
            builder: (context, constraints) {
              if (constraints.crossAxisExtent > 600) {
                return SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.2,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => _DeliveryCard(
                      delivery: data[i],
                      onOpen: () => _openDelivery(data[i]),
                      onDelete: () => _deleteDelivery(data[i]),
                      isGridItem: true,
                    ),
                    childCount: data.length,
                  ),
                );
              }
              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _DeliveryCard(
                      delivery: data[i],
                      onOpen: () => _openDelivery(data[i]),
                      onDelete: () => _deleteDelivery(data[i]),
                      isGridItem: false,
                    ),
                  ),
                  childCount: data.length,
                ),
              );
            },
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: scheme.secondaryContainer.withOpacity(0.5),
                shape: BoxShape.circle,
                border: Border.all(color: scheme.secondaryContainer),
              ),
              child: Icon(Icons.local_shipping_rounded,
                  size: 60, color: scheme.secondary),
            ),
            const SizedBox(height: 28),
            Text(
              'No deliveries yet',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Tap the button below to add your first delivery.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: _addNew,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add First Delivery'),
              style: FilledButton.styleFrom(
                backgroundColor: scheme.secondary,
                foregroundColor: scheme.onSecondary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openDelivery(Delivery d) async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => EditDeliveryPage(deliveryId: d.id)));
    await _refresh();
  }

  Future<void> _deleteDelivery(Delivery d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.delete_forever_rounded,
            color: Theme.of(ctx).colorScheme.error),
        title: const Text('Delete Delivery'),
        content: Text(
            'Delete "${d.lorryName}" delivery? This will remove all associated groups and measurements.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.errorContainer,
              foregroundColor: Theme.of(ctx).colorScheme.onErrorContainer,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    // if (ok == true) {
    //   await Repository.instance.deleteDelivery(d.id);
    //   await _refresh();
    // }

    // In _deleteDelivery(...)
if (ok == true) {
  // Optimistic UI: remove locally first (fast), then refresh from DB
  setState(() {
    // optional: remove the card visually by filtering the current future's data
    // we'll still call _refresh() to stay authoritative
  });
  await Repository.instance.deleteDelivery(d.id);
  await _refresh();
}

  }
}

class _DeliveryCard extends StatefulWidget {
  const _DeliveryCard({
    required this.delivery,
    required this.onOpen,
    required this.onDelete,
    required this.isGridItem,
  });

  final Delivery delivery;
  final VoidCallback onOpen;
  final VoidCallback onDelete;
  final bool isGridItem;

  @override
  State<_DeliveryCard> createState() => _DeliveryCardState();
}

class _DeliveryCardState extends State<_DeliveryCard> {
  (int, int)? _counts;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _counts = await Repository.instance.deliveryCounts(widget.delivery.id);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final d = widget.delivery;
    final date = DateFormat('MMM dd, yyyy • HH:mm').format(d.date.toLocal());
    final groups = _counts?.$1 ?? 0;
    final widths = _counts?.$2 ?? 0;

    return Card(
      elevation: 0,
      color: scheme.surface, // harmonized card
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outline.withOpacity(0.15)),
      ),
      child: InkWell(
        onTap: widget.onOpen,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: widget.isGridItem
              ? _buildGridLayout(theme, scheme, d, date, groups, widths)
              : _buildListLayout(theme, scheme, d, date, groups, widths),
        ),
      ),
    );
  }

  Widget _buildListLayout(
      ThemeData theme, ColorScheme scheme, Delivery d, String date, int groups, int widths) {
    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: scheme.secondaryContainer.withOpacity(0.5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(Icons.local_shipping_rounded, color: scheme.secondary, size: 28),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(d.lorryName,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text(date, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  _countChip(icon: Icons.layers_rounded, label: '$groups groups', color: scheme.primary),
                  _countChip(icon: Icons.straighten_rounded, label: '$widths widths', color: scheme.secondary),
                ],
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Delete',
          icon: Icon(Icons.delete_outline_rounded, color: scheme.error),
          onPressed: widget.onDelete,
        ),
      ],
    );
  }

  Widget _buildGridLayout(
      ThemeData theme, ColorScheme scheme, Delivery d, String date, int groups, int widths) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: scheme.secondaryContainer.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.local_shipping_rounded, color: scheme.secondary, size: 20),
            ),
            const Spacer(),
            IconButton(
              tooltip: 'Delete',
              icon: Icon(Icons.delete_outline_rounded, color: scheme.error, size: 20),
              onPressed: widget.onDelete,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(d.lorryName,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            maxLines: 2,
            overflow: TextOverflow.ellipsis),
        const SizedBox(height: 4),
        Text(date, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
        const Spacer(),
        Row(
          children: [
            Expanded(child: _countChip(icon: Icons.layers_rounded, label: '$groups', color: scheme.primary, compact: true)),
            const SizedBox(width: 8),
            Expanded(child: _countChip(icon: Icons.straighten_rounded, label: '$widths', color: scheme.secondary, compact: true)),
          ],
        ),
      ],
    );
  }

  Widget _countChip({
    required IconData icon,
    required String label,
    required Color color,
    bool compact = false,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 12, vertical: compact ? 6 : 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 12 : 14, color: color),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(fontSize: compact ? 11 : 12, color: color, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
