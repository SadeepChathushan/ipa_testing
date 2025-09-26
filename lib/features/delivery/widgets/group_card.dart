import 'package:flutter/material.dart';
import '../../../core/models.dart';
import '../../../core/repository.dart';

class GroupCard extends StatefulWidget {
  const GroupCard({super.key, required this.group, required this.onChanged});
  final WoodGroup group;
  final Future<void> Function() onChanged;

  @override
  State<GroupCard> createState() => _GroupCardState();
}

class _GroupCardState extends State<GroupCard> {
  final _repo = Repository.instance;
  final _widthCtl = TextEditingController(); // accepts comma-separated widths
  List<WoodWidth> _widths = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _widths = await _repo.getWidths(widget.group.id);
    if (mounted) setState(() {});
  }

  Future<void> _addWidths() async {
    final raw = _widthCtl.text.trim();
    if (raw.isEmpty) return;
    final parts = raw.split(RegExp(r'[,\s]+')).where((e) => e.isNotEmpty);
    final values = <double>[];
    for (final p in parts) {
      final v = double.tryParse(p);
      if (v != null) values.add(v);
    }
    await _repo.addWidths(widget.group.id, values);
    _widthCtl.clear();
    await _load();
    await widget.onChanged();
  }

  Future<void> _deleteGroup() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Group'),
        content: const Text('Delete this thickness/length group and its widths?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton.tonal(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      await _repo.deleteGroup(widget.group.id);
      await widget.onChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.group;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('x=${g.thickness}  y=${g.length}', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                IconButton(
                  tooltip: 'Delete group',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: _deleteGroup,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _widths.map((w) => InputChip(
                label: Text(w.width.toString()),
                onDeleted: () async {
                  await _repo.deleteWidth(w.id);
                  await _load();
                  await widget.onChanged();
                },
              )).toList(),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _widthCtl,
                    decoration: const InputDecoration(
                      labelText: 'Add widths (z) — comma or space separated',
                      hintText: 'e.g. 2, 3, 4, 27, 372, 23, 23',
                    ),
                    onSubmitted: (_) => _addWidths(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _addWidths,
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
