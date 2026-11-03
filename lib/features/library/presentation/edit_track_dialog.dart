import 'package:flutter/material.dart';
import '../application/library_controller.dart';
import '../domain/models.dart';
import '../../importing/music_link.dart';

Future<void> showEditTrack(
        BuildContext context, LibraryController controller, Track track) =>
    showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => EditTrackDialog(controller: controller, track: track));

class EditTrackDialog extends StatefulWidget {
  const EditTrackDialog(
      {super.key, required this.controller, required this.track});
  final LibraryController controller;
  final Track track;
  @override
  State<EditTrackDialog> createState() => _EditTrackDialogState();
}

class _EditTrackDialogState extends State<EditTrackDialog> {
  late final _name = TextEditingController(text: widget.track.displayTitle);
  late final _position =
      TextEditingController(text: '${widget.track.position}');
  late final String _originalLink = widget.track.manualUrl.isNotEmpty
      ? widget.track.manualUrl
      : widget.track.sourceUrl.isNotEmpty
          ? widget.track.sourceUrl
          : widget.track.mediaUrl.startsWith('asset:')
              ? ''
              : widget.track.mediaUrl;
  late final _link = TextEditingController(text: _originalLink);
  late MusicLinkKind _platform = _initialPlatform();
  final _form = GlobalKey<FormState>();
  bool _saving = false;
  String _error = '';
  MusicLinkKind _initialPlatform() {
    try {
      return MusicLink.parse(_originalLink).kind;
    } on FormatException {
      return MusicLinkKind.mp3;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _position.dispose();
    _link.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate() || _saving) return;
    setState(() {
      _saving = true;
      _error = '';
    });
    final saved = await widget.controller.editTrack(widget.track,
        name: _name.text,
        position: int.parse(_position.text),
        sourceInput:
            _link.text.trim() == _originalLink.trim() ? null : _link.text,
        platform: _platform);
    if (!mounted) return;
    if (saved) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _saving = false;
      _error = widget.controller.message;
    });
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !_saving,
      child: AlertDialog(
          title: const Text('Editar faixa'),
          content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                  child: Form(
                      key: _form,
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextFormField(
                                key: const ValueKey('edit-track-name'),
                                controller: _name,
                                enabled: !_saving,
                                maxLength: 400,
                                decoration: const InputDecoration(
                                    labelText: 'Nome', counterText: ''),
                                validator: (value) =>
                                    value == null || value.trim().isEmpty
                                        ? 'Informe um nome.'
                                        : null),
                            const SizedBox(height: 14),
                            TextFormField(
                                key: const ValueKey('edit-track-position'),
                                controller: _position,
                                enabled: !_saving,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                    labelText: 'Posição / número'),
                                validator: (value) {
                                  final n = int.tryParse(value ?? '');
                                  return n == null ||
                                          n < 1 ||
                                          n >
                                              (widget.controller.current
                                                      ?.trackCount ??
                                                  0)
                                      ? 'Posição fora da coleção.'
                                      : null;
                                }),
                            const SizedBox(height: 14),
                            DropdownButtonFormField<MusicLinkKind>(
                                initialValue: _platform,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                    labelText: 'Plataforma do link / ID'),
                                items: [
                                  for (final kind in MusicLinkKind.values)
                                    DropdownMenuItem(
                                        value: kind,
                                        child: Text(switch (kind) {
                                          MusicLinkKind.spotify => 'Spotify',
                                          MusicLinkKind.deezer => 'Deezer',
                                          MusicLinkKind.youtubeMusic =>
                                            'YouTube Music',
                                          MusicLinkKind.youtube => 'YouTube',
                                          MusicLinkKind.mp3 => 'MP3 direto'
                                        }))
                                ],
                                onChanged: _saving
                                    ? null
                                    : (value) =>
                                        setState(() => _platform = value!)),
                            const SizedBox(height: 14),
                            TextFormField(
                                key: const ValueKey('edit-track-source'),
                                controller: _link,
                                enabled: !_saving,
                                maxLength: 4096,
                                decoration: const InputDecoration(
                                    labelText: 'Link ou ID da faixa',
                                    counterText: '')),
                            if (_saving)
                              const Padding(
                                  padding: EdgeInsets.only(top: 16),
                                  child: LinearProgressIndicator(minHeight: 2)),
                            if (_error.isNotEmpty)
                              Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Text(_error)),
                          ])))),
          actions: [
            TextButton(
                onPressed: _saving ? null : () => Navigator.pop(context),
                child: const Text('Cancelar')),
            FilledButton(
                onPressed: _saving ? null : _save,
                child: const Text('Salvar alterações')),
          ]));
}
