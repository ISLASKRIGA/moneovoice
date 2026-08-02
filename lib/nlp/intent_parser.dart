// Motor NLP v3 — Intelligent Financial Intent Parser (Spanish)
//
// Pipeline de procesamiento:
//  1. Normalizar texto (tildes, mayúsculas)
//  2. Extraer Y BORRAR expresiones temporales → fecha
//  3. Detectar acción (gasto / ingreso / consulta)
//  4. Extraer montos del texto YA LIMPIO (sin fechas)
//  5. Detectar ítems múltiples o ítem único
//  6. Construir descripción limpia
//
// CRÍTICO: las fechas se eliminan ANTES de buscar montos.
// Esto evita que "hace 2 días" → $2.

enum IntentAction { create_expense, create_income, query_balance, query_summary, unknown }

// ───────────────────────────────────────────────────────────────
// Modelo de un ítem individual
// ───────────────────────────────────────────────────────────────
class LineItem {
  final String description;
  final double amount;
  final String category;
  const LineItem({required this.description, required this.amount, required this.category});
}

// ───────────────────────────────────────────────────────────────
// Resultado del parseo
// ───────────────────────────────────────────────────────────────
class FinanceIntent {
  final IntentAction action;
  final double? amount;
  final String? category;
  final String? description;
  final DateTime? date;
  final double confidence;
  final List<LineItem> lineItems;

  const FinanceIntent({
    required this.action,
    this.amount,
    this.category,
    this.description,
    this.date,
    this.confidence = 0.0,
    this.lineItems = const [],
  });

  bool get isMultiItem => lineItems.length > 1;

  @override
  String toString() =>
      'Intent: $action | Monto: $amount | Cat: $category | Desc: $description | Items: ${lineItems.length} | Conf: ${confidence.toStringAsFixed(2)}';
}

// ───────────────────────────────────────────────────────────────
// Expresiones temporales — patrones ORDENADOS de más específico
// a más general. Cada entrada: {regex, offsetDays | fn}
// ───────────────────────────────────────────────────────────────
// Devuelve (DateTime, textoCleaned) al hacer strip de fecha.
class _DateResult {
  final DateTime date;
  final String cleanText;
  const _DateResult(this.date, this.cleanText);
}

