import 'dart:io';
import 'package:chat_app/pages/authentication/login.dart';
import 'package:chat_app/pages/chat/chats_page.dart';
import 'package:chat_app/pages/home_page.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late Future<bool> _isLoggedInFuture;

  @override
  void initState() {
    super.initState();
    _isLoggedInFuture = _checkLoginStatus();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _checkPermissions(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const MaterialApp(
            home: Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        return MaterialApp(
          title: 'Chat Application',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          ),
          home: FutureBuilder<bool>(
            future: _isLoggedInFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return const Center(child: Text('Error loading app'));
              } else {
                final isLoggedIn = snapshot.data ?? false;
                return isLoggedIn ? const ChatsPage() : const Login();
              }
            },
          ),
        );
      },
    );
  }

  Future<void> _checkPermissions() async {
    if (Platform.isAndroid) {
      await Permission.storage.request();
    }
  }

  Future<bool> _checkLoginStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool('isLoggedIn') ?? false;
  }
}