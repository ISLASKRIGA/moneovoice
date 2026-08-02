import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dotted_border/dotted_border.dart';
import '../../core/di/dependency_injection.dart';
import '../../core/utils/category_utils.dart';
import 'category_provider.dart';

class CategoryEditorModal extends ConsumerStatefulWidget {
  const CategoryEditorModal({Key? key}) : super(key: key);

  @override
  _CategoryEditorModalState createState() => _CategoryEditorModalState();
}

class _CategoryEditorModalState extends ConsumerState<CategoryEditorModal> {
  final List<Color> _palette = [
    const Color(0xFFF8BBD0),
    const Color(0xFFFFCC80),
    const Color(0xFFDCEDC8),
    const Color(0xFFE8EAF6),
    const Color(0xFFB3E5FC),
    const Color(0xFFEFEBE9),
    const Color(0xFFCFD8DC),
    const Color(0xFFC5CAE9),
  ];

  // ── Bottom sheet de edición ──────────────────────────────
  void _showEditSheet(BuildContext context, CategoryItem cat, Color color) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CategoryEditSheet(
        category: cat,
        color: color,
        onSave: (newName, newEmoji) {
          ref.read(categoryProvider.notifier).updateCategory(cat.name, newName, newEmoji);
          Navigator.pop(ctx);
        },
        onDelete: () async {
          Navigator.pop(ctx); // cierra el sheet primero
          final repo = ref.read(transactionRepositoryProvider);
          final inUse = await repo.isCategoryInUse(cat.name);
          if (!context.mounted) return;

          if (inUse) {
            showDialog(
              context: context,
              builder: (dlgCtx) => AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                title: const Text('No se puede eliminar'),
                content: Text(
                  'La categoría "${cat.name}" tiene transacciones asociadas.\n\n'
                  'Recategoriza o elimina esas transacciones primero.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dlgCtx),
                    child: const Text('Entendido'),
                  ),
                ],
              ),
            );
            return;
          }

