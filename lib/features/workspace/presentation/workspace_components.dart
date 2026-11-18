import 'package:flutter/material.dart';
import '../../../app/theme.dart';

class CategoryTabs extends StatelessWidget {
  const CategoryTabs(
      {super.key,
      required this.labels,
      required this.selected,
      required this.onSelect,
      this.onBack,
      this.accent,
      this.showDivider = true,
      this.bottomSpacing = 20});
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelect;
  final VoidCallback? onBack;
  final double bottomSpacing;
  final bool showDivider;
  final Color? accent;
  @override
  Widget build(BuildContext context) {
    final color = accent;
    final selectedSurface = color == null
        ? AppColors.accentSoft
        : Color.alphaBlend(color.withAlpha(40), Colors.white);
    Widget tab(int i) => OutlinedButton(
        style: OutlinedButton.styleFrom(
            backgroundColor: i == selected ? selectedSurface : Colors.white,
            side: BorderSide(
                color: i == selected
                    ? color ?? selectedSurface
                    : Colors.transparent),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            foregroundColor: i == selected
                ? color == null
                    ? AppColors.accentActive
                    : AppColors.ink
                : AppColors.muted,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
        onPressed: () => onSelect(i),
        child: Text(labels[i],
            style: TextStyle(
                fontWeight:
                    i == selected ? FontWeight.w600 : FontWeight.w400)));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
          padding: EdgeInsets.only(
              bottom: !showDivider || MediaQuery.sizeOf(context).height < 500
                  ? 0
                  : MediaQuery.sizeOf(context).shortestSide < 600
                      ? 8
                      : 16),
          child: Align(
              alignment: Alignment.centerLeft,
              child: Wrap(spacing: 6, runSpacing: 6, children: [
                for (var i = 0; i < labels.length; i++)
                  if (i == 0 && onBack != null)
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(
                          tooltip: 'Voltar às coleções',
                          onPressed: onBack,
                          icon: const Icon(Icons.arrow_back, size: 18)),
                      tab(i),
                    ])
                  else
                    tab(i),
              ]))),
      if (showDivider) const Divider(height: 1),
      SizedBox(
          height: MediaQuery.sizeOf(context).height < 500
              ? bottomSpacing.clamp(0, 4)
              : MediaQuery.sizeOf(context).shortestSide < 600
                  ? bottomSpacing.clamp(0, 8)
                  : bottomSpacing)
    ]);
  }
}

class WorkspaceNavigationButton extends StatelessWidget {
  const WorkspaceNavigationButton(
      {super.key,
      required this.title,
      required this.subtitle,
      required this.icon,
      required this.onPressed,
      this.leading,
      this.accent});
  final String title, subtitle;
  final IconData icon;
  final Widget? leading;
  final Color? accent;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final color = accent ?? AppColors.accent;
    final surface = accent == null
        ? AppColors.accentSoft
        : Color.alphaBlend(color.withAlpha(30), Colors.white);
    final active = accent == null
        ? AppColors.accentActive
        : Color.alphaBlend(color.withAlpha(64), Colors.white);
    final activeInk = accent == null ? Colors.white : AppColors.ink;
    final iconInk = accent == null ? color : AppColors.ink;
    final border =
        accent == null ? color : Color.alphaBlend(Colors.black26, color);
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
                backgroundColor: WidgetStateProperty.resolveWith(
                    (states) => highlighted(states) ? active : surface),
                foregroundColor: WidgetStateProperty.resolveWith((states) =>
                    highlighted(states) ? activeInk : AppColors.ink),
                iconColor: WidgetStateProperty.resolveWith(
                    (states) => highlighted(states) ? activeInk : iconInk),
                side: WidgetStateProperty.resolveWith((states) =>
                    BorderSide(color: highlighted(states) && accent == null ? active : border)),
                overlayColor: const WidgetStatePropertyAll(Colors.transparent)),
        onPressed: onPressed,
        child: Row(children: [
          leading ?? Icon(icon, size: 24),
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
      {super.key,
      required this.child,
      this.padding = EdgeInsets.zero,
      this.borderColor = AppColors.line,
      this.color = AppColors.surface});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color borderColor, color;
  @override
  Widget build(BuildContext context) => Material(
      clipBehavior: Clip.antiAlias,
      color: color,
      shape: RoundedRectangleBorder(
          side: BorderSide(color: borderColor),
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
