import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';
import 'package:pakiip/screens/admin/admin_restaurant_orders_history_screen.dart';

class AdminRestaurantsScreen extends StatefulWidget {
  const AdminRestaurantsScreen({super.key});

  @override
  State<AdminRestaurantsScreen> createState() => _AdminRestaurantsScreenState();
}

class _AdminRestaurantsScreenState extends State<AdminRestaurantsScreen> {
  // ── Palette ─────────────────────────────────────────────────────────────────
  static const Color _card = Color(0xFFF9FAFB);
  static const Color _red = Color(0xFFFA7516);
  static const Color _bg = Color(0xFFFFFFFF);

  bool _loading = true;
  List<Map<String, dynamic>> _restaurants = [];
  List<Map<String, dynamic>> _globalCats = [];
  Map<String, double> _planPrices = {};

  @override
  void initState() {
    super.initState();
    _loadRestaurants();
  }

  Future<void> _loadRestaurants() async {
    setState(() => _loading = true);
    try {
      final list = await ApiService.getList('/restaurants');
      final cats = await ApiService.getList('/restaurant-categories/public');

      // Intentar cargar planes de forma independiente para no romper la carga principal
      try {
        final plans = await ApiService.getList('/plans');
        _planPrices = {
          for (var p in plans)
            p['name'].toString(): double.tryParse(p['price'].toString()) ?? 0.0,
        };
      } catch (e) {
        debugPrint('Error loading plans: $e');
      }

      setState(() {
        _globalCats = cats.cast<Map<String, dynamic>>();

        _restaurants = list.map((item) {
          final r = item as Map<String, dynamic>;
          final planName = r['plan'] ?? 'Pakiip Emprende';
          final price =
              _planPrices[planName] ??
              (planName == 'Pakiip Empresarial' ? 149.0 : 0.0);

          return {
            'id': r['id'],
            'name': r['name'] ?? '',
            'email': r['email'] ?? '',
            'plan': planName,
            'plan_price': price,
            'region': r['region'] ?? 'Otras',
            'commission_rate': r['commission_rate'] ?? 0.00,
            'plan_expiry': r['plan_expiry'],
            'active': r['active'] ?? true,
            'category_ids': (r['category_ids'] as List?)?.cast<int>() ?? [],
            'avatarColor': _planColor(planName),
            'icon': _planIcon(planName),
          };
        }).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      _snack('Error al cargar restaurantes', Colors.red);
    }
  }

  Color _planColor(String plan) {
    switch (plan) {
      case 'Pakiip Empresarial':
        return const Color(0xFFFA7516);
      case 'Pakiip Emprende':
      default:
        return const Color(0xFF4CAF50);
    }
  }

  IconData _planIcon(String plan) {
    switch (plan) {
      case 'Pakiip Empresarial':
        return Icons.business_center_rounded;
      case 'Pakiip Emprende':
      default:
        return Icons.rocket_launch_rounded;
    }
  }

  String _query = '';

  List<Map<String, dynamic>> get _filtered {
    if (_query.trim().isEmpty) return _restaurants;
    final q = _query.toLowerCase();
    return _restaurants
        .where(
          (r) =>
              (r['name'] as String).toLowerCase().contains(q) ||
              (r['plan'] as String).toLowerCase().contains(q),
        )
        .toList();
  }

  // ── Actions ──────────────────────────────────────────────────────────────────
  Future<void> _suspend(int index) async {
    final id = _restaurants[index]['id'];
    try {
      await ApiService.patch('/restaurants/$id/status', {'active': false});
      setState(() => _restaurants[index]['active'] = false);
      _snack('Restaurante suspendido', Colors.orange);
    } catch (e) {
      _snack('Error: $e', Colors.red);
    }
  }

  Future<void> _reactivate(int index) async {
    final id = _restaurants[index]['id'];
    try {
      await ApiService.patch('/restaurants/$id/status', {'active': true});
      setState(() {
        _restaurants[index]['active'] = true;
        _restaurants[index]['daysLeft'] = 30;
      });
      _snack('Restaurante reactivado ✅', const Color(0xFF4CAF50));
    } catch (e) {
      _snack('Error: $e', Colors.red);
    }
  }

  Future<void> _deleteRestaurant(int index) async {
    final id = _restaurants[index]['id'];
    final name = _restaurants[index]['name'];

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(
          '¿Eliminar Restaurante?',
          style: GoogleFonts.poppins(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Estás a punto de eliminar permanentemente a "$name". Esta acción no se puede deshacer.',
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
            style: ElevatedButton.styleFrom(backgroundColor: _red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Eliminar',
              style: GoogleFonts.poppins(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ApiService.delete('/restaurants/$id');
      setState(() {
        _restaurants.removeAt(index);
      });
      _snack('Restaurante eliminado correctamente', Colors.green);
    } catch (e) {
      _snack('Error al eliminar: $e', Colors.red);
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

  void _editRestaurant(Map<String, dynamic> r, int realIdx) {
    final nameCtrl = TextEditingController(text: r['name']);
    final emailCtrl = TextEditingController(text: r['email']);
    final passCtrl = TextEditingController();
    final commissionCtrl = TextEditingController(
      text: (r['commission_rate'] ?? 0).toString(),
    );
    String selectedPlan = r['plan'] as String? ?? 'Básico';
    String selectedRegion = r['region'] as String? ?? 'Otras';
    List<int> selectedCatIds = List<int>.from(r['category_ids'] ?? []);
    bool passVisible = false;
    bool saving = false;
    final formKey = GlobalKey<FormState>();

    const regions = [
      'Amazonas',
      'Áncash',
      'Apurímac',
      'Arequipa',
      'Ayacucho',
      'Cajamarca',
      'Callao',
      'Cusco',
      'Huancavelica',
      'Huánuco',
      'Ica',
      'Junín',
      'La Libertad',
      'Lambayeque',
      'Lima',
      'Loreto',
      'Madre de Dios',
      'Moquegua',
      'Pasco',
      'Piura',
      'Puno',
      'San Martín',
      'Tacna',
      'Tumbes',
      'Ucayali',
      'Otras',
    ];

    const plans = [
      {'name': 'Pakiip Emprende', 'color': Color(0xFF4CAF50)},
      {'name': 'Pakiip Empresarial', 'color': Color(0xFFFA7516)},
    ];

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
            decoration: const BoxDecoration(
              color: Color(0xFFFFFFFF),
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle
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
                    const SizedBox(height: 18),

                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: _red.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.edit_note_rounded,
                                color: _red,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Text(
                              'Editar: ${r['name']}',
                              style: GoogleFonts.poppins(
                                color: Colors.black87,
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Colors.black38,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Nombre
                    _sheetField(
                      ctrl: nameCtrl,
                      label: 'Nombre del Restaurante',
                      hint: 'Ej: Parrillas El Gaucho',
                      icon: Icons.storefront_outlined,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Ingresa el nombre'
                          : null,
                    ),
                    const SizedBox(height: 12),

                    // Email
                    _sheetField(
                      ctrl: emailCtrl,
                      label: 'Correo Electrónico',
                      hint: 'restaurante@pakiip.com',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Ingresa el correo';
                        }
                        if (!v.contains('@')) return 'Correo inválido';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    // Nueva contraseña (opcional)
                    TextFormField(
                      controller: passCtrl,
                      obscureText: !passVisible,
                      validator: (v) {
                        if (v != null && v.isNotEmpty && v.length < 6) {
                          return 'Mínimo 6 caracteres';
                        }
                        return null;
                      },
                      style: GoogleFonts.poppins(
                        color: Colors.black87,
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Nueva Contraseña (opcional)',
                        labelStyle: GoogleFonts.poppins(
                          color: Colors.black38,
                          fontSize: 13,
                        ),
                        hintText: 'Dejar vacío para no cambiar',
                        hintStyle: GoogleFonts.poppins(
                          color: Colors.black26,
                          fontSize: 13,
                        ),
                        prefixIcon: const Icon(
                          Icons.lock_outline_rounded,
                          color: _red,
                          size: 18,
                        ),
                        suffixIcon: GestureDetector(
                          onTap: () =>
                              setSheet(() => passVisible = !passVisible),
                          child: Icon(
                            passVisible
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                            color: Colors.black38,
                            size: 18,
                          ),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF3F4F6),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: _red, width: 1.5),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: Colors.orange,
                            width: 1.5,
                          ),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: Colors.orange,
                            width: 1.5,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Región
                    DropdownButtonFormField<String>(
                      initialValue: selectedRegion,
                      dropdownColor: const Color(0xFFFFFFFF),
                      style: GoogleFonts.poppins(
                        color: Colors.black87,
                        fontSize: 13,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Región (Departamento)',
                        labelStyle: GoogleFonts.poppins(
                          color: Colors.black38,
                          fontSize: 13,
                        ),
                        prefixIcon: const Icon(
                          Icons.map_outlined,
                          color: _red,
                          size: 18,
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF3F4F6),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      items: regions.map((reg) {
                        return DropdownMenuItem(value: reg, child: Text(reg));
                      }).toList(),
                      onChanged: (v) => setSheet(() => selectedRegion = v!),
                    ),
                    const SizedBox(height: 20),

                    // Plan label
                    Text(
                      'PLAN',
                      style: GoogleFonts.poppins(
                        color: Colors.black38,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Plan chips
                    Row(
                      children: plans.map((p) {
                        final isSelected = selectedPlan == p['name'];
                        final col = p['color'] as Color;
                        final planName = p['name'] as String;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () =>
                                setSheet(() => selectedPlan = planName),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              margin: EdgeInsets.only(
                                right: planName == 'Pakiip Emprende' ? 12 : 0,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? col.withValues(alpha: 0.1)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected ? col : Colors.black12,
                                  width: 2,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    planName == 'Pakiip Emprende'
                                        ? Icons.rocket_launch_rounded
                                        : Icons.business_center_rounded,
                                    color: isSelected ? col : Colors.black26,
                                    size: 28,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    planName,
                                    style: GoogleFonts.poppins(
                                      color: isSelected ? col : Colors.black45,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    if (selectedPlan == 'Pakiip Emprende') ...[
                      const SizedBox(height: 24),
                      Text(
                        'COMISIÓN (%) PARA ESTE RESTAURANTE',
                        style: GoogleFonts.poppins(
                          color: const Color(0xFF4CAF50),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: TextField(
                          controller: commissionCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          style: GoogleFonts.poppins(
                            color: Colors.black87,
                            fontSize: 14,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Ej: 10',
                            hintStyle: TextStyle(color: Colors.black26),
                            suffixText: '%',
                            suffixStyle: TextStyle(color: Colors.black26),
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Categorías
                    Text(
                      'CATEGORÍAS (Selecciona una o más)',
                      style: GoogleFonts.poppins(
                        color: Colors.black38,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _globalCats.map((c) {
                        final id = c['id'] as int;
                        final isSelected = selectedCatIds.contains(id);
                        return FilterChip(
                          selected: isSelected,
                          onSelected: (v) => setSheet(() {
                            v
                                ? selectedCatIds.add(id)
                                : selectedCatIds.remove(id);
                          }),
                          label: Text(
                            c['name'] ?? '',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          backgroundColor: Colors.white,
                          selectedColor: _red.withValues(alpha: 0.15),
                          checkmarkColor: _red,
                          labelStyle: TextStyle(
                            color: isSelected ? _red : Colors.black87,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: isSelected ? _red : Colors.black12,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),

                    // Guardar
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: saving
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) return;
                                setSheet(() => saving = true);

                                final planMap = {
                                  'Pakiip Emprende': 1,
                                  'Pakiip Empresarial': 2,
                                };
                                final payload = {
                                  'name': nameCtrl.text.trim(),
                                  'email': emailCtrl.text.trim(),
                                  'plan_id': planMap[selectedPlan] ?? 1,
                                  'category_ids': selectedCatIds,
                                  'region': selectedRegion,
                                  'commission_rate':
                                      double.tryParse(commissionCtrl.text) ??
                                      0.0,
                                };
                                if (passCtrl.text.isNotEmpty) {
                                  payload['password'] = passCtrl.text;
                                }

                                try {
                                  await ApiService.put(
                                    '/restaurants/${r['id']}',
                                    payload,
                                  );
                                  setState(() {
                                    _restaurants[realIdx]['name'] = nameCtrl
                                        .text
                                        .trim();
                                    _restaurants[realIdx]['email'] = emailCtrl
                                        .text
                                        .trim();
                                    _restaurants[realIdx]['plan'] =
                                        selectedPlan;
                                    _restaurants[realIdx]['commission_rate'] =
                                        double.tryParse(commissionCtrl.text) ??
                                        0;
                                    _restaurants[realIdx]['region'] =
                                        selectedRegion;
                                    _restaurants[realIdx]['avatarColor'] =
                                        _planColor(selectedPlan);
                                    _restaurants[realIdx]['icon'] = _planIcon(
                                      selectedPlan,
                                    );
                                    _restaurants[realIdx]['category_ids'] =
                                        List<int>.from(selectedCatIds);
                                  });
                                  if (context.mounted) Navigator.pop(ctx);
                                  _snack(
                                    'Restaurante actualizado',
                                    Colors.green,
                                  );
                                } catch (e) {
                                  setSheet(() => saving = false);
                                  _snack('Error: $e', Colors.red);
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _red,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: saving
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : Text(
                                'GUARDAR CAMBIOS',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
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
      ),
    );
  }

  void _addRestaurant() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final commissionCtrl = TextEditingController(text: '10');
    String selectedPlan = 'Pakiip Emprende';
    String selectedRegion = 'Lima';
    List<int> selectedCatIds = [];
    bool passVisible = false;
    bool submitting = false;
    final formKey = GlobalKey<FormState>();

    const regions = [
      'Amazonas',
      'Áncash',
      'Apurímac',
      'Arequipa',
      'Ayacucho',
      'Cajamarca',
      'Callao',
      'Cusco',
      'Huancavelica',
      'Huánuco',
      'Ica',
      'Junín',
      'La Libertad',
      'Lambayeque',
      'Lima',
      'Loreto',
      'Madre de Dios',
      'Moquegua',
      'Pasco',
      'Piura',
      'Puno',
      'San Martín',
      'Tacna',
      'Tumbes',
      'Ucayali',
      'Otras',
    ];

    const plans = [
      {
        'name': 'Pakiip Emprende',
        'color': Color(0xFF4CAF50),
        'icon': Icons.rocket_launch_rounded,
      },
      {
        'name': 'Pakiip Empresarial',
        'color': Color(0xFFFA7516),
        'icon': Icons.business_center_rounded,
      },
    ];

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
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
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
                    const SizedBox(height: 24),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: _red.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.storefront_rounded,
                                color: _red,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Text(
                              'Nuevo Restaurante',
                              style: GoogleFonts.poppins(
                                color: Colors.black87,
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Colors.black38,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    _sheetField(
                      ctrl: nameCtrl,
                      label: 'Nombre del Restaurante',
                      hint: 'Ej: Sabores del Perú',
                      icon: Icons.storefront_outlined,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Ingresa el nombre'
                          : null,
                    ),
                    const SizedBox(height: 12),

                    _sheetField(
                      ctrl: emailCtrl,
                      label: 'Correo Electrónico',
                      hint: 'contacto@restaurante.com',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) => (v == null || !v.contains('@'))
                          ? 'Correo inválido'
                          : null,
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: passCtrl,
                      obscureText: !passVisible,
                      validator: (v) => (v == null || v.length < 6)
                          ? 'Mínimo 6 caracteres'
                          : null,
                      style: GoogleFonts.poppins(
                        color: Colors.black87,
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Contraseña',
                        labelStyle: GoogleFonts.poppins(
                          color: Colors.black38,
                          fontSize: 13,
                        ),
                        prefixIcon: const Icon(
                          Icons.lock_outline_rounded,
                          color: _red,
                          size: 18,
                        ),
                        suffixIcon: IconButton(
                          onPressed: () =>
                              setSheet(() => passVisible = !passVisible),
                          icon: Icon(
                            passVisible
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                            size: 18,
                          ),
                          color: Colors.black26,
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8F9FA),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    DropdownButtonFormField<String>(
                      initialValue: selectedRegion,
                      dropdownColor: Colors.white,
                      style: GoogleFonts.poppins(
                        color: Colors.black87,
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Región (Departamento)',
                        labelStyle: GoogleFonts.poppins(
                          color: Colors.black38,
                          fontSize: 13,
                        ),
                        prefixIcon: const Icon(
                          Icons.location_on_outlined,
                          color: _red,
                          size: 18,
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8F9FA),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      items: regions
                          .map(
                            (reg) =>
                                DropdownMenuItem(value: reg, child: Text(reg)),
                          )
                          .toList(),
                      onChanged: (v) => setSheet(() => selectedRegion = v!),
                    ),
                    const SizedBox(height: 24),

                    Text(
                      'SELECCIONA UN PLAN',
                      style: GoogleFonts.poppins(
                        color: Colors.black38,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: plans.map((p) {
                        final isSelected = selectedPlan == p['name'];
                        final col = p['color'] as Color;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => setSheet(
                              () => selectedPlan = p['name'] as String,
                            ),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              margin: EdgeInsets.only(
                                right: p['name'] == 'Pakiip Emprende' ? 12 : 0,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? col.withValues(alpha: 0.1)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected ? col : Colors.black12,
                                  width: 2,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    p['icon'] as IconData,
                                    color: isSelected ? col : Colors.black26,
                                    size: 28,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    p['name'] as String,
                                    style: GoogleFonts.poppins(
                                      color: isSelected ? col : Colors.black45,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),

                    if (selectedPlan == 'Pakiip Emprende') ...[
                      Text(
                        'COMISIÓN POR SERVICIO (%)',
                        style: GoogleFonts.poppins(
                          color: Colors.black38,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F9FA),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: TextField(
                          controller: commissionCtrl,
                          keyboardType: TextInputType.number,
                          style: GoogleFonts.poppins(
                            color: Colors.black87,
                            fontWeight: FontWeight.bold,
                          ),
                          decoration: InputDecoration(
                            hintText: '10',
                            suffixText: '%',
                            prefixIcon: const Icon(
                              Icons.percent_rounded,
                              color: Colors.black26,
                              size: 18,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.all(16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    Text(
                      'CATEGORÍAS',
                      style: GoogleFonts.poppins(
                        color: Colors.black38,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _globalCats.map((c) {
                        final id = c['id'] as int;
                        final isSelected = selectedCatIds.contains(id);
                        return FilterChip(
                          selected: isSelected,
                          onSelected: (v) => setSheet(() {
                            v
                                ? selectedCatIds.add(id)
                                : selectedCatIds.remove(id);
                          }),
                          label: Text(
                            c['name'] ?? '',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          backgroundColor: Colors.white,
                          selectedColor: _red.withValues(alpha: 0.15),
                          checkmarkColor: _red,
                          labelStyle: TextStyle(
                            color: isSelected ? _red : Colors.black54,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: isSelected ? _red : Colors.black12,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 32),

                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: submitting
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) return;
                                setSheet(() => submitting = true);
                                try {
                                  final planId =
                                      selectedPlan == 'Pakiip Emprende' ? 1 : 2;
                                  await ApiService.postAuth('/restaurants', {
                                    'name': nameCtrl.text.trim(),
                                    'email': emailCtrl.text.trim(),
                                    'password': passCtrl.text,
                                    'plan_id': planId,
                                    'category_ids': selectedCatIds,
                                    'region': selectedRegion,
                                    'commission_rate':
                                        double.tryParse(commissionCtrl.text) ??
                                        10.0,
                                  });
                                  await _loadRestaurants();
                                  if (context.mounted) Navigator.pop(ctx);
                                  _snack(
                                    'Restaurante creado con éxito',
                                    Colors.green,
                                  );
                                } catch (e) {
                                  setSheet(() => submitting = false);
                                  _snack('Error: $e', Colors.red);
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _red,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: submitting
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : Text(
                                'CREAR RESTAURANTE',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
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
      ),
    );
  }

  Widget _sheetField({
    required TextEditingController ctrl,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) => TextFormField(
    controller: ctrl,
    keyboardType: keyboardType,
    validator: validator,
    style: GoogleFonts.poppins(color: Colors.black87, fontSize: 14),
    decoration: InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.poppins(color: Colors.black38, fontSize: 13),
      hintText: hint,
      hintStyle: GoogleFonts.poppins(color: Colors.black26, fontSize: 13),
      prefixIcon: Icon(icon, color: _red, size: 18),
      filled: true,
      fillColor: const Color(0xFFF3F4F6),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _red, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.orange, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.orange, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final list = _filtered;

    return Scaffold(
      backgroundColor: _bg,
      // ── FAB ────────────────────────────────────────────────────────────────
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: _addRestaurant,
            icon: const Icon(
              Icons.add_rounded,
              color: Colors.black87,
              size: 22,
            ),
            label: Text(
              'Añadir Restaurante',
              style: GoogleFonts.poppins(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              elevation: 6,
              shadowColor: _red.withValues(alpha: 0.40),
            ),
          ),
        ),
      ),

      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFFFA7516)),
              )
            : Column(
                children: [
                  // ── App bar ──────────────────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Colors.black87,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Gestionar Restaurantes',
                          style: GoogleFonts.poppins(
                            color: Colors.black87,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 4),

                  // ── Search bar ───────────────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: _card,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: TextField(
                        style: GoogleFonts.poppins(
                          color: Colors.black87,
                          fontSize: 14,
                        ),
                        onChanged: (v) => setState(() => _query = v),
                        decoration: InputDecoration(
                          hintText: 'Buscar por nombre o ID...',
                          hintStyle: GoogleFonts.poppins(
                            color: Colors.black38,
                            fontSize: 14,
                          ),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: Colors.black38,
                            size: 20,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── List ─────────────────────────────────────────────────────────
                  Expanded(
                    child: list.isEmpty
                        ? Center(
                            child: Text(
                              'Sin resultados',
                              style: GoogleFonts.poppins(
                                color: Colors.black38,
                                fontSize: 14,
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.only(
                              left: 16,
                              right: 16,
                              bottom: 90,
                            ),
                            itemCount: list.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 12),
                            itemBuilder: (ctx, i) {
                              final r = list[i];
                              // find real index for mutations
                              final realIdx = _restaurants.indexOf(r);
                              return _RestaurantCard(
                                restaurant: r,
                                onSuspend: () => _suspend(realIdx),
                                onReactivate: () => _reactivate(realIdx),
                                onEdit: () => _editRestaurant(r, realIdx),
                                onDelete: () => _deleteRestaurant(realIdx),
                              );
                            },
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ── Reusable card ──────────────────────────────────────────────────────────────
class _RestaurantCard extends StatelessWidget {
  final Map<String, dynamic> restaurant;
  final VoidCallback onSuspend;
  final VoidCallback onReactivate;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  static const Color _card = Color(0xFFF9FAFB);
  static const Color _red = Color(0xFFFA7516);

  const _RestaurantCard({
    required this.restaurant,
    required this.onSuspend,
    required this.onReactivate,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final bool active = restaurant['active'] as bool;
    final Color avatarColor = restaurant['avatarColor'] as Color;
    final String plan = restaurant['plan'] as String;

    // Plan text color
    Color planColor;
    String subInfo = '';
    String expiryInfo = '';
    String countdownInfo = '';

    if (plan == 'Pakiip Empresarial') {
      planColor = const Color(0xFFFA7516); // red
      final double price =
          (restaurant['plan_price'] as num?)?.toDouble() ?? 149.0;
      subInfo = 'S/. ${price.toStringAsFixed(2)} / mes';
      expiryInfo = 'VENCE: ${_fmtDate(restaurant['plan_expiry'])}';
      countdownInfo = _getCountdown(restaurant['plan_expiry']);
    } else if (plan == 'Pakiip Emprende') {
      planColor = const Color(0xFF4CAF50); // green
      subInfo = 'Comisión: ${restaurant['commission_rate']}%';
      expiryInfo = 'VITALICIO';
    } else {
      planColor = Colors.white38;
      subInfo = 'Plan: $plan';
      expiryInfo = '';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _red.withValues(alpha: 0.1), width: 1.5),
        boxShadow: [
          // Capa inferior de profundidad (Efecto 3D base)
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            offset: const Offset(0, 8),
            blurRadius: 0,
          ),
          // Sombra de elevación suave
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            offset: const Offset(0, 10),
            blurRadius: 20,
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Info row ────────────────────────────────────────────────────────
          Row(
            children: [
              // Avatar
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: avatarColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: avatarColor.withValues(alpha: 0.2),
                    width: 2,
                  ),
                ),
                child: Icon(
                  restaurant['icon'] as IconData,
                  color: avatarColor,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              // Name + plan
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      restaurant['name'] as String,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: Colors.black87,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    RichText(
                      text: TextSpan(
                        style: GoogleFonts.poppins(fontSize: 13),
                        children: [
                          TextSpan(
                            text: subInfo,
                            style: TextStyle(
                              color: planColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (expiryInfo.isNotEmpty)
                            TextSpan(
                              text: ' • $expiryInfo',
                              style: const TextStyle(
                                color: Colors.black38,
                                fontSize: 11,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: active
                      ? const Color(0xFF4CAF50).withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  active ? 'ACTIVO' : 'INACTIVO',
                  style: GoogleFonts.poppins(
                    color: active ? const Color(0xFF4CAF50) : Colors.black38,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),

          if (countdownInfo.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _getCountdownColor(
                  restaurant['plan_expiry'],
                ).withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.timer_rounded,
                    color: _getCountdownColor(restaurant['plan_expiry']),
                    size: 14,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    countdownInfo.toUpperCase(),
                    style: GoogleFonts.poppins(
                      color: _getCountdownColor(restaurant['plan_expiry']),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 18),
          Container(height: 1, color: Colors.black.withValues(alpha: 0.03)),
          const SizedBox(height: 18),

          // ── Action buttons ──────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Ver Pedidos
              _cardAction(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AdminRestaurantOrdersHistoryScreen(
                        restaurantId: restaurant['id'] as int,
                        restaurantName: restaurant['name'] as String,
                      ),
                    ),
                  );
                },
                icon: Icons.receipt_long_rounded,
                color: Colors.black45,
              ),
              const SizedBox(width: 6),
              // Editar
              Expanded(
                child: _cardAction(
                  onTap: onEdit,
                  icon: Icons.edit_rounded,
                  color: _red,
                  label: 'Editar',
                  isPrimary: true,
                ),
              ),
              const SizedBox(width: 6),
              // Deletar
              _cardAction(
                onTap: onDelete,
                icon: Icons.delete_outline_rounded,
                color: _red,
              ),
              const SizedBox(width: 6),
              // Suspender / Reactivar
              Expanded(
                child: active
                    ? _cardAction(
                        onTap: onSuspend,
                        icon: Icons.block_rounded,
                        color: Colors.black45,
                        label: 'Suspender',
                      )
                    : _cardAction(
                        onTap: onReactivate,
                        icon: Icons.play_arrow_rounded,
                        color: Colors.black87,
                        label: 'Reactivar',
                        isPrimary: true,
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cardAction({
    required VoidCallback onTap,
    required IconData icon,
    required Color color,
    String? label,
    bool isPrimary = false,
  }) {
    return label != null
        ? GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              decoration: BoxDecoration(
                color: isPrimary ? _red : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isPrimary
                      ? _red
                      : Colors.black.withValues(alpha: 0.05),
                  width: 1.5,
                ),
                boxShadow: [
                  if (isPrimary)
                    BoxShadow(
                      color: _red.withValues(alpha: 0.2),
                      offset: const Offset(0, 4),
                      blurRadius: 0,
                    ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    offset: const Offset(0, 4),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: isPrimary ? Colors.white : color, size: 14),
                  const SizedBox(width: 4),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        label,
                        style: GoogleFonts.poppins(
                          color: isPrimary ? Colors.white : color,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
        : GestureDetector(
            onTap: onTap,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.black.withValues(alpha: 0.05),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    offset: const Offset(0, 4),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Icon(icon, color: color, size: 16),
            ),
          );
  }

  Color _getCountdownColor(dynamic expiry) {
    if (expiry == null) return Colors.white24;
    try {
      final expiryDate = DateTime.parse(expiry.toString());
      final now = DateTime.now();
      final diff = expiryDate.difference(now);

      if (diff.isNegative || diff.inDays < 3) {
        return const Color(0xFFFA7516); // Rojo alerta
      }
      if (diff.inDays < 7) return Colors.orange; // Naranja advertencia
      return Colors.white70; // Normal
    } catch (_) {
      return Colors.white24;
    }
  }

  String _getCountdown(dynamic expiry) {
    if (expiry == null) return '';
    try {
      final expiryDate = DateTime.parse(expiry.toString());
      final now = DateTime.now();
      final diff = expiryDate.difference(now);

      if (diff.isNegative) return 'PLAN VENCIDO';

      if (diff.inDays >= 1) {
        return 'Faltan ${diff.inDays} días';
      } else if (diff.inHours >= 1) {
        return 'Faltan ${diff.inHours} h';
      } else {
        return 'Faltan ${diff.inMinutes} min';
      }
    } catch (_) {
      return '';
    }
  }

  String _fmtDate(dynamic date) {
    if (date == null) return 'Vitalicio';
    try {
      final dt = DateTime.parse(date.toString());
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return date.toString();
    }
  }
}