          showDialog(
            context: context,
            builder: (dlgCtx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Eliminar categoría'),
              content: Text('¿Eliminar "${cat.name}"?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dlgCtx),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    ref.read(categoryProvider.notifier).removeCategory(cat.name);
                    Navigator.pop(dlgCtx);
                  },
                  child: const Text('Eliminar'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Pantalla completa de añadir ──────────────────────────
  void _showAddCategoryDialog(BuildContext context) {
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: true,
        pageBuilder: (ctx, animation, _) => _AddCategoryFullPage(
          onAdd: (name, emoji) {
            ref.read(categoryProvider.notifier).addCategory(name, emoji);
            Navigator.pop(ctx);
          },
        ),
        transitionsBuilder: (ctx, animation, _, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.06),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 280),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoryProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFFFDFDFD),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Stack(
        children: [
          Column(
            children: [
              // Handle
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Editar categorías',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.black),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // Hint
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Icon(Icons.touch_app_outlined, size: 14, color: Colors.grey[400]),
                    const SizedBox(width: 6),
                    Text(
                      'Toca una categoría para editarla',
                      style: TextStyle(fontSize: 13, color: Colors.grey[400]),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Grid
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8)
                      .copyWith(bottom: 120),
                  physics: const BouncingScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 0.85,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 24,
                  ),
                  itemCount: categories.length + 1,
                  itemBuilder: (context, index) {
                    if (index == categories.length) {
                      // Botón Añadir
                      return GestureDetector(
                        onTap: () => _showAddCategoryDialog(context),
                        child: Column(
                          children: [
                            Expanded(
                              child: DottedBorder(
                                color: Colors.grey[300]!,
                                strokeWidth: 2,
                                dashPattern: const [8, 4],
                                borderType: BorderType.RRect,
                                radius: const Radius.circular(20),
                                child: Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: Colors.transparent,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Center(
                                    child: Icon(Icons.add, size: 32, color: Colors.grey),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Añadir',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      );
                    }

                    final cat = categories[index];
                    final color = _palette[index % _palette.length];

                    return GestureDetector(
                      // ── TAP → abrir sheet de edición ──
                      onTap: () => _showEditSheet(context, cat, color),
                      child: Column(
                        children: [
                          Expanded(
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                // Tarjeta
                                Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: color,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Center(
                                    child: Text(
                                      cat.emoji,
                                      style: const TextStyle(fontSize: 32),
                                    ),
                                  ),
                                ),
                                // Lápiz pequeño en la esquina
                                Positioned(
                                  top: -6,
                                  right: -6,
                                  child: Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.12),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.edit,
                                      size: 12,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            cat.name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),

          // Botón Terminar
          Positioned(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E1E1E),
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    elevation: 10,
                    shadowColor: Colors.black26,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.check, size: 18),
                      SizedBox(width: 8),
                      Text('Terminar',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Sheet de EDICIÓN — sube desde abajo ultra-smooth
// ─────────────────────────────────────────────────────────────
class _CategoryEditSheet extends StatefulWidget {
  final CategoryItem category;
  final Color color;
  final void Function(String name, String emoji) onSave;
  final VoidCallback onDelete;

  const _CategoryEditSheet({
    required this.category,
    required this.color,
    required this.onSave,
    required this.onDelete,
  });

  @override
  State<_CategoryEditSheet> createState() => _CategoryEditSheetState();
}

class _CategoryEditSheetState extends State<_CategoryEditSheet> {
  late final TextEditingController _nameCtrl;
  late String _emoji;

  // Emojis rápidos para elegir
  final List<String> _quickEmojis = [
    '🍔', '🚗', '🛍️', '🎮', '💊', '🥬', '✈️', '🏠',
    '📱', '💡', '🎵', '🐾', '🎓', '💼', '🏋️', '☕',
    '🍕', '🎉', '💰', '🔑', '🛒', '📚', '🌿', '✨',
  ];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.category.name);
    _emoji = widget.category.emoji;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Emoji grande + botón cambiar
                Center(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Fondo color de la categoría
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: widget.color,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Center(
                          child: Text(_emoji, style: const TextStyle(fontSize: 44)),
                        ),
                      ),
                      // Botón lápiz para desplegar picker
                      Positioned(
                        bottom: -6,
                        right: -6,
                        child: GestureDetector(
                          onTap: _showEmojiPicker,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.black,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(Icons.edit, size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // Campo de nombre
                TextField(
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Nombre',
                    hintStyle: TextStyle(color: Colors.grey[300], fontSize: 28),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  autofocus: false,
                ),

                const SizedBox(height: 28),

                // Botones: Eliminar | Guardar
                Row(
                  children: [
                    // Eliminar
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: widget.onDelete,
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text(
                          'Eliminar',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF3B30),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20)),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Guardar
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final name = _nameCtrl.text.trim();
                          if (name.isEmpty) return;
                          widget.onSave(name, _emoji);
                        },
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text(
                          'Guardar',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Emoji picker rápido ────────────────────────────────
  void _showEmojiPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300], borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Elige un emoji',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              // También campo manual
              TextField(
                maxLength: 2,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 32),
                decoration: InputDecoration(
                  hintText: '✏️',
                  hintStyle: TextStyle(color: Colors.grey[300], fontSize: 32),
                  counterText: '',
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onChanged: (v) {
                  if (v.isNotEmpty) {
                    setState(() => _emoji = v);
                    Navigator.pop(ctx);
                  }
                },
              ),
              const SizedBox(height: 16),
              // Grid de emojis rápidos
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 6,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1,
                ),
                itemCount: _quickEmojis.length,
                itemBuilder: (_, i) {
                  final e = _quickEmojis[i];
                  final selected = e == _emoji;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _emoji = e);
                      Navigator.pop(ctx);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      decoration: BoxDecoration(
                        color: selected ? Colors.black : Colors.grey[100],
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Text(e, style: const TextStyle(fontSize: 26)),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Pantalla completa de AÑADIR nueva categoría
// ─────────────────────────────────────────────────────────────
class _AddCategoryFullPage extends StatefulWidget {
  final void Function(String name, String emoji) onAdd;
  const _AddCategoryFullPage({required this.onAdd});

  @override
  State<_AddCategoryFullPage> createState() => _AddCategoryFullPageState();
}

class _AddCategoryFullPageState extends State<_AddCategoryFullPage> {
  final _nameCtrl        = TextEditingController();
  final _emojiSearchCtrl = TextEditingController();
  bool   _hasText   = false;
  bool   _confirmed = false;
  bool   _loading   = false;
  String _emoji     = '📦';
  String _emojiSearch = '';

  // Emoji con palabras clave en español para el buscador
  static const Map<String, String> _emojiData = {
    '🍔': 'comida hamburguesa restaurante almuerzo cena burger',
    '🍕': 'pizza comida restaurante',
    '🍣': 'sushi comida japonesa',
    '🥗': 'ensalada comida saludable verduras',
    '🍺': 'cerveza bebida alcohol bar cantina',
    '☕': 'cafe desayuno bebida cafeteria',
    '🥤': 'bebida refresco soda jugo',
    '🍰': 'postre dulce pastel torta',
    '🍳': 'cocinar comida casa cocina',
    '🍷': 'vino bebida cena restaurante',
    '🚗': 'transporte coche auto gasolina uber taxi',
    '🚌': 'bus transporte publico',
    '🚇': 'metro tren transporte',
    '🚲': 'bicicleta transporte deporte',
    '✈️': 'viaje avion vuelo turismo vacaciones',
    '🏖️': 'playa vacaciones viaje turismo',
    '🏠': 'casa hogar renta alquiler',
    '🏡': 'casa hogar jardin residencia',
    '💡': 'electricidad luz servicio energia',
    '🚿': 'agua servicio bano plomeria',
    '📱': 'tecnologia celular movil telefono smartphone',
    '💻': 'computadora laptop tecnologia trabajo oficina',
    '📺': 'television entretenimiento cable',
    '🎮': 'videojuegos juegos entretenimiento consola',
    '🎬': 'cine pelicula streaming netflix',
    '🎵': 'musica entretenimiento spotify concierto',
    '📚': 'libros educacion lectura',
    '🎓': 'educacion escuela universidad curso clases',
    '💊': 'salud farmacia medicina doctor hospital',
    '🏥': 'hospital clinica salud medico',
    '🌡️': 'salud temperatura fiebre enfermedad',
    '🛒': 'supermercado compras mercado walmart tienda abarrotes',
    '👕': 'ropa moda vestimenta camisa',
    '👟': 'zapatos tenis ropa calzado',
    '💄': 'belleza cosmeticos maquillaje estetica',
    '💪': 'gym deporte ejercicio fitness pesas crossfit',
    '🏋️': 'gym pesas deporte musculacion',
    '⚽': 'futbol deporte pelota',
    '🏊': 'natacion deporte piscina',
    '🧘': 'meditacion yoga relajacion bienestar',
    '🐾': 'mascotas animales perro gato veterinario',
    '💰': 'dinero ahorro ingresos sueldo salario',
    '💳': 'banco tarjeta credito debito pago',
    '🏦': 'banco finanzas credito prestamo',
    '📊': 'finanzas inversion bolsa acciones',
    '🎁': 'regalo presente obsequio',
    '🎉': 'fiesta celebracion cumpleanos',
    '🌿': 'naturaleza plantas jardin',
    '✨': 'otros general miscelaneo',
    '🛍️': 'compras tienda shopping bolsas',
    '🔑': 'llaves casa departamento cerraduras',
    '⛽': 'gasolina combustible auto bencina',
    '🌐': 'internet servicio wifi red',
    '🧴': 'higiene cuidado personal aseo',
    '🧹': 'limpieza hogar aseo',
    '📦': 'paquete envio entrega delivery',
    '🅿️': 'estacionamiento parqueo parqueadero',
    '💈': 'barberia peluqueria corte',
    '💼': 'trabajo oficina negocios empresa',
    '📸': 'fotografia camara recuerdos',
    '🎨': 'arte manualidades pintura creatividad',
    '🔧': 'herramientas reparacion mantenimiento',
    '🌍': 'viajes exterior internacional',
    '🎭': 'teatro cultura entretenimiento obra',
    '🎪': 'entretenimiento parque diversiones feria',
  };

  @override
  void initState() {
    super.initState();
    _nameCtrl.addListener(() {
      final has = _nameCtrl.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
    _emojiSearchCtrl.addListener(() {
      setState(() => _emojiSearch = _emojiSearchCtrl.text.toLowerCase().trim());
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emojiSearchCtrl.dispose();
    super.dispose();
  }

  List<String> get _filteredEmojis {
    final keys = _emojiData.keys.toSet().toList(); // deduplicate
    if (_emojiSearch.isEmpty) return keys;
    return _emojiData.entries
        .where((e) => e.value.contains(_emojiSearch))
        .map((e) => e.key)
        .toList();
  }

  Future<void> _confirm() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _loading = true);
    FocusScope.of(context).unfocus();
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() {
      _emoji     = CategoryUtils.getEmoji(name);
      _loading   = false;
      _confirmed = true;
    });
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    widget.onAdd(name, _emoji);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: _confirmed ? _buildEmojiPhase() : _buildTypingPhase(),
      ),
    );
  }

  // ── FASE 0: escribir nombre ────────────────────────────────
  Widget _buildTypingPhase() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // X cerrar
        Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: const EdgeInsets.only(top: 8, right: 8),
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.black, size: 26),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),

        // Campo de texto
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 30, 28, 0),
          child: TextField(
            controller: _nameCtrl,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
            decoration: InputDecoration(
              hintText: 'Categoría',
              hintStyle: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.grey[300],
              ),
              border: InputBorder.none,
            ),
          ),
        ),

        const Spacer(),

        // Confirmar / cargando — siempre visible al fondo
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: _loading
              ? Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 22, height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5,
                      ),
                    ),
                  ),
                )
              : ElevatedButton.icon(
                  onPressed: _hasText ? _confirm : null,
                  icon: Icon(Icons.check, size: 18, color: _hasText ? Colors.white : Colors.grey[500]),
                  label: Text(
                    'Confirmar',
                    style: TextStyle(
                      fontSize: 16, 
                      fontWeight: FontWeight.bold,
                      color: _hasText ? Colors.white : Colors.grey[500],
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _hasText ? Colors.black : Colors.grey[200],
                    disabledBackgroundColor: Colors.grey[200],
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 0,
                  ),
                ),
        ),
      ],
    );
  }

  // ── FASE 1: emoji seleccionado + picker ────────────────────
  Widget _buildEmojiPhase() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // X cerrar
        Align(
          alignment: Alignment.centerRight,
          child: IconButton(
            icon: const Icon(Icons.close, color: Colors.black, size: 26),
            onPressed: () => Navigator.pop(context),
          ),
        ),

        // Emoji seleccionado + nombre
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
          child: Row(
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.4, end: 1.0),
                duration: const Duration(milliseconds: 500),
                curve: Curves.elasticOut,
                builder: (_, scale, child) =>
                    Transform.scale(scale: scale, child: child),
                child: Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Center(
                    child: Text(_emoji,
                        style: const TextStyle(fontSize: 32)),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  _nameCtrl.text.trim(),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // Botón Guardar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ElevatedButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check, size: 18),
            label: const Text(
              'Guardar',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 0,
            ),
          ),
        ),

        const SizedBox(height: 14),

        // Buscador de emojis
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: TextField(
            controller: _emojiSearchCtrl,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Describe un emoji',
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
              prefixIcon:
                  Icon(Icons.search, color: Colors.grey[400], size: 20),
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              isDense: true,
            ),
          ),
        ),

        const SizedBox(height: 10),

        // Grid de emojis
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            physics: const BouncingScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1,
            ),
            itemCount: _filteredEmojis.length,
            itemBuilder: (_, i) {
              final e = _filteredEmojis[i];
              final selected = e == _emoji;
              return GestureDetector(
                onTap: () => setState(() => _emoji = e),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    color: selected ? Colors.black : Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(e,
                        style: const TextStyle(fontSize: 22)),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
