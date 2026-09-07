/// Valores lógicos de 1 bit, no estilo do Logisim.
///
/// - [zero] / [one]: níveis lógicos definidos (verde-escuro / verde-claro);
/// - [unknown]: flutuante / não conectado (azul);
/// - [error]: conflito de drivers ou entrada inválida (vermelho).
enum LogicValue {
  zero,
  one,
  unknown,
  error;

  bool get isDefined => this == zero || this == one;

  LogicValue get not {
    switch (this) {
      case LogicValue.zero:
        return LogicValue.one;
      case LogicValue.one:
        return LogicValue.zero;
      case LogicValue.unknown:
      case LogicValue.error:
        return LogicValue.error;
    }
  }

  /// Resolve o valor de uma rede com vários drivers (como um barramento).
  static LogicValue resolve(LogicValue a, LogicValue b) {
    if (a == LogicValue.error || b == LogicValue.error) return LogicValue.error;
    if (a == LogicValue.unknown) return b;
    if (b == LogicValue.unknown) return a;
    if (a == b) return a;
    return LogicValue.error; // 0 + 1 em curto
  }
}
