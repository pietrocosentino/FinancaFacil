import 'package:financafacil/core/utils/auth_validators.dart';
import 'package:financafacil/features/profile/domain/user_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cadastro valida e-mail, telefone, nome e senha', () {
    expect(validateEmail('pietro@example.com'), isNull);
    expect(validateEmail('sem-arroba'), isNotNull);
    expect(validateEmail('a @b.com'), isNotNull);
    expect(validateName('Pietro Cosentino'), isNull);
    expect(validateName(' '), isNotNull);
    expect(validatePhone('(11) 98459-7523'), isNull);
    expect(validatePhone('123'), isNotNull);
    expect(validatePassword('forte1234'), isNull);
    expect(validatePassword('123'), isNotNull);
  });
  test('perfil mostra metadados reais e suporta contas antigas', () {
    final profile = UserProfileData.fromMetadata('pietro@example.com', {
      'full_name': 'Pietro Cosentino',
      'phone': '(11) 99999-9999',
    });
    expect(profile.name, 'Pietro Cosentino');
    expect(profile.email, 'pietro@example.com');
    expect(profile.phone, '(11) 99999-9999');
    expect(profile.initials, 'PC');
    final legacy = UserProfileData.fromMetadata('pietro@example.com', null);
    expect(legacy.name, 'pietro');
    expect(legacy.phone, isEmpty);
  });
}
