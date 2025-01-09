import "dart:async";

import "package:flutter/material.dart";
import "package:flutter_background_service/flutter_background_service.dart";
import "package:flutter_local_notifications/flutter_local_notifications.dart";
import "package:background_service_demo/services/background_service.dart";
import "package:background_service_demo/services/location_service.dart";
import "package:permission_handler/permission_handler.dart";

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Request notification permissions first
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.requestNotificationsPermission();

  await BackgroundService.initializeService();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const HomeScreen(),
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _currentLocation;
  final _service = FlutterBackgroundService();
  final _locationService = LocationService();

  @override
  void initState() {
    super.initState();
    _listenToLocationUpdates();
  }

  void _listenToLocationUpdates() {
    _service.on("update_location").listen((event) {
      if (event != null && mounted) {
        setState(() {
          _currentLocation = 'Lat: ${event['latitude']}, Lng: ${event['longitude']}';
        });
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      await _service.startService();
    }
  }

  Future<void> stopService() async {
    final isRunning = await _service.isRunning();
    if (isRunning) {
      _service.invoke("stopService");
      setState(() {});
    }
  }

  Future<void> startService() async {
    final isRunning = await _service.isRunning();
    if (isRunning) {
      print("Service is already running");
      return;
    }

    // Check permissions before starting service
    final hasPermission = await _locationService.requestPermissions();
    if (!hasPermission) {
      if (mounted) {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Location Permission Required"),
            content: const Text(
              "This app needs background location access to track your location even when the app is closed. "
              "Please grant 'Allow all the time' permission in the next screen.",
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await openAppSettings();
                },
                child: const Text("Open Settings"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
            ],
          ),
        );
      }
      return;
    }

    // Start service only after permissions are granted
    await _service.startService();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Location Tracker"),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_currentLocation ?? "No location data"),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: startService,
              child: const Text("Start Service"),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: stopService,
              child: const Text("Stop Service"),
            )
          ],
        ),
      ),
    );
  }
}
