import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/tourist.dart';
import '../widgets/modern_app_wrapper.dart';


class EFIRSuccessScreen extends StatelessWidget {
  final String firNumber;
  final String referenceNumber;
  final String blockchainTxId;
  final String timestamp;
  final String? verificationUrl;
  final Tourist tourist;

  const EFIRSuccessScreen({
    super.key,
    required this.firNumber,
    required this.referenceNumber,
    required this.blockchainTxId,
    required this.timestamp,
    this.verificationUrl,
    required this.tourist,
  });

  void _copyToClipboard(BuildContext context, String text, String label) {
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
        title: const Text('E-FIR Submitted'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Success Icon
            Center(
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle,
                  size: 80,
                  color: Colors.green.shade700,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Success Message
            const Center(
              child: Text(
                'E-FIR Submitted Successfully!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text(
                'Your report has been filed and stored on blockchain',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 32),

            // FIR Details Card
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'E-FIR Details',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(height: 24),

                    // FIR Number
                    _DetailRow(
                      icon: Icons.description,
                      label: 'FIR Number',
                      value: firNumber,
                      onCopy: () => _copyToClipboard(context, firNumber, 'FIR Number'),
                    ),
                    const SizedBox(height: 16),

                    // Reference Number
                    _DetailRow(
                      icon: Icons.confirmation_number,
                      label: 'Reference Number',
                      value: referenceNumber,
                      onCopy: () => _copyToClipboard(context, referenceNumber, 'Reference Number'),
                    ),
                    const SizedBox(height: 16),

                    // Timestamp
                    _DetailRow(
                      icon: Icons.access_time,
                      label: 'Submitted At',
                      value: _formatTimestamp(timestamp),
                    ),
                    const SizedBox(height: 16),

                    // Blockchain TX
                    _DetailRow(
                      icon: Icons.link,
                      label: 'Blockchain TX ID',
                      value: _truncateTxId(blockchainTxId),
                      onCopy: () => _copyToClipboard(context, blockchainTxId, 'Blockchain TX ID'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Blockchain Verification Card
            Card(
              elevation: 2,
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.verified, color: Colors.blue.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Blockchain Protected',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Your report is cryptographically secured and cannot be tampered with',
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Important Information
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'Important Information',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('• Save your FIR and Reference numbers'),
                  const SizedBox(height: 4),
                  const Text('• Local authorities have been notified'),
                  const SizedBox(height: 4),
                  const Text('• You will be contacted for follow-up'),
                  const SizedBox(height: 4),
                  const Text('• Use reference number for inquiries'),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Action Button
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (context) => ModernAppWrapper(tourist: tourist),
                  ),
                  (route) => false,
                );
              },
              icon: const Icon(Icons.home),
              label: const Text('Go Home'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(String timestamp) {
    try {
      final dateTime = DateTime.parse(timestamp);
      return DateFormat('MMM dd, yyyy - hh:mm a').format(dateTime.toLocal());
    } catch (e) {
      return timestamp;
    }
  }

  String _truncateTxId(String txId) {
    if (txId.length <= 20) return txId;
    return '${txId.substring(0, 10)}...${txId.substring(txId.length - 10)}';
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onCopy;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade700),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        if (onCopy != null)
          IconButton(
            icon: const Icon(Icons.copy, size: 20),
            onPressed: onCopy,
            tooltip: 'Copy',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
      ],
    );
  }
}