// ───────────────────────────────────────────────────────────────
// Keywords de categorías
// ───────────────────────────────────────────────────────────────
const Map<String, List<String>> _categoryKeywords = {
  'Comida': [
    'comida', 'comer', 'almuerzo', 'desayuno', 'cena', 'restaurante',
    'taqueria', 'tacos', 'pizza', 'burger', 'hamburgesa', 'sushi', 'torta',
    'lonche', 'lunch', 'cafe', 'coffee', 'starbucks', 'dominos', 'mcdonalds',
    'kfc', 'subway', 'snack', 'merienda', 'antojitos', 'gorditas', 'quesadillas',
    'wings', 'pollo', 'sopa', 'caldo', 'elotes', 'tamales', 'enchiladas',
    'frijoles', 'jitomate', 'tomate', 'cebolla', 'chile', 'aguacate', 'naranja',
    'manzana', 'platano', 'limon', 'zanahoria', 'papa', 'papas', 'arroz',
    'atun', 'sardinas', 'huevo', 'huevos', 'aceite', 'sal', 'azucar',
    'harina', 'fideo', 'pasta', 'refresco', 'pozole', 'carnitas', 'barbacoa',
    'milanesa', 'chilaquiles', 'huaraches', 'burrito', 'tamal',
  ],
  'Super': [
    'super', 'supermercado', 'mercado', 'despensa', 'walmart', 'soriana',
    'chedraui', 'costco', 'oxxo', 'seven eleven', 'tienda', 'abarrotes',
    'verduras', 'frutas', 'leche', 'pan', 'tortillas', 'mandado',
    'champinon', 'brocoli', 'espinaca', 'pepino', 'lechuga', 'pimienta',
    'detergente', 'jabon', 'shampoo', 'crema', 'yogurt', 'queso',
    'jamon', 'mantequilla', 'cereal', 'galletas', 'jugo',
  ],
  'Transporte': [
    'uber', 'didi', 'taxi', 'cabify', 'bus', 'camion', 'metro', 'metrobus',
    'gasolina', 'combustible', 'pemex', 'caseta', 'autopista', 'peaje',
    'estacionamiento', 'parking', 'tenencia', 'verificacion', 'afinacion',
    'llanta', 'transporte', 'pasaje', 'boleto', 'pesero', 'colectivo',
    'autobus', 'trolebus', 'moto', 'bicicleta', 'patinete',
  ],
  'Ropa': [
    'ropa', 'zapatos', 'tenis', 'zapatillas', 'camisa', 'pantalon', 'jeans',
    'vestido', 'falda', 'blusa', 'playera', 'sudadera', 'chamarra', 'jacket',
    'nike', 'adidas', 'zara', 'shein', 'liverpool', 'moda', 'outfit',
    'calcetines', 'gorra', 'sombrero', 'bolsa', 'cartera', 'cinturon',
    'abrigo', 'traje', 'corbata', 'aretes', 'collar', 'pulsera', 'anillo',
  ],
  'Salud': [
    'farmacia', 'medicina', 'medicamento', 'pastillas', 'vitaminas', 'doctor',
    'medico', 'hospital', 'clinica', 'consulta', 'dentista', 'oculista',
    'psicologo', 'terapia', 'analisis', 'laboratorio', 'seguro medico',
    'similares', 'benavides', 'inyeccion', 'vacuna', 'salud',
    'radiografia', 'ultrasonido', 'antibiotico',
  ],
  'Entretenimiento': [
    'cine', 'pelicula', 'teatro', 'concierto', 'show', 'evento', 'netflix',
    'spotify', 'amazon', 'disney', 'hbo', 'suscripcion', 'antro', 'bar',
    'discoteca', 'karaoke', 'bowling', 'parque', 'zoo', 'museo', 'diversion',
    'fiesta', 'bailar', 'club',
  ],
  'Juegos': [
    'juego', 'videojuego', 'steam', 'playstation', 'xbox', 'nintendo',
  ],
  'Casa': [
    'renta', 'alquiler', 'hipoteca', 'predial', 'luz', 'electricidad', 'cfe',
    'internet', 'telmex', 'izzi', 'totalplay', 'megacable', 'telefono', 'celular',
    'telcel', 'movistar', 'muebles', 'silla', 'mesa', 'cama', 'sofa',
    'refrigerador', 'lavadora', 'estufa', 'limpieza', 'plomero', 'mantenimiento',
    'hogar', 'casa', 'departamento', 'gas', 'tinaco', 'pintura',
  ],
  'Educacion': [
    'escuela', 'colegio', 'universidad', 'colegiatura', 'matricula',
    'inscripcion', 'curso', 'taller', 'diplomado', 'maestria', 'doctorado',
    'libros', 'utiles', 'papeleria', 'cuadernos', 'plumas', 'mochila',
    'udemy', 'coursera', 'platzi', 'tutorias', 'clases', 'libro', 'educacion',
  ],
  'Gym': [
    'gym', 'gimnasio', 'crossfit', 'yoga', 'pilates', 'spinning', 'membresia',
    'smart fit', 'sport city', 'pesas', 'proteina', 'suplementos', 'deporte',
    'ejercicio', 'correr', 'nadar', 'natacion', 'futbol', 'basquet',
  ],
  'Viajes': [
    'viaje', 'hotel', 'hostal', 'airbnb', 'booking', 'avion', 'aeropuerto',
    'vuelo', 'maleta', 'vacaciones', 'tour', 'excursion', 'crucero', 'resort',
  ],
  'Regalo': [
    'regalo', 'obsequio', 'cumpleanos', 'navidad', 'san valentin',
    'flores', 'chocolates', 'pastel',
  ],
  'Mascotas': [
    'mascota', 'perro', 'gato', 'veterinario', 'croquetas',
  ],
};

// ───────────────────────────────────────────────────────────────
// Verbos de gasto e ingreso con peso de confianza
// ───────────────────────────────────────────────────────────────
const Map<String, double> _expenseVerbs = {
  'gaste': 0.95, 'pague': 0.95, 'compre': 0.95, 'gastaste': 0.90,
  'consumi': 0.90, 'gasto': 0.80, 'pago': 0.75, 'compra': 0.75,
  'salida': 0.70, 'erogué': 0.80, 'salio': 0.70, 'fui a': 0.60,
  'fui al': 0.60, 'fui por': 0.60, 'compré': 0.95, 'pagué': 0.95,
  'desembolsé': 0.90, 'pagamos': 0.85, 'compramos': 0.85,
  'invierto': 0.75, 'abono': 0.75,
};

const Map<String, double> _incomeVerbs = {
  'ingrese': 0.95, 'gane': 0.95, 'recibi': 0.92, 'cobre': 0.90,
  'facture': 0.90, 'vendi': 0.88, 'ingreso': 0.80, 'deposito': 0.85,
  'depositaron': 0.88, 'ganancia': 0.82, 'sueldo': 0.88, 'salario': 0.88,
  'bono': 0.78, 'transferencia': 0.70, 'devolucion': 0.72, 'reembolso': 0.75,
  'me pagaron': 0.90, 'me depositaron': 0.90, 'recibi pago': 0.92,
  'vendi algo': 0.88, 'cobré': 0.90, 'gané': 0.95, 'recibí': 0.92,
};

