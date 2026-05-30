import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/api_service.dart';

class _VariantOption {
  String name;
  double? price;
  _VariantOption({required this.name, this.price});

  Map<String, dynamic> toJson() => {'name': name, 'price': price};
  factory _VariantOption.fromJson(Map<String, dynamic> j) =>
      _VariantOption(name: j['name'] ?? '', price: j['price']?.toDouble());
}

class _VariantGroup {
  String title;
  bool required = false;
  bool multiSelect = false;
  int maxSelect = 1;
  List<_VariantOption> options;

  _VariantGroup({
    required this.title,
    bool required = false,
    bool multiSelect = false,
    int maxSelect = 1,
    List<_VariantOption>? options,
  }) : required = required,
       multiSelect = multiSelect,
       maxSelect = maxSelect,
       options = options ?? [_VariantOption(name: '')];

  Map<String, dynamic> toJson() => {
    'title': title,
    'required': required,
    'multiSelect': multiSelect,
    'maxSelect': maxSelect,
    'options': options.map((o) => o.toJson()).toList(),
  };

  factory _VariantGroup.fromJson(Map<String, dynamic> j) => _VariantGroup(
    title: j['title'] ?? '',
    required: j['required'] ?? false,
    multiSelect: j['multiSelect'] ?? false,
    maxSelect: j['maxSelect'] ?? 1,
    options: (j['options'] as List?)
        ?.map((o) => _VariantOption.fromJson(o as Map<String, dynamic>))
        .toList(),
  );
}

class RestaurantAddProductScreen extends StatefulWidget {
  final List<String> categories;
  final String? initialName;
  final String? initialDescription;
  final double? initialPrice;
  final String? initialCategory;
  final String? initialImageUrl;
  final List<dynamic>? initialGroups;
  final bool editMode;

  const RestaurantAddProductScreen({
    super.key,
    required this.categories,
    this.initialName,
    this.initialDescription,
    this.initialPrice,
    this.initialCategory,
    this.initialImageUrl,
    this.initialGroups,
    this.editMode = false,
  });

  @override
  State<RestaurantAddProductScreen> createState() =>
      _RestaurantAddProductScreenState();
}

