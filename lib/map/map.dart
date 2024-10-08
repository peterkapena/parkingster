import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
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
  var _durationInHours = 0;
  bool _isNavigating = false;
  StreamSubscription<LocationData>? _locationSubscription;
  String? _reservedBayAddress;

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

          // Format destination as required: "latitude, longitude"
          String formattedDestination = '$lat, $lng';

          // Fetch available parking bays near the destination
          _fetchAvailableBays(formattedDestination);
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

  Future<void> _fetchAvailableBays(String destination) async {
    const query = r'''
  query GetAvailableBays($destination: String!) {
    getAvailableBays(destination: $destination) {
      bayCount
      latitude
      longitude
      parkingSpaceId
    }
  }
  ''';

    final variables = {
      "destination": destination,
    };

    final result = await GraphQLProvider.of(context).value.query(
          QueryOptions(document: gql(query), variables: variables),
        );

    if (result.hasException) {
      if (kDebugMode) {
        print("GraphQL Exception: ${result.exception.toString()}");
      }
    } else {
      final availableBays = result.data?['getAvailableBays'] ?? [];

      if (availableBays.isEmpty) {
        // Show snackbar if no parking bays are available
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "No monitored parking spaces found near your destination. The max distance is 500m.",
            ),
            duration: Duration(seconds: 4),
          ),
        );
        return; // Exit the method as there are no available bays
      }

      List<Map<String, dynamic>> baysWithNames = [];
      for (var bay in availableBays) {
        String address = await _getLocationName(
          bay['latitude'],
          bay['longitude'],
        );
        baysWithNames.add({
          'parkingSpaceId': bay['parkingSpaceId'],
          'bayCount': bay['bayCount'],
          'address': address,
        });
      }
      _showAvailableBaysBottomSheet(baysWithNames);
    }
  }

  Future<String> _getLocationName(double latitude, double longitude) async {
    final String url =
        'https://maps.googleapis.com/maps/api/geocode/json?latlng=$latitude,$longitude&key=$googleMapsApiKey';

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final result = json.decode(response.body);
      if (result['results'].isNotEmpty) {
        return result['results'][0]['formatted_address'];
      }
    }
    return 'Unknown Location';
  }

  void _showAvailableBaysBottomSheet(
    List<Map<String, dynamic>> availableBays,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                "Tap on a parking option below to reserve your bay.",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ),
            Expanded(
              child: ListView.separated(
                separatorBuilder: (context, i) => const Divider(),
                itemCount: availableBays.length,
                itemBuilder: (context, index) {
                  final bay = availableBays[index];
                  return ListTile(
                    title: Text("Parking Space ID: ${bay['parkingSpaceId']}"),
                    subtitle: Text(
                      'Available Bays: ${bay['bayCount']} • Address: ${bay['address']}',
                    ),
                    trailing: const Icon(Icons.arrow_forward, color: Colors.blue),
                    onTap: () {
                      Navigator.pop(context); // Close the bottom sheet
                      _createBooking(bay['parkingSpaceId']);
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _createBooking(String parkingSpaceId) async {
    const mutation = '''
  mutation CreateBooking(\$bookingData: BookingInput!) {
    createBooking(bookingData: \$bookingData) {
      bayNumber
      geoLocation {
        latitude
        longitude
      }
    }
  }
  ''';

    final bookingData = {
      "bookingData": {
        "userId":
            "user123", // Replace this with actual user ID from context/auth.
        "parkingSpaceId": parkingSpaceId,
        "durationInHours":
            _durationInHours, // Use the dynamically calculated duration
      }
    };

    final result = await GraphQLProvider.of(context).value.mutate(
          MutationOptions(document: gql(mutation), variables: bookingData),
        );

    if (result.hasException) {
      if (kDebugMode) {
        print("GraphQL Exception: ${result.exception.toString()}");
      }
    } else {
      // Booking is successful
      if (kDebugMode) {
        print("Booking successful: ${result.data?['createBooking']}");
      }

      // Get geoLocation from the result
      double latitude =
          result.data!['createBooking']['geoLocation']['latitude'];
      double longitude =
          result.data!['createBooking']['geoLocation']['longitude'];

      // Fetch the friendly address of the reserved bay
      String friendlyAddress = await _getLocationName(latitude, longitude);

      setState(() {
        // Update destination controller with the friendly address
        _destinationController.text = friendlyAddress;

        // Store the reserved bay address to display on the UI
        _reservedBayAddress =
            '$friendlyAddress. Bay number: ${result.data!['createBooking']['bayNumber']}';
      });

      // Alternatively, show a snackbar as a toast-like notification
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text("Booking confirmed! Reserved parking at $friendlyAddress"),
          duration: const Duration(seconds: 3),
        ),
      );
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

        // Extract journey duration from the response
        int journeyDurationInMinutes = result['routes'][0]['legs'][0]
                ['duration']['value'] ~/
            60; // Convert seconds to minutes
        int durationInHours = (journeyDurationInMinutes / 60).ceil() +
            1; // Convert to hours and add 1 extra hour

        setState(() {
          _polylines.clear();
          _polylines.add(Polyline(
            polylineId: const PolylineId("route"),
            points: points,
            color: Colors.blue,
            width: 5,
          ));

          // Store the duration for use in booking
          _durationInHours = durationInHours;
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

    setState(() {
      _isNavigating = true;
    });

    // Speak out the initial directions
    await flutterTts
        .speak("Starting navigation. Follow the blue line for directions.");

    // Listen for location updates and move the camera accordingly
    _locationSubscription =
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

  void _stopNavigation({bool arrived = false}) {
    if (_locationSubscription != null) {
      _locationSubscription?.cancel();
      _locationSubscription = null;
    }

    setState(() {
      _isNavigating = false;
      _polylines.clear(); // Clear the navigation route

      // Remove the current location marker (blue icon)
      _markers.removeWhere(
          (marker) => marker.markerId == const MarkerId("current_location"));

      if (arrived) {
        _reservedBayAddress = null; // Clear reserved bay information
      }
    });

    // Provide feedback to the user
    String message =
        arrived ? "You have arrived at your destination!" : "Navigation ended.";
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
      ),
    );
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
                // Display reserved bay information, if available
                if (_reservedBayAddress != null)
                  Card(
                    color: Colors.lightBlueAccent.withOpacity(0.2),
                    elevation: 5,
                    margin: const EdgeInsets.symmetric(vertical: 10.0),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          const Icon(Icons.local_parking, color: Colors.blue),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "Reserved Parking at: $_reservedBayAddress",
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
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
                      icon: const Icon(Icons.clear),
                    ),
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
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.extended(
                  onPressed: _isNavigating
                      ? () => _stopNavigation(arrived: true)
                      : _startNavigation,
                  label: Text(
                      _isNavigating ? 'I Have Arrived' : 'Start Navigation'),
                  icon: Icon(
                      _isNavigating ? Icons.check_circle : Icons.navigation),
                ),
                if (_isNavigating) const SizedBox(height: 10),
                if (_isNavigating)
                  FloatingActionButton.extended(
                    onPressed: () => _stopNavigation(),
                    label: const Text('Cancel Navigation'),
                    icon: const Icon(Icons.cancel),
                    backgroundColor: Colors.redAccent,
                  ),
              ],
            )
          : null,
    );
  }
}
