import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';

import '../utils/logger.dart';

/// Comprehensive caching and offline support system
/// Features: Multi-layer caching, intelligent sync, offline queue,
/// and progressive data loading for maximum robustness

/// Custom connectivity result enum for robust offline handling
enum SafeConnectivityResult {
  mobile,
  wifi,
  ethernet,
  vpn,
  bluetooth,
  other,
  none,
}

/// Cache entry with metadata
class CacheEntry<T> {
  final T data;
  final DateTime timestamp;
  final Duration? ttl;
  final Map<String, dynamic> metadata;
  final int priority;
  final String etag;
  
  CacheEntry({
    required this.data,
    required this.timestamp,
    this.ttl,
    this.metadata = const {},
    this.priority = 1,
    this.etag = '',
  });
  
  bool get isExpired {
    if (ttl == null) return false;
    return DateTime.now().difference(timestamp) > ttl!;
  }
  
  Duration get age => DateTime.now().difference(timestamp);
  
  Map<String, dynamic> toJson() => {
    'data': data,
    'timestamp': timestamp.toIso8601String(),
    'ttl': ttl?.inSeconds,
    'metadata': metadata,
    'priority': priority,
    'etag': etag,
  };
  
  factory CacheEntry.fromJson(Map<String, dynamic> json) {
    return CacheEntry<T>(
      data: json['data'] as T,
      timestamp: DateTime.parse(json['timestamp']),
      ttl: json['ttl'] != null ? Duration(seconds: json['ttl']) : null,
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
      priority: json['priority'] ?? 1,
      etag: json['etag'] ?? '',
    );
  }
}

/// Multi-layer cache manager
class OptimizedCacheManager {
  static OptimizedCacheManager? _instance;
  static OptimizedCacheManager get instance => 
      _instance ??= OptimizedCacheManager._internal();
  OptimizedCacheManager._internal();

  // Cache layers
  final Map<String, CacheEntry> _memoryCache = {};
  late Directory _cacheDirectory;
  
  // Configuration
  static const int _maxMemoryCacheSize = 100;
  static const Duration _defaultTTL = Duration(hours: 1);
  static const Duration _cleanupInterval = Duration(minutes: 30);
  
  // Statistics
  int _memoryHits = 0;
  int _diskHits = 0;
  int _misses = 0;
  Timer? _cleanupTimer;
  
  /// Initialize the cache manager
  Future<void> initialize() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      _cacheDirectory = Directory('${appDir.path}/cache');
      
      if (!await _cacheDirectory.exists()) {
        await _cacheDirectory.create(recursive: true);
      }
      