// ───────────────────────────────────────────────────────────────
// Números en palabras (ordenados de MAYOR a MENOR para greedy match)
// ───────────────────────────────────────────────────────────────
const List<MapEntry<String, double>> _wordNumbers = [
  MapEntry('cien mil', 100000),
  MapEntry('cincuenta mil', 50000),
  MapEntry('cuarenta mil', 40000),
  MapEntry('treinta mil', 30000),
  MapEntry('veinte mil', 20000),
  MapEntry('quince mil', 15000),
  MapEntry('doce mil', 12000),
  MapEntry('diez mil', 10000),
  MapEntry('nueve mil', 9000),
  MapEntry('ocho mil', 8000),
  MapEntry('siete mil', 7000),
  MapEntry('seis mil', 6000),
  MapEntry('cinco mil', 5000),
  MapEntry('cuatro mil', 4000),
  MapEntry('tres mil', 3000),
  MapEntry('dos mil quinientos', 2500),
  MapEntry('dos mil', 2000),
  MapEntry('mil ochocientos', 1800),
  MapEntry('mil quinientos', 1500),
  MapEntry('mil doscientos', 1200),
  MapEntry('un mil', 1000),
  MapEntry('novecientos', 900),
  MapEntry('ochocientos', 800),
  MapEntry('setecientos', 700),
  MapEntry('seiscientos', 600),
  MapEntry('quinientos', 500),
  MapEntry('cuatrocientos', 400),
  MapEntry('trescientos', 300),
  MapEntry('doscientos', 200),
  MapEntry('ciento cincuenta', 150),
  MapEntry('ciento veinte', 120),
  MapEntry('cien', 100),
  MapEntry('ciento', 100),
  MapEntry('noventa', 90),
  MapEntry('ochenta', 80),
  MapEntry('setenta', 70),
  MapEntry('sesenta', 60),
  MapEntry('cincuenta', 50),
  MapEntry('cuarenta', 40),
  MapEntry('treinta', 30),
  MapEntry('veinticinco', 25),
  MapEntry('veinte', 20),
  MapEntry('quince', 15),
  MapEntry('doce', 12),
  MapEntry('once', 11),
  MapEntry('diez', 10),
  MapEntry('nueve', 9),
  MapEntry('ocho', 8),
  MapEntry('siete', 7),
  MapEntry('seis', 6),
  MapEntry('cinco', 5),
  MapEntry('cuatro', 4),
  MapEntry('tres', 3),
  MapEntry('dos', 2),
  MapEntry('uno', 1),
  MapEntry('un ', 1),
  MapEntry('mil', 1000),
];

