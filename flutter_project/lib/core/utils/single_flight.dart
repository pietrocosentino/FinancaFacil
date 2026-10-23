/// Impede que uma ação assíncrona seja iniciada novamente enquanto a anterior
/// ainda não terminou, como toques repetidos que abririam a mesma tela duas vezes.
class SingleFlight {
  bool _running = false;

  bool get isRunning => _running;

  /// Executa [action] se nenhuma execução estiver em andamento; caso contrário,
  /// ignora a chamada.
  Future<void> run(Future<void> Function() action) async {
    if (_running) return;
    _running = true;
    try {
      await action();
    } finally {
      _running = false;
    }
  }
}
