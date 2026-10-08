String? validateEmail(String? input) {
  final value = input?.trim() ?? '';
  if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value)) {
    return 'Informe um e-mail válido.';
  }
  return null;
}

String? validateName(String? input) {
  return (input?.trim().length ?? 0) >= 2 ? null : 'Informe seu nome.';
}

String? validatePhone(String? input) {
  final digits = (input ?? '').replaceAll(RegExp(r'\D'), '');
  return digits.length >= 10 && digits.length <= 15
      ? null
      : 'Informe o telefone com DDD.';
}

String? validatePassword(String? input) {
  return (input?.length ?? 0) >= 8 ? null : 'Use pelo menos 8 caracteres.';
}
