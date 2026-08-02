/// Mapa de palabras clave → emoji.
/// Para añadir una categoría, agrega una entrada aquí; no hay que tocar lógica.
const _categoryEmojiMap = <String, List<String>>{
  '🍔': ['comida', 'restaurante', 'tacos', 'pizza', 'burger', 'almuerzo', 'cena'],
  '🚗': ['transporte', 'gasolina', 'uber', 'taxi', 'bus', 'auto', 'coche'],
  '🛍️': ['ropa', 'zapatos', 'tenis', 'jeans', 'moda'],
  '🎮': ['juegos', 'steam', 'xbox', 'cine', 'pelicula', 'netflix'],
  '💊': ['salud', 'farmacia', 'doctor', 'hospital', 'medicina'],
  '🛒': ['super', 'despensa', 'mercado', 'oxxo', 'walmart', 'tienda'],
  '🏠': ['casa', 'renta', 'luz', 'agua', 'internet', 'gas', 'hogar'],
  '✈️': ['viaje', 'hotel', 'avion', 'vuelo', 'vacaciones'],
  '🎁': ['regalo', 'obsequio'],
  '📚': ['educacion', 'escuela', 'curso', 'libro', 'universidad'],
  '💪': ['gym', 'deporte', 'fit', 'ejercicio'],
  '💲': ['ingreso', 'sueldo', 'deposito', 'cobro', 'dinero', 'ventas', 'pago'],
};

const _defaultEmoji = '📦';

class CategoryUtils {
  /// Devuelve el emoji correspondiente a [category].
  /// Si no hay coincidencia, retorna [_defaultEmoji].
  static String getEmoji(String? category) {
    if (category == null || category.trim().isEmpty) return _defaultEmoji;
    final cat = category.toLowerCase().trim();

    for (final entry in _categoryEmojiMap.entries) {
      if (entry.value.any(cat.contains)) return entry.key;
    }

    return _defaultEmoji;
  }
}