      _startCleanupTimer();
      AppLogger.info('Cache manager initialized');
    } catch (e) {
      AppLogger.error('Cache manager initialization failed: $e');
    }
  }
  
  void _startCleanupTimer() {
    _cleanupTimer = Timer.periodic(_cleanupInterval, (timer) {
      _performCleanup();
    });
  }
  
  /// Get data from cache with fallback chain
  Future<T?> get<T>(
    String key, {
    Duration? maxAge,
    bool memoryOnly = false,
  }) async {
    try {
      // Check memory cache first
      final memoryEntry = _memoryCache[key];
      if (memoryEntry != null && !memoryEntry.isExpired) {
        if (maxAge == null || memoryEntry.age <= maxAge) {
          _memoryHits++;
          return memoryEntry.data as T?;
        }
      }
      
      // Check disk cache if not memory-only
      if (!memoryOnly) {
        final diskEntry = await _getDiskCache<T>(key);
        if (diskEntry != null && !diskEntry.isExpired) {
          if (maxAge == null || diskEntry.age <= maxAge) {
            _diskHits++;
            // Promote to memory cache
            _setMemoryCache(key, diskEntry);
            return diskEntry.data;
          }
        }
      }
      
      _misses++;
      return null;
    } catch (e) {
      AppLogger.error('Cache get failed for key $key: $e');
      return null;
    }
  }
  
  /// Set data in cache with intelligent storage
  Future<void> set<T>(
    String key,
    T data, {
    Duration? ttl,
    int priority = 1,
    Map<String, dynamic>? metadata,
    bool memoryOnly = false,
  }) async {
    try {
      final entry = CacheEntry<T>(
        data: data,
        timestamp: DateTime.now(),
        ttl: ttl ?? _defaultTTL,
        priority: priority,
        metadata: metadata ?? {},
        etag: _generateETag(data),
      );
      
      // Always store in memory for fast access
      _setMemoryCache(key, entry);
      
      // Store in disk cache if not memory-only and data is serializable
      if (!memoryOnly && _isSerializable(data)) {
        await _setDiskCache(key, entry);
      }
      
      AppLogger.debug('Cache set for key $key (TTL: ${ttl?.inMinutes ?? 'none'} min)');
    } catch (e) {
      AppLogger.error('Cache set failed for key $key: $e');
    }
  }
  
  void _setMemoryCache(String key, CacheEntry entry) {
    _memoryCache[key] = entry;
    
    // Evict old entries if cache is full
    if (_memoryCache.length > _maxMemoryCacheSize) {
      _evictMemoryCache();
    }
  }
  
  void _evictMemoryCache() {
    // Sort by priority and age, evict lowest priority + oldest
    final entries = _memoryCache.entries.toList();
    entries.sort((a, b) {
      final priorityCompare = a.value.priority.compareTo(b.value.priority);
      if (priorityCompare != 0) return priorityCompare;
      return b.value.timestamp.compareTo(a.value.timestamp); // Older first
    });
    
    // Remove 20% of entries
    final removeCount = (_maxMemoryCacheSize * 0.2).ceil();
    for (int i = 0; i < removeCount && entries.isNotEmpty; i++) {
      _memoryCache.remove(entries[i].key);
    }
  }
  
  Future<CacheEntry<T>?> _getDiskCache<T>(String key) async {
    try {
      final file = File('${_cacheDirectory.path}/${_hashKey(key)}.cache');
      if (!await file.exists()) return null;
      
      final content = await file.readAsString();
      final json = jsonDecode(content);
      return CacheEntry<T>.fromJson(json);
    } catch (e) {
      AppLogger.debug('Disk cache read failed for key $key: $e');
      return null;
    }
  }
  
  Future<void> _setDiskCache<T>(String key, CacheEntry<T> entry) async {
    try {
      final file = File('${_cacheDirectory.path}/${_hashKey(key)}.cache');
      final json = jsonEncode(entry.toJson());
      await file.writeAsString(json);
    } catch (e) {
      AppLogger.debug('Disk cache write failed for key $key: $e');
    }
  }
  
  String _hashKey(String key) {
    return sha256.convert(utf8.encode(key)).toString().substring(0, 16);
  }
  
  String _generateETag<T>(T data) {
    final content = jsonEncode(data);
    return sha256.convert(utf8.encode(content)).toString().substring(0, 16);
  }
  
  bool _isSerializable(dynamic data) {
    try {
      jsonEncode(data);
      return true;
    } catch (e) {
      return false;
    }
  }
  
  /// Remove specific cache entry
  Future<void> remove(String key) async {
    _memoryCache.remove(key);
    
    try {
      final file = File('${_cacheDirectory.path}/${_hashKey(key)}.cache');
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      AppLogger.debug('Cache remove failed for key $key: $e');
    }
  }
  
  /// Clear all cache
  Future<void> clear() async {
    _memoryCache.clear();
    
    try {
      if (await _cacheDirectory.exists()) {
        await _cacheDirectory.delete(recursive: true);
        await _cacheDirectory.create(recursive: true);
      }
    } catch (e) {
      AppLogger.error('Cache clear failed: $e');
    }
  }
  
  /// Perform cache cleanup
  void _performCleanup() {
    // Clean expired memory entries
    _memoryCache.removeWhere((key, entry) => entry.isExpired);
    
    // Clean disk cache in background
    _cleanDiskCache();
  }
  
  Future<void> _cleanDiskCache() async {
    try {
      final files = await _cacheDirectory.list().toList();
      final cacheFiles = files.whereType<File>().where((f) => f.path.endsWith('.cache'));
      
      for (final file in cacheFiles) {
        try {
          final content = await file.readAsString();
          final json = jsonDecode(content);
          final entry = CacheEntry.fromJson(json);
          
          if (entry.isExpired) {
            await file.delete();
          }
        } catch (e) {
          // If we can't read the file, delete it
          await file.delete();
        }
      }
    } catch (e) {
      AppLogger.error('Disk cache cleanup failed: $e');
    }
  }
  
  /// Get cache statistics
  Map<String, dynamic> getStats() => {
    'memorySize': _memoryCache.length,
    'memoryHits': _memoryHits,
    'diskHits': _diskHits,
    'misses': _misses,
    'hitRate': (_memoryHits + _diskHits) / (_memoryHits + _diskHits + _misses),
  };
  
  void dispose() {
    _cleanupTimer?.cancel();
    _performCleanup();
  }
}

