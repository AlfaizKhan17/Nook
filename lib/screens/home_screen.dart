
import 'package:flutter/material.dart';

import 'add_item_screen.dart';
import 'my_post_screen.dart';
import 'profile_screen.dart';
import 'social_feed_screen.dart';
import 'groups_screen.dart';
import 'lost_found_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  Future<void> _openAdd() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AddItemScreen(),
      ),
    );

    if (mounted) {
      setState(() {});
    }
  }

  void _openProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ProfileScreen(),
      ),
    );
  }

  Widget _buildScreen() {
    switch (_tab) {
      case 0:
        return SocialFeedScreen(
          onProfileTap: _openProfile,
        );

      case 1:
        return const GroupsScreen();

      case 2:
        return const LostFoundScreen();

      case 3:
        return const MyPostsScreen(
          embedded: true,
        );

      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildScreen(),

      floatingActionButton: _tab == 2
          ? FloatingActionButton(
        onPressed: _openAdd,
        tooltip: 'Create a lost or found listing',
        child: const Icon(
          Icons.add_rounded,
          size: 30,
        ),
      )
          : null,

      floatingActionButtonLocation:
      FloatingActionButtonLocation.endFloat,

      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (index) {
          setState(() {
            _tab = index;
          });
        },
        height: 72,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups_rounded),
            label: 'Groups',
          ),
          NavigationDestination(
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search_rounded),
            label: 'Lost & Found',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2_rounded),
            label: 'My Posts',
          ),
        ],
      ),
    );
  }
}
