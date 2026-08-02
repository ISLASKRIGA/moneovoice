import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/di/dependency_injection.dart';
import '../../data/database/app_database.dart';
import '../lists/lists_provider.dart';

class TagEditorModal extends ConsumerStatefulWidget {
  const TagEditorModal({Key? key}) : super(key: key);

  @override
  ConsumerState<TagEditorModal> createState() => _TagEditorModalState();
}

class _TagEditorModalState extends ConsumerState<TagEditorModal> {
  @override
  Widget build(BuildContext context) {
    final activeList = ref.watch(activeListProvider);
    final transactionsStream = ref.watch(transactionRepositoryProvider).watchTransactionsByList(activeList?.id);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      snap: true,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              // Handle
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
                    Text('Editar etiquetas',
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: -0.5, color: textColor)),
                    Container(
                      decoration: BoxDecoration(color: isDark ? const Color(0xFF2C2C2E) : Colors.grey[100], shape: BoxShape.circle),
                      child: IconButton(
                        icon: Icon(Icons.close, size: 20, color: textColor),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ],
                ),
              ),

              // Subtitle
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 14, color: Colors.grey[400]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Las etiquetas se extraen de tus transacciones que terminan con #Tag.',
                        style: TextStyle(fontSize: 13, color: Colors.grey[400]),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // Tags List
              Expanded(
                child: StreamBuilder<List<Transaction>>(
                  stream: transactionsStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }

                    final transactions = snapshot.data ?? [];
                    final tagsCount = <String, int>{};

                    for (var t in transactions) {
                      final descParts = t.description.split(' ');
                      for (var word in descParts) {
                        if (word.startsWith('#') && word.length > 1) {
                          final tag = word.substring(1);
                          tagsCount[tag] = (tagsCount[tag] ?? 0) + 1;
                        }
                      }
                    }

                    if (tagsCount.isEmpty) {
                      return _buildEmptyHint(isDark);
                    }

                    final sortedTags = tagsCount.keys.toList()..sort();

                    return ListView.builder(
                      controller: scrollController,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      itemCount: sortedTags.length,
                      itemBuilder: (context, index) {
                        final tag = sortedTags[index];
                        final count = tagsCount[tag]!;
                        return _buildTagTile(tag, count, isDark, activeList?.id);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyHint(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.tag, size: 60, color: isDark ? Colors.grey[800] : Colors.grey[200]),
          const SizedBox(height: 16),
          Text(
            'No hay etiquetas en esta lista',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.grey[400]),
          ),
          const SizedBox(height: 8),
          Text(
            'Usa #nombre al final de tus transacciones',
            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildTagTile(String tag, int count, bool isDark, int? listId) {
    final textColor = isDark ? Colors.white : Colors.black87;
    final cardColor = isDark ? const Color(0xFF2C2C2E) : Colors.grey[50];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? const Color(0xFF3A3A3C) : Colors.grey.withOpacity(0.1)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), shape: BoxShape.circle),
          child: const Icon(Icons.tag, color: Colors.blue, size: 20),
        ),
        title: Text('#$tag', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
        subtitle: Text('$count ${count == 1 ? 'transacción' : 'transacciones'}', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              onPressed: () => _showRenameDialog(tag, listId),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
              onPressed: () => _confirmDelete(tag, listId),
            ),
          ],
        ),
      ),
    );
  }

  void _showRenameDialog(String oldTag, int? listId) {
    final ctrl = TextEditingController(text: oldTag);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Renombrar etiqueta'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            prefixText: '#',
            hintText: 'Nuevo nombre',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              final newTag = ctrl.text.trim().replaceAll('#', '');
              if (newTag.isNotEmpty && newTag != oldTag) {
                final count = await ref.read(transactionRepositoryProvider).updateTag(oldTag, newTag, listId);
                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Se actualizaron $count transacciones')));
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(String tag, int? listId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('¿Eliminar etiqueta?'),
        content: Text('La etiqueta #$tag se quitará de todas las transacciones de esta lista.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              final count = await ref.read(transactionRepositoryProvider).updateTag(tag, null, listId);
              if (mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Se quitó de $count transacciones')));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}
