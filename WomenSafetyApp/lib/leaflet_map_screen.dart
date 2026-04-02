import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:http/http.dart' as http;
import 'route_screen.dart';
import 'app_config.dart';

class LeafletMapScreen extends StatefulWidget {
  final LatLng startLocation;
  final LatLng endLocation;

  const LeafletMapScreen({
    super.key,
    required this.startLocation,
    required this.endLocation,
  });

  @override
  State<LeafletMapScreen> createState() => _LeafletMapScreenState();
}

class _LeafletMapScreenState extends State<LeafletMapScreen> {
  late WebViewController _webViewController;
  String _routeInfo = '';
  bool _isLoading = false;

  String get _geoapifyApiKey => AppConfig.geoapifyApiKey;

  @override
  void initState() {
    super.initState();
    _initializeWebViewController();
    _generateRoute();
  }

  void _initializeWebViewController() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(
        Uri.dataFromString(
          _mapHtml(widget.startLocation, widget.endLocation),
          mimeType: 'text/html',
        ),
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            _generateRoute();
          },
        ),
      );
  }

  Future<void> _generateRoute() async {
    setState(() {
      _isLoading = true;
      _routeInfo = 'Fetching route...';
    });

    try {
      final apiKey = _geoapifyApiKey;
      if (apiKey.isNotEmpty) {
        final String url =
            "https://api.geoapify.com/v1/routing?waypoints=${widget.startLocation.latitude},${widget.startLocation.longitude}|${widget.endLocation.latitude},${widget.endLocation.longitude}&mode=walk&apiKey=$apiKey";
        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final route = data['features'][0];
          final List<dynamic> coordinates = route['geometry']['coordinates'][0];
          final double distance = route['properties']['distance'] / 1000;
          final double durationSeconds = (route['properties']['time'] as num).toDouble();
          final durationMinutes = (durationSeconds / 60).toStringAsFixed(1);

          final coordsJsArray = coordinates.map((coord) => "[${coord[1]}, ${coord[0]}]").toList().join(',');
          final jsRoute = '''
            clearRoute();
            drawRoute([$coordsJsArray]);
          ''';
          await _webViewController.runJavaScript(jsRoute);

          setState(() {
            _routeInfo = 'Route Details:\n'
                '- Distance: ${distance.toStringAsFixed(2)} km\n'
                '- Estimated Time: $durationMinutes minutes (walking)';
            _isLoading = false;
          });
          return;
        }
      }

      // Fallback to OSRM since Geoapify Key may be missing or request failed
      final String osrmUrl = "https://router.project-osrm.org/route/v1/foot/${widget.startLocation.longitude},${widget.startLocation.latitude};${widget.endLocation.longitude},${widget.endLocation.latitude}?geometries=geojson";
      final response = await http.get(Uri.parse(osrmUrl));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['code'] == 'Ok' && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final List<dynamic> coordinates = route['geometry']['coordinates'];
          
          final coordsJsArray = coordinates.map((coord) => "[${coord[1]}, ${coord[0]}]").join(',');

          final double distance = (route['distance'] as num).toDouble() / 1000;
          final double durationSeconds = (route['duration'] as num).toDouble();
          final durationMinutes = (durationSeconds / 60).toStringAsFixed(1);

          final jsRoute = '''
            clearRoute();
            drawRoute([$coordsJsArray]);
          ''';

          await _webViewController.runJavaScript(jsRoute);

          setState(() {
            _routeInfo = 'Route Details:\n'
                '- Distance: ${distance.toStringAsFixed(2)} km\n'
                '- Estimated Time: $durationMinutes minutes (walking)';
            _isLoading = false;
          });
          return;
        }
      }

      setState(() {
        _routeInfo = 'Failed to fetch route. No valid routing provider found.';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _routeInfo = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Route Map',
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
        child: Column(
          children: [
            Expanded(
              child: WebViewWidget(controller: _webViewController),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator()),
                  Text(
                    _routeInfo,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFF5D616A),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _mapHtml(LatLng startLocation, LatLng endLocation) => '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Leaflet Map</title>
  <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css"/>
  <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
  <style>
    body, html { margin: 0; padding: 0; height: 100%; }
    #map { width: 100%; height: 100vh; }
  </style>
</head>
<body>
  <div id="map"></div>
  <script>
    var map = L.map('map').setView([${startLocation.latitude}, ${startLocation.longitude}], 14);
    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', { maxZoom: 19 }).addTo(map);

    var startMarker = L.marker([${startLocation.latitude}, ${startLocation.longitude}]).addTo(map).bindPopup("Start: You are here").openPopup();
    var endMarker = L.marker([${endLocation.latitude}, ${endLocation.longitude}]).addTo(map).bindPopup("Destination");
    var routeLayer = L.layerGroup().addTo(map);

    function clearRoute() {
      routeLayer.clearLayers();
    }

    function drawRoute(coords) {
      var route = L.polyline(coords, { color: 'blue', weight: 5 }).addTo(routeLayer);
      map.fitBounds(route.getBounds());
      startMarker.openPopup(); // Ensure start marker popup is visible
      endMarker.openPopup(); // Ensure end marker popup is visible
    }
  </script>
</body>
</html>
''';
}