# Google Maps Implementation for Bus Tracking

This document explains the implementation of Google Maps in the bus tracking application.

## Features

1. **Real-time Location Tracking**
   - Uses Geolocator to get and track the user's current location
   - Updates location marker in real-time
   - Shows accuracy circle around the user's location

2. **Customized Map Styles**
   - Light theme (default)
   - Dark theme (toggle with button)
   - Styles loaded from JSON files in assets

3. **Bus Stops and Routes**
   - Fetches bus stops from Firebase
   - Displays routes between stops
   - Shows buses on the map
   - Fallback to demo data if Firebase is unavailable

4. **Search Functionality**
   - Search for locations using geocoding
   - Search for bus stops by name
   - Display search results in a list
   - Navigate to selected results

5. **Map Legend**
   - Shows different marker types:
     - Red: Your location
     - Blue: Bus stops
     - Green: Buses
     - Purple: Search results
   - Includes polyline for bus routes
   - Shows accuracy circle information

6. **User Interface**
   - Smooth animations
   - Loading indicators
   - Error handling
   - Location permission management

## Google Maps API Key

The API key is included in:
- Android: `android/app/src/main/AndroidManifest.xml`
- iOS: `ios/Runner/AppDelegate.swift`

**Current API Key:** `AIzaSyBQyBRLDvdrrGQk3NT8Sm9c5lX7Nizvj24`

## Required Permissions

### Android
- `ACCESS_FINE_LOCATION`
- `ACCESS_COARSE_LOCATION`
- `ACCESS_BACKGROUND_LOCATION`
- `INTERNET`

### iOS
- `NSLocationWhenInUseUsageDescription`
- `NSLocationAlwaysUsageDescription`

## Dependencies

- `google_maps_flutter: ^2.10.1`
- `geolocator: ^13.0.1`
- `geocoding: ^3.0.0`
- `permission_handler: ^11.3.0`

## File Structure

- `map.dart`: Main map implementation
- `assets/json/map.json`: Light theme styling
- `assets/json/map_sombre.json`: Dark theme styling

## Known Issues

If you encounter build issues with the geolocator_android plugin, fix by modifying:
- `c:\Users\nizar\AppData\Local\Pub\Cache\hosted\pub.dev\geolocator_android-X.X.X\android\build.gradle`
- Replace `compileSdk flutter.compileSdkVersion` with `compileSdkVersion 33`
- Replace `minSdkVersion flutter.minSdkVersion` with `minSdkVersion 19`
