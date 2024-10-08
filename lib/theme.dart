import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeNotifier extends ChangeNotifier {
  ThemeData _currentTheme;
  Brightness _brightness;

  ThemeNotifier(this._currentTheme, this._brightness);

  ThemeData get currentTheme => _currentTheme;
  Brightness get brightness => _brightness;

  Future<void> toggleTheme() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (_brightness == Brightness.dark) {
      _brightness = Brightness.light;
      _currentTheme = theme(Brightness.light);
      await prefs.setBool('isDarkMode', false);
    } else {
      _brightness = Brightness.dark;
      _currentTheme = theme(Brightness.dark);
      await prefs.setBool('isDarkMode', true);
    }
    notifyListeners();
  }

  Future<void> loadTheme() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool? isDarkMode = prefs.getBool('isDarkMode');
    if (isDarkMode == null) {
      // Use system theme if no preference is set
      var brightness = PlatformDispatcher.instance.platformBrightness;
      _brightness = brightness;
      _currentTheme = theme(brightness);
    } else {
      _brightness = isDarkMode ? Brightness.dark : Brightness.light;
      _currentTheme = theme(_brightness);
    }
    notifyListeners();
  }
}

// Define your custom theme function
ThemeData theme([Brightness brightness = Brightness.light]) {
  return ThemeData(
    useMaterial3: true,
    hintColor: Colors.blueAccent,
    colorScheme: ColorScheme.fromSeed(
      brightness: brightness,
      seedColor: Colors.green,
      primary: Colors.green,
      secondary: Colors.blue,
      error: Colors.red,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      elevation: 10,
      enableFeedback: true,
      type: BottomNavigationBarType.shifting,
      selectedLabelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
      unselectedLabelStyle:
          TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontSize: 72,
        fontWeight: FontWeight.bold,
      ),
      // ...
    ),
  );
}
