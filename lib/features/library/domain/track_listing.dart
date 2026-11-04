enum TrackSort { position, name, duration, correspondence }

String foldTrackText(String value) {
  var text = value.toLowerCase();
  const replacements = {
    'a': '[áàâãäå]',
    'e': '[éèêë]',
    'i': '[íìîï]',
    'o': '[óòôõö]',
    'u': '[úùûü]',
    'c': '[ç]',
    'n': '[ñ]',
  };
  for (final entry in replacements.entries) {
    text = text.replaceAll(RegExp(entry.value), entry.key);
  }
  return text;
}
