import 'package:flutter/material.dart';
import '../../../app/theme.dart';

class CategoryTabs extends StatelessWidget {
  const CategoryTabs(
      {super.key,
      required this.labels,
      required this.selected,
      required this.onSelect});
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelect;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Align(
                alignment: Alignment.centerLeft,
                child: Wrap(spacing: 6, runSpacing: 6, children: [
                  for (var i = 0; i < labels.length; i++)
                    OutlinedButton(
                        style: OutlinedButton.styleFrom(
                            backgroundColor: i == selected
                                ? AppColors.accentSoft
                                : Colors.white,
                            side: BorderSide(
                                color: i == selected
                                    ? AppColors.accentSoft
                                    : Colors.transparent),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            foregroundColor: i == selected
                                ? AppColors.accentActive
                                : AppColors.muted,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10)),
                        onPressed: () => onSelect(i),
                        child: Text(labels[i],
                            style: TextStyle(
                                fontWeight: i == selected
                                    ? FontWeight.w600
                                    : FontWeight.w400))),
                ]))),
        const Divider(height: 1),
        const SizedBox(height: 20)
      ]);
}

class WorkspaceNavigationButton extends StatelessWidget {
  const WorkspaceNavigationButton(
      {super.key,
      required this.title,
      required this.subtitle,
      required this.icon,
      required this.onPressed});
  final String title, subtitle;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    bool highlighted(Set<WidgetState> states) => states.any((state) => const {
          WidgetState.hovered,
          WidgetState.focused,
          WidgetState.pressed,
        }.contains(state));
    return OutlinedButton(
        style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(68),
                alignment: Alignment.centerLeft,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)))
            .copyWith(
                backgroundColor: WidgetStateProperty.resolveWith((states) => highlighted(states)
                    ? AppColors.accentActive
                    : AppColors.accentSoft),
                foregroundColor: WidgetStateProperty.resolveWith((states) =>
                    highlighted(states) ? Colors.white : AppColors.ink),
                iconColor: WidgetStateProperty.resolveWith((states) =>
                    highlighted(states) ? Colors.white : AppColors.accent),
                side: WidgetStateProperty.resolveWith(
                    (states) => BorderSide(color: highlighted(states) ? AppColors.accentActive : AppColors.accent)),
                overlayColor: const WidgetStatePropertyAll(Colors.transparent)),
        onPressed: onPressed,
        child: Row(children: [
          Icon(icon, size: 24),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Opacity(
                    opacity: .8,
                    child: Text(subtitle,
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w500))),
              ])),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right_rounded, size: 22),
        ]));
  }
}

class WorkspacePanel extends StatelessWidget {
  const WorkspacePanel(
      {super.key, required this.child, this.padding = EdgeInsets.zero});
  final Widget child;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => Material(
      clipBehavior: Clip.antiAlias,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
          side: const BorderSide(color: AppColors.line),
          borderRadius: BorderRadius.circular(12)),
      child: Padding(padding: padding, child: child));
}

class PageControls extends StatelessWidget {
  const PageControls(
      {super.key,
      required this.offset,
      required this.count,
      required this.total,
      required this.onPage,
      this.label = 'itens',
      this.showDivider = true});
  final int offset, count, total;
  final String label;
  final bool showDivider;
  final ValueChanged<int> onPage;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: showDivider
          ? const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.line)))
          : null,
      child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        Flexible(
            child: Text(
                total == 0
                    ? '0 $label'
                    : '${offset + 1}–${offset + count} de $total',
                style: const TextStyle(fontSize: 11, color: AppColors.muted))),
        IconButton(
            tooltip: 'Página anterior',
            onPressed: offset > 0 ? () => onPage(-1) : null,
            icon: const Icon(Icons.chevron_left)),
        IconButton(
            tooltip: 'Próxima página',
            onPressed: offset + count < total ? () => onPage(1) : null,
            icon: const Icon(Icons.chevron_right)),
      ]));
}

class WorkspaceNotice extends StatelessWidget {
  const WorkspaceNotice(
      {super.key, required this.title, required this.message, this.action});
  final String title, message;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Center(
      child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    Text(message,
                        style: const TextStyle(
                            height: 1.7, color: AppColors.muted)),
                    if (action != null)
                      Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: action),
                  ]))));
}
