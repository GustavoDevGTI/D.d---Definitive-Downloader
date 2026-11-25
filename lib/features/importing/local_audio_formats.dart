/// Local files only. These extensions are never interpreted as remote URLs.
const localAudioDemuxers = {
  '.mp3': 'mp3',
  '.wav': 'wav',
  '.flac': 'flac',
  '.m4a': 'mov',
  '.aac': 'aac',
  '.ogg': 'ogg',
  '.opus': 'ogg',
  '.wma': 'asf',
  '.aif': 'aiff',
  '.aiff': 'aiff',
  '.ape': 'ape',
  '.wv': 'wv',
};
final localAudioExtensions = Set<String>.unmodifiable(localAudioDemuxers.keys);
const maximumLocalAudioBytes = 2 * 1024 * 1024 * 1024;
const maximumLocalAudioBatchBytes = 10 * 1024 * 1024 * 1024;
