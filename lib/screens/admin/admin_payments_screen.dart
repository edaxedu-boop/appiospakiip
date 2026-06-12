import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';


class AdminPaymentsScreen extends StatefulWidget {
  const AdminPaymentsScreen({super.key});

  @override
  State<AdminPaymentsScreen> createState() => _AdminPaymentsScreenState();
}

class _AdminPaymentsScreenState extends State<AdminPaymentsScreen> {
  static const Color _bg = Colors.white;
  static const Color _red = Color(0xFFFA7516);
  static const Color _green = Color(0xFF4CAF50);

  List<Map<String, dynamic>> _payments = [];
  double _totalBillingMonthly = 0.0;
  bool _isLoading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('es', null);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.get('/admin/liquidations');
      if (mounted) {
        setState(() {
          _totalBillingMonthly = (res['total_monthly_billing'] ?? 0).toDouble();
          _payments = List<Map<String, dynamic>>.from(res['liquidations'] ?? [])
              .map((e) => {
                    ...e,
                    'paid': false,
                    'avatarIcon': Icons.person_rounded,
                    'avatarBg': const Color(0xFFFA7516).withValues(alpha: 0.1),
                    'avatarFg': const Color(0xFFFA7516),
                  })
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error payments: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  double get _totalBilling => _totalBillingMonthly;

  List<Map<String, dynamic>> get _filtered {
    if (_query.trim().isEmpty) return _payments;
    final q = _query.toLowerCase();
    return _payments.where((r) => (r['name'] as String).toLowerCase().contains(q)).toList();
  }

  int get _pendingCount => _payments.where((r) => !(r['paid'] as bool)).length;

  Future<void> _processPay(int idx) async {
    final rider = _payments[idx];
    try {
      await ApiService.postAuth('/admin/liquidations/${rider['id']}/pay', {});
      if (mounted) {
        setState(() => _payments[idx]['paid'] = true);
        _snack('✅ Pago procesado para ${rider['name']}', _green);
      }
    } catch (e) {
      if (mounted) _snack('Error: $e', Colors.red);
    }
  }

  void _snack(String m, Color c) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(m, style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: c,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Liquidaciones de Repartidores',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.history_rounded, color: Colors.black26, size: 22),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _red))
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        _buildSummaryCard(),
                        const SizedBox(height: 24),
                        _buildSearchBar(),
                        const SizedBox(height: 24),
                        _buildSectionHeader(),
                        const SizedBox(height: 16),
                        ...list.map((r) {
                          final realIdx = _payments.indexOf(r);
                          return _paymentCard(r, realIdx);
                        }),
                        const SizedBox(height: 32),
                        _buildFooter(),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _red,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(color: _red.withValues(alpha: 0.3), offset: const Offset(0, 10), blurRadius: 20),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Facturación Mensual en Pedidos',
                style: GoogleFonts.poppins(color: Colors.white.withValues(alpha: 0.85), fontSize: 13, fontWeight: FontWeight.w500),
              ),
              const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 20),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'S/. ${_totalBilling.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}',
            style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 32, letterSpacing: -0.5),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(30)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.trending_up_rounded, color: Colors.white, size: 16),
                const SizedBox(width: 6),
                Text(
                  '+12% desde ayer',
                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: TextField(
        style: GoogleFonts.poppins(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.w500),
        onChanged: (v) => setState(() => _query = v),
        decoration: InputDecoration(
          hintText: 'Buscar repartidores...',
          hintStyle: GoogleFonts.poppins(color: Colors.black26, fontSize: 14),
          prefixIcon: const Icon(Icons.search_rounded, color: _red, size: 22),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildSectionHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'LIQUIDACIONES PENDIENTES',
          style: GoogleFonts.poppins(color: Colors.black38, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: _red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
          child: Text(
            '$_pendingCount Nuevas',
            style: GoogleFonts.poppins(color: _red, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  double _asDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? 0.0;
    return 0.0;
  }

  Widget _paymentCard(Map<String, dynamic> r, int realIdx) {
    final bool paid = r['paid'] as bool;
    final double billing = _asDouble(r['billing']);
    final double tips = _asDouble(r['tips']);
    final int deliveries = (r['deliveries'] ?? 0).toInt();
    final double commission = _asDouble(r['commission']);
    final double payout = _asDouble(r['payout']);

    return InkWell(
      onTap: () => _showRiderOrders(r),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _red.withValues(alpha: 0.08), width: 1.5),
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
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(color: _red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
                    child: const Icon(Icons.person_rounded, color: _red, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r['name'] as String, style: GoogleFonts.poppins(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('Repartidor Activo', style: GoogleFonts.poppins(color: Colors.black26, fontSize: 12, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  if (paid) _buildPaidBadge(),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  _buildMetric('FACTURACIÓN', 'S/. ${billing.toStringAsFixed(2)}'),
                  const Spacer(),
                  _buildMetric('PROPINA', 'S/. ${tips.toStringAsFixed(2)}'),
                  const Spacer(),
                  _buildMetric('PEDIDOS', '$deliveries'),
                  const Spacer(),
                  _buildMetric('COMISIÓN', '${(commission * 100).round()}%'),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(color: Colors.black12, height: 1),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('TOTAL A PAGAR (INCL. PROPINA)', style: GoogleFonts.poppins(color: Colors.black38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                      const SizedBox(height: 4),
                      Text('S/. ${payout.toStringAsFixed(2)}', style: GoogleFonts.poppins(color: _red, fontWeight: FontWeight.bold, fontSize: 20)),
                    ],
                  ),
                  if (!paid)
                    ElevatedButton(
                      onPressed: () => _processPay(realIdx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _red,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text('Procesar Pago', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRiderOrders(Map<String, dynamic> rider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _RiderOrdersModal(rider: rider),
    );
  }

  Widget _buildMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.poppins(color: Colors.black26, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        const SizedBox(height: 4),
        Text(value, style: GoogleFonts.poppins(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }

  Widget _buildPaidBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: _green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(30)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_rounded, color: _green, size: 14),
          const SizedBox(width: 4),
          Text('PAGADO', style: GoogleFonts.poppins(color: _green, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Center(
      child: Column(
        children: [
          const Icon(Icons.done_all_rounded, color: Colors.black12, size: 32),
          const SizedBox(height: 8),
          Text(
            'FIN DE LA LISTA PENDIENTE',
            style: GoogleFonts.poppins(color: Colors.black26, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5),
          ),
        ],
      ),
    );
  }
}

class _RiderOrdersModal extends StatefulWidget {
  final Map<String, dynamic> rider;
  const _RiderOrdersModal({required this.rider});

  @override
  State<_RiderOrdersModal> createState() => _RiderOrdersModalState();
}

class _RiderOrdersModalState extends State<_RiderOrdersModal> {
  bool _loading = true;
  List<dynamic> _orders = [];
  static const Color _red = Color(0xFFFA7516);
  static const Color _green = Color(0xFF4CAF50);

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  Future<void> _fetchOrders() async {
    try {
      final res = await ApiService.getList('/admin/riders/${widget.rider['id']}/pending-orders');
      if (mounted) {
        setState(() {
          _orders = res;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Historial Pendiente', style: GoogleFonts.poppins(color: Colors.black38, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                    Text(widget.rider['name'], style: GoogleFonts.poppins(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 20)),
                  ],
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.black45),
                  style: IconButton.styleFrom(backgroundColor: Colors.black.withValues(alpha: 0.05)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Colors.black12),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: _red))
                : _orders.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.assignment_turned_in_outlined, size: 64, color: Colors.black.withValues(alpha: 0.05)),
                            const SizedBox(height: 16),
                            Text('No hay pedidos pendientes', style: GoogleFonts.poppins(color: Colors.black26, fontSize: 14)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(24),
                        itemCount: _orders.length,
                        itemBuilder: (context, index) => _orderItem(_orders[index]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _orderItem(Map<String, dynamic> o) {
    String formattedDate = '';
    try {
      var date = DateTime.parse(o['created_at']);
      if (!date.isUtc) {
        final str = o['created_at'].toString();
        if (!str.contains('Z') && !str.contains('+') && !str.contains('-')) {
          date = DateTime.parse('${str}Z');
        }
      }
      final peruDate = date.toUtc().subtract(const Duration(hours: 5));
      formattedDate = DateFormat('dd MMM, hh:mm a', 'es').format(peruDate);
    } catch (_) {
      formattedDate = o['created_at'].toString();
    }
    final double fee = (o['delivery_fee'] ?? 0).toDouble();
    final double tip = (o['tip'] ?? 0).toDouble();
    final double commPct = (widget.rider['commission'] ?? 0).toDouble();
    final double earning = (fee * commPct) + tip;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: _red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: Text('#${o['order_code'] ?? o['id']}', style: GoogleFonts.robotoMono(color: _red, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
              const Spacer(),
              Text(formattedDate, style: GoogleFonts.poppins(color: Colors.black38, fontSize: 11, fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.restaurant_rounded, size: 16, color: Colors.black45),
              const SizedBox(width: 8),
              Expanded(
                child: Text(o['restaurant_name'] ?? 'Restaurante', style: GoogleFonts.poppins(color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 14)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.person_outline_rounded, size: 16, color: Colors.black45),
              const SizedBox(width: 8),
              Expanded(
                child: Text(o['client_name'] ?? 'Cliente', style: GoogleFonts.poppins(color: Colors.black54, fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Colors.black12),
          const SizedBox(height: 12),
          Row(
            children: [
              _detailMetric('ENVÍO', 'S/. ${fee.toStringAsFixed(2)}'),
              const Spacer(),
              _detailMetric('PROPINA', 'S/. ${tip.toStringAsFixed(2)}'),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('GANANCIA', style: GoogleFonts.poppins(color: Colors.black38, fontSize: 9, fontWeight: FontWeight.bold)),
                  Text('S/. ${earning.toStringAsFixed(2)}', style: GoogleFonts.poppins(color: _green, fontWeight: FontWeight.bold, fontSize: 15)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _detailMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.poppins(color: Colors.black38, fontSize: 9, fontWeight: FontWeight.bold)),
        Text(value, style: GoogleFonts.poppins(color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 13)),
      ],
    );
  }
}






