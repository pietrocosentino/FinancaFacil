import 'package:flutter/material.dart';

class AsyncPanel<T> extends StatelessWidget {
  const AsyncPanel(
      {super.key,
      required this.future,
      required this.onRetry,
      required this.errorMessage,
      required this.builder});
  final Future<T> future;
  final VoidCallback onRetry;
  final String errorMessage;
  final Widget Function(T data) builder;
  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return EmptyPanel(
              message: errorMessage,
              action: OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Tentar novamente')));
        }
        return builder(snapshot.data as T);
      });
}

class EmptyPanel extends StatelessWidget {
  const EmptyPanel({super.key, required this.message, this.action});
  final String message;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Center(
          child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(message, textAlign: TextAlign.center),
          if (action != null) ...[const SizedBox(height: 12), action!],
        ]),
      ));
}

/// Estado assíncrono dentro de uma única rolagem com filtros e conteúdo.
class AsyncSliverPanel<T> extends StatelessWidget {
  const AsyncSliverPanel({
    super.key,
    required this.future,
    required this.onRetry,
    required this.errorMessage,
    required this.builder,
  });

  final Future<T> future;
  final VoidCallback onRetry;
  final String errorMessage;
  final Widget Function(T data) builder;

  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SliverToBoxAdapter(
              child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator())));
        }
        if (snapshot.hasError) {
          return SliverToBoxAdapter(
              child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(children: [
                    Text(errorMessage, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                        onPressed: onRetry,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Tentar novamente')),
                  ])));
        }
        return builder(snapshot.data as T);
      });
}
