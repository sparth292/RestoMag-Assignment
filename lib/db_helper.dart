import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class Vehicle {
  final int? id;
  final String make;
  final String model;
  final int year;

  Vehicle({this.id, required this.make, required this.model, required this.year});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'make': make,
      'model': model,
      'year': year,
    };
  }

  factory Vehicle.fromMap(Map<String, dynamic> map) {
    return Vehicle(
      id: map['id'],
      make: map['make'],
      model: map['model'],
      year: map['year'],
    );
  }
}

class DBHelper {
  static final DBHelper _instance = DBHelper._internal();
  factory DBHelper() => _instance;
  DBHelper._internal();

  static Database? _db;

  Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final directory = await getApplicationDocumentsDirectory();
    final path = join(directory.path, 'vehicles.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (Database db, int version) async {
        await db.execute('''
          CREATE TABLE vehicles(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            make TEXT,
            model TEXT,
            year INTEGER
          )
        ''');
      },
    );
  }

  Future<int> insertVehicle(Vehicle vehicle) async {
    final dbClient = await db;
    return await dbClient.insert('vehicles', vehicle.toMap());
  }

  Future<List<Vehicle>> getVehicles() async {
    final dbClient = await db;
    final List<Map<String, dynamic>> maps = await dbClient.query('vehicles', orderBy: 'id DESC');
    return List.generate(maps.length, (i) => Vehicle.fromMap(maps[i]));
  }
}
