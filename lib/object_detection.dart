//import 'dart:developer';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class ObjectDetection {
  static const String _modelPath = 'assets/model.tflite';
  static const String _labelPath = 'assets/labelmap.txt';

  Interpreter? _interpreter;
  List<String>? _labels;

  // Variables to store detected object counts
  int cansCount = 0;
  int glassBottlesCount = 0;
  int plasticBottlesCount = 0;

  ObjectDetection() {
    _loadModel();
    _loadLabels();
  }

  Future<void> _loadModel() async {
    final interpreterOptions = InterpreterOptions();

    // Use XNNPACK Delegate
    if (Platform.isAndroid) {
      interpreterOptions.addDelegate(XNNPackDelegate());
    }

    // Use Metal Delegate
    if (Platform.isIOS) {
      interpreterOptions.addDelegate(GpuDelegate());
    }

    _interpreter = await Interpreter.fromAsset(_modelPath, options: interpreterOptions);
  }

  Future<void> _loadLabels() async {
    final labelsRaw = await rootBundle.loadString(_labelPath);
    _labels = labelsRaw.split('\n').map((label) => label.trim()).toList();
  }

  Uint8List analyseImage(String imagePath) {
    final imageData = File(imagePath).readAsBytesSync();

    // Decoding image
    final image = img.decodeImage(imageData);

    // Resizing image for model, [512, 512]
    final imageInput = img.copyResize(
      image!,
      width: 512,
      height: 512,
    );

    // Creating matrix representation, [512, 512, 3]
    final imageMatrix = List.generate(
      imageInput.height,
      (y) => List.generate(
        imageInput.width,
        (x) {
          final pixel = imageInput.getPixel(x, y);
          return [pixel.r, pixel.g, pixel.b];
        },
      ),
    );

    final output = _runInference(imageMatrix);

    // Process Tensors from the output
    final boxesTensor = output[0] as List<List<List<double>>>;  // [1, 40, 4]
    final classesTensor = output[1] as List<List<double>>;      // [1, 40]
    final scoresTensor = output[2] as List<List<double>>;       // [1, 40]
    final numberOfDetections = (output[3] as List<double>).first.toInt();  // [1]

    // Reset counts
    cansCount = 0;
    glassBottlesCount = 0;
    plasticBottlesCount = 0;

    final List<List<int>> locations = boxesTensor.first
        .map((box) => box.map((value) => ((value * 512).toInt())).toList())
        .toList();

    final List<int> classes = classesTensor.first.map((value) => value.toInt()).toList();
    final List<double> scores = scoresTensor.first;

    for (var i = 0; i < numberOfDetections; i++) {
      if (scores[i] > 0.2) { // Adjust threshold as needed
        // Increment counts based on detected classes
        final label = _labels![classes[i]];

        if (label == "can") {
          cansCount++;
        } else if (label == "glass bottle") {
          glassBottlesCount++;
        } else if (label == "plastic bottle") {
          plasticBottlesCount++;
        }

        img.drawRect(
          imageInput,
          x1: locations[i][1],
          y1: locations[i][0],
          x2: locations[i][3],
          y2: locations[i][2],
          color: img.ColorRgb8(0, 255, 0),
        );

        img.drawString(
          imageInput,
          font: img.arial14,
          x: locations[i][1] + 7,
          y: locations[i][0] + 7,
          '$label ${scores[i].toStringAsFixed(2)}',
          color: img.ColorRgb8(0, 255, 0),
        );
      }
    }

    return Uint8List.fromList(img.encodeJpg(imageInput));
  }

  List<List<Object>> _runInference(List<List<List<num>>> imageMatrix) {
    // Input tensor [1, 512, 512, 3]
    final input = [imageMatrix];

    // Set output tensors to match actual model output shapes
    final output = {
      0: [List<List<double>>.filled(40, List<double>.filled(4, 0.0))], // Locations [1, 40, 4]
      1: [List<double>.filled(40, 0.0)], // Classes [1, 40]
      2: [List<double>.filled(40, 0.0)], // Scores [1, 40]
      3: [0.0], // Number of detections [1]
    };

    _interpreter!.runForMultipleInputs([input], output);
    return output.values.toList();
  }
}