// ───────────────────────────────────────────────────────────────
// Parser principal
// ───────────────────────────────────────────────────────────────
class IntentParser {
  FinanceIntent parse(String input) {
    if (input.trim().isEmpty) {
      return const FinanceIntent(action: IntentAction.unknown);
    }

    // ── PASO 1: Normalizar ─────────────────────────────────
    final rawNorm = _normalize(input);

    // ── PASO 2: Consultas de balance/resumen ───────────────
    if (_containsAny(rawNorm, ['cuanto tengo', 'saldo', 'balance disponible', 'dinero disponible'])) {
      return const FinanceIntent(action: IntentAction.query_balance, confidence: 0.9);
    }
    if (_containsAny(rawNorm, ['resumen', 'historial', 'movimientos', 'que gaste', 'gastos del mes'])) {
      return const FinanceIntent(action: IntentAction.query_summary, confidence: 0.9);
    }

    // ── PASO 3: Extraer fecha Y limpiar el texto ───────────
    // CRÍTICO: la fecha se elimina ANTES de buscar montos.
    final dateResult = _extractDateAndClean(rawNorm);
    String cleanText = dateResult.cleanText; // texto sin expresiones temporales
    final date       = dateResult.date;

    // ── PASO 3b: Detectar y extraer categoría explícita ────
    String? explicitCategoryHint;
    final catHintMatch = RegExp(
      r'\bcategor[ií]a\s+(\w+)',
      caseSensitive: false,
    ).firstMatch(cleanText);
    if (catHintMatch != null) {
      explicitCategoryHint = catHintMatch.group(1);
      cleanText = cleanText.replaceAll(catHintMatch.group(0)!, '').trim();
      cleanText = cleanText.replaceAll(RegExp(r'\s+'), ' ').trim();
    }

    // ── PASO 3c: Detectar y extraer etiquetas ("etiqueta crédito", "hashtag comida", "#viaje") ────
    final tags = <String>[];
    
    // 1. Extraer símbolos # literales que el dictado por voz pudo haber convertido automáticamente
    final literalHashes = RegExp(r'#([a-záéíóúüñ]+)', caseSensitive: false).allMatches(cleanText).toList();
    for (final m in literalHashes) {
      tags.add('#${m.group(1)}');
      cleanText = cleanText.replaceAll(m.group(0)!, '').trim();
    }

    // 2. Extraer a través de la palabra hablada "etiqueta" o "hashtag"
    final tagMatch = RegExp(r'\b(etiqueta[s]?|hashtag[s]?)\b', caseSensitive: false).firstMatch(cleanText);
    if (tagMatch != null) {
      final tagIdx = tagMatch.start;
      final textAfter = cleanText.substring(tagMatch.end).trim();
      
      // Quitar todo a partir de la palabra gatillo para no alterar otros parsers
      cleanText = cleanText.substring(0, tagIdx).trim();
      
      final parts = textAfter.split(RegExp(r'\s+'));
      final stopWords = ['en', 'para', 'por', 'a', 'al', 'del', 'con', 'el', 'la', 'los', 'las', 'un', 'una', 'mi', 'tu', 'su'];
      
      for (var word in parts) {
        final w = word.replaceAll(RegExp(r'[^a-záéíóúüñ]'), ''); 
        if (w.isEmpty) continue;
        if (stopWords.contains(w)) break; // Si llegamos a otra instrucción, paramos de leer
        if (w == 'y' || w == 'o' || w == 'e' || w == 'de') continue; 
        if (w == 'etiqueta' || w == 'etiquetas' || w == 'hashtag' || w == 'hashtags') continue; // Jamás agregar estas como tags
        
        tags.add('#$w');
      }
    }
    
    final String finalTagsStr = tags.isNotEmpty ? ' ' + tags.join(' ') : '';

    // ── PASO 4: Detectar tipo (gasto vs ingreso) ───────────
    double expenseScore = 0.0;
    double incomeScore  = 0.0;

    for (final entry in _expenseVerbs.entries) {
      if (rawNorm.contains(entry.key) && entry.value > expenseScore) {
        expenseScore = entry.value;
      }
    }
    for (final entry in _incomeVerbs.entries) {
      if (rawNorm.contains(entry.key) && entry.value > incomeScore) {
        incomeScore = entry.value;
      }
    }

    // Si no hay verbo explícito pero hay número → asumir gasto (compra más común)
    final hasNumber = RegExp(r'\d').hasMatch(cleanText) || _hasWordNumber(cleanText);
    if (expenseScore == 0.0 && incomeScore == 0.0 && hasNumber) {
      expenseScore = 0.55;
    }
    if (expenseScore == 0.0 && incomeScore == 0.0) {
      return const FinanceIntent(action: IntentAction.unknown, confidence: 0.0);
    }

    final isIncome       = incomeScore > expenseScore;
    final action         = isIncome ? IntentAction.create_income : IntentAction.create_expense;
    final typeConfidence = isIncome ? incomeScore : expenseScore;

    // ── PASO 5: Multi-ítem vs ítem único ───────────────────
    final items = _extractLineItems(cleanText);

    if (items.length > 1) {
      final totalAmount   = items.fold<double>(0, (s, i) => s + i.amount);
      final dominantItem  = items.reduce((a, b) => a.amount >= b.amount ? a : b);
      final descriptions  = items.map((i) => i.description).join(', ');

      return FinanceIntent(
        action:      action,
        amount:      totalAmount,
        category:    dominantItem.category,
        description: _capitalizeFirst(descriptions) + finalTagsStr,
        date:        date,
        confidence:  (typeConfidence * 0.9).clamp(0.0, 1.0),
        lineItems:   items,
      );
    }

    // ── Ítem único ─────────────────────────────────────────
    final amount = _extractTotalAmount(cleanText);
    // Si el usuario dijo "categoría X" explícitamente, úsalo con máxima prioridad;
    // si no, inferir desde el texto.
    final category = explicitCategoryHint != null
        ? _capitalizeFirst(explicitCategoryHint)
        : _detectCategory(cleanText);
    final description = _buildDescription(cleanText, category);

    final singleItem = amount != null
        ? [LineItem(description: description, amount: amount, category: category)]
        : <LineItem>[];

    final descriptionBase = description.isNotEmpty
          ? _capitalizeFirst(description)
          : _capitalizeFirst(category);

    return FinanceIntent(
      action:      action,
      amount:      amount,
      category:    category,
      description: (descriptionBase + finalTagsStr).trim(),
      date:        date,
      confidence:  typeConfidence,
      lineItems:   singleItem,
    );
  }

