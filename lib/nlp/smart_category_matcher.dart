// SmartCategoryMatcher v2 — NLP semántico para categorías financieras (Español)
//
// Capas de detección:
//  1. Frases de contexto (bigramas y trigramas) — mayor peso
//  2. Tokens individuales en diccionario de aliases
//  3. Match parcial / subcadena
//  4. Match difuso (token overlap) como fallback
//
// Cada coincidencia acumula votos ponderados → gana la categoría con más puntos.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/categories/category_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FRASES DE CONTEXTO (bigramas/trigramas) → mayor peso (score 4.0)
// ─────────────────────────────────────────────────────────────────────────────
const Map<String, String> _contextPhrases = {
  // Salud
  'fui al medico': 'Salud', 'fui al doctor': 'Salud', 'fui al dentista': 'Salud',
  'fui a la clinica': 'Salud', 'fui al hospital': 'Salud',
  'me duele la muela': 'Salud', 'me duele el diente': 'Salud',
  'me operaron': 'Salud', 'me opere': 'Salud', 'me enyesaron': 'Salud',
  'me vacune': 'Salud', 'puse una vacuna': 'Salud',
  'tome una pastilla': 'Salud', 'tome medicamento': 'Salud',
  'seguro de salud': 'Salud', 'seguro medico': 'Salud',
  'analisis de sangre': 'Salud', 'estudios medicos': 'Salud',
  'cita con el doctor': 'Salud', 'cita medica': 'Salud',
  'receta medica': 'Salud',

  // Comida / Restaurantes
  'fui a comer': 'Comida', 'salimos a comer': 'Comida', 'fui a cenar': 'Comida',
  'pedi comida': 'Comida', 'ordene comida': 'Comida',
  'comida a domicilio': 'Comida', 'delivery de comida': 'Comida',
  'rappi de comida': 'Comida', 'uber eats': 'Comida', 'didi food': 'Comida',
  'fui a desayunar': 'Comida', 'fui al restaurante': 'Comida',
  'me fui a la taqueria': 'Comida',

  // Super
  'fui al super': 'Super', 'fui al walmart': 'Super', 'fui al mercado': 'Super',
  'hice el mandado': 'Super', 'hice las compras': 'Super',
  'compre en soriana': 'Super', 'compre en chedraui': 'Super',
  'compre en costco': 'Super', 'compre en oxxo': 'Super',

  // Transporte
  'pedi un uber': 'Transporte', 'pedi un didi': 'Transporte',
  'tome el uber': 'Transporte', 'tome el metro': 'Transporte',
  'fui en uber': 'Transporte', 'fui en taxi': 'Transporte',
  'fui en camion': 'Transporte', 'le puse gasolina': 'Transporte',
  'puse gasolina': 'Transporte', 'cargue gasolina': 'Transporte',
  'pague la caseta': 'Transporte', 'pague el estacionamiento': 'Transporte',
  'pague el metro': 'Transporte', 'pague el camion': 'Transporte',
  'afinacion del carro': 'Transporte', 'cambio de aceite': 'Transporte',
  'cambio de llanta': 'Transporte', 'revisione el carro': 'Transporte',

  // Casa
  'pague la renta': 'Casa', 'pague el internet': 'Casa',
  'pague la luz': 'Casa', 'pague el gas': 'Casa',
  'pague el agua': 'Casa', 'pague el telefono': 'Casa',
  'pague la hipoteca': 'Casa', 'pague el predial': 'Casa',
  'fui a home depot': 'Casa', 'compre muebles': 'Casa',
  'repare la llave': 'Casa', 'compre para el hogar': 'Casa',

  // Educacion
  'pague la colegiatura': 'Educacion', 'pague la inscripcion': 'Educacion',
  'compre libros': 'Educacion', 'compre utiles': 'Educacion',
  'pague el curso': 'Educacion', 'tome un curso': 'Educacion',
  'pague clases': 'Educacion', 'pague la universidad': 'Educacion',
  'pague el colegio': 'Educacion',

  // Gym
  'pague el gym': 'Gym', 'pague el gimnasio': 'Gym',
  'pague la membresia': 'Gym', 'pague clases de yoga': 'Gym',
  'pague crossfit': 'Gym', 'compre proteina': 'Gym',
  'compre suplementos': 'Gym',

  // Entretenimiento
  'fui al cine': 'Entretenimiento', 'fui al teatro': 'Entretenimiento',
  'fui al antro': 'Entretenimiento', 'fui al bar': 'Entretenimiento',
  'fui a un concierto': 'Entretenimiento', 'pague netflix': 'Entretenimiento',
  'pague spotify': 'Entretenimiento', 'pague disney': 'Entretenimiento',
  'pague amazon prime': 'Entretenimiento', 'fui a bowling': 'Entretenimiento',
  'compre entrada': 'Entretenimiento',

  // Juegos
  'compre un juego': 'Juegos', 'compre en steam': 'Juegos',
  'compre dlc': 'Juegos', 'pague xbox': 'Juegos',
  'pague playstation': 'Juegos', 'compre videojuego': 'Juegos',
  'compre creditos': 'Juegos',

  // Viajes
  'compre boleto de avion': 'Viajes', 'compre vuelo': 'Viajes',
  'pague el hotel': 'Viajes', 'pague airbnb': 'Viajes',
  'fui de vacaciones': 'Viajes', 'fui a viajar': 'Viajes',

  // Ropa
  'compre ropa': 'Ropa', 'compre tenis': 'Ropa', 'compre zapatos': 'Ropa',
  'compre en zara': 'Ropa', 'compre en shein': 'Ropa',
  'compre en liverpool': 'Ropa', 'compre playera': 'Ropa',
  'compre pantalon': 'Ropa', 'compre chamarra': 'Ropa',

  // Mascotas
  'pague al veterinario': 'Mascotas', 'compre croquetas': 'Mascotas',
  'vacuna del perro': 'Mascotas', 'vacuna del gato': 'Mascotas',
  'comida del perro': 'Mascotas', 'comida del gato': 'Mascotas',
  'consulta del veterinario': 'Mascotas',

  // Regalo
  'compre un regalo': 'Regalo', 'compre flores': 'Regalo',
  'compre chocolates': 'Regalo', 'compre un pastel': 'Regalo',
  'compre para navidad': 'Regalo',

  // Ingresos
  'me deposito el sueldo': 'Ingresos', 'me cayo la quincena': 'Ingresos',
  'me pagaron el sueldo': 'Ingresos', 'me transfirieron': 'Ingresos',
  'vendi algo': 'Ingresos', 'cobré mi sueldo': 'Ingresos',
};

