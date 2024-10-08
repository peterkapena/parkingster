import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:parkingster/api/graphql_config.dart';
import 'package:parkingster/map/map.dart';
import 'package:parkingster/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_notifier.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  final ValueNotifier<GraphQLClient> client = await GraphQLConfig.initClient();

  // Check initial login status
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString(refreshTokenString);
  if (token != null) {
    authNotifier.login();
  }
  final themeNotifier = ThemeNotifier(theme(), Brightness.light);
  await themeNotifier.loadTheme();

  runApp(
    GraphQLProvider(
      client: client,
      child: ChangeNotifierProvider(
        create: (context) => themeNotifier,
        child: const MyApp(),
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeNotifier>(
      builder: (context, themeNotifier, child) {
        return MaterialApp(
          title: 'Flutter YouTube UI',
          debugShowCheckedModeBanner: false,
          theme: themeNotifier.currentTheme,
          home: ValueListenableBuilder<bool>(
            valueListenable: authNotifier,
            builder: (context, isLoggedIn, child) {
              return const MapPage();
            },
          ),
        );
      },
    );
  }
}
