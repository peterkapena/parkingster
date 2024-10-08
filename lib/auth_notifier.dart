import 'package:flutter/foundation.dart';

class AuthNotifier extends ValueNotifier<bool> {
  AuthNotifier() : super(false);

  void login() => value = true;
  void logout() => value = false;
}

final authNotifier = AuthNotifier();
