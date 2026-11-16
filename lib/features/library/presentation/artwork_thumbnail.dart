import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../data/artwork_store.dart';

class ArtworkThumbnail extends StatefulWidget {
  const ArtworkThumbnail(
      {super.key,
      this.reference = '',
      this.audioPath = '',
      this.size = 44,
      this.store,
      this.borderColor,
      this.placeholderColor = AppColors.accentSoft,
      this.icon = Icons.music_note_rounded});
  final String reference, audioPath;
  final double size;
  final IconData icon;
  final Color? borderColor;
  final Color placeholderColor;
  final ArtworkStore? store;
  @override
  State<ArtworkThumbnail> createState() => _ArtworkThumbnailState();
}

class _ArtworkThumbnailState extends State<ArtworkThumbnail> {
  Future<Uint8List?>? _image;
  Uint8List? _data;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final generation = ++_generation;
    final store = widget.store ?? ArtworkStore.shared;
    _data = store.cached(widget.reference, audioPath: widget.audioPath);
    _image =
        store.load(widget.reference, audioPath: widget.audioPath).then((data) {
      if (mounted && generation == _generation) _data = data;
      return data;
    });
  }

  @override
  void didUpdateWidget(ArtworkThumbnail old) {
    super.didUpdateWidget(old);
    if (old.reference != widget.reference ||
        old.audioPath != widget.audioPath ||
        old.store != widget.store ||
        _data == null) {
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(5);
    final borderColor = widget.borderColor;
    final thumbnail = ClipRRect(
        borderRadius: radius,
        child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: FutureBuilder<Uint8List?>(
                key: ValueKey((widget.reference, widget.audioPath)),
                future: _image,
                initialData: _data,
                builder: (context, snapshot) {
                  final data = snapshot.data;
                  return data == null
                      ? ColoredBox(
                          color: widget.placeholderColor,
                          child: Icon(widget.icon,
                              color: AppColors.accentActive,
                              size: widget.size * .46))
                      : Image.memory(data,
                          key: ValueKey((widget.reference, widget.audioPath)),
                          fit: BoxFit.cover,
                          gaplessPlayback: false,
                          excludeFromSemantics: true);
                })));
    if (borderColor == null) return thumbnail;
    return DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
            borderRadius: radius, border: Border.all(color: borderColor)),
        child: thumbnail);
  }
}
