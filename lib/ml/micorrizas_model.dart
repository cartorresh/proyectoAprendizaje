import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:flutter/foundation.dart';

class MicorrizasModel {
  late final Interpreter _interpreter;

  late final Map<int, String> labelMap;
  late final Map<String, int> paisMap;
  late final Map<String, int> provMap;

  bool _loaded = false;
  int _paisVocab = 1;
  int _provVocab = 1;

  Future<void> load() async {
    _interpreter = await Interpreter.fromAsset('assets/modelo_micorrizas.tflite');

    final labelsStr = await rootBundle.loadString('assets/label_map_familia.json');
    final paisStr = await rootBundle.loadString('assets/encoder_pais.json');
    final provStr = await rootBundle.loadString('assets/encoder_provincia.json');

    final Map rawLabels = json.decode(labelsStr);
    final Map rawPais = json.decode(paisStr);
    final Map rawProv = json.decode(provStr);

    labelMap = rawLabels.map((k, v) => MapEntry(int.parse(k.toString()), v.toString()));
    paisMap = rawPais.map((k, v) => MapEntry(k.toString(), int.parse(v.toString())));
    provMap = rawProv.map((k, v) => MapEntry(k.toString(), int.parse(v.toString())));

    _paisVocab = (paisMap.isEmpty) ? 1 : (paisMap.values.reduce(max) + 1);
    _provVocab = (provMap.isEmpty) ? 1 : (provMap.values.reduce(max) + 1);

    _loaded = true;
  }

  int _safePaisId(String pais) {
    final key = pais.trim().toUpperCase();
    final id = paisMap[key] ?? paisMap["OTRO"] ?? 0;
    if (id < 0 || id >= _paisVocab) return 0;
    return id;
  }

  int _safeProvId(String prov) {
    final key = prov.trim();
    final id = provMap[key] ?? provMap["OTRO"] ?? 0;
    if (id < 0 || id >= _provVocab) return 0;
    return id;
  }

  Map<String, dynamic> predict({
    required double lat,
    required double lon,
    required String pais,
    required String provincia,
  }) {
    if (!_loaded) {
      throw StateError("MicorrizasModel no cargado. Llama a load() antes de predict().");
    }

    final pId = _safePaisId(pais);
    final prId = _safeProvId(provincia);
    if (kDebugMode) {
  debugPrint("pais=$pais -> $pId | prov=$provincia -> $prId");
}


    final inputNum = <List<double>>[
      <double>[lat, lon]
    ];
    final inputProv = <List<int>>[
      <int>[prId]
    ];
    final inputPais = <List<int>>[
      <int>[pId]
    ];

    final numClasses = labelMap.length;
    final output = List.generate(1, (_) => List.filled(numClasses, 0.0));
    final outputs = <int, Object>{0: output};

    // ORDEN CORRECTO (según tu TFLite):
    // num (0), prov (1), pais (2)
    _interpreter.runForMultipleInputs([inputNum, inputProv, inputPais], outputs);

    final probs = output[0].cast<double>();

    final idx = List<int>.generate(probs.length, (i) => i);
    idx.sort((a, b) => probs[b].compareTo(probs[a]));

    final top3 = idx.take(3).map((i) {
      return {
        "familia": labelMap[i] ?? "Desconocido",
        "p": probs[i],
      };
    }).toList();

    return {
      "pred": top3[0]["familia"],
      "conf": top3[0]["p"],
      "top3": top3,
    };
  }

  List<String> getPaises() => paisMap.keys.toList()..sort();
  List<String> getProvincias() => provMap.keys.toList()..sort();

  void close() {
    if (_loaded) _interpreter.close();
    _loaded = false;
  }
}
