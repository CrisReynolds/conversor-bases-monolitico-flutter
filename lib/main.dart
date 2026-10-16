// =============================================================================
//  PDM-307 · Ejemplo 17
//  CONVERSOR DE BASES Y LABORATORIO DE BITS
//  -----------------------------------------------------------------------
//  Sin plugins: el mismo archivo corre en Chrome, en Android y en DartPad.
//
//  LO QUE ENSEÑA
//    · Conversión entre binario, octal, decimal y hexadecimal.
//    · El algoritmo de divisiones sucesivas, mostrado paso a paso.
//    · Representación en bits, complemento a dos y rango con signo.
//    · Operaciones lógicas bit a bit: AND, OR, XOR, NOT y desplazamientos.
//
//  Y ADEMÁS, UNA DIFERENCIA REAL ENTRE PLATAFORMAS
//    En Android un int de Dart es de 64 bits con signo. En el navegador, en
//    cambio, se apoya en el tipo numérico de JavaScript y las operaciones
//    bit a bit trabajan sobre 32 bits. Por eso esta aplicación se limita a
//    32 bits: así el resultado es idéntico en las dos plataformas. La app lo
//    explica en pantalla, porque es un caso perfecto para el tema.
//
//  Autor: Ing. Cristian Miguel Reynolds Muriel · INTFOSIN "Khana Marka"
//  Flutter 3.41.7 · Dart 3.11
// =============================================================================

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() => runApp(const AppConversor());

// =============================================================================
// LÓGICA
// -----------------------------------------------------------------------------
// Dart puro otra vez: ni un import de Flutter en esta sección.
// =============================================================================

enum Base {
  binario(2, 'Binario', 'BIN', '0b'),
  octal(8, 'Octal', 'OCT', '0o'),
  decimal(10, 'Decimal', 'DEC', ''),
  hexadecimal(16, 'Hexadecimal', 'HEX', '0x');

  const Base(this.radix, this.nombre, this.sigla, this.prefijo);

  final int radix;
  final String nombre;
  final String sigla;
  final String prefijo;

  /// Dígitos permitidos en esta base. Sirve para filtrar lo que el usuario
  /// puede escribir: en binario solo 0 y 1, en hexadecimal 0-9 y A-F.
  String get alfabeto => '0123456789ABCDEF'.substring(0, radix);
}

class Conversor {
  /// Cuántos bits maneja la aplicación. Ver la nota del encabezado.
  static const int bits = 32;

  /// Valor máximo sin signo con 32 bits: 4 294 967 295.
  static const int maximo = 0xFFFFFFFF;

  // ---------------------------------------------------------------------------
  // TABLAS EN LUGAR DE DESPLAZAMIENTOS
  //
  // Sería natural escribir (1 << n) para obtener la potencia de dos, pero
  // en el navegador los desplazamientos trabajan sobre 32 bits y 1 << 32
  // no da lo esperado. Construir la tabla multiplicando por dos da el mismo
  // resultado en las dos plataformas, porque la multiplicación es exacta
  // mucho más allá de los 32 bits.
  // ---------------------------------------------------------------------------

  /// potencias[n] == 2 elevado a n, para n de 0 a 32.
  static final List<int> potencias = () {
    final lista = <int>[];
    int v = 1;
    for (int i = 0; i <= 32; i++) {
      lista.add(v);
      v *= 2;
    }
    return lista;
  }();

  /// Máscara de todos unos para cada ancho de palabra.
  static const Map<int, int> mascaras = {
    8: 0xFF,
    16: 0xFFFF,
    32: 0xFFFFFFFF,
  };

  /// Valor máximo sin signo según el ancho.
  static int maxSinSigno(int anchoBits) => mascaras[anchoBits] ?? maximo;

  /// Valor mínimo y máximo con signo según el ancho.
  static int minConSigno(int anchoBits) => -potencias[anchoBits - 1];
  static int maxConSigno(int anchoBits) => potencias[anchoBits - 1] - 1;

  /// Texto -> número. Devuelve null si el texto no es válido en esa base.
  /// int.tryParse con radix hace el trabajo pesado y nunca lanza excepción.
  static int? desdeTexto(String texto, Base base) {
    final limpio = texto.trim().toUpperCase().replaceAll(' ', '');
    if (limpio.isEmpty) return null;

    final valor = int.tryParse(limpio, radix: base.radix);
    if (valor == null || valor < 0 || valor > maximo) return null;
    return valor;
  }

