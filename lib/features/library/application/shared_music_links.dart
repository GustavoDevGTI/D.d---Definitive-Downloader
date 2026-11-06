/// Sharesheets often append a title around a public URL. Keep only the links;
/// the existing import domain still validates every scheme, host and source.
String sharedMusicLinks(String text) {
  final links = RegExp(r'''https://[^\s<>"']+''', caseSensitive: false)
      .allMatches(text)
      .map((match) => match[0]!.replaceFirst(RegExp(r'[),.;]+$'), ''));
  return links.isEmpty ? text : links.join('\n');
}