// ─────────────────────────────────────────────────────────────────────────────
// ALIAS SEMÁNTICOS — tokens individuales (score 2.0 exact / 0.5 partial)
// ─────────────────────────────────────────────────────────────────────────────
const Map<String, String> _semanticAliases = {
  // ── Comida / Restaurantes ──
  'comida': 'Comida', 'comer': 'Comida', 'almuerzo': 'Comida',
  'desayuno': 'Comida', 'cena': 'Comida', 'tacos': 'Comida',
  'taco': 'Comida', 'tortas': 'Comida', 'torta': 'Comida',
  'pizza': 'Comida', 'hamburguesa': 'Comida', 'hamburgesa': 'Comida',
  'sushi': 'Comida', 'lonche': 'Comida', 'lunch': 'Comida',
  'cafe': 'Comida', 'coffee': 'Comida', 'cappuccino': 'Comida',
  'latte': 'Comida', 'americano': 'Comida',
  'starbucks': 'Comida', 'dominos': 'Comida', 'mcdonalds': 'Comida',
  'kfc': 'Comida', 'subway': 'Comida', 'burger king': 'Comida',
  'little caesars': 'Comida', 'dennys': 'Comida', 'vips': 'Comida',
  'ihop': 'Comida', 'wendys': 'Comida', 'chipotle': 'Comida',
  'snack': 'Comida', 'merienda': 'Comida', 'antojitos': 'Comida',
  'gorditas': 'Comida', 'quesadillas': 'Comida', 'quesadilla': 'Comida',
  'pollo': 'Comida', 'sopa': 'Comida', 'caldo': 'Comida',
  'elotes': 'Comida', 'tamales': 'Comida', 'enchiladas': 'Comida',
  'enchilada': 'Comida', 'taqueria': 'Comida', 'restaurante': 'Comida',
  'wings': 'Comida', 'alitas': 'Comida', 'burrito': 'Comida',
  'tamal': 'Comida', 'pozole': 'Comida', 'carnitas': 'Comida',
  'barbacoa': 'Comida', 'milanesa': 'Comida', 'chilaquiles': 'Comida',
  'huaraches': 'Comida', 'tlayuda': 'Comida', 'molotes': 'Comida',
  'flautas': 'Comida', 'tostada': 'Comida', 'tostadas': 'Comida',
  'menudo': 'Comida', 'birria': 'Comida', 'suadero': 'Comida',
  'pastor': 'Comida', 'campechana': 'Comida', 'vampiro': 'Comida',
  'cochinita': 'Comida', 'torta ahogada': 'Comida',
  'raspado': 'Comida', 'nieve': 'Comida', 'helado': 'Comida',
  'pay': 'Comida', 'pastelillo': 'Comida', 'dona': 'Comida',
  'dona dunkin': 'Comida', 'panque': 'Comida', 'cuernito': 'Comida',
  'concha': 'Comida', 'pan dulce': 'Comida',
  'ensalada': 'Comida', 'wrap': 'Comida', 'hot dog': 'Comida',
  'hotdog': 'Comida', 'hot-dog': 'Comida', 'elote': 'Comida',
  'esquite': 'Comida', 'gelatina': 'Comida', 'flan': 'Comida',
  'rappi': 'Comida', 'ubereats': 'Comida', 'didifood': 'Comida',
  'pedidosya': 'Comida',

  // ── Mercado / Super ──
  'super': 'Super', 'supermercado': 'Super', 'mercado': 'Super',
  'despensa': 'Super', 'walmart': 'Super', 'soriana': 'Super',
  'chedraui': 'Super', 'costco': 'Super', 'oxxo': 'Super',
  'seven eleven': 'Super', '711': 'Super', 'circle k': 'Super',
  'tienda': 'Super', 'abarrotes': 'Super', 'mandado': 'Super',
  'comercial mexicana': 'Super', 'city market': 'Super',
  'superama': 'Super', 'la comer': 'Super', 'sams': 'Super',
  'bodega aurrera': 'Super', 'bodega': 'Super',
  'frijoles': 'Super', 'jitomate': 'Super', 'tomate': 'Super',
  'cebolla': 'Super', 'chile': 'Super', 'aguacate': 'Super',
  'naranja': 'Super', 'manzana': 'Super', 'platano': 'Super',
  'limon': 'Super', 'zanahoria': 'Super', 'papa': 'Super',
  'papas': 'Super', 'arroz': 'Super', 'atun': 'Super',
  'sardinas': 'Super', 'huevo': 'Super', 'huevos': 'Super',
  'aceite': 'Super', 'sal': 'Super', 'azucar': 'Super',
  'harina': 'Super', 'fideo': 'Super', 'pasta': 'Super',
  'leche': 'Super', 'pan': 'Super', 'tortillas': 'Super',
  'verduras': 'Super', 'frutas': 'Super',
  'champinon': 'Super', 'brocoli': 'Super', 'espinaca': 'Super',
  'pepino': 'Super', 'lechuga': 'Super', 'pimienta': 'Super',
  'detergente': 'Super', 'jabon': 'Super', 'shampoo': 'Super',
  'crema': 'Super', 'yogurt': 'Super', 'queso': 'Super',
  'jamon': 'Super', 'mantequilla': 'Super', 'cereal': 'Super',
  'galletas': 'Super', 'refresco': 'Super', 'jugo': 'Super',
  'agua': 'Super', 'desodorante': 'Super', 'pasta dental': 'Super',
  'papel': 'Super', 'servilletas': 'Super',
  'mayonesa': 'Super', 'ketchup': 'Super', 'mostaza': 'Super',
  'salsa': 'Super', 'vinagre': 'Super', 'miel': 'Super',
  'avena': 'Super', 'granola': 'Super', 'cafe molido': 'Super',

  // ── Transporte ──
  'uber': 'Transporte', 'didi': 'Transporte', 'taxi': 'Transporte',
  'cabify': 'Transporte', 'bus': 'Transporte', 'camion': 'Transporte',
  'metro': 'Transporte', 'metrobus': 'Transporte', 'trolebus': 'Transporte',
  'gasolina': 'Transporte', 'combustible': 'Transporte', 'pemex': 'Transporte',
  'caseta': 'Transporte', 'autopista': 'Transporte', 'peaje': 'Transporte',
  'estacionamiento': 'Transporte', 'parking': 'Transporte',
  'tenencia': 'Transporte', 'verificacion': 'Transporte',
  'afinacion': 'Transporte', 'llanta': 'Transporte', 'llantas': 'Transporte',
  'transporte': 'Transporte', 'pasaje': 'Transporte', 'boleto': 'Transporte',
  'pesero': 'Transporte', 'colectivo': 'Transporte', 'autobus': 'Transporte',
  'moto': 'Transporte', 'bicicleta': 'Transporte', 'patinete': 'Transporte',
  'scooter': 'Transporte', 'carro': 'Transporte', 'auto': 'Transporte',
  'refaccion': 'Transporte', 'mecanico': 'Transporte',
  'aceite del carro': 'Transporte', 'frenos': 'Transporte',
  'servicio del auto': 'Transporte', 'placas': 'Transporte',
  'seguro del carro': 'Transporte', 'remolque': 'Transporte',

  // ── Ropa ──
  'ropa': 'Ropa', 'zapatos': 'Ropa', 'tenis': 'Ropa', 'zapatillas': 'Ropa',
  'camisa': 'Ropa', 'pantalon': 'Ropa', 'jeans': 'Ropa', 'vestido': 'Ropa',
  'falda': 'Ropa', 'blusa': 'Ropa', 'playera': 'Ropa', 'sudadera': 'Ropa',
  'chamarra': 'Ropa', 'jacket': 'Ropa', 'nike': 'Ropa', 'adidas': 'Ropa',
  'zara': 'Ropa', 'shein': 'Ropa', 'liverpool': 'Ropa', 'moda': 'Ropa',
  'outfit': 'Ropa', 'calcetines': 'Ropa', 'gorra': 'Ropa', 'sombrero': 'Ropa',
  'bolsa': 'Ropa', 'cartera': 'Ropa', 'cinturon': 'Ropa', 'abrigo': 'Ropa',
  'traje': 'Ropa', 'corbata': 'Ropa', 'aretes': 'Ropa', 'collar': 'Ropa',
  'pulsera': 'Ropa', 'anillo': 'Ropa', 'pijama': 'Ropa', 'ropa interior': 'Ropa',
  'calzoncillo': 'Ropa', 'calzon': 'Ropa', 'calzones': 'Ropa',
  'sostén': 'Ropa', 'brasier': 'Ropa', 'pañuelo': 'Ropa', 'bufanda': 'Ropa',
  'guantes': 'Ropa', 'medias': 'Ropa', 'ropa deportiva': 'Ropa',
  'shorts': 'Ropa', 'leggins': 'Ropa', 'leggings': 'Ropa',
  'h&m': 'Ropa', 'forever 21': 'Ropa', 'pull and bear': 'Ropa',
  'bershka': 'Ropa', 'stradivarius': 'Ropa',

  // ── Salud ──
  'farmacia': 'Salud', 'medicina': 'Salud', 'medicamento': 'Salud',
  'pastillas': 'Salud', 'vitaminas': 'Salud', 'doctor': 'Salud',
  'medico': 'Salud', 'hospital': 'Salud', 'clinica': 'Salud',
  'consulta': 'Salud', 'dentista': 'Salud', 'oculista': 'Salud',
  'oftalmologo': 'Salud', 'otorrinolaringologo': 'Salud',
  'psicologo': 'Salud', 'psiquiatra': 'Salud',
  'terapia': 'Salud', 'analisis': 'Salud', 'laboratorio': 'Salud',
  'similares': 'Salud', 'benavides': 'Salud', 'farmacias guadalajara': 'Salud',
  'inyeccion': 'Salud', 'vacuna': 'Salud', 'salud': 'Salud',
  'radiografia': 'Salud', 'ultrasonido': 'Salud', 'antibiotico': 'Salud',
  'antiinflamatorio': 'Salud', 'calmante': 'Salud', 'jarabe': 'Salud',
  'pomada': 'Salud', 'vendas': 'Salud', 'gasas': 'Salud',
  'termometro': 'Salud', 'glucosa': 'Salud', 'presion arterial': 'Salud',
  'operacion': 'Salud', 'cirugia': 'Salud', 'internamiento': 'Salud',
  'emergencia': 'Salud', 'ambulancia': 'Salud', 'ortopedista': 'Salud',
  'fisioterapia': 'Salud', 'nutriologo': 'Salud', 'dermatologo': 'Salud',
  'cardiologo': 'Salud', 'neurologo': 'Salud',
  'craneo': 'Salud', 'fractura': 'Salud', 'esguince': 'Salud',

  // ── Entretenimiento / Juegos ──
  'cine': 'Entretenimiento', 'pelicula': 'Entretenimiento',
  'teatro': 'Entretenimiento', 'concierto': 'Entretenimiento',
  'show': 'Entretenimiento', 'evento': 'Entretenimiento',
  'netflix': 'Entretenimiento', 'spotify': 'Entretenimiento',
  'amazon prime': 'Entretenimiento', 'disney plus': 'Entretenimiento',
  'hbo': 'Entretenimiento', 'hbo max': 'Entretenimiento',
  'apple tv': 'Entretenimiento', 'paramount': 'Entretenimiento',
  'suscripcion': 'Entretenimiento', 'antro': 'Entretenimiento',
  'bar': 'Entretenimiento', 'discoteca': 'Entretenimiento',
  'karaoke': 'Entretenimiento', 'bowling': 'Entretenimiento',
  'parque': 'Entretenimiento', 'zoo': 'Entretenimiento',
  'museo': 'Entretenimiento', 'diversion': 'Entretenimiento',
  'fiesta': 'Entretenimiento', 'bailar': 'Entretenimiento',
  'club': 'Entretenimiento', 'escape room': 'Entretenimiento',
  'circo': 'Entretenimiento', 'obra': 'Entretenimiento',
  'festival': 'Entretenimiento', 'entrada': 'Entretenimiento',
  'boliche': 'Entretenimiento', 'juego de realidad virtual': 'Entretenimiento',
  'trampolines': 'Entretenimiento', 'go karts': 'Entretenimiento',
  'juego': 'Juegos', 'videojuego': 'Juegos', 'steam': 'Juegos',
  'playstation': 'Juegos', 'xbox': 'Juegos', 'nintendo': 'Juegos',
  'switch': 'Juegos', 'ps5': 'Juegos', 'ps4': 'Juegos',
  'dlc': 'Juegos', 'skin': 'Juegos', 'creditos del juego': 'Juegos',
  'robux': 'Juegos', 'v-bucks': 'Juegos', 'coins': 'Juegos',

  // ── Casa / Hogar ──
  'renta': 'Casa', 'alquiler': 'Casa', 'hipoteca': 'Casa',
  'predial': 'Casa', 'luz': 'Casa', 'electricidad': 'Casa', 'cfe': 'Casa',
  'internet': 'Casa', 'telmex': 'Casa', 'izzi': 'Casa', 'totalplay': 'Casa',
  'megacable': 'Casa', 'telefono': 'Casa', 'celular': 'Casa',
  'telcel': 'Casa', 'movistar': 'Casa', 'att': 'Casa',
  'muebles': 'Casa', 'silla': 'Casa', 'mesa': 'Casa', 'cama': 'Casa',
  'sofa': 'Casa', 'refrigerador': 'Casa', 'lavadora': 'Casa',
  'estufa': 'Casa', 'microondas': 'Casa', 'licuadora': 'Casa',
  'electrodomestico': 'Casa', 'limpieza': 'Casa', 'plomero': 'Casa',
  'mantenimiento': 'Casa', 'hogar': 'Casa', 'casa': 'Casa',
  'departamento': 'Casa', 'gas': 'Casa', 'tinaco': 'Casa', 'pintura': 'Casa',
  'home depot': 'Casa', 'truper': 'Casa', 'sodimac': 'Casa',
  'cortinas': 'Casa', 'lampara': 'Casa', 'foco': 'Casa', 'focos': 'Casa',
  'escoba': 'Casa', 'trapeador': 'Casa', 'clorox': 'Casa', 'cloro': 'Casa',
  'insecticida': 'Casa', 'candado': 'Casa', 'cerradura': 'Casa',
  'colchon': 'Casa', 'almohada': 'Casa', 'cobija': 'Casa',
  'regadera': 'Casa', 'tuberia': 'Casa', 'cable': 'Casa',
  'instalacion': 'Casa', 'electricista': 'Casa', 'carpintero': 'Casa',
  'albañil': 'Casa', 'fontanero': 'Casa',

  // ── Educación ──
  'escuela': 'Educacion', 'colegio': 'Educacion', 'universidad': 'Educacion',
  'colegiatura': 'Educacion', 'matricula': 'Educacion',
  'inscripcion': 'Educacion', 'curso': 'Educacion', 'taller': 'Educacion',
  'diplomado': 'Educacion', 'maestria': 'Educacion', 'doctorado': 'Educacion',
  'libros': 'Educacion', 'utiles': 'Educacion', 'papeleria': 'Educacion',
  'cuadernos': 'Educacion', 'plumas': 'Educacion', 'mochila': 'Educacion',
  'udemy': 'Educacion', 'coursera': 'Educacion', 'platzi': 'Educacion',
  'tutorias': 'Educacion', 'clases': 'Educacion', 'libro': 'Educacion',
  'educacion': 'Educacion', 'capacitacion': 'Educacion',
  'certificacion': 'Educacion', 'examen': 'Educacion',
  'tesis': 'Educacion', 'posgrado': 'Educacion',
  'prepa': 'Educacion', 'preparatoria': 'Educacion',
  'primaria': 'Educacion', 'secundaria': 'Educacion',

  // ── Gym / Deporte ──
  'gym': 'Gym', 'gimnasio': 'Gym', 'crossfit': 'Gym', 'yoga': 'Gym',
  'pilates': 'Gym', 'spinning': 'Gym', 'membresia': 'Gym',
  'smart fit': 'Gym', 'sport city': 'Gym', 'pesas': 'Gym',
  'proteina': 'Gym', 'suplementos': 'Gym', 'deporte': 'Gym',
  'ejercicio': 'Gym', 'correr': 'Gym', 'nadar': 'Gym',
  'natacion': 'Gym', 'futbol': 'Gym', 'basquet': 'Gym',
  'beisbol': 'Gym', 'tenis deporte': 'Gym', 'squash': 'Gym',
  'clase de baile': 'Gym', 'zumba': 'Gym', 'kick boxing': 'Gym',
  'box': 'Gym', 'boxeo': 'Gym', 'muay thai': 'Gym',
  'atletismo': 'Gym', 'marathon': 'Gym', 'triatlon': 'Gym',
  'proteinas': 'Gym', 'creatina': 'Gym', 'bcaa': 'Gym',
  'guantes de box': 'Gym',

  // ── Viajes ──
  'viaje': 'Viajes', 'hotel': 'Viajes', 'hostal': 'Viajes',
  'airbnb': 'Viajes', 'booking': 'Viajes', 'avion': 'Viajes',
  'aeropuerto': 'Viajes', 'vuelo': 'Viajes', 'maleta': 'Viajes',
  'vacaciones': 'Viajes', 'tour': 'Viajes', 'excursion': 'Viajes',
  'crucero': 'Viajes', 'resort': 'Viajes', 'pasaporte': 'Viajes',
  'visa': 'Viajes', 'seguro de viaje': 'Viajes',
  'alojamiento': 'Viajes', 'traslado': 'Viajes',

  // ── Regalos ──
  'regalo': 'Regalo', 'obsequio': 'Regalo', 'cumpleanos': 'Regalo',
  'navidad': 'Regalo', 'san valentin': 'Regalo', 'flores': 'Regalo',
  'chocolates': 'Regalo', 'pastel': 'Regalo',
  'dia de las madres': 'Regalo', 'dia del padre': 'Regalo',
  'quince anos': 'Regalo', 'boda': 'Regalo', 'baby shower': 'Regalo',
  'peluche': 'Regalo', 'joya': 'Regalo',

  // ── Mascotas ──
  'mascota': 'Mascotas', 'perro': 'Mascotas', 'gato': 'Mascotas',
  'veterinario': 'Mascotas', 'croquetas': 'Mascotas',
  'conejo': 'Mascotas', 'hamster': 'Mascotas', 'pajaro': 'Mascotas',
  'acuario': 'Mascotas', 'pez': 'Mascotas', 'tortuga': 'Mascotas',
  'arena del gato': 'Mascotas', 'collar del perro': 'Mascotas',
  'correa': 'Mascotas', 'juguete del perro': 'Mascotas',
  'desparasitar': 'Mascotas', 'antipulgas': 'Mascotas',
  'estetica canina': 'Mascotas', 'pension del perro': 'Mascotas',

  // ── Ingresos ──
  'sueldo': 'Ingresos', 'salario': 'Ingresos', 'quincena': 'Ingresos',
  'deposito': 'Ingresos', 'transferencia': 'Ingresos', 'cobro': 'Ingresos',
  'venta': 'Ingresos', 'freelance': 'Ingresos', 'pago': 'Ingresos',
  'nomina': 'Ingresos', 'bono': 'Ingresos', 'comision': 'Ingresos',
  'aguinaldo': 'Ingresos', 'prestamo': 'Ingresos', 'devolucion': 'Ingresos',
  'reembolso': 'Ingresos', 'dividendo': 'Ingresos', 'renta cobrada': 'Ingresos',
};

