import "dart:async";

import "package:background_fetch/background_fetch.dart";
import "package:flutter_background_geolocation/flutter_background_geolocation.dart";
import "package:permission_handler/permission_handler.dart";

class LocationService {
  static final LocationService _instance = LocationService._internal();

  factory LocationService() {
    return _instance;
  }

  LocationService._internal();

  Future<bool> requestPermissions() async {
    // Check if location services are enabled
    if (!await Permission.locationWhenInUse.serviceStatus.isEnabled) {
      print("Location services are not enabled");
      return false;
    }

    // Request location when in use permission
    var whenInUseStatus = await Permission.locationWhenInUse.request();
    if (!whenInUseStatus.isGranted) {
      return false;
    }

    // Request background location permission
    var alwaysStatus = await Permission.locationAlways.request();
    if (!alwaysStatus.isGranted) {
      // Show dialog explaining why we need background location
      return false;
    }

    return true;
  }

  Future<void> initialize() async {
    bool permissionsGranted = await requestPermissions();
    if (!permissionsGranted) {
      print("Permissions not granted");
      return;
    }

    BackgroundGeolocation.onLocation((Location location) async {
      print("Location: $location");
    });
    BackgroundGeolocation.onMotionChange((Location location) {
      print("MotionChange: ${location.isMoving}");
    });
    BackgroundGeolocation.onActivityChange((ActivityChangeEvent activityChange) {
      print("ActivityChange: ${activityChange.activity}");
    });

    await BackgroundGeolocation.ready(
      Config(
        reset: true,
        debug: false,
        preventSuspend: true,
        heartbeatInterval: 60,
        logLevel: Config.LOG_LEVEL_VERBOSE,
        desiredAccuracy: Config.DESIRED_ACCURACY_MEDIUM,
        distanceFilter: 10.0,
        stopTimeout: 5,
        autoSync: false,
        stopOnTerminate: false,
        startOnBoot: true,
      ),
    );
    await BackgroundFetch.configure(
        BackgroundFetchConfig(
          minimumFetchInterval: 15,
          startOnBoot: true,
          stopOnTerminate: false,
          enableHeadless: true,
          requiresStorageNotLow: false,
          requiresBatteryNotLow: false,
          requiresCharging: false,
          requiresDeviceIdle: false,
          requiredNetworkType: NetworkType.NONE,
        ), (String taskId) async {
      try {
        // Fetch current position
        Location location = await BackgroundGeolocation.getCurrentPosition(
          samples: 2,
          maximumAge: 1000 * 10, // 30 seconds ago
          timeout: 30,
          desiredAccuracy: 40,
          persist: true,
          extras: {"event": "background-fetch", "headless": false},
        );
        print("[location] $location");
      } catch (error, stk) {
        print("An error occurred in fetching current position from tsgl");
      }

      print("🔔 [BackgroundFetch finish] $taskId");
      await BackgroundFetch.finish(taskId);
    });

    await BackgroundGeolocation.start();
  }
}
