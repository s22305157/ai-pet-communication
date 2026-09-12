import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../domain/pilot_metrics.dart';
import '../domain/pilot_repository.dart';
import '../domain/pilot_request.dart';
import '../../../widgets/pilot_surface.dart';

class PilotCostScreen extends StatefulWidget {
  final PilotRepository repository;
  const PilotCostScreen({super.key, required this.repository});
  @override
  State<PilotCostScreen> createState() => _PilotCostScreenState();
}

class _PilotCostScreenState extends State<PilotCostScreen> {
  late DateTime today = DateTime.parse(
    DateFormat(
      'yyyy-MM-dd',
    ).format(DateTime.now().toUtc().add(const Duration(hours: 8))),
  );
  late DateTime selected = today;
  String get day => DateFormat('yyyy-MM-dd').format(selected);
  @override
  Widget build(BuildContext context) => PilotSurface<PilotCost>(
    title: '每日成本與管理時間',
    repository: widget.repository,
    loader: () => widget.repository.execute(GetPilotCost(day)),
    builder: (context, c) => ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('請依帳務與營運紀錄填寫該日總額，統一使用新台幣。重新儲存會更新該日總額，不會累加。'),
        TextButton(
          onPressed: c.busy
              ? null
              : () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: selected,
                    firstDate: today.subtract(const Duration(days: 90)),
                    lastDate: today,
                  );
                  if (date != null && mounted) {
                    setState(() => selected = date);
                    await c.load();
                  }
                },
          child: Text('日期 $day（台北時間）'),
        ),
        if (c.value != null)
          _CostForm(
            key: ValueKey('$day/${c.value!.revision}'),
            cost: c.value!,
            busy: c.busy,
            save: (cost) => c.submit(SetPilotCost(day, cost)),
          ),
      ],
    ),
  );
}

class _CostForm extends StatefulWidget {
  final PilotCost cost;
  final bool busy;
  final Future<bool> Function(PilotCost) save;
  const _CostForm({
    super.key,
    required this.cost,
    required this.busy,
    required this.save,
  });
  @override
  State<_CostForm> createState() => _CostFormState();
}

class _CostFormState extends State<_CostForm> {
  final form = GlobalKey<FormState>();
  late final fields = [
    TextEditingController(text: widget.cost.modelTwd.toString()),
    TextEditingController(text: widget.cost.storageTwd.toString()),
    TextEditingController(text: widget.cost.requests.toString()),
    TextEditingController(text: widget.cost.minutes.toString()),
  ];
  @override
  void dispose() {
    for (final field in fields) {
      field.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Form(
    key: form,
    child: Column(
      children: [
        for (var i = 0; i < fields.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: TextFormField(
              controller: fields[i],
              enabled: !widget.busy,
              keyboardType: TextInputType.numberWithOptions(decimal: i < 2),
              decoration: InputDecoration(
                labelText: ['模型費用（NT\$）', '儲存費用（NT\$）', '請求次數', '人工管理分鐘'][i],
              ),
              validator: (v) {
                final value = i < 2
                    ? double.tryParse(v ?? '')
                    : int.tryParse(v ?? '');
                return value == null ||
                        !value.isFinite ||
                        value < 0 ||
                        value > 1e9
                    ? '請輸入有效的非負數值'
                    : null;
              },
            ),
          ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: widget.busy
              ? null
              : () async {
                  if (!form.currentState!.validate()) return;
                  final saved = await widget.save(
                    PilotCost(
                      revision: widget.cost.revision,
                      modelTwd: double.parse(fields[0].text),
                      storageTwd: double.parse(fields[1].text),
                      requests: int.parse(fields[2].text),
                      minutes: int.parse(fields[3].text),
                    ),
                  );
                  if (saved && context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('當日成本已儲存')));
                  }
                },
          child: const Text('儲存當日總額'),
        ),
      ],
    ),
  );
}
