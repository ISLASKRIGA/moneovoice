import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database/app_database.dart';
import '../../core/di/dependency_injection.dart';
import '../premium/premium_paywall.dart';
import 'lists_provider.dart';

class UserListsModal extends ConsumerStatefulWidget {
  const UserListsModal({Key? key}) : super(key: key);

  @override
  ConsumerState<UserListsModal> createState() => _UserListsModalState();
}

class _UserListsModalState extends ConsumerState<UserListsModal> {
  bool _showForm = false;
  UserList? _editingList;
  bool _isEditingDefault = false;
  final _nameCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _focusNode = FocusNode();
  String _selectedEmoji = '⭐';
  late final ScrollController _scrollController;
  final DraggableScrollableController _sheetController = DraggableScrollableController();

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(() {
      // Si estamos en el formulario y el usuario hace scroll hacia abajo (drag beyond top)
      if (_showForm && _scrollController.offset < -50) {
        _closeForm();
      }
    });
  }

  final List<String> _emojiOptions = [
    '⭐', '💰', '🏠', '✈️', '🎉', '🍕', '💼', '🎓',
    '🏋️', '🛒', '🛍️', '🎮', '🚗', '📱', '🐾', '🌿',
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    _sheetController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe un nombre para la lista')),
      );
      return;
    }

    if (_isEditingDefault) {
      await ref.read(defaultListProvider.notifier).update(name, _selectedEmoji);
    } else if (_editingList != null) {
      // Usando add para disparar recarga (el notifier tiene rename)
      await ref.read(listsNotifierProvider.notifier).rename(
        _editingList!,
        name,
        emoji: _selectedEmoji,
      );
    } else {
      await ref.read(listsNotifierProvider.notifier).add(
        name: name,
        emoji: _selectedEmoji,
      );
    }

    _nameCtrl.clear();
    setState(() {
      _showForm = false;
      _editingList = null;
      _isEditingDefault = false;
      _selectedEmoji = '⭐';
    });

    // Bajar pestaña
    if (_sheetController.isAttached) {
      _sheetController.animateTo(
        0.7,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    }

    // Scroll al principio para mostrar la nueva lista/actualización
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
    );
  }

  void _openForm({UserList? list, bool isDefault = false}) async {
    // 1. Primero subimos la pestaña
    if (_sheetController.isAttached) {
      await _sheetController.animateTo(
        0.95,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    }

    // 2. Después mostramos el form
    if (!mounted) return;
    setState(() {
      _showForm = true;
      _editingList = list;
      _isEditingDefault = isDefault;
      if (isDefault) {
        final def = ref.read(defaultListProvider);
        _nameCtrl.text = def.name;
        _selectedEmoji = def.emoji;
      } else if (list != null) {
        _nameCtrl.text = list.name;
        _selectedEmoji = list.emoji;
      } else {
        _nameCtrl.clear();
        _selectedEmoji = '⭐';
      }
    });

    // 3. Finalmente enfocamos
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
      _focusNode.requestFocus();
    });
  }

  void _closeForm() {
    _focusNode.unfocus();
    setState(() {
      _showForm = false;
      _editingList = null;
      _isEditingDefault = false;
      _nameCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final listsState = ref.watch(listsNotifierProvider);
    final activeList = ref.watch(activeListProvider);
    final topPad = MediaQuery.of(context).padding.top;

    return DraggableScrollableSheet(
      controller: _sheetController,
      initialChildSize: _showForm ? 0.95 : 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      snap: true,
      snapSizes: const [0.7, 0.95],
      builder: (context, scrollController) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final bgColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;
        final textColor = isDark ? Colors.white : Colors.black87;

        return Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              // Drag handle
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: isDark ? const Color(0xFF3A3A3C) : Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 4, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Tus listas',
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: -0.5, color: textColor)),
                    Row(children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: _showForm
                            ? const SizedBox.shrink()
                            : Container(
                                key: const ValueKey('add_list_btn'),
                                decoration: BoxDecoration(color: textColor, borderRadius: BorderRadius.circular(20)),
                                child: TextButton.icon(
                                  onPressed: () async {
                                    final isPremium = ref.read(premiumProvider);
                                    if (!isPremium) {
                                      final lists = ref.read(listsNotifierProvider).valueOrNull ?? [];
                                      // +1 por la lista privada por defecto
                                      if (lists.length >= kFreeListLimit) {
                                        await showPremiumPaywall(context);
                                        return;
                                      }
                                    }
                                    _openForm();
                                  },
                                  icon: Icon(Icons.add, color: bgColor, size: 18),
                                  label: Text('Nueva', style: TextStyle(color: bgColor, fontWeight: FontWeight.bold)),
                                ),
                              ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(color: isDark ? const Color(0xFF2C2C2E) : Colors.grey[100], shape: BoxShape.circle),
                        child: IconButton(
                          icon: Icon(Icons.close, size: 20, color: textColor),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                    ]),
                  ],
                ),
              ),

              // Body
              Expanded(
                child: ListView(
                  controller: scrollController,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  children: [
                    // ── Formulario ───────────────────────
                    AnimatedSize(
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeInOutCubic,
                      child: _showForm ? _buildForm() : const SizedBox.shrink(),
                    ),

                    // ── Lista 1 ───────────
                    Consumer(builder: (context, ref, child) {
                      final defaultList = ref.watch(defaultListProvider);
                      final listsData = ref.watch(listsNotifierProvider).asData?.value ?? [];

                      // Si está "borrada" y HAY otras listas, no la mostramos
                      if (defaultList.isDeleted && listsData.isNotEmpty) {
                        return const SizedBox.shrink();
                      }

                      return _buildListTile(
                        name: defaultList.name,
                        emoji: defaultList.emoji,
                        isDefault: true,
                        isActive: activeList == null,
                        onTap: () {
                          ref.read(activeListProvider.notifier).select(null);
                          Navigator.pop(context);
                        },
                        onEdit: () => _openForm(isDefault: true),
                        // Solo permitimos borrar si hay otras listas
                        onDelete: listsData.isNotEmpty ? () => _confirmDeleteDefault() : null,
                      );
                    }),

                    const Divider(height: 20),

                    // ── Listas del usuario ────────────────
                    listsState.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (e, _) => Text('Error: $e'),
                      data: (lists) {
                        if (lists.isEmpty && !_showForm) {
                          return _buildEmptyHint();
                        }
                        return Column(
                          children: lists
                              .map((l) => _buildListTile(
                                    name: l.name,
                                    emoji: l.emoji,
                                    isActive: activeList?.id == l.id,
                                    onTap: () {
                                      ref.read(activeListProvider.notifier).select(l);
                                      Navigator.pop(context);
                                    },
                                    onEdit: () => _openForm(list: l),
                                    onDelete: () => _confirmDelete(l),
                                  ))
                              .toList(),
                        );
                      },
                    ),
                    SizedBox(height: topPad + 32),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyHint() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Text('⭐', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 10),
          Text(
            'Crea tu primera lista personalizada',
            style: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  // ── Tile de lista ────────────────────────────────────────
  Widget _buildListTile({
    required String name,
    required String emoji,
    bool isDefault = false,
    required bool isActive,
    required VoidCallback onTap,
    VoidCallback? onEdit,
    VoidCallback? onDelete,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = isDark ? Colors.white : Colors.black;
    final activeTextColor = isDark ? Colors.black : Colors.white;
    final inactiveColor = isDark ? const Color(0xFF2C2C2E) : Colors.white;
    final inactiveBorder = isDark ? const Color(0xFF3A3A3C) : Colors.grey.withOpacity(0.15);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: isActive ? activeColor : inactiveColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? activeColor : inactiveBorder,
            width: isActive ? 0 : 1,
          ),
          boxShadow: isActive
              ? [BoxShadow(color: activeColor.withOpacity(0.18), blurRadius: 12, offset: const Offset(0, 4))]
              : (isDark ? [] : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))]),
        ),
        child: Row(children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isActive ? activeTextColor : (isDark ? Colors.white : Colors.black87),
                  ),
                ),
              ],
            ),
          ),
          if (isActive)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Icon(Icons.check_circle_rounded, color: activeTextColor, size: 20),
            ),
          if (onEdit != null)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              color: isActive ? activeTextColor : (isDark ? Colors.white70 : Colors.black54),
              iconSize: 20,
              onPressed: onEdit,
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(),
            ),
          if (onDelete != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              color: isActive ? activeTextColor : Colors.red[400],
              iconSize: 20,
              onPressed: onDelete,
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(),
            ),
        ]),
      ),
    );
  }

  // ── Formulario nueva/editar lista ───────────────────────────────
  Widget _buildForm() {
    final isEditing = _editingList != null || _isEditingDefault;
    final title = _isEditingDefault ? 'Editar Lista Predeterminada' : (isEditing ? 'Editar lista' : 'Nueva lista');
    return Listener(
      onPointerMove: (event) {
        // Si el usuario desliza hacia abajo significativamente en el area del form
        if (event.delta.dy > 15) {
          _closeForm();
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F8FB),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey.withOpacity(0.12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 14),

            // Emoji picker
            const Text('Elige un emoji', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: _emojiOptions.map((e) {
                final selected = e == _selectedEmoji;
                return GestureDetector(
                  onTap: () => setState(() => _selectedEmoji = e),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: selected ? Colors.black : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: selected ? Colors.black : Colors.grey.withOpacity(0.2)),
                    ),
                    child: Center(child: Text(e, style: const TextStyle(fontSize: 22))),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),

            // Nombre
            TextFormField(
              controller: _nameCtrl,
              focusNode: _focusNode,
              decoration: InputDecoration(
                labelText: 'Nombre de la lista',
                filled: true,
                fillColor: Colors.white,
                prefixText: '$_selectedEmoji  ',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey.withOpacity(0.2)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey.withOpacity(0.2)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Colors.black, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),

            // Botones
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _closeForm,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(isEditing ? 'Guardar' : 'Crear lista', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteDefault() {
    final def = ref.read(defaultListProvider);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('¿Eliminar lista predeterminada?'),
        content: Text('Se ocultará "${def.emoji} ${def.name}".'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteDefault();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  void _deleteDefault() async {
    final listsData = ref.read(listsNotifierProvider).asData?.value ?? [];
    if (listsData.isNotEmpty) {
      // Si la lista activa era la default, cambiamos a la primera disponible
      if (ref.read(activeListProvider) == null) {
        ref.read(activeListProvider.notifier).select(listsData.first);
      }
      await ref.read(defaultListProvider.notifier).delete();
    }
  }

  void _confirmDelete(UserList list) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('¿Eliminar lista?'),
        content: Text('Se eliminará "${list.emoji} ${list.name}" permanentemente.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(listsNotifierProvider.notifier).delete(list.id);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}
