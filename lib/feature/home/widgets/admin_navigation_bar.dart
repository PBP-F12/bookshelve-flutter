import 'package:bookshelve_flutter/constant/color.dart';
import 'package:bookshelve_flutter/utils/cookie.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AdminNavigationBar extends StatefulWidget {
  int index;
  Function onTap;

  AdminNavigationBar({super.key, required this.index, required this.onTap});

  @override
  State<AdminNavigationBar> createState() =>
      _AdminNavigationBarState(index: index, onTap: onTap);
}

class _AdminNavigationBarState extends State<AdminNavigationBar> {
  int index;
  Function onTap;

  _AdminNavigationBarState({required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    CookieRequest request = context.watch<CookieRequest>();

    return CurvedNavigationBar(
      index: index,
      items: const [
        Icon(Icons.home_filled, color: FontanaColor.brown2),
        Icon(Icons.event, color: FontanaColor.brown2),
        Icon(Icons.person, color: FontanaColor.brown2)
      ],
      onTap: (int index) {
        onTap(index);
      },
      color: const Color(0xffeac696),
      backgroundColor: Colors.transparent,
      buttonBackgroundColor: const Color(0xfff8ede3),
      animationDuration: const Duration(milliseconds: 300),
      height: 50,
    );
  }
}
