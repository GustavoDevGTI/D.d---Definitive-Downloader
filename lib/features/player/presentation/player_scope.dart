import 'package:flutter/widgets.dart';
import '../application/music_player_controller.dart';

class PlayerScope extends InheritedWidget {
  const PlayerScope({super.key, required this.player, required super.child});
  final MusicPlayerController? player;
  static MusicPlayerController? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PlayerScope>()?.player;
  @override
  bool updateShouldNotify(PlayerScope oldWidget) => player != oldWidget.player;
}
