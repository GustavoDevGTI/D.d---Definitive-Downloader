import 'dart:async';
import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../domain/collection_organization.dart';

class OrganizationNameDialog extends StatefulWidget {
  const OrganizationNameDialog(
      {super.key,
      required this.title,
      required this.name,
      required this.onSave,
      this.groups,
      this.groupId,
      this.maxLength = 160,
      this.nameEditable = true});
  final String title, name;
  final int maxLength;
  final bool nameEditable;
  final List<CollectionGroup>? groups;
  final int? groupId;
  final Future<String?> Function(String, int?) onSave;
  @override
  State<OrganizationNameDialog> createState() => OrganizationNameDialogState();
}

class OrganizationNameDialogState extends State<OrganizationNameDialog> {
  late final _name = TextEditingController(text: widget.name);
  late int? _groupId = widget.groupId;
  String? _error;
  bool _saving = false;
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final error = await widget.onSave(_name.text, _groupId);
    if (!mounted) return;
    if (error == null) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _saving = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !_saving,
      child: AlertDialog(
          title: Text(widget.title),
          content: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                    if (widget.nameEditable)
                      TextField(
                          key: const ValueKey('organization-name'),
                          controller: _name,
                          autofocus: true,
                          enabled: !_saving,
                          maxLength: widget.maxLength,
                          decoration: const InputDecoration(labelText: 'Nome'),
                          onSubmitted: (_) => unawaited(_save()))
                    else
                      Text(widget.name,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    if (widget.groups != null) ...[
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int>(
                          initialValue: _groupId ?? 0,
                          isExpanded: true,
                          menuMaxHeight: 300,
                          decoration: const InputDecoration(labelText: 'Grupo'),
                          items: [
                            const DropdownMenuItem(
                                value: 0, child: Text('Sem grupo')),
                            for (final g in widget.groups!)
                              DropdownMenuItem(
                                  value: g.id,
                                  child: Text(g.name,
                                      overflow: TextOverflow.ellipsis))
                          ],
                          onChanged: _saving
                              ? null
                              : (v) =>
                                  setState(() => _groupId = v == 0 ? null : v))
                    ],
                    if (_error != null)
                      Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(_error!,
                              style: const TextStyle(
                                  color: AppColors.accentActive))),
                  ]))),
          actions: [
            TextButton(
                onPressed: _saving ? null : () => Navigator.pop(context, false),
                child: const Text('Cancelar')),
            FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Salvando…' : 'Salvar'))
          ]));
}
