import 'package:pacors_core/pacors_core.dart';

abstract interface class SolidAuthProvider implements Auth {
  Future<({String accessToken, String dPoP})> getDpopToken(
      String url, String method);
}
