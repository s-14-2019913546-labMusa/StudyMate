import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math' as math;

class QiblaCompassScreen extends StatefulWidget {
  const QiblaCompassScreen({super.key});

  @override
  State<QiblaCompassScreen> createState() => _QiblaCompassScreenState();
}

class _QiblaCompassScreenState extends State<QiblaCompassScreen> {
  bool _loadingLocation = true;
  double? _qiblaBearing;
  String _statusText = "Calculating Qibla direction...";

  @override
  void initState() {
    super.initState();
    _checkLocationAndCalculateQibla();
  }

  Future<void> _checkLocationAndCalculateQibla() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        final bearing = _calculateBearing(23.8103, 90.4125);
        if (mounted) {
          setState(() {
            _qiblaBearing = bearing;
            _loadingLocation = false;
            _statusText = "Using Dhaka location (Permission Denied)";
          });
        }
        return;
      }

      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 5),
        );
      } catch (_) {
        position = await Geolocator.getLastKnownPosition();
      }

      if (position != null) {
        final bearing = _calculateBearing(position.latitude, position.longitude);
        if (mounted) {
          setState(() {
            _qiblaBearing = bearing;
            _loadingLocation = false;
            _statusText = "Point your device's top towards the golden indicator";
          });
        }
      } else {
        final bearing = _calculateBearing(23.8103, 90.4125);
        if (mounted) {
          setState(() {
            _qiblaBearing = bearing;
            _loadingLocation = false;
            _statusText = "Using Dhaka location (No GPS signal)";
          });
        }
      }
    } catch (e) {
      debugPrint("Error loading location for Qibla: $e");
      final bearing = _calculateBearing(23.8103, 90.4125);
      if (mounted) {
        setState(() {
          _qiblaBearing = bearing;
          _loadingLocation = false;
          _statusText = "Using Dhaka location (Error loading GPS)";
        });
      }
    }
  }

  double _calculateBearing(double lat1, double lon1) {
    const double lat2 = 21.4225 * math.pi / 180.0;
    const double lon2 = 39.8262 * math.pi / 180.0;

    double phi1 = lat1 * math.pi / 180.0;
    double lambda1 = lon1 * math.pi / 180.0;

    double dLon = lon2 - lambda1;

    double y = math.sin(dLon) * math.cos(lat2);
    double x = math.cos(phi1) * math.sin(lat2) -
        math.sin(phi1) * math.cos(lat2) * math.cos(dLon);

    double qiblaRad = math.atan2(y, x);
    double qiblaDeg = qiblaRad * 180.0 / math.pi;

    return (qiblaDeg + 360.0) % 360.0;
  }

  @override
  Widget build(BuildContext context) {
    const primaryBg = Color(0xFF0F1E19);
    const cardBg = Color(0xFF162D24);
    const goldAccent = Color(0xFFE5B842);

    return Scaffold(
      backgroundColor: primaryBg,
      appBar: AppBar(
        title: const Text('Qibla Compass', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _loadingLocation
          ? const Center(child: CircularProgressIndicator(color: goldAccent))
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    _statusText,
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  Expanded(
                    child: StreamBuilder<CompassEvent>(
                      stream: FlutterCompass.events,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return const Center(child: Text("Error reading compass sensor", style: TextStyle(color: Colors.white)));
                        }
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator(color: goldAccent));
                        }

                        double? direction = snapshot.data?.heading;

                        if (direction == null) {
                          return const Center(
                            child: Text(
                              "Device does not have compass sensors.",
                              style: TextStyle(color: Colors.white),
                              textAlign: TextAlign.center,
                            ),
                          );
                        }

                        double qiblaAngle = _qiblaBearing != null ? (_qiblaBearing! - direction) : 0.0;
                        
                        double diff = (qiblaAngle.abs() % 360);
                        if (diff > 180) diff = 360 - diff;
                        bool isFacingQibla = diff < 5.0;

                        return Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              isFacingQibla ? "🕋 Facing Qibla!" : "${diff.toStringAsFixed(0)}° to Mecca",
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: isFacingQibla ? Colors.greenAccent : goldAccent,
                              ),
                            ),
                            const SizedBox(height: 40),
                            Center(
                              child: SizedBox(
                                width: 280,
                                height: 280,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Transform.rotate(
                                      angle: (direction * math.pi / 180) * -1,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white24, width: 3),
                                        ),
                                        child: Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            Container(
                                              decoration: const BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: cardBg,
                                              ),
                                            ),
                                            Positioned(top: 8, child: Text('N', style: TextStyle(color: Colors.red.shade400, fontWeight: FontWeight.bold, fontSize: 18))),
                                            Positioned(bottom: 8, child: const Text('S', style: TextStyle(color: Colors.white38, fontWeight: FontWeight.bold))),
                                            Positioned(left: 8, child: const Text('W', style: TextStyle(color: Colors.white38, fontWeight: FontWeight.bold))),
                                            Positioned(right: 8, child: const Text('E', style: TextStyle(color: Colors.white38, fontWeight: FontWeight.bold))),
                                          ],
                                        ),
                                      ),
                                    ),
                                    Transform.rotate(
                                      angle: qiblaAngle * math.pi / 180,
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          Icon(
                                            Icons.navigation_rounded,
                                            size: 140,
                                            color: isFacingQibla ? Colors.greenAccent : goldAccent,
                                          ),
                                          Positioned(
                                            top: 40,
                                            child: Container(
                                              padding: const EdgeInsets.all(6),
                                              decoration: BoxDecoration(
                                                color: primaryBg,
                                                shape: BoxShape.circle,
                                                border: Border.all(color: isFacingQibla ? Colors.greenAccent : goldAccent, width: 1.5),
                                              ),
                                              child: const Text('🕋', style: TextStyle(fontSize: 16)),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      width: 16,
                                      height: 16,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isFacingQibla ? Colors.greenAccent : goldAccent,
                                        boxShadow: [
                                          BoxShadow(
                                            color: (isFacingQibla ? Colors.greenAccent : goldAccent).withValues(alpha: 0.5),
                                            blurRadius: 8,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  Card(
                    color: cardBg,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, color: goldAccent, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "Keep your device flat and away from electromagnetic interference or metal objects.",
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
