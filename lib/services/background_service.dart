import "dart:async";
import "dart:isolate";
import "dart:ui" show DartPluginRegistrant, IsolateNameServer;

import "package:flutter_background_service/flutter_background_service.dart";
import "package:flutter_local_notifications/flutter_local_notifications.dart";
import "package:background_service_demo/services/location_service.dart";

@pragma("vm:entry-point")
class BackgroundService {
  static final FlutterBackgroundService _service = FlutterBackgroundService();
  static final ReceivePort _receivePort = ReceivePort();
  static const String _serviceName = "background_service";

  static Timer? _timer;

  /// Initializes the background service
  static Future<void> initializeService() async {
    // Initialize notifications
    await _initializeNotifications();

    // Configure the background service
    await _service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        autoStartOnBoot: true,
        isForegroundMode: true,
        notificationChannelId:
            "location_service", // <--- Must match the channel below
        initialNotificationTitle: "Location Service",
        initialNotificationContent: "Tracking location in background",
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );

    // Register the port for communication
    IsolateNameServer.registerPortWithName(
      _receivePort.sendPort,
      _serviceName,
    );

    _receivePort.listen((message) {
      if (message == "stopService") {
        stopService();
      }
    });
  }

  /// Initializes local notifications
  static Future<void> _initializeNotifications() async {
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    // Android-specific initialization
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings("@mipmap/ic_launcher");

    // iOS-specific initialization
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // Unified settings
    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    // Initialize the plugin
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);

    // Create (or update) the notification channel for Android
    const AndroidNotificationChannel androidChannel =
        AndroidNotificationChannel(
      "location_service", // <--- Must match the 'notificationChannelId' above
      "Location Service", // Channel name
      description: "Used for the location tracking service",
      importance: Importance.high, // Can adjust based on your needs
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  /// iOS background handler
  @pragma("vm:entry-point")
  static Future<bool> onIosBackground(ServiceInstance service) async {
    // Ensure plugins are registered for background isolate
    DartPluginRegistrant.ensureInitialized();
    return true;
  }

  /// Main entry point for the background isolate (on Android and iOS foreground)
  @pragma("vm:entry-point")
  static Future<void> onStart(ServiceInstance service) async {
    try {
      DartPluginRegistrant.ensureInitialized();

      // 1. Show an IMMEDIATE notification, letting Android know
      //    we're running in the foreground (required to prevent kills).
      final FlutterLocalNotificationsPlugin notifications =
          FlutterLocalNotificationsPlugin();

      await notifications.show(
        888, // A unique notification ID
        "Service Running",
        "Foreground service is active",
        const NotificationDetails(
          android: AndroidNotificationDetails(
            "location_service", // Matches channel ID created above
            "Location Service", // Channel name
            icon: "@mipmap/ic_launcher",
            ongoing: true,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );

      // 2. Initialize services
      final locationService = LocationService();
      await locationService.initialize();

      // 3. Set up a periodic timer to update location every 10 seconds
      _timer = Timer.periodic(const Duration(seconds: 2), (_) async {
        try {
          await notifications.show(
            888, // A unique notification ID
            "Service Running",
            "Foreground service is active",
            const NotificationDetails(
              android: AndroidNotificationDetails(
                "location_service", // Matches channel ID created above
                "Location Service", // Channel name
                icon: "@mipmap/ic_launcher",
                ongoing: true,
                importance: Importance.high,
                priority: Priority.high,
              ),
              iOS: DarwinNotificationDetails(),
            ),
          );
          final position = await locationService.getCurrentLocation();
          if (position != null) {
            final now = DateTime.now();
            final formattedTime =
                "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";

            // Update the existing notification with location/time
            await notifications.show(
              887,
              "Location Tracking Active",
              "Location: ${position.latitude.toStringAsFixed(4)}, "
                  "${position.longitude.toStringAsFixed(4)}\nLast Update: $formattedTime",
              const NotificationDetails(
                android: AndroidNotificationDetails(
                  "location_service", // same channel ID
                  "Location Service",
                  ongoing: true,
                  icon: "@mipmap/ic_launcher",
                  importance: Importance.low,
                  priority: Priority.low,
                  playSound: false,
                  enableVibration: false,
                ),
                iOS: DarwinNotificationDetails(
                  presentSound: false,
                  presentBadge: false,
                ),
              ),
            );

            // Optionally, send data back to the main isolate
            service.invoke(
              "update_location",
              {
                "latitude": position.latitude,
                "longitude": position.longitude,
                "timestamp": now.toIso8601String(),
              },
            );
          }
        } catch (e, stack) {
          print("Error in periodic timer: $e\n$stack");
        }
      });

      // 4. Handle "stopService" requests
      service.on("stopService").listen((event) {
        stopService();
      });

      print("Background service started successfully.");
    } catch (e, stack) {
      print("Error in onStart: $e\n$stack");
    }
  }

  /// Starts the background service
  static Future<void> startService() async {
    if (await _service.isRunning()) {
      print("Service is already running.");
      return;
    }
    await _service.startService();
    print("Service started.");
  }

  /// Stops the background service
  static Future<void> stopService() async {
    print("Stopping service.");
    _timer?.cancel();
    _service.invoke("stopService"); // Tells background isolate to stop
    IsolateNameServer.removePortNameMapping(_serviceName);
    print("Service stopped.");
  }

  /// Checks if the service is running
  static Future<bool> isServiceRunning() async {
    return _service.isRunning();
  }
}
