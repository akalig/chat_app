import 'dart:typed_data';
import 'package:chat_app/database/database_helper.dart';
import 'package:blurrycontainer/blurrycontainer.dart';
import 'package:chat_app/pages/authentication/register.dart';
import 'package:chat_app/pages/chat/chat_room.dart';
import 'package:chat_app/pages/chat/chats_page.dart';
import 'package:elegant_notification/elegant_notification.dart';
import 'package:elegant_notification/resources/arrays.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../components/buttons/authentication_button.dart';

class AuthenticationTextField extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final bool obscureText;

  const AuthenticationTextField({
    Key? key,
    required this.controller,
    required this.hintText,
    required this.obscureText,
  }) : super(key: key);

  @override
  _AuthenticationTextFieldState createState() => _AuthenticationTextFieldState();
}

class _AuthenticationTextFieldState extends State<AuthenticationTextField> {
  late bool _obscureText;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.obscureText;
  }

  void _toggleVisibility() {
    setState(() {
      _obscureText = !_obscureText;
    });
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      obscureText: _obscureText,
      decoration: InputDecoration(
        hintText: widget.hintText,
        suffixIcon: widget.hintText == 'Password'
            ? IconButton(
          icon: Icon(
            _obscureText ? Icons.visibility : Icons.visibility_off,
          ),
          onPressed: _toggleVisibility,
        )
            : null,
      ),
    );
  }
}

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();
  Uint8List? companyLogo;
  late DatabaseHelper db;

  @override
  void initState() {
    db = DatabaseHelper();
    // _fetchUserImage();
    super.initState();
  }

  // Future<void> _fetchUserImage() async {
  //   final image = await db.getCompanyImage();
  //   setState(() {
  //     companyLogo = image;
  //   });
  // }

  Future<void> _login() async {
    final username = usernameController.text;
    final password = passwordController.text;
    final db = DatabaseHelper();

    // In your _login method:
    final user = await db.authenticateUser(username, password);

    if (user == null) {
      _showMessage('Invalid username or password.');
    } else {
      final userId = user['user_id'];
      final email = user['email'];

      if (userId == null) {
        _showMessage('Invalid user data received');
        return;
      }

      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('userId', userId);
      await prefs.setString('username', username);
      if (email != null) await prefs.setString('email', email);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const ChatsPage()),
      );
    }
  }

  void _showMessage(String message) {
    ElegantNotification.error(
      width: 360,
      position: Alignment.topCenter,
      animation: AnimationType.fromTop,
      key: const Key('value'),
      description: Text(
        message,
        style: const TextStyle(color: Colors.blueGrey),
      ),
      progressBarHeight: 10,
      progressBarPadding: const EdgeInsets.symmetric(horizontal: 20),
      progressIndicatorBackground: Colors.blue[100]!,
      icon: const Icon(Icons.warning, color: Colors.redAccent),
      toastDuration: const Duration(seconds: 5),
    ).show(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFFFFFFF), // Dark Blue
                  Color(0xFFC5C5C5), // Light Blue
                ],
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: BlurryContainer(
                blur: 15,
                height: 500,
                width: 350,
                elevation: 6,
                padding: const EdgeInsets.all(20),
                color: Colors.black.withOpacity(0.1),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.mark_chat_unread_outlined, size: 100, color: Colors.black54,),
                    const SizedBox(height: 20),
                    AuthenticationTextField(
                      controller: usernameController,
                      hintText: 'Username',
                      obscureText: false,
                    ),
                    const SizedBox(height: 15),
                    AuthenticationTextField(
                      controller: passwordController,
                      hintText: 'Password',
                      obscureText: true,
                    ),
                    const SizedBox(height: 30),
                    LoginButton(onTap: _login),
                    // Add this to your Login's build method, inside the Column widget:
                    const SizedBox(height: 15),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const Register()),
                        );
                      },
                      child: const Text("Don't have an account? Register"),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