// ─────────────────────────────────────────────────────────────────────────────
// CLASE PRINCIPAL
// ─────────────────────────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────
// GRUPOS SEMANTICOS CANONICOS
// Permite que categorias con nombres creativos del usuario ("Alimentos",
// "Mercado", "Groceries") coincidan con los votos canonicos ("Comida","Super").
// ─────────────────────────────────────────────────────────────────────────────
const Map<String, List<String>> _canonicalGroups = {
  'Comida':          ['comida','alimentos','food','restaurante','comer','cocina','gastronomia','resto','eatery'],
  'Super':           ['super','supermercado','mercado','despensa','mandado','abarrotes','tienda','compras','groceries','market','bodega'],
  'Transporte':      ['transporte','movilidad','gasolina','combustible','auto','carro','vehiculo','traslado','transit'],
  'Ropa':            ['ropa','vestimenta','vestido','indumentaria','moda','calzado','accesorios','clothes','fashion'],
  'Salud':           ['salud','medico','medicina','farmacia','bienestar','health','wellness','doctor'],
  'Entretenimiento': ['entretenimiento','diversion','ocio','leisure','recreacion','suscripciones','fun'],
  'Juegos':          ['juegos','videojuegos','gaming','games','video games'],
  'Casa':            ['casa','hogar','home','vivienda','departamento','apartamento','servicios','hogar'],
  'Educacion':       ['educacion','estudio','aprendizaje','escuela','formacion','capacitacion','school','learning'],
  'Gym':             ['gym','gimnasio','deporte','ejercicio','fitness','sport','entrenamiento','workout'],
  'Viajes':          ['viajes','viaje','vacaciones','turismo','travel','tourism','excursion'],
  'Regalo':          ['regalo','regalos','obsequio','presentes','gifts','presente'],
  'Mascotas':        ['mascotas','mascota','pets','animales','animal'],
  'Ingresos':        ['ingresos','ingreso','sueldo','salario','income','ganancias','quincena','nomina'],
  'Inversion':       ['inversion','inversiones','ahorro','ahorros','investment','finanzas','fondos'],
};

