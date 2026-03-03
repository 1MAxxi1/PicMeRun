// Propósito: El administrador de SQLite. El único archivo autorizado para
// escribir o leer tablas, insertar registros de fotos y manejar estados de la cola a nivel local.

import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class LocalDBService {
  static final LocalDBService instance = LocalDBService._init();
  static Database? _database;

  LocalDBService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    //  Versión 5: Estructura relacional completa para PicMeRun
    _database = await _initDB('picmerun_relational_final_v5.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 5,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
      //  Habilita el CASCADE y restricciones de llave foránea
      onConfigure: (db) async => await db.execute('PRAGMA foreign_keys = ON'),
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // 1. EVENTOS
    await db.execute('''
      CREATE TABLE events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT, date TEXT, city TEXT, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // 2. FOTÓGRAFOS
    await db.execute('''
      CREATE TABLE photographers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT, email TEXT, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // 3. PHOTOS (Tabla Maestra)
    await db.execute('''
      CREATE TABLE photos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        hash_photo TEXT UNIQUE NOT NULL, 
        event_id INTEGER, photographer_id INTEGER,
        file_url TEXT, width INTEGER, height INTEGER,
        taken_at TEXT, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (event_id) REFERENCES events (id),
        FOREIGN KEY (photographer_id) REFERENCES photographers (id)
      )
    ''');

    // 4. FACE_CLUSTERS
    await db.execute('''
      CREATE TABLE face_clusters (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        event_id INTEGER, centroid_embedding TEXT, face_count INTEGER DEFAULT 0,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (event_id) REFERENCES events (id)
      )
    ''');

    // 5. FACES (Relación foto-rostro con Cascada)
    await db.execute('''
      CREATE TABLE faces (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        photo_id INTEGER, cluster_id INTEGER, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (photo_id) REFERENCES photos (id) ON DELETE CASCADE,
        FOREIGN KEY (cluster_id) REFERENCES face_clusters (id)
      )
    ''');

    // 6. TORSO_PROCESSING_QUEUE (Cola de Envío limpia para Gregorio)
    await db.execute('''
      CREATE TABLE torso_processing_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        photo_id INTEGER, torso_image_url TEXT, status TEXT DEFAULT 'pending',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, processed_at TEXT,
        FOREIGN KEY (photo_id) REFERENCES photos (id) ON DELETE CASCADE
      )
    ''');

    // 7. BIB_NUMBERS (Dorsales detectados)
    await db.execute('''
      CREATE TABLE bib_numbers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        photo_id INTEGER, bib_number INTEGER, confidence REAL, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (photo_id) REFERENCES photos (id) ON DELETE CASCADE
      )
    ''');

    // Índices de optimización
    await db.execute('CREATE INDEX idx_bib_number ON bib_numbers (bib_number)');
    await db.execute('CREATE INDEX idx_photo_hash ON photos (hash_photo)');

    // Inserción de datos semilla obligatorios
    await db.insert('events', {
      'id': 1,
      'name': 'Maratón Inicial',
      'city': 'Viña del Mar',
      'date': DateTime.now().toIso8601String()
    });
    await db.insert('photographers', {
      'id': 1,
      'name': 'Maxi Analista',
      'email': 'maxi@inacap.cl'
    });

    print("🚀 DB PicMeRun v5: Todas las tablas creadas.");
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 5) {
      await db.execute("DROP TABLE IF EXISTS bib_numbers");
      await db.execute("DROP TABLE IF EXISTS torso_processing_queue");
      await db.execute("DROP TABLE IF EXISTS faces");
      await db.execute("DROP TABLE IF EXISTS face_clusters");
      await db.execute("DROP TABLE IF EXISTS photos");
      await db.execute("DROP TABLE IF EXISTS photographers");
      await db.execute("DROP TABLE IF EXISTS events");
      await _createDB(db, newVersion);
    }
  }

  // --- MÉTODOS DE INSERCIÓN ---

  Future<int> insertPhoto(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert('photos', row, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<int> insertTorsoQueue(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert('torso_processing_queue', row);
  }

  // --- MÉTODOS DE ACTUALIZACIÓN ---

  //  NUEVO MÉTODO: Actualiza la ruta de la galería sin afectar la cola
  Future<int> updatePhotoPath(int id, String newPath) async {
    final db = await instance.database;
    return await db.update(
        'photos',
        {'file_url': newPath},
        where: 'id = ?',
        whereArgs: [id]
    );
  }

  Future<int> updateTorsoStatus(int id, String status) async {
    final db = await instance.database;
    return await db.update(
      'torso_processing_queue',
      {'status': status, 'processed_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- MÉTODOS DE CONSULTA ---

  Future<List<Map<String, dynamic>>> getPendingTorsos() async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT t.*, p.file_url 
      FROM torso_processing_queue t
      INNER JOIN photos p ON t.photo_id = p.id
      WHERE t.status = ?
      ORDER BY t.created_at DESC
    ''', ['pending']);
  }

  // --- MÉTODOS DE ELIMINACIÓN ---

  Future<void> deletePhoto(int id) async {
    final db = await instance.database;

    final photoResults = await db.query('photos', where: 'id = ?', whereArgs: [id]);
    final torsoResults = await db.query('torso_processing_queue', where: 'photo_id = ?', whereArgs: [id]);

    if (photoResults.isNotEmpty && photoResults.first['file_url'] != null) {
      final file = File(photoResults.first['file_url'] as String);
      if (await file.exists()) await file.delete();
    }

    if (torsoResults.isNotEmpty && torsoResults.first['torso_image_url'] != null) {
      final file = File(torsoResults.first['torso_image_url'] as String);
      if (await file.exists()) await file.delete();
    }

    await db.delete('photos', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deletePhotoByPath(String path) async {
    final db = await instance.database;
    return await db.delete('photos', where: 'file_url = ?', whereArgs: [path]);
  }
}