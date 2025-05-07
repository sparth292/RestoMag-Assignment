import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart' show rootBundle;

class ApiService {
  static const String modelsUrl = 'https://vpic.nhtsa.dot.gov/api/vehicles/GetModelsForMake/';

  Future<List<CarMake>> loadMakesFromAssets() async {
    final jsonString = await rootBundle.loadString('assets/makes.json');
    final data = json.decode(jsonString);
    final List results = data['Results'] ?? data;
    return results.map<CarMake>((e) => CarMake.fromJson(e)).toList();
  }

  Future<List<CarModel>> fetchModelsForMake(String make) async {
    final url = '${modelsUrl}${Uri.encodeComponent(make)}?format=json';
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List results = data['Results'];
      return results.map((e) => CarModel.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load models');
    }
  }
}

class CarMake {
  final int id;
  final String name;

  CarMake({required this.id, required this.name});

  factory CarMake.fromJson(Map<String, dynamic> json) {
    return CarMake(
      id: json['Make_ID'],
      name: json['Make_Name'],
    );
  }
}

class CarModel {
  final int id;
  final String name;
  final String makeName;

  CarModel({required this.id, required this.name, required this.makeName});

  factory CarModel.fromJson(Map<String, dynamic> json) {
    return CarModel(
      id: json['Model_ID'] ?? 0,
      name: json['Model_Name'] ?? '',
      makeName: json['Make_Name'] ?? '',
    );
  }
}
