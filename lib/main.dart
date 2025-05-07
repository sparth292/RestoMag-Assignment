import 'package:flutter/material.dart';
import 'db_helper.dart';
import 'vehicle_list_page.dart';
import 'api_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
  
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vehicle App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const AddVehiclePage(),
      routes: {
        '/list': (context) => const VehicleListPage(),
      },
    );
  }
}

class AddVehiclePage extends StatefulWidget {
  const AddVehiclePage({Key? key}) : super(key: key);

  @override
  State<AddVehiclePage> createState() => _AddVehiclePageState();
}

class _AddVehiclePageState extends State<AddVehiclePage> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();
  List<CarMake> _makes = [];
  List<CarModel> _models = [];
  String? selectedMake;
  String? selectedModel;
  int? selectedYear;
  final Map<String, List<CarModel>> _modelCache = {}; // Cache for models
  final TextEditingController _searchController = TextEditingController();
  bool _loadingMakes = true;
  bool _loadingModels = false;
  String? _searchError;
  int _searchProgress = 0;
  bool _cancelSearch = false;

  List<int> get years => List.generate(2025 - 1900 + 1, (i) => 1900 + i).reversed.toList();

  @override
  void initState() {
    super.initState();
    _fetchMakes();
  }

  Future<void> _fetchMakes() async {
    setState(() { _loadingMakes = true; });
    try {
      final makes = await _apiService.loadMakesFromAssets();
      setState(() {
        _makes = makes;
        _loadingMakes = false;
      });
    } catch (_) {
      setState(() { _loadingMakes = false; });
    }
  }

  Future<void> _fetchModels(String make) async {
    final cleanedMake = make.trim();
    print("Fetching models for make: '$cleanedMake'");
    if (cleanedMake.isEmpty) {
      setState(() { _models = []; _loadingModels = false; });
      return;
    }
    // Use cache if available
    if (_modelCache.containsKey(cleanedMake)) {
      setState(() {
        _models = _modelCache[cleanedMake]!;
        _loadingModels = false;
      });
      print("Loaded models for '$cleanedMake' from cache.");
      return;
    }
    if (!_loadingModels) {
      setState(() { _loadingModels = true; });
    }
    try {
      final models = await _apiService.fetchModelsForMake(cleanedMake);
      setState(() {
        _models = models;
        _loadingModels = false;
      });
      _modelCache[cleanedMake] = models;
      print("Fetched and cached models for '$cleanedMake'.");
    } catch (_) {
      setState(() { _loadingModels = false; });
    }
  }

  void _onMakeChanged(String? make) {
    setState(() {
      selectedMake = make;
      selectedModel = null;
      _models = [];
      if (make != null) {
        _fetchModels(make);
      }
    });
  }

  void _onModelChanged(String? model) {
    setState(() {
      selectedModel = model;
    });
  }

  void _onSearchByModel() async {
    final searchText = _searchController.text.trim().toLowerCase();
    if (searchText.isEmpty) {
      setState(() {
        _searchError = 'Please enter a model to search.';
        _loadingModels = false;
      });
      return;
    }

    setState(() {
      _searchError = null;
      _loadingModels = true;
      _searchProgress = 0;
      _cancelSearch = false;
    });

    bool found = false;
    const int batchSize = 5;
    List<CarMake> makesToSearch = _makes;

    for (int i = 0; i < makesToSearch.length && !found && !_cancelSearch; i += batchSize) {
      final batch = makesToSearch.skip(i).take(batchSize).toList();

      final futures = batch.map((make) async {
        final cleanedMake = make.name.trim();
        if (_modelCache.containsKey(cleanedMake)) {
          return {'make': cleanedMake, 'models': _modelCache[cleanedMake]!};
        }
        try {
          final models = await _apiService.fetchModelsForMake(cleanedMake);
          _modelCache[cleanedMake] = models;
          return {'make': cleanedMake, 'models': models};
        } catch (_) {
          return null;
        }
      }).toList();

      final results = await Future.wait(futures);
      _searchProgress += batch.length;

      for (final result in results) {
        if (result == null || result is! Map<String, dynamic>) continue;

        final cleanedMake = result['make'] as String?;
        final models = result['models'] as List<CarModel>?;

        if (cleanedMake == null || models == null) continue;

        final match = models.firstWhere(
              (m) => m.name.toLowerCase() == searchText,
          orElse: () => CarModel(id: 0, name: '', makeName: ''),
        );

        if (match.id != 0) {
          setState(() {
            selectedMake = cleanedMake;
            selectedModel = match.name;
            _models = models;
            _loadingModels = false;
          });
          found = true;
          break;
        }
      }

      // Update progress UI
      if (mounted) {
        setState(() {});
      }
    }

    if (!found && !_cancelSearch) {
      setState(() {
        _searchError = 'No match found for "$searchText" in any make.';
        _loadingModels = false;
      });
    }
  }


  void _addVehicle() async {
    if (_formKey.currentState?.validate() ?? false) {
      final vehicle = Vehicle(
        make: selectedMake!,
        model: selectedModel!,
        year: selectedYear!,
      );
      await DBHelper().insertVehicle(vehicle);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vehicle added successfully!')),
        );
        setState(() {
          selectedMake = null;
          selectedModel = null;
          selectedYear = null;
          _searchController.clear();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Vehicle'),
        actions: [
          IconButton(
            icon: const Icon(Icons.list),
            tooltip: 'View Vehicle List',
            onPressed: () {
              Navigator.pushNamed(context, '/list');
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search by model
              const Text('Search by model', style: TextStyle(fontSize: 16)),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Enter model',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _onSearchByModel,
                    child: const Text('Search'),
                  ),
                ],
              ),
              if (_searchError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(_searchError!, style: const TextStyle(color: Colors.red)),
                ),
              if (_loadingModels)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: LinearProgressIndicator(
                          value: _makes.isNotEmpty ? _searchProgress / _makes.length : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('$_searchProgress / ${_makes.length}'),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          setState(() { _cancelSearch = true; });
                        },
                        child: const Text('Cancel'),
                      ),
                    ],
                  ),
                ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text('OR', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              const Text('Make', style: TextStyle(fontSize: 16)),
              _loadingMakes
                  ? const Center(child: CircularProgressIndicator())
                  : DropdownButtonFormField<String>(
                      value: selectedMake,
                      items: _makes
                          .map((make) => DropdownMenuItem(
                                value: make.name,
                                child: Text(make.name),
                              ))
                          .toList(),
                      onChanged: _onMakeChanged,
                      validator: (val) => val == null ? 'Please select a make' : null,
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                    ),
              const SizedBox(height: 16),
              const Text('Model', style: TextStyle(fontSize: 16)),
              _loadingModels
                  ? const Center(child: CircularProgressIndicator())
                  : DropdownButtonFormField<String>(
                      value: selectedModel,
                      items: selectedMake == null
                          ? []
                          : _models
                              .map((model) => DropdownMenuItem(
                                    value: model.name,
                                    child: Text(model.name),
                                  ))
                              .toList(),
                      onChanged: _onModelChanged,
                      validator: (val) => val == null ? 'Please select a model' : null,
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                    ),
              const SizedBox(height: 16),
              const Text('Year', style: TextStyle(fontSize: 16)),
              DropdownButtonFormField<int>(
                value: selectedYear,
                items: years
                    .map((year) => DropdownMenuItem(
                          value: year,
                          child: Text(year.toString()),
                        ))
                    .toList(),
                onChanged: (val) {
                  setState(() {
                    selectedYear = val;
                  });
                },
                validator: (val) => val == null ? 'Please select a year' : null,
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _addVehicle,
                  child: const Text('Add vehicle'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