class _RestaurantAddProductScreenState
    extends State<RestaurantAddProductScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  String? _selectedCategory;

  String? _serverImageUrl;
  String? _localImagePath;
  bool _isUploading = false;

  final List<_VariantGroup> _groups = [];

  static const Color _bg = Color(0xFFFFFFFF);
  static const Color _card = Color(0xFFF9FAFB);
  static const Color _red = Color(0xFFFA7516);
  static const Color _border = Color(0xFFE0E0E0);
  static const Color _fieldBg = Color(0xFFF3F4F6);

  @override
  void initState() {
    super.initState();
    if (widget.editMode) {
      _nameCtrl.text = widget.initialName ?? '';
      _descCtrl.text = widget.initialDescription ?? '';
      _priceCtrl.text = widget.initialPrice != null
          ? widget.initialPrice!.toStringAsFixed(2)
          : '';
      _selectedCategory = widget.initialCategory;
      _serverImageUrl = widget.initialImageUrl;

      if (widget.initialGroups != null) {
        for (final g in widget.initialGroups!) {
          try {
            _groups.add(_VariantGroup.fromJson(g as Map<String, dynamic>));
          } catch (e) {
            debugPrint('Error parsing group: $e');
          }
        }
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: _card,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: _red),
              title: const Text(
                'Cámara',
                style: TextStyle(color: Colors.black87),
              ),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: _red),
              title: const Text(
                'Galería',
                style: TextStyle(color: Colors.black87),
              ),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source != null) {
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 70, // Compresión 70%
      );

      if (pickedFile != null) {
        setState(() {
          _localImagePath = pickedFile.path;
          _isUploading = true;
        });

        try {
          final res = await ApiService.uploadFile(
            '/upload/product',
            pickedFile.path,
          );
          setState(() {
            _serverImageUrl = res['imageUrl'];
            _isUploading = false;
          });
        } catch (e) {
          setState(() => _isUploading = false);
          _snack('Error al subir imagen: $e');
        }
      }
    }
  }

  void _addGroup() {
    setState(() => _groups.add(_VariantGroup(title: '')));
  }

  void _removeGroup(int i) => setState(() => _groups.removeAt(i));

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null) {
      _snack('Selecciona una categoría');
      return;
    }
    Navigator.pop(context, {
      'name': _nameCtrl.text.trim(),
      'description': _descCtrl.text.trim(),
      'price': double.tryParse(_priceCtrl.text.trim()) ?? 0,
      'category': _selectedCategory,
      'image_url': _serverImageUrl,
      'groups': _groups.map((g) => g.toJson()).toList(),
    });
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: _red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _sectionTitle(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 10, top: 20),
    child: Text(
      label,
      style: GoogleFonts.poppins(
        color: _red,
        fontWeight: FontWeight.bold,
        fontSize: 13,
        letterSpacing: 0.4,
      ),
    ),
  );

  Widget _inputField({
    required TextEditingController ctrl,
    required String hint,
    IconData? icon,
    String? Function(String?)? validator,
    TextInputType? type,
    int maxLines = 1,
    List<TextInputFormatter>? inputFormatters,
    bool enabled = true,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _fieldBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: TextFormField(
        controller: ctrl,
        keyboardType: type,
        maxLines: maxLines,
        enabled: enabled,
        inputFormatters: inputFormatters,
        validator: validator,
        style: GoogleFonts.poppins(
          color: enabled ? Colors.black87 : Colors.black26,
          fontSize: 14,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.poppins(color: Colors.black26, fontSize: 13),
          prefixIcon: icon != null ? Icon(icon, color: _red, size: 20) : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildGroupCard(int gi) {
    final group = _groups[gi];
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _red.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.tune, color: _red, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    initialValue: group.title,
                    style: GoogleFonts.poppins(
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'Nombre del grupo',
                      hintStyle: GoogleFonts.poppins(
                        color: Colors.black26,
                        fontSize: 12,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (v) => group.title = v,
                  ),
                ),
                GestureDetector(
                  onTap: () => _removeGroup(gi),
                  child: const Icon(
                    Icons.close,
                    color: Colors.black38,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _toggleChip(
                      label: 'Obligatorio',
                      active: group.required,
                      onTap: () =>
                          setState(() => group.required = !group.required),
                    ),
                    const SizedBox(width: 8),
                    _toggleChip(
                      label: group.multiSelect ? 'Varias' : 'Una sola',
                      active: group.multiSelect,
                      onTap: () => setState(
                        () => group.multiSelect = !group.multiSelect,
                      ),
                    ),
                    if (group.multiSelect) ...[
                      const SizedBox(width: 8),
                      _maxChip(group),
                    ],
                  ],
                ),
                const SizedBox(height: 14),
                ...List.generate(
                  group.options.length,
                  (oi) => _buildOptionRow(gi, oi, group.options[oi]),
                ),
                GestureDetector(
                  onTap: () => setState(
                    () => group.options.add(_VariantOption(name: '')),
                  ),
                  child: Container(
                    margin: const EdgeInsets.only(top: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: _red.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _red.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.add, color: _red, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'Agregar opción',
                          style: GoogleFonts.poppins(
                            color: _red,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
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

  Widget _buildOptionRow(int gi, int oi, _VariantOption opt) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: _fieldBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          const SizedBox(width: 10),
          Expanded(
            flex: 3,
            child: TextFormField(
              initialValue: opt.name,
              style: GoogleFonts.poppins(color: Colors.black87, fontSize: 13),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Nombre opción',
                hintStyle: GoogleFonts.poppins(
                  color: Colors.black26,
                  fontSize: 12,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onChanged: (v) => opt.name = v,
            ),
          ),
          Container(width: 1, height: 30, color: _border),
          Expanded(
            flex: 2,
            child: TextFormField(
              initialValue: opt.price != null
                  ? opt.price!.toStringAsFixed(2)
                  : '',
              style: GoogleFonts.poppins(color: Colors.black54, fontSize: 13),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              decoration: InputDecoration(
                isDense: true,
                hintText: '+S/. 0.00',
                hintStyle: GoogleFonts.poppins(
                  color: Colors.black26,
                  fontSize: 12,
                ),
                prefixText: opt.price != null ? '+S/. ' : '',
                prefixStyle: GoogleFonts.poppins(
                  color: Colors.black45,
                  fontSize: 12,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 12,
                ),
              ),
              onChanged: (v) {
                final d = double.tryParse(v);
                setState(() => opt.price = (v.isEmpty || d == null) ? null : d);
              },
            ),
          ),
          GestureDetector(
            onTap: _groups[gi].options.length > 1
                ? () => setState(() => _groups[gi].options.removeAt(oi))
                : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Icon(
                Icons.remove_circle_outline,
                color: _groups[gi].options.length > 1
                    ? _red.withValues(alpha: 0.7)
                    : Colors.white12,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _toggleChip({
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? _red : _fieldBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? _red : _border),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            color: active ? Colors.white : Colors.black54,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _maxChip(_VariantGroup group) {
    return Container(
      decoration: BoxDecoration(
        color: _fieldBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () {
              if (group.maxSelect > 1) setState(() => group.maxSelect--);
            },
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Icon(Icons.remove, color: Colors.black45, size: 14),
            ),
          ),
          Text(
            'Máx ${group.maxSelect}',
            style: GoogleFonts.poppins(
              color: Colors.black54,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => group.maxSelect++),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Icon(Icons.add, color: Colors.black45, size: 14),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fullImageUrl = _serverImageUrl != null
        ? (_serverImageUrl!.startsWith('http')
              ? _serverImageUrl
              : '${ApiService.baseUrl}$_serverImageUrl')
        : null;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: _red),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.editMode ? 'Editar Producto' : 'Nuevo Producto',
          style: GoogleFonts.poppins(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _isUploading ? null : _save,
            child: Text(
              widget.editMode ? 'Actualizar' : 'Guardar',
              style: GoogleFonts.poppins(
                color: _red,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          physics: const BouncingScrollPhysics(),
          children: [
            // --- Imagen del Producto con Compresión ---
            GestureDetector(
              onTap: _isUploading ? null : _pickImage,
              child: Container(
                height: 180,
                decoration: BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: _serverImageUrl != null ? _red : _border,
                    width: 2,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Stack(
                    children: [
                      // Mostrar imagen seleccionada o del servidor
                      if (_localImagePath != null)
                        (kIsWeb
                            ? Image.network(
                                _localImagePath!,
                                width: double.infinity,
                                height: double.infinity,
                                fit: BoxFit.cover,
                              )
                            : Image.file(
                                File(_localImagePath!),
                                width: double.infinity,
                                height: double.infinity,
                                fit: BoxFit.cover,
                              ))
                      else if (fullImageUrl != null)
                        Image.network(
                          fullImageUrl,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              const Icon(Icons.broken_image),
                        )
                      else
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_a_photo_outlined,
                                color: _red.withValues(alpha: 0.5),
                                size: 40,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Añadir foto del plato',
                                style: GoogleFonts.poppins(
                                  color: Colors.black38,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                'Optimizado para carga rápida',
                                style: GoogleFonts.poppins(
                                  color: Colors.black26,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Overlay de carga
                      if (_isUploading)
                        Container(
                          color: Colors.black54,
                          child: const Center(
                            child: CircularProgressIndicator(color: _red),
                          ),
                        ),

                      // Indicador de "Cambiar"
                      if (_serverImageUrl != null && !_isUploading)
                        Positioned(
                          right: 12,
                          bottom: 12,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: _red,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.edit,
                              color: Colors.black87,
                              size: 16,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            _sectionTitle('INFORMACIÓN BÁSICA'),
            _inputField(
              ctrl: _nameCtrl,
              hint: 'Nombre del producto',
              icon: Icons.fastfood_outlined,
              validator: (v) => v!.isEmpty ? 'Requerido' : null,
            ),
            const SizedBox(height: 12),
            _inputField(
              ctrl: _descCtrl,
              hint: 'Descripción (ej: con papas y crema)',
              maxLines: 3,
              icon: Icons.notes_outlined,
            ),
            const SizedBox(height: 12),
            _inputField(
              ctrl: _priceCtrl,
              hint: 'Precio base (S/.)',
              icon: Icons.attach_money,
              type: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              validator: (v) => v!.isEmpty ? 'Requerido' : null,
            ),

            _sectionTitle('CATEGORÍA'),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: _fieldBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCategory,
                  isExpanded: true,
                  dropdownColor: _card,
                  borderRadius: BorderRadius.circular(14),
                  hint: Text(
                    'Seleccionar categoría',
                    style: GoogleFonts.poppins(
                      color: Colors.black26,
                      fontSize: 13,
                    ),
                  ),
                  items: widget.categories
                      .where((c) => c != 'Todos')
                      .map(
                        (c) => DropdownMenuItem(
                          value: c,
                          child: Text(
                            c,
                            style: GoogleFonts.poppins(
                              color: Colors.black87,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _selectedCategory = v),
                ),
              ),
            ),

            _sectionTitle('VARIABLES / EXTRAS'),
            if (_groups.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _border),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.add_box_outlined,
                      color: Colors.black26,
                      size: 32,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sin variables aún',
                      style: GoogleFonts.poppins(
                        color: Colors.black38,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              )
            else
              ...List.generate(_groups.length, _buildGroupCard),

            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _addGroup,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: _red, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const Icon(Icons.add_circle_outline, color: _red, size: 18),
              label: Text(
                'Agregar grupo de variables',
                style: GoogleFonts.poppins(
                  color: _red,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _isUploading ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _red,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 4,
                ),
                icon: const Icon(
                  Icons.check_circle_outline,
                  color: Colors.black87,
                  size: 22,
                ),
                label: Text(
                  widget.editMode ? 'Actualizar Producto' : 'Guardar Producto',
                  style: GoogleFonts.poppins(
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
