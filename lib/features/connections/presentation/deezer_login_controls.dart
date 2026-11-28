import '../../../core/web/password_login_only.dart';

/// The Deezer page keeps only the email/password flow supported by the app.
const deezerLoginControlInstaller = socialSignInBlocker;

final deezerLoginControls = passwordLoginOnly(['deezer.com']);