  /// Número -> texto en la base pedida.
  static String enTexto(int valor, Base base) =>
      valor.toRadixString(base.radix).toUpperCase();

  /// Igual que el anterior, pero rellenando con ceros a la izquierda hasta
  /// completar los bits indicados. Solo tiene sentido en binario.
  static String enBinario(int valor, int anchoBits) =>
      valor.toRadixString(2).padLeft(anchoBits, '0');

  /// Agrupa de a cuatro para que el binario se pueda leer:
  ///     "11010110"  ->  "1101 0110"
  static String agrupar(String texto, [int tamano = 4]) {
    final buffer = StringBuffer();
    for (int i = 0; i < texto.length; i++) {
      // Un espacio cada vez que faltan un múltiplo de 'tamano' caracteres.
      if (i != 0 && (texto.length - i) % tamano == 0) buffer.write(' ');
      buffer.write(texto[i]);
    }
    return buffer.toString();
  }

  /// Los pasos del algoritmo de divisiones sucesivas, que es como se enseña
  /// la conversión en el pizarrón:
  ///     13 ÷ 2 = 6  resto 1
  ///      6 ÷ 2 = 3  resto 0
  ///      3 ÷ 2 = 1  resto 1
  ///      1 ÷ 2 = 0  resto 1   ->  se leen los restos de abajo hacia arriba
  static List<PasoDivision> pasosDivision(int valor, int radix) {
    if (valor == 0) {
      return [const PasoDivision(dividendo: 0, cociente: 0, resto: 0)];
    }

    final pasos = <PasoDivision>[];
    int actual = valor;
    while (actual > 0) {
      pasos.add(PasoDivision(
        dividendo: actual,
        cociente: actual ~/ radix, // división entera
        resto: actual % radix,
      ));
      actual = actual ~/ radix;
    }
    return pasos;
  }

  /// Interpreta el mismo patrón de bits como número con signo, usando
  /// complemento a dos: si el bit más significativo es 1, el valor es
  /// negativo y equivale a  valor - 2^bits.
  static int comoConSigno(int valor, int anchoBits) {
    final mitad = potencias[anchoBits - 1]; // 2^(bits-1)
    return valor >= mitad ? valor - potencias[anchoBits] : valor;
  }

  /// Recorta un resultado al ancho de bits elegido. Es lo que hace el
  /// hardware real: los bits que se salen simplemente se pierden.
  static int recortar(int valor, int anchoBits) =>
      valor & maxSinSigno(anchoBits);

  /// Invierte un bit concreto. El XOR con la potencia correspondiente es el
  /// truco estándar: 1 XOR 1 = 0 y 0 XOR 1 = 1, el resto queda intacto.
  static int conmutarBit(int valor, int posicion, int anchoBits) =>
      recortar(valor ^ potencias[posicion], anchoBits);

  /// Desplazamientos escritos con multiplicación y división entera para que
  /// den lo mismo en web y en Android, incluso con 32 bits.
  static int desplazarIzquierda(int valor, int anchoBits) =>
      recortar(valor * 2, anchoBits);

  static int desplazarDerecha(int valor) => valor ~/ 2;
}

class PasoDivision {
  final int dividendo;
  final int cociente;
  final int resto;

  const PasoDivision({
    required this.dividendo,
    required this.cociente,
    required this.resto,
  });
}

// =============================================================================
// APLICACIÓN
// =============================================================================

class AppConversor extends StatelessWidget {
  const AppConversor({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PDM-307 · Conversor de bases',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFFA6161C),
        brightness: Brightness.light,
      ),
      home: const PantallaConversor(),
    );
  }
}

class PantallaConversor extends StatefulWidget {
  const PantallaConversor({super.key});

  @override
  State<PantallaConversor> createState() => _PantallaConversorState();
}

class _PantallaConversorState extends State<PantallaConversor> {
  final TextEditingController _entrada = TextEditingController(text: '2026');

  Base _baseEntrada = Base.decimal;
  int _valor = 2026;
  bool _valido = true;
  int _anchoBits = 16;

  // Operandos de la pestaña de operaciones lógicas.
  int _a = 0xAC;
  int _b = 0x3F;

  @override
  void dispose() {
    _entrada.dispose();
    super.dispose();
  }

  void _alEscribir(String texto) {
    final nuevo = Conversor.desdeTexto(texto, _baseEntrada);
    setState(() {
      _valido = texto.trim().isEmpty || nuevo != null;
      if (nuevo != null) _valor = nuevo;
    });
  }

