/// A claimed occurrence keeps its position even after failure, stop or restart.
bool trackOrderLocked(
        {required String status,
        String run = '',
        String localPath = '',
        String error = ''}) =>
    run.isNotEmpty ||
    localPath.isNotEmpty ||
    const ['downloading', 'completed', 'failed'].contains(status) ||
    error.startsWith('Transferência interrompida') ||
    error.startsWith('Interrompido.');
