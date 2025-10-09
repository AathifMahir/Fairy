# Fairy Framework Benchmarks

This project contains performance benchmarks comparing Fairy with other popular Flutter state management frameworks.

## Running Benchmarks

To run the performance benchmarks:

```bash
flutter test lib/benchmark.dart
```

## Results

The benchmarks compare three frameworks:
- **🧚 Fairy**: Our lightweight MVVM framework
- **📦 Provider**: Popular state management solution  
- **🏗️ Riverpod**: Modern reactive framework

### Latest Results

- **Widget Performance**: Fairy performs within 2.2% of Riverpod (fastest)
- **Build Performance**: Fairy builds 21% slower than Provider but still very fast
- **Memory Management**: Fairy is 9-10% faster at cleanup than competitors

See [PERFORMANCE_ANALYSIS.md](PERFORMANCE_ANALYSIS.md) for detailed results and analysis.

## Frameworks Tested

All benchmarks use real framework implementations:

- **Fairy**: Uses `FairyScope`, `Bind`, and `Command` widgets
- **Provider**: Uses `ChangeNotifierProvider`, `Selector` and `Consumer`  
- **Riverpod**: Uses `StateNotifierProvider`, `Select` and `ConsumerWidget`

## Test Scenarios

1. **Widget Performance**: 1000 rapid state updates with UI rebuilds
2. **Build Performance**: 100 widget create/build cycles  
3. **Memory Management**: 50 create/dispose cycles with state changes

The benchmarks use Flutter's official `benchmarkWidgets` function for accurate, real-world performance measurement.