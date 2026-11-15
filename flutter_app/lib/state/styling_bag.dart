import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/catalog.dart';

const String bagStorageKey = 'runway-styling-bag-v3';
const String allowedProductHost = 'nike-makknzjs.myshopify.com';

class BagEntry {
  BagEntry({required this.id, required this.quantity});

  final int id;
  int quantity;

  Map<String, dynamic> toJson() => {'id': id, 'quantity': quantity};
}

class VariantMatch {
  const VariantMatch({required this.item, required this.variant});

  final CatalogItem item;
  final CatalogVariant variant;
}

class StylingBag extends ChangeNotifier {
  StylingBag() {
    for (final item in RunwayCatalog.items) {
      for (final variant in item.variants) {
        _variantIndex[variant.id] = VariantMatch(item: item, variant: variant);
      }
    }
  }

  final Map<int, VariantMatch> _variantIndex = {};
  List<BagEntry> _entries = [];
  String? _toastMessage;
  int _toastRevision = 0;

  List<BagEntry> get entries => List.unmodifiable(_entries);
  String? get toastMessage => _toastMessage;
  int get toastRevision => _toastRevision;

  int get totalCount => _entries.fold(0, (sum, e) => sum + e.quantity);

  double get subtotal {
    var total = 0.0;
    for (final entry in _entries) {
      final match = _variantIndex[entry.id];
      if (match != null) {
        total += match.item.price * entry.quantity;
      }
    }
    return total;
  }

  VariantMatch? matchForVariant(int variantId) => _variantIndex[variantId];

  static String formatMoney(double amount) => '\$${amount.toStringAsFixed(2)}';

  static Uri validateProductUri(String urlString) {
    final uri = Uri.parse(urlString);
    if (uri.host != allowedProductHost) {
      throw ArgumentError('Invalid product URL host: ${uri.host}');
    }
    return uri;
  }

  static List<BagEntry> parseEntries(String? rawJson) {
    if (rawJson == null || rawJson.isEmpty) return [];
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is! List) return [];
      final out = <BagEntry>[];
      for (final row in decoded) {
        if (row is! Map) continue;
        final id = row['id'];
        final qty = row['quantity'];
        if (id is int && qty is int && qty >= 1 && qty <= 20) {
          out.add(BagEntry(id: id, quantity: qty));
          if (out.length >= 50) break;
        }
      }
      return out;
    } catch (_) {
      return [];
    }
  }

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _entries = parseEntries(prefs.getString(bagStorageKey));
      notifyListeners();
    } catch (_) {
      // ignore storage load failures
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = jsonEncode(_entries.map((e) => e.toJson()).toList());
      await prefs.setString(bagStorageKey, payload);
    } catch (_) {
      // ignore storage save failures
    }
  }

  void add(List<({int id, int quantity})> items) {
    final next = _entries.map((e) => BagEntry(id: e.id, quantity: e.quantity)).toList();
    for (final req in items) {
      final match = _variantIndex[req.id];
      if (match == null || !match.variant.available) {
        throw StateError('Please choose an available size.');
      }
      final existingIdx = next.indexWhere((e) => e.id == req.id);
      if (existingIdx >= 0) {
        next[existingIdx].quantity =
            (next[existingIdx].quantity + req.quantity.clamp(1, 20)).clamp(1, 20);
      } else if (next.length < 50) {
        next.add(BagEntry(id: req.id, quantity: req.quantity.clamp(1, 20)));
      }
    }
    _entries = next;
    _save();
    showToast(
      items.length > 1
          ? 'Look saved to your styling bag'
          : 'Piece saved to your styling bag',
    );
    notifyListeners();
  }

  void remove(int variantId) {
    _entries = _entries.where((e) => e.id != variantId).toList();
    _save();
    notifyListeners();
  }

  void showToast(String message) {
    _toastMessage = message;
    _toastRevision++;
    final rev = _toastRevision;
    notifyListeners();
    Future<void>.delayed(const Duration(milliseconds: 2500), () {
      if (_toastRevision == rev && _toastMessage != null) {
        _toastMessage = null;
        notifyListeners();
      }
    });
  }

  String buildShortlistText() {
    final parts = <String>[
      'RUNWAY — STYLING SHORTLIST',
      'Reference prices; no order or payment has been placed.',
      '',
    ];
    for (final entry in _entries) {
      final match = _variantIndex[entry.id];
      if (match == null) continue;
      final size = match.variant.options.join(' / ');
      parts.add('${match.item.name} · Size $size · Quantity ${entry.quantity}');
      parts.add(validateProductUri(match.item.url).toString());
    }
    return parts.join('\n\n');
  }
}
