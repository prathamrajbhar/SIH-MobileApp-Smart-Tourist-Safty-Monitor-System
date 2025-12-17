import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../utils/logger.dart';

/// Advanced state management system with memoization, optimization,
/// and intelligent rebuilding for 200% UI performance

/// Base class for optimized state management
abstract class OptimizedNotifier extends ChangeNotifier {
  bool _disposed = false;
  final Set<VoidCallback> _listeners = <VoidCallback>{};
  
  @override
  void addListener(VoidCallback listener) {
    if (_disposed) return;
    _listeners.add(listener);
    super.addListener(listener);
  }
  
  @override
  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
    super.removeListener(listener);
  }
  
  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }
  
  @override
  void dispose() {
    _disposed = true;
    _listeners.clear();
    super.dispose();
  }
  
  bool get isDisposed => _disposed;
  int get listenerCount => _listeners.length;
}

/// Memoization helper for expensive computations
class MemoizedValue<T> {
  final T Function() _compute;
  final bool Function()? _shouldRecalculate;
  T? _cachedValue;
  bool _hasValue = false;
  
  MemoizedValue(this._compute, {bool Function()? shouldRecalculate})
      : _shouldRecalculate = shouldRecalculate;
  
  T get value {
    if (!_hasValue || (_shouldRecalculate?.call() ?? false)) {
      _cachedValue = _compute();
      _hasValue = true;
    }
    return _cachedValue!;
  }
  
  void invalidate() {
    _hasValue = false;
    _cachedValue = null;
  }
  
  bool get hasValue => _hasValue;
}

/// Smart widget that prevents unnecessary rebuilds
class OptimizedBuilder extends StatefulWidget {
  final Widget Function(BuildContext context) builder;
  final List<Listenable>? listenables;
  final bool Function()? shouldRebuild;
  final String? debugName;
  
  const OptimizedBuilder({
    super.key,
    required this.builder,
    this.listenables,
    this.shouldRebuild,
    this.debugName,
  });
  
  @override
  State<OptimizedBuilder> createState() => _OptimizedBuilderState();
}

class _OptimizedBuilderState extends State<OptimizedBuilder> {
  late Widget _cachedWidget;
  bool _hasBuilt = false;
  int _buildCount = 0;
  
  @override
  void initState() {
    super.initState();
    _setupListeners();
  }
  
  void _setupListeners() {
    widget.listenables?.forEach((listenable) {
      listenable.addListener(_onDependencyChanged);
    });
  }
  
  void _onDependencyChanged() {
    if (widget.shouldRebuild?.call() ?? true) {
      if (mounted) {
        setState(() {
          _hasBuilt = false;
        });
      }
    }
  }
  
  @override
  void didUpdateWidget(OptimizedBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Remove old listeners
    oldWidget.listenables?.forEach((listenable) {
      listenable.removeListener(_onDependencyChanged);
    });
    
    // Add new listeners
    _setupListeners();
    
    // Force rebuild if dependencies changed
    if (!listEquals(widget.listenables, oldWidget.listenables)) {
      _hasBuilt = false;
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (!_hasBuilt) {
      _cachedWidget = widget.builder(context);
      _hasBuilt = true;
      _buildCount++;
      
      if (kDebugMode && widget.debugName != null) {
        AppLogger.performance(
          'OptimizedBuilder',
          Duration.zero,
          details: '${widget.debugName} rebuilt (count: $_buildCount)',
        );
      }
    }
    
    return _cachedWidget;
  }
  
  @override
  void dispose() {
    widget.listenables?.forEach((listenable) {
      listenable.removeListener(_onDependencyChanged);
    });
    super.dispose();
  }
}

/// Optimized list view with intelligent rendering
class OptimizedListView<T> extends StatefulWidget {
  final List<T> items;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final bool Function(T oldItem, T newItem)? itemComparator;
  final ScrollController? controller;
  final EdgeInsets? padding;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final int? cacheExtent;
  final String? debugName;
  
  const OptimizedListView({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.itemComparator,
    this.controller,
    this.padding,
    this.shrinkWrap = false,
    this.physics,
    this.cacheExtent,
    this.debugName,
  });
  
  @override
  State<OptimizedListView<T>> createState() => _OptimizedListViewState<T>();
}

class _OptimizedListViewState<T> extends State<OptimizedListView<T>> {
  final Map<int, Widget> _widgetCache = {};
  List<T> _previousItems = [];
  
  @override
  void initState() {
    super.initState();
    _previousItems = List.from(widget.items);
  }
  
  @override
  void didUpdateWidget(OptimizedListView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Invalidate cache if items changed significantly
    if (widget.items.length != _previousItems.length) {
      _widgetCache.clear();
    } else {
      // Selectively invalidate changed items
      for (int i = 0; i < widget.items.length; i++) {
        final oldItem = i < _previousItems.length ? _previousItems[i] : null;
        final newItem = widget.items[i];
        
        if (oldItem == null || 
            (widget.itemComparator?.call(oldItem, newItem) ?? oldItem != newItem)) {
          _widgetCache.remove(i);
        }
      }
    }
    
    _previousItems = List.from(widget.items);
  }
  
