import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';

class RestaurantDeliveryConfigScreen extends StatefulWidget {
  const RestaurantDeliveryConfigScreen({super.key});

  @override
  State<RestaurantDeliveryConfigScreen> createState() =>
      _RestaurantDeliveryConfigScreenState();
}

// ── Day model ────────────────────────────────────────────────────────────────
class _DayConfig {
  final String name;
  bool enabled;
  TimeOfDay openTime;
  TimeOfDay closeTime;

  _DayConfig({
    required this.name,
    this.enabled = true,
    this.openTime = const TimeOfDay(hour: 9, minute: 0),
    this.closeTime = const TimeOfDay(hour: 22, minute: 0),
  });

  String get formattedRange => '${_fmt(openTime)} - ${_fmt(closeTime)}';

  static String _fmt(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _RestaurantDeliveryConfigScreenState
    extends State<RestaurantDeliveryConfigScreen> {
  static const Color _bg = Color(0xFFFFFFFF);
  static const Color _card = Color(0xFFF9FAFB);
  static const Color _red = Color(0xFFFA7516);
  static const Color _border = Color(0xFFE0E0E0);
  static const Color _fieldBg = Color(0xFFF3F4F6);

  final _minTimeCtrl = TextEditingController(text: '25');
  final _maxTimeCtrl = TextEditingController(text: '45');

  int _rating = 5; // Calificación manual del restaurante
  int? _editingDayIndex;
  bool _loading = true;
  bool _saving = false;

  final List<_DayConfig> _days = [
    _DayConfig(
      name: 'Lunes',
      enabled: true,
      openTime: const TimeOfDay(hour: 9, minute: 0),
      closeTime: const TimeOfDay(hour: 22, minute: 0),
    ),
    _DayConfig(
      name: 'Martes',
      enabled: true,
      openTime: const TimeOfDay(hour: 9, minute: 0),
      closeTime: const TimeOfDay(hour: 22, minute: 0),
    ),
    _DayConfig(
      name: 'Miércoles',
      enabled: true,
      openTime: const TimeOfDay(hour: 9, minute: 0),
      closeTime: const TimeOfDay(hour: 22, minute: 0),
    ),
    _DayConfig(
      name: 'Jueves',
      enabled: true,
      openTime: const TimeOfDay(hour: 9, minute: 0),
      closeTime: const TimeOfDay(hour: 22, minute: 0),
    ),
    _DayConfig(
      name: 'Viernes',
      enabled: true,
      openTime: const TimeOfDay(hour: 9, minute: 0),
      closeTime: const TimeOfDay(hour: 22, minute: 0),
    ),
    _DayConfig(
      name: 'Sábado',
      enabled: true,
      openTime: const TimeOfDay(hour: 10, minute: 0),
      closeTime: const TimeOfDay(hour: 23, minute: 0),
    ),
    _DayConfig(
      name: 'Domingo',
      enabled: false,
      openTime: const TimeOfDay(hour: 10, minute: 0),
      closeTime: const TimeOfDay(hour: 22, minute: 0),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    _minTimeCtrl.dispose();
    _maxTimeCtrl.dispose();
    super.dispose();
  }

  // ── Load ───────────────────────────────────────────────────────────
  Future<void> _loadConfig() async {
    setState(() => _loading = true);
    try {
      final config = await ApiService.get('/config/delivery');
      setState(() {
        _minTimeCtrl.text = (config['min_time'] ?? '25').toString();
        _maxTimeCtrl.text = (config['max_time'] ?? '45').toString();
        _rating = (config['rating'] as num?)?.toInt().clamp(1, 5) ?? 5;

        final schedule = config['schedule'];
        if (schedule is List) {
          for (int i = 0; i < schedule.length && i < _days.length; i++) {
            final s = schedule[i] as Map<String, dynamic>;
            _days[i].enabled = s['enabled'] ?? true;
            final open = (s['open'] as String?)?.split(':') ?? ['09', '00'];
            final close = (s['close'] as String?)?.split(':') ?? ['22', '00'];
            _days[i].openTime = TimeOfDay(
              hour: int.tryParse(open[0]) ?? 9,
              minute: int.tryParse(open[1]) ?? 0,
            );
            _days[i].closeTime = TimeOfDay(
              hour: int.tryParse(close[0]) ?? 22,
              minute: int.tryParse(close[1]) ?? 0,
            );
          }
        }
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  // ── Save ───────────────────────────────────────────────────────────
  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ApiService.put('/config/delivery', {
        'min_time': int.tryParse(_minTimeCtrl.text) ?? 25,
        'max_time': int.tryParse(_maxTimeCtrl.text) ?? 45,
        'rating': _rating,
        'schedule': _days
            .map(
              (d) => {
                'day': d.name,
                'enabled': d.enabled,
                'open': _DayConfig._fmt(d.openTime),
                'close': _DayConfig._fmt(d.closeTime),
              },
            )
            .toList(),
      });
      _snack('✓ Configuración guardada');
    } catch (e) {
      _snack('Error: $e', error: true);
    }
    setState(() => _saving = false);
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.poppins()),
        backgroundColor: error ? Colors.red : _red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _pickTime(int idx, bool isOpen) async {
    final current = isOpen ? _days[idx].openTime : _days[idx].closeTime;
    final picked = await showTimePicker(context: context, initialTime: current);
    if (picked != null) {
      setState(() {
        if (isOpen) {
          _days[idx].openTime = picked;
        } else {
          _days[idx].closeTime = picked;
        }
      });
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _red),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Configuración de Horario',
          style: GoogleFonts.poppins(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _red))
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
              children: [
                // ── Tiempo de Espera ──────────────────────────────────
                _sectionHeader(Icons.schedule, 'Tiempo de Espera'),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: _cardDeco(),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _timeInput('MÍNIMO (MIN)', _minTimeCtrl),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _timeInput('MÁXIMO (MIN)', _maxTimeCtrl),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.info_outline,
                            color: Colors.black26,
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Este tiempo se mostrará a los clientes antes de pedir.',
                              style: GoogleFonts.poppins(
                                color: Colors.black26,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // ── Calificación ──────────────────────────────────────
                _sectionHeader(Icons.star_rounded, 'Calificación Visible'),
                Container(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                  decoration: _cardDeco(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Selecciona tu calificación (aparecerá en la app del cliente)',
                        style: GoogleFonts.poppins(
                          color: Colors.black38,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: List.generate(5, (i) {
                          final star = i + 1;
                          final selected = star <= _rating;
                          return GestureDetector(
                            onTap: () => setState(() => _rating = star),
                            child: AnimatedScale(
                              scale: selected ? 1.15 : 1.0,
                              duration: const Duration(milliseconds: 150),
                              child: Icon(
                                selected
                                    ? Icons.star_rounded
                                    : Icons.star_border_rounded,
                                color: selected ? Colors.amber : Colors.black12,
                                size: 44,
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: Text(
                          _ratingLabel(_rating),
                          style: GoogleFonts.poppins(
                            color: Colors.amber,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // ── Días y Horarios ───────────────────────────────────
                _sectionHeader(
                  Icons.calendar_today,
                  'Días y Horarios de Atención',
                ),
                Container(
                  decoration: _cardDeco(),
                  child: Column(
                    children: List.generate(_days.length, (i) {
                      final d = _days[i];
                      final isEditing = _editingDayIndex == i;
                      final isLast = i == _days.length - 1;

                      return Column(
                        children: [
                          // ── Fila del día ──
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 90,
                                  child: Text(
                                    d.name,
                                    style: GoogleFonts.poppins(
                                      color: d.enabled
                                          ? Colors.black87
                                          : Colors.black26,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                if (d.enabled)
                                  _badge(
                                    'ABIERTO',
                                    Colors.greenAccent,
                                    Colors.green.withOpacity(0.18),
                                  )
                                else
                                  _badge(
                                    'CERRADO',
                                    Colors.redAccent,
                                    Colors.red.withOpacity(0.15),
                                  ),
                                const Spacer(),
                                if (d.enabled && !isEditing)
                                  GestureDetector(
                                    onTap: () =>
                                        setState(() => _editingDayIndex = i),
                                    child: const Icon(
                                      Icons.edit,
                                      color: Colors.black26,
                                      size: 18,
                                    ),
                                  ),
                                const SizedBox(width: 12),
                                Switch(
                                  value: d.enabled,
                                  onChanged: (v) => setState(() {
                                    d.enabled = v;
                                    if (!v) _editingDayIndex = null;
                                  }),
                                  activeThumbColor: Colors.black87,
                                  activeTrackColor: _red,
                                  inactiveThumbColor: Colors.black12,
                                  inactiveTrackColor: Colors.black.withOpacity(0.05),
                                ),
                              ],
                            ),
                          ),

                          // ── Horario expandido ──
                          if (d.enabled && isEditing)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                              child: Row(
                                children: [
                                  _timePill(
                                    _DayConfig._fmt(d.openTime),
                                    () => _pickTime(i, true),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                    ),
                                    child: Text(
                                      'a',
                                      style: GoogleFonts.poppins(
                                        color: Colors.black45,
                                      ),
                                    ),
                                  ),
                                  _timePill(
                                    _DayConfig._fmt(d.closeTime),
                                    () => _pickTime(i, false),
                                  ),
                                  const Spacer(),
                                  TextButton(
                                    onPressed: () =>
                                        setState(() => _editingDayIndex = null),
                                    child: Text(
                                      'OK',
                                      style: GoogleFonts.poppins(
                                        color: _red,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else if (d.enabled)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  d.formattedRange,
                                  style: GoogleFonts.poppins(
                                    color: Colors.black38,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),

                          if (!isLast)
                            Divider(
                              color: _border,
                              height: 1,
                              indent: 16,
                              endIndent: 16,
                            ),
                        ],
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 36),

                // ── Guardar ───────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 58,
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _red,
                      disabledBackgroundColor: _red.withOpacity(0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 4,
                      shadowColor: _red.withOpacity(0.35),
                    ),
                    icon: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.black87,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.save_alt, color: Colors.white),
                    label: Text(
                      'Guardar Configuración',
                      style: GoogleFonts.poppins(
                        color: Colors.black87,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Los cambios se aplicarán instantáneamente en la app del cliente.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: Colors.black26,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  BoxDecoration _cardDeco() => BoxDecoration(
    color: _card,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: _border),
  );

  Widget _sectionHeader(IconData icon, String title) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        Icon(icon, color: _red, size: 22),
        const SizedBox(width: 10),
        Text(
          title,
          style: GoogleFonts.poppins(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    ),
  );

  Widget _badge(String label, Color text, Color bg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      label,
      style: GoogleFonts.poppins(
        color: text,
        fontSize: 9,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      ),
    ),
  );

  Widget _timeInput(String label, TextEditingController ctrl) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: GoogleFonts.poppins(
          color: Colors.black38,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: _fieldBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border),
        ),
        child: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: GoogleFonts.poppins(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
          decoration: const InputDecoration(border: InputBorder.none),
        ),
      ),
    ],
  );

  Widget _timePill(String label, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: _fieldBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(color: Colors.black87, fontSize: 14),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.access_time, color: Colors.black26, size: 14),
        ],
      ),
    ),
  );

  String _ratingLabel(int r) {
    switch (r) {
      case 1:
        return '⭐ Básico (1.0)';
      case 2:
        return '⭐⭐ Regular (2.0)';
      case 3:
        return '⭐⭐⭐ Bueno (3.0)';
      case 4:
        return '⭐⭐⭐⭐ Muy bueno (4.0)';
      case 5:
        return '⭐⭐⭐⭐⭐ Excelente (5.0)';
      default:
        return '$r estrellas';
    }
  }
}






