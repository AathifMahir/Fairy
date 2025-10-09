import 'package:flutter/material.dart';
import 'package:fairy/fairy.dart';
import '../models/fairy_models.dart';

/// Fairy counter widget for performance testing
class FairyCounterWidget extends StatelessWidget {
  const FairyCounterWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FairyScope(
      viewModel: (_) => FairyCounterViewModel(),
      child: Builder(
        builder: (context) {
          return Column(
            children: [
              Bind<FairyCounterViewModel, int>(
                selector: (vm) => vm.counter.value,
                builder: (context, value, update) => Text('Count: $value'),
              ),
              Command<FairyCounterViewModel>(
                command: (vm) => vm.incrementCommand,
                builder: (context, execute, canExecute) => ElevatedButton(
                  onPressed: execute,
                  child: const Text('Increment'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