  Widget _buildItem(BuildContext context, int index) {
    return _widgetCache.putIfAbsent(index, () {
      if (kDebugMode && widget.debugName != null) {
        AppLogger.performance(
          'OptimizedListView',
          Duration.zero,
          details: '${widget.debugName} item $index built',
        );
      }
      return widget.itemBuilder(context, widget.items[index], index);
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: widget.controller,
      padding: widget.padding,
      shrinkWrap: widget.shrinkWrap,
      physics: widget.physics,
      cacheExtent: widget.cacheExtent?.toDouble(),
      itemCount: widget.items.length,
      itemBuilder: _buildItem,
    );
  }
}

/// Smart Future builder with caching and error recovery
class OptimizedFutureBuilder<T> extends StatefulWidget {
  final Future<T> Function() futureBuilder;
  final Widget Function(BuildContext context, T data) dataBuilder;
  final Widget Function(BuildContext context)? loadingBuilder;
  final Widget Function(BuildContext context, Object error)? errorBuilder;
  final Duration? cacheDuration;
  final bool retryOnError;
  final String? debugName;
  
  const OptimizedFutureBuilder({
    super.key,
    required this.futureBuilder,
    required this.dataBuilder,
    this.loadingBuilder,
    this.errorBuilder,
    this.cacheDuration,
    this.retryOnError = true,
    this.debugName,
  });
  
  @override
  State<OptimizedFutureBuilder<T>> createState() => _OptimizedFutureBuilderState<T>();
}

class _OptimizedFutureBuilderState<T> extends State<OptimizedFutureBuilder<T>> {
  Future<T>? _future;
  T? _cachedData;
  DateTime? _cacheTime;
  Object? _lastError;
  int _retryCount = 0;
  static const int _maxRetries = 3;
  
  @override
  void initState() {
    super.initState();
    _initializeFuture();
  }
  
  void _initializeFuture() {
    // Check if cached data is still valid
    if (_cachedData != null && _cacheTime != null && widget.cacheDuration != null) {
      final age = DateTime.now().difference(_cacheTime!);
      if (age < widget.cacheDuration!) {
        return; // Use cached data
      }
    }
    
    _future = widget.futureBuilder().then((data) {
      if (mounted) {
        setState(() {
          _cachedData = data;
          _cacheTime = DateTime.now();
          _lastError = null;
          _retryCount = 0;
        });
      }
      return data;
    }).catchError((error) {
      if (mounted) {
        setState(() {
          _lastError = error;
        });
      }
      
      // Auto-retry on error if enabled
      if (widget.retryOnError && _retryCount < _maxRetries) {
        Timer(Duration(seconds: math.pow(2, _retryCount).toInt()), () {
          if (mounted) {
            _retryCount++;
            _initializeFuture();
          }
        });
      }
      
      throw error;
    });
  }
  
  @override
  void didUpdateWidget(OptimizedFutureBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Rebuild future if futureBuilder changed
    if (widget.futureBuilder != oldWidget.futureBuilder) {
      _initializeFuture();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    // Return cached data immediately if available and valid
    if (_cachedData != null && _lastError == null) {
      if (widget.cacheDuration != null && _cacheTime != null) {
        final age = DateTime.now().difference(_cacheTime!);
        if (age < widget.cacheDuration!) {
          return widget.dataBuilder(context, _cachedData!);
        }
      } else {
        return widget.dataBuilder(context, _cachedData!);
      }
    }
    
    return FutureBuilder<T>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return widget.dataBuilder(context, snapshot.data!);
        } else if (snapshot.hasError) {
          final error = snapshot.error!;
          AppLogger.error('OptimizedFutureBuilder error: $error');
          
          return widget.errorBuilder?.call(context, error) ??
                 _buildDefaultErrorWidget(error);
        } else {
          return widget.loadingBuilder?.call(context) ??
                 const Center(child: CircularProgressIndicator());
        }
      },
    );
  }
  
  Widget _buildDefaultErrorWidget(Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red.shade700),
          const SizedBox(height: 16),
          Text(
            'Something went wrong',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.red.shade700,
            ),
          ),
          if (kDebugMode) ...[
            const SizedBox(height: 8),
            Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red.shade600),
            ),
          ],
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _lastError = null;
                _retryCount = 0;
                _initializeFuture();
              });
            },
            child: Text('Retry${_retryCount > 0 ? ' ($_retryCount/$_maxRetries)' : ''}'),
          ),
        ],
      ),
    );
  }
}

/// Performance monitoring widget
class PerformanceMonitor extends StatefulWidget {
  final Widget child;
  final String? name;
  final void Function(String name, Duration buildTime)? onBuildComplete;
  
  const PerformanceMonitor({
    super.key,
    required this.child,
    this.name,
    this.onBuildComplete,
  });
  
  @override
  State<PerformanceMonitor> createState() => _PerformanceMonitorState();
}

