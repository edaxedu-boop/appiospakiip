import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';

class AdminConfigScreen extends StatefulWidget {
  const AdminConfigScreen({super.key});

  @override
  State<AdminConfigScreen> createState() => _AdminConfigScreenState();
}

class _AdminConfigScreenState extends State<AdminConfigScreen> {
  static const Color _bg = Colors.white;
  static const Color _red = Color(0xFFFA7516);
  static const Color _green = Color(0xFF4CAF50);

  final _serviceFeeCtrl = TextEditingController(text: '0.00');
  final _commissionCtrl = TextEditingController(text: '0.00');
  final _baseCost1KmCtrl = TextEditingController(text: '4.00');
  final _priceIntermediateCtrl = TextEditingController(text: '1.00');
  final _priceLongCtrl = TextEditingController(text: '2.00');
  final _riderRadiusCtrl = TextEditingController(text: '10.0');
  final _clientRadiusCtrl = TextEditingController(text: '10.0');
  final _maintenanceMsgCtrl = TextEditingController(
    text: 'Estamos realizando mejoras en el sistema.\nVolveremos pronto...',
  );

  bool _maintenanceMode = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.get('/admin/config');
      if (mounted) {
        setState(() {
          _serviceFeeCtrl.text = data['service_fee']?.toString() ?? '0.00';
          _commissionCtrl.text = data['rider_commission']?.toString() ?? '60.00';
          _baseCost1KmCtrl.text = data['base_cost_1km']?.toString() ?? '4.00';
          _priceIntermediateCtrl.text = data['price_per_km_intermediate']?.toString() ?? '1.00';
          _priceLongCtrl.text = data['price_per_km_long']?.toString() ?? '2.00';
          _riderRadiusCtrl.text = data['rider_view_radius']?.toString() ?? '10.0';
          _clientRadiusCtrl.text = data['client_view_radius']?.toString() ?? '10.0';
          _maintenanceMode = data['maintenance_mode'] ?? false;
          _maintenanceMsgCtrl.text = data['maintenance_message'] ?? '';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _serviceFeeCtrl.dispose();
    _commissionCtrl.dispose();
    _baseCost1KmCtrl.dispose();
    _priceIntermediateCtrl.dispose();
    _priceLongCtrl.dispose();
    _riderRadiusCtrl.dispose();
    _clientRadiusCtrl.dispose();
    _maintenanceMsgCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isLoading = true);
    try {
      await ApiService.patch('/admin/config', {
        'service_fee': double.tryParse(_serviceFeeCtrl.text),
        'rider_commission': double.tryParse(_commissionCtrl.text),
        'base_cost_1km': double.tryParse(_baseCost1KmCtrl.text),
        'price_per_km_intermediate': double.tryParse(_priceIntermediateCtrl.text),
        'price_per_km_long': double.tryParse(_priceLongCtrl.text),
        'rider_view_radius': double.tryParse(_riderRadiusCtrl.text),
        'client_view_radius': double.tryParse(_clientRadiusCtrl.text),
        'maintenance_mode': _maintenanceMode,
        'maintenance_message': _maintenanceMsgCtrl.text,
      });

      if (mounted) {
        setState(() => _isLoading = false);
        _snack('✅ Cambios guardados correctamente', _green);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _snack('Error: $e', Colors.red);
      }
    }
  }

  void _snack(String m, Color c) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(m, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w500)),
        backgroundColor: c,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _sectionHeader(IconData icon, String label) => Padding(
        padding: const EdgeInsets.only(top: 28, bottom: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: _red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: _red, size: 18),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: GoogleFonts.poppins(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 13,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      );

  Widget _numericField({
    required String label,
    required TextEditingController ctrl,
    required IconData suffixIcon,
  }) =>
      Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.black.withValues(alpha: 0.05), width: 1.5),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.03), offset: const Offset(0, 4), blurRadius: 0),
            BoxShadow(color: Colors.black.withValues(alpha: 0.02), offset: const Offset(0, 8), blurRadius: 15),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.poppins(color: Colors.black38, fontSize: 11, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: ctrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: GoogleFonts.poppins(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.w600),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                    ),
                  ),
                ),
                Icon(suffixIcon, color: _red.withValues(alpha: 0.6), size: 20),
              ],
            ),
          ],
        ),
      );

  void _showSupportDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: _red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.headset_mic_rounded, color: _red, size: 22),
            ),
            const SizedBox(width: 12),
            Text('Soporte Técnico', style: GoogleFonts.poppins(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _supportRow(Icons.phone_iphone_rounded, 'WhatsApp / Celular', '+51 910 318 809'),
            const SizedBox(height: 20),
            _supportRow(Icons.alternate_email_rounded, 'Correo Electrónico', 'pakiipglobal@gmail.com'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cerrar', style: GoogleFonts.poppins(color: _red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _supportRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.black26, size: 20),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: GoogleFonts.poppins(color: Colors.black38, fontSize: 11, fontWeight: FontWeight.w500)),
            Text(value, style: GoogleFonts.poppins(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
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
          'Configurar App',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16, top: 12, bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: _red,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [BoxShadow(color: _red.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 4))],
            ),
            alignment: Alignment.center,
            child: Text(
              'SUPER ADMIN',
              style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 0.5),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5))],
        ),
        child: SizedBox(
          height: 56,
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _save,
            icon: _isLoading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            label: Text(
              _isLoading ? 'Guardando...' : 'Guardar Cambios',
              style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _red,
              elevation: 4,
              shadowColor: _red.withValues(alpha: 0.3),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
      ),
      body: _isLoading && _serviceFeeCtrl.text == '0.00'
          ? const Center(child: CircularProgressIndicator(color: _red))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionHeader(Icons.settings_rounded, 'PARÁMETROS GENERALES'),
                  _numericField(label: 'Tarifa de Servicio (S/)', ctrl: _serviceFeeCtrl, suffixIcon: Icons.payments_rounded),
                  _numericField(label: 'Comisión Repartidor por Pedido (%)', ctrl: _commissionCtrl, suffixIcon: Icons.percent_rounded),
                  _numericField(label: 'Costo Base Delivery (1er KM) (S/.)', ctrl: _baseCost1KmCtrl, suffixIcon: Icons.near_me_rounded),
                  _numericField(label: 'Precio por KM Intermedio (KM 1.01 al 3) (S/.)', ctrl: _priceIntermediateCtrl, suffixIcon: Icons.location_on_rounded),
                  _numericField(label: 'Precio por KM Largo (A partir de KM 3) (S/.)', ctrl: _priceLongCtrl, suffixIcon: Icons.map_rounded),
                  _numericField(label: 'Radio de Pedidos para Repartidor (KM)', ctrl: _riderRadiusCtrl, suffixIcon: Icons.radar_rounded),
                  _numericField(label: 'Radio de Visibilidad para Clientes (KM)', ctrl: _clientRadiusCtrl, suffixIcon: Icons.visibility_rounded),
                  _sectionHeader(Icons.build_rounded, 'MANTENIMIENTO DEL SISTEMA'),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.black.withValues(alpha: 0.05), width: 1.5),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.03), offset: const Offset(0, 4), blurRadius: 0),
                        BoxShadow(color: Colors.black.withValues(alpha: 0.02), offset: const Offset(0, 8), blurRadius: 15),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                              child: const Icon(Icons.power_settings_new_rounded, color: Colors.blue, size: 22),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Modo Mantenimiento', style: GoogleFonts.poppins(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 14)),
                                  Text('Desactiva el acceso a usuarios finales', style: GoogleFonts.poppins(color: Colors.black38, fontSize: 11)),
                                ],
                              ),
                            ),
                            Switch.adaptive(
                              value: _maintenanceMode,
                              onChanged: (v) => setState(() => _maintenanceMode = v),
                              activeColor: _red,
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Text('Mensaje para el Usuario', style: GoogleFonts.poppins(color: Colors.black38, fontSize: 11, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        Container(
                          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(14)),
                          child: TextField(
                            controller: _maintenanceMsgCtrl,
                            maxLines: 3,
                            style: GoogleFonts.poppins(color: Colors.black54, fontSize: 13, fontWeight: FontWeight.w500),
                            decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.all(16)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _sectionHeader(Icons.headset_mic_rounded, 'SOPORTE TÉCNICO'),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.black.withValues(alpha: 0.05), width: 1.5),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.03), offset: const Offset(0, 4), blurRadius: 0),
                        BoxShadow(color: Colors.black.withValues(alpha: 0.02), offset: const Offset(0, 8), blurRadius: 15),
                      ],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      leading: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(color: _red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.help_center_rounded, color: _red, size: 22),
                      ),
                      title: Text('Contacto de Emergencia', style: GoogleFonts.poppins(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: Text('Asistencia técnica 24/7', style: GoogleFonts.poppins(color: Colors.black38, fontSize: 12)),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.black12, size: 16),
                      onTap: () => _showSupportDialog(),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }
}
