import 'package:flutter/material.dart';

import '../../../../core/errors/app_log.dart';
import '../../../../core/errors/failure_message.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/async_panel.dart';
import '../../../../shared/widgets/confirm_dialog.dart';
import '../../data/finance_repository.dart';
import '../../domain/finance_models.dart';

class RecurrenceRulesScreen extends StatefulWidget {
  const RecurrenceRulesScreen({super.key, required this.repository});
  final FinanceRepository repository;
  @override
  State<RecurrenceRulesScreen> createState() => _RecurrenceRulesScreenState();
}

class _RecurrenceRulesScreenState extends State<RecurrenceRulesScreen> {
  late final FinanceRepository _repository;
  late Future<List<RecurrencePlan>> _future;
  String? _busyId;
  @override
  void initState() {
    super.initState();
    _repository = widget.repository;
    _future = _repository.plans();
  }

  void _reload() => setState(() {
    _future = _repository.plans();
  });

  Future<void> _stop(RecurrencePlan plan) async {
    if (_busyId != null) return;
    final confirmed = await showConfirmDialog(
      context,
      title: 'Encerrar recorrência?',
      message: 'A regra termina no fim deste mês. As previsões seguintes serão removidas da consulta. O histórico de pagamentos será preservado.',
      confirmLabel: 'Encerrar',
    );
    if (!confirmed || !mounted) return;
    setState(() => _busyId = plan.id);
    try {
      await _repository.stopPlan(plan.id);
      if (mounted) _reload();
    } catch (error, stack) {
      AppLog.error(error, stack, 'encerrar recorrência');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              failureMessage(
                error,
                fallback: 'Não foi possível encerrar. Tente novamente.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Lançamentos recorrentes'),
      actions: [
        IconButton(
          onPressed: _busyId == null ? _reload : null,
          icon: const Icon(Icons.refresh),
          tooltip: 'Recarregar',
        ),
      ],
    ),
    body: AsyncPanel<List<RecurrencePlan>>(
      future: _future,
      onRetry: _reload,
      errorMessage: 'Não foi possível carregar as regras. Verifique sua conexão e tente novamente.',
      builder: (plans) => plans.isEmpty
          ? const EmptyPanel(
              message: 'Nenhuma regra mensal cadastrada. Cadastre uma conta e escolha “Todo mês” ou “Parcelado”.',
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: plans.length,
              itemBuilder: (_, index) {
                final plan = plans[index];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          plan.description,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        Text(plan.kind.label),
                        Text(
                          '${AppFormatters.currency.format(plan.amountAt(DateTime.now()))} por mês',
                        ),
                        Text(
                          'Primeiro vencimento: ${AppFormatters.date.format(plan.firstDue)}',
                        ),
                        Text(
                          'Vence todo dia ${plan.monthlyDay} (ou no último dia do mês).',
                        ),
                        Text(
                          plan.totalInstallments == null
                              ? 'Mensal • sem data final'
                              : '${plan.totalInstallments} parcelas • última prevista: ${AppFormatters.date.format(plan.lastDue!)}',
                        ),
                        for (final change in plan.futureAmounts)
                          Text(
                            'A partir de ${AppFormatters.monthYear.format(DateTime.parse(change['from_month'].toString()))}: ${AppFormatters.currency.format(change['amount'])}',
                          ),
                        if (plan.endDate != null)
                          Text(
                            'Encerramento: ${AppFormatters.date.format(plan.endDate!)}',
                          ),
                        if (plan.isFinished(DateTime.now()))
                          const Text('Período de cobrança concluído')
                        else if (plan.endDate == null)
                          TextButton.icon(
                            onPressed: _busyId != null
                                ? null
                                : () => _stop(plan),
                            icon: const Icon(Icons.stop_circle_outlined),
                            label: Text(
                              _busyId == plan.id
                                  ? 'Encerrando...'
                                  : 'Encerrar após este mês',
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
    ),
  );
}