  /// Al cambiar de base, se reescribe el mismo NÚMERO en la nueva notación.
  /// Es importante: no se reinterpreta el texto, se conserva el valor.
  void _cambiarBase(Base nueva) {
    setState(() {
      _baseEntrada = nueva;
      _entrada.text = Conversor.enTexto(_valor, nueva);
      _valido = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('17 · Conversor de bases'),
          backgroundColor: tema.colorScheme.primary,
          foregroundColor: Colors.white,
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Color(0xFFE3A21A),
            tabs: [
              Tab(icon: Icon(Icons.swap_horiz), text: 'Conversor'),
              Tab(icon: Icon(Icons.grid_on), text: 'Bits'),
              Tab(icon: Icon(Icons.calculate_outlined), text: 'Operaciones'),
            ],
          ),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: TabBarView(
              children: [
                _pestanaConversor(),
                _pestanaBits(),
                _pestanaOperaciones(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // PESTAÑA 1 · CONVERSOR
  // ===========================================================================
  Widget _pestanaConversor() {
    // Los pasos se muestran siempre hacia binario, que es la conversión que
    // más cuesta entender y la que más se pide en los exámenes.
    final pasos = Conversor.pasosDivision(_valor, 2);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ---- Base de entrada -----------------------------------------
        const Text('El número que escribo está en:',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: Base.values.map((b) {
            return ChoiceChip(
              label: Text('${b.nombre}  (${b.radix})'),
              selected: _baseEntrada == b,
              onSelected: (_) => _cambiarBase(b),
            );
          }).toList(),
        ),
        const SizedBox(height: 14),

        // ---- Campo de entrada -----------------------------------------
        TextField(
          controller: _entrada,
          onChanged: _alEscribir,
          textCapitalization: TextCapitalization.characters,
          // El filtro impide escribir un 2 en binario o una G en hexadecimal.
          // Es mejor que validar después: el error no llega a existir.
          inputFormatters: [
            FilteringTextInputFormatter.allow(
              RegExp('[${_baseEntrada.alfabeto}${_baseEntrada.alfabeto.toLowerCase()}]'),
            ),
          ],
          decoration: InputDecoration(
            labelText: 'Número en ${_baseEntrada.nombre.toLowerCase()}',
            prefixText: _baseEntrada.prefijo,
            border: const OutlineInputBorder(),
            errorText: _valido ? null : 'No es válido en esta base',
            helperText: 'Dígitos permitidos: ${_baseEntrada.alfabeto}',
          ),
          style: const TextStyle(
              fontFamily: 'monospace', fontSize: 20, letterSpacing: 1),
        ),
        const SizedBox(height: 18),

        // ---- Resultados en las cuatro bases ----------------------------
        ...Base.values.map((b) => _TarjetaResultado(
          base: b,
          valor: _valor,
          esEntrada: b == _baseEntrada,
        )),

        const SizedBox(height: 10),
        _Nota(
          titulo: 'Lo mismo, escrito distinto',
          texto: 'Las cuatro tarjetas muestran EL MISMO número. Cambiar de '
              'base no cambia la cantidad, solo la notación con la que se '
              'escribe. Es igual que decir "doce" o "docena".',
        ),
        const SizedBox(height: 14),

        // ---- Divisiones sucesivas ---------------------------------------
        const Text('Divisiones sucesivas hacia binario',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        const Text(
          'Se divide una y otra vez entre 2 y se guardan los restos. El '
              'resultado se lee de ABAJO hacia ARRIBA.',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 10),
        _TablaPasos(pasos: pasos, radix: 2, valor: _valor),
      ],
    );
  }

  // ===========================================================================
  // PESTAÑA 2 · BITS
  // ===========================================================================
  Widget _pestanaBits() {
    final recortado = Conversor.recortar(_valor, _anchoBits);
    final binario = Conversor.enBinario(recortado, _anchoBits);
    final conSigno = Conversor.comoConSigno(recortado, _anchoBits);
    final maxSinSigno = Conversor.maxSinSigno(_anchoBits);
    final minConSigno = Conversor.minConSigno(_anchoBits);
    final maxConSigno = Conversor.maxConSigno(_anchoBits);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ---- Ancho de palabra -------------------------------------------
        const Text('Ancho de palabra',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [8, 16, 32].map((n) {
            return ChoiceChip(
              label: Text('$n bits'),
              selected: _anchoBits == n,
              onSelected: (_) => setState(() => _anchoBits = n),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),

        // ---- Rejilla de bits ---------------------------------------------
        const Text('Toca un bit para encenderlo o apagarlo',
            style: TextStyle(fontSize: 12, color: Colors.black54)),
        const SizedBox(height: 8),
        _RejillaBits(
          binario: binario,
          anchoBits: _anchoBits,
          alTocar: (posicion) {
            // posicion 0 es el bit menos significativo (el de la derecha).
            setState(() {
              _valor =
                  Conversor.conmutarBit(recortado, posicion, _anchoBits);
              _entrada.text = Conversor.enTexto(_valor, _baseEntrada);
            });
          },
        ),
        const SizedBox(height: 16),

        // ---- Las dos lecturas del mismo patrón ---------------------------
        Row(
          children: [
            Expanded(
              child: _Caja(
                titulo: 'Sin signo',
                valor: '$recortado',
                detalle: 'Rango: 0 a $maxSinSigno',
                color: const Color(0xFF0E7C66),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Caja(
                titulo: 'Con signo (complemento a dos)',
                valor: '$conSigno',
                detalle: 'Rango: $minConSigno a $maxConSigno',
                color: conSigno < 0
                    ? const Color(0xFFA6161C)
                    : const Color(0xFF02569B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        _Nota(
          titulo: 'El mismo patrón, dos significados',
          texto: 'Los bits de arriba no saben si son un número con signo o '
              'sin signo: eso lo decide quien los interpreta. Si el bit más '
              'a la izquierda vale 1, la lectura con signo da negativo. '
              'Enciende ese bit y observa cómo cambian las dos cajas.',
        ),
        const SizedBox(height: 14),

        // ---- Desplazamientos ----------------------------------------------
        const Text('Desplazamientos',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _botonBit('<< 1  (×2)',
                    () => _aplicar(Conversor.desplazarIzquierda(recortado, _anchoBits))),
            _botonBit('>> 1  (÷2)',
                    () => _aplicar(Conversor.desplazarDerecha(recortado))),
            _botonBit('NOT', () => _aplicar(~recortado)),
            _botonBit('Todo 1', () => _aplicar(maxSinSigno)),
            _botonBit('Todo 0', () => _aplicar(0)),
          ],
        ),
        const SizedBox(height: 10),
        _Nota(
          titulo: 'Por qué desplazar es multiplicar',
          texto: 'Correr los bits una posición a la izquierda multiplica por '
              '2, igual que en decimal correr una posición multiplica por 10. '
              'Es la operación más barata que existe en un procesador, y por '
              'eso los compiladores reemplazan x*2 por x<<1.',
        ),
        const SizedBox(height: 14),

        const _NotaPlataforma(),
      ],
    );
  }

  Widget _botonBit(String texto, VoidCallback alPulsar) {
    return OutlinedButton(
      onPressed: alPulsar,
      child: Text(texto, style: const TextStyle(fontFamily: 'monospace')),
    );
  }

  void _aplicar(int nuevo) {
    setState(() {
      _valor = Conversor.recortar(nuevo, _anchoBits);
      _entrada.text = Conversor.enTexto(_valor, _baseEntrada);
    });
  }

  // ===========================================================================
  // PESTAÑA 3 · OPERACIONES LÓGICAS
  // ===========================================================================
  Widget _pestanaOperaciones() {
    const ancho = 8; // esta pestaña trabaja con un byte, para que se lea bien
    final a = Conversor.recortar(_a, ancho);
    final b = Conversor.recortar(_b, ancho);

    final operaciones = <List<Object>>[
      ['A AND B', a & b, 'Un 1 solo donde AMBOS tienen 1. Sirve para '
          'enmascarar: apaga todo menos lo que interesa.'],
      ['A OR B', a | b, 'Un 1 donde CUALQUIERA tiene 1. Sirve para encender '
          'banderas sin tocar las demás.'],
      ['A XOR B', a ^ b, 'Un 1 donde son DISTINTOS. Sirve para invertir bits '
          'y es la base de sumadores y cifrados simples.'],
      ['NOT A', Conversor.recortar(~a, ancho), 'Invierte todos los bits de A.'],
      ['A << 1', Conversor.desplazarIzquierda(a, ancho),
        'Desplaza a la izquierda: multiplica por dos.'],
      ['A >> 1', Conversor.desplazarDerecha(a),
        'Desplaza a la derecha: divide entre dos descartando el resto.'],
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _EditorByte(
          etiqueta: 'A',
          valor: a,
          color: const Color(0xFF02569B),
          alCambiar: (v) => setState(() => _a = v),
        ),
        const SizedBox(height: 12),
        _EditorByte(
          etiqueta: 'B',
          valor: b,
          color: const Color(0xFF0E7C66),
          alCambiar: (v) => setState(() => _b = v),
        ),
        const SizedBox(height: 18),

        ...operaciones.map((op) {
          final nombre = op[0] as String;
          final resultado = op[1] as int;
          final explicacion = op[2] as String;

          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: 78,
                        child: Text(nombre,
                            style: const TextStyle(
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.bold)),
                      ),
                      Expanded(
                        child: Text(
                          Conversor.agrupar(
                              Conversor.enBinario(resultado, ancho)),
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 16,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      Text(
                        '$resultado',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '0x${Conversor.enTexto(resultado, Base.hexadecimal).padLeft(2, '0')}',
                        style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: Colors.black54),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(explicacion,
                      style: const TextStyle(fontSize: 11.5, height: 1.4)),
                ],
              ),
            ),
          );
        }),

        _Nota(
          titulo: 'Ejercicio',
          texto: 'Pon A = 1111 0000 y B = 0000 1111. Observa que AND da cero '
              'porque no comparten ningún 1, y que OR da 1111 1111. Luego '
              'prueba A XOR A: siempre da cero, y por eso XOR consigo mismo '
              'es la forma clásica de limpiar un registro.',
        ),
      ],
    );
  }
}

// =============================================================================
// WIDGETS
// =============================================================================

class _TarjetaResultado extends StatelessWidget {
  final Base base;
  final int valor;
  final bool esEntrada;

  const _TarjetaResultado({
    required this.base,
    required this.valor,
    required this.esEntrada,
  });

  @override
  Widget build(BuildContext context) {
    final texto = Conversor.enTexto(valor, base);
    final mostrado = base == Base.binario ? Conversor.agrupar(texto) : texto;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: esEntrada ? const Color(0xFFE4EFF7) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 52,
              child: Text(
                base.sigla,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Color(0xFF5A6472),
                ),
              ),
            ),
            Expanded(
              child: SelectableText(
                '${base.prefijo}$mostrado',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 17,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Copiar',
              iconSize: 18,
              onPressed: () {
                // El portapapeles funciona igual en web y en móvil: lo
                // resuelve Flutter con el canal de la plataforma.
                Clipboard.setData(ClipboardData(text: texto));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Copiado: $texto'),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
              icon: const Icon(Icons.copy),
            ),
          ],
        ),
      ),
    );
  }
}

class _TablaPasos extends StatelessWidget {
  final List<PasoDivision> pasos;
  final int radix;
  final int valor;

  const _TablaPasos({
    required this.pasos,
    required this.radix,
    required this.valor,
  });

  @override
  Widget build(BuildContext context) {
    // Los restos se leen del último paso al primero: por eso reversed.
    final lectura = pasos.reversed.map((p) => p.resto.toRadixString(radix)).join();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2029),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...pasos.asMap().entries.map((e) {
            final i = e.key;
            final p = e.value;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${p.dividendo.toString().padLeft(10)} ÷ $radix '
                          '= ${p.cociente.toString().padLeft(10)}',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: Color(0xFFE8EAED),
                      ),
                    ),
                  ),
                  Text(
                    'resto ${p.resto}',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      // El último paso es el primer dígito del resultado.
                      color: i == pasos.length - 1
                          ? const Color(0xFFE3A21A)
                          : const Color(0xFFAFD1A0),
                    ),
                  ),
                ],
              ),
            );
          }),
          const Divider(color: Colors.white24, height: 18),
          Text(
            '$valor en base $radix  =  $lectura',
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Color(0xFFE3A21A),
            ),
          ),
        ],
      ),
    );
  }
}

