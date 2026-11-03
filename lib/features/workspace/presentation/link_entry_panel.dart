import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import 'workspace_components.dart';

class LinkEntryPanel extends StatelessWidget {
  const LinkEntryPanel({
    super.key,
    required this.title,
    required this.fieldLabel,
    required this.hintText,
    required this.controller,
    required this.inputKey,
    required this.actionLabel,
    required this.actionIcon,
    required this.onAction,
    this.actionKey,
    this.focusNode,
    this.enabled = true,
    this.onSubmitted,
    this.secondaryActions = const [],
    this.status,
  });

  final String title, fieldLabel, hintText, actionLabel;
  final String? status;
  final TextEditingController controller;
  final FocusNode? focusNode;
  final Key inputKey;
  final Key? actionKey;
  final IconData actionIcon;
  final bool enabled;
  final VoidCallback? onAction;
  final ValueChanged<String>? onSubmitted;
  final List<Widget> secondaryActions;

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        WorkspacePanel(
            padding: const EdgeInsets.all(16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                      key: inputKey,
                      controller: controller,
                      focusNode: focusNode,
                      enabled: enabled,
                      keyboardType: TextInputType.url,
                      textInputAction: TextInputAction.done,
                      style:
                          const TextStyle(fontSize: 13, color: AppColors.ink),
                      decoration: InputDecoration(
                          labelText: fieldLabel,
                          labelStyle: const TextStyle(
                              fontSize: 13, color: AppColors.muted),
                          hintText: hintText),
                      onSubmitted: onSubmitted),
                  const SizedBox(height: 12),
                  OutlinedButtonTheme(
                      data: OutlinedButtonThemeData(
                          style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 48),
                              visualDensity: VisualDensity.standard,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              foregroundColor: AppColors.ink,
                              side: const BorderSide(color: AppColors.line),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              textStyle: const TextStyle(
                                  fontFamily: 'Manrope',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600))),
                      child: IconButtonTheme(
                          data: IconButtonThemeData(
                              style: IconButton.styleFrom(
                                  minimumSize: const Size(48, 48),
                                  visualDensity: VisualDensity.standard,
                                  foregroundColor: AppColors.secondary)),
                          child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                FilledButton.icon(
                                    key: actionKey,
                                    style: FilledButton.styleFrom(
                                        minimumSize: const Size(0, 48),
                                        visualDensity: VisualDensity.standard,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 12)),
                                    onPressed: onAction,
                                    icon: Icon(actionIcon, size: 18),
                                    label: Text(actionLabel)),
                                ...secondaryActions,
                              ]))),
                ])),
        if (status != null) ...[
          const SizedBox(height: 10),
          Text(status!,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.muted, height: 1.6)),
        ],
      ]);
}