/// Simple connectivity manager for offline detection
class SimpleConnectivityManager {
  static SimpleConnectivityManager? _instance;
  static SimpleConnectivityManager get instance => 
      _instance ??= SimpleConnectivityManager._internal();
  SimpleConnectivityManager._internal();

  bool _isOnline = true;
  Timer? _connectivityCheckTimer;
  final List<Function(bool)> _listeners = [];
  
  /// Initialize connectivity manager
  Future<void> initialize() async {
    await _checkConnectivity();
    _startPeriodicCheck();
  }
  
  void _startPeriodicCheck() {
    _connectivityCheckTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _checkConnectivity();
    });
  }
  
  Future<void> _checkConnectivity() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      final wasOnline = _isOnline;
      _isOnline = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      
      if (wasOnline != _isOnline) {
        _notifyListeners();
      }
    } catch (e) {
      final wasOnline = _isOnline;
      _isOnline = false;
      
      if (wasOnline != _isOnline) {
        _notifyListeners();
      }
    }
  }
  
  void _notifyListeners() {
    for (final listener in _listeners) {
      try {
        listener(_isOnline);
      } catch (e) {
        AppLogger.error('Connectivity listener error: $e');
      }
    }
  }
  
  void addListener(Function(bool) listener) {
    _listeners.add(listener);
  }
  
  void removeListener(Function(bool) listener) {
    _listeners.remove(listener);
  }
  
  bool get isOnline => _isOnline;
  
  void dispose() {
    _connectivityCheckTimer?.cancel();
    _listeners.clear();
  }
}

/// Offline data synchronization manager
class OfflineSyncManager {
  static OfflineSyncManager? _instance;
  static OfflineSyncManager get instance => 
      _instance ??= OfflineSyncManager._internal();
  OfflineSyncManager._internal();

  final List<OfflineOperation> _operationQueue = [];
  final SimpleConnectivityManager _connectivity = SimpleConnectivityManager.instance;
  Timer? _syncTimer;
  
  /// Initialize offline sync manager
  Future<void> initialize() async {
    try {
      // Initialize connectivity manager
      await _connectivity.initialize();
      
      // Listen for connectivity changes
      _connectivity.addListener((isOnline) {
        if (isOnline && _operationQueue.isNotEmpty) {
          AppLogger.info('Network connection restored, starting sync');
          _performSync();
        } else if (!isOnline) {
          AppLogger.warning('Network connection lost, entering offline mode');
        }
      });
      
      // Load pending operations from storage
      await _loadPendingOperations();
      
      // Start periodic sync
      _startPeriodicSync();
      
      AppLogger.info('Offline sync manager initialized (online: ${_connectivity.isOnline})');
    } catch (e) {
      AppLogger.error('Offline sync manager initialization failed: $e');
    }
  }
  
  void _startPeriodicSync() {
    _syncTimer = Timer.periodic(const Duration(minutes: 2), (timer) {
      if (_connectivity.isOnline && _operationQueue.isNotEmpty) {
        _performSync();
      }
    });
  }
  
