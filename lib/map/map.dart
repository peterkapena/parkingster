import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapStatePage();
}

class _MapStatePage extends State<MapPage> {
  GoogleMapController? _mapController;
  LocationData? _currentLocation;
  Location _locationService = Location();
  LatLng _initialCameraPosition =
      LatLng(-33.918861, 18.423300); // Default to Cape Town

  @override
  void initState() {
    super.initState();
    _getUserLocation();
  }

  Future<void> _getUserLocation() async {
    bool _serviceEnabled;
    PermissionStatus _permissionGranted;

    // Check if location service is enabled
    _serviceEnabled = await _locationService.serviceEnabled();
    if (!_serviceEnabled) {
      _serviceEnabled = await _locationService.requestService();
      if (!_serviceEnabled) {
        return;
      }
    }

    // Check for permission
    _permissionGranted = await _locationService.hasPermission();
    if (_permissionGranted == PermissionStatus.denied) {
      _permissionGranted = await _locationService.requestPermission();
      if (_permissionGranted != PermissionStatus.granted) {
        return;
      }
    }

    // Get current location
    final locationData = await _locationService.getLocation();
    setState(() {
      _currentLocation = locationData;
    });

    // Move the camera to the current location if available
    if (_mapController != null && _currentLocation != null) {
      _mapController!.animateCamera(CameraUpdate.newCameraPosition(
        CameraPosition(
          target:
              LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!),
          zoom: 15,
        ),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("User Location on Map")),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: _initialCameraPosition,
          zoom: 10,
        ),
        myLocationEnabled: true, // Enable location marker on the map
        onMapCreated: (GoogleMapController controller) {
          _mapController = controller;
          _getUserLocation(); // Get the location once the map is created
        },
      ),
    );
  }
}
