import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';
import 'package:pakiip/screens/admin/admin_restaurant_orders_history_screen.dart';

class AdminRestaurantSettlementsScreen extends StatefulWidget {
  const AdminRestaurantSettlementsScreen({super.key});

  @override
  State<AdminRestaurantSettlementsScreen> createState() =>
      _AdminRestaurantSettlementsScreenState();
}

class _AdminRestaurantSettlementsScreenState
    extends State<AdminRestaurantSettlementsScreen> {
  static const Color _bg = Colors.white;
  static const Color _red = Color(0xFFFA7516);
  static const Color _green = Color(0xFF4CAF50);

  List<dynamic> _settlements = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.getList('/restaurant-payments');
      if (mounted) {
        setState(() {
          _settlements = res;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e', style: GoogleFonts.poppins(color: Colors.white)),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
      setState(() => _loading = false);
    }
  }

  Future<void> _generateMonthly() async {
    final now = DateTime.now();
    int month = now.month;
    int year = now.year;

    await showDialog(
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
              child: const Icon(Icons.calculate_rounded, color: _red, size: 22),
            ),
            const SizedBox(width: 12),
            Text(
              'Generar Comisiones',
              style: GoogleFonts.poppins(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Esto calculará las comisiones acumuladas para restaurantes en el periodo seleccionado.',
              style: GoogleFonts.poppins(color: Colors.black54, fontSize: 13),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildDropdown(
                    label: 'Mes',
                    value: month,
                    items: List.generate(12, (i) => i + 1).map((m) => DropdownMenuItem(value: m, child: Text('$m'))).toList(),
                    onChanged: (v) => month = v!,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDropdown(
                    label: 'Año',
                    value: year,
                    items: [year - 1, year, year + 1].map((y) => DropdownMenuItem(value: y, child: Text('$y'))).toList(),
                    onChanged: (v) => year = v!,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar', style: GoogleFonts.poppins(color: Colors.black38, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _doGenerate(month, year);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _red,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: Text('Generar', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown({required String label, required int value, required List<DropdownMenuItem<int>> items, required Function(int?) onChanged}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.poppins(color: Colors.black38, fontSize: 11, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: value,
              isExpanded: true,
              items: items,
              onChanged: onChanged,
              style: GoogleFonts.poppins(color: Colors.black87, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _doGenerate(int month, int year) async {
    setState(() => _loading = true);
    try {
      await ApiService.postAuth('/restaurant-payments/generate', {
        'month': month,
        'year': year,
      });
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al generar: $e')));
      }
      setState(() => _loading = false);
    }
  }

  Future<void> _markAsPaid(int id) async {
    try {
      await ApiService.patch('/restaurant-payments/$id/pay', {});
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
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
          'Pagos de Restaurantes',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh_rounded, color: _red, size: 20),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: _red))
                : _settlements.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                        itemCount: _settlements.length,
                        itemBuilder: (ctx, i) => _settlementCard(_settlements[i]),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _generateMonthly,
        backgroundColor: _red,
        elevation: 4,
        highlightElevation: 8,
        icon: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
        label: Text(
          'Generar Comisiones',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.03), shape: BoxShape.circle),
            child: const Icon(Icons.payments_outlined, color: Colors.black12, size: 64),
          ),
          const SizedBox(height: 16),
          Text(
            'No hay liquidaciones generadas.',
            style: GoogleFonts.poppins(color: Colors.black45, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _settlementCard(dynamic s) {
    final bool isPaid = s['status'] == 'paid';
    final monthNames = ['', 'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: (isPaid ? _green : _red).withValues(alpha: 0.08), width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), offset: const Offset(0, 4), blurRadius: 0),
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), offset: const Offset(0, 8), blurRadius: 15),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s['restaurant_name'] ?? 'Restaurante',
                        style: GoogleFonts.poppins(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        '${monthNames[s['period_month']]} ${s['period_year']}',
                        style: GoogleFonts.poppins(color: Colors.black38, fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                _statusBadge(isPaid),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                _infoTile('VENTAS', 'S/. ${s['total_sales']}'),
                const Spacer(),
                _infoTile(
                  'COMISIÓN (${s['commission_rate']}%)',
                  'S/. ${s['commission_amount']}',
                  color: isPaid ? _green : _red,
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AdminRestaurantOrdersHistoryScreen(
                            restaurantId: s['restaurant_id'],
                            restaurantName: s['restaurant_name'] ?? 'Restaurante',
                            initialMonth: int.tryParse(s['period_month']?.toString() ?? '') ?? s['period_month'],
                            initialYear: int.tryParse(s['period_year']?.toString() ?? '') ?? s['period_year'],
                          ),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.receipt_long_rounded, color: Colors.black38, size: 16),
                    label: Text(
                      'VER DETALLE DE PEDIDOS',
                      style: GoogleFonts.poppins(color: Colors.black54, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    ),
                  ),
                ),
              ],
            ),
            if (!isPaid) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _markAsPaid(s['id']),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _green,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                  label: Text(
                    'REGISTRAR PAGO RECIBIDO',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ),
            ] else ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: _green.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    const Icon(Icons.verified_rounded, color: _green, size: 14),
                    const SizedBox(width: 8),
                    Text(
                      'Este pago fue registrado exitosamente.',
                      style: GoogleFonts.poppins(color: _green.withValues(alpha: 0.7), fontSize: 10, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(bool isPaid) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: (isPaid ? _green : Colors.orange).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        isPaid ? 'PAGADO' : 'PENDIENTE',
        style: GoogleFonts.poppins(color: isPaid ? _green : Colors.orange, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5),
      ),
    );
  }

  Widget _infoTile(String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(color: Colors.black38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.poppins(color: color ?? Colors.black87, fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}






