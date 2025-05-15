import 'dart:async';

import 'package:ably_flutter/ably_flutter.dart' as ably;
import 'package:flutter/foundation.dart';

class AblyService {
  static final AblyService _instance = AblyService._internal();
  static const String _apiKey =
      'ZOjqbw.DlgzTA:uP-qt1q2aE8lc_2qYaLiGTSl_Jumeu2ck72FBI84Y-4';

  ably.Realtime? _realtime;
  final Map<String, ably.RealtimeChannel> _channelCache = {};

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
          _channelCache.clear(); // Clear channel cache when closing connection
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
        
        // If reconnected, reattach all channels
        if (stateChange.current == ably.ConnectionState.connected &&
            stateChange.previous == ably.ConnectionState.disconnected) {
          _reattachAllChannels();
        }
      });

      await _realtime!.connect();
      debugPrint('Ably initialized successfully');
    } catch (e) {
      debugPrint('Error initializing Ably: $e');
      rethrow;
    }
  }

  // Reattach all channels after reconnection
  Future<void> _reattachAllChannels() async {
    for (final channelName in _channelCache.keys) {
      try {
        final channel = _channelCache[channelName];
        if (channel != null && channel.state != ably.ChannelState.attached) {
          debugPrint('Reattaching channel: $channelName');
          await channel.attach();
        }
      } catch (e) {
        debugPrint('Error reattaching channel $channelName: $e');
      }
    }
  }

  // Get or create a channel for driver location updates
  ably.RealtimeChannel getDriverLocationChannel(String driverId) {
    if (_realtime == null) {
      throw Exception('Ably not initialized. Call initialize() first.');
    }
    
    final channelName = 'driver:$driverId:location';
    
    // Return from cache if exists
    if (_channelCache.containsKey(channelName)) {
      return _channelCache[channelName]!;
    }
    
    // Create and cache new channel
    final channel = _realtime!.channels.get(channelName);
    _channelCache[channelName] = channel;
    
    debugPrint('Created driver location channel: $channelName');
    return channel;
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
  Stream<ably.Message> subscribeToDriverLocation(String driverId) async* {
    debugPrint("Subscribing to driver location updates for driver $driverId");
    
    if (_realtime == null) {
      throw Exception('Ably not initialized. Call initialize() first.');
    }

    final channel = getDriverLocationChannel(driverId);

    // Use a completer to handle the asynchronous attachment process
    final completer = Completer<void>();
    
    // Make sure the channel is attached before subscribing
    if (channel.state != ably.ChannelState.attached) {
      debugPrint("Attaching to channel for driver $driverId");
      
      // Listen for state changes to detect when attached
      final subscription = channel.on().listen((ably.ChannelStateChange stateChange) {
        debugPrint("Channel state changed to: ${stateChange.current}");
        if (stateChange.current == ably.ChannelState.attached && !completer.isCompleted) {
          completer.complete();
        } else if (stateChange.current == ably.ChannelState.failed && !completer.isCompleted) {
          completer.completeError("Channel attachment failed");
        }
      });
      
      // Start attachment process
      channel.attach().then((_) {
        debugPrint("Channel attached for driver $driverId");
        if (!completer.isCompleted) completer.complete();
      }).catchError((error) {
        debugPrint("Error attaching to channel: $error");
        if (!completer.isCompleted) completer.completeError(error);
      });
      
      // Wait for attachment or error
      try {
        await completer.future.timeout(const Duration(seconds: 10));
        subscription.cancel();
      } catch (e) {
        subscription.cancel();
        debugPrint("Failed to attach to channel: $e");
        throw Exception("Failed to subscribe to driver location: $e");
      }
    } else {
      debugPrint("Channel already attached for driver $driverId");
    }

    // Create the subscription and transform the stream
    final controller = StreamController<ably.Message>();
    
    final messageSubscription = channel.subscribe(name: 'location-update')
      .listen((message) {
        debugPrint("Received location update: ${message.data}");
        
        try {
          // Verify data structure is as expected
          final data = message.data as Map<dynamic, dynamic>;
          final lat = data['latitude'];
          final lng = data['longitude'];
          debugPrint("Driver $driverId location: lat=$lat, lng=$lng");
          controller.add(message);
        } catch (e) {
          debugPrint("Error parsing location data: $e");
          // Still add the message to the stream, let consumer handle it
          controller.add(message);
        }
      }, onError: (error) {
        debugPrint("Error in location subscription: $error");
        controller.addError(error);
      }, onDone: () {
        debugPrint("Location subscription closed");
        controller.close();
      });
    
    // Handle stream controller disposal
    controller.onCancel = () {
      debugPrint("Cancelling location subscription for driver $driverId");
      messageSubscription.cancel();
    };
    
    yield* controller.stream;
  }

  // Get a stream of driver location as map data
  Stream<Map<String, dynamic>> getDriverLocationUpdates(String driverId) async* {
    debugPrint("Getting location updates for driver $driverId (user app)");

    try {
      await for (final message in subscribeToDriverLocation(driverId)) {
        try {
          final data = message.data as Map<dynamic, dynamic>;
          // Convert to a consistent Map<String, dynamic> format
          yield {
            'driverId': data['driverId']?.toString() ?? '',
            'latitude': data['latitude'] is double ? data['latitude'] : 0.0,
            'longitude': data['longitude'] is double ? data['longitude'] : 0.0,
            'status': data['status']?.toString() ?? 'Unknown',
            'timestamp': data['timestamp']?.toString() ?? DateTime.now().toIso8601String(),
          };
        } catch (e) {
          debugPrint("Error parsing driver location data: $e");
          yield {
            'driverId': driverId,
            'error': 'Failed to parse location data',
            'timestamp': DateTime.now().toIso8601String(),
          };
        }
      }
    } catch (e) {
      debugPrint("Error in getDriverLocationUpdates: $e");
      yield {
        'driverId': driverId,
        'error': 'Subscription error: $e',
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  // Disconnect from Ably
  Future<void> disconnect() async {
    try {
      // Detach all channels first
      for (final channelName in _channelCache.keys) {
        try {
          final channel = _channelCache[channelName];
          if (channel != null && channel.state == ably.ChannelState.attached) {
            await channel.detach();
            debugPrint('Detached from channel: $channelName');
          }
        } catch (e) {
          debugPrint('Warning: Error detaching channel $channelName: $e');
        }
      }
      
      _channelCache.clear();

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