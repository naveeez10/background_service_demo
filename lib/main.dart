import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'services/background_service.dart';
import 'services/location_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
              onPressed: () async {
                final isRunning = await _service.isRunning();
                if (isRunning) {
                  _service.invoke('stopService');
                } else {
                  _service.startService();
                }
                setState(() {});
              },
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
