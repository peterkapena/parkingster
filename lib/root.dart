import 'package:flutter/material.dart';
import 'package:parkingster/drawer.dart';
import 'package:parkingster/widgets/map_sample.dart';

class Root extends StatefulWidget {
  const Root({super.key});

  @override
  State<Root> createState() => _RootState();
}

class _RootState extends State<Root> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(),
      body: const MapSample(),
    );
  }
}
