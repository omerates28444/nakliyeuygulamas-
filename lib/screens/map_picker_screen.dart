import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapPickerScreen extends StatefulWidget {
  const MapPickerScreen({super.key});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  LatLng selectedPoint = LatLng(39.0, 35.0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Konum Seç")),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: selectedPoint,
              initialZoom: 6,
              onTap: (tapPosition, point) {
                setState(() => selectedPoint = point);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                userAgentPackageName: "com.example.nakliyeyg",
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: selectedPoint,
                    width: 40,
                    height: 40,
                    child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: ElevatedButton(
              child: const Text("Konumu Seç"),
              onPressed: () {
                Navigator.pop(context, {
                  "lat": selectedPoint.latitude,
                  "lng": selectedPoint.longitude,
                });
              },
            ),
          )
        ],
      ),
    );
  }
}