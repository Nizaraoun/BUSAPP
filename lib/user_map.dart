import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'ably_service.dart';

class DriverLocationMap extends StatefulWidget {
  final String driverId;

  const DriverLocationMap({
    Key? key,
    required this.driverId,
  }) : super(key: key);

  @override
  State<DriverLocationMap> createState() => _DriverLocationMapState();
}

class _DriverLocationMapState extends State<DriverLocationMap> {
  final Completer<GoogleMapController> _controller = Completer();
  final AblyService _ablyService = AblyService();

  // Initial camera position (will be updated with driver's location)
  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(33.8739735, 10.1290892), // Default position
    zoom: 14.0,
  );

  // Marker for the driver's position
  final Map<MarkerId, Marker> _markers = {};
  StreamSubscription? _locationSubscription;
  String _driverStatus = "Unknown";
  String _lastUpdated = "";

  @override
  void initState() {
    super.initState();
    _initializeAbly();
  }

  Future<void> _initializeAbly() async {
    try {
      await _ablyService.initialize();
      _subscribeToDriverLocation();
    } catch (e) {
      debugPrint("Error initializing Ably: $e");
      // Show error to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to connect to location service: $e")),
        );
      }
    }
  }

  void _subscribeToDriverLocation() {
    // Cancel any existing subscription
    _locationSubscription?.cancel();

    // Subscribe to driver location updates
    _locationSubscription = _ablyService
        .getDriverLocationUpdates(widget.driverId)
        .listen(_updateDriverLocation, onError: (error) {
      debugPrint("Error receiving driver location: $error");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Location tracking error: $error")),
        );
      }
    });
  }

  void _updateDriverLocation(Map<String, dynamic> locationData) async {
    if (!mounted) return;

    if (locationData.containsKey('error')) {
      debugPrint("Received error: ${locationData['error']}");
      return;
    }

    final double lat = locationData['latitude'];
    final double lng = locationData['longitude'];
    final String status = locationData['status'];
    final String timestamp = locationData['timestamp'];

    debugPrint("Updating map with driver location: $lat, $lng");

    // Create the marker for driver's position
    final MarkerId markerId = MarkerId(widget.driverId);
    final Marker marker = Marker(
      markerId: markerId,
      position: LatLng(lat, lng),
      infoWindow: InfoWindow(
        title: "Driver ${widget.driverId}",
        snippet: "Status: $status",
      ),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
    );

    setState(() {
      _markers[markerId] = marker;
      _driverStatus = status;
      _lastUpdated = DateTime.parse(timestamp).toLocal().toString();
    });

    // Move camera to driver's position
    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(CameraUpdate.newLatLng(LatLng(lat, lng)));
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Driver ${widget.driverId} Location'),
      ),
      body: Column(
        children: [
          Expanded(
            child: GoogleMap(
              mapType: MapType.normal,
              initialCameraPosition: _initialPosition,
              markers: Set<Marker>.of(_markers.values),
              onMapCreated: (GoogleMapController controller) {
                _controller.complete(controller);
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16.0),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Driver Status: $_driverStatus',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Last Updated: $_lastUpdated',
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
