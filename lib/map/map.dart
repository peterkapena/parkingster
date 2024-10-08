import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:parkingster/config.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapStatePage();
}

class _MapStatePage extends State<MapPage> {
  GoogleMapController? _mapController;
  LocationData? _currentLocation;
  final _locationService = Location();
  final _initialCameraPosition =
      const LatLng(-33.918861, 18.423300); // Default to Cape Town
  final FlutterTts flutterTts = FlutterTts();
  final String googleMapsApiKey = Config.googleMapsApiKey;
  final Set<Polyline> _polylines = {};
  final Set<Marker> _markers = {};
  final TextEditingController _destinationController = TextEditingController();
  List<String> _suggestions = [];
  final FocusNode _focusNode = FocusNode();
// Define a controller for the non-editable TextField to show the current location
  final TextEditingController _currentLocationController =
      TextEditingController();
  String _currentLocationName = '';

  @override
  void initState() {
    super.initState();
    _getUserLocation();
    _destinationController.addListener(_onSearchChanged);

    _destinationController.addListener(_onSearchChanged);
  }

  Future<void> _reverseGeocodeLocation(
      double latitude, double longitude) async {
    final String url =
        'https://maps.googleapis.com/maps/api/geocode/json?latlng=$latitude,$longitude&key=$googleMapsApiKey';

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final result = json.decode(response.body);
      if (result['results'].isNotEmpty) {
        setState(() {
          _currentLocationController.text =
              result['results'][0]['formatted_address'];
          _currentLocationName = result['results'][0]['formatted_address'];
        });
      }
    } else {
      if (kDebugMode) {
        print("Failed to fetch address: ${response.body}");
      }
    }
  }

  Future<void> _getUserLocation() async {
    bool serviceEnabled;
    PermissionStatus permissionGranted;

    serviceEnabled = await _locationService.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _locationService.requestService();
      if (!serviceEnabled) {
        return;
      }
    }

    permissionGranted = await _locationService.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await _locationService.requestPermission();
      if (permissionGranted != PermissionStatus.granted) {
        return;
      }
    }

    final locationData = await _locationService.getLocation();
    setState(() {
      _currentLocation = locationData;
    });

    if (_currentLocation != null) {
      _reverseGeocodeLocation(
          _currentLocation!.latitude!, _currentLocation!.longitude!);
    }

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

  void _onSearchChanged() {
    if (_destinationController.text.isNotEmpty) {
      _getAutocompleteSuggestions(_destinationController.text, false);
    } else {
      setState(() {
        _suggestions = [];
      });
    }
  }

  Future<void> _getAutocompleteSuggestions(String input, bool isSource) async {
    final String url =
        'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$input&key=$googleMapsApiKey';

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final result = json.decode(response.body);
      setState(() {
        _suggestions = (result['predictions'] as List<dynamic>)
            .map((prediction) => prediction['description'] as String)
            .toList();
      });
    } else {
      if (kDebugMode) {
        print("Failed to fetch suggestions: ${response.body}");
      }
    }
  }

  Future<void> _searchPlace() async {
    if (_destinationController.text.isEmpty) return;

    String url =
        'https://maps.googleapis.com/maps/api/place/findplacefromtext/json?input=${_destinationController.text}&inputtype=textquery&fields=geometry&key=$googleMapsApiKey';

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final result = json.decode(response.body);
      if (result['candidates'].isNotEmpty) {
        double lat = result['candidates'][0]['geometry']['location']['lat'];
        double lng = result['candidates'][0]['geometry']['location']['lng'];

        if (_currentLocation != null) {
          LatLng start =
              LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!);
          LatLng end = LatLng(lat, lng);
          _getDirections(start, end);

          setState(() {
            _markers.clear();
            _markers.add(
                Marker(markerId: const MarkerId("destination"), position: end));
          });
        }
      } else {
        if (kDebugMode) {
          print("No results found");
        }
      }
    } else {
      if (kDebugMode) {
        print("Failed to fetch place details: ${response.body}");
      }
    }
  }

  Future<void> _getDirections(LatLng start, LatLng end) async {
    String url =
        'https://maps.googleapis.com/maps/api/directions/json?origin=${start.latitude},${start.longitude}&destination=${end.latitude},${end.longitude}&key=$googleMapsApiKey';

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final result = json.decode(response.body);
      if (result['routes'].isNotEmpty) {
        String encodedPolyline =
            result['routes'][0]['overview_polyline']['points'];
        List<LatLng> points = _decodePolyline(encodedPolyline);

        setState(() {
          _polylines.clear();
          _polylines.add(Polyline(
            polylineId: const PolylineId("route"),
            points: points,
            color: Colors.blue,
            width: 5,
          ));
        });

        // Fit the entire polyline into the screen
        LatLngBounds bounds = _calculateBounds(points);
        _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));

        // Optional: Voice directions
        await flutterTts.speak(
            "Head towards your destination. Follow the blue line for directions.");
      }
    } else {
      if (kDebugMode) {
        print("Failed to fetch directions: ${response.body}");
      }
    }
  }

  LatLngBounds _calculateBounds(List<LatLng> points) {
    double? southWestLat, southWestLng, northEastLat, northEastLng;

    for (LatLng point in points) {
      if (southWestLat == null || point.latitude < southWestLat) {
        southWestLat = point.latitude;
      }
      if (southWestLng == null || point.longitude < southWestLng) {
        southWestLng = point.longitude;
      }
      if (northEastLat == null || point.latitude > northEastLat) {
        northEastLat = point.latitude;
      }
      if (northEastLng == null || point.longitude > northEastLng) {
        northEastLng = point.longitude;
      }
    }

    return LatLngBounds(
      southwest: LatLng(southWestLat!, southWestLng!),
      northeast: LatLng(northEastLat!, northEastLng!),
    );
  }

  List<LatLng> _decodePolyline(String polyline) {
    List<LatLng> points = [];
    int index = 0, len = polyline.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = polyline.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = polyline.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }

    return points;
  }

  Future<void> _startNavigation() async {
    if (_currentLocation == null) return;

    // Speak out the initial directions
    await flutterTts
        .speak("Starting navigation. Follow the blue line for directions.");

    // Listen for location updates and move the camera accordingly
    _locationService.onLocationChanged.listen((LocationData locationData) {
      if (_mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(locationData.latitude!, locationData.longitude!),
              zoom: 15,
            ),
          ),
        );

        // Optionally, update marker to represent current location
        setState(() {
          _markers.add(Marker(
            markerId: const MarkerId("current_location"),
            position: LatLng(locationData.latitude!, locationData.longitude!),
            icon:
                BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          ));
        });

        // Optionally, provide real-time spoken directions or alerts
        flutterTts
            .speak("Proceed to your destination. Stay on the blue route.");
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(
            _currentLocationName,
            style: const TextStyle(fontSize: 13),
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  TextField(
                    controller: _destinationController,
                    focusNode: _focusNode,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.location_pin),
                      suffixIcon: IconButton(
                          onPressed: () {
                            setState(() {
                              _destinationController.text = '';
                            });
                          },
                          icon: const Icon(Icons.clear)),
                      hintText: "Enter destination",
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  if (_suggestions.isNotEmpty && _focusNode.hasFocus)
                    SizedBox(
                      height: 150.0,
                      child: ListView.builder(
                        itemCount: _suggestions.length,
                        itemBuilder: (context, index) {
                          return ListTile(
                            title: Text(_suggestions[index]),
                            onTap: () {
                              _destinationController.text = _suggestions[index];
                              setState(() {
                                _suggestions = [];
                              });
                              _focusNode.unfocus();
                              _searchPlace();
                            },
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: _initialCameraPosition,
                  zoom: 10,
                ),
                myLocationEnabled: true,
                markers: _markers,
                polylines: _polylines,
                onMapCreated: (GoogleMapController controller) {
                  _mapController = controller;
                  _getUserLocation();
                },
              ),
            ),
          ],
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
        floatingActionButton: _destinationController.text.isNotEmpty
            ? FloatingActionButton.extended(
                onPressed: _startNavigation,
                label: const Text('Start Navigation'),
                icon: const Icon(Icons.navigation),
              )
            : null);
  }
}
