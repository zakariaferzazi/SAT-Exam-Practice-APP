import 'package:shared_preferences/shared_preferences.dart';

class UserPreferences {
  static const String _keyName = 'user_name';
  static const String _keyGender = 'user_gender';
  static const String _keyIsFirstLaunch = 'is_first_launch';

  // Save user name
  static Future<bool> setName(String name) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.setString(_keyName, name);
  }

  // Get user name
  static Future<String?> getName() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyName);
  }

  // Save user gender
  static Future<bool> setGender(String gender) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.setString(_keyGender, gender);
  }

  // Get user gender
  static Future<String?> getGender() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyGender);
  }

  // Set first launch flag to false
  static Future<bool> completeFirstLaunch() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.setBool(_keyIsFirstLaunch, false);
  }

  // Check if it's the first launch
  static Future<bool> isFirstLaunch() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsFirstLaunch) ?? true;
  }
}
