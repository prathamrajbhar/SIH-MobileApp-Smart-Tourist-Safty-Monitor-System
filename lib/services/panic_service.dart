import 'dart:async';

import 'api_service.dart';
import 'location_transmission_service.dart';
import '../utils/logger.dart';

/// PanicService is responsible for sending panic alerts to the backend immediately.
/// No cooldown restrictions - tourists can send SOS alerts anytime.
/// Now includes immediate location transmission for emergency response.
class PanicService {
  final ApiService _apiService;
  final LocationTransmissionService _locationService;

  PanicService({ApiService? apiService, LocationTransmissionService? locationService})
      : _apiService = apiService ?? ApiService(),
        _locationService = locationService ?? LocationTransmissionService();

  /// Sends panic alert immediately without any restrictions.
  /// Includes immediate location transmission for emergency response.
  /// Uses proper sequencing to prevent race conditions.
  Future<Map<String, dynamic>> sendPanicAlert() async {
    AppLogger.emergency('🚨 PANIC ALERT TRIGGERED - Sending SOS with location');
    
    try {
      // Initialize services in parallel for speed
      await Future.wait([
        _apiService.initializeAuth(),
        _locationService.initialize(),
      ]);

      // CRITICAL: Send location immediately FIRST and wait for completion
      // This ensures location data is available for emergency response
      Map<String, dynamic>? locationResult;
      bool locationSentSuccessfully = false;
      
      try {
        // Use timeout to prevent blocking SOS alert indefinitely
        locationResult = await _locationService.sendSOSLocation()
            .timeout(const Duration(seconds: 15));
        locationSentSuccessfully = true;
        AppLogger.emergency('✅ Emergency location sent successfully before SOS alert');
      } catch (e) {
        AppLogger.error('❌ Failed to send emergency location: $e');
        locationSentSuccessfully = false;
        // Continue with SOS even if location fails - better than no alert at all
      }

      // Send SOS alert with location status
      final sosResponse = await _apiService.triggerSOS();

      if (sosResponse['success'] == true) {
        final responseData = {
          ...sosResponse,
          'location_sent': locationSentSuccessfully,
          'location_data': locationResult,
          'emergency_timestamp': DateTime.now().toIso8601String(),
          'sequence_completed': true,
        };
        
        AppLogger.emergency('✅ SOS alert sequence completed successfully (location: $locationSentSuccessfully)');
        return responseData;
      }
      
      throw Exception(sosResponse['message'] ?? 'Unknown panic alert failure');
    } catch (e) {
      AppLogger.error('❌ PANIC ALERT SEQUENCE FAILED: $e');
      rethrow;
    }
  }
}