  /// Queue an operation for offline sync
  Future<void> queueOperation(OfflineOperation operation) async {
    _operationQueue.add(operation);
    await _savePendingOperations();
    
    AppLogger.info('Operation queued: ${operation.type} (queue size: ${_operationQueue.length})');
    
    // Try immediate sync if online
    if (_connectivity.isOnline) {
      _performSync();
    }
  }
  
  /// Perform sync of pending operations
  Future<void> _performSync() async {
    if (!_connectivity.isOnline || _operationQueue.isEmpty) return;
    
    AppLogger.info('Starting sync of ${_operationQueue.length} operations');
    final startTime = DateTime.now();
    int successCount = 0;
    int failureCount = 0;
    
    // Process operations in order
    final operationsToRemove = <OfflineOperation>[];
    
    for (final operation in List.from(_operationQueue)) {
      try {
        final success = await _executeOperation(operation);
        if (success) {
          operationsToRemove.add(operation);
          successCount++;
        } else {
          failureCount++;
          // Increment retry count
          operation.retryCount++;
          
          // Remove if max retries exceeded
          if (operation.retryCount >= operation.maxRetries) {
            operationsToRemove.add(operation);
            AppLogger.warning('Operation max retries exceeded: ${operation.type}');
          }
        }
      } catch (e) {
        AppLogger.error('Operation execution failed: ${operation.type} - $e');
        failureCount++;
        operation.retryCount++;
        
        if (operation.retryCount >= operation.maxRetries) {
          operationsToRemove.add(operation);
        }
      }
    }
    
    // Remove completed/failed operations
    for (final operation in operationsToRemove) {
      _operationQueue.remove(operation);
    }
    
    await _savePendingOperations();
    
    final duration = DateTime.now().difference(startTime);
    AppLogger.info('Sync completed: $successCount success, $failureCount failed (${duration.inMilliseconds}ms)');
  }
  
  Future<bool> _executeOperation(OfflineOperation operation) async {
    try {
      // Implement operation execution based on type
      switch (operation.type) {
        case OperationType.locationUpdate:
          return await _syncLocationUpdate(operation);
        case OperationType.alertCreate:
          return await _syncAlertCreate(operation);
        case OperationType.dataUpdate:
          return await _syncDataUpdate(operation);
      }
    } catch (e) {
      AppLogger.error('Operation execution error: $e');
      return false;
    }
  }
  
  Future<bool> _syncLocationUpdate(OfflineOperation operation) async {
    // Implement location update sync
    AppLogger.debug('Syncing location update: ${operation.data}');
    // TODO: Call actual API
    await Future.delayed(const Duration(milliseconds: 100)); // Simulate API call
    return true;
  }
  
  Future<bool> _syncAlertCreate(OfflineOperation operation) async {
    // Implement alert creation sync
    AppLogger.debug('Syncing alert creation: ${operation.data}');
    // TODO: Call actual API
    await Future.delayed(const Duration(milliseconds: 200)); // Simulate API call
    return true;
  }
  
  Future<bool> _syncDataUpdate(OfflineOperation operation) async {
    // Implement data update sync
    AppLogger.debug('Syncing data update: ${operation.data}');
    // TODO: Call actual API
    await Future.delayed(const Duration(milliseconds: 150)); // Simulate API call
    return true;
  }
  
  Future<void> _loadPendingOperations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final operationsJson = prefs.getStringList('pending_operations') ?? [];
      
      _operationQueue.clear();
      for (final json in operationsJson) {
        try {
          final map = jsonDecode(json) as Map<String, dynamic>;
          _operationQueue.add(OfflineOperation.fromJson(map));
        } catch (e) {
          AppLogger.warning('Failed to parse pending operation: $e');
        }
      }
      
