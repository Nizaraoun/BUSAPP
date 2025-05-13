import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'ably_service.dart';

class DriverMapScreen extends StatefulWidget {
  final String driverId; // ID of the driver

  const DriverMapScreen({
    Key? key,
    required this.driverId,
  }) : super(key: key);

  @override
  State<DriverMapScreen> createState() => _DriverMapScreenState();
}

class _DriverMapScreenState extends State<DriverMapScreen> {
  final Completer<GoogleMapController> _controller = Completer();

  // Default position (Tunis, Tunisia coordinates)
  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(36.8065, 10.1815),
    zoom: 14.0,
  );
  // Map elements
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  final Set<Circle> _circles = {};

  // Driver's current position
  Position? _currentPosition;
  StreamSubscription<Position>? _positionStreamSubscription;

  // For loading indicators
  bool _isLoadingRoutes = false;
  bool _isUpdatingStatus = false;

  // For Ably reconnection handling
  bool _reconnectTimerActive = false;
  DateTime? _lastReconnectAttempt;

  // Ably service for real-time location sharing
  final AblyService _ablyService = AblyService();
  bool _isLocationSharingEnabled = false;

  // Map style strings
  String _normalMapStyle = '';
  String _darkMapStyle = '';
  bool _isDarkMode = false;

  // Driver status options - simplified to just On Duty and Off Duty
  final List<String> _statusOptions = [
    'On Duty',
    'Off Duty',
  ];
  String _currentStatus = 'Off Duty'; // Default status

  // Driver's assigned route
  String? _assignedRouteId;
  List<Map<String, dynamic>> _routeStops = [];
  @override
  void initState() {
    super.initState();
    _initializeAbly();

    _loadMapStyles();

    _requestLocationPermission();

  }

  // Initialize Ably service
  Future<void> _initializeAbly() async {
    try {
      await _ablyService.initialize();
      debugPrint('Ably initialized successfully');
    } catch (e) {
      debugPrint('Failed to initialize Ably: $e');
    }
  }

  @override
  void dispose() {
    // Cancel location subscription when widget is disposed
    _positionStreamSubscription?.cancel();
    // Disconnect from Ably
    _ablyService.disconnect();
    super.dispose();
  }

  // Request location permission
  Future<void> _requestLocationPermission() async {
    bool serviceEnabled;
    LocationPermission geoPermission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Request to enable location services
      await Permission.location.request();
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Location services are disabled. Please enable to continue.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    // Check location permission
    geoPermission = await Geolocator.checkPermission();
    if (geoPermission == LocationPermission.denied) {
      // Request location permission from Geolocator
      geoPermission = await Geolocator.requestPermission();

      // If still denied, ask with permission_handler
      if (geoPermission == LocationPermission.denied) {
        await Permission.location.request();
        geoPermission = await Geolocator.checkPermission();
        if (geoPermission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Location permission denied. Features will be limited.'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }
      }
    }

    if (geoPermission == LocationPermission.deniedForever) {
      // Permission permanently denied, show a dialog suggesting to open settings
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Location Permission'),
          content: const Text(
              'Location permission is permanently denied. Please enable in settings.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => openAppSettings(),
              child: const Text('Open Settings'),
            ),
          ],
        ),
      );
      return;
    }

    // Get current position and start location updates
    _getCurrentLocation();
    _startLocationUpdates();
  }

  // Get current location
  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      _currentPosition = position;
      setState(() {
        _animateToUserLocation(position);
      });

      // Update driver location in Firestore and Ably
      _updateDriverLocation(position);
    } catch (e) {
      debugPrint('Error getting current location: $e');
    }
  }

  // Start real-time location updates
  void _startLocationUpdates() {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Update every 10 meters
    );

    _positionStreamSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings)
            .listen((Position position) {
      setState(() {
        _currentPosition = position;
        _updateUserLocationMarker(position);
      });

      // Update driver location in Firestore and Ably if on duty
      _updateDriverLocation(position);
    });
  }

  // Update user location marker
  void _updateUserLocationMarker(Position position) {
    final LatLng latLng = LatLng(position.latitude, position.longitude);

    // Remove old user marker if it exists
    _markers.removeWhere(
        (marker) => marker.markerId == const MarkerId('driver_location'));

    // Add new user marker
    _markers.add(
      Marker(
        markerId: const MarkerId('driver_location'),
        position: latLng,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        infoWindow: InfoWindow(
          title: 'Your Location',
          snippet: 'Status: $_currentStatus',
        ),
      ),
    );

    // Add or update accuracy circle
    _circles.removeWhere(
        (circle) => circle.circleId == const CircleId('accuracy_circle'));
    _circles.add(
      Circle(
        circleId: const CircleId('accuracy_circle'),
        center: latLng,
        radius: position.accuracy,
        strokeWidth: 2,
        strokeColor: Colors.blue,
        fillColor: Colors.blue.withOpacity(0.1),
      ),
    );
  }

  // Update driver location in Ably
  Future<void> _updateDriverLocation(Position position) async {
    try {
      // Publish location to Ably if on duty
      if (_currentStatus == 'On Duty') {
        try {
          await _ablyService.publishDriverLocation(
            widget.driverId,
            position.latitude,
            position.longitude,
            _currentStatus,
          );

          // Update location sharing status
          if (!_isLocationSharingEnabled) {
            setState(() {
              _isLocationSharingEnabled = true;
            });
          }
        } catch (ablyError) {
          debugPrint('Error publishing location to Ably: $ablyError');

          // If specific MissingPluginException for resetAblyClients, try to reconnect
          if (ablyError.toString().contains('MissingPluginException') &&
              ablyError.toString().contains('resetAblyClients')) {
            // Only attempt to reconnect once every 30 seconds to avoid connection storm
            final now = DateTime.now();

            if (!_reconnectTimerActive &&
                (_lastReconnectAttempt == null ||
                    now.difference(_lastReconnectAttempt!).inSeconds > 30)) {
              _reconnectTimerActive = true;
              _lastReconnectAttempt = now;

              try {
                debugPrint('Attempting to reconnect to Ably after error...');
                await _ablyService.disconnect();
                await Future.delayed(const Duration(seconds: 1));
                await _ablyService.initialize();

                // Try again after reconnection
                await _ablyService.publishDriverLocation(
                  widget.driverId,
                  position.latitude,
                  position.longitude,
                  _currentStatus,
                );

                debugPrint('Successfully reconnected to Ably');
              } catch (reconnectError) {
                debugPrint('Failed to reconnect to Ably: $reconnectError');
                // Don't show snackbar here to avoid flooding UI with error messages
              } finally {
                // Reset reconnect timer after 30 seconds
                Future.delayed(const Duration(seconds: 30), () {
                  _reconnectTimerActive = false;
                });
              }
            }
          }
        }
      } else if (_isLocationSharingEnabled) {
        // If off duty, stop sharing location
        setState(() {
          _isLocationSharingEnabled = false;
        });
      }
    } catch (e) {
      debugPrint('Error updating driver location: $e');
    }
  }

  // Animate camera to user location
  Future<void> _animateToUserLocation(Position position) async {
    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(position.latitude, position.longitude),
          zoom: 16.0,
        ),
      ),
    );
  }

  // Load map styles from assets
  Future<void> _loadMapStyles() async {
    _normalMapStyle = await rootBundle.loadString('assets/json/map.json');
    _darkMapStyle = await rootBundle.loadString('assets/json/map_sombre.json');
  }

  // Toggle between light and dark map styles
  Future<void> _toggleMapStyle() async {
    final controller = await _controller.future;
    setState(() {
      _isDarkMode = !_isDarkMode;
    });

    if (_isDarkMode) {
      controller.setMapStyle(_darkMapStyle);
    } else {
      controller.setMapStyle(_normalMapStyle);
    }
  }

  // Set the initial map style when map is created
  Future<void> _setInitialMapStyle(GoogleMapController controller) async {
    if (_isDarkMode) {
      controller.setMapStyle(_darkMapStyle);
    } else {
      controller.setMapStyle(_normalMapStyle);
    }
  }



  Future<void> _updateDriverStatus(String newStatus) async {
    setState(() {
      _isUpdatingStatus = true;
      _currentStatus = newStatus;
    });

    try {
      // Update marker info window with new status
      if (_currentPosition != null) {
        _updateUserLocationMarker(_currentPosition!);

        // If going from Off Duty to On Duty, start publishing location
        if (newStatus == 'On Duty') {
          try {
            await _ablyService.publishDriverLocation(
              widget.driverId,
              _currentPosition!.latitude,
              _currentPosition!.longitude,
              newStatus,
            );

            setState(() {
              _isLocationSharingEnabled = true;
            });

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Location sharing enabled'),
                backgroundColor: Colors.green,
              ),
            );
          } catch (ablyError) {
            debugPrint(
                'Error with Ably while enabling location sharing: $ablyError');

            // Try to reinitialize Ably
            try {
              await _ablyService.disconnect();
              await Future.delayed(const Duration(seconds: 1));
              await _ablyService.initialize();

              // Try again after reinitialization
              await _ablyService.publishDriverLocation(
                widget.driverId,
                _currentPosition!.latitude,
                _currentPosition!.longitude,
                newStatus,
              );

              setState(() {
                _isLocationSharingEnabled = true;
              });

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Location sharing enabled after reconnection'),
                  backgroundColor: Colors.green,
                ),
              );
            } catch (retryError) {
              debugPrint('Failed to reconnect to Ably: $retryError');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content:
                      Text('Failed to enable location sharing: $retryError'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        } else {
          // If going from On Duty to Off Duty, stop publishing location
          setState(() {
            _isLocationSharingEnabled = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location sharing disabled'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error updating driver status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update status: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isUpdatingStatus = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Map'),
        backgroundColor: const Color(0xFF0E2A47),
        actions: [
          // Toggle map style button
          IconButton(
            icon: Icon(_isDarkMode ? Icons.wb_sunny : Icons.brightness_3),
            onPressed: _toggleMapStyle,
            tooltip: 'Toggle Map Style',
          ),
          // Status dropdown
          PopupMenuButton<String>(
            icon: const Icon(Icons.person),
            tooltip: 'Update Status',
            onSelected: _updateDriverStatus,
            itemBuilder: (context) {
              return _statusOptions.map((String status) {
                return PopupMenuItem<String>(
                  value: status,
                  child: Row(
                    children: [
                      Icon(
                        status == _currentStatus ? Icons.check : null,
                        color: Colors.green,
                      ),
                      const SizedBox(width: 8),
                      Text(status),
                    ],
                  ),
                );
              }).toList();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Google Map
          GoogleMap(
            mapType: MapType.normal,
            initialCameraPosition: _initialPosition,
            markers: _markers,
            polylines: _polylines,
            circles: _circles,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: true,
            mapToolbarEnabled: true,
            onMapCreated: (GoogleMapController controller) {
              _controller.complete(controller);
              _setInitialMapStyle(controller);
            },
          ),

          // Loading indicator
          if (_isLoadingRoutes || _isUpdatingStatus)
            const Center(
              child: CircularProgressIndicator(),
            ),

          // Route information panel
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Route: ${_assignedRouteId ?? 'Default Route'}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      if (_isLocationSharingEnabled)
                        const Chip(
                          label: Text('LIVE'),
                          backgroundColor: Colors.green,
                          labelStyle: TextStyle(color: Colors.white),
                          avatar: Icon(Icons.broadcast_on_personal,
                              color: Colors.white, size: 16),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Status: $_currentStatus',
                    style: TextStyle(
                      color: _currentStatus == 'On Duty'
                          ? Colors.green
                          : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Total Stops: ${_routeStops.length}'),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Return to current location
          FloatingActionButton(
            heroTag: 'location',
            child: const Icon(Icons.my_location),
            onPressed: () {
              if (_currentPosition != null) {
                _animateToUserLocation(_currentPosition!);
              } else {
                _getCurrentLocation();
              }
            },
          ),
          const SizedBox(height: 16),
          // View route details
        ],
      ),
    );
  }

  // Show route details dialog
// Navigate to a specific stop
  Future<void> _navigateToStop(Map<String, dynamic> stop) async {
    if (stop.containsKey('latitude') && stop.containsKey('longitude')) {
      final LatLng position = LatLng(stop['latitude'], stop['longitude']);
      final GoogleMapController controller = await _controller.future;

      controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: position,
            zoom: 16.0,
          ),
        ),
      );
    }
  }
}

// Main driver map entry widget for integration into the app
class ChauffeurScreen extends StatelessWidget {
  const ChauffeurScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // In a real app, you would get the driver ID from authentication/state management
    const String driverId = 'driver_123'; // Placeholder driver ID

    return const DriverMapScreen(driverId: driverId);
  }
}
