import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/broadcast.dart';
import '../services/api_service.dart';
import '../utils/logger.dart';
import 'broadcast_detail_screen.dart';

class BroadcastScreen extends StatefulWidget {
  const BroadcastScreen({super.key});

  @override
  State<BroadcastScreen> createState() => _BroadcastScreenState();
}

class _BroadcastScreenState extends State<BroadcastScreen> with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  final ApiService _apiService = ApiService();
  late TabController _tabController;
  
  List<Broadcast> _activeBroadcasts = [];
  List<Broadcast> _allBroadcasts = [];
  bool _isLoadingActive = false;
  bool _isLoadingAll = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadActiveBroadcasts();
    _loadAllBroadcasts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadActiveBroadcasts() async {
    setState(() {
      _isLoadingActive = true;
      _errorMessage = null;
    });

    try {
      final response = await _apiService.getActiveBroadcasts();
      
      if (response['success'] == true) {
        final List<dynamic> broadcastsJson = response['active_broadcasts'] ?? [];
        setState(() {
          _activeBroadcasts = broadcastsJson
              .map((json) => Broadcast.fromJson(json))
              .toList();
          _isLoadingActive = false;
        });
        
        AppLogger.service('Loaded ${_activeBroadcasts.length} active broadcasts');
      } else {
        setState(() {
          _isLoadingActive = false;
          _errorMessage = response['message'] ?? 'Failed to load broadcasts';
        });
      }
    } catch (e) {
      AppLogger.service('Failed to load active broadcasts: $e', isError: true);
      setState(() {
        _isLoadingActive = false;
        _errorMessage = 'Failed to load broadcasts. Please try again.';
      });
    }
  }

  Future<void> _loadAllBroadcasts() async {
    setState(() {
      _isLoadingAll = true;
      _errorMessage = null;
    });

    try {
      final response = await _apiService.getAllBroadcasts(limit: 100);
      
      if (response['success'] == true) {
        final List<dynamic> broadcastsJson = response['broadcasts'] ?? [];
        setState(() {
          _allBroadcasts = broadcastsJson
              .map((json) => Broadcast.fromJson(json))
              .toList();
          _isLoadingAll = false;
        });
        
        AppLogger.service('Loaded ${_allBroadcasts.length} total broadcasts');
      } else {
        setState(() {
          _isLoadingAll = false;
          _errorMessage = response['message'] ?? 'Failed to load broadcasts';
        });
      }
    } catch (e) {
      AppLogger.service('Failed to load all broadcasts: $e', isError: true);
      setState(() {
        _isLoadingAll = false;
        _errorMessage = 'Failed to load broadcasts. Please try again.';
      });
    }
  }

  Future<void> _refreshBroadcasts() async {
    if (_tabController.index == 0) {
      await _loadActiveBroadcasts();
    } else {
      await _loadAllBroadcasts();
    }
  }

  void _openBroadcastDetail(Broadcast broadcast) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BroadcastDetailScreen(broadcast: broadcast),
      ),
    ).then((_) {
      // Refresh broadcasts when returning from detail screen
      _refreshBroadcasts();
    });
  }

  @override
  bool get wantKeepAlive => true; // Keep screen alive when switching tabs

  @override
  Widget build(BuildContext context) {
    super.build(context); // Must call super when using AutomaticKeepAliveClientMixin
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Emergency Broadcasts'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF1E40AF),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF1E40AF),
          tabs: const [
            Tab(
              icon: Icon(Icons.notifications_active),
              text: 'Active',
            ),
            Tab(
              icon: Icon(Icons.history),
              text: 'History',
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshBroadcasts,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildActiveBroadcastsTab(),
          _buildAllBroadcastsTab(),
        ],
      ),
    );
  }

  Widget _buildActiveBroadcastsTab() {
    if (_isLoadingActive) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return _buildErrorState(_errorMessage!);
    }

    if (_activeBroadcasts.isEmpty) {
      return _buildEmptyState(
        icon: Icons.notifications_off_outlined,
        title: 'No Active Broadcasts',
        message: 'There are no active emergency broadcasts in your area.',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadActiveBroadcasts,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _activeBroadcasts.length,
        itemBuilder: (context, index) {
          return _buildBroadcastCard(_activeBroadcasts[index]);
        },
      ),
    );
  }

  Widget _buildAllBroadcastsTab() {
    if (_isLoadingAll) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return _buildErrorState(_errorMessage!);
    }

    if (_allBroadcasts.isEmpty) {
      return _buildEmptyState(
        icon: Icons.history,
        title: 'No Broadcast History',
        message: 'You haven\'t received any broadcasts yet.',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAllBroadcasts,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _allBroadcasts.length,
        itemBuilder: (context, index) {
          return _buildBroadcastCard(_allBroadcasts[index]);
        },
      ),
    );
  }

  Widget _buildBroadcastCard(Broadcast broadcast) {
    final Color severityColor = _getSeverityColor(broadcast.severity);
    final bool isExpired = broadcast.isExpired;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isExpired ? Colors.grey.shade300 : severityColor.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: () => _openBroadcastDetail(broadcast),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isExpired 
                          ? Colors.grey.shade200 
                          : severityColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      broadcast.severityEmoji,
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                broadcast.title,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isExpired ? Colors.grey : const Color(0xFF0F172A),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (broadcast.isAcknowledged)
                              const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                                size: 20,
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            _buildChip(
                              label: broadcast.severity.toUpperCase(),
                              color: severityColor,
                              isExpired: isExpired,
                            ),
                            const SizedBox(width: 8),
                            if (broadcast.distanceKm != null)
                              _buildChip(
                                label: '${broadcast.distanceKm!.toStringAsFixed(1)} km away',
                                color: Colors.blue,
                                isExpired: isExpired,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                broadcast.message,
                style: TextStyle(
                  fontSize: 14,
                  color: isExpired ? Colors.grey : const Color(0xFF475569),
                  height: 1.4,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 14,
                        color: isExpired ? Colors.grey : Colors.grey.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatDateTime(broadcast.sentAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: isExpired ? Colors.grey : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  if (isExpired)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'EXPIRED',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChip({
    required String label,
    required Color color,
    bool isExpired = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isExpired ? Colors.grey.shade200 : color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: isExpired ? Colors.grey : color,
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 80,
              color: Colors.red.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'Error',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _refreshBroadcasts,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E40AF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getSeverityColor(String severity) {
    switch (severity) {
      case 'critical':
        return Colors.red;
      case 'high':
        return Colors.orange;
      case 'medium':
        return Colors.amber;
      case 'low':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d, y').format(dateTime);
    }
  }
}