  // ─────────────────────────────────────────────────────────────
  // EXTRACCIÓN DE FECHA Y LIMPIEZA SIMULTÁNEA
  //
  // Este método es el corazón del fix: detecta la expresión
  // temporal, calcula la fecha, la BORRA del texto y devuelve
  // el texto limpio para que _extractTotalAmount no la vea.
  // ─────────────────────────────────────────────────────────────
  _DateResult _extractDateAndClean(String text) {
    final now = DateTime.now();

    // ── A. "hace N días/semanas/meses" ─────────────────────
    final haceNumPattern = RegExp(
      r'hace\s+(\d+|un|uno|una|dos|tres|cuatro|cinco|seis|siete|ocho|nueve|diez|'
      r'once|doce|trece|catorce|quince|dieciseis|diecisiete|dieciocho|diecinueve|'
      r'veinte|veintiuno|veintidos|veintitres|veinticuatro|veinticinco|'
      r'treinta|cuarenta|cincuenta|sesenta|setenta|ochenta|noventa)\s+'
      r'(dia|dias|semana|semanas|mes|meses)',
      caseSensitive: false,
    );
    final haceNumMatch = haceNumPattern.firstMatch(text);
    if (haceNumMatch != null) {
      final numStr  = haceNumMatch.group(1)!;
      final unitStr = haceNumMatch.group(2)!;
      final n       = _wordToInt(numStr) ?? int.tryParse(numStr) ?? 1;
      int days;
      if (unitStr.startsWith('dia')) {
        days = n;
      } else if (unitStr.startsWith('semana')) {
        days = n * 7;
      } else {
        days = n * 30;
      }
      final cleaned = text.replaceAll(haceNumMatch.group(0)!, '').trim();
      return _DateResult(now.subtract(Duration(days: days)), _tidy(cleaned));
    }

    // ── B. "el lunes pasado", "el martes pasado", etc. ─────
    final weekdayPastPattern = RegExp(
      r'(?:el\s+)?(lunes|martes|miercoles|jueves|viernes|sabado|domingo)\s+pasad[oa]?',
    );
    final wdPastMatch = weekdayPastPattern.firstMatch(text);
    if (wdPastMatch != null) {
      const wd = {'lunes':1,'martes':2,'miercoles':3,'jueves':4,'viernes':5,'sabado':6,'domingo':7};
      final target = wd[wdPastMatch.group(1)!]!;
      int diff = target - now.weekday;
      if (diff >= 0) diff -= 7;
      final cleaned = text.replaceAll(wdPastMatch.group(0)!, '').trim();
      return _DateResult(now.add(Duration(days: diff)), _tidy(cleaned));
    }

    // ── C. "el lunes" / "el martes" (sin "pasado") ─────────
    final weekdayPattern = RegExp(
      r'(?:el\s+)(lunes|martes|miercoles|jueves|viernes|sabado|domingo)',
    );
    final wdMatch = weekdayPattern.firstMatch(text);
    if (wdMatch != null) {
      const wd = {'lunes':1,'martes':2,'miercoles':3,'jueves':4,'viernes':5,'sabado':6,'domingo':7};
      final target = wd[wdMatch.group(1)!]!;
      int diff = target - now.weekday;
      if (diff > 0) diff -= 7;
      final cleaned = text.replaceAll(wdMatch.group(0)!, '').trim();
      return _DateResult(now.add(Duration(days: diff)), _tidy(cleaned));
    }

    // ── D. "la semana pasada" ──────────────────────────────
    if (text.contains('la semana pasada')) {
      final cleaned = text.replaceAll('la semana pasada', '').trim();
      return _DateResult(now.subtract(const Duration(days: 7)), _tidy(cleaned));
    }

    // ── E. Frases fijas de días relativos ─────────────────
    // Ordenadas de más larga a más corta para evitar matches parciales
    final fixedDates = <String, int>{
      'anteayer':     -2,
      'antier':       -2,
      'antes de ayer':-2,
      'ayer':         -1,
      'hoy':           0,
      'manana':        1,
    };
    for (final entry in fixedDates.entries) {
      if (text.contains(entry.key)) {
        final cleaned = text.replaceAll(entry.key, '').trim();
        return _DateResult(
          now.add(Duration(days: entry.value)),
          _tidy(cleaned),
        );
      }
    }

    // ── F. "esta semana" ───────────────────────────────────
    if (text.contains('esta semana')) {
      final cleaned = text.replaceAll('esta semana', '').trim();
      return _DateResult(now, _tidy(cleaned));
    }

    // ── G. Fecha explícita "el 15", "el 15 de enero", etc. ─
    final explicitDatePattern = RegExp(
      r'el\s+(\d{1,2})(?:\s+de\s+(enero|febrero|marzo|abril|mayo|junio|julio|agosto|septiembre|octubre|noviembre|diciembre))?',
    );
    final edMatch = explicitDatePattern.firstMatch(text);
    if (edMatch != null) {
      final day   = int.tryParse(edMatch.group(1)!) ?? now.day;
      final month = _monthToInt(edMatch.group(2)) ?? now.month;
      final year  = now.year;
      final candidate = DateTime(year, month, day);
      final resolved  = candidate.isAfter(now) ? DateTime(year - 1, month, day) : candidate;
      final cleaned   = text.replaceAll(edMatch.group(0)!, '').trim();
      return _DateResult(resolved, _tidy(cleaned));
    }

    // Sin fecha detectada → hoy, texto sin cambios
    return _DateResult(now, text);
  }