class SmartCategoryMatcher {
  final List<CategoryItem> userCategories;

  SmartCategoryMatcher(this.userCategories);

  /// Encuentra la mejor categoria del usuario dado el texto de voz.
  CategoryItem? match(String voiceText, String? nlpCategory) {
    if (userCategories.isEmpty) return null;

    final norm   = _normalize(voiceText);
    final tokens = norm.split(RegExp(r'[\s,]+'));
    final votes  = <String, double>{};

    // ── Capa 1: Frases de contexto (bigramas/trigramas) — peso alto ──────────
    for (final entry in _contextPhrases.entries) {
      if (norm.contains(_normalize(entry.key))) {
        votes[entry.value] = (votes[entry.value] ?? 0) + 4.5;
      }
    }

    // ── Capa 2: Tokens individuales en alias semanticos ───────────────────────
    for (final token in tokens) {
      if (token.length < 3) continue;
      if (_semanticAliases.containsKey(token)) {
        final cat = _semanticAliases[token]!;
        votes[cat] = (votes[cat] ?? 0) + 2.5;
      }
      // Subcadena — peso menor para evitar falsos positivos
      for (final aliasEntry in _semanticAliases.entries) {
        if (aliasEntry.key.length >= 5 &&
            (aliasEntry.key.contains(token) || token.contains(aliasEntry.key))) {
          votes[aliasEntry.value] = (votes[aliasEntry.value] ?? 0) + 0.4;
        }
      }
    }

    // ── Capa 3: Bigramas y trigramas del texto ────────────────────────────────
    for (int i = 0; i < tokens.length - 1; i++) {
      final bigram = '${tokens[i]} ${tokens[i + 1]}';
      if (_semanticAliases.containsKey(bigram)) {
        votes[_semanticAliases[bigram]!] = (votes[_semanticAliases[bigram]!] ?? 0) + 3.0;
      }
      if (_contextPhrases.containsKey(bigram)) {
        votes[_contextPhrases[bigram]!] = (votes[_contextPhrases[bigram]!] ?? 0) + 3.5;
      }
      if (i < tokens.length - 2) {
        final trigram = '${tokens[i]} ${tokens[i+1]} ${tokens[i+2]}';
        if (_semanticAliases.containsKey(trigram)) {
          votes[_semanticAliases[trigram]!] = (votes[_semanticAliases[trigram]!] ?? 0) + 4.0;
        }
        if (_contextPhrases.containsKey(trigram)) {
          votes[_contextPhrases[trigram]!] = (votes[_contextPhrases[trigram]!] ?? 0) + 4.5;
        }
      }
    }

    // ── Capa 4: Voto del NLP — peso elevado (ya validado) ─────────────────────
    if (nlpCategory != null && nlpCategory.isNotEmpty) {
      votes[nlpCategory] = (votes[nlpCategory] ?? 0) + 2.5;
    }

    // ── Capa 5: Mapear votos canonicos a categorias reales del usuario ─────────
    final userScores = <CategoryItem, double>{};

    for (final item in userCategories) {
      double score = 0.0;
      final itemNorm = _normalize(item.name);

      for (final voteEntry in votes.entries) {
        final canonNorm = _normalize(voteEntry.key);
        final pts = voteEntry.value;

        // 5a. Match exacto
        if (canonNorm == itemNorm) {
          score += pts * 3.5;
          continue;
        }

        // 5b. El nombre del usuario es sinonimo del grupo canonico
        final group = _canonicalGroups[voteEntry.key];
        if (group != null && group.any((s) => _normalize(s) == itemNorm)) {
          score += pts * 3.0;
          continue;
        }

        // 5c. Contenido parcial
        if (canonNorm.contains(itemNorm) || itemNorm.contains(canonNorm)) {
          score += pts * 1.8;
          continue;
        }

        // 5d. Buscar en todos los grupos si el nombre del usuario es sinonimo
        //     del canonico votado (transitividad de grupos)
        bool matched = false;
        for (final grp in _canonicalGroups.entries) {
          final grpNorm = _normalize(grp.key);
          final isSameCanon = grpNorm == canonNorm ||
              grp.value.any((s) => _normalize(s) == canonNorm);
          if (isSameCanon) {
            final userInGroup = grpNorm == itemNorm ||
                grp.value.any((s) => _normalize(s) == itemNorm);
            if (userInGroup) {
              score += pts * 2.0;
              matched = true;
              break;
            }
          }
        }
        if (matched) continue;

        // 5e. Token overlap como ultimo recurso
        if (_tokenOverlap(canonNorm, itemNorm) > 0.4) {
          score += pts * 0.8;
        }
      }

      // Bonus A: nombre de la categoria aparece en el texto
      if (norm.contains(itemNorm) && itemNorm.length > 3) {
        score += 6.0;
      }

      // Bonus B: un sinonimo del grupo al que pertenece la categoria aparece en el texto
      for (final grp in _canonicalGroups.entries) {
        final isUserCat = _normalize(grp.key) == itemNorm ||
            grp.value.any((s) => _normalize(s) == itemNorm);
        if (isUserCat) {
          for (final syn in [grp.key, ...grp.value]) {
            final synNorm = _normalize(syn);
            if (synNorm.length > 3 && norm.contains(synNorm)) {
              score += 1.5;
              break;
            }
          }
        }
      }

      if (score > 0) userScores[item] = score;
    }

    if (userScores.isNotEmpty) {
      return userScores.entries
          .reduce((a, b) => a.value >= b.value ? a : b)
          .key;
    }

    // ── Fallback: solo NLP si no hay votos ────────────────────────────────────
    return matchFromNlpCategory(nlpCategory);
  }

