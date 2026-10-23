import '../../../core/errors/failure_message.dart';
import '../../../core/files/cloud_files.dart';

String importFailure(Object error) => error is CloudAppNotReady
    ? error.message
    : failureMessage(
        error,
        fallback: 'Não foi possível concluir. Confira a conexão e tente novamente. Nenhum cadastro parcial será feito.',
      );
