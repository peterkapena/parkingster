import 'package:flutter/material.dart';
import 'package:parkingster/api/graphql_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserEmail extends StatelessWidget {
  const UserEmail({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: SharedPreferences.getInstance().then((onValue) => onValue),
      builder:
          (BuildContext context, AsyncSnapshot<SharedPreferences> snapshot) {
        return Text(snapshot.data?.getString(emailString) ?? '');
      },
    );
  }
}
