import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/efir.dart';
import '../models/tourist.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../utils/logger.dart';
import 'efir_success_screen.dart';

class EFIRFormScreen extends StatefulWidget {
  final Tourist tourist;

  const EFIRFormScreen({
    super.key,
    required this.tourist,
  });

  @override
  State<EFIRFormScreen> createState() => _EFIRFormScreenState();
}

class _EFIRFormScreenState extends State<EFIRFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _additionalDetailsController = TextEditingController();
  final _witnessController = TextEditingController();
  
  final ApiService _apiService = ApiService();
  final LocationService _locationService = LocationService();
  
  IncidentType _selectedIncidentType = IncidentType.other;
  DateTime _incidentTimestamp = DateTime.now();
  List<String> _witnesses = [];
  bool _isSubmitting = false;
  bool _useCurrentLocation = true;
  String? _currentLocationText;

  @override
  void initState() {
    super.initState();
    _loadCurrentLocation();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _locationController.dispose();
    _additionalDetailsController.dispose();
    _witnessController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentLocation() async {
    try {
      final position = await _locationService.getCurrentLocation();
      if (position != null && mounted) {
        setState(() {
          _currentLocationText = '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
          if (_useCurrentLocation) {
            _locationController.text = _currentLocationText ?? '';
          }
        });
      }
    } catch (e) {
      AppLogger.error('Failed to get current location: $e');
    }
  }

  void _addWitness() {
    if (_witnessController.text.trim().isNotEmpty) {
      setState(() {
        _witnesses.add(_witnessController.text.trim());
        _witnessController.clear();
      });
    }
  }

  void _removeWitness(int index) {
    setState(() {
      _witnesses.removeAt(index);
    });
  }

  Future<void> _selectDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _incidentTimestamp,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );

    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_incidentTimestamp),
      );

      if (time != null && mounted) {
        setState(() {
          _incidentTimestamp = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  Future<void> _submitEFIR() async {
    if (!_formKey.currentState!.validate()) return;

    // Show confirmation dialog
    final confirmed = await _showConfirmationDialog();
    if (!confirmed) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final response = await _apiService.generateEFIR(
        incidentDescription: _descriptionController.text.trim(),
        incidentType: _selectedIncidentType.name,
        location: _locationController.text.trim().isNotEmpty 
            ? _locationController.text.trim() 
            : null,
        timestamp: _incidentTimestamp,
        witnesses: _witnesses,
        additionalDetails: _additionalDetailsController.text.trim().isNotEmpty 
            ? _additionalDetailsController.text.trim() 
            : null,
      );

      if (mounted) {
        if (response['success'] == true) {
          // Navigate to success screen
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => EFIRSuccessScreen(
                firNumber: response['fir_number'] ?? '',
                referenceNumber: response['reference_number'] ?? '',
                blockchainTxId: response['blockchain_tx_id'] ?? '',
                timestamp: response['timestamp'] ?? '',
                verificationUrl: response['verification_url'],
                tourist: widget.tourist,
              ),
            ),
          );
        } else {
          _showErrorDialog(response['message'] ?? 'Failed to submit E-FIR');
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Failed to submit E-FIR: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<bool> _showConfirmationDialog() async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange),
              SizedBox(width: 8),
              Text('Confirm E-FIR Submission'),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'You are about to submit an Electronic First Information Report.',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              SizedBox(height: 12),
              Text('This report will be:'),
              SizedBox(height: 8),
              Text('• Stored on blockchain (immutable)'),
              Text('• Sent to local authorities'),
              Text('• Used for legal proceedings'),
              SizedBox(height: 12),
              Text(
                'Make sure all information is accurate.',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Submit E-FIR'),
            ),
          ],
        );
      },
    ) ?? false;
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red),
              SizedBox(width: 8),
              Text('Error'),
            ],
          ),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('File E-FIR'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
      ),
      body: _isSubmitting
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Submitting E-FIR...'),
                  SizedBox(height: 8),
                  Text(
                    'Please wait while we process your report',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Important Notice
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.red.shade700),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Important',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red.shade700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'E-FIR reports are stored on blockchain and cannot be modified. For immediate emergencies, use the SOS button.',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Incident Type Selection
                    const Text(
                      'Incident Type',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: IncidentType.values.map((type) {
                        final isSelected = _selectedIncidentType == type;
                        return ChoiceChip(
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(type.icon),
                              const SizedBox(width: 4),
                              Text(type.displayName),
                            ],
                          ),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              _selectedIncidentType = type;
                            });
                          },
                          selectedColor: Colors.red.shade100,
                          backgroundColor: Colors.grey.shade100,
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _selectedIncidentType.description,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Incident Description
                    const Text(
                      'Incident Description *',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 6,
                      maxLength: 5000,
                      decoration: const InputDecoration(
                        hintText: 'Describe what happened in detail...',
                        helperText: 'Be as specific as possible',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please describe the incident';
                        }
                        if (value.trim().length < 20) {
                          return 'Please provide more details (minimum 20 characters)';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Date & Time
                    const Text(
                      'Date & Time of Incident',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: _selectDateTime,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 20),
                            const SizedBox(width: 12),
                            Text(
                              DateFormat('MMM dd, yyyy - hh:mm a')
                                  .format(_incidentTimestamp),
                              style: const TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Location
                    const Text(
                      'Location',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Checkbox(
                          value: _useCurrentLocation,
                          onChanged: (value) {
                            setState(() {
                              _useCurrentLocation = value ?? false;
                              if (_useCurrentLocation && _currentLocationText != null) {
                                _locationController.text = _currentLocationText!;
                              } else {
                                _locationController.clear();
                              }
                            });
                          },
                        ),
                        const Text('Use current location'),
                      ],
                    ),
                    TextFormField(
                      controller: _locationController,
                      enabled: !_useCurrentLocation,
                      decoration: const InputDecoration(
                        hintText: 'Enter location or address',
                        prefixIcon: Icon(Icons.location_on),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Witnesses
                    const Text(
                      'Witnesses (Optional)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _witnessController,
                            decoration: const InputDecoration(
                              hintText: 'Witness name or description',
                            ),
                            onSubmitted: (_) => _addWitness(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: _addWitness,
                          icon: const Icon(Icons.add),
                          label: const Text('Add'),
                        ),
                      ],
                    ),
                    if (_witnesses.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _witnesses.asMap().entries.map((entry) {
                          return Chip(
                            label: Text(entry.value),
                            deleteIcon: const Icon(Icons.close, size: 18),
                            onDeleted: () => _removeWitness(entry.key),
                          );
                        }).toList(),
                      ),
                    ],
                    const SizedBox(height: 24),

                    // Additional Details
                    const Text(
                      'Additional Details (Optional)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _additionalDetailsController,
                      maxLines: 4,
                      maxLength: 2000,
                      decoration: const InputDecoration(
                        hintText: 'Any additional information, evidence, or notes...',
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitEFIR,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade700,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.description),
                            SizedBox(width: 8),
                            Text(
                              'Submit E-FIR',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
    );
  }
}
