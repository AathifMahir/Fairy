/// Holds benchmark results for all test categories
class BenchmarkResults {
  final Map<String, int> widgetPerformance = {};
  final Map<String, int> buildPerformance = {};
  final Map<String, int> memoryPerformance = {};
  final Map<String, int> selectiveRebuildPerformance = {};
  final Map<String, int> rebuildPerformance = {};
}
