import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/riverpod_models.dart';

/// Riverpod counter widget for performance testing
class RiverpodCounterWidget extends ConsumerWidget {
  const RiverpodCounterWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counter = ref.watch(riverpodCounterProvider);
    final notifier = ref.read(riverpodCounterProvider.notifier);

    return Column(
      children: [
        Text('Count: $counter'),
        ElevatedButton(
          onPressed: notifier.increment,
          child: const Text('Increment'),
        ),
      ],
    );
  }
}
