import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart'; // Konum almak için ekledik

class MapPickerScreen extends StatefulWidget {
  const MapPickerScreen({super.key});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  // Başlangıçta Türkiye'nin ortası (Yedek olarak)
  LatLng selectedPoint = const LatLng(39.0, 35.0);

  // Haritayı kontrol etmek için controller ekledik (konum bulununca oraya uçmak için)
  final MapController _mapController = MapController();

  // Konum aranıyor mu?
  bool _isLoadingLocation = true;

  @override
  void initState() {
    super.initState();
    _getUserLocation(); // Ekran açılır açılmaz konumu bulmaya çalış
  }

  // Kullanıcının mevcut konumunu alan fonksiyon
  Future<void> _getUserLocation() async {
    try {
      // Konum servisi açık mı kontrol et
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _isLoadingLocation = false);
        return; // Kapalıysa yedek konumda (39.0, 35.0) kalsın
      }

      // İzinleri kontrol et
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _isLoadingLocation = false);
          return; // İzin verilmediyse yedek konumda kalsın
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() => _isLoadingLocation = false);
        return; // Kalıcı reddedildiyse yedek konumda kalsın
      }

      // İzinler tamamsa mevcut konumu al
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      // Konum bulunduysa haritayı oraya taşı ve seçili noktayı güncelle
      if (mounted) {
        setState(() {
          selectedPoint = LatLng(position.latitude, position.longitude);
          _isLoadingLocation = false;
        });

        // Haritayı kullanıcının konumuna kaydır (Zoom seviyesi 14)
        _mapController.move(selectedPoint, 14.0);
      }
    } catch (e) {
      // Herhangi bir hata olursa yükleniyor yazısını kaldır
      if (mounted) {
        setState(() => _isLoadingLocation = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Konum Seç")),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController, // Controller'ı haritaya bağladık
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

          // Eğer konum aranıyorsa ekranda küçük bir yükleniyor işareti göster
          if (_isLoadingLocation)
            const Positioned(
              top: 20,
              left: 0,
              right: 0,
              child: Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                        SizedBox(width: 10),
                        Text("Konumunuz bulunuyor..."),
                      ],
                    ),
                  ),
                ),
              ),
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