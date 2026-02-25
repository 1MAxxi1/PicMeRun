import 'package:flutter/material.dart';
import 'package:picmerun/services/log_service.dart';

class LogViewScreen extends StatefulWidget {
  const LogViewScreen({super.key});

  @override
  State<LogViewScreen> createState() => _LogViewScreenState();
}

class _LogViewScreenState extends State<LogViewScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Registro de Terreno", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.grey[900],
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep, color: Colors.red),
            onPressed: () async {
              await LogService.clear();
              setState(() {}); // Refrescar vista
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.blue),
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: FutureBuilder<String>(
        future: LogService.getLogs(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          return SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Text(
              snapshot.data!,
              style: const TextStyle(
                color: Color(0xFF00FF00), // Verde matriz para que sea "full claro"
                fontFamily: 'monospace',
                fontSize: 13,
              ),
            ),
          );
        },
      ),
    );
  }
}