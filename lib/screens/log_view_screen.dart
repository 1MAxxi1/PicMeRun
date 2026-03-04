// Propósito: La "Terminal" profesional. Separa los logs en cuadros individuales
// por foto, con formato Clave-Valor estructurado y permite filtrar entre
// Información de Imágenes y Errores.

import 'package:flutter/material.dart';
import 'package:picmerun/services/log_service.dart';

class LogViewScreen extends StatefulWidget {
  const LogViewScreen({super.key});

  @override
  State<LogViewScreen> createState() => _LogViewScreenState();
}

class _LogViewScreenState extends State<LogViewScreen> {
  List<String> _allLogs = [];
  List<String> _filteredLogs = [];
  String _currentFilter = 'Inf Imágenes'; // Pestaña por defecto
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    try {
      final String rawLogs = await LogService.readLogs();
      // Separamos el texto por saltos de línea
      final List<String> lines = rawLogs.split('\n').where((line) => line.trim().isNotEmpty).toList();

      setState(() {
        _allLogs = lines.reversed.toList(); // Los más nuevos arriba
        _filterLogs(_currentFilter);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _allLogs = ["🚨 Error al leer los logs: $e"];
        _filteredLogs = _allLogs;
        _isLoading = false;
      });
    }
  }

  // 🧠 El Motor de Búsqueda Binario
  void _filterLogs(String filter) {
    setState(() {
      _currentFilter = filter;
      if (filter == 'Inf Imágenes') {
        // Mostramos TODO lo que no sea un error (Fotos, ráfagas, info general)
        _filteredLogs = _allLogs.where((log) => !log.contains('🚨') && !log.toLowerCase().contains('error')).toList();
      } else if (filter == 'Errores') {
        // Mostramos SOLO los errores
        _filteredLogs = _allLogs.where((log) => log.contains('🚨') || log.toLowerCase().contains('error')).toList();
      }
    });
  }

  Future<void> _clearLogs() async {
    await LogService.clearLogs();
    _loadLogs();
    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("🗑️ Terminal limpiada"), backgroundColor: Colors.green, duration: Duration(seconds: 1)),
      );
    }
  }

  // 🎨 Diseño de los 2 Botones Gigantes Superiores
  Widget _buildFilterButton(String label, IconData icon) {
    final bool isSelected = _currentFilter == label;
    return Expanded(
      child: GestureDetector(
        onTap: () => _filterLogs(label),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? (label == 'Errores' ? Colors.red.withOpacity(0.15) : Colors.blue.withOpacity(0.15)) : Colors.black,
            border: Border(
              bottom: BorderSide(
                color: isSelected ? (label == 'Errores' ? Colors.redAccent : Colors.blueAccent) : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: isSelected ? (label == 'Errores' ? Colors.redAccent : Colors.blueAccent) : Colors.grey, size: 22),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 📦 El Formateador Inteligente de Recuadros (Extractor Regex)
  Widget _buildLogCard(String log) {
    // 1. RECUADRO DE ERRORES (Rojo)
    if (log.contains('🚨') || log.toLowerCase().contains('error')) {
      return Card(
        color: const Color(0xFF2A1111), // Rojo ultra oscuro
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.redAccent, width: 1)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.error_outline, color: Colors.redAccent, size: 28),
              const SizedBox(width: 12),
              Expanded(child: Text(log, style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4))),
            ],
          ),
        ),
      );
    }

    // 2. RECUADRO ESTRUCTURADO DE FOTO (Azul) - El diseño de Maxi
    if (log.contains('Foto #')) {
      String header = "Foto  #---";
      String timeStr = "";
      String caras = "-";
      String resolucion = "-";
      String peso = "-";
      List<String> detallesList = [];

      // A) Extraer Fecha y Hora (transformando YYYY-MM-DD a DD-MM-YYYY)
      final timeRegex = RegExp(r'^(\d{4})-(\d{2})-(\d{2}) (\d{2}:\d{2}:\d{2})');
      final timeMatch = timeRegex.firstMatch(log);
      if (timeMatch != null) {
        timeStr = "${timeMatch.group(3)}-${timeMatch.group(2)}-${timeMatch.group(1)} ${timeMatch.group(4)}";
      }

      // B) Extraer ID
      final idRegex = RegExp(r'Foto #(\d+)');
      final idMatch = idRegex.firstMatch(log);
      if (idMatch != null) header = "Foto  #${idMatch.group(1)}";

      // C) Extraer Caras
      final carasRegex = RegExp(r'Caras:\s*(\d+)');
      final carasMatch = carasRegex.firstMatch(log);
      if (carasMatch != null) caras = carasMatch.group(1)!;

      // D) Extraer Resolución
      final resRegex = RegExp(r'Res:\s*([\dx]+)');
      final resMatch = resRegex.firstMatch(log);
      if (resMatch != null) resolucion = resMatch.group(1)!;

      // E) Extraer Peso
      final pesoRegex = RegExp(r'Peso:\s*([0-9\.A-Z]+)');
      final pesoMatch = pesoRegex.firstMatch(log);
      if (pesoMatch != null) peso = pesoMatch.group(1)!;

      // F) Extraer Detalles y formatearlos
      final detRegex = RegExp(r'Detalles:\s*(.*?)\s*(?:\| Res:|$)');
      final detMatch = detRegex.firstMatch(log);
      if (detMatch != null) {
        String rawDetalles = detMatch.group(1)!;
        if (rawDetalles.contains('Sin datos')) {
          detallesList.add(rawDetalles);
        } else {
          // Cortamos los detalles por la coma y aplicamos el formato en mayúsculas sin el grado "°"
          List<String> rawList = rawDetalles.split(', ');
          for (var item in rawList) {
            String cleaned = item.toUpperCase().replaceAll('°', '').replaceAll('PX', ' px');
            detallesList.add(cleaned);
          }
        }
      }

      return Card(
        color: const Color(0xFF161B22), // Azul noche GitHub
        margin: const EdgeInsets.only(bottom: 16),
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.blueAccent.withOpacity(0.4), width: 1)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(header, style: const TextStyle(color: Colors.blueAccent, fontSize: 15, fontWeight: FontWeight.bold)),
                  Text(timeStr, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ),
              const Divider(color: Colors.white24, height: 24),
              Text("Caras: $caras", style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5)),
              Text("Resolución: $resolucion", style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5)),
              Text("Peso: $peso", style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5)),
              const SizedBox(height: 4),
              const Text("Detalles:", style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5)),
              ...detallesList.map((d) => Text(d, style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5))),
            ],
          ),
        ),
      );
    }

    // 3. RECUADRO DE INFO GENERAL (Gris) - Para eventos como iniciar app o ráfagas
    return Card(
      color: const Color(0xFF1A1A1A),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.white24, width: 1)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.grey, size: 24),
            const SizedBox(width: 12),
            Expanded(child: Text(log, style: const TextStyle(color: Colors.white70, fontSize: 14))),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D), // Fondo oscuro profundo
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text("Auditoría de Imágenes", style: TextStyle(color: Colors.white, fontSize: 18)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(icon: const Icon(Icons.delete_sweep, color: Colors.redAccent), onPressed: _clearLogs, tooltip: "Limpiar"),
          IconButton(icon: const Icon(Icons.refresh, color: Colors.blueAccent), onPressed: _loadLogs, tooltip: "Actualizar"),
        ],
      ),
      body: Column(
        children: [
          // 🔘 Los 2 Botones Solicitados
          Container(
            color: Colors.black,
            child: Row(
              children: [
                _buildFilterButton('Inf Imágenes', Icons.data_usage),
                _buildFilterButton('Errores', Icons.bug_report_outlined),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Mostrando ${_filteredLogs.length} recuadros",
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ),
          ),

          // 📜 Lista de Recuadros
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
                : _filteredLogs.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_currentFilter == 'Errores' ? Icons.check_circle_outline : Icons.inbox_outlined, size: 60, color: Colors.white24),
                  const SizedBox(height: 16),
                  Text("No hay registros de $_currentFilter", style: const TextStyle(color: Colors.white54, fontSize: 16)),
                ],
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              itemCount: _filteredLogs.length,
              itemBuilder: (context, index) => _buildLogCard(_filteredLogs[index]),
            ),
          ),
        ],
      ),
    );
  }
}