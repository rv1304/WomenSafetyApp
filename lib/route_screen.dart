import 'package:flutter/material.dart';
import 'package:location/location.dart' as location;
import 'package:permission_handler/permission_handler.dart' as permission_handler;
import 'leaflet_map_screen.dart';

class RouteScreen extends StatefulWidget {
  const RouteScreen({super.key});

  @override
  State<RouteScreen> createState() => _RouteScreenState();
}

class _RouteScreenState extends State<RouteScreen> {
  final TextEditingController _startController = TextEditingController();
  final TextEditingController _endController = TextEditingController();
  LatLng? _currentLocation;
  String? _selectedStartPlace;

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
      final currentLocation = ModalRoute.of(context)!.settings.arguments as String?;
      if (currentLocation != null) {
        _startController.text = currentLocation;
      }
    });
  }

  Future<void> _fetchLiveLocation() async {
    location.Location locationService = location.Location();
    bool serviceEnabled;
    permission_handler.PermissionStatus permissionGranted;

    // Check if location service is enabled
    serviceEnabled = await locationService.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await locationService.requestService();
      if (!serviceEnabled) {
        setState(() {
          _startController.text = 'Location service disabled.';
        });
        return;
      }
    }

    // Request location permission
    permissionGranted = await permission_handler.Permission.locationWhenInUse.request();
    if (permissionGranted == permission_handler.PermissionStatus.granted) {
      // Fetch location if permission is granted
      location.LocationData locationData = await locationService.getLocation();
      setState(() {
        _currentLocation = LatLng(locationData.latitude!, locationData.longitude!);
        _selectedStartPlace = null; // Clear dropdown selection
        _startController.text = 'Current Location: Lat: ${locationData.latitude}, Lon: ${locationData.longitude}';
      });
    } else {
      setState(() {
        _startController.text = 'Location permission denied.';
      });
    }
  }

  void _navigateToMap() {
    final String destination = _endController.text.trim();

    // Check if a destination is selected
    if (!_chandigarhPlaces.containsKey(destination)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a valid destination.')),
      );
      return;
    }

    // Determine the starting location: either from dropdown or current location
    LatLng startLocation;
    if (_currentLocation != null) {
      startLocation = _currentLocation!;
    } else if (_selectedStartPlace != null && _chandigarhPlaces.containsKey(_selectedStartPlace)) {
      startLocation = _chandigarhPlaces[_selectedStartPlace]!;
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a starting location or use your current location.')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LeafletMapScreen(
          startLocation: startLocation,
          endLocation: _chandigarhPlaces[destination]!,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Route Planner',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFFFFFFFF),
          ),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF5B21B6), Color(0xFF8B5CF6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF3F4F6), Color(0xFFFFFFFF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Plan Your Route',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF020817),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFFFF),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withValues(alpha: 0.2),
                      spreadRadius: 2,
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _startController,
                            decoration: const InputDecoration(
                              labelText: 'Starting Point',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.all(Radius.circular(10)),
                              ),
                              labelStyle: TextStyle(
                                fontSize: 16,
                                color: Color(0xFF5D616A),
                              ),
                            ),
                            enabled: false, // Display-only field
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.my_location, color: Color(0xFF5B21B6)),
                          onPressed: _fetchLiveLocation,
                          tooltip: 'Use Live Location',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Or Select Starting Point',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(10)),
                        ),
                        labelStyle: TextStyle(
                          fontSize: 16,
                          color: Color(0xFF5D616A),
                        ),
                      ),
                      items: _chandigarhPlaces.keys.map((place) {
                        return DropdownMenuItem<String>(
                          value: place,
                          child: Text(place),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedStartPlace = value;
                          _currentLocation = null; // Clear live location if dropdown is used
                          _startController.text = value ?? '';
                        });
                      },
                      value: _selectedStartPlace,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Destination',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(10)),
                        ),
                        labelStyle: TextStyle(
                          fontSize: 16,
                          color: Color(0xFF5D616A),
                        ),
                      ),
                      items: _chandigarhPlaces.keys.map((place) {
                        return DropdownMenuItem<String>(
                          value: place,
                          child: Text(place),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _endController.text = value ?? '';
                        });
                      },
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _navigateToMap,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5B21B6),
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Show Route on Map',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFFFFFFF),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LatLng {
  final double latitude;
  final double longitude;
  LatLng(this.latitude, this.longitude);
}