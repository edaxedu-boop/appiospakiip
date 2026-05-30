import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/api_service.dart';

class AdminPromotionsScreen extends StatefulWidget {
  const AdminPromotionsScreen({super.key});

  @override
  State<AdminPromotionsScreen> createState() => _AdminPromotionsScreenState();
}

class _AdminPromotionsScreenState extends State<AdminPromotionsScreen> {
  static const Color _bg = Color(0xFFFFFFFF);
  static const Color _red = Color(0xFFFA7516);

  bool _loading = true;
  List<Map<String, dynamic>> _promos = [];
  List<Map<String, dynamic>> _restaurants = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final promos = await ApiService.getList('/promotions');
      final rests = await ApiService.getList('/restaurants');
      setState(() {
        _promos = promos.cast<Map<String, dynamic>>();
        _restaurants = rests.cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      _snack('Error al cargar: $e', Colors.red);
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Eliminar promoción',
          style: GoogleFonts.poppins(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          '¿Seguro que deseas eliminarla?',
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
            style: ElevatedButton.styleFrom(backgroundColor: _red),
            child: Text(
              'Eliminar',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiService.delete('/promotions/$id');
      setState(() => _promos.removeWhere((p) => p['id'] == id));
      _snack('Promoción eliminada', Colors.orange);
    } catch (e) {
      _snack('Error: $e', Colors.red);
    }
  }

  void _openForm({Map<String, dynamic>? promo}) {
    final isEdit = promo != null;
    final titleCtrl = TextEditingController(text: promo?['title'] ?? '');
    final descCtrl = TextEditingController(text: promo?['description'] ?? '');
    final linkCtrl = TextEditingController(text: promo?['link'] ?? '');
    int? selectedRestId = promo?['restaurant_id'];
    bool saving = false;
    final formKey = GlobalKey<FormState>();

    String? localImagePath;
    String? serverImageUrl = promo?['image_url'];
    bool uploadingImage = false;

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
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _red.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.local_offer_rounded,
                            color: _red,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            isEdit ? 'Editar Promoción' : 'Nueva Promoción',
                            style: GoogleFonts.poppins(
                              color: Colors.black87,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(ctx),
                          child: const Icon(
                            Icons.close_rounded,
                            color: Colors.black38,
                            size: 22,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),

                    // Título
                    _field(
                      ctrl: titleCtrl,
                      label: 'Título del Banner *',
                      hint: 'Ej: 2x1 en pizzas este fin de semana',
                      icon: Icons.title_rounded,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Campo requerido'
                          : null,
                    ),
                    const SizedBox(height: 12),

                    // Descripción
                    _field(
                      ctrl: descCtrl,
                      label: 'Descripción (opcional)',
                      hint: 'Breve detalle de la promo',
                      icon: Icons.description_outlined,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),

                    // Imagen selector
                    Text(
                      'Imagen del Banner *',
                      style: GoogleFonts.poppins(
                        color: Colors.black45,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () async {
                        final picker = ImagePicker();
                        final XFile? image = await picker.pickImage(
                          source: ImageSource.gallery,
                          imageQuality: 80,
                        );
                        if (image != null) {
                          setSheet(() {
                            localImagePath = image.path;
                            serverImageUrl = null; // Priorizar local
                          });
                        }
                      },
                      child: Container(
                        height: 140,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white10),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: localImagePath != null
                            ? (kIsWeb
                                  ? Image.network(
                                      localImagePath!,
                                      fit: BoxFit.cover,
                                    )
                                  : Image.file(
                                      File(localImagePath!),
                                      fit: BoxFit.cover,
                                    ))
                            : (serverImageUrl != null &&
                                  serverImageUrl!.isNotEmpty)
                            ? Image.network(
                                serverImageUrl!.startsWith('http')
                                    ? serverImageUrl!
                                    : '${ApiService.baseUrl}$serverImageUrl',
                                fit: BoxFit.cover,
                              )
                            : Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.add_photo_alternate_outlined,
                                      color: _red,
                                      size: 30,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Seleccionar Imagen',
                                      style: GoogleFonts.poppins(
                                        color: Colors.black38,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Divider con etiqueta OPCIONALES
                    Row(
                      children: [
                        const Expanded(child: Divider(color: Colors.white12)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            'OPCIONALES',
                            style: GoogleFonts.poppins(
                              color: Colors.black26,
                              fontSize: 10,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        const Expanded(child: Divider(color: Colors.white12)),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Restaurante vinculado
                    Text(
                      'Restaurante al que lleva al hacer clic',
                      style: GoogleFonts.poppins(
                        color: Colors.black45,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int?>(
                          value: selectedRestId,
                          isExpanded: true,
                          dropdownColor: const Color(0xFFF3F4F6),
                          style: GoogleFonts.poppins(
                            color: Colors.black87,
                            fontSize: 13,
                          ),
                          hint: Text(
                            'Sin restaurante',
                            style: GoogleFonts.poppins(
                              color: Colors.black38,
                              fontSize: 13,
                            ),
                          ),
                          items: [
                            DropdownMenuItem<int?>(
                              value: null,
                              child: Text(
                                'Sin restaurante',
                                style: GoogleFonts.poppins(
                                  color: Colors.black38,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            ..._restaurants.map(
                              (r) => DropdownMenuItem<int?>(
                                value: r['id'] as int?,
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.storefront_rounded,
                                      color: _red,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        r['name'] ?? '',
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.poppins(
                                          color: Colors.black87,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          onChanged: (v) => setSheet(() => selectedRestId = v),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Link externo
                    _field(
                      ctrl: linkCtrl,
                      label: 'Link externo (alternativo al restaurante)',
                      hint: 'https://mipromo.com',
                      icon: Icons.link_rounded,
                      keyboardType: TextInputType.url,
                    ),
                    const SizedBox(height: 24),

                    // Botón guardar
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: saving
                            ? null
                            : () async {
                                if (localImagePath == null &&
                                    (serverImageUrl == null ||
                                        serverImageUrl!.isEmpty)) {
                                  _snack(
                                    'Selecciona una imagen',
                                    Colors.orange,
                                  );
                                  return;
                                }

                                setSheet(() => saving = true);

                                try {
                                  String finalImageUrl = serverImageUrl ?? '';

                                  // Si hay nueva imagen local, subirla primero
                                  if (localImagePath != null) {
                                    setSheet(() => uploadingImage = true);
                                    final uploadRes =
                                        await ApiService.uploadFile(
                                          '/upload/promo',
                                          localImagePath!,
                                        );
                                    finalImageUrl = uploadRes['imageUrl'];
                                  }

                                  final payload = {
                                    'title': titleCtrl.text.trim(),
                                    'description': descCtrl.text.trim(),
                                    'image_url': finalImageUrl,
                                    'restaurant_id': selectedRestId,
                                    'link': linkCtrl.text.trim().isEmpty
                                        ? null
                                        : linkCtrl.text.trim(),
                                  };

                                  if (isEdit) {
                                    await ApiService.put(
                                      '/promotions/${promo['id']}',
                                      payload,
                                    );
                                  } else {
                                    await ApiService.postAuth(
                                      '/promotions',
                                      payload,
                                    );
                                  }
                                  await _load();
                                  if (context.mounted) Navigator.pop(ctx);
                                  _snack(
                                    isEdit
                                        ? '✅ Promoción actualizada'
                                        : '✅ Promoción creada',
                                    const Color(0xFF2E7D32),
                                  );
                                } catch (e) {
                                  setSheet(() {
                                    saving = false;
                                    uploadingImage = false;
                                  });
                                  _snack('Error: $e', Colors.red);
                                }
                              },
                        icon: saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  color: Colors.black87,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.save_alt_rounded,
                                color: Colors.black87,
                                size: 20,
                              ),
                        label: Text(
                          saving
                              ? (uploadingImage
                                    ? 'Subiendo imagen…'
                                    : 'Guardando…')
                              : (isEdit
                                    ? 'Guardar Cambios'
                                    : 'Crear Promoción'),
                          style: GoogleFonts.poppins(
                            color: Colors.black87,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _red,
                          disabledBackgroundColor: _red.withValues(alpha: 0.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 4,
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

  Widget _field({
    required TextEditingController ctrl,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) => TextFormField(
    controller: ctrl,
    keyboardType: keyboardType,
    validator: validator,
    maxLines: maxLines,
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
    return Scaffold(
      backgroundColor: _bg,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: _openForm,
            icon: const Icon(
              Icons.add_rounded,
              color: Colors.black87,
              size: 22,
            ),
            label: Text(
              'Nueva Promoción',
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
        child: Column(
          children: [
            // AppBar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(
                      Icons.arrow_back_rounded,
                      color: Colors.black87,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Gestionar Promociones',
                    style: GoogleFonts.poppins(
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _load,
                    child: const Icon(
                      Icons.refresh_rounded,
                      color: Colors.black38,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: _red))
                  : _promos.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.local_offer_outlined,
                            color: Colors.white12,
                            size: 64,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No hay promociones aún',
                            style: GoogleFonts.poppins(
                              color: Colors.black38,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Toca "Nueva Promoción" para crear la primera',
                            style: GoogleFonts.poppins(
                              color: Colors.black26,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                      itemCount: _promos.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (_, i) {
                        final p = _promos[i];
                        return _PromoCard(
                          promo: p,
                          onEdit: () => _openForm(promo: p),
                          onDelete: () => _delete(p['id'] as int),
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

// ── Card de promo ─────────────────────────────────────────────────
class _PromoCard extends StatelessWidget {
  final Map<String, dynamic> promo;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  static const Color _card = Color(0xFFF9FAFB);
  static const Color _red = Color(0xFFFA7516);

  const _PromoCard({
    required this.promo,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = promo['image_url'] as String? ?? '';
    final title = promo['title'] as String? ?? '';
    final description = promo['description'] as String?;
    final restName = promo['restaurant_name'] as String?;
    final link = promo['link'] as String?;

    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Imagen banner
          if (imageUrl.isNotEmpty)
            SizedBox(
              height: 130,
              width: double.infinity,
              child: Image.network(
                imageUrl.startsWith('http')
                    ? imageUrl
                    : '${ApiService.baseUrl}$imageUrl',
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  color: const Color(0xFFF3F4F6),
                  child: const Center(
                    child: Icon(
                      Icons.image_not_supported_outlined,
                      color: Colors.black26,
                      size: 36,
                    ),
                  ),
                ),
              ),
            ),

          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),

                if (description != null && description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: GoogleFonts.poppins(
                      color: Colors.black45,
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                const SizedBox(height: 8),

                // Chips de info
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    if (restName != null)
                      _Chip(
                        icon: Icons.storefront_rounded,
                        label: restName,
                        color: _red,
                      ),
                    if (link != null && link.isNotEmpty)
                      _Chip(
                        icon: Icons.link_rounded,
                        label: 'Link externo',
                        color: Colors.blue,
                      ),
                    if (restName == null && (link == null || link.isEmpty))
                      _Chip(
                        icon: Icons.info_outline,
                        label: 'Sin destino',
                        color: Colors.black26,
                      ),
                  ],
                ),

                const SizedBox(height: 12),

                // Botones acción
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onEdit,
                        icon: const Icon(
                          Icons.edit_rounded,
                          color: _red,
                          size: 15,
                        ),
                        label: Text(
                          'Editar',
                          style: GoogleFonts.poppins(
                            color: _red,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: _red, width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onDelete,
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: Colors.black38,
                          size: 15,
                        ),
                        label: Text(
                          'Eliminar',
                          style: GoogleFonts.poppins(
                            color: Colors.black38,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _Chip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: 0.30)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 13),
        const SizedBox(width: 5),
        Text(
          label,
          style: GoogleFonts.poppins(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}
