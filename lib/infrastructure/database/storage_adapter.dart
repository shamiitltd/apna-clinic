// Apna Clinic - Storage Adapter Abstraction
// Allows LocalDatabase to run seamlessly across in-memory tests and browser persistence

import 'dart:async';

abstract class IStorageAdapter {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> remove(String key);
  Future<void> clear();
}

/// In-memory storage adapter for zero-overhead unit testing
class MemoryStorageAdapter implements IStorageAdapter {
  final Map<String, String> _store = {};

  @override
  Future<String?> read(String key) async => _store[key];

  @override
  Future<void> write(String key, String value) async {
    _store[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    _store.remove(key);
  }

  @override
  Future<void> clear() async {
    _store.clear();
  }
}
