// En lib/widgets/queue_progress_indicator.dart

import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:picmerun/services/local_db_service.dart';

class QueueProgressIndicator extends StatefulWidget {
  const QueueProgressIndicator({super.key});

  @override
  State<QueueProgressIndicator> createState() => _QueueProgressIndicatorState();
}

class _QueueProgressIndicatorState extends State<QueueProgressIndicator> {
  late Stream<Map<String, int>> _queueStream;

  @override
  void initState() {
    super.initState();
    _queueStream = _getQueueStream();
  }

  // Mudamos la lógica del Stream aquí adentro
  Stream<Map<String, int>> _getQueueStream() async* {
    while (true) {
      final db = await LocalDBService.instance.database;
      final total = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM import_processing_queue')) ?? 0;
      final processed = Sqflite.firstIntValue(await db.rawQuery("SELECT COUNT(*) FROM import_processing_queue WHERE status = 'completed' OR status = 'failed'")) ?? 0;

      yield {'total': total, 'processed': processed};

      if (total > 0 && total == processed) {
        await LocalDBService.instance.clearQueue();
      }

      await Future.delayed(const Duration(seconds: 1));
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, int>>(
        stream: _queueStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const SizedBox.shrink();

          final total = snapshot.data!['total'] ?? 0;
          final processed = snapshot.data!['processed'] ?? 0;

          if (total == 0 || total == processed) return const SizedBox.shrink();

          return Positioned(
            top: 100, left: 0, right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.redAccent, width: 2),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10)],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.redAccent, strokeWidth: 2)),
                    const SizedBox(width: 15),
                    Text(
                      "Cola: $processed / $total fotos",
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
    );
  }
}