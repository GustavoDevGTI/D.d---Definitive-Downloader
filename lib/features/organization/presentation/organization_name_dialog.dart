import 'dart:async';
import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../domain/collection_organization.dart';
import 'playlist_color_dialog.dart';

class OrganizationNameDialog extends StatefulWidget {
  const OrganizationNameDialog(
      {super.key,
      required this.title,
      required this.name,
      required this.onSave,
      this.groups,
      this.groupId,
      this.playlistColor,
      this.usedPlaylistColors = const {},
      this.maxLength = 160,
      this.onSaveWithLink,
      this.onCancel,
      this.progress,
      this.nameEditable = true});
  final String title, name;
  final int maxLength;
  final bool nameEditable;
  final List<CollectionGroup>? groups;
  final int? groupId;
  final int? playlistColor;
  final Set<int> usedPlaylistColors;
  final Future<String?> Function(String, int?, int?) onSave;
  final Future<String?> Function(String, int?, String)? onSaveWithLink;
  final VoidCallback? onCancel;
  final Widget? progress;
  @override
  State<OrganizationNameDialog> createState() => OrganizationNameDialogState();
}

class OrganizationNameDialogState extends State<OrganizationNameDialog> {
  late final _name = TextEditingController(text: widget.name);
  final _link = TextEditingController();
  late int? _groupId = widget.groupId;
  late int? _playlistColor = widget.playlistColor;
  String? _error;
  bool _saving = false;
  @override
  void dispose() {
    _name.dispose();
    _link.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final error = widget.onSaveWithLink == null
        ? await widget.onSave(_name.text, _groupId, _playlistColor)
        : await widget.onSaveWithLink!(_name.text, _groupId, _link.text);
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

  Future<void> _pickColor() async {
    final color = await showDialog<int>(
        context: context,
        builder: (_) => PlaylistColorDialog(
            initialColor: _playlistColor!,
            usedColors: widget.usedPlaylistColors));
    if (!mounted || color == null) return;
    setState(() {
      _playlistColor = color;
      _error = null;
    });
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
                    if (widget.onSaveWithLink != null) ...[
                      const SizedBox(height: 12),
                      TextField(
                          key: const ValueKey('new-playlist-link'),
                          controller: _link,
                          enabled: !_saving,
                          maxLength: 4096,
                          decoration: const InputDecoration(
                              labelText: 'Link da playlist (opcional)',
                              counterText: ''),
                          onSubmitted: (_) => unawaited(_save())),
                    ],
                    if (_playlistColor != null)
                      ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: PlaylistColorSwatch(rgb: _playlistColor),
                          title: const Text('Cor da playlist'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: _saving ? null : _pickColor),
                    if (widget.groups != null) ...[
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int>(
                          initialValue: _groupId ?? 0,
                          isExpanded: true,
                          menuMaxHeight: 300,
                          decoration: const InputDecoration(labelText: 'Pasta'),
                          items: [
                            const DropdownMenuItem(
                                value: 0, child: Text('Sem pasta')),
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
                    if (_saving && widget.progress != null) ...[
                      const SizedBox(height: 12),
                      widget.progress!,
                    ],
                  ]))),
          actions: [
            TextButton(
                onPressed: _saving
                    ? widget.onCancel
                    : () => Navigator.pop(context, false),
                child: Text(_saving ? 'Interromper' : 'Cancelar')),
            FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Salvando…' : 'Salvar'))
          ]));
}
