// filepath: c:\Users\nizar\Desktop\saif\nv busap\BUSAPP\lib\ably_service.dart
import 'package:ably_flutter/ably_flutter.dart' as ably;
import 'package:flutter/foundation.dart';

class AblyService {
  static final AblyService _instance = AblyService._internal();
  static const String _apiKey =
      'ZOjqbw.DlgzTA:uP-qt1q2aE8lc_2qYaLiGTSl_Jumeu2ck72FBI84Y-4';

  ably.Realtime? _realtime;
  ably.RealtimeChannel? _driverLocationChannel;

  // Singleton pattern
  factory AblyService() {
    return _instance;
  }

  AblyService._internal();

  // Initialize Ably client
  Future<void> initialize() async {
    try {
      if (_realtime != null) {
        // If we already have a realtime instance, try to close it first
        try {
          await _realtime!.close();
          _realtime = null;
        } catch (e) {
          debugPrint('Warning: Error closing existing Ably connection: $e');
          // Continue despite error
        }
      }

      final clientOptions = ably.ClientOptions(
        key: _apiKey,
        autoConnect: false, // We'll connect manually
        clientId: 'driver-app-${DateTime.now().millisecondsSinceEpoch}',
      );

      _realtime = ably.Realtime(options: clientOptions);

      // Setup connection state change listener
      _realtime!.connection
          .on()
          .listen((ably.ConnectionStateChange stateChange) {
        debugPrint('Ably connection state changed to: ${stateChange.current}');
      });

      await _realtime!.connect();
      debugPrint('Ably initialized successfully');
    } catch (e) {
      debugPrint('Error initializing Ably: $e');
      rethrow;
    }
  }

  // Get or create a channel for driver location updates
  ably.RealtimeChannel getDriverLocationChannel(String driverId) {
    final channelName = 'driver:$driverId:location';
    _driverLocationChannel = _realtime?.channels.get(channelName);
    print('Driver location channel: $channelName');
    return _driverLocationChannel!;
  }

  // Publish driver location to the channel
  Future<void> publishDriverLocation(
      String driverId, double latitude, double longitude, String status) async {
    try {
      // Check if Ably is initialized
      if (_realtime == null ||
          _realtime!.connection.state != ably.ConnectionState.connected) {
        debugPrint('Reconnecting to Ably before publishing location...');
        await initialize();
      }

      final locationData = {
        'driverId': driverId,
        'latitude': latitude,
        'longitude': longitude,
        'status': status,
        'timestamp': DateTime.now().toIso8601String(),
      };

      final channel = getDriverLocationChannel(driverId);

      // Check channel state and attach if needed
      if (channel.state != ably.ChannelState.attached) {
        await channel.attach();
      }

      await channel.publish(name: 'location-update', data: locationData);

      debugPrint('Published location for driver $driverId: $locationData');
    } catch (e) {
      debugPrint('Error publishing driver location: $e');

      // If we get a MissingPluginException related to resetAblyClients,
      // try to reinitialize Ably from scratch
      if (e.toString().contains('MissingPluginException') &&
          e.toString().contains('resetAblyClients')) {
        debugPrint(
            'Detected resetAblyClients error, recreating Ably connection...');

        // Force disconnect and recreate
        await disconnect();

        // Wait a bit before reconnecting
        await Future.delayed(const Duration(seconds: 1));

        // Try to reconnect
        await initialize();
      }
    }
  }

  // Subscribe to driver location updates
  Stream<ably.Message> subscribeToDriverLocation(String driverId) {
    debugPrint("Subscribing to driver location updates for driver $driverId");
    debugPrint("Subscribing to driver location: driver:$driverId:location");
    if (_realtime == null) {
      throw Exception('Ably not initialized. Call initialize() first.');
    }

    final channel = getDriverLocationChannel(driverId);

    // Make sure the channel is attached before subscribing
    if (channel.state != ably.ChannelState.attached) {
      channel.attach().then((_) {
        debugPrint("Subscribed to location updates for driver $driverId");
      }).catchError((error) {
        debugPrint("Error attaching to channel: $error");
      });
    } else {
      debugPrint("Subscribed to location updates for driver $driverId");
    }

    // Create a stream that logs received messages for debugging
    return channel.subscribe(name: 'location-update').map((message) {
      debugPrint("Received location update: ${message.data}");

      try {
        // Verify data structure is as expected
        final data = message.data as Map<dynamic, dynamic>;
        final lat = data['latitude'];
        final lng = data['longitude'];
        debugPrint("Driver $driverId location: lat=$lat, lng=$lng");
      } catch (e) {
        debugPrint("Error parsing location data: $e");
      }

      return message;
    });
  }

  // New method to get a stream of driver location as map data
  Stream<Map<String, dynamic>> getDriverLocationUpdates(String driverId) {
    debugPrint("Getting location updates for driver $driverId (user app)");

    if (_realtime == null) {
      throw Exception('Ably not initialized. Call initialize() first.');
    }

    final channel = getDriverLocationChannel(driverId);

    // Make sure the channel is attached before subscribing
    if (channel.state != ably.ChannelState.attached) {
      channel.attach().then((_) {
        debugPrint("Attached to location channel for driver $driverId");
      }).catchError((error) {
        debugPrint("Error attaching to channel: $error");
      });
    }

    // Transform the message stream into a more usable format for the map
    return channel.subscribe(name: 'location-update').map((message) {
      debugPrint("User app received location update: ${message.data}");

      try {
        final data = message.data as Map<dynamic, dynamic>;
        // Convert to a consistent Map<String, dynamic> format
        return {
          'driverId': data['driverId']?.toString() ?? '',
          'latitude': data['latitude'] is double ? data['latitude'] : 0.0,
          'longitude': data['longitude'] is double ? data['longitude'] : 0.0,
          'status': data['status']?.toString() ?? 'Unknown',
          'timestamp':
              data['timestamp']?.toString() ?? DateTime.now().toIso8601String(),
        };
      } catch (e) {
        debugPrint("Error parsing driver location data: $e");
        return {
          'driverId': driverId,
          'error': 'Failed to parse location data',
          'timestamp': DateTime.now().toIso8601String(),
        };
      }
    });
  }

  // Disconnect from Ably
  Future<void> disconnect() async {
    try {
      if (_driverLocationChannel != null) {
        try {
          await _driverLocationChannel!.detach();
          _driverLocationChannel = null;
          debugPrint('Detached from driver location channel');
        } catch (e) {
          debugPrint('Warning: Error detaching channel: $e');
          // Continue despite error
        }
      }

      if (_realtime != null) {
        try {
          await _realtime!.close();
          _realtime = null;
          debugPrint('Disconnected from Ably');
        } catch (e) {
          debugPrint('Warning: Error closing Ably connection: $e');
          // We'll still set _realtime to null to force a new instance on next initialize
          _realtime = null;
        }
      }
    } catch (e) {
      debugPrint('Error during Ably disconnect: $e');
      // Ensure _realtime is null to force recreation on next initialize
      _realtime = null;
    }
  }
}
