 import 'package:local_auth/local_auth.dart';

abstract interface class BiometricAuthenticator {
  Future<bool> get canAuthenticate;
  Future<bool> authenticate(String reason);
}

class DeviceBiometricAuthenticator implements BiometricAuthenticator {
  DeviceBiometricAuthenticator({LocalAuthentication? authentication})
    : _authentication = authentication ?? LocalAuthentication();

  final LocalAuthentication _authentication;

  @override
  Future<bool> get canAuthenticate async =>
      await _authentication.canCheckBiometrics &&
      (await _authentication.getAvailableBiometrics()).isNotEmpty;

  @override
  Future<bool> authenticate(String reason) => _authentication.authenticate(
    localizedReason: reason,
    biometricOnly: false,
    persistAcrossBackgrounding: true,
  );
}
