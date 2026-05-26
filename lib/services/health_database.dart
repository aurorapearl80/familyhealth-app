import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Local SQLite database for storing health readings when offline.
class HealthDatabase {
  HealthDatabase._();

  static Database? _db;

  static Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  static Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'health_monitor.db');
    return openDatabase(
      path,
      version: 5,
      onCreate: (db, _) => _createTables(db),
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await _createOximeterTable(db);
        if (oldVersion < 3) await _createWeightTable(db);
        if (oldVersion < 4) await _createBloodPressureTable(db);
        if (oldVersion < 5) await _createGlucoseTable(db);
      },
    );
  }

  static Future<void> _createTables(Database db) async {
    await _createTemperatureTable(db);
    await _createOximeterTable(db);
    await _createWeightTable(db);
    await _createBloodPressureTable(db);
    await _createGlucoseTable(db);
  }

  // ── Temperature ────────────────────────────────────────────────────────────

  static Future<void> _createTemperatureTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS temperature_readings (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        temperature  REAL    NOT NULL,
        measured_at  TEXT    NOT NULL,
        device_id    TEXT    NOT NULL,
        timezone     TEXT    NOT NULL,
        synced       INTEGER NOT NULL DEFAULT 0,
        created_at   TEXT    NOT NULL
      )
    ''');
  }

  static Future<int> insertTemperatureReading({
    required double temperature,
    required String measuredAt,
    required String deviceId,
    required String timezone,
  }) async {
    final db = await database;
    return db.insert('temperature_readings', {
      'temperature': temperature,
      'measured_at': measuredAt,
      'device_id': deviceId,
      'timezone': timezone,
      'synced': 0,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  static Future<List<Map<String, dynamic>>> getPendingTemperatureReadings() async {
    final db = await database;
    return db.query(
      'temperature_readings',
      where: 'synced = ?',
      whereArgs: [0],
      orderBy: 'created_at ASC',
    );
  }

  static Future<void> markTemperatureAsSynced(int id) async {
    final db = await database;
    await db.update(
      'temperature_readings',
      {'synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ── Weight ────────────────────────────────────────────────────────────────

  static Future<void> _createWeightTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS weight_readings (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        weight      REAL    NOT NULL,
        measured_at TEXT    NOT NULL,
        device_id   TEXT    NOT NULL,
        timezone    TEXT    NOT NULL,
        synced      INTEGER NOT NULL DEFAULT 0,
        created_at  TEXT    NOT NULL
      )
    ''');
  }

  static Future<int> insertWeightReading({
    required double weight,
    required String measuredAt,
    required String deviceId,
    required String timezone,
  }) async {
    final db = await database;
    return db.insert('weight_readings', {
      'weight': weight,
      'measured_at': measuredAt,
      'device_id': deviceId,
      'timezone': timezone,
      'synced': 0,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  static Future<List<Map<String, dynamic>>> getPendingWeightReadings() async {
    final db = await database;
    return db.query(
      'weight_readings',
      where: 'synced = ?',
      whereArgs: [0],
      orderBy: 'created_at ASC',
    );
  }

  static Future<void> markWeightAsSynced(int id) async {
    final db = await database;
    await db.update(
      'weight_readings',
      {'synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ── Blood Pressure ────────────────────────────────────────────────────────

  static Future<void> _createBloodPressureTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS blood_pressure_readings (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        systolic    INTEGER NOT NULL,
        diastolic   INTEGER NOT NULL,
        bpm         INTEGER NOT NULL,
        measured_at TEXT    NOT NULL,
        device_id   TEXT    NOT NULL,
        timezone    TEXT    NOT NULL,
        synced      INTEGER NOT NULL DEFAULT 0,
        created_at  TEXT    NOT NULL
      )
    ''');
  }

  static Future<int> insertBloodPressureReading({
    required int systolic,
    required int diastolic,
    required int bpm,
    required String measuredAt,
    required String deviceId,
    required String timezone,
  }) async {
    final db = await database;
    return db.insert('blood_pressure_readings', {
      'systolic': systolic,
      'diastolic': diastolic,
      'bpm': bpm,
      'measured_at': measuredAt,
      'device_id': deviceId,
      'timezone': timezone,
      'synced': 0,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  static Future<List<Map<String, dynamic>>> getPendingBloodPressureReadings() async {
    final db = await database;
    return db.query(
      'blood_pressure_readings',
      where: 'synced = ?',
      whereArgs: [0],
      orderBy: 'created_at ASC',
    );
  }

  static Future<void> markBloodPressureAsSynced(int id) async {
    final db = await database;
    await db.update(
      'blood_pressure_readings',
      {'synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ── Oximeter ───────────────────────────────────────────────────────────────

  static Future<void> _createOximeterTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS oximeter_readings (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        oxygen      INTEGER NOT NULL,
        pulse_rate  INTEGER NOT NULL,
        measured_at TEXT    NOT NULL,
        device_id   TEXT    NOT NULL,
        timezone    TEXT    NOT NULL,
        synced      INTEGER NOT NULL DEFAULT 0,
        created_at  TEXT    NOT NULL
      )
    ''');
  }

  static Future<int> insertOximeterReading({
    required int oxygen,
    required int pulseRate,
    required String measuredAt,
    required String deviceId,
    required String timezone,
  }) async {
    final db = await database;
    return db.insert('oximeter_readings', {
      'oxygen': oxygen,
      'pulse_rate': pulseRate,
      'measured_at': measuredAt,
      'device_id': deviceId,
      'timezone': timezone,
      'synced': 0,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  static Future<List<Map<String, dynamic>>> getPendingOximeterReadings() async {
    final db = await database;
    return db.query(
      'oximeter_readings',
      where: 'synced = ?',
      whereArgs: [0],
      orderBy: 'created_at ASC',
    );
  }

  static Future<void> markOximeterAsSynced(int id) async {
    final db = await database;
    await db.update(
      'oximeter_readings',
      {'synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ── Blood Glucose ──────────────────────────────────────────────────────────

  static Future<void> _createGlucoseTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS glucose_readings (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        glucose     REAL    NOT NULL,
        mail_value  REAL    NOT NULL,
        measured_at TEXT    NOT NULL,
        device_id   TEXT    NOT NULL,
        timezone    TEXT    NOT NULL,
        synced      INTEGER NOT NULL DEFAULT 0,
        created_at  TEXT    NOT NULL
      )
    ''');
  }

  static Future<int> insertGlucoseReading({
    required double glucose,
    required double mailValue,
    required String measuredAt,
    required String deviceId,
    required String timezone,
  }) async {
    final db = await database;
    return db.insert('glucose_readings', {
      'glucose': glucose,
      'mail_value': mailValue,
      'measured_at': measuredAt,
      'device_id': deviceId,
      'timezone': timezone,
      'synced': 0,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  static Future<List<Map<String, dynamic>>> getPendingGlucoseReadings() async {
    final db = await database;
    return db.query(
      'glucose_readings',
      where: 'synced = ?',
      whereArgs: [0],
      orderBy: 'created_at ASC',
    );
  }

  static Future<void> markGlucoseAsSynced(int id) async {
    final db = await database;
    await db.update(
      'glucose_readings',
      {'synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}