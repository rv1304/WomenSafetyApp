import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart' as location;
import 'package:permission_handler/permission_handler.dart' as permission_handler;
import 'package:http/http.dart' as http;
import 'dart:convert';

class RouteScreen extends StatefulWidget {
  const RouteScreen({super.key});

  @override
  State<RouteScreen> createState() => _RouteScreenState();
}

class _RouteScreenState extends State<RouteScreen> {
  final MapController _mapController = MapController();
  LatLng? _currentLocation;
  String? _selectedStartPlace;
  String? _selectedEndPlace;

  List<LatLng> _routePoints = [];
  bool _isLoadingRoute = false;
  String _routeInfo = '';

  final Map<String, LatLng> _chandigarhPlaces = {
    'Sector 17': LatLng(30.7398, 76.7821),
    'Rock Garden': LatLng(30.7525, 76.8052),
    'Sukhna Lake': LatLng(30.7421, 76.8188),
    'Rose Garden': LatLng(30.7473, 76.7745),
    'Chandigarh Railway Station': LatLng(30.7046, 76.8207),
    'Elante Mall': LatLng(30.7051, 76.8013),
    'Panjab University': LatLng(30.7612, 76.7698),
    'Sector 22 Market': LatLng(30.7309, 76.7799),
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final passedLocation = ModalRoute.of(context)!.settings.arguments as String?;
      if (passedLocation != null && _chandigarhPlaces.containsKey(passedLocation)) {
        setState(() {
          _selectedStartPlace = passedLocation;
        });
      }
    });
  }

  Future<void> _fetchLiveLocation() async {
    location.Location locationService = location.Location();
    bool serviceEnabled;
    permission_handler.PermissionStatus permissionGranted;

    serviceEnabled = await locationService.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await locationService.requestService();
      if (!serviceEnabled) return;
    }

    permissionGranted = await permission_handler.Permission.locationWhenInUse.request();
    if (permissionGranted == permission_handler.PermissionStatus.granted) {
      location.LocationData locationData = await locationService.getLocation();
      setState(() {
        _currentLocation = LatLng(locationData.latitude!, locationData.longitude!);
        _selectedStartPlace = null;
        _mapController.move(_currentLocation!, 14.0);
      });
    }
  }

  Future<void> _fetchRoute() async {
    if (_selectedEndPlace == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a destination')));
      return;
    }

    LatLng start;
    if (_currentLocation != null) {
      start = _currentLocation!;
    } else if (_selectedStartPlace != null) {
      start = _chandigarhPlaces[_selectedStartPlace]!;
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a starting point')));
      return;
    }

    LatLng end = _chandigarhPlaces[_selectedEndPlace]!;

    setState(() {
      _isLoadingRoute = true;
      _routeInfo = 'Finding route...';
      _routePoints = [];
    });

    final String osrmUrl = "https://router.project-osrm.org/route/v1/foot/\${start.longitude},\${start.latitude};\${end.longitude},\${end.latitude}?geometries=geojson";
    
    try {
      final response = await http.get(Uri.parse(osrmUrl));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['code'] == 'Ok' && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final List<dynamic> coordinates = route['geometry']['coordinates'];
          
          List<LatLng> points = coordinates.map((coord) => LatLng(coord[1], coord[0])).toList();

          final double distance = (route['distance'] as num).toDouble() / 1000;
          final double durationSeconds = (route['duration'] as num).toDouble();
          final durationMinutes = (durationSeconds / 60).toStringAsFixed(1);

          setState(() {
            _routePoints = points;
            _routeInfo = 'Distance: \${distance.toStringAsFixed(2)} km  |  Time: \$durationMinutes min';
            _isLoadingRoute = false;
          });

          // Focus map on the path
          final bounds = LatLngBounds.fromPoints(_routePoints);
          _mapController.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50.0)));
          return;
        }
      }
    } catch (e) {
      print(e);
    }
    
    setState(() {
      _isLoadingRoute = false;
      _routeInfo = 'We are currently in testing phase and our API key limit is exceeded.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Route Planner'),
        backgroundColor: const Color(0xFF5B21B6),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // The Map taking up upper portion of screen
          Expanded(
            flex: 5,
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: const LatLng(30.7333, 76.7794), // Chandigarh
                initialZoom: 12.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.my_app.womensafetyapp',
                ),
                PolylineLayer(
                  polylines: [
                    if (_routePoints.isNotEmpty)
                      Polyline(
                        points: _routePoints,
                        strokeWidth: 4.0,
                        color: Colors.blueAccent,
                      ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    if (_currentLocation != null || _selectedStartPlace != null)
                      Marker(
                        point: _currentLocation ?? _chandigarhPlaces[_selectedStartPlace]!,
                        width: 40,
                        height: 40,
                        child: const Icon(Icons.location_on, color: Colors.green, size: 40),
                      ),
                    if (_selectedEndPlace != null)
                      Marker(
                        point: _chandigarhPlaces[_selectedEndPlace]!,
                        width: 40,
                        height: 40,
                        child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                      ),
                  ],
                ),
              ],
            ),
          ),
          
          // Controls Panel
          Expanded(
            flex: 4,
            child: Container(
              padding: const EdgeInsets.all(16.0),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2))],
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Start Point
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            decoration: const InputDecoration(labelText: 'Starting Point', border: OutlineInputBorder()),
                            value: _selectedStartPlace,
                            items: _chandigarhPlaces.keys.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                            onChanged: (val) {
                              setState(() {
                                _selectedStartPlace = val;
                                _currentLocation = null;
                                _mapController.move(_chandigarhPlaces[val!]!, 14.0);
                              });
                            },
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.my_location, color: Color(0xFF5B21B6), size: 30),
                          onPressed: _fetchLiveLocation,
                          tooltip: 'Use Live Location',
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    // Destination
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'Destination', border: OutlineInputBorder()),
                      value: _selectedEndPlace,
                      items: _chandigarhPlaces.keys.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                      onChanged: (val) => setState(() => _selectedEndPlace = val),
                    ),
                    
                    const SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5B21B6),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _isLoadingRoute ? null : _fetchRoute,
                      child: _isLoadingRoute 
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white))
                        : const Text('Find Route', style: TextStyle(fontSize: 18, color: Colors.white)),
                    ),
                    
                    if (_routeInfo.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.indigo.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _routeInfo, 
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF5B21B6)),
                        ),
                      ),
                    ]
                  ],
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}