      AppLogger.info('Loaded ${_operationQueue.length} pending operations');
    } catch (e) {
      AppLogger.error('Failed to load pending operations: $e');
    }
  }
  
  Future<void> _savePendingOperations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final operationsJson = _operationQueue.map((op) => jsonEncode(op.toJson())).toList();
      await prefs.setStringList('pending_operations', operationsJson);
    } catch (e) {
      AppLogger.error('Failed to save pending operations: $e');
    }
  }
  
  /// Check if currently online
  bool get isOnline => _connectivity.isOnline;
  
  /// Get sync queue size
  int get queueSize => _operationQueue.length;
  
  /// Force sync (if online)
  Future<void> forceSync() async {
    if (_connectivity.isOnline) {
      await _performSync();
    }
  }
  
  /// Clear all pending operations
  Future<void> clearQueue() async {
    _operationQueue.clear();
    await _savePendingOperations();
  }
  
  void dispose() {
    _syncTimer?.cancel();
    _savePendingOperations();
  }
}

/// Offline operation data structure
class OfflineOperation {
  final String id;
  final OperationType type;
  final Map<String, dynamic> data;
  final DateTime timestamp;
  final int priority;
  final int maxRetries;
  int retryCount;
  
  OfflineOperation({
    required this.id,
    required this.type,
    required this.data,
    required this.timestamp,
    this.priority = 1,
    this.maxRetries = 3,
    this.retryCount = 0,
  });
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.toString(),
    'data': data,
    'timestamp': timestamp.toIso8601String(),
    'priority': priority,
    'maxRetries': maxRetries,
    'retryCount': retryCount,
  };
  
  factory OfflineOperation.fromJson(Map<String, dynamic> json) {
    return OfflineOperation(
      id: json['id'],
      type: OperationType.values.firstWhere((e) => e.toString() == json['type']),
      data: Map<String, dynamic>.from(json['data']),
      timestamp: DateTime.parse(json['timestamp']),
      priority: json['priority'] ?? 1,
      maxRetries: json['maxRetries'] ?? 3,
      retryCount: json['retryCount'] ?? 0,
    );
  }
}

enum OperationType {
  locationUpdate,
  alertCreate,
  dataUpdate,
}

/// Progressive data loader with caching
class ProgressiveDataLoader<T> {
  final String cacheKey;
  final Future<T> Function() dataLoader;
  final Duration? cacheValidityDuration;
  final bool useProgressiveLoading;
  
  ProgressiveDataLoader({
    required this.cacheKey,
    required this.dataLoader,
    this.cacheValidityDuration,
    this.useProgressiveLoading = true,
  });
  
  /// Load data with progressive enhancement
  Future<T?> load({
    bool forceRefresh = false,
    void Function(T data)? onCacheData,
    void Function(T data)? onFreshData,
  }) async {
    final cacheManager = OptimizedCacheManager.instance;
    
    if (!forceRefresh) {
      // Try cache first
      final cachedData = await cacheManager.get<T>(
        cacheKey,
        maxAge: cacheValidityDuration,
      );
      
      if (cachedData != null) {
        onCacheData?.call(cachedData);
        
        if (!useProgressiveLoading) {
          return cachedData;
        }
        
        // Return cached data immediately for progressive loading
        _loadFreshDataInBackground(onFreshData);
        return cachedData;
      }
    }
    
    // Load fresh data
    try {
      final freshData = await dataLoader();
      
      // Cache the fresh data
      await cacheManager.set(
        cacheKey,
        freshData,
        ttl: cacheValidityDuration,
      );
      
      onFreshData?.call(freshData);
      return freshData;
    } catch (e) {
      AppLogger.error('Progressive data loading failed: $e');
      
      // Fallback to any cached data if fresh load fails
      return await cacheManager.get<T>(cacheKey);
    }
  }
  
  void _loadFreshDataInBackground(void Function(T data)? onFreshData) {
    Timer(Duration.zero, () async {
      try {
        final freshData = await dataLoader();
        
        // Update cache
        await OptimizedCacheManager.instance.set(
          cacheKey,
          freshData,
          ttl: cacheValidityDuration,
        );
        
        onFreshData?.call(freshData);
      } catch (e) {
        AppLogger.debug('Background data refresh failed: $e');
      }
    });
  }
}