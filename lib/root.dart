import 'package:flutter/material.dart';
import 'package:parkingster/drawer.dart';
 
class Root extends StatefulWidget {
  const Root({super.key});

  @override
  State<Root> createState() => _RootState();
}

class _RootState extends State<Root> {
  int selectedIndex = 0;

  final List<Widget> _screens = [
    const Center(
      child: Text("Hello"),
    )
  ];
 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(),
      body: _screens[selectedIndex],
    );
  }
}
