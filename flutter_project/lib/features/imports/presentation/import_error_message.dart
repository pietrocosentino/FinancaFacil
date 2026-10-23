import '../../../core/errors/failure_message.dart';

String importFailure(Object error) => failureMessage(
  error,
  fallback: 'Não foi possível concluir. Confira a conexão e tente novamente. Nenhum cadastro parcial será feito.',
);