class _RejillaBits extends StatelessWidget {
  final String binario;
  final int anchoBits;
  final void Function(int posicion) alTocar;

  const _RejillaBits({
    required this.binario,
    required this.anchoBits,
    required this.alTocar,
  });

  @override
  Widget build(BuildContext context) {
    // Se dibuja de a 8 bits por fila: así cabe en un celular y se lee como
    // se escribe en el pizarrón.
    final filas = (anchoBits / 8).ceil();

    return Column(
      children: List.generate(filas, (fila) {
        final desde = fila * 8;
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: List.generate(8, (k) {
              final indiceTexto = desde + k;
              // La posición del bit se cuenta desde la derecha.
              final posicion = anchoBits - 1 - indiceTexto;
              final encendido = binario[indiceTexto] == '1';

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: GestureDetector(
                    onTap: () => alTocar(posicion),
                    child: Column(
                      children: [
                        AspectRatio(
                          aspectRatio: 1,
                          child: Container(
                            decoration: BoxDecoration(
                              color: encendido
                                  ? const Color(0xFF0E7C66)
                                  : const Color(0xFFF2F3F5),
                              border: Border.all(
                                color: encendido
                                    ? const Color(0xFF0E7C66)
                                    : const Color(0xFFDCDFE4),
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            alignment: Alignment.center,
                            child: FittedBox(
                              child: Padding(
                                padding: const EdgeInsets.all(6),
                                child: Text(
                                  encendido ? '1' : '0',
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
                                    color: encendido
                                        ? Colors.white
                                        : Colors.black38,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        // El exponente: este bit vale 2 elevado a ese número.
                        FittedBox(
                          child: Text(
                            '$posicion',
                            style: const TextStyle(
                                fontSize: 9, color: Colors.black45),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        );
      }),
    );
  }
}

class _EditorByte extends StatelessWidget {
  final String etiqueta;
  final int valor;
  final Color color;
  final void Function(int) alCambiar;

  const _EditorByte({
    required this.etiqueta,
    required this.valor,
    required this.color,
    required this.alCambiar,
  });

  @override
  Widget build(BuildContext context) {
    final binario = Conversor.enBinario(valor, 8);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  alignment: Alignment.center,
                  child: Text(etiqueta,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 10),
                Text('$valor',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(width: 10),
                Text('0x${valor.toRadixString(16).toUpperCase().padLeft(2, '0')}',
                    style: const TextStyle(
                        fontFamily: 'monospace', color: Colors.black54)),
              ],
            ),
            const SizedBox(height: 10),
            _RejillaBits(
              binario: binario,
              anchoBits: 8,
              alTocar: (posicion) =>
                  alCambiar(Conversor.conmutarBit(valor, posicion, 8)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Caja extends StatelessWidget {
  final String titulo;
  final String valor;
  final String detalle;
  final Color color;

  const _Caja({
    required this.titulo,
    required this.valor,
    required this.detalle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          FittedBox(
            child: Text(valor,
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontFamily: 'monospace')),
          ),
          const SizedBox(height: 2),
          Text(detalle,
              style: const TextStyle(fontSize: 10, color: Colors.black54)),
        ],
      ),
    );
  }
}

class _Nota extends StatelessWidget {
  final String titulo;
  final String texto;

  const _Nota({required this.titulo, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFBEFD3),
        border: Border.all(color: const Color(0xFFE3A21A)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Color(0xFF6E0F13))),
          const SizedBox(height: 4),
          Text(texto, style: const TextStyle(fontSize: 12, height: 1.45)),
        ],
      ),
    );
  }
}

/// Explica, dentro de la propia app, por qué se trabaja con 32 bits.
class _NotaPlataforma extends StatelessWidget {
  const _NotaPlataforma();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kIsWeb ? const Color(0xFFE4EFF7) : const Color(0xFFE9F5F1),
        border: Border.all(
            color: kIsWeb ? const Color(0xFF02569B) : const Color(0xFF0E7C66)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(kIsWeb ? Icons.language : Icons.phone_android,
                  size: 18,
                  color: kIsWeb
                      ? const Color(0xFF02569B)
                      : const Color(0xFF0E7C66)),
              const SizedBox(width: 8),
              Text(
                kIsWeb ? 'Corriendo en el navegador' : 'Corriendo en Android',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            kIsWeb
                ? 'Aquí un int de Dart se apoya en el tipo numérico de '
                'JavaScript, y las operaciones bit a bit trabajan sobre '
                '32 bits. Por eso esta app se limita a 32: así el '
                'resultado es idéntico al de Android.'
                : 'Aquí un int de Dart es de 64 bits con signo, así que se '
                'podría trabajar con palabras más anchas. La app se '
                'limita a 32 para que el resultado coincida con el de la '
                'versión web.',
            style: const TextStyle(fontSize: 11.5, height: 1.45),
          ),
        ],
      ),
    );
  }
}
