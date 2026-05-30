import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';

class AdminPlansScreen extends StatefulWidget {
  const AdminPlansScreen({super.key});

  @override
  State<AdminPlansScreen> createState() => _AdminPlansScreenState();
}

class _AdminPlansScreenState extends State<AdminPlansScreen> {
  static const Color _bg = Colors.white;
  static const Color _red = Color(0xFFFA7516);
  static const Color _green = Color(0xFF4CAF50);

  bool _loading = false;
  late final List<_PlanData> _plans = [
    _PlanData(
      id: 1,
      name: 'Pakiip Emprende',
      color: _green,
      accentLight: _green.withValues(alpha: 0.1),
      icon: Icons.rocket_launch_rounded,
      priceCtrl: TextEditingController(text: '0.00'),
      commissionCtrl: TextEditingController(text: '10.00'),
      durationCtrl: TextEditingController(text: '0'),
      features: [
        'Productos ilimitados',
        'Panel de pedidos completo',
        'Estadísticas avanzadas',
      ],
    ),
    _PlanData(
      id: 2,
      name: 'Pakiip Empresarial',
      color: _red,
      accentLight: _red.withValues(alpha: 0.1),
      icon: Icons.business_center_rounded,
      priceCtrl: TextEditingController(text: '149.00'),
      commissionCtrl: TextEditingController(text: '0.00'),
      durationCtrl: TextEditingController(text: '30'),
      features: [
        'Soporte prioritario',
        'Personalización de menú',
        'Marketing avanzado',
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    setState(() => _loading = true);
    try {
      final list = await ApiService.getList('/plans');
      if (list.isNotEmpty && mounted) {
        setState(() {
          for (var json in list) {
            final id = json['id'];
            final planObj = _plans.firstWhere(
              (p) => p.id == id,
              orElse: () => _plans[0],
            );
            planObj.priceCtrl.text = json['price'].toString();
            planObj.durationCtrl.text = json['duration_days'].toString();
            planObj.commissionCtrl.text =
                json['commission_rate']?.toString() ?? '0.00';
          }
        });
      }
    } catch (e) {
      debugPrint('Error plans: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    try {
      for (final p in _plans) {
        await ApiService.put('/plans/${p.id}', {
          'name': p.name,
          'price': double.tryParse(p.priceCtrl.text) ?? 0.0,
          'duration_days': int.tryParse(p.durationCtrl.text) ?? 30,
          'commission_rate': double.tryParse(p.commissionCtrl.text) ?? 0.0,
        });
      }
      if (mounted) _snack('✅ Planes guardados correctamente', _green);
    } catch (e) {
      if (mounted) _snack('❌ Error: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String m, Color c) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          m,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: c,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  void dispose() {
    for (final p in _plans) {
      p.priceCtrl.dispose();
      p.durationCtrl.dispose();
      p.commissionCtrl.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Planes de Restaurante',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.black87,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16, top: 12, bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: _red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(
              '${_plans.length} PLANES',
              style: GoogleFonts.poppins(
                color: _red,
                fontWeight: FontWeight.bold,
                fontSize: 10,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SizedBox(
          height: 56,
          child: ElevatedButton.icon(
            onPressed: _loading ? null : _save,
            icon: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.save_rounded, color: Colors.white, size: 20),
            label: Text(
              _loading ? 'Guardando...' : 'Guardar Planes',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _red,
              elevation: 4,
              shadowColor: _red.withValues(alpha: 0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ),
      body: _loading && _plans[0].priceCtrl.text == '0.00'
          ? const Center(child: CircularProgressIndicator(color: _red))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _plans.length,
              separatorBuilder: (_, _) => const SizedBox(height: 24),
              itemBuilder: (ctx, i) => _planCard(_plans[i]),
            ),
    );
  }

  Widget _planCard(_PlanData p) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: p.color.withValues(alpha: 0.08), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            offset: const Offset(0, 4),
            blurRadius: 0,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            offset: const Offset(0, 8),
            blurRadius: 15,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: p.color.withValues(alpha: 0.05),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: p.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(p.icon, color: p.color, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.name,
                        style: GoogleFonts.poppins(
                          color: Colors.black87,
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                      ),
                      Text(
                        'Configuración de Nivel',
                        style: GoogleFonts.poppins(
                          color: Colors.black38,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (p.id == 2)
                  Row(
                    children: [
                      Expanded(
                        child: _inputField(
                          label: 'PRECIO MENSUAL',
                          ctrl: p.priceCtrl,
                          accentColor: p.color,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          prefixText: 'S/. ',
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _inputField(
                          label: 'DURACIÓN (DÍAS)',
                          ctrl: p.durationCtrl,
                          accentColor: p.color,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_rounded, color: p.color, size: 20),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Plan Gratuito Permanente. La comisión se define individualmente por restaurante.',
                            style: TextStyle(
                              color: Colors.black54,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 20),
                Text(
                  'BENEFICIOS INCLUIDOS',
                  style: GoogleFonts.poppins(
                    color: Colors.black38,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 12),
                ...p.features.map(
                  (f) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          color: p.color,
                          size: 16,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          f,
                          style: GoogleFonts.poppins(
                            color: Colors.black87,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _inputField({
    required String label,
    required TextEditingController ctrl,
    required Color accentColor,
    TextInputType? keyboardType,
    String? prefixText,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: GoogleFonts.poppins(
          color: Colors.black38,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
      const SizedBox(height: 6),
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accentColor.withValues(alpha: 0.2)),
        ),
        child: TextField(
          controller: ctrl,
          keyboardType: keyboardType,
          style: GoogleFonts.poppins(
            color: Colors.black87,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
          decoration: InputDecoration(
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            prefixText: prefixText,
            prefixStyle: GoogleFonts.poppins(
              color: accentColor,
              fontWeight: FontWeight.bold,
            ),
            isDense: true,
          ),
        ),
      ),
    ],
  );
}

class _PlanData {
  final int id;
  final String name;
  final Color color;
  final Color accentLight;
  final IconData icon;
  final TextEditingController priceCtrl;
  final TextEditingController commissionCtrl;
  final TextEditingController durationCtrl;
  final List<String> features;

  _PlanData({
    required this.id,
    required this.name,
    required this.color,
    required this.accentLight,
    required this.icon,
    required this.priceCtrl,
    required this.commissionCtrl,
    required this.durationCtrl,
    required this.features,
  });
}