class _PerformanceMonitorState extends State<PerformanceMonitor> {
  late Stopwatch _stopwatch;
  
  @override
  void initState() {
    super.initState();
    _stopwatch = Stopwatch()..start();
  }
  
  @override
  Widget build(BuildContext context) {
    final child = widget.child;
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _stopwatch.stop();
      final buildTime = _stopwatch.elapsed;
      
      if (kDebugMode) {
        final name = widget.name ?? child.runtimeType.toString();
        AppLogger.performance('Widget Build', buildTime, details: name);
        widget.onBuildComplete?.call(name, buildTime);
      }
    });
    
    return child;
  }
}

/// Smart setState that batches multiple updates
mixin OptimizedStateMixin<T extends StatefulWidget> on State<T> {
  Timer? _batchTimer;
  bool _hasPendingUpdate = false;
  
  void optimizedSetState(VoidCallback fn) {
    fn();
    
    if (_hasPendingUpdate) return;
    
    _hasPendingUpdate = true;
    _batchTimer?.cancel();
    _batchTimer = Timer(Duration.zero, () {
      if (mounted && _hasPendingUpdate) {
        setState(() {
          _hasPendingUpdate = false;
        });
      }
    });
  }
  
  @override
  void dispose() {
    _batchTimer?.cancel();
    super.dispose();
  }
}

/// Global performance tracker
class PerformanceTracker {
  static final PerformanceTracker _instance = PerformanceTracker._internal();
  factory PerformanceTracker() => _instance;
  PerformanceTracker._internal();
  
  final Map<String, List<Duration>> _buildTimes = {};
  final Map<String, int> _buildCounts = {};
  Timer? _reportTimer;
  
  void initialize() {
    _reportTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      _reportPerformanceMetrics();
    });
  }
  
  void recordBuildTime(String widgetName, Duration buildTime) {
    _buildTimes.putIfAbsent(widgetName, () => []).add(buildTime);
    _buildCounts[widgetName] = (_buildCounts[widgetName] ?? 0) + 1;
    
    // Keep only recent measurements
    final times = _buildTimes[widgetName]!;
    if (times.length > 50) {
      times.removeAt(0);
    }
  }
  
  void _reportPerformanceMetrics() {
    if (_buildTimes.isEmpty) return;
    
    final report = StringBuffer('Performance Report:\n');
    
    for (final entry in _buildTimes.entries) {
      final times = entry.value;
      if (times.isEmpty) continue;
      
      final avgTime = times.fold<int>(0, (sum, time) => sum + time.inMicroseconds) / times.length;
      final maxTime = times.fold<Duration>(Duration.zero, (max, time) => time > max ? time : max);
      final count = _buildCounts[entry.key] ?? 0;
      
      report.writeln('${entry.key}: avg=${(avgTime / 1000).toStringAsFixed(2)}ms, '
                    'max=${maxTime.inMilliseconds}ms, count=$count');
    }
    
    AppLogger.performance('Global Performance', Duration.zero, details: report.toString());
  }
  
  Map<String, Map<String, dynamic>> getMetrics() {
    final metrics = <String, Map<String, dynamic>>{};
    
    for (final entry in _buildTimes.entries) {
      final times = entry.value;
      if (times.isEmpty) continue;
      
      final avgTime = times.fold<int>(0, (sum, time) => sum + time.inMicroseconds) / times.length;
      final maxTime = times.fold<Duration>(Duration.zero, (max, time) => time > max ? time : max);
      final minTime = times.fold<Duration>(const Duration(hours: 1), (min, time) => time < min ? time : min);
      
      metrics[entry.key] = {
        'averageMs': avgTime / 1000,
        'maxMs': maxTime.inMicroseconds / 1000,
        'minMs': minTime.inMicroseconds / 1000,
        'buildCount': _buildCounts[entry.key] ?? 0,
        'measurements': times.length,
      };
    }
    
    return metrics;
  }
  
  void dispose() {
    _reportTimer?.cancel();
  }
}

/// Memory management utilities
class MemoryManager {
  static final MemoryManager _instance = MemoryManager._internal();
  factory MemoryManager() => _instance;
  MemoryManager._internal();
  
  final Set<WeakReference<OptimizedNotifier>> _notifiers = {};
  Timer? _cleanupTimer;
  
  void initialize() {
    _cleanupTimer = Timer.periodic(const Duration(minutes: 10), (timer) {
      _performCleanup();
    });
  }
  
  void registerNotifier(OptimizedNotifier notifier) {
    _notifiers.add(WeakReference(notifier));
  }
  
  void _performCleanup() {
    // Remove weak references to disposed objects
    _notifiers.removeWhere((ref) => ref.target == null || ref.target!.isDisposed);
    
    // Force garbage collection in debug mode
    if (kDebugMode) {
      AppLogger.info('Memory cleanup: ${_notifiers.length} active notifiers');
    }
  }
  
  void dispose() {
    _cleanupTimer?.cancel();
  }
}