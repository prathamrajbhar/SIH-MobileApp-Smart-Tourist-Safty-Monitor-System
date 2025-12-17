import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/broadcast.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../utils/logger.dart';

class BroadcastDetailScreen extends StatefulWidget {
  final Broadcast broadcast;

  const BroadcastDetailScreen({
    super.key,
    required this.broadcast,
  });

  @override
  State<BroadcastDetailScreen> createState() => _BroadcastDetailScreenState();
}

class _BroadcastDetailScreenState extends State<BroadcastDetailScreen> {
  final ApiService _apiService = ApiService();
  final LocationService _locationService = LocationService();
  
  late Broadcast _broadcast;
  bool _isAcknowledging = false;
  String? _selectedStatus;
  final TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _broadcast = widget.broadcast;
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _acknowledgeBroadcast() async {
    if (_selectedStatus == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select your status'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isAcknowledging = true;
    });

    try {
      // Get current location
      final locationInfo = await _locationService.getCurrentLocationWithAddress();
      double? lat;
      double? lon;
      
      if (locationInfo != null) {
        lat = locationInfo['latitude'];
        lon = locationInfo['longitude'];
      }

      final response = await _apiService.acknowledgeBroadcast(
        broadcastId: _broadcast.broadcastId,
        status: _selectedStatus!,
        lat: lat,
        lon: lon,
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
      );

      if (response['success'] == true) {
        setState(() {
          _broadcast = _broadcast.copyWith(isAcknowledged: true);
          _isAcknowledging = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Broadcast acknowledged successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }

        // Close the dialog if open
        if (mounted && Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      } else {
        throw Exception(response['message'] ?? 'Failed to acknowledge');
      }
    } catch (e) {
      AppLogger.service('Failed to acknowledge broadcast: $e', isError: true);
      
      setState(() {
        _isAcknowledging = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to acknowledge: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showAcknowledgmentDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Acknowledge Broadcast'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Let authorities know your status:',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
              _buildStatusOption('safe', '✅ I am safe', Colors.green),
              const SizedBox(height: 8),
              _buildStatusOption('affected', '⚠️ I am affected', Colors.orange),
              const SizedBox(height: 8),
              _buildStatusOption('need_help', '🆘 I need help', Colors.red),
              const SizedBox(height: 16),
              TextField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Additional notes (optional)',
                  hintText: 'Any additional information...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _isAcknowledging ? null : _acknowledgeBroadcast,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E40AF),
              foregroundColor: Colors.white,
            ),
            child: _isAcknowledging
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text('Submit'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusOption(String value, String label, Color color) {
    return InkWell(
      onTap: () {
        setState(() {
          _selectedStatus = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
            color: _selectedStatus == value ? color : Colors.grey.shade300,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(8),
          color: _selectedStatus == value ? color.withValues(alpha: 0.1) : Colors.transparent,
        ),
        child: Row(
          children: [
            Radio<String>(
              value: value,
              groupValue: _selectedStatus,
              onChanged: (newValue) {
                setState(() {
                  _selectedStatus = newValue;
                });
              },
              activeColor: color,
            ),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: _selectedStatus == value 
                      ? FontWeight.bold 
                      : FontWeight.normal,
                  color: _selectedStatus == value ? color : Colors.black,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color severityColor = _getSeverityColor(_broadcast.severity);
    final bool isExpired = _broadcast.isExpired;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Broadcast Details'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Section
            Container(
              color: isExpired 
                  ? Colors.grey.shade200 
                  : severityColor.withValues(alpha: 0.1),
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Text(
                    _broadcast.severityEmoji,
                    style: const TextStyle(fontSize: 64),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _broadcast.title,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isExpired ? Colors.grey : const Color(0xFF0F172A),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    children: [
                      _buildChip(
                        label: _broadcast.severity.toUpperCase(),
                        color: severityColor,
                        isExpired: isExpired,
                      ),
                      _buildChip(
                        label: _broadcast.type.toUpperCase(),
                        color: Colors.blue,
                        isExpired: isExpired,
                      ),
                      if (isExpired)
                        _buildChip(
                          label: 'EXPIRED',
                          color: Colors.grey,
                          isExpired: true,
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // Message Section
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Message',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _broadcast.message,
                    style: TextStyle(
                      fontSize: 16,
                      color: isExpired ? Colors.grey : const Color(0xFF475569),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),

            // Action Required Section
            if (_broadcast.actionRequired != null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  border: Border.all(color: Colors.amber.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.warning_amber, color: Colors.amber),
                        SizedBox(width: 8),
                        Text(
                          'Action Required',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _getActionRequiredText(_broadcast.actionRequired!),
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 16),

            // Details Section
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Details',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildDetailRow('Broadcast ID', _broadcast.broadcastId),
                  if (_broadcast.alertType != null)
                  _buildDetailRow('Alert Type', _broadcast.alertType!),
                  _buildDetailRow(
                    'Sent At',
                    DateFormat('MMM d, y \'at\' h:mm a').format(_broadcast.sentAt),
                  ),
                  if (_broadcast.expiresAt != null)
                    _buildDetailRow(
                      'Expires At',
                      DateFormat('MMM d, y \'at\' h:mm a').format(_broadcast.expiresAt!),
                    ),
                  if (_broadcast.distanceKm != null)
                    _buildDetailRow(
                      'Distance',
                      '${_broadcast.distanceKm!.toStringAsFixed(1)} km from your location',
                    ),
                  _buildDetailRow(
                    'Status',
                    _broadcast.isAcknowledged ? '✅ Acknowledged' : '⏳ Not Acknowledged',
                  ),
                ],
              ),
            ),

            // Acknowledgment Button
            if (!_broadcast.isAcknowledged && !isExpired)
              Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton.icon(
                  onPressed: _showAcknowledgmentDialog,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Acknowledge Broadcast'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E40AF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 32),
          ],
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isExpired ? Colors.grey.shade300 : color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: isExpired ? Colors.grey.shade700 : color,
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
        ],
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

  String _getActionRequiredText(String action) {
    switch (action) {
      case 'evacuate':
        return 'Please evacuate the area immediately and move to a safe location.';
      case 'stay_indoors':
        return 'Stay indoors and avoid going outside until further notice.';
      case 'avoid_area':
        return 'Avoid this area and take an alternative route.';
      case 'follow_instructions':
        return 'Follow instructions from local authorities.';
      default:
        return action;
    }
  }
}
