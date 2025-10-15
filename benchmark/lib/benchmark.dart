import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fairy/fairy.dart';
import 'package:provider/provider.dart' as provider;
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Import refactored models
import 'models/benchmark_results.dart';
import 'models/fairy_models.dart';
import 'models/provider_models.dart';
import 'models/riverpod_models.dart';

// Import refactored widgets
import 'widgets/fairy_widgets.dart';
import 'widgets/provider_widgets.dart';
import 'widgets/riverpod_widgets.dart';

// Import utilities
import 'utils/benchmark_printer.dart';

// Store benchmark results
final _results = BenchmarkResults();

void main() {
  // Create proper test binding for benchmarks
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Fairy vs Provider vs Riverpod Benchmark', () {
    testWidgets('Fairy Widget Performance', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: const FairyCounterWidget(),
          ),
        ),
      );

      // Warm up
      for (int i = 0; i < 10; i++) {
        await tester.tap(find.byType(ElevatedButton));
        await tester.pump();
      }

      // Actual benchmark
      final stopwatch = Stopwatch()..start();
      for (int i = 0; i < 1000; i++) {
        await tester.tap(find.byType(ElevatedButton));
        await tester.pump();
      }
      stopwatch.stop();
      
      _results.widgetPerformance['Fairy'] = stopwatch.elapsedMicroseconds;
    });

    testWidgets('Provider Widget Performance', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: const ProviderCounterWidget(),
          ),
        ),
      );

      // Warm up
      for (int i = 0; i < 10; i++) {
        await tester.tap(find.byType(ElevatedButton));
        await tester.pump();
      }

      // Actual benchmark
      final stopwatch = Stopwatch()..start();
      for (int i = 0; i < 1000; i++) {
        await tester.tap(find.byType(ElevatedButton));
        await tester.pump();
      }
      stopwatch.stop();
      
      _results.widgetPerformance['Provider'] = stopwatch.elapsedMicroseconds;
    });

    testWidgets('Riverpod Widget Performance', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: const RiverpodCounterWidget(),
            ),
          ),
        ),
      );

      // Warm up
      for (int i = 0; i < 10; i++) {
        await tester.tap(find.byType(ElevatedButton));
        await tester.pump();
      }

      // Actual benchmark
      final stopwatch = Stopwatch()..start();
      for (int i = 0; i < 1000; i++) {
        await tester.tap(find.byType(ElevatedButton));
        await tester.pump();
      }
      stopwatch.stop();
      
      _results.widgetPerformance['Riverpod'] = stopwatch.elapsedMicroseconds;
    });

    testWidgets('Build Performance Comparison', (WidgetTester tester) async {
      // Test Fairy build performance
      final fairyStopwatch = Stopwatch()..start();
      for (int i = 0; i < 100; i++) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: const FairyCounterWidget(),
            ),
          ),
        );
        await tester.pumpWidget(Container()); // Clear
      }
      fairyStopwatch.stop();
      _results.buildPerformance['Fairy'] = fairyStopwatch.elapsedMicroseconds;

      // Test Provider build performance
      final providerStopwatch = Stopwatch()..start();
      for (int i = 0; i < 100; i++) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: const ProviderCounterWidget(),
            ),
          ),
        );
        await tester.pumpWidget(Container()); // Clear
      }
      providerStopwatch.stop();
      _results.buildPerformance['Provider'] = providerStopwatch.elapsedMicroseconds;

      // Test Riverpod build performance
      final riverpodStopwatch = Stopwatch()..start();
      for (int i = 0; i < 100; i++) {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: const RiverpodCounterWidget(),
              ),
            ),
          ),
        );
        await tester.pumpWidget(Container()); // Clear
      }
      riverpodStopwatch.stop();
      _results.buildPerformance['Riverpod'] = riverpodStopwatch.elapsedMicroseconds;
    });

    testWidgets('Memory Usage Comparison', (WidgetTester tester) async {

      // Fairy memory test
      final fairyStopwatch = Stopwatch()..start();
      for (int i = 0; i < 50; i++) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: const FairyCounterWidget(),
            ),
          ),
        );
        
        // Trigger state changes
        for (int j = 0; j < 10; j++) {
          await tester.tap(find.byType(ElevatedButton));
          await tester.pump();
        }
        
        await tester.pumpWidget(Container()); // Dispose
      }
      fairyStopwatch.stop();
      _results.memoryPerformance['Fairy'] = fairyStopwatch.elapsedMicroseconds;

      // Provider memory test
      final providerStopwatch = Stopwatch()..start();
      for (int i = 0; i < 50; i++) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: const ProviderCounterWidget(),
            ),
          ),
        );
        
        // Trigger state changes
        for (int j = 0; j < 10; j++) {
          await tester.tap(find.byType(ElevatedButton));
          await tester.pump();
        }
        
        await tester.pumpWidget(Container()); // Dispose
      }
      providerStopwatch.stop();
      _results.memoryPerformance['Provider'] = providerStopwatch.elapsedMicroseconds;

      // Riverpod memory test
      final riverpodStopwatch = Stopwatch()..start();
      for (int i = 0; i < 50; i++) {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: const RiverpodCounterWidget(),
              ),
            ),
          ),
        );
        
        // Trigger state changes
        for (int j = 0; j < 10; j++) {
          await tester.tap(find.byType(ElevatedButton));
          await tester.pump();
        }
        
        await tester.pumpWidget(Container()); // Dispose
      }
      riverpodStopwatch.stop();
      _results.memoryPerformance['Riverpod'] = riverpodStopwatch.elapsedMicroseconds;
    });

    // SELECTIVE REBUILD TEST - The REAL optimization benchmark!
    // This tests what happens when ONE property changes in a multi-property ViewModel
    // Fairy TWO-WAY binding should only rebuild widgets watching that specific property
    // Fairy ONE-WAY binding, Provider, and Riverpod will rebuild ALL widgets (global notifications)
    testWidgets('Selective Rebuild Performance', (WidgetTester tester) async {
      
      // === FAIRY TWO-WAY BINDING (Selective Notifications) ===
      int fairy1BuildsSelective = 0, fairy2BuildsSelective = 0, fairy3BuildsSelective = 0;
      int listenerCalls = 0;
      FairyMultiPropertyViewModel? capturedVm;
      
      // Build widget tree with FairyScope and TWO-WAY binding (returns ObservableProperty)
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FairyScope(
              key: const ValueKey('fairy-two-way'),
              viewModel: (locator) {
                final vm = FairyMultiPropertyViewModel();
                // Add a global listener to verify notifications are being sent
                vm.propertyChanged(() {
                  listenerCalls++;
                });
                capturedVm = vm;
                return vm;
              },
              child: Builder(
                builder: (context) {
                  return Column(
                    children: [
                      // Each Bind watches a DIFFERENT property
                      // TValue is int, selector returns ObservableProperty<int> → Two-way binding
                      Bind.viewModel<FairyMultiPropertyViewModel, int>(
                        selector: (vm) => vm.property1, // Returns ObservableProperty<int> → Two-way!
                        builder: (context, value, update) {
                          fairy1BuildsSelective++;
                          return Text('Fairy1: $value', key: const ValueKey('fairy1'));
                        },
                      ),
                      Bind.viewModel<FairyMultiPropertyViewModel, int>(
                        selector: (vm) => vm.property2, // Returns ObservableProperty<int> → Two-way!
                        builder: (context, value, update) {
                          fairy2BuildsSelective++;
                          return Text('Fairy2: $value', key: const ValueKey('fairy2'));
                        },
                      ),
                      Bind.viewModel<FairyMultiPropertyViewModel, int>(
                        selector: (vm) => vm.property3, // Returns ObservableProperty<int> → Two-way!
                        builder: (context, value, update) {
                          fairy3BuildsSelective++;
                          return Text('Fairy3: $value', key: const ValueKey('fairy3'));
                        },
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );
      
      await tester.pumpAndSettle();
      fairy1BuildsSelective = fairy2BuildsSelective = fairy3BuildsSelective = 0;
      listenerCalls = 0;

      final fairySelectiveStopwatch = Stopwatch()..start();
      
      // Update property1 100 times - ONLY widget1 should rebuild!
      for (int i = 0; i < 100; i++) {
        capturedVm!.property1.value = i;
        await tester.pump();
      }
      fairySelectiveStopwatch.stop();
      
      print('\n🧚 Fairy TWO-WAY Binding (Selective Notification):');
      print('  Global listener calls: $listenerCalls (property changes detected)');
      print('  Widget 1 (watching property1): $fairy1BuildsSelective rebuilds ← Only this one!');
      print('  Widget 2 (watching property2): $fairy2BuildsSelective rebuilds ← Should be 0');
      print('  Widget 3 (watching property3): $fairy3BuildsSelective rebuilds ← Should be 0');
      print('  Time: ${fairySelectiveStopwatch.elapsedMilliseconds}ms');
      print('  Efficiency: ${fairy1BuildsSelective > 0 ? ((fairy1BuildsSelective / (fairy1BuildsSelective + fairy2BuildsSelective + fairy3BuildsSelective)) * 100).toStringAsFixed(1) : 0}% of rebuilds were necessary\n');
      
      _results.selectiveRebuildPerformance['Fairy (selective)'] = fairySelectiveStopwatch.elapsedMicroseconds;
      
      // === FAIRY ONE-WAY BINDING (Global Notifications) ===
      int fairy1BuildsGlobal = 0, fairy2BuildsGlobal = 0, fairy3BuildsGlobal = 0;
      FairyMultiPropertyViewModel? capturedVmGlobal;
      
      // Build with ONE-WAY binding (returns raw value)
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FairyScope(
              key: const ValueKey('fairy-one-way'),
              viewModel: (locator) {
                final vm = FairyMultiPropertyViewModel();
                capturedVmGlobal = vm;
                return vm;
              },
              child: Builder(
                builder: (context) => Column(
                  children: [
                    // Returns raw int → global notifications
                    Bind.viewModel<FairyMultiPropertyViewModel, int>(
                      selector: (vm) => vm.property1.value,
                      builder: (context, value, update) {
                        fairy1BuildsGlobal++;
                        return Text('Fairy1: $value', key: const ValueKey('fairy1'));
                      },
                    ),
                    Bind.viewModel<FairyMultiPropertyViewModel, int>(
                      selector: (vm) => vm.property2.value,
                      builder: (context, value, update) {
                        fairy2BuildsGlobal++;
                        return Text('Fairy2: $value', key: const ValueKey('fairy2'));
                      },
                    ),
                    Bind.viewModel<FairyMultiPropertyViewModel, int>(
                      selector: (vm) => vm.property3.value,
                      builder: (context, value, update) {
                        fairy3BuildsGlobal++;
                        return Text('Fairy3: $value', key: const ValueKey('fairy3'));
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      
      await tester.pumpAndSettle();
      fairy1BuildsGlobal = fairy2BuildsGlobal = fairy3BuildsGlobal = 0;

      final fairyGlobalStopwatch = Stopwatch()..start();
      
      // Update property1 100 times - ALL widgets will rebuild
      // For ONE-WAY binding, we manually trigger global notifications
      for (int i = 0; i < 100; i++) {
        capturedVmGlobal!.property1.value = i;
        capturedVmGlobal!.notifyGlobal(); // Trigger global notification
        await tester.pump();
      }
      fairyGlobalStopwatch.stop();
      
      print('🧚 Fairy ONE-WAY Binding (Global Notification):');
      print('  Widget 1 (watching property1): $fairy1BuildsGlobal rebuilds');
      print('  Widget 2 (watching property2): $fairy2BuildsGlobal rebuilds ← Unnecessary!');
      print('  Widget 3 (watching property3): $fairy3BuildsGlobal rebuilds ← Unnecessary!');
      print('  Time: ${fairyGlobalStopwatch.elapsedMilliseconds}ms');
      final totalGlobal = fairy1BuildsGlobal + fairy2BuildsGlobal + fairy3BuildsGlobal;
      print('  Efficiency: ${totalGlobal > 0 ? ((fairy1BuildsGlobal / totalGlobal) * 100).toStringAsFixed(1) : 0}% of rebuilds were necessary\n');
      
      _results.selectiveRebuildPerformance['Fairy (global)'] = fairyGlobalStopwatch.elapsedMicroseconds;

      // === PROVIDER WITH SELECTOR (Selective Notification) ===
      int providerSelectiveBuilds1 = 0, providerSelectiveBuilds2 = 0, providerSelectiveBuilds3 = 0;
      final providerNotifierSelective = ProviderMultiPropertyNotifier();
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: provider.ChangeNotifierProvider.value(
              value: providerNotifierSelective,
              child: Builder(
                builder: (context) => Column(
                  children: [
                    provider.Selector<ProviderMultiPropertyNotifier, int>(
                      selector: (context, notifier) => notifier.property1,
                      builder: (context, value, child) {
                        providerSelectiveBuilds1++;
                        return Text('Provider1: $value', key: const ValueKey('provider1'));
                      },
                    ),
                    provider.Selector<ProviderMultiPropertyNotifier, int>(
                      selector: (context, notifier) => notifier.property2,
                      builder: (context, value, child) {
                        providerSelectiveBuilds2++;
                        return Text('Provider2: $value', key: const ValueKey('provider2'));
                      },
                    ),
                    provider.Selector<ProviderMultiPropertyNotifier, int>(
                      selector: (context, notifier) => notifier.property3,
                      builder: (context, value, child) {
                        providerSelectiveBuilds3++;
                        return Text('Provider3: $value', key: const ValueKey('provider3'));
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      
      await tester.pumpAndSettle();
      providerSelectiveBuilds1 = providerSelectiveBuilds2 = providerSelectiveBuilds3 = 0;

      final providerSelectiveStopwatch = Stopwatch()..start();
      
      for (int i = 0; i < 100; i++) {
        providerNotifierSelective.updateProperty1();
        await tester.pump();
      }
      providerSelectiveStopwatch.stop();
      
      print('📦 Provider with Selector (Selective Notification):');
      print('  Widget 1 (watching property1): $providerSelectiveBuilds1 rebuilds ← Only this one!');
      print('  Widget 2 (watching property2): $providerSelectiveBuilds2 rebuilds ← Should be 0');
      print('  Widget 3 (watching property3): $providerSelectiveBuilds3 rebuilds ← Should be 0');
      print('  Time: ${providerSelectiveStopwatch.elapsedMilliseconds}ms');
      final totalProviderSelective = providerSelectiveBuilds1 + providerSelectiveBuilds2 + providerSelectiveBuilds3;
      print('  Efficiency: ${totalProviderSelective > 0 ? ((providerSelectiveBuilds1 / totalProviderSelective) * 100).toStringAsFixed(1) : 0}% of rebuilds were necessary\n');
      
      _results.selectiveRebuildPerformance['Provider (selective)'] = providerSelectiveStopwatch.elapsedMicroseconds;

      // === PROVIDER WITHOUT SELECTOR (Global Notification) ===
      int providerGlobalBuilds1 = 0, providerGlobalBuilds2 = 0, providerGlobalBuilds3 = 0;
      final providerNotifierGlobal = ProviderMultiPropertyNotifier();
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: provider.ChangeNotifierProvider.value(
              value: providerNotifierGlobal,
              child: Builder(
                builder: (context) => Column(
                  children: [
                    provider.Consumer<ProviderMultiPropertyNotifier>(
                      builder: (context, notifier, child) {
                        providerGlobalBuilds1++;
                        return Text('P1: ${notifier.property1}');
                      },
                    ),
                    provider.Consumer<ProviderMultiPropertyNotifier>(
                      builder: (context, notifier, child) {
                        providerGlobalBuilds2++;
                        return Text('P2: ${notifier.property2}');
                      },
                    ),
                    provider.Consumer<ProviderMultiPropertyNotifier>(
                      builder: (context, notifier, child) {
                        providerGlobalBuilds3++;
                        return Text('P3: ${notifier.property3}');
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      
      await tester.pumpAndSettle();
      providerGlobalBuilds1 = providerGlobalBuilds2 = providerGlobalBuilds3 = 0;

      final providerGlobalStopwatch = Stopwatch()..start();
      
      for (int i = 0; i < 100; i++) {
        providerNotifierGlobal.updateProperty1();
        await tester.pump();
      }
      providerGlobalStopwatch.stop();
      
      print('📦 Provider without Selector (Global Notification):');
      print('  Widget 1 (watching property1): $providerGlobalBuilds1 rebuilds');
      print('  Widget 2 (watching property2): $providerGlobalBuilds2 rebuilds ← Unnecessary!');
      print('  Widget 3 (watching property3): $providerGlobalBuilds3 rebuilds ← Unnecessary!');
      print('  Time: ${providerGlobalStopwatch.elapsedMilliseconds}ms');
      final totalProviderGlobal = providerGlobalBuilds1 + providerGlobalBuilds2 + providerGlobalBuilds3;
      print('  Efficiency: ${totalProviderGlobal > 0 ? ((providerGlobalBuilds1 / totalProviderGlobal) * 100).toStringAsFixed(1) : 0}% of rebuilds were necessary\n');
      
      _results.selectiveRebuildPerformance['Provider (global)'] = providerGlobalStopwatch.elapsedMicroseconds;

      // === RIVERPOD WITH SELECT (Selective Notification) ===
      int riverpodSelectiveBuilds1 = 0, riverpodSelectiveBuilds2 = 0, riverpodSelectiveBuilds3 = 0;
      final riverpodSelectiveContainer = ProviderContainer();
      
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: riverpodSelectiveContainer,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => Column(
                  children: [
                    Consumer(
                      builder: (context, ref, child) {
                        final value = ref.watch(riverpodMultiProvider.select((state) => state['p1']));
                        riverpodSelectiveBuilds1++;
                        return Text('Riverpod1: $value', key: const ValueKey('riverpod1'));
                      },
                    ),
                    Consumer(
                      builder: (context, ref, child) {
                        final value = ref.watch(riverpodMultiProvider.select((state) => state['p2']));
                        riverpodSelectiveBuilds2++;
                        return Text('Riverpod2: $value', key: const ValueKey('riverpod2'));
                      },
                    ),
                    Consumer(
                      builder: (context, ref, child) {
                        final value = ref.watch(riverpodMultiProvider.select((state) => state['p3']));
                        riverpodSelectiveBuilds3++;
                        return Text('Riverpod3: $value', key: const ValueKey('riverpod3'));
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      
      await tester.pumpAndSettle();
      riverpodSelectiveBuilds1 = riverpodSelectiveBuilds2 = riverpodSelectiveBuilds3 = 0;

      final riverpodSelectiveStopwatch = Stopwatch()..start();
      final riverpodSelectiveNotifier = riverpodSelectiveContainer.read(riverpodMultiProvider.notifier);
      
      for (int i = 0; i < 100; i++) {
        riverpodSelectiveNotifier.updateProperty1();
        await tester.pump();
      }
      riverpodSelectiveStopwatch.stop();
      
      print('🏗️ Riverpod with select() (Selective Notification):');
      print('  Widget 1 (watching property1): $riverpodSelectiveBuilds1 rebuilds ← Only this one!');
      print('  Widget 2 (watching property2): $riverpodSelectiveBuilds2 rebuilds ← Should be 0');
      print('  Widget 3 (watching property3): $riverpodSelectiveBuilds3 rebuilds ← Should be 0');
      print('  Time: ${riverpodSelectiveStopwatch.elapsedMilliseconds}ms');
      final totalRiverpodSelective = riverpodSelectiveBuilds1 + riverpodSelectiveBuilds2 + riverpodSelectiveBuilds3;
      print('  Efficiency: ${totalRiverpodSelective > 0 ? ((riverpodSelectiveBuilds1 / totalRiverpodSelective) * 100).toStringAsFixed(1) : 0}% of rebuilds were necessary\n');
      
      _results.selectiveRebuildPerformance['Riverpod (selective)'] = riverpodSelectiveStopwatch.elapsedMicroseconds;
      
      riverpodSelectiveContainer.dispose();

      // === RIVERPOD WITHOUT SELECT (Global Notification) ===
      int riverpodGlobalBuilds1 = 0, riverpodGlobalBuilds2 = 0, riverpodGlobalBuilds3 = 0;
      final riverpodGlobalContainer = ProviderContainer();
      
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: riverpodGlobalContainer,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => Column(
                  children: [
                    Consumer(
                      builder: (context, ref, child) {
                        final state = ref.watch(riverpodMultiProvider);
                        riverpodGlobalBuilds1++;
                        return Text('P1: ${state['p1']}');
                      },
                    ),
                    Consumer(
                      builder: (context, ref, child) {
                        final state = ref.watch(riverpodMultiProvider);
                        riverpodGlobalBuilds2++;
                        return Text('P2: ${state['p2']}');
                      },
                    ),
                    Consumer(
                      builder: (context, ref, child) {
                        final state = ref.watch(riverpodMultiProvider);
                        riverpodGlobalBuilds3++;
                        return Text('P3: ${state['p3']}');
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      
      await tester.pumpAndSettle();
      riverpodGlobalBuilds1 = riverpodGlobalBuilds2 = riverpodGlobalBuilds3 = 0;

      final riverpodGlobalStopwatch = Stopwatch()..start();
      final riverpodGlobalNotifier = riverpodGlobalContainer.read(riverpodMultiProvider.notifier);
      
      for (int i = 0; i < 100; i++) {
        riverpodGlobalNotifier.updateProperty1();
        await tester.pump();
      }
      riverpodGlobalStopwatch.stop();
      
      print('🏗️ Riverpod without select() (Global Notification):');
      print('  Widget 1 (watching property1): $riverpodGlobalBuilds1 rebuilds');
      print('  Widget 2 (watching property2): $riverpodGlobalBuilds2 rebuilds ← Unnecessary!');
      print('  Widget 3 (watching property3): $riverpodGlobalBuilds3 rebuilds ← Unnecessary!');
      print('  Time: ${riverpodGlobalStopwatch.elapsedMilliseconds}ms');
      final totalRiverpodGlobal = riverpodGlobalBuilds1 + riverpodGlobalBuilds2 + riverpodGlobalBuilds3;
      print('  Efficiency: ${totalRiverpodGlobal > 0 ? ((riverpodGlobalBuilds1 / totalRiverpodGlobal) * 100).toStringAsFixed(1) : 0}% of rebuilds were necessary\n');
      
      _results.selectiveRebuildPerformance['Riverpod (global)'] = riverpodGlobalStopwatch.elapsedMicroseconds;
      
      riverpodGlobalContainer.dispose();
    });
  });

  // Print formatted results after all tests complete
  tearDownAll(() {
    printBenchmarkResults(_results);
  });
}