import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';

class AdminRidersScreen extends StatefulWidget {
  const AdminRidersScreen({super.key});

  @override
  State<AdminRidersScreen> createState() => _AdminRidersScreenState();
}

class _AdminRidersScreenState extends State<AdminRidersScreen> {
  // ── Palette ─────────────────────────────────────────────────────────────────
  static const Color _bg = Color(0xFFFFFFFF);
  static const Color _card = Color(0xFFFFFFFF);
  static const Color _field = Color(0xFFF5F5F5);
  static const Color _red = Color(0xFFFA7516);
  static const Color _green = Color(0xFF4CAF50);
  static const Color _amber = Color(0xFFFFB300);

  bool _loading = true;
  List<dynamic> _riders = [];
  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadRiders();
  }

  Future<void> _loadRiders() async {
    setState(() => _loading = true);
    try {
      final data = await ApiService.getList('/riders');
      if (mounted) {
        setState(() {
          _riders = data;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _snack('Error al cargar repartidores: $e');
      }
    }
  }

  Future<void> _deleteRider(int id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          '¿Eliminar Repartidor?',
          style: GoogleFonts.poppins(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Estás a punto de eliminar a "$name". Esta acción no se puede deshacer.',
          style: GoogleFonts.poppins(color: Colors.black54, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancelar',
              style: GoogleFonts.poppins(color: Colors.black38),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Eliminar',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ApiService.delete('/riders/$id');
      _loadRiders();
      _snack('Repartidor eliminado correctamente', error: false);
    } catch (e) {
      _snack('Error al eliminar: $e');
    }
  }

  // ── Computed stats ────────────────────────────────────────────────────────────
  int get _online => _riders.where((r) => r['status'] == 'online').length;
  int get _busy => _riders.where((r) => r['status'] == 'busy').length;
  int get _offline => _riders.where((r) => r['status'] == 'offline').length;

  List<dynamic> get _filtered {
    if (_query.trim().isEmpty) return _riders;
    final q = _query.toLowerCase();
    return _riders
        .where((r) => (r['name'] as String).toLowerCase().contains(q))
        .toList();
  }

  // ── Status helpers ──────────────────────────────────────────────────────────
  Color _dotColor(String status) {
    switch (status) {
      case 'online':
        return _green;
      case 'busy':
        return _amber;
      default:
        return Colors.black12;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'online':
        return 'Disponible';
      case 'busy':
        return 'Ocupado';
      default:
        return 'Desconectado';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'online':
        return _green;
      case 'busy':
        return _amber;
      default:
        return Colors.black38;
    }
  }

  void _snack(String msg, {bool error = true}) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg, style: GoogleFonts.poppins(color: Colors.white)),
          backgroundColor: error ? _red : _green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );

  // ── Modal para crear repartidor ──────────────────────────────────────────────
  void _showAddRiderSheet() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    bool submitting = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: _card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 32,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Nuevo Repartidor',
                    style: GoogleFonts.poppins(
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close_rounded, color: Colors.black38),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _sheetField(nameCtrl, 'Nombre Completo', Icons.person_outline),
              const SizedBox(height: 12),
              _sheetField(
                phoneCtrl,
                'WhatsApp / Teléfono',
                Icons.phone_android_rounded,
                keyboard: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              _sheetField(
                emailCtrl,
                'Correo Electrónico',
                Icons.email_outlined,
                keyboard: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              _sheetField(
                passCtrl,
                'Contraseña',
                Icons.lock_outline,
                isPass: true,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: submitting
                      ? null
                      : () async {
                          if (nameCtrl.text.isEmpty ||
                              emailCtrl.text.isEmpty ||
                              passCtrl.text.isEmpty) {
                            _snack('Por favor completa los campos principales');
                            return;
                          }
                          setS(() => submitting = true);
                          try {
                            await ApiService.postAuth('/riders', {
                              'name': nameCtrl.text.trim(),
                              'email': emailCtrl.text.trim(),
                              'password': passCtrl.text.trim(),
                              'phone': phoneCtrl.text.trim(),
                            });
                            Navigator.pop(ctx);
                            _snack('Repartidor creado con éxito', error: false);
                            _loadRiders();
                          } catch (e) {
                            setS(() => submitting = false);
                            _snack('Error: $e');
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _red,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: submitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'CREAR CUENTA',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sheetField(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType keyboard = TextInputType.text,
    bool isPass = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _field,
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextField(
        controller: ctrl,
        obscureText: isPass,
        keyboardType: keyboard,
        style: GoogleFonts.poppins(color: Colors.black87, fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.poppins(color: Colors.black38, fontSize: 13),
          prefixIcon: Icon(icon, color: _red, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;

    return Scaffold(
      backgroundColor: _bg,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _red,
        onPressed: _showAddRiderSheet,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(
          'Añadir Repartidor',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Top Bar ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.black87,
                      size: 20,
                    ),
                  ),
                  Text(
                    'Repartidores',
                    style: GoogleFonts.poppins(
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: _loadRiders,
                    icon: const Icon(
                      Icons.refresh_rounded,
                      color: Colors.black45,
                    ),
                  ),
                ],
              ),
            ),

            // ── Search ───────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F8F8),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
                ),
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  style: GoogleFonts.poppins(color: Colors.black87, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Buscar por nombre...',
                    hintStyle: GoogleFonts.poppins(color: Colors.black26),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: Colors.black26,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ── Stats ────────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _statItem('Activos', _online, _green),
                  const SizedBox(width: 10),
                  _statItem('En Ruta', _busy, _amber),
                  const SizedBox(width: 10),
                  _statItem('Offline', _offline, Colors.black26),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── List ─────────────────────────────────────────────────────────
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: _red))
                  : list.isEmpty
                  ? Center(
                      child: Text(
                        'No se encontraron repartidores',
                        style: GoogleFonts.poppins(color: Colors.black26),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                      itemCount: list.length,
                      itemBuilder: (ctx, i) {
                        final r = list[i];
                        return _riderCard(r);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statItem(String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            // Capa de profundidad 3D
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              offset: const Offset(0, 6),
              blurRadius: 0,
            ),
            // Suavizado de sombra
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              offset: const Offset(0, 8),
              blurRadius: 15,
            ),
          ],
          border: Border.all(color: Colors.black.withValues(alpha: 0.03), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.poppins(
                color: Colors.black38,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$count',
              style: GoogleFonts.poppins(
                color: color,
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _riderCard(dynamic r) {
    final status = r['status'] ?? 'offline';
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          // Efecto de profundidad sólido
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            offset: const Offset(0, 6),
            blurRadius: 0,
          ),
          // Sombra de elevación suave
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            offset: const Offset(0, 8),
            blurRadius: 20,
          ),
        ],
        border: Border.all(
          color: Colors.black.withValues(alpha: 0.05),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: _red.withValues(alpha: 0.1),
            child: Text(
              r['name'][0].toUpperCase(),
              style: GoogleFonts.poppins(
                color: _red,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r['name'],
                  style: GoogleFonts.poppins(
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: _dotColor(status),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _statusLabel(status),
                      style: GoogleFonts.poppins(
                        color: _statusColor(status),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                r['phone'] ?? 'Sin tel.',
                style: GoogleFonts.poppins(
                  color: Colors.black87,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                r['email'],
                style: GoogleFonts.poppins(
                  color: Colors.black45,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),
          IconButton(
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: _red,
              size: 22,
            ),
            onPressed: () => _deleteRider(r['id'], r['name']),
          ),
        ],
      ),
    );
  }
}






