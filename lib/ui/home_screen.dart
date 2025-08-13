import 'package:flutter/material.dart';
import '../views/home_view.dart';
import '../views/menu_view.dart';
import '../views/profile_view.dart';
import '../widgets/glowing_nav_item.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 1;

  final List<Widget> _views = const [
    MenuView(),
    HomeView(),
    ProfileView(),
  ];

  final List<IconData> _icons = const [
    Icons.menu,
    Icons.home,
    Icons.person,
  ];

  final List<String> _titles = const [
    'Settings',
    'Home',
    'Profile',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lock Your Door'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          // Remove the AI Test button
          // IconButton(
          //   tooltip: 'AI Test',
          //   icon: const Icon(Icons.videocam),
          //   onPressed: () {
          //     Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AITestView()));
          //   },
          // ),
        ],
      ),
      backgroundColor: Colors.transparent,
      extendBody: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF3D0F63), Color(0xFF5A2F7E), Color(0xFF5F3384)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: IndexedStack(
          index: _selectedIndex,
          children: _views,
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(32, 0, 32, 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(_icons.length, (index) {
              return GlowingNavItem(
                key: ValueKey('nav_$index'),
                isSelected: _selectedIndex == index,
                icon: _icons[index],
                onTap: () {
                  if (_selectedIndex == index) return;
                  setState(() => _selectedIndex = index);
                },
              );
            }),
          ),
        ),
      ),
    );
  }
}