  /// Versión sin texto de voz — solo usa la categoría NLP.
  CategoryItem? matchFromNlpCategory(String? nlpCategory) {
    if (nlpCategory == null || userCategories.isEmpty) return null;
    final normNlp = _normalize(nlpCategory);
    CategoryItem? best;
    double bestScore = 0;
    for (final item in userCategories) {
      final normItem = _normalize(item.name);
      double score = 0;
      if (normItem == normNlp) {
        score = 10;
      } else if (normItem.contains(normNlp) || normNlp.contains(normItem)) {
        score = 6;
      } else if (_tokenOverlap(normItem, normNlp) > 0.4) {
        score = 3;
      }
      if (score > bestScore) {
        bestScore = score;
        best = item;
      }
    }
    return best;
  }

  // ─── Utilidades ─────────────────────────────────────────────────────────────
  String _normalize(String s) => s
      .toLowerCase()
      .replaceAll('á', 'a').replaceAll('é', 'e').replaceAll('í', 'i')
      .replaceAll('ó', 'o').replaceAll('ú', 'u').replaceAll('ü', 'u')
      .replaceAll('ñ', 'n');

  double _tokenOverlap(String a, String b) {
    final ta = a.split(RegExp(r'\s+')).toSet();
    final tb = b.split(RegExp(r'\s+')).toSet();
    if (ta.isEmpty || tb.isEmpty) return 0;
    return ta.intersection(tb).length / ta.union(tb).length;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Provider de Riverpod
// ─────────────────────────────────────────────────────────────────────────────
final smartCategoryMatcherProvider = Provider<SmartCategoryMatcher>((ref) {
  final categories = ref.watch(categoryProvider);
  return SmartCategoryMatcher(categories);
});
