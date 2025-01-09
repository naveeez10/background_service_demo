import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'services/background_service.dart';
import 'services/location_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Request notification permissions first
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.requestNotificationsPermission();

  // Initialize notifications
  await flutterLocalNotificationsPlugin.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
        defaultPresentAlert: true,
        defaultPresentBadge: true,
        defaultPresentSound: true,
      ),
    ),
  );

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
    _service.on('update_location').listen((event) {
      if (event != null && mounted) {
        setState(() {
          _currentLocation = 'Lat: ${event['latitude']}, Lng: ${event['longitude']}';
        });
      }
    });
  }

  Future<void> _handleServiceToggle() async {
    final isRunning = await _service.isRunning();
    if (isRunning) {
      _service.invoke('stopService');
    } else {
      final hasPermission = await _locationService.requestPermissions();
      if (hasPermission) {
        _service.startService();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permissions are required to start tracking'),
            ),
          );
        }
      }
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Location Tracker'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_currentLocation ?? 'No location data'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _handleServiceToggle,
              child: FutureBuilder<bool>(
                future: _service.isRunning(),
                builder: (context, snapshot) {
                  return Text(snapshot.data == true ? 'Stop Service' : 'Start Service');
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
