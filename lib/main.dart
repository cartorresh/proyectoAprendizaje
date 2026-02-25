import 'package:flutter/material.dart';
import 'ml/micorrizas_model.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Micorrizas',
      theme: ThemeData(useMaterial3: true),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _formKey = GlobalKey<FormState>();

  final _latC = TextEditingController(text: "-2.17");
  final _lonC = TextEditingController(text: "-79.92");
  final _paisC = TextEditingController(text: "OTRO");
  final _provC = TextEditingController(text: "OTRO");

  final _model = MicorrizasModel();
  bool _loading = true;

  Map<String, dynamic>? _result;
  List<String> _paises = [];
  List<String> _provincias = [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      await _model.load();
      _paises = _model.getPaises();
      _provincias = _model.getProvincias();
    } catch (e) {
      _result = {"error": e.toString()};
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _latC.dispose();
    _lonC.dispose();
    _paisC.dispose();
    _provC.dispose();
    _model.close();
    super.dispose();
  }

  String? _valLat(String? v) {
    final x = double.tryParse((v ?? "").trim());
    if (x == null) return "Número inválido";
    if (x < -90 || x > 90) return "Latitud -90 a 90";
    return null;
  }

  String? _valLon(String? v) {
    final x = double.tryParse((v ?? "").trim());
    if (x == null) return "Número inválido";
    if (x < -180 || x > 180) return "Longitud -180 a 180";
    return null;
  }

  void _predict() {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final out = _model.predict(
      lat: double.parse(_latC.text),
      lon: double.parse(_lonC.text),
      pais: _paisC.text,
      provincia: _provC.text,
    );
    setState(() => _result = out);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final err = _result?["error"];
    if (err != null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Micorrizas")),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Text("Error:\n$err"),
        ),
      );
    }

    final pred = _result?["pred"]?.toString();
    final conf = (_result?["conf"] is num) ? (_result!["conf"] as num).toDouble() : null;
    final top3 = (_result?["top3"] as List?) ?? [];
    

    return Scaffold(
      appBar: AppBar(title: const Text("Clasificación Micorrizas")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _latC,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: "Latitud"),
                              validator: _valLat,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _lonC,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: "Longitud"),
                              validator: _valLon,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      Autocomplete<String>(
                        initialValue: TextEditingValue(text: _paisC.text),
                        optionsBuilder: (v) {
                          final q = v.text.trim().toUpperCase();
                          if (q.isEmpty) return _paises.take(20);
                          return _paises.where((e) => e.toUpperCase().contains(q)).take(20);
                        },
                        onSelected: (v) => _paisC.text = v,
                        fieldViewBuilder: (context, controller, focusNode, onSubmit) {
                          controller.text = _paisC.text;
                          controller.addListener(() => _paisC.text = controller.text);
                          return TextFormField(
                            controller: controller,
                            focusNode: focusNode,
                            decoration: const InputDecoration(labelText: "País (o OTRO)"),
                          );
                        },
                      ),

                      const SizedBox(height: 12),

                      Autocomplete<String>(
                        initialValue: TextEditingValue(text: _provC.text),
                        optionsBuilder: (v) {
                          final q = v.text.trim().toUpperCase();
                          if (q.isEmpty) return _provincias.take(20);
                          return _provincias.where((e) => e.toUpperCase().contains(q)).take(20);
                        },
                        onSelected: (v) => _provC.text = v,
                        fieldViewBuilder: (context, controller, focusNode, onSubmit) {
                          controller.text = _provC.text;
                          controller.addListener(() => _provC.text = controller.text);
                          return TextFormField(
                            controller: controller,
                            focusNode: focusNode,
                            decoration: const InputDecoration(labelText: "Provincia (o OTRO)"),
                          );
                        },
                      ),

                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _predict,
                          icon: const Icon(Icons.analytics),
                          label: const Text("Predecir"),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            if (_result != null && pred != null && conf != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Resultado", style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 8),
                      Text("Predicción: $pred", style: Theme.of(context).textTheme.titleMedium),
                      Text("Confianza: ${(conf * 100).toStringAsFixed(1)}%"),
                      if (conf < 0.50) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.18),
                            border: Border.all(color: Colors.amber),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.warning_amber_rounded),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  "Predicción con incertidumbre (${(conf * 100).toStringAsFixed(1)}%). "
                                  "Revisa el Top-3 antes de concluir.",
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      const Text("Top-3:"),
                      const SizedBox(height: 8),
                      for (final item in top3)
                        Row(
                          children: [
                            Expanded(child: Text(item["familia"].toString())),
                            Text("${((item["p"] as num).toDouble() * 100).toStringAsFixed(1)}%"),
                          ],
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
