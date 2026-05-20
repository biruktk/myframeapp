enum TransportKind {
  wifi,
  bluetooth,
}

extension TransportKindX on TransportKind {
  String get label => switch (this) {
        TransportKind.wifi => 'Wi‑Fi',
        TransportKind.bluetooth => 'Bluetooth',
      };

  /// Server / API field name (matches enum name).
  String get apiValue => name;
}
