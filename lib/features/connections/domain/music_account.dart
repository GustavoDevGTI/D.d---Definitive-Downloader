enum MusicAccount {
  spotify('Spotify'),
  deezer('Deezer');

  const MusicAccount(this.label);
  final String label;
}

class MusicAccountRequired extends FormatException {
  const MusicAccountRequired(this.account)
      : super('Conecte sua conta para continuar.');
  final MusicAccount account;
}