  // ─────────────────────────────────────────────────────────────
  // MULTI-ÍTEM
  // ─────────────────────────────────────────────────────────────
  List<LineItem> _extractLineItems(String text) {
    final items = <LineItem>[];

    // Patrón A: "$X de [cosa]" seguidos por "y" o ","
    final patternAmountFirst = RegExp(
      r'(\$?\s*[\d.,]+\s*(?:pesos?|mxn|cop|usd|eur)?\s*(?:de|para|en)\s+([a-záéíóúüñ\s]+?))'
      r'(?=\s*(?:y|,|\.|$|\s+y\s+))',
      caseSensitive: false,
    );
    for (final m in patternAmountFirst.allMatches(text)) {
      final full  = m.group(1) ?? '';
      final desc  = (m.group(2) ?? '').trim();
      final amount = _extractFirstNumber(full);
      if (amount != null && amount > 0 && desc.isNotEmpty) {
        items.add(LineItem(
          description: _capitalizeFirst(desc),
          amount:      amount,
          category:    _detectCategory(desc),
        ));
      }
    }
    if (items.length > 1) return items;

    // Patrón B: segmentar por "y" y parsear cada parte
    items.clear();
    final segments = _splitIntoSegments(text);
    if (segments.length > 1) {
      for (final seg in segments) {
        final amount = _extractTotalAmount(seg);
        if (amount != null && amount > 0) {
          final cat  = _detectCategory(seg);
          final desc = _buildDescription(seg, cat);
          items.add(LineItem(
            description: _capitalizeFirst(desc.isNotEmpty ? desc : seg.trim()),
            amount:      amount,
            category:    cat,
          ));
        }
      }
      if (items.length > 1) return items;
    }

    // Patrón C: "frijoles y jitomate a 20 cada uno"
    items.clear();
    final unitPrice = _detectUnitPrice(text);
    if (unitPrice != null) {
      final things = _extractListOfThings(text);
      for (final thing in things) {
        items.add(LineItem(
          description: _capitalizeFirst(thing),
          amount:      unitPrice,
          category:    _detectCategory(thing),
        ));
      }
    }

    return items;
  }

  double? _detectUnitPrice(String text) {
    final patterns = [
      RegExp(r'a\s+(\$?[\d.,]+)\s*(?:pesos?|mxn|cop)?\s*(?:cada\s+uno?|por\s+(?:cada|uno?|pieza)|c\/u)\b'),
      RegExp(r'(\$?[\d.,]+)\s*(?:pesos?|mxn)?\s*(?:cada\s+uno?|c\/u)\b'),
    ];
    for (final p in patterns) {
      final m = p.firstMatch(text);
      if (m != null) return _parseNumber(m.group(1) ?? '');
    }
    return null;
  }

  List<String> _extractListOfThings(String text) {
    var cleaned = text
        .replaceAll(RegExp(r'a\s+\$?[\d.,]+\s*(?:pesos?|mxn|cop|usd)?\s*(?:cada\s+uno?|por\s+(?:cada|uno?|pieza)|c\/u)\b'), '')
        .replaceAll(RegExp(r'\$?[\d.,]+\s*(?:pesos?|mxn|cop)?\s*(?:cada\s+uno?|c\/u)\b'), '');
    for (final v in _expenseVerbs.keys) { cleaned = cleaned.replaceAll(v, ''); }
    for (final v in _incomeVerbs.keys)  { cleaned = cleaned.replaceAll(v, ''); }
    cleaned = cleaned.replaceAll(
        RegExp(r'\b(de|un|una|el|la|los|las|con|en|para|por|al|del)\b'), '');
    return cleaned
        .split(RegExp(r'\s*(?:y|,)\s*'))
        .map((p) => p.trim())
        .where((p) => p.length > 2)
        .toList();
  }

  List<String> _splitIntoSegments(String text) {
    var stripped = text;
    for (final v in _expenseVerbs.keys) { stripped = stripped.replaceFirst(v, '').trim(); }
    for (final v in _incomeVerbs.keys)  { stripped = stripped.replaceFirst(v, '').trim(); }
    for (final sep in [' y ', ', ']) {
      if (stripped.contains(sep)) {
        final parts = stripped.split(sep);
        if (parts.every((p) => p.trim().length > 3)) {
          return parts.map((p) => p.trim()).toList();
        }
      }
    }
    return [stripped];
  }

