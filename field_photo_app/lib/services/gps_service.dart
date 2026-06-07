import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_compass/flutter_compass.dart';

class GpsService {
  StreamSubscription<Position>? _positionSub;
  StreamSubscription<CompassEvent>? _compassSub;

  final _positionController = StreamController<Position>.broadcast();
  final _headingController = StreamController<double>.broadcast();

  Stream<Position> get positionStream => _positionController.stream;
  Stream<double> get headingStream => _headingController.stream;

  Position? lastPosition;
  double? lastHeading;

  void startTracking() {
    stopTracking();
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 2,
      ),
    ).listen((pos) {
      lastPosition = pos;
      _positionController.add(pos);
    });

    _compassSub = FlutterCompass.events?.listen((event) {
      if (event.heading != null) {
        lastHeading = event.heading;
        _headingController.add(event.heading!);
      }
    });
  }

  void stopTracking() {
    _positionSub?.cancel();
    _compassSub?.cancel();
  }

  void dispose() {
    stopTracking();
    _positionController.close();
    _headingController.close();
  }
}
