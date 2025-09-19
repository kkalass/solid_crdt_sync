// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'solid_auth_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class SolidAuthLocalizationsDe extends SolidAuthLocalizations {
  SolidAuthLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get connectToSolid => 'Mit Solid verbinden';

  @override
  String get syncAcrossDevices => 'Geräteübergreifend synchronisieren';

  @override
  String get chooseProvider => 'Wählen Sie einen Anbieter:';

  @override
  String get orEnterManually => 'Oder geben Sie Ihre WebID manuell ein:';

  @override
  String get webIdHint => 'https://benutzername.anbieter.de/profile/card#me';

  @override
  String get connect => 'Verbinden';

  @override
  String get noPod => 'Haben Sie noch keinen Pod?';

  @override
  String get getPod => 'Pod erhalten';

  @override
  String errorConnectingSolid(String error) {
    return 'Fehler beim Verbinden mit Solid: $error';
  }

  @override
  String get connecting => 'Verbinde...';

  @override
  String get connected => 'Verbunden';

  @override
  String get syncing => 'Synchronisiere...';

  @override
  String get upToDate => 'Auf dem neuesten Stand';

  @override
  String get notConnected => 'Nicht verbunden';

  @override
  String get signOut => 'Abmelden';

  @override
  String get pleaseEnterWebId =>
      'Bitte geben Sie eine WebID ein oder wählen Sie einen Anbieter';

  @override
  String get syncNow => 'Jetzt synchronisieren';

  @override
  String get syncError => 'Synchronisierungsfehler';
}
