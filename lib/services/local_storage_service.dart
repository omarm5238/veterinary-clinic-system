import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/user.dart';
import '../models/chat_message.dart';

/// Local storage service using SharedPreferences (web-compatible)
class LocalStorageService {
  static final LocalStorageService instance = LocalStorageService._init();
  SharedPreferences? _prefs;

  LocalStorageService._init();

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  // User session
  Future<void> saveUserSession(User user) async {
    await init();
    await _prefs!.setString('current_user', jsonEncode(user.toMap()));
    await _prefs!.setBool('is_logged_in', true);
  }

  Future<User?> getCurrentUser() async {
    await init();
    final userJson = _prefs!.getString('current_user');
    if (userJson != null) {
      return User.fromMap(jsonDecode(userJson));
    }
    return null;
  }

  Future<bool> isLoggedIn() async {
    await init();
    return _prefs!.getBool('is_logged_in') ?? false;
  }

  Future<void> clearSession() async {
    await init();
    await _prefs!.remove('current_user');
    await _prefs!.setBool('is_logged_in', false);
  }

  // Save users
  Future<void> saveUsers(List<User> users) async {
    await init();
    final usersJson = users.map((u) => jsonEncode(u.toMap())).toList();
    await _prefs!.setStringList('users', usersJson);
  }

  Future<List<User>> getUsers() async {
    await init();
    final usersJson = _prefs!.getStringList('users') ?? [];
    return usersJson.map((json) => User.fromMap(jsonDecode(json))).toList();
  }



  // Save chat messages
  Future<void> saveChatMessages(List<ChatMessage> messages) async {
    await init();
    final messagesJson = messages.map((m) => jsonEncode(m.toMap())).toList();
    await _prefs!.setStringList('chat_messages', messagesJson);
  }

  Future<List<ChatMessage>> getChatMessages() async {
    await init();
    final messagesJson = _prefs!.getStringList('chat_messages') ?? [];
    return messagesJson.map((json) => ChatMessage.fromMap(jsonDecode(json))).toList();
  }

  // Clear all data
  Future<void> clearAll() async {
    await init();
    await _prefs!.clear();
  }
}

