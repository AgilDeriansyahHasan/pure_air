import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../services/users.dart';
import '../admin_page/admin_page.dart';
import '../users_page/user_dashboard_page.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() =>
      _LoginPageState();
}

class _LoginPageState
    extends State<LoginPage> {
  final TextEditingController
  email =
  TextEditingController();

  final TextEditingController
  password =
  TextEditingController();

  bool isLoading = false;

  Future<void> login() async {
    setState(() {
      isLoading = true;
    });

    try {
      final response =
      await http.post(
        Uri.parse(
          "${ApiService.baseUrl}/login.php",
        ),

        body: {
          "email":
          email.text.trim(),

          "password":
          password.text.trim(),
        },
      );

      print(response.body);

      final data =
      jsonDecode(
        response.body,
      );

      if (data["status"] ==
          "success") {
        if (data["role"] ==
            "admin") {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AdminDashboardPage(
                username: data["username"],
                email: data["email"],
              ),
            ),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder:
                  (_) =>
                  UserDashboardPage(
                    username:
                    data["username"],
                    email:
                    data["email"],
                  ),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          SnackBar(
            content: Text(
              data["message"] ??
                  "Login Failed",
            ),
          ),
        );
      }
    } catch (e) {
      print(e);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content: Text(
            "Error: $e",
          ),
        ),
      );
    }

    setState(() {
      isLoading = false;
    });
  }

  @override
  void dispose() {
    email.dispose();
    password.dispose();

    super.dispose();
  }

  @override
  Widget build(
      BuildContext context,
      ) {
    return Scaffold(
      body: Padding(
        padding:
        const EdgeInsets.all(
          20,
        ),

        child: Column(
          mainAxisAlignment:
          MainAxisAlignment
              .center,

          children: [
            const Text(
              "Login",

              style: TextStyle(
                fontSize: 28,
                fontWeight:
                FontWeight.bold,
              ),
            ),

            const SizedBox(
              height: 30,
            ),

            TextField(
              controller: email,

              decoration:
              const InputDecoration(
                hintText:
                "Email",

                border:
                OutlineInputBorder(),
              ),
            ),

            const SizedBox(
              height: 20,
            ),

            TextField(
              controller:
              password,

              obscureText:
              true,

              decoration:
              const InputDecoration(
                hintText:
                "Password",

                border:
                OutlineInputBorder(),
              ),
            ),

            const SizedBox(
              height: 30,
            ),

            SizedBox(
              width:
              double.infinity,

              height: 50,

              child:
              ElevatedButton(
                onPressed:
                isLoading
                    ? null
                    : login,

                child:
                isLoading
                    ? const CircularProgressIndicator(
                  color:
                  Colors.white,
                )
                    : const Text(
                  "Login",
                ),
              ),
            ),

            const SizedBox(
              height: 15,
            ),

            TextButton(
              onPressed: () {
                Navigator.push(
                  context,

                  MaterialPageRoute(
                    builder:
                        (_) =>
                    const RegisterPage(),
                  ),
                );
              },

              child: const Text(
                "Belum punya akun? Register",
              ),
            ),
          ],
        ),
      ),
    );
  }
}