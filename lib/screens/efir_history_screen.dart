import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/efir.dart';
import '../models/tourist.dart';
import '../services/api_service.dart';
import '../utils/logger.dart';

class EFIRHistoryScreen extends StatefulWidget {
  final Tourist tourist;

  const EFIRHistoryScreen({
    super.key,
    required this.tourist,
  });

  @override
  State<EFIRHistoryScreen> createState() => _EFIRHistoryScreenState();
}

class _EFIRHistoryScreenState extends State<EFIRHistoryScreen> {
  final ApiService _apiService = ApiService();
  List<EFIR> _efirList = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadEFIRHistory();
  }

  Future<void> _loadEFIRHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _apiService.getEFIRHistory();
      
      if (response['success'] == true) {
        final efirData = response['efirs'] as List;
        setState(() {
          _efirList = efirData.map((json) => EFIR.fromJson(json)).toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = response['message'] ?? 'Failed to load E-FIR history';
          _isLoading = false;
        });
      }
    } catch (e) {
      AppLogger.error('Failed to load E-FIR history: $e');
      setState(() {
        _errorMessage = 'Failed to load E-FIR history. Please try again.';
        _isLoading = false;
      });
    }
  }

  void _showEFIRDetails(EFIR efir) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _EFIRDetailsSheet(efir: efir),
    );
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard'),
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('E-FIR History'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading E-FIR history...'),
                ],
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red.shade300,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _loadEFIRHistory,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _efirList.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.description_outlined,
                            size: 80,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No E-FIRs filed yet',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Your filed reports will appear here',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadEFIRHistory,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _efirList.length,
                        itemBuilder: (context, index) {
                          final efir = _efirList[index];
                          return _EFIRCard(
                            efir: efir,
                            onTap: () => _showEFIRDetails(efir),
                            onCopy: (text, label) => _copyToClipboard(text, label),
                          );
                        },
                      ),
                    ),
    );
  }
}

class _EFIRCard extends StatelessWidget {
  final EFIR efir;
  final VoidCallback onTap;
  final Function(String text, String label) onCopy;

  const _EFIRCard({
    required this.efir,
    required this.onTap,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
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
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      efir.incidentType.icon,
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          efir.incidentType.displayName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('MMM dd, yyyy - hh:mm a').format(efir.timestamp.toLocal()),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _StatusBadge(status: efir.status),
                ],
              ),
              const Divider(height: 24),
              Text(
                efir.incidentDescription.length > 100
                    ? '${efir.incidentDescription.substring(0, 100)}...'
                    : efir.incidentDescription,
                style: const TextStyle(fontSize: 14),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              if (efir.firNumber != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.confirmation_number, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        efir.firNumber!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 16),
                      onPressed: () => onCopy(efir.firNumber!, 'FIR Number'),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final EFIRStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case EFIRStatus.draft:
        color = Colors.grey;
        break;
      case EFIRStatus.submitted:
        color = Colors.blue;
        break;
      case EFIRStatus.acknowledged:
        color = Colors.orange;
        break;
      case EFIRStatus.resolved:
        color = Colors.green;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        status.displayName,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _EFIRDetailsSheet extends StatelessWidget {
  final EFIR efir;

  const _EFIRDetailsSheet({required this.efir});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    const Text(
                      'E-FIR Details',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Incident Type
                      _DetailSection(
                        icon: Icons.category,
                        label: 'Incident Type',
                        value: '${efir.incidentType.icon} ${efir.incidentType.displayName}',
                      ),
                      const SizedBox(height: 16),

                      // Description
                      _DetailSection(
                        icon: Icons.description,
                        label: 'Description',
                        value: efir.incidentDescription,
                      ),
                      const SizedBox(height: 16),

                      // Date & Time
                      _DetailSection(
                        icon: Icons.access_time,
                        label: 'Date & Time',
                        value: DateFormat('MMMM dd, yyyy - hh:mm a').format(efir.timestamp.toLocal()),
                      ),
                      const SizedBox(height: 16),

                      // Location
                      if (efir.location != null) ...[
                        _DetailSection(
                          icon: Icons.location_on,
                          label: 'Location',
                          value: efir.location!,
                        ),
                        const SizedBox(height: 16),
                      ],

                      // FIR Number
                      if (efir.firNumber != null) ...[
                        _DetailSection(
                          icon: Icons.confirmation_number,
                          label: 'FIR Number',
                          value: efir.firNumber!,
                          copyable: true,
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Reference Number
                      if (efir.referenceNumber != null) ...[
                        _DetailSection(
                          icon: Icons.bookmark,
                          label: 'Reference Number',
                          value: efir.referenceNumber!,
                          copyable: true,
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Blockchain TX ID
                      if (efir.blockchainTxId != null) ...[
                        _DetailSection(
                          icon: Icons.link,
                          label: 'Blockchain TX ID',
                          value: efir.blockchainTxId!,
                          copyable: true,
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Witnesses
                      if (efir.witnesses.isNotEmpty) ...[
                        const Text(
                          'Witnesses',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...efir.witnesses.map((witness) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              const Icon(Icons.person, size: 16),
                              const SizedBox(width: 8),
                              Text(witness),
                            ],
                          ),
                        )),
                        const SizedBox(height: 16),
                      ],

                      // Additional Details
                      if (efir.additionalDetails != null && efir.additionalDetails!.isNotEmpty) ...[
                        _DetailSection(
                          icon: Icons.notes,
                          label: 'Additional Details',
                          value: efir.additionalDetails!,
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Status
                      _DetailSection(
                        icon: Icons.flag,
                        label: 'Status',
                        value: efir.status.displayName,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DetailSection extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool copyable;

  const _DetailSection({
    required this.icon,
    required this.label,
    required this.value,
    this.copyable = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: Colors.grey.shade600),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                value,
                style: const TextStyle(fontSize: 15),
              ),
            ),
            if (copyable)
              IconButton(
                icon: const Icon(Icons.copy, size: 18),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: value));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('$label copied'),
                      duration: const Duration(seconds: 2),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
          ],
        ),
      ],
    );
  }
}
