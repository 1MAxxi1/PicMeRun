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
    _database = await _initDB('picmerun_relational_final_v7.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 7,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
      onConfigure: (db) async => await db.execute('PRAGMA foreign_keys = ON'),
    );
  }

  Future<void> clearQueue() async {
    final db = await instance.database;
    await db.delete('import_processing_queue');
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT, date TEXT, city TEXT, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('''
      CREATE TABLE photographers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT, email TEXT, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ''');

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

    await db.execute('''
      CREATE TABLE face_clusters (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        event_id INTEGER, centroid_embedding TEXT, face_count INTEGER DEFAULT 0,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (event_id) REFERENCES events (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE faces (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        photo_id INTEGER, cluster_id INTEGER, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (photo_id) REFERENCES photos (id) ON DELETE CASCADE,
        FOREIGN KEY (cluster_id) REFERENCES face_clusters (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE torso_processing_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        photo_id INTEGER, torso_image_url TEXT, status TEXT DEFAULT 'pending',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, processed_at TEXT,
        FOREIGN KEY (photo_id) REFERENCES photos (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE bib_numbers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        photo_id INTEGER, bib_number INTEGER, confidence REAL, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (photo_id) REFERENCES photos (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE import_processing_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        file_path TEXT NOT NULL,
        status TEXT DEFAULT 'pending',
        retry_count INTEGER DEFAULT 0,
        error_message TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('CREATE INDEX idx_bib_number ON bib_numbers (bib_number)');
    await db.execute('CREATE INDEX idx_photo_hash ON photos (hash_photo)');
    await db.execute('CREATE INDEX idx_import_status ON import_processing_queue (status)');

    await db.insert('events', {'id': 1, 'name': 'Maratón Inicial', 'city': 'Viña del Mar', 'date': DateTime.now().toIso8601String()});
    await db.insert('photographers', {'id': 1, 'name': 'Maxi Analista', 'email': 'maxi@inacap.cl'});

    print("🚀 DB PicMeRun v7: Sistema de Colas Senior Integrado.");
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 7) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS import_processing_queue (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          file_path TEXT NOT NULL,
          status TEXT DEFAULT 'pending',
          retry_count INTEGER DEFAULT 0,
          error_message TEXT,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      ''');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_import_status ON import_processing_queue (status)');
    }
  }

  // --- NUEVOS MÉTODOS PARA LA COLA DE IMPORTACIÓN (ESTILO CELERY) ---

  Future<void> enqueueImportTasks(List<String> paths) async {
    final db = await instance.database;
    final batch = db.batch();

    for (var path in paths) {
      batch.insert('import_processing_queue', {
        'file_path': path,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      });
    }

    // El commit asegura los datos en SQLite. Se removió el PRAGMA que causaba el crash.
    await batch.commit(noResult: true);
    print("📦 DB: ${paths.length} tareas confirmadas en disco.");
  }

  Future<Map<String, dynamic>?> getNextImportTask() async {
    final db = await instance.database;
    final List<Map<String, dynamic>> results = await db.rawQuery(
        "SELECT * FROM import_processing_queue WHERE status = 'pending' ORDER BY id ASC LIMIT 1"
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<int> updateImportStatus(int id, String status, {String? error}) async {
    final db = await instance.database;
    return await db.update(
      'import_processing_queue',
      {
        'status': status,
        'error_message': error,
        'retry_count': status == 'failed' ? 1 : 0
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- MÉTODOS ORIGINALES ---

  Future<int> insertPhoto(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert('photos', row, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<int> insertTorsoQueue(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert('torso_processing_queue', row);
  }

  Future<int> updatePhotoPath(int id, String newPath) async {
    final db = await instance.database;
    return await db.update('photos', {'file_url': newPath}, where: 'id = ?', whereArgs: [id]);
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

  // --- MÉTODOS DE CONSULTA ---

  Future<List<Map<String, dynamic>>> getPendingTorsos() async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT t.*, p.file_url 
      FROM torso_processing_queue t
      INNER JOIN photos p ON t.photo_id = p.id
      WHERE t.status = ?
      -- 🚀 Ordenamos por ID descendente. Al usar la cola (FIFO),
      -- el ID garantiza el orden cronológico exacto de la captura.
      ORDER BY t.id DESC
    ''', ['pending']);
  }

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