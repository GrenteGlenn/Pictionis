import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  // final _usernameController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isLogin =
      true; // Pour savoir si l'utilisateur se connecte ou crée un compte
  String _errorMessage = '';

  Future<void> _loginOrSignUp() async {
    try {
      if (_isLogin) {
        // Connexion avec un compte existant
        await _auth.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      } else {
        // Création d'un nouveau compte
        await _auth.createUserWithEmailAndPassword(
          // username: _usernameController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      }
      // Redirection après connexion ou inscription réussie
      Navigator.of(context).pushReplacementNamed('/rooms');
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = e.message ?? 'Une erreur est survenue.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isLogin ? 'Connexion' : 'Inscription'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _emailController,
              decoration: InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(labelText: 'Mot de passe'),
              obscureText: true,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loginOrSignUp,
              child: Text(_isLogin ? 'Connexion' : 'Créer un compte'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _isLogin =
                      !_isLogin; // Bascule entre connexion et inscription
                });
              },
              child: Text(_isLogin
                  ? "Pas de compte ? Inscription ici"
                  : "Compte déjà existant ? Connexion ici"),
            ),
            if (_errorMessage.isNotEmpty)
              Text(
                _errorMessage,
                style: TextStyle(color: Colors.red),
              ),
          ],
        ),
      ),
    );
  }
}
