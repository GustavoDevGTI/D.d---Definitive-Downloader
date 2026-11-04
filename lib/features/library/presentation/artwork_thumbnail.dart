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
      this.icon = Icons.music_note_rounded});
  final String reference, audioPath;
  final double size;
  final IconData icon;
  @override
  State<ArtworkThumbnail> createState() => _ArtworkThumbnailState();
}

class _ArtworkThumbnailState extends State<ArtworkThumbnail> {
  late Future<Uint8List?> _image;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _image =
        ArtworkStore.shared.load(widget.reference, audioPath: widget.audioPath);
  }

  @override
  void didUpdateWidget(ArtworkThumbnail old) {
    super.didUpdateWidget(old);
    if (old.reference != widget.reference ||
        old.audioPath != widget.audioPath) {
      _load();
    }
  }

  @override
  Widget build(BuildContext context) => ClipRRect(
      borderRadius: BorderRadius.circular(5),
      child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: FutureBuilder<Uint8List?>(
              future: _image,
              builder: (context, snapshot) {
                final data = snapshot.data;
                return data == null
                    ? ColoredBox(
                        color: AppColors.accentSoft,
                        child: Icon(widget.icon,
                            color: AppColors.accentActive,
                            size: widget.size * .46))
                    : Image.memory(data,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                        excludeFromSemantics: true);
              })));
}