  // ─────────────────────────────────────────────────────────────
  // EXTRACCIÓN DE MONTO (opera sobre texto YA sin fechas)
  // ─────────────────────────────────────────────────────────────
  double? _extractTotalAmount(String text) {
    // ── PRIORIDAD 1: $número (símbolo explícito) ───────────────
    final symMatch = RegExp(r'\$\s*([\d]{1,7}(?:[.,]\d{1,2})?)').firstMatch(text);
    if (symMatch != null) {
      final v = _parseNumber(symMatch.group(1)!);
      if (v != null) return v;
    }

    // ── PRIORIDAD 2: número + unidad monetaria explícita ───────
    // Ej: "100 pesos", "50 mxn" — captura TODOS y devuelve el primero válido.
    // Esto asegura que "1 kilo de tortillas 100 pesos" → 100.
    final unitMatch = RegExp(
      r'([\d]{1,7}(?:[.,]\d{1,2})?)\s*(?:pesos?|mxn|cop|eur|usd|dolares?)\b',
    ).firstMatch(text);
    if (unitMatch != null) {
      final v = _parseNumber(unitMatch.group(1)!);
      if (v != null) return v;
    }

    // ── PRIORIDAD 3: Multiplicación explícita (qty * precio) ───
    // Ej: "3 kilos a 15", "2 piezas por 50"
    final multMatch = RegExp(
      r'(\d+(?:[.,]\d+)?)\s*(?:kg|kilos?|gramos?|piezas?|litros?|paquetes?|cajas?)?\s*'
      r'(?:de\s+[\w\s]+?)?(?:a|por)\s*\$?([\d.,]+)',
    ).firstMatch(text);
    if (multMatch != null) {
      final qty   = _parseNumber(multMatch.group(1)!);
      final price = _parseNumber(multMatch.group(2)!);
      if (qty != null && price != null) return qty * price;
    }

    // ── PRIORIDAD 4: Patrón "N [unidad] de [cosa] PRECIO" ──────
    // Ej: "1 kilo de tortillas 100" → precio = 100 (no la cantidad)
    // Si la frase empieza con un número de cantidad + unidad, el precio
    // es el ÚLTIMO número significativo que aparece después.
    final qtyUnitPattern = RegExp(
      r'^\s*(\d+(?:[.,]\d+)?)\s*(?:kg|kilos?|gramos?|piezas?|litros?|paquetes?|cajas?|'
      r'docenas?|unidades?|bolsas?|latas?)\b',
      caseSensitive: false,
    );
    if (qtyUnitPattern.hasMatch(text)) {
      // Recolectar todos los números del texto; el precio es el último.
      final allNums = RegExp(r'\b(\d{1,7}(?:[.,]\d{1,2})?)\b')
          .allMatches(text)
          .map((m) => _parseNumber(m.group(1)!))
          .whereType<double>()
          .toList();
      if (allNums.length >= 2) {
        // El último número es el precio; el primero es la cantidad.
        return allNums.last;
      }
    }

    // ── PRIORIDAD 5: Números en palabras (greedy, más largo primero) ─
    for (final entry in _wordNumbers) {
      if (text.contains(entry.key)) return entry.value;
    }

    // ── PRIORIDAD 6: Número puro — heurística ─────────────────
    // Si hay varios números, preferir el mayor (más probable que sea precio).
    final plainMatches = RegExp(r'\b(\d{1,7}(?:[.,]\d{1,2})?)\b').allMatches(text);
    double? best;
    for (final m in plainMatches) {
      final v = _parseNumber(m.group(1)!);
      if (v != null && v >= 1 && v < 10000000) {
        if (best == null || v > best) best = v;
      }
    }
    return best;
  }

  double? _extractFirstNumber(String text) {
    for (final entry in _wordNumbers) {
      if (text.contains(entry.key)) return entry.value;
    }
    final m = RegExp(r'\$?\s*(\d{1,7}(?:[.,]\d{1,2})?)').firstMatch(text);
    if (m != null) return _parseNumber(m.group(1)!);
    return null;
  }

  // ─────────────────────────────────────────────────────────────
  // CATEGORIZACIÓN
  // ─────────────────────────────────────────────────────────────
  String _detectCategory(String text) {
    int bestScore      = 0;
    String bestCategory = 'General';
    for (final entry in _categoryKeywords.entries) {
      int score = 0;
      for (final kw in entry.value) {
        if (text.contains(_normalize(kw))) {
          score += kw.split(' ').length > 1 ? 3 : 1;
        }
      }
      if (score > bestScore) {
        bestScore    = score;
        bestCategory = entry.key;
      }
    }
    return bestCategory;
  }

