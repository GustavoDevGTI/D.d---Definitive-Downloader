String safeSegment(String value) {
  var text = value
      .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1f]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  text = text.replaceAll(RegExp(r'[. ]+$'), '');
  if (text.isEmpty) text = 'Sem nome';
  if (RegExp(r'^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])$', caseSensitive: false)
      .hasMatch(text)) {
    text = '_$text';
  }
  return text.length > 65 ? text.substring(0, 65).trim() : text;
}
