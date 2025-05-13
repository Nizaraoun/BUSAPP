import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'ably_service.dart';
import 'map_legend.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final Completer<GoogleMapController> _controller = Completer();

  // Default position (can be adjusted to any location)
  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(36.8065, 10.1815), // Tunis, Tunisia coordinates
    zoom: 14.0,
  );

  // Set of markers
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  final Set<Circle> _circles = {};

  // User's current position
  Position? _currentPosition;
  StreamSubscription<Position>? _positionStreamSubscription;

  // For searching locations
  final TextEditingController _searchController = TextEditingController();
  List<Prediction> _searchResults = [];
  bool _isSearching = false;
  // For loading indicators
  bool _isLoadingBusStops = false;
  bool _isLoadingBuses = false;

  // FirebaseFirestore instance
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // AblyService for real-time driver tracking
  final AblyService _ablyService = AblyService();
  StreamSubscription? _driverLocationSubscription;

  // Map of driver IDs to marker IDs for tracking
  final Map<String, String> _driverMarkerIds = {};

  // Map style strings
  String _normalMapStyle = '';
  String _darkMapStyle = '';
  bool _isDarkMode = false;
  @override
  void initState() {
    super.initState();
    // Load map styles
    _loadMapStyles();

    // Request location permission and get current location
    _requestLocationPermission();

    // Load bus stops and buses from Firebase
    _loadBusStopsFromFirebase();
    _loadBusesFromFirebase();

    // Initialize Ably service and subscribe to driver location
    _initializeAblyService();
  }

  @override
  void dispose() {
    // Cancel location subscription when widget is disposed
    _positionStreamSubscription?.cancel();

    // Cancel driver location subscription and disconnect from Ably
    _driverLocationSubscription?.cancel();
    _ablyService.disconnect();

    super.dispose();
  }

  // Request location permission
  Future<void> _requestLocationPermission() async {
    bool serviceEnabled;
    LocationPermission geoPermission; // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Request to enable location services
      await Permission.location.request();
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Location services are still not enabled
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Les services de localisation sont désactivés. Veuillez les activer.'),
        ));
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
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Permission de localisation refusée.'),
          ));
          return;
        }
      }
    }

    if (geoPermission == LocationPermission.deniedForever) {
      // Permission permanently denied, show a dialog suggesting to open settings
      showDialog(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          title: const Text('Permission de localisation requise'),
          content: const Text(
              'La permission de localisation est définitivement refusée. '
              'Veuillez l\'activer dans les paramètres de l\'application.'),
          actions: [
            TextButton(
              child: const Text('Annuler'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Ouvrir les paramètres'),
              onPressed: () {
                Navigator.of(context).pop();
                openAppSettings();
              },
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
          desiredAccuracy: LocationAccuracy.high);

      setState(() {
        _currentPosition = position;

        // Add or update user location marker
        _updateUserLocationMarker(position);

        // Move camera to user's location
        _animateToUserLocation(position);
      });
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
    });
  }

  // Update user location marker
  void _updateUserLocationMarker(Position position) {
    final LatLng latLng = LatLng(position.latitude, position.longitude);

    // Remove old user marker if it exists
    _markers.removeWhere((marker) =>
        marker.markerId ==
        const MarkerId('user_location')); // Add new user marker
    _markers.add(
      Marker(
        markerId: const MarkerId('user_location'),
        position: latLng,
        infoWindow: const InfoWindow(title: 'Votre position'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
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
        strokeColor: Colors.blue.withOpacity(0.5),
        fillColor: Colors.blue.withOpacity(0.1),
      ),
    );
  }

  // Animate camera to user location
  Future<void> _animateToUserLocation(Position position) async {
    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(position.latitude, position.longitude),
          zoom: 16,
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

  // Load bus stops from Firebase
  Future<void> _loadBusStopsFromFirebase() async {
    setState(() {
      _isLoadingBusStops = true;
    });

    try {
      // This is a placeholder. Replace with your actual Firestore collection
      final QuerySnapshot busStopsSnapshot =
          await _firestore.collection('bus_stops').get();

      for (var doc in busStopsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;

        // Check if the document contains latitude and longitude
        if (data.containsKey('latitude') && data.containsKey('longitude')) {
          final double lat = data['latitude'];
          final double lng = data['longitude'];
          final String stopName = data['name'] ?? 'Bus Stop';

          final Marker marker = Marker(
            markerId: MarkerId('stop_${doc.id}'),
            position: LatLng(lat, lng),
            infoWindow: InfoWindow(title: stopName),
            icon:
                BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          );

          setState(() {
            _markers.add(marker);
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading bus stops: $e');
      // Add some default bus stops for demonstration if Firebase data is not available
      _addDefaultBusStops();
    } finally {
      setState(() {
        _isLoadingBusStops = false;
      });
    }
  }

  // Load buses from Firebase
  Future<void> _loadBusesFromFirebase() async {
    setState(() {
      _isLoadingBuses = true;
    });

    try {
      // This is a placeholder. Replace with your actual Firestore collection
      final QuerySnapshot busesSnapshot =
          await _firestore.collection('buses').get();

      for (var doc in busesSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;

        // Check if the document contains latitude and longitude
        if (data.containsKey('latitude') && data.containsKey('longitude')) {
          final double lat = data['latitude'];
          final double lng = data['longitude'];
          final String busNumber = data['number'] ?? 'Unknown';
          final String routeName = data['route'] ?? 'Unknown Route';

          final Marker marker = Marker(
            markerId: MarkerId('bus_${doc.id}'),
            position: LatLng(lat, lng),
            infoWindow: InfoWindow(
              title: 'Bus $busNumber',
              snippet: 'Route: $routeName',
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueGreen),
          );

          setState(() {
            _markers.add(marker);
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading buses: $e');
      // Add some default buses for demonstration if Firebase data is not available
      _addDefaultBuses();
    } finally {
      setState(() {
        _isLoadingBuses = false;
      });
    }
  }

  // Add default bus stops if Firebase data is not available
  void _addDefaultBusStops() {
    final List<Map<String, dynamic>> defaultStops = [
      {
        'id': '1',
        'name': 'Central Station',
        'latitude': 36.8035,
        'longitude': 10.1795,
      },
      {
        'id': '2',
        'name': 'Market Square',
        'latitude': 36.8095,
        'longitude': 10.1835,
      },
      {
        'id': '3',
        'name': 'University',
        'latitude': 36.8025,
        'longitude': 10.1865,
      },
    ];

    for (var stop in defaultStops) {
      final Marker marker = Marker(
        markerId: MarkerId('stop_${stop['id']}'),
        position: LatLng(stop['latitude'], stop['longitude']),
        infoWindow: InfoWindow(title: stop['name']),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      );

      setState(() {
        _markers.add(marker);
      });
    }

    // Add a sample route between bus stops
    final Polyline route = Polyline(
      polylineId: const PolylineId('route_1'),
      points: defaultStops
          .map((stop) => LatLng(stop['latitude'], stop['longitude']))
          .toList(),
      color: Colors.blue,
      width: 5,
    );

    setState(() {
      _polylines.add(route);
    });
  }

  // Add default buses if Firebase data is not available
  void _addDefaultBuses() {
    final List<Map<String, dynamic>> defaultBuses = [
      {
        'id': '1',
        'number': '42',
        'route': 'Central - University',
        'latitude': 36.8045,
        'longitude': 10.1805,
      },
      {
        'id': '2',
        'number': '15',
        'route': 'Market - Downtown',
        'latitude': 36.8085,
        'longitude': 10.1845,
      },
    ];

    for (var bus in defaultBuses) {
      final Marker marker = Marker(
        markerId: MarkerId('bus_${bus['id']}'),
        position: LatLng(bus['latitude'], bus['longitude']),
        infoWindow: InfoWindow(
          title: 'Bus ${bus['number']}',
          snippet: 'Route: ${bus['route']}',
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      );

      setState(() {
        _markers.add(marker);
      });
    }
  }

  // Find nearby bus stops around user's current location
  Future<void> _findNearbyBusStops(double radiusInMeters,
      {bool useDefaults = false}) async {
    if (_currentPosition == null) {
      // Try to get current location first
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Getting your location...'),
        duration: Duration(seconds: 2),
      ));

      try {
        await _getCurrentLocation();
        if (_currentPosition == null) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Unable to get your location. Please try again.'),
            backgroundColor: Colors.red,
          ));
          return;
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error getting location: $e'),
          backgroundColor: Colors.red,
        ));
        return;
      }
    }

    setState(() {
      _isLoadingBusStops = true;
    });

    // Clear previous bus stops but keep user location
    _markers.removeWhere((marker) => marker.markerId.value != 'user_location');

    // Clear previous circles except accuracy circle
    _circles
        .removeWhere((circle) => circle.circleId.value != 'accuracy_circle');

    try {
      // Current user location coordinates
      final double userLat = _currentPosition!.latitude;
      final double userLng = _currentPosition!.longitude;

      // Try Google Places API first
      try {
        await _findNearbyBusStationsWithGoogleAPI(
            userLat, userLng, radiusInMeters);
        return; // If successful, exit the method
      } catch (apiError) {
        debugPrint(
            'Google Places API error: $apiError, falling back to other methods');

        // If API fails, proceed to try Firestore or defaults
        if (!useDefaults) {
          await _findNearbyBusStopsFromFirestore(
              userLat, userLng, radiusInMeters);
        } else {
          _findNearbyDefaultBusStops(radiusInMeters);
        }
      }
    } catch (e) {
      debugPrint('Error finding nearby bus stops: $e');

      if (useDefaults) {
        // Try with default data for demonstration
        _findNearbyDefaultBusStops(radiusInMeters);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error fetching bus stops: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      setState(() {
        _isLoadingBusStops = false;
      });
    }
  }

  // Use Google Places API to find nearby bus stations
  Future<void> _findNearbyBusStationsWithGoogleAPI(
      double lat, double lng, double radiusInMeters) async {
    try {
      // Clear previous bus stops but keep user location
      _markers
          .removeWhere((marker) => marker.markerId.value != 'user_location');

      // Clear previous circles except accuracy circle
      _circles
          .removeWhere((circle) => circle.circleId.value != 'accuracy_circle');

      setState(() {
        _isLoadingBusStops = true;
      });

      // Google Places API key
      final apiKey = 'AIzaSyBQyBRLDvdrrGQk3NT8Sm9c5lX7Nizvj24';

      // Construct the request URL
      final url = 'https://maps.googleapis.com/maps/api/place/nearbysearch/json'
          '?location=$lat,$lng'
          '&radius=$radiusInMeters'
          '&types=bus_station'
          '&key=$apiKey';

      debugPrint('Making API request to: $url');

      // Make the API request
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK') {
          final results = data['results'] as List;
          List<Map<String, dynamic>> nearbyStops = [];

          debugPrint('Found ${results.length} bus stations from API');

          // Process each bus station
          for (var station in results) {
            final stationLat = station['geometry']['location']['lat'];
            final stationLng = station['geometry']['location']['lng'];
            final stationName = station['name'];
            final stationId = station['place_id'];

            // Calculate distance between user and bus station
            double distanceInMeters =
                Geolocator.distanceBetween(lat, lng, stationLat, stationLng);

            // Add marker for the bus station
            final Marker marker = Marker(
              markerId: MarkerId('station_$stationId'),
              position: LatLng(stationLat, stationLng),
              infoWindow: InfoWindow(
                title: stationName,
                snippet:
                    'Distance: ${(distanceInMeters / 3000).toStringAsFixed(2)} km',
              ),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueBlue),
            );

            setState(() {
              _markers.add(marker);
              nearbyStops.add({
                'id': stationId,
                'name': stationName,
                'latitude': stationLat,
                'longitude': stationLng,
                'distance': distanceInMeters,
              });
            });
          }

          // Draw circle to represent search radius
          _circles.add(
            Circle(
              circleId: const CircleId('search_radius'),
              center: LatLng(lat, lng),
              radius: radiusInMeters,
              strokeWidth: 2,
              strokeColor: Colors.green.withOpacity(0.7),
              fillColor: Colors.green.withOpacity(0.1),
            ),
          );

          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Found ${nearbyStops.length} bus stations within ${(radiusInMeters / 3000).toStringAsFixed(2)} km'),
            backgroundColor: Colors.green,
          ));

          // If no stations found, show a message
          if (nearbyStops.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text(
                  'No bus stations found nearby. Try increasing the search radius.'),
              backgroundColor: Colors.orange,
            ));
          }
        } else {
          // API returned an error
          debugPrint(
              'Google Places API error: ${data['status']} - ${data['error_message'] ?? "No detailed error message"}');
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Google Places API error: ${data['status']}'),
            backgroundColor: Colors.red,
          ));
        }
      } else {
        // HTTP error
        debugPrint(
            'HTTP error ${response.statusCode}: ${response.reasonPhrase}');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'HTTP error ${response.statusCode}: ${response.reasonPhrase}'),
          backgroundColor: Colors.red,
        ));
      }
    } catch (e) {
      debugPrint('Error finding nearby bus stations: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error finding nearby bus stations: $e'),
        backgroundColor: Colors.red,
      ));
      // Re-throw to allow fallback to other methods
      rethrow;
    } finally {
      setState(() {
        _isLoadingBusStops = false;
      });
    }
  }

  // Find nearby bus stops from Firestore
  Future<void> _findNearbyBusStopsFromFirestore(
      double userLat, double userLng, double radiusInMeters) async {
    // Get all bus stops from Firebase
    final QuerySnapshot busStopsSnapshot =
        await _firestore.collection('bus_stops').get();

    List<Map<String, dynamic>> nearbyStops = [];

    // For each bus stop, calculate distance and check if it's within the radius
    for (var doc in busStopsSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;

      if (data.containsKey('latitude') && data.containsKey('longitude')) {
        final double stopLat = data['latitude'];
        final double stopLng = data['longitude'];

        // Calculate distance between user and bus stop
        double distanceInMeters =
            Geolocator.distanceBetween(userLat, userLng, stopLat, stopLng);

        // If within radius, add to nearby stops
        if (distanceInMeters <= radiusInMeters) {
          final String stopName = data['name'] ?? 'Bus Stop';

          // Add marker for nearby bus stop
          final Marker marker = Marker(
            markerId: MarkerId('nearby_stop_${doc.id}'),
            position: LatLng(stopLat, stopLng),
            infoWindow: InfoWindow(
              title: stopName,
              snippet:
                  'Distance: ${(distanceInMeters / 3000).toStringAsFixed(2)} km',
            ),
            icon:
                BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          );

          setState(() {
            _markers.add(marker);
            nearbyStops.add({
              'id': doc.id,
              'name': stopName,
              'latitude': stopLat,
              'longitude': stopLng,
              'distance': distanceInMeters,
            });
          });
        }
      }
    }

    // If no nearby stops found in Firestore, use local fallback data
    if (nearbyStops.isEmpty) {
      _findNearbyDefaultBusStops(radiusInMeters);
      return;
    }

    // Draw circle to represent search radius
    _circles.add(
      Circle(
        circleId: const CircleId('search_radius'),
        center: LatLng(userLat, userLng),
        radius: radiusInMeters,
        strokeWidth: 2,
        strokeColor: Colors.green.withOpacity(0.7),
        fillColor: Colors.green.withOpacity(0.1),
      ),
    );

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
          'Found ${nearbyStops.length} bus stops within ${(radiusInMeters / 3000).toStringAsFixed(2)} km'),
      backgroundColor: Colors.green,
    ));
  }

  // Find nearby default bus stops (fallback for demonstration)
  void _findNearbyDefaultBusStops(double radiusInMeters) {
    if (_currentPosition == null) return;

    final double userLat = _currentPosition!.latitude;
    final double userLng = _currentPosition!.longitude;

    // Default bus stops data - positioned around user's location
    final List<Map<String, dynamic>> defaultStops = [];

    List<Map<String, dynamic>> nearbyStops = [];

    for (var stop in defaultStops) {
      final double stopLat = stop['latitude'];
      final double stopLng = stop['longitude'];

      // Calculate distance
      double distanceInMeters =
          Geolocator.distanceBetween(userLat, userLng, stopLat, stopLng);

      // If within radius, add to nearby stops
      if (distanceInMeters <= radiusInMeters) {
        // Add marker
        final Marker marker = Marker(
          markerId: MarkerId('nearby_default_${stop['id']}'),
          position: LatLng(stopLat, stopLng),
          infoWindow: InfoWindow(
            title: stop['name'],
            snippet:
                'Distance: ${(distanceInMeters / 3000).toStringAsFixed(2)} km',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        );

        setState(() {
          _markers.add(marker);
          nearbyStops.add({
            'id': stop['id'],
            'name': stop['name'],
            'latitude': stopLat,
            'longitude': stopLng,
            'distance': distanceInMeters,
          });
        });
      }
    }

    // Draw circle to represent search radius
    _circles.add(
      Circle(
        circleId: const CircleId('search_radius'),
        center: LatLng(userLat, userLng),
        radius: radiusInMeters,
        strokeWidth: 2,
        strokeColor: Colors.green.withOpacity(0.7),
        fillColor: Colors.green.withOpacity(0.1),
      ),
    );

    if (nearbyStops.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'No bus stops found nearby. Try increasing the search radius.'),
        backgroundColor: Colors.orange,
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'Found ${nearbyStops.length} bus stops within ${(radiusInMeters / 3000).toStringAsFixed(2)} km'),
        backgroundColor: Colors.green,
      ));
    }
  }

  // Search for a location
  Future<void> _searchLocation(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      // Skip external API call to geocoding service
      // Instead, directly search bus stops by name
      await _searchBusStops(query);
    } catch (e) {
      debugPrint('Error searching location: $e');
      setState(() {
        _isSearching = false;
      });
    }
  }

  // Search bus stops by name
  Future<void> _searchBusStops(String query) async {
    try {
      final QuerySnapshot busStopsSnapshot =
          await _firestore.collection('bus_stops').get();

      List<Prediction> results = [];

      // First try exact matches
      for (var doc in busStopsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final String stopName = data['name'] ?? '';
        final String stopId = data['id'] ?? '';
        final String stopDescription = data['description'] ?? '';

        // Check for matches in name, ID, or description
        if ((stopName.toLowerCase() == query.toLowerCase() ||
                stopId.toLowerCase() == query.toLowerCase() ||
                stopDescription.toLowerCase() == query.toLowerCase()) &&
            data.containsKey('latitude') &&
            data.containsKey('longitude')) {
          results.add(Prediction(
            placeId: doc.id,
            description: stopName,
            latitude: data['latitude'],
            longitude: data['longitude'],
          ));
        }
      }

      // If no exact matches, try partial matches
      if (results.isEmpty) {
        for (var doc in busStopsSnapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final String stopName = data['name'] ?? '';
          final String stopId = data['id'] ?? '';
          final String stopDescription = data['description'] ?? '';

          // Check for partial matches in name, ID, or description
          if ((stopName.toLowerCase().contains(query.toLowerCase()) ||
                  stopId.toLowerCase().contains(query.toLowerCase()) ||
                  stopDescription
                      .toLowerCase()
                      .contains(query.toLowerCase())) &&
              data.containsKey('latitude') &&
              data.containsKey('longitude')) {
            results.add(Prediction(
              placeId: doc.id,
              description: stopName,
              latitude: data['latitude'],
              longitude: data['longitude'],
            ));
          }
        }
      }

      // If still no results, try local fallback data
      if (results.isEmpty) {
        results = _searchLocalBusStops(query);
      }

      setState(() {
        _searchResults = results;
      });

      // If we got a match, move to the first result
      if (_searchResults.isNotEmpty) {
        _goToSearchResult(_searchResults.first);
      } else {
        // No matches found
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No matching bus stops found.'),
          backgroundColor: Colors.orange,
        ));
      }
    } catch (e) {
      debugPrint('Error searching bus stops: $e');
      // Try local fallback if Firebase fails
      final results = _searchLocalBusStops(query);

      setState(() {
        _searchResults = results;
      });

      if (_searchResults.isNotEmpty) {
        _goToSearchResult(_searchResults.first);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error searching bus stops: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }

  // Search bus stops in local data
  List<Prediction> _searchLocalBusStops(String query) {
    // Local bus stop data for fallback
    final List<Map<String, dynamic>> localBusStops = [];

    List<Prediction> results = [];

    // First try exact matches on name or ID
    for (var stop in localBusStops) {
      final String stopName = stop['name'] ?? '';
      final String stopId = stop['id'] ?? '';

      if (stopName.toLowerCase() == query.toLowerCase() ||
          stopId.toLowerCase() == query.toLowerCase()) {
        results.add(Prediction(
          placeId: stop['id'],
          description: stopName,
          latitude: stop['latitude'],
          longitude: stop['longitude'],
        ));
      }
    }

    // If no exact matches, try partial matches
    if (results.isEmpty) {
      for (var stop in localBusStops) {
        final String stopName = stop['name'] ?? '';
        final String stopId = stop['id'] ?? '';

        if (stopName.toLowerCase().contains(query.toLowerCase()) ||
            stopId.toLowerCase().contains(query.toLowerCase())) {
          results.add(Prediction(
            placeId: stop['id'],
            description: stopName,
            latitude: stop['latitude'],
            longitude: stop['longitude'],
          ));
        }
      }
    }

    return results;
  }

  // Navigate to search result
  Future<void> _goToSearchResult(Prediction prediction) async {
    if (prediction.latitude != null && prediction.longitude != null) {
      final GoogleMapController controller = await _controller.future;

      // Add a marker for the search result
      final LatLng position =
          LatLng(prediction.latitude!, prediction.longitude!);

      // Add a marker for the search result
      _markers.add(
        Marker(
          markerId: MarkerId('search_${prediction.placeId}'),
          position: position,
          infoWindow: InfoWindow(title: prediction.description),
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
        ),
      );

      // Move camera to the search result
      controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: position,
            zoom: 16,
          ),
        ),
      ); // Clear search after navigation
      setState(() {
        _searchResults = [];
        _searchController.clear();
      });
    }
  }

  // Show dialog to add a new bus stop
  Future<void> _showAddBusStopDialog() async {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController latController = TextEditingController();
    final TextEditingController lngController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();

    // If we have current position, pre-fill lat/lng fields
    if (_currentPosition != null) {
      latController.text = _currentPosition!.latitude.toString();
      lngController.text = _currentPosition!.longitude.toString();
    }

    return showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Bus Stop'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Stop Name',
                    hintText: 'Enter stop name',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: latController,
                  decoration: const InputDecoration(
                    labelText: 'Latitude',
                    hintText: 'Enter latitude',
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: lngController,
                  decoration: const InputDecoration(
                    labelText: 'Longitude',
                    hintText: 'Enter longitude',
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    hintText: 'Enter description',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0E2A47),
                  ),
                  child: const Text('Select on Map'),
                  onPressed: () async {
                    // Close dialog temporarily
                    Navigator.of(context).pop();

                    // Show a snackbar with instructions
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text(
                          'Tap on the map to select a location for the bus stop'),
                      duration: Duration(seconds: 3),
                    ));

                    // Add a tap listener to the map (this would need a more complex implementation in a real app)
                    // For now, we'll just wait a bit and then show the dialog again with current location
                    await Future.delayed(const Duration(seconds: 3));
                    if (!context.mounted) return;

                    // Reopen dialog with updated coordinates
                    _showAddBusStopDialog();
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Save'),
              onPressed: () {
                // Validate inputs
                if (nameController.text.isEmpty ||
                    latController.text.isEmpty ||
                    lngController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Please fill all required fields'),
                    backgroundColor: Colors.red,
                  ));
                  return;
                }

                // Parse latitude and longitude
                double? lat = double.tryParse(latController.text);
                double? lng = double.tryParse(lngController.text);

                if (lat == null || lng == null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Invalid latitude or longitude'),
                    backgroundColor: Colors.red,
                  ));
                  return;
                }

                // Add to Firestore with optional description
                _addBusStopToFirestoreWithDescription(
                  nameController.text,
                  lat,
                  lng,
                  description: descriptionController.text,
                );

                // Close dialog
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  // Add a bus stop to Firestore
  Future<void> _addBusStopToFirestoreWithDescription(
      String name, double latitude, double longitude,
      {String description = ''}) async {
    try {
      // Generate a unique ID
      final String id = DateTime.now().millisecondsSinceEpoch.toString();

      // Create data map
      Map<String, dynamic> data = {
        'id': id,
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'createdAt': DateTime.now(),
      };

      // Add description if provided
      if (description.isNotEmpty) {
        data['description'] = description;
      }

      // Add to Firestore
      await _firestore.collection('bus_stops').add(data);

      // Add marker to map
      final Marker marker = Marker(
        markerId: MarkerId('stop_$id'),
        position: LatLng(latitude, longitude),
        infoWindow: InfoWindow(
          title: name,
          snippet: description.isNotEmpty ? description : null,
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      );

      setState(() {
        _markers.add(marker);
      });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Bus stop "$name" added successfully'),
        backgroundColor: Colors.green,
      ));
    } catch (e) {
      debugPrint('Error adding bus stop: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error adding bus stop: $e'),
        backgroundColor: Colors.red,
      ));
    }
  }

  // Method to show dialog for adding a bus stop at a specific location
  void _showAddBusStopAtLocation(LatLng position) {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Bus Stop'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Stop Name',
                  hintText: 'Enter bus stop name',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  hintText: 'Enter description',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              Text(
                'Latitude: ${position.latitude.toStringAsFixed(6)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Longitude: ${position.longitude.toStringAsFixed(6)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          TextButton(
            child: const Text('Save'),
            onPressed: () {
              if (nameController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Please enter a name for the bus stop'),
                  backgroundColor: Colors.red,
                ));
                return;
              }

              // Add bus stop to Firestore
              _addBusStopToFirestore(
                nameController.text,
                position.latitude,
                position.longitude,
                description: descriptionController.text,
              );

              // Close dialog
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  // Add a bus stop to Firestore with optional description
  Future<void> _addBusStopToFirestore(
      String name, double latitude, double longitude,
      {String description = ''}) async {
    try {
      // Generate a unique ID
      final String id = DateTime.now().millisecondsSinceEpoch.toString();

      // Create data map
      Map<String, dynamic> data = {
        'id': id,
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'createdAt': DateTime.now(),
      };

      // Add description if provided
      if (description.isNotEmpty) {
        data['description'] = description;
      }

      // Add to Firestore
      await _firestore.collection('bus_stops').add(data);

      // Add marker to map
      final Marker marker = Marker(
        markerId: MarkerId('stop_$id'),
        position: LatLng(latitude, longitude),
        infoWindow: InfoWindow(
          title: name,
          snippet: description.isNotEmpty ? description : null,
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      );

      setState(() {
        _markers.add(marker);
      });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Bus stop "$name" added successfully'),
        backgroundColor: Colors.green,
      ));
    } catch (e) {
      debugPrint('Error adding bus stop: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error adding bus stop: $e'),
        backgroundColor: Colors.red,
      ));
    }
  }

  // Initialize Ably and subscribe to driver locations
  Future<void> _initializeAblyService() async {
    try {
      // Initialize Ably service
      await _ablyService.initialize();

      // Subscribe to driver location updates (using driverId "1" based on the logs)
      _subscribeToDriverLocation("1");

      debugPrint('Ably service initialized and subscribed to driver locations');
    } catch (e) {
      debugPrint('Error initializing Ably service: $e');
    }
  }

  // Subscribe to a specific driver's location updates
  void _subscribeToDriverLocation(String driverId) {
    print('Subscribing to driver location updates for driver $driverId');
    try {
      _driverLocationSubscription =
          _ablyService.subscribeToDriverLocation(driverId).listen((message) {
        print('Driver location update: $message');
        _updateDriverMarker(message.data);
      });

      debugPrint('Subscribed to location updates for driver $driverId');
    } catch (e) {
      print('Error subscribing to driver location: $e');
      debugPrint('Error subscribing to driver location: $e');
    }
  }

  // Update driver marker on the map
  void _updateDriverMarker(dynamic locationData) {
    if (locationData == null) return;

    try {
      // Convert data to Map if it's not already
      final Map<String, dynamic> data = locationData is Map<String, dynamic>
          ? locationData
          : json.decode(locationData.toString());

      // Extract location data
      final String driverId = data['driverId'].toString();
      final double latitude = double.parse(data['latitude'].toString());
      final double longitude = double.parse(data['longitude'].toString());
      final String status = data['status'].toString();
      final String timestamp = data['timestamp'].toString();

      // Create unique marker ID for this driver
      final String markerId = 'driver-$driverId';
      _driverMarkerIds[driverId] = markerId;

      // Create or update the driver marker
      setState(() {
        // Remove existing marker for this driver if it exists
        _markers.removeWhere((marker) => marker.markerId.value == markerId);

        // Add new marker for driver location
        _markers.add(
          Marker(
            markerId: MarkerId(markerId),
            position: LatLng(latitude, longitude),
            infoWindow: InfoWindow(
              title: 'Driver $driverId',
              snippet:
                  'Status: $status\nLast update: ${_formatTimestamp(timestamp)}',
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueYellow),
          ),
        );
      });

      debugPrint(
          'Updated marker for driver $driverId at $latitude, $longitude');
    } catch (e) {
      debugPrint('Error updating driver marker: $e');
    }
  }

  // Format timestamp for display
  String _formatTimestamp(String timestamp) {
    try {
      final DateTime dateTime = DateTime.parse(timestamp);
      return '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return timestamp;
    }
  }

  // Focus the map on a specific driver's location
  Future<void> _focusOnDriverLocation(String driverId) async {
    // Check if we have a marker for this driver
    final markerId = _driverMarkerIds[driverId];
    if (markerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:
            Text('Driver location not available yet. Waiting for updates...'),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    // Find the marker for this driver
    Marker? driverMarker;
    for (var marker in _markers) {
      if (marker.markerId.value == markerId) {
        driverMarker = marker;
        break;
      }
    }

    // If marker exists, animate to its position
    if (driverMarker != null) {
      final controller = await _controller.future;
      controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: driverMarker.position,
            zoom: 16.0,
          ),
        ),
      );

      // Show the info window for this marker
      controller.showMarkerInfoWindow(driverMarker.markerId);

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Showing driver\'s location'),
        duration: Duration(seconds: 1),
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Driver location not available'),
        backgroundColor: Colors.orange,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Bus Map'),
          backgroundColor: const Color(0xFF0E2A47),
          elevation: 0,
          actions: [
            // Add bus stop button
            IconButton(
              icon: const Icon(Icons.add_location_alt),
              tooltip: 'Add Bus Stop',
              onPressed: () => _showAddBusStopDialog(),
            ),
            // Legend button
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: () => showMapLegend(context),
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  GoogleMap(
                    mapType: MapType.normal,
                    initialCameraPosition: _initialPosition,
                    onMapCreated: (GoogleMapController controller) {
                      _controller.complete(controller);
                      _setInitialMapStyle(controller);
                    },
                    markers: _markers,
                    polylines: _polylines,
                    circles: _circles,
                    myLocationEnabled: true,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: true,
                    compassEnabled: true,
                    onTap: (LatLng position) {
                      // Show dialog to add a bus stop at tapped location
                      _showAddBusStopAtLocation(position);
                    },
                  ),
                  // Loading indicators
                  if (_isLoadingBusStops || _isLoadingBuses)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0E2A47).withOpacity(0.8),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Loading...',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton:
            Column(mainAxisAlignment: MainAxisAlignment.end, children: [
          FloatingActionButton(
            heroTag: 'theme',
            backgroundColor: const Color(0xFF0E2A47),
            onPressed: _toggleMapStyle,
            child: Icon(_isDarkMode ? Icons.light_mode : Icons.dark_mode),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: 'nearby',
            backgroundColor: const Color(0xFF0E2A47),
            child: const Icon(Icons.near_me),
            onPressed: () {
              // Show nearby bus stops within 3000 meters (1 km)
              // Don't use default stations by default (useDefaults=false)
              _findNearbyBusStops(3000, useDefaults: false);
            },
            tooltip: 'Show nearby stations',
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: 'refresh',
            backgroundColor: const Color(0xFF0E2A47),
            child: _isLoadingBusStops || _isLoadingBuses
                ? const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    strokeWidth: 2,
                  )
                : const Icon(Icons.refresh),
            onPressed: () {
              if (_isLoadingBusStops || _isLoadingBuses)
                return; // Prevent multiple reloads

              setState(() {
                // Clear map elements but keep user location
                _markers.removeWhere(
                    (marker) => marker.markerId.value != 'user_location');
                _polylines.clear();
              });
              _loadBusStopsFromFirebase();
              _loadBusesFromFirebase();
            },
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: 'location',
            backgroundColor: const Color(0xFF0E2A47),
            child: const Icon(Icons.my_location),
            onPressed: () async {
              try {
                if (_currentPosition != null) {
                  _animateToUserLocation(_currentPosition!);
                } else {
                  // Show a snackbar while trying to get location
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Getting your location...'),
                    duration: Duration(seconds: 2),
                  ));
                  await _getCurrentLocation();
                }
              } catch (e) {
                // Show error message
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Error getting location: $e'),
                  backgroundColor: Colors.red,
                ));
              }
            },
          ),
          // Add a button to focus on the driver's location
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: 'driver_location',
            backgroundColor: const Color(0xFF0E2A47),
            child: const Icon(Icons.directions_bus),
            onPressed: () {
              _focusOnDriverLocation("1"); // Focus on driver ID 1
            },
          ),
        ]));
  }
}

// A simplified prediction class for location search results
class Prediction {
  final String placeId;
  final String description;
  final double? latitude;
  final double? longitude;

  Prediction({
    required this.placeId,
    required this.description,
    this.latitude,
    this.longitude,
  });
}
