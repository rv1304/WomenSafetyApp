import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistent contact storage backed by SharedPreferences.
/// Supports up to 10 contacts, priority ordering, and verification status.
class ContactService {
  static final ContactService _instance = ContactService._internal();
  factory ContactService() => _instance;
  ContactService._internal();

  static const String _contactsKey = 'trusted_contacts';
  static const int maxContacts = 10;

  // ---------------------------------------------------------------------------
  // READ
  // ---------------------------------------------------------------------------
  Future<List<Map<String, String>>> getContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_contactsKey);
    if (raw == null) return [];
    try {
      final List decoded = jsonDecode(raw) as List;
      return decoded.map((e) => Map<String, String>.from(e as Map)).toList();
    } catch (e) {
      debugPrint('ContactService read error: $e');
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // WRITE
  // ---------------------------------------------------------------------------
  Future<bool> addContact({
    required String name,
    required String phone,
    String relation = '',
  }) async {
    final contacts = await getContacts();
    if (contacts.length >= maxContacts) return false;

    // Avoid duplicates by phone
    if (contacts.any((c) => c['phone'] == phone)) return false;

    contacts.add({
      'name': name,
      'phone': phone,
      'relation': relation,
      'verified': 'false',
      'priority': contacts.length.toString(),
    });

    return await _save(contacts);
  }

  // ---------------------------------------------------------------------------
  // DELETE
  // ---------------------------------------------------------------------------
  Future<void> removeContact(int index) async {
    final contacts = await getContacts();
    if (index >= 0 && index < contacts.length) {
      contacts.removeAt(index);
      _reorderPriorities(contacts);
      await _save(contacts);
    }
  }

  // ---------------------------------------------------------------------------
  // REORDER (drag-to-reorder)
  // ---------------------------------------------------------------------------
  Future<void> reorderContacts(int oldIndex, int newIndex) async {
    final contacts = await getContacts();
    if (oldIndex < newIndex) newIndex -= 1;
    final item = contacts.removeAt(oldIndex);
    contacts.insert(newIndex, item);
    _reorderPriorities(contacts);
    await _save(contacts);
  }

  // ---------------------------------------------------------------------------
  // MARK VERIFIED
  // ---------------------------------------------------------------------------
  Future<void> markVerified(int index) async {
    final contacts = await getContacts();
    if (index >= 0 && index < contacts.length) {
      contacts[index]['verified'] = 'true';
      await _save(contacts);
    }
  }

  // ---------------------------------------------------------------------------
  // UPDATE CONTACT
  // ---------------------------------------------------------------------------
  Future<void> updateContact(
      int index, Map<String, String> updated) async {
    final contacts = await getContacts();
    if (index >= 0 && index < contacts.length) {
      contacts[index] = {...contacts[index], ...updated};
      await _save(contacts);
    }
  }

  // ---------------------------------------------------------------------------
  // CLEAR ALL
  // ---------------------------------------------------------------------------
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_contactsKey);
  }

  // ---------------------------------------------------------------------------
  // PRIVATE HELPERS
  // ---------------------------------------------------------------------------
  Future<bool> _save(List<Map<String, String>> contacts) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(contacts);
      return await prefs.setString(_contactsKey, encoded);
    } catch (e) {
      debugPrint('ContactService save error: $e');
      return false;
    }
  }

  void _reorderPriorities(List<Map<String, String>> contacts) {
    for (int i = 0; i < contacts.length; i++) {
      contacts[i]['priority'] = i.toString();
    }
  }
}
