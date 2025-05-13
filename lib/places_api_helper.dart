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
import 'map_legend.dart';

// Function to find nearby bus stations using Google Places API
Future<void> findNearbyBusStationsWithGoogleAPI(
    double lat,
    double lng,
    double radiusInMeters,
    Function setState,
    Set<Marker> markers,
    Set<Circle> circles,
    BuildContext context,
    bool isLoadingBusStops) async {
  try {
    // Clear previous bus stops but keep user location
    markers.removeWhere((marker) => marker.markerId.value != 'user_location');

    // Clear previous circles except accuracy circle
    circles.removeWhere((circle) => circle.circleId.value != 'accuracy_circle');

    setState(() {
      isLoadingBusStops = true;
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
                  'Distance: ${(distanceInMeters / 1000).toStringAsFixed(2)} km',
            ),
            icon:
                BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          );

          setState(() {
            markers.add(marker);
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
        circles.add(
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
              'Found ${nearbyStops.length} bus stations within ${(radiusInMeters / 1000).toStringAsFixed(2)} km'),
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
      debugPrint('HTTP error ${response.statusCode}: ${response.reasonPhrase}');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
            Text('HTTP error ${response.statusCode}: ${response.reasonPhrase}'),
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
      isLoadingBusStops = false;
    });
  }
}
