import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../domain/collection_organization.dart';

class CollectionGroupStrip extends StatelessWidget {
  const CollectionGroupStrip(
      {super.key,
      required this.groups,
      required this.selected,
      required this.onSelect,
      this.onRename,
      this.onRemove});
  final List<CollectionGroup> groups;
  final int? selected;
  final ValueChanged<int?> onSelect;
  final VoidCallback? onRename, onRemove;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
              child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    _tab('Todas', null),
                    _tab('Sem pasta', 0),
                    for (final g in groups)
                      _tab('${g.name} (${g.count})', g.id),
                  ]))),
          if (selected != null && selected! > 0) ...[
            IconButton(
                tooltip: 'Renomear pasta',
                onPressed: onRename,
                icon: const Icon(Icons.edit_outlined, size: 18)),
            IconButton(
                tooltip: 'Remover pasta',
                onPressed: onRemove,
                icon: const Icon(Icons.folder_delete_outlined, size: 19)),
          ]
        ]),
        const Divider(height: 1),
      ]);
  Widget _tab(String text, int? id) => DecoratedBox(
      decoration: BoxDecoration(
          border: Border(
              bottom: BorderSide(
                  width: 2,
                  color: selected == id
                      ? AppColors.accentActive
                      : Colors.transparent))),
      child: TextButton(
          key: ValueKey('group-tab-${id ?? 'all'}'),
          onPressed: () => onSelect(id),
          style: TextButton.styleFrom(
              foregroundColor:
                  selected == id ? AppColors.accentActive : AppColors.muted,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: const RoundedRectangleBorder()),
          child: Text(text,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight:
                      selected == id ? FontWeight.w700 : FontWeight.w500))));
}
