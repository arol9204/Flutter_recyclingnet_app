import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:object_detection_ssd_mobilenet_v2/object_detection.dart';
import 'package:exif/exif.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 1;

  static final List<Widget> _widgetOptions = <Widget>[
    const AppInfoScreen(),
    const DetectScreen(),
    const MapScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('RecyclingNet Detector'),
      ),
      body: Center(
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.info),
            label: 'App Info',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.photo_camera),
            label: 'Detect',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Map',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.orange,
        onTap: _onItemTapped,
      ),
    );
  }
}

class AppInfoScreen extends StatelessWidget {
  const AppInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const <Widget>[
          Text(
            'RecyclingNet App',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16),
          Text(
            'This app helps users to identify and post the locations of recycling objects. '
            'You can take pictures of objects and the app will detect recyclable items like cans, '
            'glass bottles, and plastic bottles. These objects will be mapped so others can collect '
            'and recycle them. You can also track locations where recycling objects have been detected '
            'using the Map tab.',
            style: TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class DetectScreen extends StatefulWidget {
  const DetectScreen({super.key});

  @override
  State<DetectScreen> createState() => _DetectScreenState();
}

class _DetectScreenState extends State<DetectScreen> {
  final imagePicker = ImagePicker();
  ObjectDetection? objectDetection;

  Uint8List? image;
  Map<String, String> _extractedMetadata = {
    'Image DateTime': 'N/A',
    'GPS GPSLatitude': 'N/A',
    'GPS GPSLongitude': 'N/A',
  };

  // Variables to store the count of each object detected
  int cansCount = 0;
  int glassBottlesCount = 0;
  int plasticBottlesCount = 0;

  @override
  void initState() {
    super.initState();
    objectDetection = ObjectDetection();
  }

  Future<void> _processImage(String path) async {
    final result = objectDetection!.analyseImage(path);

    setState(() {
      image = result;
      cansCount = objectDetection!.cansCount;
      glassBottlesCount = objectDetection!.glassBottlesCount;
      plasticBottlesCount = objectDetection!.plasticBottlesCount;
    });

    // Extract and display metadata
    final file = File(path);
    await _readImageMetadata(file);
  }

  // Function to extract specific EXIF metadata
  Future<void> _readImageMetadata(File imageFile) async {
    try {
      final imageData = await imageFile.readAsBytes();
      final exifData = await readExifFromBytes(imageData);

      setState(() {
        _extractedMetadata = {
          'Image DateTime': exifData['Image DateTime']?.printable ?? 'N/A',
          'GPS GPSLatitude': exifData['GPS GPSLatitude']?.printable ?? 'N/A',
          'GPS GPSLongitude': exifData['GPS GPSLongitude']?.printable ?? 'N/A',
        };
      });
    } catch (e) {
      print('Error reading metadata: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: <Widget>[
          Expanded(
            child: Center(
              child: (image != null) ? Image.memory(image!) : Container(),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildIconWithText(
                iconPath: 'assets/icons/can.png',
                label: 'Cans',
                count: cansCount,
              ),
              _buildIconWithText(
                iconPath: 'assets/icons/glass_bottle.png',
                label: 'Glass Bottles',
                count: glassBottlesCount,
              ),
              _buildIconWithText(
                iconPath: 'assets/icons/plastic_bottle.png',
                label: 'Plastic Bottles',
                count: plasticBottlesCount,
              ),
            ],
          ),
          SizedBox(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  onPressed: () async {
                    final result = await imagePicker.pickImage(
                      source: ImageSource.camera,
                    );
                    if (result != null) {
                      await _processImage(result.path);
                    }
                  },
                  icon: const Icon(
                    Icons.camera_alt,
                    size: 64,
                  ),
                ),
                IconButton(
                  onPressed: () async {
                    final result = await imagePicker.pickImage(
                      source: ImageSource.gallery,
                    );
                    if (result != null) {
                      await _processImage(result.path);
                    }
                  },
                  icon: const Icon(
                    Icons.photo,
                    size: 64,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Metadata:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Date: ${_extractedMetadata['Image DateTime']}', style: const TextStyle(fontSize: 14)),
                  Text('Latitude: ${_extractedMetadata['GPS GPSLatitude']}', style: const TextStyle(fontSize: 14)),
                  Text('Longitude: ${_extractedMetadata['GPS GPSLongitude']}', style: const TextStyle(fontSize: 14)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconWithText({
    required String iconPath,
    required String label,
    required int count,
  }) {
    return Column(
      children: [
        Image.asset(
          iconPath,
          width: 48,
          height: 48,
        ),
        Text(
          '$label: $count',
          style: const TextStyle(fontSize: 16),
        ),
      ],
    );
  }
}

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Map functionality to be implemented'),
    );
  }
}
