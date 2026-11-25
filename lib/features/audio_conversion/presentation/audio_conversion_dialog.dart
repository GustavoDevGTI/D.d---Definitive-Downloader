import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/platform/desktop_files.dart';
import '../../library/domain/models.dart';
import '../application/audio_conversion_controller.dart';
import '../application/local_audio_converter.dart';

Future<void> showAudioConversion(
        BuildContext context, Track track, DesktopFiles files) =>
    showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _AudioConversionDialog(track: track, files: files));

class _AudioConversionDialog extends StatefulWidget {
  const _AudioConversionDialog({required this.track, required this.files});
  final Track track;
  final DesktopFiles files;
  @override
  State<_AudioConversionDialog> createState() => _AudioConversionDialogState();
}

class _AudioConversionDialogState extends State<_AudioConversionDialog> {
  late final controller = AudioConversionController(widget.files);
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: controller,
      builder: (context, _) => PopScope(
          canPop: !controller.busy,
          child: AlertDialog(
            title: const Text('Converter para MP3'),
            content: SizedBox(
                width: 400,
                child: SingleChildScrollView(
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                      Text(widget.track.displayTitle),
                      const SizedBox(height: 12),
                      if (controller.savedPath.isEmpty) ...[
                        const Text(
                            'Uma cópia estéreo em MP3. O original e a playlist permanecem intactos.'),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<int>(
                            initialValue: controller.bitrate,
                            decoration:
                                const InputDecoration(labelText: 'Qualidade'),
                            items: [
                              for (final bitrate
                                  in LocalAudioConverter.bitrates)
                                DropdownMenuItem(
                                    value: bitrate,
                                    child: Text('$bitrate kbps'))
                            ],
                            onChanged: controller.busy
                                ? null
                                : (value) {
                                    if (value != null) {
                                      controller.bitrate = value;
                                    }
                                  }),
                      ] else ...[
                        const Text('MP3 salvo'),
                        const SizedBox(height: 8),
                        SelectableText(
                            controller.files.displayPath(controller.savedPath)),
                      ],
                      if (controller.busy) ...[
                        const SizedBox(height: 16),
                        const LinearProgressIndicator(
                            semanticsLabel: 'Convertendo áudio'),
                      ],
                      if (controller.error.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(controller.error,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error)),
                      ],
                    ]))),
            actions: [
              TextButton(
                  onPressed: controller.cancelling
                      ? null
                      : () {
                          if (controller.busy) {
                            controller.cancel();
                          } else {
                            Navigator.pop(context);
                          }
                        },
                  child: Text(controller.savedPath.isNotEmpty
                      ? 'Fechar'
                      : controller.cancelling
                          ? 'Cancelando…'
                          : 'Cancelar')),
              if (controller.savedPath.isEmpty)
                FilledButton(
                    onPressed: controller.busy
                        ? null
                        : () => unawaited(controller.convert(widget.track)),
                    child:
                        Text(controller.busy ? 'Convertendo…' : 'Salvar MP3'))
              else
                FilledButton(
                    onPressed: () => unawaited(controller.revealSaved()),
                    child: const Text('Abrir pasta')),
            ],
          )));
}
