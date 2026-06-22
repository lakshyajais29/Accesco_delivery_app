import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class TrackingData {
  final LatLng position;
  final String etaText;

  TrackingData({required this.position, required this.etaText});

  factory TrackingData.fromJson(Map<String, dynamic> json) {
    return TrackingData(
      position: LatLng(
        (json['lat'] as num?)?.toDouble() ?? 0.0,
        (json['lng'] as num?)?.toDouble() ?? 0.0,
      ),
      etaText: json['eta']?.toString() ?? 'Calculating...',
    );
  }
}

class TrackingService {
  // WebSocketChannel? _channel;

  /// Connects to the backend and returns a stream of tracking updates.
  Stream<TrackingData> connectToTracking(String orderId) {
    // MOCK BANGALORE ROUTE
    final mockLocations = [
      const LatLng(12.9352, 77.6245),
      const LatLng(12.9356, 77.6248),
      const LatLng(12.9360, 77.6252),
      const LatLng(12.9365, 77.6255),
      const LatLng(12.9370, 77.6260),
      const LatLng(12.9375, 77.6265),
      const LatLng(12.9380, 77.6270),
    ];
    int index = 0;

    return Stream.periodic(const Duration(seconds: 3), (_) {
      final currentLoc = mockLocations[index];
      
      final String etaStr;
      if (index == mockLocations.length - 1) {
        etaStr = 'Arrived';
      } else {
        etaStr = '${mockLocations.length - 1 - index} min'; // Keep format "X min" to trigger checklist at 2 min
      }
      
      if (index < mockLocations.length - 1) {
        index++;
      }
      
      return TrackingData(
        position: currentLoc,
        etaText: etaStr,
      );
    });

    /*
    final wsUrl = Uri.parse('ws://10.0.2.2:8001/ws/tracking/$orderId');
    _channel = WebSocketChannel.connect(wsUrl);

    return _channel!.stream.map((event) {
      if (event is String) {
        try {
          final data = jsonDecode(event) as Map<String, dynamic>;
          return TrackingData.fromJson(data);
        } catch (e) {
          // Fallback if parsing fails
          return TrackingData(
            position: const LatLng(0, 0),
            etaText: 'Connection active...',
          );
        }
      }
      return TrackingData(
        position: const LatLng(0, 0),
        etaText: 'Waiting for updates...',
      );
    });
    */
  }

  void disconnect() {
    // _channel?.sink.close();
  }
}
