import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../../logic/chat_provider.dart';
import '../chat/chat_history_screen.dart';
import '../chat/chat_screen.dart';
import '../profile/profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // list of screens
  final List<Widget> _screens = [
    const ChatHistoryScreen(),
    const ChatScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {

    return Consumer<ChatProvider>(
      builder: (context, chatProvider, child) {
        return Scaffold(
            body: PageView(
              controller: chatProvider.pageController,
              children: _screens,
              onPageChanged: (index) {
                chatProvider.setCurrentIndex(newIndex: index);
              },
            ),
            bottomNavigationBar: BottomNavigationBar(
              currentIndex: chatProvider.currentIndex,
              elevation: 0,
              selectedItemColor: Theme.of(context).colorScheme.primary,
              onTap: (index) {
                chatProvider.setCurrentIndex(newIndex: index);
                chatProvider.pageController.jumpToPage(index);
              },
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.history),
                  label: 'Chat History',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.chat),
                  label: 'Chat',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person),
                  label: 'Profile',
                ),
              ],
            ));
      },
    );
  }
}
