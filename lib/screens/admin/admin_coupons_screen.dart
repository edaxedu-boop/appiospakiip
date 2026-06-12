import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';

class AdminCouponsScreen extends StatefulWidget {
  const AdminCouponsScreen({super.key});

  @override
  State<AdminCouponsScreen> createState() => _AdminCouponsScreenState();
}

class _AdminCouponsScreenState extends State<AdminCouponsScreen> {
  static const Color _bg = Color(0xFFFFFFFF);
  static const Color _red = Color(0xFFFA7516);
  static const Color _green = Color(0xFF4CAF50);

  bool _loading = true;
  List<Map<String, dynamic>> _coupons = [];
  List<Map<String, dynamic>> _restaurants = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final couponsData = await ApiService.getList('/coupons');
      final restaurantsData = await ApiService.getList('/restaurants');
      setState(() {
        _coupons = couponsData.cast<Map<String, dynamic>>();
        _restaurants = restaurantsData.cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      _snack('Error al cargar datos: $e', Colors.red);
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _delete(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(
          'Eliminar Cupón',
          style: GoogleFonts.poppins(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          '¿Seguro que deseas eliminar este cupón permanentemente?',
          style: GoogleFonts.poppins(color: Colors.black54),
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
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: Text('Eliminar', style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await ApiService.delete('/coupons/$id');
      _load();
      _snack('Cupón eliminado correctamente', _red);
    } catch (e) {
      _snack('Error: $e', Colors.red);
    }
  }

  Future<void> _toggleStatus(int id, bool currentActive) async {
    try {
      await ApiService.put('/coupons/$id', {
        'active': !currentActive,
      });
      _load();
      _snack(!currentActive ? 'Cupón activado' : 'Cupón desactivado', Colors.green);
    } catch (e) {
      _snack('Error: $e', Colors.red);
    }
  }

  void _openForm({Map<String, dynamic>? coupon}) {
    final isEdit = coupon != null;
    final codeCtrl = TextEditingController(text: coupon?['code'] ?? '');
    final discountValCtrl = TextEditingController(text: coupon?['discount_value']?.toString() ?? '');
    final minOrderValCtrl = TextEditingController(text: coupon?['min_order_value']?.toString() ?? '0.00');
    final usageLimitCtrl = TextEditingController(
      text: coupon?['usage_limit'] != null ? coupon!['usage_limit'].toString() : '',
    );
    
    String discountType = coupon?['discount_type'] ?? 'fixed'; // fixed | percent
    String restaurantScope = coupon?['restaurant_scope'] ?? 'all'; // all | specific
    List<int> selectedRestaurants = List<int>.from(coupon?['applicable_restaurants'] ?? []);
    bool active = coupon?['active'] ?? true;
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.85,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFFFFFFFF),
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.black54,
                          size: 20,
                        ),
                      ),
                      Text(
                        isEdit ? 'Editar Cupón' : 'Nuevo Cupón',
                        style: GoogleFonts.poppins(
                          color: Colors.black87,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _field(
                    ctrl: codeCtrl,
                    label: 'CÓDIGO DE CUPÓN',
                    icon: Icons.confirmation_number_rounded,
                    textCapitalization: TextCapitalization.characters,
                  ),
                  const SizedBox(height: 16),
                  
                  // Discount Type Selector
                  Text(
                    'TIPO DE DESCUENTO',
                    style: GoogleFonts.poppins(
                      color: Colors.black54,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: Center(
                            child: Text(
                              'Monto Fijo (S/.)',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                color: discountType == 'fixed' ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                          selected: discountType == 'fixed',
                          selectedColor: _red,
                          backgroundColor: Colors.black.withValues(alpha: 0.05),
                          onSelected: (val) {
                            if (val) setSheet(() => discountType = 'fixed');
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ChoiceChip(
                          label: Center(
                            child: Text(
                              'Porcentaje (%)',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                color: discountType == 'percent' ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                          selected: discountType == 'percent',
                          selectedColor: _red,
                          backgroundColor: Colors.black.withValues(alpha: 0.05),
                          onSelected: (val) {
                            if (val) setSheet(() => discountType = 'percent');
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: _field(
                          ctrl: discountValCtrl,
                          label: discountType == 'fixed' ? 'VALOR (S/.)' : 'VALOR (%)',
                          icon: Icons.monetization_on_rounded,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _field(
                          ctrl: minOrderValCtrl,
                          label: 'MIN. COMPRA (S/.)',
                          icon: Icons.shopping_bag_rounded,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _field(
                    ctrl: usageLimitCtrl,
                    label: 'LÍMITE DE USO (DEJAR EN BLANCO PARA ILIMITADO)',
                    icon: Icons.loop_rounded,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),

                  // Restaurant Scope Selector
                  Text(
                    'ALCANCE DE RESTAURANTES',
                    style: GoogleFonts.poppins(
                      color: Colors.black54,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: Center(
                            child: Text(
                              'Todos',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                color: restaurantScope == 'all' ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                          selected: restaurantScope == 'all',
                          selectedColor: _red,
                          backgroundColor: Colors.black.withValues(alpha: 0.05),
                          onSelected: (val) {
                            if (val) setSheet(() => restaurantScope = 'all');
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ChoiceChip(
                          label: Center(
                            child: Text(
                              'Específicos',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                color: restaurantScope == 'specific' ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                          selected: restaurantScope == 'specific',
                          selectedColor: _red,
                          backgroundColor: Colors.black.withValues(alpha: 0.05),
                          onSelected: (val) {
                            if (val) setSheet(() => restaurantScope = 'specific');
                          },
                        ),
                      ),
                    ],
                  ),
                  
                  if (restaurantScope == 'specific') ...[
                    const SizedBox(height: 16),
                    Text(
                      'SELECCIONA RESTAURANTES APLICABLES',
                      style: GoogleFonts.poppins(
                        color: Colors.black54,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 180),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.black12),
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _restaurants.length,
                        itemBuilder: (ctx, idx) {
                          final rest = _restaurants[idx];
                          final id = rest['id'] as int;
                          final name = rest['name'] as String;
                          final isSelected = selectedRestaurants.contains(id);
                          return CheckboxListTile(
                            activeColor: _red,
                            title: Text(
                              name,
                              style: GoogleFonts.poppins(fontSize: 13, color: Colors.black87),
                            ),
                            value: isSelected,
                            onChanged: (val) {
                              setSheet(() {
                                if (val == true) {
                                  selectedRestaurants.add(id);
                                } else {
                                  selectedRestaurants.remove(id);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: saving
                          ? null
                          : () async {
                              final code = codeCtrl.text.trim();
                              final discountVal = double.tryParse(discountValCtrl.text) ?? 0.0;
                              final minOrderVal = double.tryParse(minOrderValCtrl.text) ?? 0.0;

                              if (code.isEmpty || discountVal <= 0.0) {
                                _snack('Por favor, ingresa un código válido y un valor de descuento mayor a 0', Colors.red);
                                return;
                              }

                              if (restaurantScope == 'specific' && selectedRestaurants.isEmpty) {
                                _snack('Selecciona al menos un restaurante aplicable', Colors.red);
                                return;
                              }

                              setSheet(() => saving = true);
                              try {
                                final payload = {
                                  'code': code.toUpperCase(),
                                  'discount_type': discountType,
                                  'discount_value': discountVal,
                                  'min_order_value': minOrderVal,
                                  'restaurant_scope': restaurantScope,
                                  'applicable_restaurants': restaurantScope == 'specific' ? selectedRestaurants : [],
                                  'active': active,
                                  'usage_limit': usageLimitCtrl.text.trim().isEmpty ? null : int.tryParse(usageLimitCtrl.text.trim()),
                                };

                                if (isEdit) {
                                  await ApiService.put('/coupons/${coupon['id']}', payload);
                                } else {
                                  await ApiService.postAuth('/coupons', payload);
                                }

                                _load();
                                Navigator.pop(ctx);
                                _snack(
                                  isEdit ? 'Cupón actualizado con éxito' : 'Cupón creado con éxito',
                                  Colors.green,
                                );
                              } catch (e) {
                                setSheet(() => saving = false);
                                _snack('Error: $e', Colors.red);
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _red,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        saving ? 'Guardando...' : 'Guardar Cupón',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController ctrl,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      style: GoogleFonts.poppins(color: Colors.black87, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(color: Colors.black45, fontSize: 12),
        prefixIcon: Icon(icon, color: _red),
        filled: true,
        fillColor: const Color(0xFFF7F7F7),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Cupones de Descuento',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        backgroundColor: _red,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _red))
          : _coupons.isEmpty
              ? Center(
                  child: Text(
                    'No hay cupones registrados',
                    style: GoogleFonts.poppins(color: Colors.black38),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _coupons.length,
                  itemBuilder: (ctx, i) {
                    final c = _coupons[i];
                    final isPercent = c['discount_type'] == 'percent';
                    final discountStr = isPercent ? '${c['discount_value']}%' : 'S/ ${c['discount_value']}';
                    final minOrderStr = 'Mín. compra: S/ ${c['min_order_value']}';
                    final usageCount = c['usage_count'] ?? 0;
                    final usageLimit = c['usage_limit'];
                    final usageLimitStr = usageLimit != null ? '$usageLimit' : 'Sin límite';
                    final usageStr = 'Usos: $usageCount / $usageLimitStr';
                    
                    return Card(
                      color: const Color(0xFFF9FAFB),
                      margin: const EdgeInsets.only(bottom: 16),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(color: Colors.black.withValues(alpha: 0.05)),
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: _red.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        c['code'] ?? '',
                                        style: GoogleFonts.poppins(
                                          color: _red,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: c['restaurant_scope'] == 'all' ? Colors.blue.withValues(alpha: 0.1) : Colors.purple.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        c['restaurant_scope'] == 'all' ? 'Todo Pakiip' : 'Rest. Específicos',
                                        style: GoogleFonts.poppins(
                                          color: c['restaurant_scope'] == 'all' ? Colors.blue : Colors.purple,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                Switch.adaptive(
                                  value: c['active'] ?? false,
                                  activeColor: _green,
                                  onChanged: (val) => _toggleStatus(c['id'], c['active'] ?? false),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Descuento: $discountStr',
                                      style: GoogleFonts.poppins(
                                        color: Colors.black87,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      minOrderStr,
                                      style: GoogleFonts.poppins(
                                        color: Colors.black45,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      usageStr,
                                      style: GoogleFonts.poppins(
                                        color: Colors.black54,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, color: Colors.black54),
                                      onPressed: () => _openForm(coupon: c),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                      onPressed: () => _delete(c['id']),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            if (c['restaurant_scope'] == 'specific' && c['restaurant_names'] != null) ...[
                              const Divider(height: 20),
                              Text(
                                'Restaurantes aplicables: ${(c['restaurant_names'] as List).join(', ')}',
                                style: GoogleFonts.poppins(
                                  color: Colors.black54,
                                  fontSize: 11,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
