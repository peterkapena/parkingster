import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:parkingster/theme.dart';
import 'package:parkingster/widgets/user_email.dart';
import 'package:provider/provider.dart';

class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  PackageInfo _packageInfo = PackageInfo(
    appName: '',
    packageName: '',
    version: '',
    buildNumber: '',
    buildSignature: '',
    installerStore: '',
  );

  Future<void> _initPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _packageInfo = info;
    });
  }

  @override
  void initState() {
    super.initState();
    _initPackageInfo();
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(
              color: Colors.green,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Parkingster'),
                UserEmail(),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.sunny),
            title: const Text('Switch theme'),
            onTap: () {
              Provider.of<ThemeNotifier>(context, listen: false).toggleTheme();
            },
          ),
          SizedBox(
            height: MediaQuery.of(context).size.height * .2,
          ),
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(_packageInfo.appName),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                    'Version ${_packageInfo.version}+${_packageInfo.buildNumber}'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
