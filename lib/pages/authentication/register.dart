import 'package:chat_app/database/database_helper.dart';
import 'package:flutter/material.dart';
import 'package:elegant_notification/elegant_notification.dart';
import 'package:elegant_notification/resources/arrays.dart';
import 'login.dart';

class Register extends StatefulWidget {
  const Register({Key? key}) : super(key: key);

  @override
  State<Register> createState() => _RegisterState();
}

class _RegisterState extends State<Register> {
  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final emailController = TextEditingController();
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  final db = DatabaseHelper();
  bool _isLoading = false;

  Future<void> _register() async {
    if (passwordController.text != confirmPasswordController.text) {
      _showMessage("Passwords don't match");
      return;
    }

    if (firstNameController.text.isEmpty ||
        lastNameController.text.isEmpty ||
        emailController.text.isEmpty ||
        usernameController.text.isEmpty ||
        passwordController.text.isEmpty) {
      _showMessage("Please fill all fields");
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Check if username is taken
      final isTaken = await db.isUsernameTaken(usernameController.text);
      if (isTaken) {
        _showMessage("Username already taken");
        return;
      }

      // Register user
      final userId = await db.registerUser(
        firstName: firstNameController.text,
        lastName: lastNameController.text,
        email: emailController.text,
        username: usernameController.text,
        password: passwordController.text,
      );

      if (userId != null) {
        _showSuccess("Registration successful!");
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const Login()),
        );
      } else {
        _showMessage("Registration failed. Please try again.");
      }
    } catch (e) {
      _showMessage("An error occurred: ${e.toString()}");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showMessage(String message) {
    ElegantNotification.error(
      width: 360,
      position: Alignment.topCenter,
      animation: AnimationType.fromTop,
      description: Text(message),
    ).show(context);
  }

  void _showSuccess(String message) {
    ElegantNotification.success(
      width: 360,
      position: Alignment.topCenter,
      animation: AnimationType.fromTop,
      description: Text(message),
    ).show(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Register'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: firstNameController,
              decoration: const InputDecoration(labelText: 'First Name'),
            ),
            TextField(
              controller: lastNameController,
              decoration: const InputDecoration(labelText: 'Last Name'),
            ),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            TextField(
              controller: usernameController,
              decoration: const InputDecoration(labelText: 'Username'),
            ),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            TextField(
              controller: confirmPasswordController,
              decoration: const InputDecoration(labelText: 'Confirm Password'),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            // AuthenticationButton(
            //   text: 'Register',
            //   onTap: _isLoading ? null : _register,
            //   isLoading: _isLoading,
            // ),

            TextButton(onPressed: _isLoading ? null : _register, child: Text('Login'))
          ],
        ),
      ),
    );
  }
}