  // ─────────────────────────────────────────────────────────────
  // DESCRIPCIÓN LIMPIA — extrae solo las palabras más importantes
  // ─────────────────────────────────────────────────────────────
  String _buildDescription(String text, String category) {
    var desc = text;

    // 0. Eliminar indicadores de categoría explícitos: "categoría juegos", "categoria comida"
    desc = desc.replaceAll(
        RegExp(r'\bcategor[ií]a\s+\w+', caseSensitive: false), '');

    // 1. Eliminar verbos de gasto/ingreso
    for (final v in _expenseVerbs.keys)  { desc = desc.replaceAll(v, ''); }
    for (final v in _incomeVerbs.keys)   { desc = desc.replaceAll(v, ''); }

    // 2. Eliminar montos numéricos y sus unidades
    desc = desc.replaceAll(
        RegExp(r'\$?\s*\d+(?:[.,]\d{1,2})?\s*(?:pesos?|mxn|cop|usd|eur|dolares?)?'), '');

    // 3. Eliminar palabras vacías (stopwords) en español
    //    Frase completa de artículos, preposiciones, pronombres, cuantificadores
    const stopwords = [
      'hace', 'ayer', 'hoy', 'manana', 'antier', 'anteayer',
      'pasado', 'semana', 'mes', 'dia', 'dias',
      'en', 'de', 'para', 'por', 'a', 'al', 'del',
      'un', 'una', 'el', 'la', 'los', 'las', 'con',
      'que', 'me', 'le', 'se', 'te', 'lo', 'les',
      'mi', 'tu', 'su', 'mis', 'tus', 'sus',
      'hay', 'fue', 'fui', 'era', 'son', 'es', 'esta', 'este',
      'también', 'tambien', 'si', 'no', 'ya', 'muy', 'mas',
      'pero', 'y', 'o', 'ni', 'e',
      'otro', 'otra', 'otros', 'otras',
      'poco', 'mucho', 'tanto', 'algo', 'todo',
      'cada', 'uno', 'unos', 'unas',
    ];
    for (final sw in stopwords) {
      desc = desc.replaceAll(RegExp('\\b$sw\\b', caseSensitive: false), '');
    }

    // 4. Limpiar espacios múltiples
    desc = desc.replaceAll(RegExp(r'\s+'), ' ').trim();

    // 5. Limitar longitud — máximo 4 palabras significativas
    final words = desc
        .split(' ')
        .where((w) => w.length >= 3)
        .take(4)
        .toList();

    if (words.isEmpty) return _capitalizeFirst(category);

    // 6. Capitalizar solo la primera letra del resultado
    final result = words.join(' ');
    return result.length < 3 ? _capitalizeFirst(category) : result;
  }

  // ─────────────────────────────────────────────────────────────
  // Utilidades
  // ─────────────────────────────────────────────────────────────

  /// Limpia espacios extra y comas/puntos al inicio/fin.
  String _tidy(String s) =>
      s.replaceAll(RegExp(r'^\s*[,\.]\s*|\s*[,\.]\s*$'), '').replaceAll(RegExp(r'\s+'), ' ').trim();

  bool _hasWordNumber(String text) =>
      _wordNumbers.any((e) => text.contains(e.key));

  double? _parseNumber(String raw) {
    final cleaned = raw.replaceAll(r'$', '').replaceAll(',', '.').trim();
    final val     = double.tryParse(cleaned);
    if (val != null && val > 0 && val < 10000000) return val;
    return null;
  }

  String _normalize(String input) => input
      .toLowerCase()
      .replaceAll('á', 'a').replaceAll('é', 'e').replaceAll('í', 'i')
      .replaceAll('ó', 'o').replaceAll('ú', 'u').replaceAll('ü', 'u')
      .replaceAll('ñ', 'n');

  bool _containsAny(String text, List<String> keywords) =>
      keywords.any((k) => text.contains(k));

  String _capitalizeFirst(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  /// Convierte palabras numéricas pequeñas a int.
  int? _wordToInt(String w) {
    const map = {
      'un': 1, 'uno': 1, 'una': 1, 'dos': 2, 'tres': 3,
      'cuatro': 4, 'cinco': 5, 'seis': 6, 'siete': 7,
      'ocho': 8, 'nueve': 9, 'diez': 10,
      'once': 11, 'doce': 12, 'trece': 13, 'catorce': 14, 'quince': 15,
      'dieciseis': 16, 'diecisiete': 17, 'dieciocho': 18, 'diecinueve': 19,
      'veinte': 20, 'veintiuno': 21, 'veintidos': 22, 'veintitres': 23,
      'veinticuatro': 24, 'veinticinco': 25,
      'treinta': 30, 'cuarenta': 40, 'cincuenta': 50,
      'sesenta': 60, 'setenta': 70, 'ochenta': 80, 'noventa': 90,
    };
    return map[w.toLowerCase()];
  }

  int? _monthToInt(String? s) {
    if (s == null) return null;
    const months = {
      'enero': 1, 'febrero': 2, 'marzo': 3, 'abril': 4,
      'mayo': 5, 'junio': 6, 'julio': 7, 'agosto': 8,
      'septiembre': 9, 'octubre': 10, 'noviembre': 11, 'diciembre': 12,
    };
    return months[s.toLowerCase()];
  }
}
